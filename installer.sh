#!/usr/bin/env bash
# Copyright (c) INFRA - Andrea Bodei 2026-2036
set -Eeuo pipefail

# Universal CMS Vulnerability Scanner installer
# Installs all tools listed in README.md with best-effort compatibility handling.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
VENV_DIR=""
VENV_DIR_SET_BY_ARG=0
BIN_DIR="${SCRIPT_DIR}/bin"
LOG_FILE="${SCRIPT_DIR}/logs/installer.log"

# Runtime switches (CLI options can override these defaults).
INSTALL_SYSTEM_DEPS=0
RUN_SMOKE_TESTS=1
UPDATE_EXISTING=1
STRICT_MODE=0
INSTALL_USER=""
INSTALL_HOME=""
USER_GEM_BIN=""
BASE_PATH="${PATH}"
APT_UPDATED=0
SHOW_COMMAND_OUTPUT="${SHOW_COMMAND_OUTPUT:-0}"
FAIL_OUTPUT_TAIL_LINES="${FAIL_OUTPUT_TAIL_LINES:-120}"

# Result buckets used in final summary.
declare -a INSTALLED=()
declare -a SKIPPED=()
declare -a FAILED=()
declare -a WARNINGS=()
declare -a PHASE_RESULTS=()

# -----------------------------------------------------------------------------
# CLI and logging helpers
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: ./installer.sh [options]

Options:
  --system-deps             Install full apt dependency set up front (requires sudo/root)
  --skip-smoke-tests        Skip post-install smoke tests
  --no-update               Do not pull existing git repositories
  --strict                  Exit non-zero when skipped tools or warnings are present
  --tools-dir <path>        Override tool checkout directory (default: ./tools)
  --venv-dir <path>         Override python venv directory (default: <user-home>/.venv/cms_scanner)
  --bin-dir <path>          Override wrappers directory (default: ./bin)
  --log-file <path>         Override log file path (default: ./logs/installer.log)
  -h, --help                Show this help
EOF
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE"
}

warn() {
  WARNINGS+=("$*")
  log "WARN: $*"
}

mark_installed() {
  INSTALLED+=("$1")
  log "OK: $1 installed"
}

mark_skipped() {
  SKIPPED+=("$1: $2")
  log "SKIP: $1 - $2"
}

mark_failed() {
  FAILED+=("$1: $2")
  log "FAIL: $1 - $2"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Prepare a compact one-line preview for logged commands.
command_preview() {
  local text="$*"
  text="${text//$'\r'/}"
  text="${text//$'\n'/\\n}"
  if ((${#text} > 220)); then
    printf '%s...' "${text:0:220}"
  else
    printf '%s' "${text}"
  fi
}

run_and_capture_output() {
  local tmp_file="$1"
  shift
  local rc=0
  set +e
  "$@" >"${tmp_file}" 2>&1
  rc=$?
  set -e
  cat "${tmp_file}" >>"$LOG_FILE"
  return "$rc"
}

emit_failure_output() {
  local rc="$1"
  local preview="$2"
  local tmp_file="$3"
  log "ERROR: command failed with exit ${rc}: ${preview}"
  if [[ -s "${tmp_file}" ]]; then
    tail -n "${FAIL_OUTPUT_TAIL_LINES}" "${tmp_file}" >&2 || true
  fi
}

# Shared command runner:
# - logs command intent
# - captures full output to installer log
# - prints output only when SHOW_COMMAND_OUTPUT=1
# - prints failure tail on non-zero exit
run_logged_command() {
  local log_line="$1"
  local fail_preview="$2"
  shift 2
  local tmp_file
  local rc=0

  log "${log_line}"
  tmp_file="$(mktemp)"
  if run_and_capture_output "${tmp_file}" "$@"; then
    if [[ "${SHOW_COMMAND_OUTPUT}" -eq 1 ]]; then
      cat "${tmp_file}"
    fi
    rm -f "${tmp_file}"
    return 0
  fi

  rc=$?
  emit_failure_output "$rc" "${fail_preview}" "${tmp_file}"
  rm -f "${tmp_file}"
  return "$rc"
}

# Execute a host-level command (current user/root context).
run_cmd() {
  local preview

  preview="$(command_preview "$@")"
  run_logged_command "RUN: ${preview}" "${preview}" "$@"
}

require_option_arg() {
  local opt="$1"
  local value="${2:-}"
  if [[ -z "${value}" || "${value}" == --* ]]; then
    echo "Option ${opt} requires a value" >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# User resolution and command execution context
# -----------------------------------------------------------------------------

# Determine the non-root user that should own cloned repos, venvs, and wrappers.
resolve_install_user() {
  local detected_user=""
  local detected_home=""

  if [[ "${EUID}" -ne 0 ]]; then
    detected_user="${USER:-$(id -un)}"
  else
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && id -u "${SUDO_USER}" >/dev/null 2>&1; then
      detected_user="${SUDO_USER}"
    elif has_cmd logname; then
      detected_user="$(logname 2>/dev/null || true)"
      if [[ "${detected_user}" == "root" ]]; then
        detected_user=""
      fi
    fi

    if [[ -z "${detected_user}" && -n "${USER:-}" && "${USER}" != "root" ]] && id -u "${USER}" >/dev/null 2>&1; then
      detected_user="${USER}"
    fi
    if [[ -z "${detected_user}" ]] && has_cmd stat; then
      detected_user="$(stat -c '%U' "${SCRIPT_DIR}" 2>/dev/null || true)"
      if [[ -z "${detected_user}" || "${detected_user}" == "root" ]] || ! id -u "${detected_user}" >/dev/null 2>&1; then
        detected_user=""
      fi
    fi
    if [[ -z "${detected_user}" ]] && id -u spabam >/dev/null 2>&1; then
      detected_user="spabam"
    fi
    if [[ -z "${detected_user}" ]]; then
      detected_user="root"
    fi
  fi

  if has_cmd getent; then
    detected_home="$(getent passwd "${detected_user}" | cut -d: -f6)"
  fi
  if [[ -z "${detected_home}" && "${detected_user}" == "root" ]]; then
    detected_home="/root"
  elif [[ -z "${detected_home}" ]]; then
    detected_home="${HOME:-/home/${detected_user}}"
  fi

  INSTALL_USER="${detected_user}"
  INSTALL_HOME="${detected_home}"
}

# Run command as resolved install user while preserving required PATH/HOME.
run_as_install_user() {
  local user_path="${BIN_DIR}:${PATH}"
  if [[ -n "${USER_GEM_BIN}" ]]; then
    user_path="${BIN_DIR}:${USER_GEM_BIN}:${PATH}"
  fi

  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    if has_cmd sudo; then
      sudo -H -u "${INSTALL_USER}" env "HOME=${INSTALL_HOME}" "PATH=${user_path}" "$@"
    elif has_cmd runuser; then
      HOME="${INSTALL_HOME}" PATH="${user_path}" runuser -u "${INSTALL_USER}" -- "$@"
    else
      return 1
    fi
  else
    HOME="${INSTALL_HOME}" PATH="${user_path}" "$@"
  fi
}

# Execute a command as install user with logging.
run_user_cmd() {
  local preview

  preview="$(command_preview "$@")"
  run_logged_command \
    "RUN(user:${INSTALL_USER}): ${preview}" \
    "user:${INSTALL_USER} ${preview}" \
    run_as_install_user "$@"
}

# Execute git as install user with interactive prompts disabled.
run_git_user_cmd() {
  local preview

  preview="$(command_preview "git $*")"
  run_logged_command \
    "RUN(user:${INSTALL_USER}): ${preview}" \
    "user:${INSTALL_USER} ${preview}" \
    run_as_install_user env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git "$@"
}

# Execute a shell script as install user (used for multiline compatibility patches).
run_user_shell() {
  local cmd="$1"
  local preview=""

  if [[ "${cmd}" == *$'\n'* ]]; then
    preview="bash -lc <multiline-script omitted>"
  else
    preview="bash -lc $(command_preview "${cmd}")"
  fi
  run_logged_command \
    "RUN(user:${INSTALL_USER}): ${preview}" \
    "user:${INSTALL_USER} ${preview}" \
    run_as_install_user bash -lc "${cmd}"
}

capture_user_cmd() {
  run_as_install_user "$@"
}

# Run command with privilege escalation only when needed.
run_privileged() {
  if [[ "${EUID}" -eq 0 ]]; then
    run_cmd "$@"
  elif has_cmd sudo; then
    if ! sudo -v; then
      return 1
    fi
    run_cmd sudo "$@"
  else
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Dependency/runtime helpers
# -----------------------------------------------------------------------------

apt_install_packages() {
  local reason="$1"
  shift
  local -a pkgs=( "$@" )

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  if ! has_cmd apt-get; then
    warn "${reason}: apt-get not available; cannot auto-install packages: ${pkgs[*]}"
    return 1
  fi
  if [[ "$APT_UPDATED" -ne 1 ]]; then
    if ! run_privileged apt-get update; then
      warn "${reason}: apt-get update failed (need sudo/root)"
      return 1
    fi
    APT_UPDATED=1
  fi
  if ! run_privileged apt-get install -y "${pkgs[@]}"; then
    warn "${reason}: apt-get install failed for packages: ${pkgs[*]}"
    return 1
  fi
}

has_user_cmd() {
  local cmd="$1"
  run_as_install_user bash -lc "command -v '${cmd}' >/dev/null 2>&1"
}

resolve_user_cmd_path() {
  local cmd="$1"
  run_as_install_user bash -lc "command -v '${cmd}' 2>/dev/null || true"
}

refresh_user_gem_bin() {
  local gem_user_dir=""

  USER_GEM_BIN=""
  if has_user_cmd ruby; then
    gem_user_dir="$(capture_user_cmd ruby -r rubygems -e 'puts Gem.user_dir' 2>/dev/null || true)"
    if [[ -n "${gem_user_dir}" ]]; then
      USER_GEM_BIN="${gem_user_dir}/bin"
    fi
  fi
}

# Ensure Ruby + gem toolchain is available for Ruby-based scanners.
ensure_ruby_runtime() {
  if has_user_cmd ruby && has_user_cmd gem; then
    refresh_user_gem_bin
    return 0
  fi
  if ! apt_install_packages "Ruby runtime" ruby ruby-dev build-essential; then
    return 1
  fi
  if ! has_user_cmd ruby || ! has_user_cmd gem; then
    warn "Ruby runtime is unavailable after installation attempt"
    return 1
  fi
  refresh_user_gem_bin
  return 0
}

# Ensure Perl runtime is available for perl-based scanners.
ensure_perl_runtime() {
  if has_cmd perl; then
    return 0
  fi
  if ! apt_install_packages "Perl runtime" perl; then
    return 1
  fi
  if ! has_cmd perl; then
    warn "Perl runtime is unavailable after installation attempt"
    return 1
  fi
}

# Validate sudo auth once when --system-deps is requested by non-root user.
ensure_sudo_access() {
  if [[ "$INSTALL_SYSTEM_DEPS" -ne 1 || "${EUID}" -eq 0 ]]; then
    return 0
  fi
  if ! has_cmd sudo; then
    mark_failed "System dependencies" "sudo is required for --system-deps"
    return 1
  fi
  log "Root access is required for apt packages. Please enter your sudo password."
  if ! sudo -v; then
    mark_failed "System dependencies" "sudo authentication failed"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Filesystem/repository/wrapper helpers
# -----------------------------------------------------------------------------

# Ensure working directories and log file exist with proper ownership.
ensure_dirs() {
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    if ! run_as_install_user mkdir -p "$(dirname "$LOG_FILE")"; then
      mkdir -p "$(dirname "$LOG_FILE")"
      chown -R "${INSTALL_USER}:${INSTALL_USER}" "$(dirname "$LOG_FILE")" || true
    fi
    if ! run_as_install_user mkdir -p "$TOOLS_DIR" "$VENV_DIR" "$BIN_DIR"; then
      mkdir -p "$TOOLS_DIR" "$VENV_DIR" "$BIN_DIR"
      chown -R "${INSTALL_USER}:${INSTALL_USER}" "$TOOLS_DIR" "$VENV_DIR" "$BIN_DIR" || true
    fi
    run_as_install_user touch "$LOG_FILE" || touch "$LOG_FILE"
    run_as_install_user truncate -s 0 "$LOG_FILE" || : >"$LOG_FILE"
    chown "${INSTALL_USER}:${INSTALL_USER}" "$LOG_FILE" || true
  else
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$TOOLS_DIR" "$VENV_DIR" "$BIN_DIR"
    : >"$LOG_FILE"
  fi
}

# Create an executable shim in ./bin that normalizes invocation details.
create_wrapper() {
  local name="$1"
  local body="$2"
  cat >"${BIN_DIR}/${name}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
${body}
EOF
  chmod +x "${BIN_DIR}/${name}"
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    chown "${INSTALL_USER}:${INSTALL_USER}" "${BIN_DIR}/${name}" || true
  fi
}

# Clone tool repo or update existing checkout.
repo_clone_or_update() {
  local repo_url="$1"
  local repo_dir="$2"

  if [[ -d "${repo_dir}/.git" ]]; then
    if [[ "$UPDATE_EXISTING" -eq 1 ]]; then
      run_git_user_cmd -C "$repo_dir" pull --ff-only
    else
      log "INFO: Using existing checkout ${repo_dir}"
    fi
  else
    if [[ -d "${repo_dir}" ]]; then
      run_user_cmd rm -rf "$repo_dir"
    fi
    run_git_user_cmd clone --depth 1 "$repo_url" "$repo_dir"
  fi
}

repo_is_reachable() {
  local repo_url="$1"
  capture_user_cmd env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git ls-remote --heads "$repo_url" >/dev/null 2>&1
}

# Try primary repository first, then fallback URL if unavailable.
repo_clone_with_fallback() {
  local tool_name="$1"
  local primary_url="$2"
  local fallback_url="$3"
  local repo_dir="$4"

  if repo_is_reachable "$primary_url" && repo_clone_or_update "$primary_url" "$repo_dir"; then
    return 0
  fi
  if repo_is_reachable "$fallback_url" && repo_clone_or_update "$fallback_url" "$repo_dir"; then
    log "INFO: Using ${tool_name} fallback repository: ${fallback_url}"
    return 0
  fi
  return 1
}

# -----------------------------------------------------------------------------
# Phase orchestration and Python compatibility helpers
# -----------------------------------------------------------------------------

# Run named phase and record timing/result in PHASE_RESULTS.
run_phase() {
  local name="$1"
  shift
  local start_ts
  local end_ts
  local elapsed
  local rc=0

  log "==================== PHASE START: ${name} ===================="
  start_ts="$(date +%s)"

  set +e
  "$@"
  rc=$?
  set -e

  end_ts="$(date +%s)"
  elapsed=$((end_ts - start_ts))

  if [[ "$rc" -eq 0 ]]; then
    PHASE_RESULTS+=("${name}: ok (${elapsed}s)")
    log "==================== PHASE OK: ${name} (${elapsed}s) ===================="
  else
    PHASE_RESULTS+=("${name}: fail (rc=${rc}, ${elapsed}s)")
    log "==================== PHASE FAIL: ${name} (rc=${rc}, ${elapsed}s) ===================="
  fi

  return "$rc"
}

# Inject minimal shims for removed stdlib modules used by legacy tools on Python 3.12+.
ensure_py312_compat_shims() {
  local venv="$1"

  if capture_user_cmd "${venv}/bin/python" - <<'PY' >/dev/null 2>&1
import importlib.util, sys
missing = []
for mod in ("imp", "distutils.util"):
    if importlib.util.find_spec(mod) is None:
        missing.append(mod)
raise SystemExit(1 if missing else 0)
PY
  then
    return 0
  fi

  run_user_cmd "${venv}/bin/python" - <<'PY'
import sysconfig
from pathlib import Path

site = Path(sysconfig.get_paths()["purelib"])

imp_code = '''"""Compatibility shim for removed stdlib imp module on Python 3.12+."""
from __future__ import annotations

import importlib
import importlib.machinery
import importlib.util
import os
import sys
from types import ModuleType

PY_SOURCE = 1
PY_COMPILED = 2
C_EXTENSION = 3
PKG_DIRECTORY = 5
C_BUILTIN = 6
PY_FROZEN = 7

def reload(module: ModuleType) -> ModuleType:
    return importlib.reload(module)

def find_module(name, path=None):
    spec = importlib.machinery.PathFinder.find_spec(name, path)
    if spec is None:
        raise ImportError(f"No module named {name!r}")
    origin = spec.origin
    if origin in (None, "built-in"):
        return None, name, ("", "", C_BUILTIN)
    if origin == "frozen":
        return None, name, ("", "", PY_FROZEN)
    suffix = os.path.splitext(origin)[1]
    mode = "rb"
    mtype = PY_SOURCE
    if suffix == ".py":
        mode = "r"
        mtype = PY_SOURCE
    elif suffix in (".pyc", ".pyo"):
        mode = "rb"
        mtype = PY_COMPILED
    elif suffix in (".so", ".pyd", ".dll", ".dylib"):
        mode = "rb"
        mtype = C_EXTENSION
    f = open(origin, mode)
    return f, origin, (suffix, mode, mtype)

def load_module(name, file=None, pathname=None, description=None):
    if name in sys.modules:
        return sys.modules[name]
    spec = None
    if pathname and pathname not in ("built-in", "frozen"):
        if os.path.isdir(pathname):
            spec = importlib.util.spec_from_file_location(name, os.path.join(pathname, "__init__.py"))
        else:
            spec = importlib.util.spec_from_file_location(name, pathname)
    if spec is None:
        return importlib.import_module(name)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    if file and not getattr(file, "closed", True):
        file.close()
    return module
'''

distutils_util_code = '''"""Compatibility subset of distutils.util for Python 3.12+."""
def strtobool(val):
    val = str(val).lower()
    if val in ("y", "yes", "t", "true", "on", "1"):
        return 1
    if val in ("n", "no", "f", "false", "off", "0"):
        return 0
    raise ValueError(f"invalid truth value {val!r}")
'''

imp_file = site / "imp.py"
if not imp_file.exists():
    imp_file.write_text(imp_code, encoding="utf-8")

distutils_dir = site / "distutils"
distutils_dir.mkdir(exist_ok=True)
init_file = distutils_dir / "__init__.py"
if not init_file.exists():
    init_file.write_text("", encoding="utf-8")
util_file = distutils_dir / "util.py"
if not util_file.exists():
    util_file.write_text(distutils_util_code, encoding="utf-8")
PY
}

# Build/update a dedicated tool venv and keep pip current.
create_or_update_venv() {
  local venv_path="$1"
  local py_bin="$2"
  if [[ ! -x "${venv_path}/bin/python" ]]; then
    run_user_cmd "$py_bin" -m venv "$venv_path"
  fi
  cleanup_venv_artifacts "$venv_path"
  run_user_cmd "${venv_path}/bin/pip" install --upgrade pip
  cleanup_venv_artifacts "$venv_path"
}

# Remove stale/partial temp distributions that can break repeat installs.
cleanup_venv_artifacts() {
  local venv_path="$1"
  local leftovers=""

  run_user_cmd "${venv_path}/bin/python" - <<'PY'
import shutil
import sysconfig
from pathlib import Path

site = Path(sysconfig.get_paths()["purelib"])
for path in site.glob("~*"):
    if path.is_dir():
        shutil.rmtree(path, ignore_errors=True)
    else:
        path.unlink(missing_ok=True)
PY

  leftovers="$(capture_user_cmd "${venv_path}/bin/python" - <<'PY'
import sysconfig
from pathlib import Path

site = Path(sysconfig.get_paths()["purelib"])
for path in site.glob("~*"):
    print(path)
PY
)"

  if [[ -n "${leftovers}" ]]; then
    log "INFO: Removing stale root-owned temp distributions from ${venv_path}"
    while IFS= read -r stale; do
      [[ -z "$stale" ]] && continue
      run_privileged rm -rf "$stale" || true
    done <<<"$leftovers"
  fi
}

# Run a smoke test command if smoke tests are enabled.
tool_smoke_test() {
  local tool_name="$1"
  shift

  if [[ "$RUN_SMOKE_TESTS" -eq 0 ]]; then
    return 0
  fi

  if run_user_cmd "$@"; then
    return 0
  fi

  warn "${tool_name} smoke test failed: $*"
  return 1
}

# Refresh PATH so wrappers and user gem binaries are visible during this run.
prepare_env() {
  # Make wrappers and user gem bin visible in this run and future shells.
  refresh_user_gem_bin
  if [[ -n "${USER_GEM_BIN}" ]]; then
    export PATH="${BIN_DIR}:${USER_GEM_BIN}:${BASE_PATH}"
  else
    export PATH="${BIN_DIR}:${BASE_PATH}"
  fi
}

install_system_dependencies() {
  if [[ "$INSTALL_SYSTEM_DEPS" -ne 1 ]]; then
    return 0
  fi

  log "Installing system dependencies via apt..."
  if ! run_privileged apt-get update; then
    mark_failed "System dependencies" "apt-get update failed (need sudo/root)"
    return 1
  fi
  APT_UPDATED=1

  if ! run_privileged apt-get install -y \
    git curl perl ruby ruby-dev build-essential \
    python3 python3-pip python3-venv \
    libxml2-dev libxslt1-dev zlib1g-dev liblzma-dev libcurl4-openssl-dev \
    nmap; then
    mark_failed "System dependencies" "core apt packages failed"
    return 1
  fi

  # Optional legacy runtimes used by a few tools.
  run_privileged apt-get install -y python2 || log "INFO: python2 could not be installed (WPForce will use python3 compatibility mode)"
  run_privileged apt-get install -y python3.11 python3.11-venv || log "INFO: python3.11 package is unavailable; applying droopescan python3.12+ compatibility shims"
}

# -----------------------------------------------------------------------------
# Tool installers (one function per integrated scanner/tool)
# -----------------------------------------------------------------------------

# WordPress scanner (system package or gem install fallback).
install_wpscan() {
  local name="WPScan"
  local wpscan_path=""
  local gem_user_dir=""

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby/gem runtime unavailable"
    return 0
  fi

  if ! has_cmd wpscan && ! has_user_cmd wpscan; then
    apt_install_packages "$name" wpscan || warn "apt install wpscan failed; trying gem install"
  fi

  if ! has_cmd wpscan && ! has_user_cmd wpscan; then
    if ! run_user_cmd gem install --user-install wpscan; then
      mark_failed "$name" "gem install failed"
      return 0
    fi
    prepare_env
  fi

  wpscan_path="$(resolve_user_cmd_path wpscan || true)"
  if [[ -z "${wpscan_path}" && -n "${USER_GEM_BIN}" && -x "${USER_GEM_BIN}/wpscan" ]]; then
    wpscan_path="${USER_GEM_BIN}/wpscan"
  fi
  if [[ -n "${USER_GEM_BIN}" ]]; then
    gem_user_dir="${USER_GEM_BIN%/bin}"
  fi
  if [[ -z "${gem_user_dir}" ]]; then
    gem_user_dir="${INSTALL_HOME}/.local/share/gem/ruby/3.3.0"
  fi

  cat >"${BIN_DIR}/wpscan" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="\$(readlink -f "\${BASH_SOURCE[0]}" 2>/dev/null || echo "\${BASH_SOURCE[0]}")"
GEM_HOME_DIR="${gem_user_dir}"
WPSCAN_HOME="${INSTALL_HOME}/.wpscan"
DEFAULT_CACHE_DIR="\${WPSCAN_HOME}/cache"
DEFAULT_COOKIE_JAR="\${WPSCAN_HOME}/cookie_jar.txt"

mkdir -p "\${DEFAULT_CACHE_DIR}" >/dev/null 2>&1 || true
mkdir -p "\$(dirname "\${DEFAULT_COOKIE_JAR}")" >/dev/null 2>&1 || true
touch "\${DEFAULT_COOKIE_JAR}" >/dev/null 2>&1 || true

HAS_CACHE_DIR=0
HAS_COOKIE_JAR=0
for arg in "\$@"; do
  if [[ "\${arg}" == "--cache-dir" ]]; then
    HAS_CACHE_DIR=1
  elif [[ "\${arg}" == "--cookie-jar" ]]; then
    HAS_COOKIE_JAR=1
  fi
done

declare -a WPSCAN_EXTRA_ARGS=()
if [[ "\${HAS_CACHE_DIR}" -eq 0 ]]; then
  WPSCAN_EXTRA_ARGS+=(--cache-dir "\${WPSCAN_CACHE_DIR:-\${DEFAULT_CACHE_DIR}}")
fi
if [[ "\${HAS_COOKIE_JAR}" -eq 0 ]]; then
  WPSCAN_EXTRA_ARGS+=(--cookie-jar "\${WPSCAN_COOKIE_JAR:-\${DEFAULT_COOKIE_JAR}}")
fi

for candidate in \\
  "${USER_GEM_BIN:-${INSTALL_HOME}/.local/share/gem/ruby/3.3.0/bin}"/wpscan \\
  "${INSTALL_HOME}"/.local/share/gem/ruby/*/bin/wpscan \\
  /usr/local/bin/wpscan \\
  /usr/bin/wpscan; do
  if [[ -x "\${candidate}" ]]; then
    if [[ "\$(readlink -f "\${candidate}" 2>/dev/null || echo "\${candidate}")" == "\${SCRIPT_PATH}" ]]; then
      continue
    fi
    RUNTIME_GEM_HOME="\${GEM_HOME_DIR}"
    if [[ "\${candidate}" == "${INSTALL_HOME}"/.local/share/gem/ruby/*/bin/wpscan ]]; then
      RUNTIME_GEM_HOME="\$(dirname "\$(dirname "\${candidate}")")"
    fi
    exec env HOME="${INSTALL_HOME}" GEM_HOME="\${RUNTIME_GEM_HOME}" GEM_PATH="\${RUNTIME_GEM_HOME}:\${GEM_PATH:-}" "\${candidate}" "\${WPSCAN_EXTRA_ARGS[@]}" "\$@"
  fi
done

echo "wpscan executable not found in gem or system paths" >&2
exit 127
EOF
  chmod +x "${BIN_DIR}/wpscan"
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    chown "${INSTALL_USER}:${INSTALL_USER}" "${BIN_DIR}/wpscan" || true
  fi

  if ! has_cmd wpscan && [[ ! -x "${BIN_DIR}/wpscan" ]]; then
    mark_failed "$name" "command not found after installation attempts"
    return 0
  fi

  if ! run_user_cmd mkdir -p "${INSTALL_HOME}/.wpscan/db" "${INSTALL_HOME}/.wpscan/cache"; then
    warn "${name}: unable to create ${INSTALL_HOME}/.wpscan cache/db directories"
  fi
  if ! run_user_cmd touch "${INSTALL_HOME}/.wpscan/cookie_jar.txt"; then
    warn "${name}: unable to initialize ${INSTALL_HOME}/.wpscan/cookie_jar.txt"
  fi
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    chown -R "${INSTALL_USER}:${INSTALL_USER}" "${INSTALL_HOME}/.wpscan" >/dev/null 2>&1 || true
  fi

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    if ! run_user_cmd wpscan --version; then
        mark_failed "$name" "smoke test failed (wpscan --version)"
        return 0
      fi
    fi

  # Prime/update local WPScan database so scans don't abort on first run.
  if has_cmd timeout; then
    if ! run_user_cmd timeout --signal=INT --kill-after=10s 300 wpscan --update; then
      warn "WPScan database update failed; scans may require a manual 'wpscan --update'"
    fi
  else
    if ! run_user_cmd wpscan --update; then
      warn "WPScan database update failed; scans may require a manual 'wpscan --update'"
    fi
  fi

  mark_installed "$name"
}

# CMSmap source install + runtime patching for exploitdb/bootstrap behavior.
install_cmsmap() {
  local name="CMSmap"
  local repo="${TOOLS_DIR}/CMSmap"
  local venv="${VENV_DIR}/cmsmap"
  local cmsmap_conf=""
  local cmsmap_pkg_dir=""
  local edb_dir="${INSTALL_HOME}/.local/share/exploitdb"

  if ! repo_clone_or_update https://github.com/Dionach/CMSmap.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install "${repo}"; then
    mark_failed "$name" "pip install . failed"
    return 0
  fi

  cmsmap_conf="$(capture_user_cmd bash -lc "ls -1 \"${venv}\"/lib/python*/site-packages/cmsmap/cmsmap.conf 2>/dev/null | head -n 1" || true)"
  if [[ -n "$cmsmap_conf" ]]; then
    cmsmap_pkg_dir="$(dirname "$cmsmap_conf")"
    if ! run_user_cmd mkdir -p "${edb_dir}"; then
      warn "${name}: unable to create local exploitdb directory ${edb_dir}"
    fi
    if ! run_user_shell "sed -i -E 's|^edbtype\\s*=.*|edbtype = apt|; s|^edbpath\\s*=.*|edbpath = ${edb_dir}/|' '${cmsmap_conf}'"; then
      warn "${name}: failed to patch cmsmap.conf exploitdb path"
    fi
    # Prevent runtime attempts to clone multiple large CMS repos when these
    # helper files are missing; CMSmap only checks for existence.
    if ! run_user_shell "for rel in data/wp_plugins_small.txt data/joo_plugins_small.txt data/dru_plugins_small.txt data/wp_versions.txt data/joo_versions.txt data/dru_versions.txt data/moo_versions.txt data/wp_defaultfiles.txt data/wp_defaultfolders.txt data/joo_defaultfiles.txt data/joo_defaultfolders.txt data/dru_defaultfiles.txt data/dru_defaultfolders.txt data/moo_defaultfiles.txt data/moo_defaultfolders.txt; do f='${cmsmap_pkg_dir}/'\$rel; if [[ ! -f \"\$f\" ]]; then mkdir -p \"\$(dirname \"\$f\")\"; : > \"\$f\"; fi; done"; then
      warn "${name}: failed to create CMSmap bootstrap data files"
    fi
    if ! run_user_shell "python3 - <<'PY'
from pathlib import Path

main_py = Path('${cmsmap_pkg_dir}/main.py')
if main_py.exists():
    text = main_py.read_text(encoding='utf-8')
    text = text.replace(
        '    updater.UpdateExploitDB()\\n    updater.CheckLocalFiles()\\n',
        '    if not initializer.NoExploitdb:\\n        updater.UpdateExploitDB()\\n    updater.CheckLocalFiles()\\n',
    )
    main_py.write_text(text, encoding='utf-8')
PY"; then
      warn "${name}: failed to patch noedb runtime path in cmsmap main.py"
    fi
    if ! run_user_shell "python3 - <<'PY'
from pathlib import Path

requester_py = Path('${cmsmap_pkg_dir}/lib/requester.py')
if requester_py.exists():
    text = requester_py.read_text(encoding='utf-8')
    old = \"\"\"        except urllib.request.HTTPError as e:
            # Does not return  200
            self.response = e
            self.htmltext = e.read().decode('utf-8', 'ignore')
            self.status_code = e.code
\"\"\"
    new = old + \"\"\"        except Exception:
            self.response = None
            self.htmltext = ''
            self.status_code = 0
\"\"\"
    text = text.replace(old, new)
    requester_py.write_text(text, encoding='utf-8')

genericchecks_py = Path('${cmsmap_pkg_dir}/lib/genericchecks.py')
if genericchecks_py.exists():
    text = genericchecks_py.read_text(encoding='utf-8')
    guard = \"\"\"        if requester.response is None or requester.status_code in (None, 0):
            report.status(\"Unable to retrieve headers from target (connection reset/timeout)\")
            return
\"\"\"
    marker = \"\"\"        requester.request(self.url, data=None)
        msg = \\\"Checking headers ...\\\"
\"\"\"
    if guard not in text and marker in text:
        text = text.replace(
            marker,
            \"\"\"        requester.request(self.url, data=None)
        if requester.response is None or requester.status_code in (None, 0):
            report.status(\\\"Unable to retrieve headers from target (connection reset/timeout)\\\")
            return
        msg = \\\"Checking headers ...\\\"
\"\"\",
        )
        genericchecks_py.write_text(text, encoding='utf-8')
PY"; then
      warn "${name}: failed to patch resilient network error handling in cmsmap"
    fi
  else
    warn "${name}: could not locate cmsmap.conf for exploitdb path patching"
  fi

  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    chown -R "${INSTALL_USER}:${INSTALL_USER}" "${venv}" >/dev/null 2>&1 || true
  fi

  create_wrapper "cmsmap" "exec \"${venv}/bin/cmsmap\" \"\$@\""
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    local out
    out="$(capture_user_cmd "${venv}/bin/cmsmap" -h 2>&1 || true)"
    printf '%s\n' "$out" | tee -a "$LOG_FILE" >/dev/null
    if ! printf '%s' "$out" | grep -qi "CMSmap tool"; then
      mark_failed "$name" "unexpected help output"
      return 0
    fi
  fi
  mark_installed "$name"
}

# CMSeek source install + wrapper.
install_cmseek() {
  local name="CMSeek"
  local repo="${TOOLS_DIR}/CMSeeK"
  local venv="${VENV_DIR}/cmseek"

  if ! repo_clone_or_update https://github.com/Tuhinshubhra/CMSeeK.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  create_wrapper "cmseek" "exec \"${venv}/bin/python\" \"${repo}/cmseek.py\" \"\$@\""
  tool_smoke_test "$name" "${venv}/bin/python" "${repo}/cmseek.py" --help || return 0
  mark_installed "$name"
}

# Droopescan install with Python-version compatibility handling.
install_droopescan() {
  local name="Droopescan"
  local venv="${VENV_DIR}/droopescan"
  local py_bin="python3"
  local smoke_out

  if has_cmd python3.11; then
    py_bin="python3.11"
  elif [[ "$INSTALL_SYSTEM_DEPS" -eq 1 ]]; then
    run_privileged apt-get install -y python3.11 python3.11-venv || true
    if has_cmd python3.11; then
      py_bin="python3.11"
    fi
  fi

  if ! create_or_update_venv "$venv" "$py_bin"; then
    mark_failed "$name" "venv creation failed with ${py_bin}"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install droopescan; then
    mark_failed "$name" "pip install droopescan failed"
    return 0
  fi
  ensure_py312_compat_shims "$venv"

  create_wrapper "droopescan" "exec \"${venv}/bin/droopescan\" \"\$@\""

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    set +e
    smoke_out="$(capture_user_cmd "${venv}/bin/droopescan" --help 2>&1)"
    local rc=$?
    set -e
    printf '%s\n' "$smoke_out" | tee -a "$LOG_FILE" >/dev/null
    if [[ $rc -ne 0 ]]; then
      mark_failed "$name" "Smoke test failed"
      return 0
    fi
  fi

  mark_installed "$name"
}

# Joomla scanner installed from OWASP repo.
install_joomscan() {
  local name="JoomScan"
  local repo="${TOOLS_DIR}/joomscan"
  if ! ensure_perl_runtime; then
    mark_failed "$name" "perl runtime unavailable"
    return 0
  fi
  if ! repo_clone_or_update https://github.com/OWASP/joomscan.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  create_wrapper "joomscan" "cd \"${repo}\" && exec perl \"${repo}/joomscan.pl\" \"\$@\""
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    local out
    out="$(capture_user_cmd bash -lc "cd \"$repo\" && perl \"${repo}/joomscan.pl\" --help" 2>&1 || true)"
    printf '%s\n' "$out" | tee -a "$LOG_FILE" >/dev/null
    if ! printf '%s' "$out" | grep -qi "Usage"; then
      mark_failed "$name" "unexpected help output"
      return 0
    fi
  fi
  mark_installed "$name"
}

# Drupwn source install from staged copy to avoid root-owned build artifacts.
install_drupwn() {
  local name="Drupwn"
  local repo="${TOOLS_DIR}/drupwn"
  local venv="${VENV_DIR}/drupwn-modern"
  local build_src="${VENV_DIR}/_build/drupwn-src"
  local smoke_out

  if ! repo_clone_or_update https://github.com/immunIT/drupwn.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install "setuptools<81"; then
    mark_failed "$name" "setuptools pin failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  # Install from a user-writable build copy to avoid permission issues when
  # repository files were previously created by root.
  if ! run_user_cmd rm -rf "$build_src"; then
    mark_failed "$name" "unable to prepare build staging directory"
    return 0
  fi
  if ! run_user_cmd mkdir -p "$(dirname "$build_src")"; then
    mark_failed "$name" "unable to create build staging root"
    return 0
  fi
  if ! run_user_cmd cp -r "$repo" "$build_src"; then
    mark_failed "$name" "unable to stage source tree"
    return 0
  fi
  if ! run_user_cmd rm -rf "${build_src}/build" "${build_src}/dist"; then
    mark_failed "$name" "unable to clean staged source tree"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install "$build_src"; then
    mark_failed "$name" "pip install from source failed"
    return 0
  fi

  create_wrapper "drupwn" "exec env PYTHONWARNINGS=ignore::SyntaxWarning,ignore::UserWarning \"${venv}/bin/drupwn\" \"\$@\""

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    set +e
    smoke_out="$(capture_user_cmd env PYTHONWARNINGS=ignore::SyntaxWarning,ignore::UserWarning "${venv}/bin/drupwn" --help 2>&1)"
    local rc=$?
    set -e
    printf '%s\n' "$smoke_out" | tee -a "$LOG_FILE" >/dev/null
    if [[ $rc -ne 0 ]]; then
      mark_failed "$name" "Smoke test failed"
      return 0
    fi
  fi

  mark_installed "$name"
}

# vBulletin scanner (Perl).
install_vbscan() {
  local name="VBScan"
  local repo="${TOOLS_DIR}/vbscan"
  if ! ensure_perl_runtime; then
    mark_failed "$name" "perl runtime unavailable"
    return 0
  fi
  if ! repo_clone_or_update https://github.com/OWASP/vbscan.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  create_wrapper "vbscan" "exec perl \"${repo}/vbscan.pl\" \"\$@\""
  mark_installed "$name"
}

# CMSScan server/runtime installation.
install_cmsscan() {
  local name="CMSScan"
  local repo="${TOOLS_DIR}/CMSScan"
  local venv="${VENV_DIR}/cmsscan"
  local py_bin="python3"

  if has_cmd python3.11; then
    py_bin="python3.11"
  fi

  if ! repo_clone_or_update https://github.com/ajinabraham/CMSScan.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! run_git_user_cmd -C "$repo" submodule update --init --recursive; then
    warn "CMSScan submodule update failed; continuing without submodules"
  fi
  if ! create_or_update_venv "$venv" "$py_bin"; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi
  ensure_py312_compat_shims "$venv"

  create_wrapper "cmsscan-server" "exec \"${venv}/bin/python\" \"${repo}/app.py\" \"\$@\""
  create_wrapper "cmsscan-python" "exec \"${venv}/bin/python\" \"\$@\""
  mark_installed "$name"
}

# VulnX installation + detector hardening patch.
install_vulnx() {
  local name="VulnX"
  local repo="${TOOLS_DIR}/vulnx"
  local venv="${VENV_DIR}/vulnx"

  if ! repo_clone_or_update https://github.com/anouarbensaad/vulnx.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  if [[ -f "${repo}/modules/detector.py" ]]; then
    if ! run_user_shell "python3 - <<'PY'
from pathlib import Path

path = Path('${repo}/modules/detector.py')
text = path.read_text(encoding='utf-8')
if 'def _safe_get_text(self, url):' not in text:
    text = text.replace(
        '        self.port = port\\n\\n    \\n',
        '        self.port = port\\n\\n    def _safe_get_text(self, url):\\n        try:\\n            return requests.get(url, headers=self.headers, verify=False, timeout=12).text\\n        except requests.exceptions.RequestException:\\n            return \"\"\\n\\n    \\n',
    )
text = text.replace(
    '        return requests.get(lm_content, headers=self.headers,verify=False).text',
    '        return self._safe_get_text(lm_content)'
)
text = text.replace(
    '        return requests.get(lm2_content, headers=self.headers,verify=False).text',
    '        return self._safe_get_text(lm2_content)'
)
text = text.replace(
    '        return requests.get(self.url, headers=self.headers,verify=False).text',
    '        return self._safe_get_text(self.url)'
)
path.write_text(text, encoding='utf-8')
PY"; then
      warn "${name}: failed to patch safe HTTP fetch handling in detector.py"
    fi
  fi

  create_wrapper "vulnx" "exec \"${venv}/bin/python\" \"${repo}/vulnx.py\" \"\$@\""
  mark_installed "$name"
}

# Clusterd Python2-era code auto-converted and shimmed for Python3 runtime.
install_clusterd() {
  local name="Clusterd"
  local repo="${TOOLS_DIR}/clusterd"
  local venv="${VENV_DIR}/clusterd"
  local build_src="${VENV_DIR}/_build/clusterd-src"
  local py_path=""

  if ! repo_clone_or_update https://github.com/hatRiot/clusterd.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install modernize six; then
    mark_failed "$name" "python3 compatibility tooling install failed"
    return 0
  fi

  if ! run_user_cmd rm -rf "${build_src}"; then
    if ! run_privileged rm -rf "${build_src}"; then
      mark_failed "$name" "unable to reset build staging directory"
      return 0
    fi
    if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
      chown -R "${INSTALL_USER}:${INSTALL_USER}" "${VENV_DIR}" >/dev/null 2>&1 || true
    fi
  fi
  if ! run_user_cmd cp -a "${repo}" "${build_src}"; then
    mark_failed "$name" "unable to stage source for python3 conversion"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/modernize" --no-diffs -w -n -f default -x import -x imports_six -x itertools_imports_six -x urllib_six "${build_src}"; then
    mark_failed "$name" "auto-conversion to python3 failed"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/commands.py\" <<'PY'
import subprocess


def getoutput(cmd):
    return subprocess.getoutput(cmd)
PY"; then
    mark_failed "$name" "unable to apply python3 commands shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/sitecustomize.py\" <<'PY'
import importlib.machinery
import importlib.util
import os
import sys


class _LoaderShim:
    def __init__(self, loader, default_name):
        self._loader = loader
        self._default_name = default_name

    def load_module(self, fullname):
        name = fullname or self._default_name
        if name in sys.modules:
            return sys.modules[name]
        if hasattr(self._loader, 'load_module'):
            return self._loader.load_module(name)
        spec = importlib.util.spec_from_loader(name, self._loader)
        if spec is None:
            raise ImportError(name)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        self._loader.exec_module(module)
        return module


def _find_module(self, fullname, path=None):
    spec = self.find_spec(fullname)
    if spec is not None and spec.loader is not None:
        return _LoaderShim(spec.loader, fullname)

    base_path = getattr(self, 'path', None)
    if base_path:
        module_path = os.path.join(base_path, fullname + '.py')
        if os.path.isfile(module_path):
            loader = importlib.machinery.SourceFileLoader(fullname, module_path)
            return _LoaderShim(loader, fullname)
    return None


if not hasattr(importlib.machinery.FileFinder, 'find_module'):
    importlib.machinery.FileFinder.find_module = _find_module
PY"; then
    mark_failed "$name" "unable to apply module loader compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/HTMLParser.py\" <<'PY'
from html.parser import HTMLParser
PY"; then
    mark_failed "$name" "unable to apply HTMLParser compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/urlparse.py\" <<'PY'
from urllib.parse import *
PY"; then
    mark_failed "$name" "unable to apply urlparse compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/ConfigParser.py\" <<'PY'
from configparser import *
PY"; then
    mark_failed "$name" "unable to apply ConfigParser compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/Queue.py\" <<'PY'
from queue import *
PY"; then
    mark_failed "$name" "unable to apply Queue compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${build_src}/src/core/httplib.py\" <<'PY'
from http.client import *
PY"; then
    mark_failed "$name" "unable to apply httplib compatibility shim"
    return 0
  fi
  if ! run_user_cmd sed -i 's/len(fingerengine\\.fingerprints) is 0/len(fingerengine.fingerprints) == 0/' "${build_src}/clusterd.py"; then
    mark_failed "$name" "unable to patch python3 syntax compatibility in clusterd.py"
    return 0
  fi
  if ! run_user_cmd sed -i 's/timeout is not 10/timeout != 10/; s/timeout is 0/timeout == 0/' "${build_src}/src/module/deploy_utils.py"; then
    mark_failed "$name" "unable to patch python3 syntax compatibility in deploy_utils.py"
    return 0
  fi
  if ! run_user_cmd sed -i "s/re.findall('\\\\d+\\/open',item)/re.findall(r'\\\\d+\\/open', item)/" "${build_src}/src/module/discovery.py"; then
    mark_failed "$name" "unable to patch regex compatibility in discovery.py"
    return 0
  fi
  if ! run_user_cmd env CLUSTERD_BUILD="${build_src}" python3 - <<'PY'
import os
from pathlib import Path

base = Path(os.environ["CLUSTERD_BUILD"])

# Python2 urllib import compatibility in older auxiliaries/deployers.
for rel, old, new in [
    ("src/platform/jboss/auxiliary/verb_tamper.py", "from urllib import quote_plus", "from urllib.parse import quote_plus"),
    ("src/platform/coldfusion/deployers/lfi_stager.py", "from urllib import quote_plus", "from urllib.parse import quote_plus"),
    ("src/platform/railo/deployers/log_injection.py", "from urllib import quote", "from urllib.parse import quote"),
    ("src/platform/jboss/deployers/seam_upload.py", "from urllib import quote_plus", "from urllib.parse import quote_plus"),
]:
    path = base / rel
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")

# Ignore duplicate module flags generated by legacy plugin set to keep argparse stable.
auxengine = base / "src/core/auxengine.py"
if auxengine.exists():
    text = auxengine.read_text(encoding="utf-8", errors="ignore")
    if 'opt = "--%s" % mod.flag' not in text:
        old = """        if 'enable_args' in dir(mod) and mod.enable_args:
            egroup.add_argument("--%s" % mod.flag, action='store', help=SUPPRESS)
        else:
            egroup.add_argument("--%s" % mod.flag, action='store_true', dest=mod.flag,
                            help=SUPPRESS)
"""
        new = """        opt = "--%s" % mod.flag
        if opt in egroup._option_string_actions:
            continue

        if 'enable_args' in dir(mod) and mod.enable_args:
            egroup.add_argument(opt, action='store', help=SUPPRESS)
        else:
            egroup.add_argument(opt, action='store_true', dest=mod.flag,
                            help=SUPPRESS)
"""
        if old in text:
            auxengine.write_text(text.replace(old, new), encoding="utf-8")
PY
  then
    mark_failed "$name" "unable to patch python3 runtime compatibility in converted source"
    return 0
  fi

  py_path="$(capture_user_cmd bash -lc "find \"${build_src}/src\" -type d | paste -sd: -" 2>/dev/null || true)"
  if [[ -z "$py_path" ]]; then
    mark_failed "$name" "unable to assemble runtime PYTHONPATH"
    return 0
  fi

  create_wrapper "clusterd" "cd \"${build_src}\" && exec env PYTHONWARNINGS=ignore::SyntaxWarning PYTHONPATH=\"${py_path}:\${PYTHONPATH:-}\" \"${venv}/bin/python\" \"${build_src}/clusterd.py\" \"\$@\""
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    if ! run_user_shell "cd \"$build_src\" && env PYTHONWARNINGS=ignore::SyntaxWarning PYTHONPATH=\"${py_path}:\${PYTHONPATH:-}\" \"${venv}/bin/python\" \"${build_src}/clusterd.py\" --help"; then
      mark_skipped "$name" "runtime compatibility issues on current platform"
      return 0
    fi
  fi
  mark_installed "$name"
}

# WPSeku source install.
install_wpseku() {
  local name="WPSeku"
  local repo="${TOOLS_DIR}/WPSeku"
  local venv="${VENV_DIR}/wpseku"

  if ! repo_clone_or_update https://github.com/andripwn/WPSeku.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  create_wrapper "wpseku" "exec \"${venv}/bin/python\" \"${repo}/wpseku.py\" \"\$@\""
  mark_installed "$name"
}

# WPXF gem install + wrapper.
install_wpxf() {
  local name="WPXF"
  local wpxf_path=""
  local gem_user_dir=""

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby/gem runtime unavailable"
    return 0
  fi
  if ! run_user_cmd gem install --user-install wpxf; then
    mark_failed "$name" "gem install failed"
    return 0
  fi

  prepare_env
  wpxf_path="$(resolve_user_cmd_path wpxf || true)"
  if [[ -z "${wpxf_path}" && -n "${USER_GEM_BIN}" && -x "${USER_GEM_BIN}/wpxf" ]]; then
    wpxf_path="${USER_GEM_BIN}/wpxf"
  fi
  if [[ -n "${USER_GEM_BIN}" ]]; then
    gem_user_dir="${USER_GEM_BIN%/bin}"
  fi
  if [[ -n "${wpxf_path}" && "${wpxf_path}" != "${BIN_DIR}/wpxf" ]]; then
    if [[ -n "${gem_user_dir}" && "${wpxf_path}" == "${USER_GEM_BIN}/"* ]]; then
      create_wrapper "wpxf" "exec env HOME=\"${INSTALL_HOME}\" GEM_HOME=\"${gem_user_dir}\" GEM_PATH=\"${gem_user_dir}:\${GEM_PATH:-}\" \"${wpxf_path}\" \"\$@\""
    else
      create_wrapper "wpxf" "exec \"${wpxf_path}\" \"\$@\""
    fi
  fi

  if has_cmd wpxf || [[ -x "${BIN_DIR}/wpxf" ]]; then
    mark_installed "$name"
  else
    mark_failed "$name" "command not found after gem install"
  fi
}

# WPForce install (native python2 path or auto-converted python3 compatibility path).
install_wpforce() {
  local name="WPForce"
  local repo="${TOOLS_DIR}/WPForce"
  local venv="${VENV_DIR}/wpforce"
  local compat_script="${venv}/wpforce.py"
  if ! repo_clone_or_update https://github.com/n00py/WPForce.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi

  # Prefer legacy python2 path when available; otherwise auto-convert to python3.
  if has_cmd python2; then
    if ! run_user_cmd python2 -m pip install --user requests; then
      mark_failed "$name" "python2 requests installation failed"
      return 0
    fi
    create_wrapper "wpforce" "exec python2 \"${repo}/wpforce.py\" \"\$@\""
    mark_installed "$name"
    return 0
  fi

  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install --upgrade pip modernize six; then
    mark_failed "$name" "python3 compatibility tooling install failed"
    return 0
  fi
  if ! run_user_cmd cp "${repo}/wpforce.py" "$compat_script"; then
    mark_failed "$name" "unable to stage wpforce.py for conversion"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/modernize" --no-diffs -w -n -f default "$compat_script"; then
    mark_failed "$name" "auto-conversion to python3 failed"
    return 0
  fi
  if ! run_user_cmd env COMPAT_SCRIPT="${compat_script}" "${venv}/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["COMPAT_SCRIPT"])
text = path.read_text(encoding="utf-8", errors="ignore")

# Python3 integer division compatibility.
text = text.replace("slice_size = input_size / size", "slice_size = input_size // size")

# urllib.request expects bytes payload in Python3.
text = text.replace(
    "req = six.moves.urllib.request.Request(url, post, headers)",
    "req = six.moves.urllib.request.Request(url, post.encode('utf-8'), headers)"
)

path.write_text(text, encoding="utf-8")
PY
  then
    mark_failed "$name" "unable to apply python3 runtime compatibility patch"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install requests six; then
    mark_failed "$name" "python3 runtime dependencies install failed"
    return 0
  fi

  create_wrapper "wpforce" "exec env PYTHONWARNINGS=ignore::SyntaxWarning \"${venv}/bin/python\" \"${compat_script}\" \"\$@\""
  tool_smoke_test "$name" env PYTHONWARNINGS=ignore::SyntaxWarning "${venv}/bin/python" "$compat_script" -h || return 0
  mark_installed "$name"
}

# JoomlaVS install with direct gem deps on modern Ruby.
install_joomlavs() {
  local name="joomlavs"
  local repo="${TOOLS_DIR}/joomlavs"

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby runtime unavailable"
    return 0
  fi
  if ! repo_clone_or_update https://github.com/rastating/joomlavs.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! run_user_cmd gem install --user-install slop typhoeus; then
    mark_failed "$name" "required gems installation failed"
    return 0
  fi

  create_wrapper "joomlavs" "cd \"${repo}\" && exec ruby joomlavs.rb \"\$@\""
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    if ! run_user_shell "cd \"$repo\" && ruby joomlavs.rb >/dev/null"; then
      mark_failed "$name" "smoke test failed"
      return 0
    fi
  fi
  mark_installed "$name"
}

# Fingerprinter install with fallback repo and runtime compatibility patches.
install_fingerprinter() {
  local name="Fingerprinter"
  local repo="${TOOLS_DIR}/fingerprinter"
  local primary_url="https://github.com/pentesterlab/fingerprinter.git"
  local fallback_url="https://github.com/erwanlr/Fingerprinter.git"
  local gem_user_dir=""

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby runtime unavailable"
    return 0
  fi
  if ! run_user_cmd gem install --user-install cms_scanner -v 0.13.9; then
    mark_failed "$name" "required gem cms_scanner (0.13.9) installation failed"
    return 0
  fi
  if ! run_user_cmd gem install --user-install dearchiver; then
    mark_failed "$name" "required gem dearchiver installation failed"
    return 0
  fi
  if [[ -n "${USER_GEM_BIN}" ]]; then
    gem_user_dir="${USER_GEM_BIN%/bin}"
  fi
  if ! repo_clone_with_fallback "$name" "$primary_url" "$fallback_url" "$repo"; then
    mark_skipped "$name" "no reachable public repository found (tried ${primary_url} and ${fallback_url})"
    return 0
  fi

  if [[ -f "${repo}/Gemfile" ]]; then
    if ! run_user_shell "sed -i -E \"s/gem 'cms_scanner', '~> 0\\.13'/gem 'cms_scanner', '~> 0.13.0'/\" \"${repo}/Gemfile\""; then
      warn "${name}: unable to pin Gemfile cms_scanner compatibility constraint"
    fi
  fi

  if [[ -f "${repo}/lib/fingerprinter/actions.rb" ]]; then
    if ! run_user_cmd env FINGERPRINTER_ACTIONS="${repo}/lib/fingerprinter/actions.rb" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["FINGERPRINTER_ACTIONS"])
text = path.read_text(encoding="utf-8", errors="ignore")

if "target.respond_to?(:in_scope_uris)" not in text:
    old = "    urls              = target.in_scope_urls(Typhoeus.get(target.url, request_options.merge(followlocation: true)))\n"
    new = (
        "    response          = Typhoeus.get(target.url, request_options.merge(followlocation: true))\n"
        "    urls              = if target.respond_to?(:in_scope_urls)\n"
        "                          target.in_scope_urls(response)\n"
        "                        elsif target.respond_to?(:in_scope_uris)\n"
        "                          target.in_scope_uris(response).map(&:to_s)\n"
        "                        else\n"
        "                          []\n"
        "                        end\n"
    )
    if old in text:
        text = text.replace(old, new)
        path.write_text(text, encoding="utf-8")
PY
    then
      warn "${name}: failed to patch Fingerprinter CMSScanner target compatibility"
    fi
  else
    warn "${name}: actions.rb not found after checkout"
  fi

  if [[ -n "${gem_user_dir}" ]]; then
    create_wrapper "fingerprinter" "cd \"${repo}\" && exec env HOME=\"${INSTALL_HOME}\" GEM_HOME=\"${gem_user_dir}\" GEM_PATH=\"${gem_user_dir}:\${GEM_PATH:-}\" RUBYOPT=\"-W0 -W:no-deprecated\" ruby \"${repo}/fingerprinter.rb\" \"\$@\""
  else
    create_wrapper "fingerprinter" "cd \"${repo}\" && exec env RUBYOPT=\"-W0 -W:no-deprecated\" ruby \"${repo}/fingerprinter.rb\" \"\$@\""
  fi
  mark_installed "$name"
}

# AutoWPScan install with optional-token patching and safer parsing behavior.
install_autowpscan() {
  local name="AutoWPScan"
  local repo="${TOOLS_DIR}/AutoWPScan"
  local primary_url="https://github.com/ethicalhack3r/AutoWPScan.git"
  local fallback_url="https://github.com/password123456/autowpscan.git"

  if ! repo_clone_with_fallback "$name" "$primary_url" "$fallback_url" "$repo"; then
    mark_skipped "$name" "no reachable public repository found (tried ${primary_url} and ${fallback_url})"
    return 0
  fi

  if [[ -f "${repo}/main.py" ]]; then
    if ! run_user_cmd env AUTOWPSCAN_MAIN="${repo}/main.py" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["AUTOWPSCAN_MAIN"])
text = path.read_text(encoding="utf-8", errors="ignore")

text = re.sub(
    r"_wpscan_api_token\s*=.*",
    "_wpscan_api_token = os.environ.get('WPSCAN_API_TOKEN', '').strip()",
    text,
    count=1,
)

def replace_or_append(src, func_name, new_block):
    pattern = rf"^def {func_name}\(.*?(?=^def |\Z)"
    if re.search(pattern, src, flags=re.S | re.M):
        return re.sub(pattern, new_block + "\n\n", src, count=1, flags=re.S | re.M)
    return src.rstrip() + "\n\n" + new_block + "\n"

new_run_wpscan = """def run_wpscan(scan_url, scan_name, tg_chat_id):
    today = datetime.now(timezone.utc).astimezone()
    output_file_name = f'{_home_path}/{today.strftime("%Y%m%d")}' \\
                       f'_{create_job_id()}_{scan_url.replace("https://", "").replace("/", "")}_wpscan_result.json'

    cache_dir = os.environ.get('WPSCAN_CACHE_DIR', '').strip()
    cookie_jar = os.environ.get('WPSCAN_COOKIE_JAR', '').strip()
    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
    if cookie_jar:
        os.makedirs(os.path.dirname(cookie_jar) or '.', exist_ok=True)

    command = (
        f'wpscan --url {scan_url} --detection-mode mixed --random-user-agent '
        f'--output {output_file_name} --format json'
    )
    if cache_dir:
        command += f' --cache-dir \"{cache_dir}\"'
    if cookie_jar:
        command += f' --cookie-jar \"{cookie_jar}\"'
    if _wpscan_api_token:
        command += f' --api-token {_wpscan_api_token}'

    result = subprocess.run(command, shell=True, capture_output=False)

    if result.returncode == 1 or result.returncode == 4:
        result = f'{result.returncode}|{scan_name}|{scan_url}|{tg_chat_id}' \\
                 f'|0|scan_aborted. wrong url or something scan failed.|{output_file_name}|0'
    else:
        vulnerabilities_count, wp_banner, vulnerabilities_list = parse_wpscan_result(output_file_name)
        if wp_banner.startswith("scan_aborted"):
            result = f'4|{scan_name}|{scan_url}|{tg_chat_id}' \\
                     f'|0|scan_aborted. wrong url or something scan failed.|{output_file_name}|0'
        else:
            result = f'{result.returncode}|{scan_name}|{scan_url}|{tg_chat_id}' \\
                     f'|{vulnerabilities_count}|{wp_banner}|{output_file_name}|{vulnerabilities_list}'
    return result"""

new_parse_wpscan = """def parse_wpscan_result(result_file):
    try:
        with open(result_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        return 0, 'scan_aborted.missing_result_file', ''

    if not isinstance(data, dict):
        return 0, 'scan_aborted.invalid_result_format', ''

    if data.get('scan_aborted'):
        return 0, f\"scan_aborted.{str(data.get('scan_aborted'))[:120]}\", ''

    version_data = data.get('version')
    if not isinstance(version_data, dict):
        return 0, 'scan_aborted.missing_version', ''

    wp_ver = str(version_data.get('number', 'unknown'))
    i = 0
    result = ''

    vulnerabilities = version_data.get('vulnerabilities')
    if isinstance(vulnerabilities, list):
        for item in vulnerabilities:
            if not isinstance(item, dict):
                continue
            i += 1
            fixed = item.get('fixed_in')
            if fixed is None:
                fixed = 'null'
            title = item.get('title', 'unknown')
            contents = f\"{i}) {title} (fixed: {fixed})\\\\n\"
            result += contents

    return i, wp_ver, result"""

text = replace_or_append(text, "run_wpscan", new_run_wpscan)
text = replace_or_append(text, "parse_wpscan_result", new_parse_wpscan)
path.write_text(text, encoding="utf-8")
PY
    then
      warn "${name}: failed to patch optional WPScan API token handling"
    fi
  else
    warn "${name}: main.py not found after checkout"
  fi

  mark_installed "$name"
}

# AEM detector/discoverer wrappers from aem-hacker project.
install_aem_detector() {
  local name="AEM Detector"
  local repo="${TOOLS_DIR}/aem-hacker"
  local venv="${VENV_DIR}/aem-hacker"

  if ! repo_clone_or_update https://github.com/0ang3el/aem-hacker.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  if ! create_or_update_venv "$venv" python3; then
    mark_failed "$name" "venv creation failed"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/pip" install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  create_wrapper "aem-hacker" "exec \"${venv}/bin/python\" \"${repo}/aem_hacker.py\" \"\$@\""
  create_wrapper "aem-discoverer" "exec \"${venv}/bin/python\" \"${repo}/aem_discoverer.py\" \"\$@\""
  mark_installed "$name"
}

# Verify generated wrappers exist and are resolvable from user PATH context.
verify_install_artifacts() {
  local missing=0
  local wrapper=""
  local cmd_check=""
  local -a expected_wrappers=(
    wpscan cmsmap cmseek droopescan joomscan drupwn vbscan
    cmsscan-server cmsscan-python vulnx clusterd wpseku wpxf
    wpforce joomlavs fingerprinter aem-hacker aem-discoverer
  )

  for wrapper in "${expected_wrappers[@]}"; do
    if [[ ! -x "${BIN_DIR}/${wrapper}" ]]; then
      mark_failed "Verification" "missing executable wrapper: ${BIN_DIR}/${wrapper}"
      missing=1
      continue
    fi

    cmd_check="PATH=\"${BIN_DIR}:\$PATH\" command -v '${wrapper}' >/dev/null 2>&1"
    if ! run_as_install_user bash -lc "${cmd_check}"; then
      mark_failed "Verification" "wrapper not resolvable on PATH: ${wrapper}"
      missing=1
    fi
  done

  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    chown -R "${INSTALL_USER}:${INSTALL_USER}" "${BIN_DIR}" "${TOOLS_DIR}" "${VENV_DIR}" >/dev/null 2>&1 || true
  fi

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    missing=1
  fi

  if [[ "$missing" -ne 0 ]]; then
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# Phase entry points and summary
# -----------------------------------------------------------------------------

phase_preflight() {
  resolve_install_user
  if [[ "$VENV_DIR_SET_BY_ARG" -ne 1 ]]; then
    VENV_DIR="${INSTALL_HOME}/.venv/cms_scanner"
  fi

  ensure_sudo_access
  ensure_dirs

  log "Installing user-level dependencies as: ${INSTALL_USER}"
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    log "Detected root execution; pip/gem/git steps will run as ${INSTALL_USER}."
  fi
  prepare_env
}

phase_system_dependencies() {
  install_system_dependencies || true
  prepare_env
}

phase_install_tools() {
  install_wpscan
  install_cmsmap
  install_cmseek
  install_droopescan
  install_joomscan
  install_drupwn
  install_vbscan
  install_cmsscan
  install_vulnx
  install_clusterd
  install_wpseku
  install_wpxf
  install_wpforce
  install_joomlavs
  install_fingerprinter
  install_autowpscan
  install_aem_detector

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Print deterministic end-of-run summary for CI/log parsing.
print_summary() {
  log "==================== INSTALL SUMMARY ===================="
  log "Install user: ${INSTALL_USER} (${INSTALL_HOME})"
  log "Python venv root: ${VENV_DIR}"
  log "Installed tools: ${#INSTALLED[@]}"
  for item in "${INSTALLED[@]}"; do
    log "  - ${item}"
  done

  log "Skipped tools: ${#SKIPPED[@]}"
  for item in "${SKIPPED[@]}"; do
    log "  - ${item}"
  done

  log "Failed tools: ${#FAILED[@]}"
  for item in "${FAILED[@]}"; do
    log "  - ${item}"
  done

  log "Warnings: ${#WARNINGS[@]}"
  for item in "${WARNINGS[@]}"; do
    log "  - ${item}"
  done

  log "Phase results: ${#PHASE_RESULTS[@]}"
  for item in "${PHASE_RESULTS[@]}"; do
    log "  - ${item}"
  done

  log "Wrappers are available in: ${BIN_DIR}"
  log "Add to PATH: export PATH=\"${BIN_DIR}:\$PATH\""
}

# -----------------------------------------------------------------------------
# Main entrypoint
# -----------------------------------------------------------------------------

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --system-deps)
        INSTALL_SYSTEM_DEPS=1
        ;;
      --skip-smoke-tests)
        RUN_SMOKE_TESTS=0
        ;;
      --no-update)
        UPDATE_EXISTING=0
        ;;
      --strict)
        STRICT_MODE=1
        ;;
      --tools-dir)
        require_option_arg "$1" "${2:-}"
        TOOLS_DIR="$2"
        shift
        ;;
      --venv-dir)
        require_option_arg "$1" "${2:-}"
        VENV_DIR="$2"
        VENV_DIR_SET_BY_ARG=1
        shift
        ;;
      --bin-dir)
        require_option_arg "$1" "${2:-}"
        BIN_DIR="$2"
        shift
        ;;
      --log-file)
        require_option_arg "$1" "${2:-}"
        LOG_FILE="$2"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done

  if ! run_phase "Preflight" phase_preflight; then
    print_summary
    exit 1
  fi

  run_phase "System Dependencies" phase_system_dependencies || true
  run_phase "Tool Installation" phase_install_tools || true
  run_phase "Post-Install Verification" verify_install_artifacts || true

  print_summary

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    exit 1
  fi
  if [[ "${STRICT_MODE}" -eq 1 && ( ${#WARNINGS[@]} -gt 0 || ${#SKIPPED[@]} -gt 0 ) ]]; then
    exit 1
  fi
}

main "$@"
