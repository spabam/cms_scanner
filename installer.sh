#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf '%s\n' 'Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com'
fi
# VANTAGE_INSTALLER_FRAMEWORK_ENTRY
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${BASH_SOURCE[0]}" in */*) __vi_source_dir="${BASH_SOURCE[0]%/*}" ;; *) __vi_source_dir=. ;; esac
    __vi_probe="$(cd -P -- "$__vi_source_dir" && pwd)" || exit 73
    __vi_bootstrap=""
    while [[ "$__vi_probe" != / ]]; do
        __vi_candidate="$__vi_probe/orchestra/suite-installer/lib/bootstrap.sh"
        if [[ -f "$__vi_candidate" && ! -L "$__vi_candidate" ]]; then
            __vi_bootstrap="$__vi_candidate"; break
        fi
        __vi_probe="${__vi_probe%/*}"
        [[ -n "$__vi_probe" ]] || __vi_probe=/
    done
    [[ -n "$__vi_bootstrap" ]] || { printf 'Error: installer framework is missing; no installation started.\n' >&2; exit 69; }
    # shellcheck source=/dev/null
    source "$__vi_bootstrap" || exit $?
    export VI_NOTICE_SHOWN=1
    vi_entrypoint wa.cms "${BASH_SOURCE[0]}" "$@" || exit $?
    set -- "${VI_NATIVE_ARGS[@]}"
    unset __vi_probe __vi_candidate __vi_bootstrap __vi_source_dir
fi
# VANTAGE_INSTALLER_FRAMEWORK_ENTRY_END
# VANTAGE_INSTALLER_OWNERSHIP_BOOTSTRAP
# Capture the real invoking account before any sudo operation and bind ownership
# restoration to this installer directory's original device/inode.
__vantage_ownership_source="${BASH_SOURCE[0]:-$0}"
if [[ "$__vantage_ownership_source" == */* ]]; then
    __vantage_ownership_source_dir="${__vantage_ownership_source%/*}"
else
    __vantage_ownership_source_dir=.
fi
__vantage_ownership_dir="$(
    cd -P -- "$__vantage_ownership_source_dir" 2>/dev/null && pwd
)"
__vantage_ownership_probe="$__vantage_ownership_dir"
while [[ "$__vantage_ownership_probe" != / ]]; do
    if [[ -f "$__vantage_ownership_probe/.installer_ownership.sh" &&
          ! -L "$__vantage_ownership_probe/.installer_ownership.sh" ]]; then
        # shellcheck source=/dev/null
        source "$__vantage_ownership_probe/.installer_ownership.sh"
        break
    fi
    __vantage_ownership_probe="${__vantage_ownership_probe%/*}"
    [[ -n "$__vantage_ownership_probe" ]] || __vantage_ownership_probe=/
done
if ! declare -F vantage_capture_original_identity >/dev/null 2>&1; then
    printf 'Error: shared installer ownership helper was not found for %s\n' \
        "$__vantage_ownership_dir" >&2
    exit 69
fi
vantage_capture_original_identity || exit $?
vantage_arm_installer_ownership "$__vantage_ownership_dir" || exit $?
unset __vantage_ownership_source __vantage_ownership_source_dir
unset __vantage_ownership_dir __vantage_ownership_probe

# VANTAGE / INFRA AI OU PROJECT NOTICE
# Project-maintained VAPT integration by Andrea Bodei and INFRA AI OU for the
# VANTAGE project under the European Commission DIGITAL programme.
# AUTHORIZED USE ONLY: governments, companies, professionals, and other entities
# may use these tools only with explicit permission to perform VAPT against each
# specific target and only within the approved scope and rules of engagement.
# This repository grants no explicit or implicit authorization to test any target.
# Andrea Bodei, INFRA AI OU, the VANTAGE project, the DIGITAL programme, and the
# European Commission disclaim responsibility for unauthorized use or misuse.
# See PROJECT_NOTICE.md; applicable licenses and upstream notices remain authoritative.

# Copyright © 2026 Andrea Bodei — www.andreabodei.com
if [[ "${EUID}" -eq 0 ]]; then
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
fi
# Do not source dynamic cleanup hooks from this privileged-capable installer.

# Copyright (c) 2026-2036 Andrea Bodei <info at andreabodei.com>
set -Eeuo pipefail

# Universal CMS Vulnerability Scanner installer
# Installs all tools listed in README.md with best-effort compatibility handling.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VANTAGE_INSTALLER_CLEANUP_HELPER="${SCRIPT_DIR}/../../.installer_cleanup.sh"
VANTAGE_VERSION_GUARD="${SCRIPT_DIR}/../scripts/installer_version_guard.sh"
if [[ ! -r "${VANTAGE_VERSION_GUARD}" ]]; then
  printf 'Error: WA-SCAN version guard is missing: %s\n' "${VANTAGE_VERSION_GUARD}" >&2
  exit 1
fi
# shellcheck source=../scripts/installer_version_guard.sh
source "${VANTAGE_VERSION_GUARD}"
VANTAGE_ROOT_DIR="${VANTAGE_ROOT_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
VANTAGE_NMAP_HELPER="${VANTAGE_ROOT_DIR}/orchestra/suite-installer/lib/nmap.sh"
if [[ ! -r "$VANTAGE_NMAP_HELPER" ]]; then
  printf 'Error: shared Nmap policy helper is missing: %s\n' "$VANTAGE_NMAP_HELPER" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$VANTAGE_NMAP_HELPER"
VANTAGE_APT_METADATA_HELPER="${VANTAGE_ROOT_DIR}/orchestra/suite-installer/lib/apt_metadata.sh"
if [[ ! -r "$VANTAGE_APT_METADATA_HELPER" ]]; then
  printf 'Error: shared APT metadata helper is missing: %s\n' "$VANTAGE_APT_METADATA_HELPER" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$VANTAGE_APT_METADATA_HELPER"
# shellcheck source=scripts/install/registry.sh
source "$SCRIPT_DIR/scripts/install/registry.sh"
cms_install_registry_load "$SCRIPT_DIR/scripts/install/tools.tsv" \
  "$SCRIPT_DIR/scripts/install/tools" || { printf 'Error: invalid CMS installer tool registry.\n' >&2; exit 65; }
TOOLS_DIR="${SCRIPT_DIR}/tools"
VENV_DIR=""
CMS_DATA_DIR=""
COMPAT_DIR=""
BIN_DIR="${SCRIPT_DIR}/bin"
LOG_FILE="${SCRIPT_DIR}/logs/installer.log"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
FINGERPRINTER_LOCKFILE="${SCRIPTS_DIR}/fingerprinter.Gemfile.lock"
FINGERPRINTER_BUNDLER_VERSION="2.5.22"
INFRA_ARCHIVE_NAME="${INFRA_ARCHIVE_NAME:-0139684769}"
INFRA_LIB_DIR="${INFRA_LIB_DIR:-/opt/infrascan/lib}"
INFRA_ARCHIVE_PATH="${INFRA_LIB_DIR}/${INFRA_ARCHIVE_NAME}"
INFRA_ARCHIVE_MANIFEST_PATH="${INFRA_ARCHIVE_PATH}.manifest"
INFRA_CMSSCAN_WRAPPER_SOURCE="${SCRIPTS_DIR}/cmsscan.wrapper"
INFRA_CMSSCAN_BIN="${INFRA_CMSSCAN_BIN:-/opt/infrascan/bin/cmsscan}"
INFRA_CMSSCAN_PUBLIC_BIN="/usr/bin/cmsscan"
INFRA_CMSSCAN_ALIAS="${INFRA_CMSSCAN_ALIAS:-/usr/bin/cmscan}"
INFRAUTH_PATH="${INFRAUTH_PATH:-/etc/infrascan/infrauth}"
INFRAUTH_FALLBACK_PATH="${INFRAUTH_FALLBACK_PATH:-/etc/infrascan/infrauth}"

# Runtime switches (CLI options can override these defaults).
INSTALL_SYSTEM_DEPS=0
RUN_SMOKE_TESTS=1
CMS_PUBLICATION_COMPLETE=0
UPDATE_EXISTING=1
FORCE_INSTALL=0
RUN_FULL_DATA_REFRESH=0
STRICT_MODE=0
VANTAGE_SHARED_CLEANUP_ARMED=0
INSTALL_USER=""
INSTALL_HOME=""
INSTALL_UID=""
INSTALL_GID=""
USER_GEM_BIN=""
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
BASE_PATH="${SYSTEM_PATH}"
if [[ "${EUID}" -eq 0 ]]; then
  export PATH="${SYSTEM_PATH}"
fi
APT_UPDATED=0
SHOW_COMMAND_OUTPUT="${SHOW_COMMAND_OUTPUT:-0}"
FAIL_OUTPUT_TAIL_LINES="${FAIL_OUTPUT_TAIL_LINES:-120}"
GIT_UPDATE_TIMEOUT="${GIT_UPDATE_TIMEOUT:-300}"
SCANNER_DATA_UPDATE_TIMEOUT="${SCANNER_DATA_UPDATE_TIMEOUT:-900}"
SMOKE_TEST_TIMEOUT="${SMOKE_TEST_TIMEOUT:-45}"
DRUPWN_MIN_WORDLIST_ENTRIES="${DRUPWN_MIN_WORDLIST_ENTRIES:-100}"

# Result buckets used in final summary.
declare -a INSTALLED=()
declare -a SKIPPED=()
declare -a FAILED=()
declare -a WARNINGS=()
declare -a PHASE_RESULTS=()
declare -a UPDATED=()
declare -a UPDATE_SKIPPED=()
declare -a UPDATE_FAILED=()
declare -a PIP_CHECK_ALLOWED_NEWER=()
SHARED_ENV_CONSTRAINTS=""
EFFECTIVE_REPO_DIR=""
EFFECTIVE_WRAPPER_REPO_DIR=""
RUNTIME_CANDIDATE=""
RUNTIME_PREVIOUS=""
PENDING_MANAGED_LIVE=""
PENDING_MANAGED_PREVIOUS=""
PENDING_MANAGED_CANDIDATE=""
PENDING_MANAGED_COMMITTED=0
PENDING_MANAGED_UPDATE_LABEL=""
INSTALL_LOCK_FD=""
WRAPPER_CANDIDATE_PATH=""
WRAPPER_TARGET_PATH=""

# -----------------------------------------------------------------------------
# CLI and logging helpers
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Copyright (c) 2026-2036 Andrea Bodei - info at andreabodei.com

Usage: ./installer.sh [options]

Options:
  --system-deps             Install full apt dependency set up front (requires sudo/root)
  --skip-smoke-tests        Skip post-install smoke tests
  --no-update               Do not update existing tools or scanner databases
  --force                   Reinstall tools even when installed versions are
                            current or newer than their online versions
  --full-data-refresh       Also run slow upstream Droopescan, Drupwn, and
                            Fingerprinter database rebuilds
  --strict                  Exit non-zero when skipped tools or warnings are present
  --tools-dir <path>        Override tool checkout directory (default: ./tools)
  --bin-dir <path>          Override wrappers directory (default: ./bin)
  --log-file <path>         Override log file path (default: ./logs/installer.log)
  -h, --help                Show this help
EOF
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  local line=""
  line="[$(timestamp)] $*"
  printf '%s\n' "${line}"
  if [[ -n "${INSTALL_USER}" && -f "${LOG_FILE}" && ! -L "${LOG_FILE}" ]]; then
    printf '%s\n' "${line}" | run_as_install_user tee -a "$LOG_FILE" >/dev/null || true
  fi
}

append_text_to_log() {
  printf '%s\n' "$1" | run_as_install_user tee -a "$LOG_FILE" >/dev/null
}

append_file_to_log() {
  run_as_install_user tee -a "$LOG_FILE" <"$1" >/dev/null
}

warn() {
  WARNINGS+=("$*")
  log "WARN: $*"
  cms_installer_event warning cms.warning failed warning "$*"
}

mark_installed() {
  INSTALLED+=("$1")
  log "OK: $1 installed"
  cms_installer_event result cms.tool succeeded installed "$1"
}

mark_skipped() {
  SKIPPED+=("$1: $2")
  log "REUSE: $1 - $2"
  cms_installer_event decision cms.tool succeeded healthy_match "$1: $2"
}

mark_failed() {
  FAILED+=("$1: $2")
  log "FAIL: $1 - $2"
  cms_installer_event result cms.tool failed tool_failed "$1: $2"
}

cms_update_event() {
  cms_installer_event "$1" "${CMS_UPDATE_OPERATION_ID:-cms.update}" "$2" "$3" "$4"
}

mark_updated() {
  UPDATED+=("$1")
  log "UPDATED: $1"
  cms_update_event result succeeded update_verified "$1"
}

mark_update_skipped() {
  UPDATE_SKIPPED+=("$1: $2")
  log "UPDATE SKIP: $1 - $2"
  cms_update_event decision not_applicable update_not_selected "$1: $2"
}

mark_update_failed() {
  UPDATE_FAILED+=("$1: $2")
  log "UPDATE FAIL: $1 - $2"
  cms_update_event result failed required_update_failed "$1: $2"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

system_cmd_path() {
  PATH="${SYSTEM_PATH}" type -P -- "$1" 2>/dev/null
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
  if "$@" >"${tmp_file}" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  append_file_to_log "${tmp_file}"
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
  vantage_make_temp tmp_file || return 1
  if run_and_capture_output "${tmp_file}" "$@"; then
    rc=0
  else
    rc=$?
  fi
  if [[ "${rc}" -eq 0 ]]; then
    if [[ "${SHOW_COMMAND_OUTPUT}" -eq 1 ]]; then
      cat "${tmp_file}"
    fi
    rm -f "${tmp_file}"
    return 0
  fi

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

# Determine the non-root user that should own cloned repos, the CMS-scoped
# venv, compatibility sources, and wrappers.
resolve_install_user() {
  vantage_require_runtime_identity || return
  vantage_runtime_resolve_identity || return
  INSTALL_USER="${VANTAGE_RUNTIME_USER}"
  INSTALL_HOME="${VANTAGE_RUNTIME_HOME}"
  INSTALL_UID="${VANTAGE_RUNTIME_UID}"
  INSTALL_GID="${VANTAGE_RUNTIME_GID}"
  CMS_DATA_DIR="${INSTALL_HOME}/.local/share/vantage/cms_scanner"
  VENV_DIR="${CMS_DATA_DIR}/venv"
}

# Run command as resolved install user while preserving required PATH/HOME.
run_as_install_user() {
  local user_path=""

  vantage_require_runtime_identity || return
  vantage_runtime_resolve_identity || return
  if [[ "${INSTALL_USER}" != "${VANTAGE_RUNTIME_USER}" ||
        "${INSTALL_HOME}" != "${VANTAGE_RUNTIME_HOME}" ||
        "${INSTALL_UID}" != "${VANTAGE_RUNTIME_UID}" ||
        "${INSTALL_GID}" != "${VANTAGE_RUNTIME_GID}" ||
        "${CMS_DATA_DIR}" != "${VANTAGE_RUNTIME_HOME}/.local/share/vantage/cms_scanner" ||
        "${VENV_DIR}" != "${CMS_DATA_DIR}/venv" ]]; then
    printf 'Error: installer runtime identity drifted from the shared aiuser policy.\n' >&2
    return 69
  fi
  user_path="${BIN_DIR}:${VANTAGE_RUNTIME_PATH}"

  if [[ -n "${USER_GEM_BIN}" ]]; then
    user_path="${BIN_DIR}:${USER_GEM_BIN}:${VANTAGE_RUNTIME_PATH}"
  fi
  vantage_runtime_run_as_user /usr/bin/env "PATH=${user_path}" "$@"
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
  local -a git_cmd=(env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git "$@")

  preview="$(command_preview "git $*")"
  if has_cmd timeout; then
    git_cmd=(timeout --signal=TERM --kill-after=10s "${GIT_UPDATE_TIMEOUT}" "${git_cmd[@]}")
  fi
  run_logged_command \
    "RUN(user:${INSTALL_USER}): ${preview}" \
    "user:${INSTALL_USER} ${preview}" \
    run_as_install_user "${git_cmd[@]}"
}

# Execute a shell script as install user (used for multiline compatibility patches).
run_user_shell() {
  local cmd="$1"
  local preview=""

  if [[ "${cmd}" == *$'\n'* ]]; then
    preview="bash --noprofile --norc -c <multiline-script omitted>"
  else
    preview="bash --noprofile --norc -c $(command_preview "${cmd}")"
  fi
  run_logged_command \
    "RUN(user:${INSTALL_USER}): ${preview}" \
    "user:${INSTALL_USER} ${preview}" \
    run_as_install_user bash --noprofile --norc -c "${cmd}"
}

capture_user_cmd() {
  run_as_install_user "$@"
}

# Install scanner requirements at the newest versions allowed by their
# upstream constraints. --no-update still installs missing requirements but
# deliberately leaves already-installed distributions unchanged.
scanner_pip_install() {
  local -a pip_args=(install --no-cache-dir --no-warn-conflicts)

  if [[ -n "${SHARED_ENV_CONSTRAINTS}" ]]; then
    pip_args+=(--constraint "${SHARED_ENV_CONSTRAINTS}")
  fi
  if [[ "${UPDATE_EXISTING}" -eq 1 ]]; then
    pip_args+=(--upgrade --upgrade-strategy only-if-needed)
  fi
  if vantage_force_requested; then
    pip_args+=(--force-reinstall)
  fi
  run_user_cmd "${VENV_DIR}/bin/python" -m pip "${pip_args[@]}" "$@"
}

# Remove only setuptools output from a validated installer-managed live source
# or its six-character mktemp candidate. User checkouts and arbitrary tool
# directories deliberately fail this guard and remain untouched.
cleanup_managed_python_build_artifacts() {
  local source_dir="${1:-}"
  local live_dir="${2:-}"

  [[ -n "${COMPAT_DIR:-}" && "${COMPAT_DIR}" != "/" &&
    -n "${source_dir}" && -n "${live_dir}" && "${live_dir}" != "/" &&
    -d "${source_dir}" && ! -L "${source_dir}" ]] || return 1
  case "${live_dir}" in
    "${COMPAT_DIR}/upstream/CMSmap"|"${COMPAT_DIR}/drupwn-src") ;;
    *) return 1 ;;
  esac
  case "${source_dir}" in
    "${live_dir}"|"${live_dir}.new."??????) ;;
    *) return 1 ;;
  esac
  run_user_cmd rm -rf -- "${source_dir}/build" "${source_dir}/dist"
}

# Return success only when a pip-check line is a genuine upper-bound mismatch:
# the installed dependency is newer than the requiring package permits.
pip_check_line_is_newer_only() {
  local line="$1"

  capture_user_cmd env PIP_CHECK_LINE="${line}" "${VENV_DIR}/bin/python" - <<'PY'
import os
import re
from importlib import metadata

try:
    from packaging.requirements import Requirement
    from packaging.utils import canonicalize_name
    from packaging.version import InvalidVersion, Version
except ImportError:
    from pip._vendor.packaging.requirements import Requirement
    from pip._vendor.packaging.utils import canonicalize_name
    from pip._vendor.packaging.version import InvalidVersion, Version

line = os.environ["PIP_CHECK_LINE"].strip()
match = re.fullmatch(
    r"(\S+) (\S+) has requirement (.+), but you have (\S+) (\S+)\.",
    line,
)
if not match:
    raise SystemExit(1)

_owner_name, _owner_version, requirement_text, actual_name, actual_text = match.groups()
try:
    requirement = Requirement(requirement_text)
    actual = Version(actual_text)
    installed = Version(metadata.version(actual_name))
except (InvalidVersion, metadata.PackageNotFoundError, ValueError):
    raise SystemExit(1)

if canonicalize_name(requirement.name) != canonicalize_name(actual_name):
    raise SystemExit(1)
if installed != actual or requirement.specifier.contains(actual, prereleases=True):
    raise SystemExit(1)

violated = [
    specifier
    for specifier in requirement.specifier
    if not specifier.contains(actual, prereleases=True)
]
if not violated:
    raise SystemExit(1)

def newer_than_allowed(specifier):
    operator = specifier.operator
    raw_version = specifier.version
    if operator in {"<", "<="}:
        try:
            boundary = Version(raw_version)
        except InvalidVersion:
            return False
        return actual >= boundary if operator == "<" else actual > boundary
    if operator == "~=":
        try:
            return actual > Version(raw_version)
        except InvalidVersion:
            return False
    if operator == "==":
        try:
            return actual > Version(raw_version.rstrip(".*"))
        except InvalidVersion:
            return False
    return False

raise SystemExit(0 if all(newer_than_allowed(item) for item in violated) else 1)
PY
}

# Preserve every currently satisfied exact, exclusion, or upper-bound
# requirement in the CMS environment while scanner packages are updated.
# Baseline newer-only conflicts are pinned at their current version as well so
# the final pip-check line cannot drift during this installer run.
write_shared_environment_constraints() {
  local constraints_path="${VENV_DIR}/.vantage-scanner-constraints.txt"
  local baseline_text=""
  local constraint_count=""

  if [[ "${#PIP_CHECK_ALLOWED_NEWER[@]}" -gt 0 ]]; then
    baseline_text="$(printf '%s\n' "${PIP_CHECK_ALLOWED_NEWER[@]}")"
  fi
  if ! run_user_cmd env \
      CONSTRAINTS_PATH="${constraints_path}" \
      PIP_CHECK_BASELINE="${baseline_text}" \
      "${VENV_DIR}/bin/python" - <<'PY'
import os
import re
import tempfile
from importlib import metadata
from pathlib import Path

try:
    from packaging.requirements import Requirement
    from packaging.utils import canonicalize_name
except ImportError:
    from pip._vendor.packaging.requirements import Requirement
    from pip._vendor.packaging.utils import canonicalize_name

target = Path(os.environ["CONSTRAINTS_PATH"])
protected = {}

for distribution in metadata.distributions():
    for requirement_text in distribution.requires or ():
        try:
            requirement = Requirement(requirement_text)
            if requirement.marker and not requirement.marker.evaluate({"extra": ""}):
                continue
            specifiers = list(requirement.specifier)
            if (
                requirement.url
                or not specifiers
                or not any(item.operator not in {">", ">="} for item in specifiers)
            ):
                continue
            installed = metadata.version(requirement.name)
            if not requirement.specifier.contains(installed, prereleases=True):
                continue
        except (metadata.PackageNotFoundError, ValueError):
            continue
        protected[canonicalize_name(requirement.name)] = installed

line_pattern = re.compile(
    r"\S+ \S+ has requirement .+, but you have (\S+) (\S+)\."
)
for line in os.environ.get("PIP_CHECK_BASELINE", "").splitlines():
    match = line_pattern.fullmatch(line.strip())
    if not match:
        continue
    dependency_name, reported_version = match.groups()
    try:
        installed = metadata.version(dependency_name)
    except metadata.PackageNotFoundError:
        continue
    if installed == reported_version:
        protected[canonicalize_name(dependency_name)] = installed

payload = "".join(
    f"{name}=={protected[name]}\n"
    for name in sorted(protected)
)
temporary_name = ""
try:
    descriptor, temporary_name = tempfile.mkstemp(
        dir=target.parent,
        prefix=f".{target.name}.",
    )
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temporary_name, 0o644)
    os.replace(temporary_name, target)
finally:
    if temporary_name:
        Path(temporary_name).unlink(missing_ok=True)

print(len(protected))
PY
  then
    mark_failed "Python environment" \
      "could not create CMS-environment constraints in ${VENV_DIR}"
    return 1
  fi

  if [[ ! -f "${constraints_path}" || -L "${constraints_path}" ]]; then
    mark_failed "Python environment" \
      "CMS-environment constraints are not a regular file: ${constraints_path}"
    return 1
  fi
  constraint_count="$(
    capture_user_cmd "${VENV_DIR}/bin/python" - "${constraints_path}" <<'PY'
import sys
from pathlib import Path

print(sum(1 for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if line))
PY
  )"
  [[ "${constraint_count}" =~ ^[0-9]+$ ]] || {
    mark_failed "Python environment" \
      "could not validate CMS-environment constraints: ${constraints_path}"
    return 1
  }
  SHARED_ENV_CONSTRAINTS="${constraints_path}"
  log "INFO: Preserving ${constraint_count} CMS dependency constraints during scanner updates"
}

# Record only verified newer-than-upper-bound conflicts from the CMS venv.
# Older or missing dependencies must disappear before final verification.
record_pip_check_baseline() {
  local output=""
  local rc=0
  local line=""

  PIP_CHECK_ALLOWED_NEWER=()
  if output="$(capture_user_cmd "${VENV_DIR}/bin/python" -m pip check 2>&1)"; then
    write_shared_environment_constraints
    return $?
  else
    rc=$?
  fi
  if [[ "${rc}" -ne 1 ]]; then
    mark_failed "Python environment" "pip check could not inspect ${VENV_DIR} (exit ${rc})"
    return 1
  fi

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    if pip_check_line_is_newer_only "${line}"; then
      PIP_CHECK_ALLOWED_NEWER+=("${line}")
      log "INFO: Accepting pre-existing newer dependency in CMS environment: ${line}"
    else
      log "INFO: Pre-existing dependency issue must be repaired by scanner upgrades: ${line}"
    fi
  done <<<"${output}"
  write_shared_environment_constraints
}

# Fail on every new, changed, older, missing, or malformed dependency issue.
verify_shared_python_dependencies() {
  local output=""
  local rc=0
  local line=""
  local allowed_line=""
  local allowed=0
  local failed=0

  if output="$(capture_user_cmd "${VENV_DIR}/bin/python" -m pip check 2>&1)"; then
    return 0
  else
    rc=$?
  fi
  [[ "${rc}" -eq 1 ]] || return 1

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    allowed=0
    for allowed_line in "${PIP_CHECK_ALLOWED_NEWER[@]}"; do
      if [[ "${line}" == "${allowed_line}" ]]; then
        allowed=1
        break
      fi
    done
    if [[ "${allowed}" -eq 1 ]]; then
      log "INFO: Accepted unchanged newer shared dependency: ${line}"
    else
      printf 'Dependency conflict after scanner installation: %s\n' "${line}" >&2
      failed=1
    fi
  done <<<"${output}"
  [[ "${failed}" -eq 0 ]]
}

# Run command with privilege escalation only when needed.
run_privileged() {
  local sudo_cmd=""

  if [[ "${EUID}" -eq 0 ]]; then
    run_cmd env "PATH=${SYSTEM_PATH}" "$@"
  else
    sudo_cmd="$(system_cmd_path sudo || true)"
    if [[ -z "${sudo_cmd}" ]] || ! "${sudo_cmd}" -v; then
      return 1
    fi
    run_cmd "${sudo_cmd}" env "PATH=${SYSTEM_PATH}" "$@"
  fi
}

# -----------------------------------------------------------------------------
# Dependency/runtime helpers
# -----------------------------------------------------------------------------

apt_install_packages() {
  local reason="$1"
  shift
  local -a pkgs=( "$@" )
  local -a install_pkgs=()

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  if ! has_cmd apt-get; then
    warn "${reason}: apt-get not available; cannot auto-install packages: ${pkgs[*]}"
    return 1
  fi
  if [[ "$APT_UPDATED" -ne 1 ]]; then
    if ! vantage_refresh_apt_metadata run_privileged apt-get; then
      warn "${reason}: APT metadata is unusable (need sudo/root and valid package state)"
      return 1
    fi
    APT_UPDATED=1
  fi
  mapfile -t install_pkgs < <(vantage_filter_apt_packages "${pkgs[@]}")
  if [[ "${#install_pkgs[@]}" -eq 0 ]]; then
    log "REUSE: APT dependencies for ${reason} - all requested packages are current or newer"
    return 0
  fi
  if vantage_force_requested; then
    install_pkgs=(--reinstall "${install_pkgs[@]}")
  fi
  if ! run_privileged apt-get install -y "${install_pkgs[@]}"; then
    warn "${reason}: apt-get install failed for packages: ${install_pkgs[*]}"
    return 1
  fi
}

has_user_cmd() {
  local cmd="$1"
  # shellcheck disable=SC2016 # Positional parameter expands in the inner shell.
  run_as_install_user bash -c 'command -v "$1" >/dev/null 2>&1' _ "${cmd}"
}

resolve_user_cmd_path() {
  local cmd="$1"
  # shellcheck disable=SC2016 # Positional parameter expands in the inner shell.
  run_as_install_user bash -c 'command -v "$1" 2>/dev/null || true' _ "${cmd}"
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

# Install a missing Ruby tool, or explicitly upgrade it when updates are enabled.
# A user gem is preferred so an old distro package cannot shadow the refreshed
# executable and no system gem directory has to be modified.
install_or_update_user_gem() {
  local tool_name="$1"
  local gem_name="$2"
  local gem_present=0
  local gem_version=""
  local gem_executable=""
  local candidate=""

  if capture_user_cmd ruby -r rubygems -e \
    'exit(Gem::Specification.find_all_by_name(ARGV.fetch(0)).empty? ? 1 : 0)' \
    "${gem_name}" >/dev/null 2>&1; then
    gem_present=1
  fi

  if [[ "${gem_present}" -eq 1 && "${UPDATE_EXISTING}" -eq 0 ]]; then
    for candidate in \
      "${USER_GEM_BIN}/${gem_name}" \
      "/usr/local/bin/${gem_name}" \
      "/usr/bin/${gem_name}"; do
      [[ -n "${candidate}" && -x "${candidate}" ]] || continue
      if [[ "$(readlink -f "${candidate}" 2>/dev/null || printf '%s' "${candidate}")" != \
            "$(readlink -f "${BIN_DIR}/${gem_name}" 2>/dev/null || true)" ]]; then
        gem_executable="${candidate}"
        break
      fi
    done
    if [[ -n "${gem_executable}" ]]; then
      mark_update_skipped "${tool_name} gem" "disabled by --no-update"
      return 0
    fi

    # The gemspec can survive while its binstub is missing. Reinstall the exact
    # installed version so --no-update repairs the tool without upgrading it.
    gem_version="$(capture_user_cmd ruby -r rubygems -e \
      's=Gem::Specification.find_all_by_name(ARGV.fetch(0)).max_by(&:version); print(s.version)' \
      "${gem_name}" 2>/dev/null || true)"
    if [[ -z "${gem_version}" ]] || ! run_user_cmd gem install --user-install \
      --no-document --force --version "${gem_version}" "${gem_name}"; then
      mark_update_failed "${tool_name} gem" \
        "missing executable could not be repaired without changing the installed version"
      return 1
    fi
    refresh_user_gem_bin
    if [[ -z "${USER_GEM_BIN}" || ! -x "${USER_GEM_BIN}/${gem_name}" ]]; then
      mark_update_failed "${tool_name} gem" "exact-version reinstall did not restore the executable"
      return 1
    fi
    mark_updated "${tool_name} gem executable (repaired at ${gem_version}; no upgrade)"
    return 0
  fi

  if vantage_force_requested; then
    if ! run_user_cmd gem install --user-install --no-document --force "${gem_name}"; then
      mark_update_failed "${tool_name} gem" "forced gem reinstall failed"
      return 1
    fi
    mark_updated "${tool_name} gem (forced reinstall)"
  elif [[ "${gem_present}" -eq 1 ]]; then
    if ! run_user_cmd gem update "${gem_name}" --user-install --no-document; then
      mark_update_failed "${tool_name} gem" "gem update failed"
      return 1
    fi
    mark_updated "${tool_name} gem"
  else
    if ! run_user_cmd gem install --user-install --no-document "${gem_name}"; then
      return 1
    fi
    mark_updated "${tool_name} gem (fresh install)"
  fi

  refresh_user_gem_bin
}

# Ensure Ruby + gem toolchain is available for Ruby-based scanners.
# The health check runs FIRST: on any Debian-family host `has_cmd apt-get` is
# true, so a failing apt (unreachable mirror, no sudo, missing ruby-dev) used to
# short-circuit past the only code that asks whether ruby and gem actually work,
# cascading into a total install failure on a perfectly usable Ruby host.
ensure_ruby_runtime() {
  if has_user_cmd ruby && has_user_cmd gem; then
    refresh_user_gem_bin
    return 0
  fi

  if has_cmd apt-get; then
    apt_install_packages "Ruby runtime" ruby ruby-dev build-essential || \
      warn "apt could not install the Ruby runtime packages; checking for an existing ruby/gem"
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

  if has_cmd apt-get; then
    apt_install_packages "Perl runtime" perl || \
      warn "apt could not install the Perl runtime package; checking for an existing perl"
  fi

  if ! has_cmd perl; then
    warn "Perl runtime is unavailable after installation attempt"
    return 1
  fi
}

# Validate sudo auth once when --system-deps is requested by non-root user.
ensure_sudo_access() {
  local sudo_cmd=""

  if [[ "$INSTALL_SYSTEM_DEPS" -ne 1 || "${EUID}" -eq 0 ]]; then
    return 0
  fi
  sudo_cmd="$(system_cmd_path sudo || true)"
  if [[ -z "${sudo_cmd}" ]]; then
    mark_failed "System dependencies" "sudo is required for --system-deps"
    return 1
  fi
  log "Root access is required for apt packages. Please enter your sudo password."
  if ! "${sudo_cmd}" -v; then
    mark_failed "System dependencies" "sudo authentication failed"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Filesystem/repository/wrapper helpers
# -----------------------------------------------------------------------------

run_privileged_raw() {
  local sudo_cmd=""

  if [[ "${EUID}" -eq 0 ]]; then
    env "PATH=${SYSTEM_PATH}" "$@"
  else
    sudo_cmd="$(system_cmd_path sudo || true)"
    [[ -n "${sudo_cmd}" ]] || return 1
    "${sudo_cmd}" env "PATH=${SYSTEM_PATH}" "$@"
  fi
}

# Remove one installer-managed tree without asking a privileged rm process to
# resolve a path through install-user-writable ancestors. The isolated system
# Python opens every directory component relative to an already-open parent,
# refuses symlinks and filesystem crossings, and unlinks children by dirfd.
remove_managed_tree_privileged() {
  local trusted_root="$1"
  local relative_tree="$2"
  local python_cmd=""

  [[ "${trusted_root}" == /* && "${trusted_root}" != "/" ]] || return 1
  [[ -n "${relative_tree}" && "${relative_tree}" != /* ]] || return 1
  python_cmd="$(system_cmd_path python3 || true)"
  [[ -n "${python_cmd}" ]] || return 1

  run_privileged "${python_cmd}" -I -S - "${trusted_root}" "${relative_tree}" <<'PY'
import errno
import os
from pathlib import PurePosixPath
import stat
import sys


def open_absolute_directory(path):
    components = PurePosixPath(path).parts
    if not components or components[0] != "/":
        raise ValueError("trusted root must be absolute")
    descriptor = os.open(
        "/",
        os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
    )
    try:
        for component in components[1:]:
            next_descriptor = os.open(
                component,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def open_relative_parent(root_descriptor, components, filesystem_device):
    descriptor = os.dup(root_descriptor)
    try:
        for component in components:
            next_descriptor = os.open(
                component,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                dir_fd=descriptor,
            )
            if os.fstat(next_descriptor).st_dev != filesystem_device:
                os.close(next_descriptor)
                raise RuntimeError(
                    f"refusing filesystem crossing at {component!r}"
                )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def remove_contents(directory_descriptor, filesystem_device):
    for name in os.listdir(directory_descriptor):
        try:
            child_descriptor = os.open(
                name,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                dir_fd=directory_descriptor,
            )
        except OSError as exc:
            if exc.errno not in (errno.ELOOP, errno.ENOTDIR):
                raise
            os.unlink(name, dir_fd=directory_descriptor)
            continue

        try:
            child_stat = os.fstat(child_descriptor)
            if child_stat.st_dev != filesystem_device:
                raise RuntimeError(f"refusing filesystem crossing at {name!r}")
            remove_contents(child_descriptor, filesystem_device)
            current = os.stat(
                name,
                dir_fd=directory_descriptor,
                follow_symlinks=False,
            )
            if (
                not stat.S_ISDIR(current.st_mode)
                or current.st_dev != child_stat.st_dev
                or current.st_ino != child_stat.st_ino
            ):
                raise RuntimeError(f"directory changed during removal: {name!r}")
            os.rmdir(name, dir_fd=directory_descriptor)
        finally:
            os.close(child_descriptor)


root_path, relative_path = sys.argv[1:]
relative = PurePosixPath(relative_path)
if (
    relative.is_absolute()
    or not relative.parts
    or any(component in ("", ".", "..") for component in relative.parts)
):
    raise SystemExit("invalid managed relative path")

root_descriptor = open_absolute_directory(root_path)
parent_descriptor = None
target_descriptor = None
try:
    root_device = os.fstat(root_descriptor).st_dev
    parent_descriptor = open_relative_parent(
        root_descriptor,
        relative.parts[:-1],
        root_device,
    )
    target_name = relative.parts[-1]
    target_descriptor = os.open(
        target_name,
        os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=parent_descriptor,
    )
    target_stat = os.fstat(target_descriptor)
    if target_stat.st_dev != root_device:
        raise RuntimeError("refusing managed-tree filesystem crossing")
    remove_contents(target_descriptor, target_stat.st_dev)
    current = os.stat(
        target_name,
        dir_fd=parent_descriptor,
        follow_symlinks=False,
    )
    if (
        not stat.S_ISDIR(current.st_mode)
        or current.st_dev != target_stat.st_dev
        or current.st_ino != target_stat.st_ino
    ):
        raise RuntimeError("managed tree changed during removal")
    os.rmdir(target_name, dir_fd=parent_descriptor)
finally:
    if target_descriptor is not None:
        os.close(target_descriptor)
    if parent_descriptor is not None:
        os.close(parent_descriptor)
    os.close(root_descriptor)
PY
}

# Verify every object in a managed tree is owned by the resolved install user.
# `find -P` inspects symlinks themselves instead of following them.
verify_install_user_tree_ownership() {
  local path="$1"
  local find_cmd=""
  local foreign_path=""

  [[ -d "${path}" && ! -L "${path}" ]] || return 1
  find_cmd="$(system_cmd_path find || true)"
  [[ -n "${find_cmd}" ]] || return 1
  if ! foreign_path="$(
    "${find_cmd}" -P "${path}" -xdev \
      \( ! -uid "${INSTALL_UID}" -o ! -gid "${INSTALL_GID}" \) \
      -print -quit 2>/dev/null
  )"; then
    return 1
  fi
  [[ -z "${foreign_path}" ]]
}

# Repair stale privileged writes only inside the already validated canonical
# virtual environment.  A two-pass descriptor-relative walker audits the whole
# tree before changing anything.  It refuses foreign non-root ownership,
# nested mounts (including same-device bind mounts), special files, and any
# ownership-changing hardlink, and it never follows symlink targets.
repair_canonical_venv_root_ownership() {
  local venv_real="$1"
  local expected_dev="$2"
  local expected_ino="$3"
  local private_group="$4"
  local python_cmd=""

  [[ "${venv_real}" == /* && "${venv_real}" != "/" && \
     "${expected_dev}" =~ ^[0-9]+$ && "${expected_ino}" =~ ^[0-9]+$ && \
     "${INSTALL_UID}" =~ ^[0-9]+$ && "${INSTALL_GID}" =~ ^[0-9]+$ && \
     ( "${private_group}" == 0 || "${private_group}" == 1 ) ]] || return 64
  python_cmd="$(system_cmd_path python3 || true)"
  [[ -n "${python_cmd}" ]] || return 69

  run_privileged "${python_cmd}" -I -S - \
    "${venv_real}" "${expected_dev}" "${expected_ino}" \
    "${INSTALL_UID}" "${INSTALL_GID}" "${private_group}" <<'PY'
import os
import stat
import sys


class UnsafeTree(RuntimeError):
    pass


(
    root_path,
    expected_device,
    expected_inode,
    target_uid,
    target_gid,
    private_group,
) = sys.argv[1:]
expected_device = int(expected_device)
expected_inode = int(expected_inode)
target_uid = int(target_uid)
target_gid = int(target_gid)
private_group = private_group == "1"

if os.geteuid() != 0:
    raise SystemExit("canonical venv ownership repair requires root")
if not root_path.startswith("/") or root_path == "/":
    raise SystemExit("invalid canonical venv path")
if not hasattr(os, "O_PATH") or not os.path.isdir("/proc/self/fdinfo"):
    raise SystemExit("descriptor and mount-ID support is unavailable")

directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC
directory_flags |= getattr(os, "O_NOFOLLOW", 0)
path_flags = os.O_PATH | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)
file_flags = os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)


def mount_id(fd):
    with open(f"/proc/self/fdinfo/{fd}", "r", encoding="ascii") as handle:
        for line in handle:
            if line.startswith("mnt_id:"):
                return int(line.split(":", 1)[1].strip())
    raise UnsafeTree("mount ID is unavailable")


def same_object(left, right):
    return (
        left.st_dev == right.st_dev
        and left.st_ino == right.st_ino
        and stat.S_IFMT(left.st_mode) == stat.S_IFMT(right.st_mode)
    )


def owner_state(metadata, label):
    owner = (metadata.st_uid, metadata.st_gid)
    if owner == (target_uid, target_gid):
        return "clean"
    if metadata.st_uid == 0 and metadata.st_gid in (0, target_gid):
        return "repair"
    if metadata.st_uid == target_uid and metadata.st_gid == 0:
        return "repair"
    raise UnsafeTree(
        f"foreign ownership at {label}: {metadata.st_uid}:{metadata.st_gid}"
    )


def validate_metadata(metadata, label, *, directory=False, allow_repair=True):
    if metadata.st_dev != expected_device:
        raise UnsafeTree(f"filesystem crossing at {label}")
    if directory:
        if not stat.S_ISDIR(metadata.st_mode):
            raise UnsafeTree(f"directory changed type at {label}")
    elif not (stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode)):
        raise UnsafeTree(f"special file is not allowed at {label}")

    if not stat.S_ISLNK(metadata.st_mode):
        if metadata.st_mode & 0o002:
            raise UnsafeTree(f"world-writable entry at {label}")
        if metadata.st_mode & 0o020 and not private_group:
            raise UnsafeTree(f"non-private group-writable entry at {label}")

    state = owner_state(metadata, label)
    if state == "repair" and not allow_repair:
        raise UnsafeTree(f"ownership repair did not converge at {label}")
    if state == "repair" and stat.S_ISLNK(metadata.st_mode):
        raise UnsafeTree(f"mismatched symlink ownership at {label}")
    if state == "repair" and not directory and metadata.st_nlink > 1:
        raise UnsafeTree(f"ownership-changing hardlink at {label}")
    return state


def open_checked_entry(parent_fd, name, expected, label):
    descriptor = os.open(name, path_flags, dir_fd=parent_fd)
    current = os.fstat(descriptor)
    if not same_object(expected, current):
        os.close(descriptor)
        raise UnsafeTree(f"entry changed during validation at {label}")
    if mount_id(descriptor) != root_mount:
        os.close(descriptor)
        raise UnsafeTree(f"nested mount at {label}")
    return descriptor


def validate_trust_anchor(root_fd):
    label = "pyvenv.cfg"
    metadata = os.stat(label, dir_fd=root_fd, follow_symlinks=False)
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or (metadata.st_uid, metadata.st_gid) != (target_uid, target_gid)
    ):
        raise UnsafeTree("pyvenv.cfg is not an unlinked install-user-owned file")
    descriptor = open_checked_entry(root_fd, label, metadata, label)
    os.close(descriptor)


def audit_directory(directory_fd, relative=".", *, allow_repair=True, is_root=False):
    metadata = os.fstat(directory_fd)
    if mount_id(directory_fd) != root_mount:
        raise UnsafeTree(f"nested mount at {relative}")
    if is_root:
        if (
            metadata.st_dev != expected_device
            or metadata.st_ino != expected_inode
            or not stat.S_ISDIR(metadata.st_mode)
            or (metadata.st_uid, metadata.st_gid) != (target_uid, target_gid)
        ):
            raise UnsafeTree("canonical venv root changed after validation")
        if metadata.st_mode & 0o002:
            raise UnsafeTree("canonical venv root is world-writable")
        if metadata.st_mode & 0o020 and not private_group:
            raise UnsafeTree("canonical venv root is writable by a non-private group")
    else:
        validate_metadata(
            metadata,
            relative,
            directory=True,
            allow_repair=allow_repair,
        )

    for name in sorted(os.listdir(directory_fd)):
        label = name if relative == "." else f"{relative}/{name}"
        entry = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        if stat.S_ISDIR(entry.st_mode):
            child_fd = os.open(name, directory_flags, dir_fd=directory_fd)
            try:
                current = os.fstat(child_fd)
                if not same_object(entry, current):
                    raise UnsafeTree(f"directory changed during validation at {label}")
                if mount_id(child_fd) != root_mount:
                    raise UnsafeTree(f"nested mount at {label}")
                audit_directory(
                    child_fd,
                    label,
                    allow_repair=allow_repair,
                    is_root=False,
                )
            finally:
                os.close(child_fd)
            continue

        validate_metadata(entry, label, allow_repair=allow_repair)
        entry_fd = open_checked_entry(directory_fd, name, entry, label)
        os.close(entry_fd)


def repair_directory(directory_fd, relative=".", *, is_root=False):
    metadata = os.fstat(directory_fd)
    if mount_id(directory_fd) != root_mount:
        raise UnsafeTree(f"nested mount at {relative}")
    if is_root:
        if (
            metadata.st_dev != expected_device
            or metadata.st_ino != expected_inode
            or (metadata.st_uid, metadata.st_gid) != (target_uid, target_gid)
        ):
            raise UnsafeTree("canonical venv root changed before repair")
    else:
        validate_metadata(metadata, relative, directory=True)

    for name in sorted(os.listdir(directory_fd)):
        label = name if relative == "." else f"{relative}/{name}"
        entry = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        if stat.S_ISDIR(entry.st_mode):
            child_fd = os.open(name, directory_flags, dir_fd=directory_fd)
            try:
                current = os.fstat(child_fd)
                if not same_object(entry, current) or mount_id(child_fd) != root_mount:
                    raise UnsafeTree(f"directory changed before repair at {label}")
                repair_directory(child_fd, label)
            finally:
                os.close(child_fd)
            continue

        state = validate_metadata(entry, label)
        entry_fd = open_checked_entry(directory_fd, name, entry, label)
        try:
            if state == "repair":
                os.close(entry_fd)
                entry_fd = os.open(name, file_flags, dir_fd=directory_fd)
                current = os.fstat(entry_fd)
                if (
                    not same_object(entry, current)
                    or mount_id(entry_fd) != root_mount
                    or current.st_nlink != 1
                    or owner_state(current, label) != "repair"
                ):
                    raise UnsafeTree(f"file changed before repair at {label}")
                os.fchown(entry_fd, target_uid, target_gid)
        finally:
            os.close(entry_fd)

    metadata = os.fstat(directory_fd)
    if not is_root and owner_state(metadata, relative) == "repair":
        os.fchown(directory_fd, target_uid, target_gid)


root_fd = os.open(root_path, directory_flags)
try:
    root_metadata = os.fstat(root_fd)
    if (root_metadata.st_dev, root_metadata.st_ino) != (
        expected_device,
        expected_inode,
    ):
        raise UnsafeTree("canonical venv root was replaced")
    root_mount = mount_id(root_fd)
    validate_trust_anchor(root_fd)
    audit_directory(root_fd, allow_repair=True, is_root=True)
    repair_directory(root_fd, is_root=True)
    audit_directory(root_fd, allow_repair=False, is_root=True)
except (OSError, UnsafeTree) as exc:
    print(f"canonical venv ownership repair refused: {exc}", file=sys.stderr)
    raise SystemExit(77)
finally:
    os.close(root_fd)
PY
}

# Repair only root-owned leftovers inside an already validated managed tree.
# Foreign non-root ownership is never seized.
repair_root_owned_managed_tree() {
  local path="$1"

  [[ -d "${path}" && ! -L "${path}" ]] || return 1
  if ! run_privileged_raw chown -R --no-dereference --from=0 \
      "${INSTALL_UID}:${INSTALL_GID}" -- "${path}"; then
    return 1
  fi
  if ! run_privileged_raw chown -R --no-dereference \
      --from="${INSTALL_UID}:0" "${INSTALL_UID}:${INSTALL_GID}" -- "${path}"; then
    return 1
  fi
  verify_install_user_tree_ownership "${path}"
}

repair_project_managed_tree() {
  local path="$1"
  local project_real=""
  local path_real=""

  [[ ! -e "${path}" ]] && return 0
  [[ -d "${path}" && ! -L "${path}" ]] || return 1
  project_real="$(readlink -f "${SCRIPT_DIR}" 2>/dev/null || true)"
  path_real="$(readlink -f "${path}" 2>/dev/null || true)"
  [[ -n "${project_real}" && -n "${path_real}" ]] || return 1
  case "${path_real}" in
    "${project_real}"|"${project_real}/"*)
      # bin/, logs/ and tools/ all ship in the checkout, so this function is
      # reached on every run. Escalate to a privileged chown only when the tree
      # actually holds foreign-owned entries: otherwise a plain ./installer.sh
      # run (no --system-deps) would demand sudo the README does not require.
      if verify_install_user_tree_ownership "${path}"; then
        return 0
      fi
      log "INFO: Repairing foreign-owned entries under ${path}"
      repair_root_owned_managed_tree "${path}"
      ;;
    *)
      # Custom paths are not auto-chowned; ensure_install_user_dir validates
      # their existing owner without seizing caller-managed content.
      return 0
      ;;
  esac
}

# Prepare WPScan's per-user mutable state. Older installer revisions could
# leave root-owned files here even when the directory itself belonged to the
# install user. Repair only root-owned entries in this exact application state
# directory, never arbitrary user-supplied paths.
prepare_wpscan_state() {
  local state_dir="${INSTALL_HOME}/.wpscan"
  local home_real=""
  local state_real=""
  local path=""

  [[ "${INSTALL_UID}" =~ ^[0-9]+$ && "${INSTALL_GID}" =~ ^[0-9]+$ ]] || return 1
  if [[ -e "${state_dir}" && ! -d "${state_dir}" ]] || [[ -L "${state_dir}" ]]; then
    return 1
  fi
  for path in \
    "${state_dir}/db" \
    "${state_dir}/cache" \
    "${state_dir}/cookie_jar.txt"; do
    [[ ! -L "${path}" ]] || return 1
  done

  run_as_install_user mkdir -p "${state_dir}/db" "${state_dir}/cache" 2>/dev/null || true

  [[ -d "${state_dir}" && ! -L "${state_dir}" ]] || return 1
  home_real="$(readlink -f "${INSTALL_HOME}" 2>/dev/null || true)"
  state_real="$(readlink -f "${state_dir}" 2>/dev/null || true)"
  [[ -n "${home_real}" && "${state_real}" == "${home_real}/.wpscan" ]] || return 1

  if ! verify_install_user_tree_ownership "${state_dir}"; then
    log "INFO: Repairing stale root-owned WPScan state under ${state_dir}"
  fi
  if ! repair_root_owned_managed_tree "${state_dir}"; then
    return 1
  fi
  for path in \
    "${state_dir}/db" \
    "${state_dir}/cache" \
    "${state_dir}/cookie_jar.txt"; do
    [[ ! -L "${path}" ]] || return 1
  done
  run_as_install_user mkdir -p "${state_dir}/db" "${state_dir}/cache" 2>/dev/null && \
    run_as_install_user touch "${state_dir}/cookie_jar.txt" 2>/dev/null && \
    run_as_install_user test -w "${state_dir}/db" 2>/dev/null && \
    run_as_install_user test -w "${state_dir}/cache" 2>/dev/null && \
    run_as_install_user test -w "${state_dir}/cookie_jar.txt" 2>/dev/null
}

# Create an installer-managed directory without resolving any target component
# through a pathname after the trusted root has been opened.  The unprivileged
# pass prevents ordinary mkdir from following a user-controlled symlink.  The
# privileged pass is create-only: it accepts only the fixed install-home and
# staged-project roots, refuses symlinks and nested mounts, and fchowns only
# descriptors for directories created by this invocation.
create_install_user_dir_nofollow() {
  local path="$1"
  local create_mode="$2"
  local python_cmd=""
  local -a runner=()

  [[ "${path}" == /* && "${path}" != "/" ]] || return 64
  [[ "${INSTALL_HOME}" == /* && "${INSTALL_HOME}" != "/" ]] || return 64
  [[ "${SCRIPT_DIR}" == /* && "${SCRIPT_DIR}" != "/" ]] || return 64
  [[ "${INSTALL_UID}" =~ ^[0-9]+$ && "${INSTALL_GID}" =~ ^[0-9]+$ ]] || \
    return 64
  [[ "${create_mode}" == "user" || "${create_mode}" == "root-create" ]] || \
    return 64
  python_cmd="$(system_cmd_path python3 || true)"
  [[ -n "${python_cmd}" ]] || return 69

  if [[ "${create_mode}" == "root-create" ]]; then
    runner=(run_privileged_raw)
  else
    runner=(run_as_install_user)
  fi
  "${runner[@]}" "${python_cmd}" -I -S - \
    "${path}" "${INSTALL_HOME}" "${SCRIPT_DIR}" \
    "${INSTALL_UID}" "${INSTALL_GID}" "${create_mode}" <<'PY'
import os
from pathlib import PurePosixPath
import stat
import sys


class UnsafePath(RuntimeError):
    pass


target_text, home_text, project_text, uid_text, gid_text, create_mode = sys.argv[1:]
target_uid = int(uid_text)
target_gid = int(gid_text)
privileged_create = create_mode == "root-create"

if privileged_create:
    if os.geteuid() != 0:
        raise SystemExit("privileged managed-directory creation requires root")
elif os.geteuid() != target_uid:
    raise SystemExit("managed-directory creation did not run as the install user")
if not hasattr(os, "O_PATH") or not hasattr(os, "O_NOFOLLOW"):
    raise SystemExit("Linux no-follow descriptor support is unavailable")
if not os.path.isdir("/proc/self/fdinfo"):
    raise SystemExit("mount-ID validation support is unavailable")


def canonical_absolute_path(text, label):
    parsed = PurePosixPath(text)
    if (
        not parsed.is_absolute()
        or text == "/"
        or str(parsed) != text
        or any(component in ("", ".", "..") for component in parsed.parts[1:])
    ):
        raise UnsafePath(f"invalid {label}")
    return parsed


def is_within(path, root):
    return path.parts[: len(root.parts)] == root.parts


def mount_id(descriptor):
    with open(
        f"/proc/self/fdinfo/{descriptor}",
        "r",
        encoding="ascii",
        errors="strict",
    ) as stream:
        for line in stream:
            if line.startswith("mnt_id:"):
                return int(line.split(":", 1)[1].strip())
    raise UnsafePath("mount ID is unavailable")


path_flags = os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC


def open_absolute_directory(path):
    descriptor = os.open("/", path_flags)
    try:
        for component in path.parts[1:]:
            child = os.open(component, path_flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def same_inode(left, right):
    return (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)


target = canonical_absolute_path(target_text, "target path")
roots = [
    canonical_absolute_path(home_text, "install home"),
    canonical_absolute_path(project_text, "project root"),
]
matching_roots = [root for root in roots if is_within(target, root)]
if not matching_roots:
    raise SystemExit("target is outside installer-managed roots")
trusted_root = max(matching_roots, key=lambda candidate: len(candidate.parts))
relative_parts = target.parts[len(trusted_root.parts) :]
if privileged_create and not relative_parts:
    raise SystemExit("refusing to change the ownership of a managed root")

root_descriptor = open_absolute_directory(trusted_root)
descriptor = os.dup(root_descriptor)
created = []
created_target = False
try:
    root_mount = mount_id(root_descriptor)
    for index, component in enumerate(relative_parts):
        try:
            before = os.stat(component, dir_fd=descriptor, follow_symlinks=False)
        except FileNotFoundError:
            before = None

        if before is not None:
            if privileged_create and index == len(relative_parts) - 1:
                raise UnsafePath("refusing to seize a pre-existing directory")
            if not stat.S_ISDIR(before.st_mode):
                raise UnsafePath(f"non-directory component: {component}")
            child = os.open(component, path_flags, dir_fd=descriptor)
            current = os.fstat(child)
            if not same_inode(before, current):
                os.close(child)
                raise UnsafePath(f"directory changed during traversal: {component}")
        else:
            os.mkdir(component, 0o700, dir_fd=descriptor)
            child = os.open(component, directory_flags, dir_fd=descriptor)
            current = os.fstat(child)
            linked = os.stat(component, dir_fd=descriptor, follow_symlinks=False)
            if (
                not stat.S_ISDIR(linked.st_mode)
                or not same_inode(linked, current)
                or current.st_uid != os.geteuid()
            ):
                os.close(child)
                raise UnsafePath(f"new directory changed before validation: {component}")
            created.append((os.dup(descriptor), component, os.dup(child)))
            if index == len(relative_parts) - 1:
                created_target = True

        if mount_id(child) != root_mount:
            os.close(child)
            raise UnsafePath(f"nested mount at component: {component}")
        os.close(descriptor)
        descriptor = child

    if privileged_create and not created_target:
        raise UnsafePath("privileged creation did not create the target directory")

    # Keep newly created parents root-only until every descendant is ready.
    # Finalize bottom-up so an install user cannot race traversal while root is
    # still creating or changing ownership below that parent.
    for parent_fd, component, child_fd in reversed(created):
        linked = os.stat(component, dir_fd=parent_fd, follow_symlinks=False)
        current = os.fstat(child_fd)
        if not stat.S_ISDIR(linked.st_mode) or not same_inode(linked, current):
            raise UnsafePath(f"new directory was replaced: {component}")
        if privileged_create:
            if current.st_uid != 0:
                raise UnsafePath(f"new directory has an unexpected owner: {component}")
            os.fchown(child_fd, target_uid, target_gid)
        os.fchmod(child_fd, 0o755)
        current = os.fstat(child_fd)
        if privileged_create and (current.st_uid, current.st_gid) != (
            target_uid,
            target_gid,
        ):
            raise UnsafePath(f"ownership verification failed: {component}")
        linked = os.stat(component, dir_fd=parent_fd, follow_symlinks=False)
        if not same_inode(linked, current):
            raise UnsafePath(f"new directory changed after finalization: {component}")

    final = os.fstat(descriptor)
    if not stat.S_ISDIR(final.st_mode):
        raise UnsafePath("target is not a directory")
except (OSError, UnsafePath) as exc:
    print(f"managed-directory creation refused: {exc}", file=sys.stderr)
    raise SystemExit(77)
finally:
    os.close(descriptor)
    os.close(root_descriptor)
    for parent_fd, _component, child_fd in created:
        os.close(parent_fd)
        os.close(child_fd)
PY
}

ensure_install_user_dir() {
  local path="$1"
  local owner="${INSTALL_UID}:${INSTALL_GID}"
  local existed=0
  local managed_scope=0
  local actual_mode=""
  local actual_owner=""

  [[ -n "${path}" ]] || return 1
  [[ ! -L "${path}" ]] || return 1
  if [[ -e "${path}" || -L "${path}" ]]; then
    existed=1
  fi

  case "${path}" in
    "${INSTALL_HOME}"|"${INSTALL_HOME}/"*|"${SCRIPT_DIR}"|"${SCRIPT_DIR}/"*)
      managed_scope=1
      ;;
  esac

  if { [[ "${managed_scope}" -eq 1 ]] && \
         create_install_user_dir_nofollow "${path}" user 2>/dev/null; } || \
     { [[ "${managed_scope}" -eq 0 ]] && \
         run_as_install_user mkdir -p "${path}" 2>/dev/null; }; then
    actual_owner="$(stat -c '%u:%g' -- "${path}" 2>/dev/null || true)"
    actual_mode="$(stat -c '%a' -- "${path}" 2>/dev/null || true)"
    if [[ -d "${path}" && ! -L "${path}" && "${actual_owner}" == "${owner}" ]] && \
      [[ "${actual_mode}" =~ ^[0-7]{3,4}$ ]] && \
      (( (8#${actual_mode} & 0300) == 0300 )) && \
      (( (8#${actual_mode} & 0002) == 0 )); then
      if (( (8#${actual_mode} & 0020) == 0 )) || \
        install_user_primary_group_is_private; then
        run_as_install_user test -w "${path}" 2>/dev/null && return 0
      fi
    fi
  fi

  # Never seize ownership of a pre-existing directory (for example
  # /usr/local/bin supplied through --bin-dir).
  [[ "${existed}" -eq 0 ]] || return 1
  # Privileged creation is restricted to fixed managed roots. Custom paths
  # must be prepared explicitly by their owner; the installer never escalates
  # mkdir/chown for them.
  [[ "${managed_scope}" -eq 1 ]] || return 1
  create_install_user_dir_nofollow "${path}" root-create || return 1
  run_as_install_user test -d "${path}" 2>/dev/null && run_as_install_user test -w "${path}" 2>/dev/null
}

ensure_existing_owner_dir() {
  local path="$1"

  [[ -n "${path}" && ! -L "${path}" ]] || return 1
  if [[ -e "${path}" ]]; then
    [[ -d "${path}" ]]
    return $?
  fi
  run_privileged_raw mkdir -p "${path}"
}

# Record why a preflight directory step failed. Without this the whole chain
# collapsed into one opaque "Preflight: fail (rc=1)" while the summary still
# reported "Failed tools: 0, Warnings: 0".
ensure_dirs_failed() {
  mark_failed "Preflight" "$1"
  return 1
}

# Ensure working directories and log file exist with proper ownership.
ensure_dirs() {
  local log_dir=""
  local log_mode=""
  local log_owner=""

  log_dir="$(dirname "$LOG_FILE")"

  repair_project_managed_tree "${TOOLS_DIR}" || \
    ensure_dirs_failed "cannot repair ownership of ${TOOLS_DIR}" || return 1
  repair_project_managed_tree "${log_dir}" || \
    ensure_dirs_failed "cannot repair ownership of ${log_dir}" || return 1
  ensure_install_user_dir "${TOOLS_DIR}" || \
    ensure_dirs_failed "${TOOLS_DIR} is not usable by ${INSTALL_USER}" || return 1
  ensure_install_user_dir "${log_dir}" || \
    ensure_dirs_failed "${log_dir} is not usable by ${INSTALL_USER}" || return 1

  [[ ! -L "${LOG_FILE}" ]] || \
    ensure_dirs_failed "refusing symlinked log file: ${LOG_FILE}" || return 1
  run_as_install_user touch "$LOG_FILE" 2>/dev/null || \
    ensure_dirs_failed "cannot create log file ${LOG_FILE} as ${INSTALL_USER}" || return 1
  [[ -f "${LOG_FILE}" && ! -L "${LOG_FILE}" ]] || \
    ensure_dirs_failed "log file ${LOG_FILE} is not a regular file" || return 1
  log_owner="$(stat -c '%u:%g' -- "${LOG_FILE}" 2>/dev/null || true)"
  [[ "${log_owner}" == "${INSTALL_UID}:${INSTALL_GID}" ]] || \
    ensure_dirs_failed "log file ${LOG_FILE} is owned by ${log_owner:-unknown}, expected ${INSTALL_UID}:${INSTALL_GID}" || return 1
  log_mode="$(stat -c '%a' -- "${LOG_FILE}" 2>/dev/null || true)"
  [[ "${log_mode}" =~ ^[0-7]{3,4}$ ]] || \
    ensure_dirs_failed "cannot read the mode of ${LOG_FILE}" || return 1
  (( (8#${log_mode} & 0002) == 0 )) || \
    ensure_dirs_failed "log file ${LOG_FILE} is world-writable (mode ${log_mode})" || return 1
  if (( (8#${log_mode} & 0020) != 0 )) && \
    ! install_user_primary_group_is_private; then
    ensure_dirs_failed "log file ${LOG_FILE} is group-writable (mode ${log_mode}) for a shared group"
    return 1
  fi
  acquire_installer_lock || return 1
  run_as_install_user truncate -s 0 "$LOG_FILE" 2>/dev/null || \
    ensure_dirs_failed "cannot truncate log file ${LOG_FILE} as ${INSTALL_USER}" || return 1
  repair_project_managed_tree "${COMPAT_DIR}" || \
    ensure_dirs_failed "cannot repair ownership of ${COMPAT_DIR}" || return 1
  repair_project_managed_tree "${BIN_DIR}" || \
    ensure_dirs_failed "cannot repair ownership of ${BIN_DIR}" || return 1
  ensure_install_user_dir "${COMPAT_DIR}" || \
    ensure_dirs_failed "${COMPAT_DIR} is not usable by ${INSTALL_USER}" || return 1
  ensure_install_user_dir "${BIN_DIR}" || \
    ensure_dirs_failed "${BIN_DIR} is not usable by ${INSTALL_USER}" || return 1
}

acquire_installer_lock() {
  local lock_dir="/run/lock/cms-scanner-installer"
  local lock_metadata=""

  if ! has_cmd flock; then
    mark_failed "Installer lock" "flock is required to prevent concurrent updates"
    return 1
  fi
  if [[ -L "${lock_dir}" ]]; then
    mark_failed "Installer lock" "refusing symlink lock directory: ${lock_dir}"
    return 1
  fi
  if [[ ! -e "${lock_dir}" ]]; then
    # mkdir is an atomic, non-following create. If another process wins the
    # race, validation below accepts only the exact trusted directory shape.
    run_privileged_raw mkdir -m 0755 "${lock_dir}" 2>/dev/null || true
  fi
  lock_metadata="$(stat -c '%u:%a' "${lock_dir}" 2>/dev/null || true)"
  if [[ ! -d "${lock_dir}" || -L "${lock_dir}" || "${lock_metadata}" != "0:755" ]]; then
    mark_failed "Installer lock" "lock directory must be a root-owned mode-755 directory: ${lock_dir}"
    return 1
  fi
  # Flock the verified directory inode itself; no predictable writable lock
  # file is needed in the world-accessible /run/lock parent.
  if ! exec {INSTALL_LOCK_FD}<"${lock_dir}"; then
    mark_failed "Installer lock" "unable to open ${lock_dir}"
    return 1
  fi
  if ! flock -n "${INSTALL_LOCK_FD}"; then
    mark_failed "Installer lock" "another CMS scanner installer process is already running"
    return 1
  fi
}

# Prepare an executable shim beside its destination. Keeping preparation and
# activation separate lets multi-wrapper tools publish all of their shims as
# one rollback-capable transaction.
prepare_wrapper_candidate() {
  local name="$1"
  local body="$2"
  # shellcheck disable=SC2016 # This literal is replaced in generated wrapper bodies.
  local portable_root='${PROJECT_ROOT}'
  local target="${BIN_DIR}/${name}"
  local wrapper_tmp=""

  WRAPPER_CANDIDATE_PATH=""
  WRAPPER_TARGET_PATH=""
  [[ ! -d "${target}" ]] || return 1
  wrapper_tmp="$(mktemp "${target}.new.XXXXXX")" || return 1
  vantage_register_temp_path "${wrapper_tmp}" || {
    rm -f "${wrapper_tmp}"
    return 1
  }
  case "${wrapper_tmp}" in
    "${target}.new."*) ;;
    *) rm -f "${wrapper_tmp}"; return 1 ;;
  esac
  body="${body//${SCRIPT_DIR}/${portable_root}}"
  if ! cat >"${wrapper_tmp}" <<EOF
#!/usr/bin/env bash
# Copyright © 2026 Andrea Bodei — www.andreabodei.com
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

RUNTIME_PASSWD="\$(/usr/bin/getent passwd aiuser 2>/dev/null || true)"
RUNTIME_UID="\$(printf '%s\\n' "\${RUNTIME_PASSWD}" | /usr/bin/cut -d: -f3)"
CANONICAL_HOME="\$(printf '%s\\n' "\${RUNTIME_PASSWD}" | /usr/bin/cut -d: -f6)"
if [[ ! "\${RUNTIME_UID}" =~ ^[1-9][0-9]*$ ||
      "\$(/usr/bin/id -u)" != "\${RUNTIME_UID}" ||
      "\${VANTAGE_DISPATCHED:-0}" != 1 ||
      "\${CANONICAL_HOME}" != /* || "\${CANONICAL_HOME}" == / ||
      "\${HOME:-}" != "\${CANONICAL_HOME}" ]]; then
  echo "CMS scanner tools must run as aiuser through the VANTAGE dispatcher" >&2
  exit 77
fi

WRAPPER_DIR="\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="${SCRIPT_DIR}"
if [[ -f "\${WRAPPER_DIR}/../run_cms_scanner.sh" && -d "\${WRAPPER_DIR}/../tools" ]]; then
  PROJECT_ROOT="\$(cd -- "\${WRAPPER_DIR}/.." && pwd -P)"
fi

CANONICAL_VENV="\${CANONICAL_HOME}/.local/share/vantage/cms_scanner/venv"
CANONICAL_PYTHON="\${CANONICAL_VENV}/bin/python"
export VIRTUAL_ENV="\${CANONICAL_VENV}"
export PATH="\${CANONICAL_VENV}/bin:\${PATH}"

${body}
EOF
  then
    rm -f "${wrapper_tmp}"
    return 1
  fi
  if ! chmod +x "${wrapper_tmp}"; then
    rm -f "${wrapper_tmp}"
    return 1
  fi
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    if ! chown "${INSTALL_UID}:${INSTALL_GID}" "${wrapper_tmp}"; then
      rm -f "${wrapper_tmp}"
      return 1
    fi
  fi
  WRAPPER_CANDIDATE_PATH="${wrapper_tmp}"
  WRAPPER_TARGET_PATH="${target}"
}

# Create an executable shim in ./bin that normalizes invocation details.
create_wrapper() {
  local name="$1"
  local body="$2"
  local wrapper_tmp=""
  local target=""

  prepare_wrapper_candidate "${name}" "${body}" || return 1
  wrapper_tmp="${WRAPPER_CANDIDATE_PATH}"
  target="${WRAPPER_TARGET_PATH}"
  if ! commit_pending_managed_source; then
    rm -f "${wrapper_tmp}"
    return 1
  fi
  if ! mv -fT "${wrapper_tmp}" "${target}"; then
    rm -f "${wrapper_tmp}"
    return 1
  fi
}

create_wrapper_pair() {
  local first_name="$1"
  local first_body="$2"
  local second_name="$3"
  local second_body="$4"
  local first_candidate=""
  local first_target=""
  local second_candidate=""
  local second_target=""
  local first_previous=""
  local second_previous=""
  local had_first=0
  local had_second=0

  prepare_wrapper_candidate "${first_name}" "${first_body}" || return 1
  first_candidate="${WRAPPER_CANDIDATE_PATH}"
  first_target="${WRAPPER_TARGET_PATH}"
  if ! prepare_wrapper_candidate "${second_name}" "${second_body}"; then
    rm -f "${first_candidate}"
    return 1
  fi
  second_candidate="${WRAPPER_CANDIDATE_PATH}"
  second_target="${WRAPPER_TARGET_PATH}"
  first_previous="${first_target}.old.$$"
  second_previous="${second_target}.old.$$"

  if [[ -e "${first_previous}" || -e "${second_previous}" ]] || \
    ! commit_pending_managed_source; then
    rm -f "${first_candidate}" "${second_candidate}"
    return 1
  fi
  if [[ -e "${first_target}" || -L "${first_target}" ]]; then
    if ! mv -fT "${first_target}" "${first_previous}"; then
      rm -f "${first_candidate}" "${second_candidate}"
      return 1
    fi
    had_first=1
  fi
  if [[ -e "${second_target}" || -L "${second_target}" ]]; then
    if ! mv -fT "${second_target}" "${second_previous}"; then
      [[ "${had_first}" -eq 0 ]] || mv -fT "${first_previous}" "${first_target}" || true
      rm -f "${first_candidate}" "${second_candidate}"
      return 1
    fi
    had_second=1
  fi

  if ! mv -fT "${first_candidate}" "${first_target}"; then
    [[ "${had_first}" -eq 0 ]] || mv -fT "${first_previous}" "${first_target}" || true
    [[ "${had_second}" -eq 0 ]] || mv -fT "${second_previous}" "${second_target}" || true
    rm -f "${first_candidate}" "${second_candidate}"
    return 1
  fi
  if ! mv -fT "${second_candidate}" "${second_target}"; then
    rm -f "${first_target}" "${second_candidate}"
    [[ "${had_first}" -eq 0 ]] || mv -fT "${first_previous}" "${first_target}" || true
    [[ "${had_second}" -eq 0 ]] || mv -fT "${second_previous}" "${second_target}" || true
    return 1
  fi
  [[ "${had_first}" -eq 0 ]] || rm -f "${first_previous}" || return 1
  [[ "${had_second}" -eq 0 ]] || rm -f "${second_previous}" || return 1
}

# Build compatibility runtimes beside their live path. Callers patch and smoke
# test RUNTIME_CANDIDATE before rollback-capable activation, so a normal
# validation failure can restore the previously working runtime.
prepare_runtime_candidate() {
  local source_dir="$1"
  local live_dir="$2"
  local candidate=""

  RUNTIME_CANDIDATE=""
  [[ -n "${source_dir}" && -d "${source_dir}" && -n "${live_dir}" && "${live_dir}" != "/" ]] || return 1
  run_user_cmd mkdir -p "$(dirname "${live_dir}")" || return 1
  candidate="$(capture_user_cmd mktemp -d "${live_dir}.new.XXXXXX" 2>/dev/null || true)"
  [[ -z "${candidate}" ]] || vantage_register_temp_path "${candidate}" || return 1
  case "${candidate}" in
    "${live_dir}.new."*) ;;
    *) return 1 ;;
  esac
  if [[ ! -d "${candidate}" ]] || ! run_user_cmd cp -a "${source_dir}/." "${candidate}/"; then
    run_user_cmd rm -rf "${candidate}" || true
    return 1
  fi
  run_user_cmd rm -rf "${candidate}/.git" || {
    run_user_cmd rm -rf "${candidate}" || true
    return 1
  }
  RUNTIME_CANDIDATE="${candidate}"
}

discard_runtime_candidate() {
  local candidate="$1"
  local live_dir="$2"

  case "${candidate}" in
    "${live_dir}.new."*) run_user_cmd rm -rf "${candidate}" ;;
    *) return 1 ;;
  esac
}

activate_runtime_candidate() {
  local candidate="$1"
  local live_dir="$2"
  local previous="${live_dir}.old.$$"

  RUNTIME_PREVIOUS=""
  case "${candidate}" in
    "${live_dir}.new."*) ;;
    *) return 1 ;;
  esac
  [[ -d "${candidate}" && -n "${live_dir}" && "${live_dir}" != "/" && ! -e "${previous}" ]] || return 1

  if [[ -e "${live_dir}" || -L "${live_dir}" ]]; then
    run_user_cmd mv -T "${live_dir}" "${previous}" || return 1
    RUNTIME_PREVIOUS="${previous}"
  fi
  if ! run_user_cmd mv -T "${candidate}" "${live_dir}"; then
    if [[ -n "${RUNTIME_PREVIOUS}" ]]; then
      run_user_cmd mv -T "${RUNTIME_PREVIOUS}" "${live_dir}" || true
    fi
    return 1
  fi
}

# A previous compatibility runtime can contain root-owned bytecode created by a
# scanner that was once invoked with sudo. User-level removal is attempted
# first; privilege is used only for a real, PID-suffixed rollback directory
# under the installer-managed compatibility tree or canonical Python venv.
remove_previous_runtime_tree() {
  local previous="$1"
  local live_dir="$2"
  local compat_real=""
  local venv_real=""
  local live_real=""
  local previous_real=""
  local previous_suffix=""
  local real_suffix=""
  local relative_previous=""
  local trusted_real=""
  local trusted_root=0

  [[ -n "${previous}" && -n "${live_dir}" ]] || return 1
  case "${previous}" in
    "${live_dir}.old."*) ;;
    *) return 1 ;;
  esac
  previous_suffix="${previous#"${live_dir}.old."}"
  [[ "${previous_suffix}" =~ ^[0-9]+$ ]] || return 1
  [[ -e "${previous}" || -L "${previous}" ]] || return 0
  [[ -d "${previous}" && ! -L "${previous}" ]] || return 1

  compat_real="$(readlink -f "${COMPAT_DIR}" 2>/dev/null || true)"
  venv_real="$(readlink -f "${VENV_DIR}" 2>/dev/null || true)"
  live_real="$(readlink -m "${live_dir}" 2>/dev/null || true)"
  previous_real="$(readlink -m "${previous}" 2>/dev/null || true)"
  if [[ -n "${compat_real}" && "${compat_real}" != "/" && \
        "${live_real}" == "${compat_real}/"* ]]; then
    trusted_real="${compat_real}"
    trusted_root=1
  elif [[ -n "${venv_real}" && "${venv_real}" != "/" && \
          "${live_real}" == "${venv_real}/"* ]]; then
    trusted_real="${venv_real}"
    trusted_root=1
  fi
  [[ "${trusted_root}" -eq 1 ]] || return 1
  case "${previous_real}" in
    "${live_real}.old."*) ;;
    *) return 1 ;;
  esac
  real_suffix="${previous_real#"${live_real}.old."}"
  [[ "${real_suffix}" =~ ^[0-9]+$ ]] || return 1
  [[ "$(dirname "${previous_real}")" == "$(dirname "${live_real}")" ]] || return 1
  relative_previous="${previous_real#"${trusted_real}/"}"
  [[ -n "${relative_previous}" && "${relative_previous}" != "${previous_real}" ]] || return 1

  if run_as_install_user rm -rf -- "${previous}" 2>/dev/null; then
    return 0
  fi
  [[ -e "${previous}" || -L "${previous}" ]] || return 0
  [[ -d "${previous}" && ! -L "${previous}" ]] || return 1
  [[ "$(readlink -m "${previous}" 2>/dev/null || true)" == "${previous_real}" ]] || return 1

  log "INFO: Removing root-owned stale rollback runtime ${previous}"
  remove_managed_tree_privileged "${trusted_real}" "${relative_previous}"
}

finalize_runtime_activation() {
  local previous="$1"
  local live_dir="$2"

  [[ -z "${previous}" ]] && return 0
  case "${previous}" in
    "${live_dir}.old."*) remove_previous_runtime_tree "${previous}" "${live_dir}" ;;
    *) return 1 ;;
  esac
}

rollback_runtime_activation() {
  local previous="$1"
  local live_dir="$2"
  local failed="${live_dir}.failed.$$"

  if [[ -z "${previous}" ]]; then
    [[ -d "${live_dir}" && -n "${live_dir}" && "${live_dir}" != "/" ]] || return 1
    run_user_cmd rm -rf "${live_dir}"
    return $?
  fi
  [[ -d "${previous}" && -d "${live_dir}" && ! -e "${failed}" ]] || return 1
  case "${previous}" in
    "${live_dir}.old."*) ;;
    *) return 1 ;;
  esac
  run_user_cmd mv -T "${live_dir}" "${failed}" || return 1
  if ! run_user_cmd mv -T "${previous}" "${live_dir}"; then
    run_user_cmd mv -T "${failed}" "${live_dir}" || true
    return 1
  fi
  run_user_cmd rm -rf "${failed}"
}

# Existing source checkouts are user workspaces. Leave them untouched and build
# a clean managed snapshot that is activated only after tool validation.
activate_managed_upstream_checkout() {
  local repo_url="$1"
  local tool_label="$2"
  local remote_branch="${3:-}"
  local record_update="${4:-1}"
  local live_dir="${COMPAT_DIR}/upstream/${tool_label}"
  local candidate=""
  local commit=""
  local -a clone_args=(clone --depth 1)

  [[ "${tool_label}" =~ ^[A-Za-z0-9._-]+$ && -n "${repo_url}" ]] || return 1
  run_user_cmd mkdir -p "$(dirname "${live_dir}")" || return 1
  candidate="$(capture_user_cmd mktemp -d "${live_dir}.new.XXXXXX" 2>/dev/null || true)"
  [[ -z "${candidate}" ]] || vantage_register_temp_path "${candidate}" || return 1
  case "${candidate}" in
    "${live_dir}.new."*) ;;
    *) return 1 ;;
  esac
  if [[ -n "${remote_branch}" ]]; then
    clone_args+=(--branch "${remote_branch}" --single-branch)
  fi
  clone_args+=("${repo_url}" "${candidate}")
  if ! run_git_user_cmd "${clone_args[@]}"; then
    run_user_cmd rm -rf "${candidate}" || true
    return 1
  fi
  commit="$(capture_user_cmd git -C "${candidate}" rev-parse HEAD 2>/dev/null || true)"
  if [[ ! "${commit}" =~ ^[0-9a-fA-F]{40,64}$ ]] ||
    ! printf '%s\n' "${commit}" |
      run_as_install_user tee "${candidate}/.vantage-upstream-commit" >/dev/null; then
    run_user_cmd rm -rf "${candidate}" || true
    return 1
  fi
  if ! run_user_cmd rm -rf "${candidate}/.git"; then
    if [[ -d "${candidate}" ]]; then
      discard_runtime_candidate "${candidate}" "${live_dir}" || true
    fi
    return 1
  fi
  PENDING_MANAGED_LIVE="${live_dir}"
  PENDING_MANAGED_PREVIOUS=""
  PENDING_MANAGED_CANDIDATE="${candidate}"
  PENDING_MANAGED_COMMITTED=0
  EFFECTIVE_REPO_DIR="${candidate}"
  EFFECTIVE_WRAPPER_REPO_DIR="${live_dir}"
  if [[ "${record_update}" -eq 1 ]]; then
    PENDING_MANAGED_UPDATE_LABEL="${tool_label} source (managed upstream ${commit:0:12}; checkout preserved)"
  fi
}

commit_pending_managed_source() {
  [[ -n "${PENDING_MANAGED_LIVE}" ]] || return 0
  [[ "${PENDING_MANAGED_COMMITTED}" -eq 0 ]] || return 0
  if ! activate_runtime_candidate \
    "${PENDING_MANAGED_CANDIDATE}" "${PENDING_MANAGED_LIVE}"; then
    return 1
  fi
  PENDING_MANAGED_PREVIOUS="${RUNTIME_PREVIOUS}"
  PENDING_MANAGED_COMMITTED=1
}

clear_pending_managed_source() {
  PENDING_MANAGED_LIVE=""
  PENDING_MANAGED_PREVIOUS=""
  PENDING_MANAGED_CANDIDATE=""
  PENDING_MANAGED_COMMITTED=0
  PENDING_MANAGED_UPDATE_LABEL=""
}

settle_pending_managed_source() {
  local outcome="$1"
  local live_dir="${PENDING_MANAGED_LIVE}"
  local previous="${PENDING_MANAGED_PREVIOUS}"
  local candidate="${PENDING_MANAGED_CANDIDATE}"
  local committed="${PENDING_MANAGED_COMMITTED}"
  local update_label="${PENDING_MANAGED_UPDATE_LABEL}"

  [[ -n "${live_dir}" ]] || return 0
  if [[ "${outcome}" == "success" ]]; then
    if ! commit_pending_managed_source; then
      discard_runtime_candidate "${candidate}" "${live_dir}" || true
      [[ -z "${update_label}" ]] || \
        mark_update_failed "${update_label}" "validated snapshot could not be activated"
      clear_pending_managed_source
      return 1
    fi
    previous="${PENDING_MANAGED_PREVIOUS}"
    finalize_runtime_activation "${previous}" "${live_dir}" || \
      warn "Managed source: previous snapshot remains at ${previous}"
    [[ -z "${update_label}" ]] || mark_updated "${update_label}"
  elif [[ "${committed}" -eq 0 ]]; then
    if ! discard_runtime_candidate "${candidate}" "${live_dir}"; then
      warn "Managed source: unable to discard rejected candidate ${candidate}"
    fi
    if [[ "${outcome}" == "skipped" ]]; then
      [[ -z "${update_label}" ]] || \
        mark_update_skipped "${update_label}" "tool was skipped; candidate discarded"
    else
      [[ -z "${update_label}" ]] || \
        mark_update_failed "${update_label}" "tool install/validation failed; candidate was not activated"
    fi
  elif rollback_runtime_activation "${previous}" "${live_dir}"; then
    if [[ "${outcome}" == "skipped" ]]; then
      if [[ -n "${previous}" ]]; then
        [[ -z "${update_label}" ]] || \
          mark_update_skipped "${update_label}" "tool was skipped; previous source restored"
      else
        [[ -z "${update_label}" ]] || \
          mark_update_skipped "${update_label}" "tool was skipped; new managed source removed"
      fi
    else
      if [[ -n "${previous}" ]]; then
        [[ -z "${update_label}" ]] || \
          mark_update_failed "${update_label}" "tool install/validation failed; previous source restored"
      else
        [[ -z "${update_label}" ]] || \
          mark_update_failed "${update_label}" "tool install/validation failed; new managed source removed"
      fi
    fi
  else
    warn "Managed source: rejected source rollback failed; state is uncertain at ${live_dir}"
    [[ -z "${update_label}" ]] || \
      mark_update_failed "${update_label}" "tool install/validation failed and source rollback failed"
  fi
  clear_pending_managed_source
}

cms_paths_are_usable() {
  local path=""

  for path in "$@"; do
    [[ -x "${path}" ]] || return 1
  done
}

# Resolve the same user-level RubyGems home used by the published
# Fingerprinter wrapper. Never use root's gem directory for an unprivileged
# install user.
fingerprinter_gem_home() {
  local gem_home=""

  if [[ -n "${USER_GEM_BIN}" && "${USER_GEM_BIN}" == */bin ]]; then
    gem_home="${USER_GEM_BIN%/bin}"
  else
    gem_home="$(capture_user_cmd ruby -r rubygems -e 'print Gem.user_dir' 2>/dev/null || true)"
  fi
  [[ -n "${gem_home}" && "${gem_home}" == /* && "${gem_home}" != "/" ]] || return 1
  printf '%s\n' "${gem_home}"
}

# Validate the exact reviewed bundle in a staged or live Fingerprinter runtime.
# The canonical lockfile is project controlled because upstream ignores
# Gemfile.lock and therefore cannot provide a reproducible lock on a clean clone.
fingerprinter_bundle_is_usable() {
  local runtime_src="${1:-${COMPAT_DIR}/fingerprinter-src}"
  local gem_user_dir=""
  local bundle_cmd=""

  [[ -d "${runtime_src}" && ! -L "${runtime_src}" ]] || return 1
  [[ -f "${runtime_src}/Gemfile" && ! -L "${runtime_src}/Gemfile" ]] || return 1
  [[ -f "${runtime_src}/Gemfile.lock" && ! -L "${runtime_src}/Gemfile.lock" ]] || return 1
  [[ -f "${FINGERPRINTER_LOCKFILE}" && ! -L "${FINGERPRINTER_LOCKFILE}" ]] || return 1
  run_as_install_user cmp -s -- \
    "${FINGERPRINTER_LOCKFILE}" "${runtime_src}/Gemfile.lock" || return 1

  gem_user_dir="$(fingerprinter_gem_home || true)"
  [[ -n "${gem_user_dir}" ]] || return 1
  bundle_cmd="${gem_user_dir}/bin/bundle"
  [[ -x "${bundle_cmd}" ]] || return 1

  run_as_install_user env \
    -u BUNDLE_BIN_PATH -u BUNDLE_GEMFILE -u RUBYGEMS_GEMDEPS \
    HOME="${INSTALL_HOME}" \
    GEM_HOME="${gem_user_dir}" \
    GEM_PATH="${gem_user_dir}${GEM_PATH:+:${GEM_PATH}}" \
    BUNDLE_GEMFILE="${runtime_src}/Gemfile" \
    BUNDLE_FROZEN=true \
    BUNDLE_IGNORE_CONFIG=true \
    RUBYOPT="-W0 -W:no-deprecated" \
    FINGERPRINTER_BUNDLER_VERSION="${FINGERPRINTER_BUNDLER_VERSION}" \
    ruby -e \
      'gem "bundler", ENV.fetch("FINGERPRINTER_BUNDLER_VERSION"); require "bundler/setup"; exit 0'
}

# A current source revision is skippable only when the reviewed runtime bundle
# and the actual published entrypoint both work in the install-user context.
fingerprinter_runtime_is_usable() {
  local runtime_src="${1:-${COMPAT_DIR}/fingerprinter-src}"
  local wrapper="${2:-${BIN_DIR}/fingerprinter}"

  [[ -x "${wrapper}" && ! -L "${wrapper}" ]] || return 1
  fingerprinter_bundle_is_usable "${runtime_src}" || return 1
  run_as_install_user env VANTAGE_DISPATCHED=1 \
    "${wrapper}" --help >/dev/null 2>&1
}

# AutoWPScan publishes no executable wrapper: its artifact is the patched
# main.py under the compat runtime directory, loaded in-process by
# run_cms_scanner.sh. Probe that artifact the way fingerprinter_runtime_is_usable
# probes its wrapper, so the skip guard can only fire on a working install.
cms_repair_autowpscan_environment() {
  local runtime="${1}"
  [[ -f "${runtime}/main.py" ]] || return 0
  run_user_cmd "${VENV_DIR}/bin/python" - "${runtime}/main.py" <<'PY_AUTOWPSCAN_ENV'
import os
from pathlib import Path
import stat
import sys
import tempfile

path = Path(sys.argv[1])
metadata = path.lstat()
if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
    raise SystemExit(f"Unsupported AutoWPScan runtime: {path}")
original = path.read_bytes()
legacy = b'    result = subprocess.run(command, shell=False, capture_output=False)'
modern = b'''    # VANTAGE_AUTOWPSCAN_OPTIONAL_TOKEN_ENV_V1
    # WPScan treats an exported empty Ruby string as a configured API token.
    scan_environment = os.environ.copy()
    if not scan_environment.get('WPSCAN_API_TOKEN', '').strip():
        scan_environment.pop('WPSCAN_API_TOKEN', None)
    result = subprocess.run(command, shell=False, capture_output=False, env=scan_environment)'''
if original.count(legacy) + original.count(modern) != 1:
    raise SystemExit(f"Unsupported AutoWPScan subprocess call: {path}")
repaired = original.replace(legacy, modern)
compile(repaired, str(path), "exec")
if repaired != original:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".autowpscan-env-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(repaired)
            os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        print(f"Repaired AutoWPScan optional-token environment: {path}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
PY_AUTOWPSCAN_ENV
}

autowpscan_runtime_is_usable() {
  local runtime_src="${COMPAT_DIR}/autowpscan-src"
  local main_py="${runtime_src}/main.py"

  [[ -f "${main_py}" && ! -L "${main_py}" ]] || return 1
  grep -qF '# VANTAGE_AUTOWPSCAN_OPTIONAL_TOKEN_ENV_V1' "${main_py}" || return 1
  [[ -x "${VENV_DIR}/bin/python" ]] || return 1
  run_as_install_user env AUTOWPSCAN_RUNTIME="${runtime_src}" \
    "${VENV_DIR}/bin/python" -c \
    'import importlib.util,os,pathlib; p=pathlib.Path(os.environ["AUTOWPSCAN_RUNTIME"])/"main.py"; s=importlib.util.spec_from_file_location("autowpscan_health_check",p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); assert callable(m.run_wpscan); assert callable(m.parse_wpscan_result)' \
    >/dev/null 2>&1
}

# Source freshness is not runtime health. The CMS-scoped venv may be
# rebuilt independently of these checkout-local wrappers, leaving a current Git
# snapshot pointing at missing Python packages.  Keep these probes silent and
# bounded because they run before deciding whether an installer may be skipped.
cms_runtime_probe_is_usable() {
  local accepted_statuses="$1"
  local expected_pattern="$2"
  shift 2
  local output=""
  local rc=0
  local -a probe_cmd=("$@")

  [[ "${#probe_cmd[@]}" -gt 0 ]] || return 1
  if has_cmd timeout; then
    probe_cmd=(timeout --signal=TERM --kill-after=5s "${SMOKE_TEST_TIMEOUT}" \
      "${probe_cmd[@]}")
  fi
  if output="$(capture_user_cmd env VANTAGE_DISPATCHED=1 \
    "${probe_cmd[@]}" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi

  [[ ",${accepted_statuses}," == *",${rc},"* ]] &&
    grep -Eiq -- "${expected_pattern}" <<<"${output}"
}

cmsmap_runtime_is_usable() {
  local cmsmap_conf=""
  local candidate=""
  local data_dir=""

  [[ -x "${BIN_DIR}/cmsmap" && -x "${VENV_DIR}/bin/cmsmap" &&
     -x "${VENV_DIR}/bin/python" ]] || return 1
  for candidate in \
    "${VENV_DIR}"/lib/python*/site-packages/cmsmap/cmsmap.conf; do
    [[ -f "${candidate}" && ! -L "${candidate}" ]] || continue
    cmsmap_conf="${candidate}"
    break
  done
  [[ -n "${cmsmap_conf}" ]] || return 1
  data_dir="$(dirname -- "${cmsmap_conf}")/data"
  [[ -d "${data_dir}" && ! -L "${data_dir}" ]] || return 1

  capture_user_cmd env CMSMAP_DATA_DIR="${data_dir}" \
    "${VENV_DIR}/bin/python" - <<'PY' >/dev/null 2>&1 || return 1
import os
from pathlib import Path

data = Path(os.environ["CMSMAP_DATA_DIR"])
required = [
    "wp_plugins_small.txt", "wp_themes_small.txt",
    "joo_plugins_small.txt", "dru_plugins_small.txt",
    "wp_versions.txt", "joo_versions.txt", "dru_versions.txt", "moo_versions.txt",
    "wp_defaultfiles.txt", "wp_defaultfolders.txt",
    "joo_defaultfiles.txt", "joo_defaultfolders.txt",
    "dru_defaultfiles.txt", "dru_defaultfolders.txt",
    "moo_defaultfiles.txt", "moo_defaultfolders.txt",
]
if any(not (data / name).is_file() or (data / name).stat().st_size == 0 for name in required):
    raise SystemExit(1)
PY

  cms_runtime_probe_is_usable "0,1" \
    '^[[:space:]]*usage:[[:space:]]+cmsmap|CMSmap tool v' \
    "${BIN_DIR}/cmsmap" -h
}

cms_repair_drupwn_banners() {
  # Only the known upstream welcome literal is rewritten. Validate every
  # candidate before publishing any change, including the legacy shared CLI.
  local candidate="" present=0
  for candidate in "$@"; do
    [[ ! -e "$candidate" && ! -L "$candidate" ]] || present=1
  done
  (( present == 1 )) || return 0
  run_user_cmd "${VENV_DIR}/bin/python" - "$@" <<'PY_DRUPWN_BANNER'
import ast
import os
from pathlib import Path
import stat
import sys
import tempfile
import warnings

legacy = r'''    print("""
        ____
       / __ \_______  ______ _      ______
      / / / / ___/ / / / __ \ | /| / / __ \\
     / /_/ / /  / /_/ / /_/ / |/ |/ / / / /
    /_____/_/   \__,_/ .___/|__/|__/_/ /_/
                     /_/
    """)'''
with warnings.catch_warnings():
    warnings.simplefilter("ignore", SyntaxWarning)
    value = ast.literal_eval(legacy.strip()[6:-1])
replacement = "    print(" + repr(value) + ")"
pending = []
for argument in sys.argv[1:]:
    path = Path(argument)
    if not path.exists() and not path.is_symlink():
        continue
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise SystemExit(f"Unsupported Drupwn entrypoint type: {path}")
    source = path.read_text(encoding="utf-8")
    if ('from engine.Dispatcher import Dispatcher' not in source
            or 'Copyright 2018, ImmunIT' not in source
            or source.count('def welcome():') != 1):
        raise SystemExit(f"Unrecognized Drupwn entrypoint: {path}")
    if source.count(legacy) == 1:
        candidate = source.replace(legacy, replacement, 1)
    elif source.count(replacement) == 1 and legacy not in source:
        candidate = source
    else:
        raise SystemExit(f"Unsupported Drupwn welcome banner: {path}")
    with warnings.catch_warnings():
        warnings.simplefilter("error", SyntaxWarning)
        compile(candidate, str(path), "exec", dont_inherit=True)
    if candidate != source:
        pending.append((path, metadata, candidate))
for path, metadata, candidate in pending:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                         prefix=".drupwn-banner.",
                                         dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(candidate)
            os.fchmod(handle.fileno(), stat.S_IMODE(metadata.st_mode))
        os.replace(temporary, path)
        temporary = None
        print(f"Repaired Drupwn welcome banner: {path}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
PY_DRUPWN_BANNER
}

drupwn_runtime_is_usable() {
  [[ -x "${BIN_DIR}/drupwn" ]] || return 1
  cms_runtime_probe_is_usable "0" 'usage:.*drupwn|drupwn' \
    "${BIN_DIR}/drupwn" --help
}

cms_cmsscan_server_wrapper_body() {
  local runtime_src="$1"
  local adapter_path="${BIN_DIR}${USER_GEM_BIN:+:${USER_GEM_BIN}}"
  printf '# VANTAGE_CMSSCAN_GUNICORN_V1\nexport PATH=%q:"${CANONICAL_VENV}/bin":"${PATH}"\n' "${adapter_path}"
  printf 'cd %q && exec "${CANONICAL_PYTHON}" -m gunicorn --bind 127.0.0.1:5000 --workers 1 --access-logfile - --error-logfile - app:app "$@"\n' "${runtime_src}"
}

cmsscan_runtime_is_usable() {
  local runtime_src="${COMPAT_DIR}/cmsscan-src"

  [[ -d "${runtime_src}" && ! -L "${runtime_src}" &&
     -x "${BIN_DIR}/cmsscan-python" &&
     -x "${BIN_DIR}/cmsscan-server" ]] || return 1
  grep -qF '# VANTAGE_CMSSCAN_GUNICORN_V1' "${BIN_DIR}/cmsscan-server" || return 1
  cms_runtime_probe_is_usable "0" 'gunicorn[[:space:]]+\(version|gunicorn[[:space:]]+[0-9]' \
    "${BIN_DIR}/cmsscan-server" --version || return 1
  cms_runtime_probe_is_usable "0" 'CMSScan server runtime OK' \
    env CMSSCAN_RUNTIME="${runtime_src}" "${BIN_DIR}/cmsscan-python" -c \
    'import os,runpy,sys,threading; r=os.environ["CMSSCAN_RUNTIME"]; os.chdir(r); sys.path.insert(0,r); import db; from plugins import scanners; db.init_db=lambda app: None; scanners.update_wpscan=lambda: None; threading.Thread.start=lambda self: None; ns=runpy.run_path(os.path.join(r,"app.py"),run_name="cmsscan_server_health_check"); assert callable(scanners.find_cms) and hasattr(ns["app"],"route"); print("CMSScan server runtime OK")'
}

cms_repair_clusterd_runtime() {
  local runtime="${1}"
  [[ -d "${runtime}" ]] || return 0
  run_user_cmd "${VENV_DIR}/bin/python" - "${runtime}" <<'PY_CLUSTERD_RUNTIME'
import os
from pathlib import Path
import stat
import sys
import tempfile
import warnings

base = Path(sys.argv[1])
marker = b"# VANTAGE_CLUSTERD_STDLIB_PLATFORM_V1"
platform_shim = b'''
# VANTAGE_CLUSTERD_STDLIB_PLATFORM_V1
# The legacy all-directory PYTHONPATH includes src/platform.  Load Python's
# platform module before application/dependency imports can select that package.
import sysconfig as _clusterd_sysconfig
_clusterd_platform_path = os.path.join(_clusterd_sysconfig.get_path("stdlib"), "platform.py")
_clusterd_platform_spec = importlib.util.spec_from_file_location("platform", _clusterd_platform_path)
if _clusterd_platform_spec is None or _clusterd_platform_spec.loader is None:
    raise ImportError("Clusterd cannot locate the Python standard platform module")
_clusterd_platform_module = importlib.util.module_from_spec(_clusterd_platform_spec)
sys.modules["platform"] = _clusterd_platform_module
_clusterd_platform_spec.loader.exec_module(_clusterd_platform_module)
'''
changes = []
targets = {
    "src/platform/tomcat/interfaces.py": [
        b'findall("Apache Tomcat/(.*)<", response.content)',
        b'findall("Apache Tomcat Version (.*?)\\n", response.content)',
        b'findall("<h3>(.*?)</h3>", response.content)',
    ],
    "src/platform/tomcat/fingerprints/Tomcat4.py": [
        b'findall("Apache Tomcat/(.*?)\\n", response.content)',
    ],
    "src/platform/tomcat/fingerprints/Tomcat41.py": [
        b'findall("Apache Tomcat/(.*?)\\n", response.content)',
    ],
    "src/platform/tomcat/fingerprints/Tomcat33Admin.py": [
        b'findall("Tomcat Administration Tools", response.content)',
    ],
}
for relative, patterns in targets.items():
    path = base / relative
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise SystemExit(f"Unsupported Clusterd source file: {path}")
    original = path.read_bytes()
    repaired = original
    for legacy in patterns:
        modern = legacy.replace(b"response.content", b"response.text")
        if repaired.count(legacy) + repaired.count(modern) != 1:
            raise SystemExit(f"Unsupported Clusterd text fingerprint: {path}")
        repaired = repaired.replace(legacy, modern)
    changes.append((path, metadata, original, repaired))
path = base / "src/core/sitecustomize.py"
metadata = path.lstat()
if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
    raise SystemExit(f"Unsupported Clusterd loader shim: {path}")
original = path.read_bytes()
if b"class _LoaderShim:" not in original:
    raise SystemExit(f"Unsupported Clusterd loader shim contents: {path}")
repaired = original if marker in original else original.rstrip(b"\r\n") + b"\n" + platform_shim
changes.append((path, metadata, original, repaired))
# Validate every source before publishing any file; binary HTTP/hash consumers
# elsewhere retain response.content unchanged.
for path, metadata, original, repaired in changes:
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", SyntaxWarning)
        compile(repaired, str(path), "exec")
for path, metadata, original, repaired in changes:
    if original == repaired:
        continue
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".clusterd-compat-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(repaired)
            os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        print(f"Repaired Clusterd Python3 runtime: {path}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
PY_CLUSTERD_RUNTIME
}

clusterd_runtime_is_usable() {
  [[ -x "${BIN_DIR}/clusterd" ]] || return 1
  grep -qF '# VANTAGE_CLUSTERD_STDLIB_PLATFORM_V1' \
    "${COMPAT_DIR}/clusterd-src/src/core/sitecustomize.py" || return 1
  cms_runtime_probe_is_usable "0" 'usage:.*clusterd|clusterd' \
    "${BIN_DIR}/clusterd" --help
}

wpforce_runtime_is_usable() {
  [[ -x "${BIN_DIR}/wpforce" ]] || return 1
  cms_runtime_probe_is_usable "0" 'usage:|WPForce|wpforce' \
    "${BIN_DIR}/wpforce" -h
}

cms_repair_wpseku_json() {
  local candidate="" present=0
  for candidate in "$@"; do
    [[ ! -e "$candidate/modules/discovery/users/wpusers.py" &&
       ! -L "$candidate/modules/discovery/users/wpusers.py" ]] || present=1
  done
  (( present == 1 )) || return 0
  run_user_cmd "${VENV_DIR}/bin/python" - "$@" <<'PY_WPSEKU_JSON'
import os
from pathlib import Path
import stat
import sys
import tempfile
import warnings

legacy = b'loads(resp.content, encoding="utf-8")'
modern = b'loads(resp.content)'
pending = []
for argument in sys.argv[1:]:
    path = Path(argument) / "modules/discovery/users/wpusers.py"
    if not path.exists() and not path.is_symlink():
        continue
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise SystemExit(f"Unsupported WPSeku JSON module type: {path}")
    source = path.read_bytes()
    if (b'from json import loads' not in source or b'class wpusers(Request):' not in source
            or b'def wpjson(self):' not in source or b'def wpjson2(self):' not in source
            or source.count(legacy) + source.count(modern) != 2):
        raise SystemExit(f"Unsupported WPSeku JSON parser source: {path}")
    # The local variable named json shadows the module in this legacy except
    # clause. JSONDecodeError is a ValueError; malformed fallback responses
    # must return no users rather than raising UnboundLocalError.
    legacy_exception = b'except json.decoder.JSONDecodeError:'
    modern_exception = b'except ValueError:'
    if source.count(legacy_exception) + source.count(modern_exception) > 1:
        raise SystemExit(f"Unsupported WPSeku JSON exception source: {path}")
    candidate = source.replace(legacy, modern).replace(legacy_exception, modern_exception)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", SyntaxWarning)
        compile(candidate, str(path), "exec", dont_inherit=True)
    if candidate != source:
        pending.append((path, metadata, candidate))
for path, metadata, candidate in pending:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="wb", prefix=".wpseku-json.",
                                         dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(candidate)
            os.fchmod(handle.fileno(), stat.S_IMODE(metadata.st_mode))
        os.replace(temporary, path)
        temporary = None
        print(f"Repaired WPSeku JSON parser compatibility: {path}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
PY_WPSEKU_JSON
}

wpseku_runtime_is_usable() {
  [[ -x "${BIN_DIR}/wpseku" ]] || return 1
  cms_runtime_probe_is_usable "0" 'usage:|WPSeku|wpseku' \
    "${BIN_DIR}/wpseku" --help
}

cms_wrapper_has_scoped_syntaxwarning_filter() {
  local wrapper="$1"

  [[ -f "${wrapper}" && ! -L "${wrapper}" ]] || return 1
  grep -Fq 'PYTHONWARNINGS=ignore::SyntaxWarning' "${wrapper}"
}

cms_user_gem_is_current() {
  local gem_name="$1"
  local executable="$2"
  local installed=""
  local online=""

  vantage_force_requested && return 1
  [[ -x "${executable}" ]] || return 1
  installed="$(capture_user_cmd ruby -r rubygems -e \
    's=Gem::Specification.find_all_by_name(ARGV.fetch(0)).max_by(&:version); abort unless s; print s.version' \
    "${gem_name}" 2>/dev/null || true)"
  online="$(capture_user_cmd gem list --remote --exact "${gem_name}" 2>/dev/null |
    sed -nE "s/^${gem_name//./\\.} \\(([^, )]+).*/\\1/p" |
    head -n 1)"
  [[ -n "${installed}" && -n "${online}" ]] || return 1
  capture_user_cmd ruby -r rubygems -e \
    'exit(Gem::Version.new(ARGV.fetch(0)) >= Gem::Version.new(ARGV.fetch(1)) ? 0 : 1)' \
    "${installed}" "${online}" >/dev/null 2>&1
}

cms_git_tool_is_current() {
  local tool_name="$1"
  local repo_url="$2"
  local repo_dir="$3"
  local source_label="$4"
  shift 4
  local managed_dir="${COMPAT_DIR}/upstream/${source_label}"
  local checkout="${repo_dir}"

  vantage_force_requested && return 1
  cms_paths_are_usable "$@" || return 1
  if [[ -f "${managed_dir}/.vantage-upstream-commit" ]]; then
    checkout="${managed_dir}"
  fi
  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    mark_skipped "${tool_name}" "functional installation retained by --no-update"
    mark_update_skipped "${source_label} source" "disabled by --no-update"
    return 0
  fi
  if vantage_git_checkout_current "${repo_url}" "${checkout}" "$@"; then
    mark_skipped "${tool_name}" \
      "functional installed Git revision matches the current upstream HEAD"
    mark_update_skipped "${source_label} source" "installed revision is current"
    return 0
  fi
  return 1
}

cms_git_tool_with_fallback_is_current() {
  local tool_name="$1"
  local primary_url="$2"
  local fallback_url="$3"
  local repo_dir="$4"
  local source_label="$5"
  shift 5

  if cms_git_tool_is_current \
    "${tool_name}" "${primary_url}" "${repo_dir}" "${source_label}" "$@"; then
    return 0
  fi
  cms_git_tool_is_current \
    "${tool_name}" "${fallback_url}" "${repo_dir}" "${source_label}" "$@"
}

cms_installer_is_current() {
  local installer_function="$1"
  local actual_wpscan=""

  vantage_force_requested && return 1
  case "${installer_function}" in
    install_wpscan)
      actual_wpscan="$(resolve_real_wpscan_path || true)"
      if [[ -x "${BIN_DIR}/wpscan" && -n "${actual_wpscan}" ]] &&
        cms_user_gem_is_current wpscan "${actual_wpscan}"; then
        mark_skipped "WPScan" "functional installed gem is current/newer than RubyGems"
        mark_update_skipped "WPScan gem" "installed version is current/newer"
        return 0
      fi
      ;;
    install_cmsmap)
      if cmsmap_runtime_is_usable; then
        cms_git_tool_is_current "CMSmap" https://github.com/Dionach/CMSmap.git \
          "${TOOLS_DIR}/CMSmap" CMSmap "${BIN_DIR}/cmsmap" && return 0
      else
        log "INFO: CMSmap source freshness check bypassed because its runtime or helper data is unhealthy"
      fi
      ;;
    install_cmseek)
      if cms_wrapper_has_scoped_syntaxwarning_filter "${BIN_DIR}/cmseek"; then
        cms_git_tool_is_current "CMSeek" https://github.com/Tuhinshubhra/CMSeeK.git \
          "${TOOLS_DIR}/CMSeeK" CMSeeK "${BIN_DIR}/cmseek" && return 0
      fi
      ;;
    install_droopescan)
      if [[ -x "${BIN_DIR}/droopescan" ]] &&
        vantage_pypi_package_current \
          "${VENV_DIR}/bin/python" droopescan "${VENV_DIR}/bin/droopescan"; then
        mark_skipped "Droopescan" "functional installed package is current/newer than PyPI"
        mark_update_skipped "Droopescan Python package" "installed version is current/newer"
        return 0
      fi
      ;;
    install_joomscan)
      cms_git_tool_is_current "JoomScan" https://github.com/OWASP/joomscan.git \
        "${TOOLS_DIR}/joomscan" joomscan "${BIN_DIR}/joomscan" && return 0
      ;;
    install_drupwn)
      if cms_repair_drupwn_banners \
          "${COMPAT_DIR}/drupwn-src/drupwn" "${VENV_DIR}/bin/drupwn" \
          "${INSTALL_HOME}/.venv/bin/drupwn" && drupwn_runtime_is_usable; then
        cms_git_tool_is_current "Drupwn" https://github.com/immunIT/drupwn.git \
          "${TOOLS_DIR}/drupwn" drupwn "${BIN_DIR}/drupwn" && return 0
      else
        log "INFO: Drupwn source freshness check bypassed because its runtime is unhealthy"
      fi
      ;;
    install_vbscan)
      cms_git_tool_is_current "VBScan" https://github.com/OWASP/vbscan.git \
        "${TOOLS_DIR}/vbscan" vbscan "${BIN_DIR}/vbscan" && return 0
      ;;
    install_cmsscan)
      if cmsscan_runtime_is_usable; then
        cms_git_tool_is_current "CMSScan" https://github.com/ajinabraham/CMSScan.git \
          "${TOOLS_DIR}/CMSScan" CMSScan \
          "${BIN_DIR}/cmsscan-server" "${BIN_DIR}/cmsscan-python" && return 0
      else
        log "INFO: CMSScan source freshness check bypassed because its runtime is unhealthy"
      fi
      ;;
    install_vulnx)
      cms_git_tool_is_current "VulnX" https://github.com/anouarbensaad/vulnx.git \
        "${TOOLS_DIR}/vulnx" vulnx "${BIN_DIR}/vulnx" && return 0
      ;;
    install_clusterd)
      if cms_repair_clusterd_runtime "${COMPAT_DIR}/clusterd-src" && \
        clusterd_runtime_is_usable; then
        cms_git_tool_is_current "Clusterd" https://github.com/hatRiot/clusterd.git \
          "${TOOLS_DIR}/clusterd" clusterd "${BIN_DIR}/clusterd" && return 0
      else
        log "INFO: Clusterd source freshness check bypassed because its runtime is unhealthy"
      fi
      ;;
    install_wpseku)
      if cms_repair_wpseku_json \
          "${TOOLS_DIR}/WPSeku" "${COMPAT_DIR}/upstream/WPSeku" &&
        cms_wrapper_has_scoped_syntaxwarning_filter "${BIN_DIR}/wpseku" &&
        wpseku_runtime_is_usable; then
        cms_git_tool_is_current "WPSeku" https://github.com/andripwn/WPSeku.git \
          "${TOOLS_DIR}/WPSeku" WPSeku "${BIN_DIR}/wpseku" && return 0
      else
        log "INFO: WPSeku source freshness check bypassed because its runtime is unhealthy"
      fi
      ;;
    install_wpxf)
      if [[ -x "${BIN_DIR}/wpxf" ]] && cms_user_gem_is_current wpxf "${BIN_DIR}/wpxf"; then
        mark_skipped "WPXF" "functional installed gem is current/newer than RubyGems"
        mark_update_skipped "WPXF gem" "installed version is current/newer"
        return 0
      fi
      ;;
    install_wpforce)
      if wpforce_runtime_is_usable; then
        cms_git_tool_is_current "WPForce" https://github.com/n00py/WPForce.git \
          "${TOOLS_DIR}/WPForce" WPForce "${BIN_DIR}/wpforce" && return 0
      else
        log "INFO: WPForce source freshness check bypassed because its runtime is unhealthy"
      fi
      ;;
    install_joomlavs)
      cms_git_tool_is_current "Joomlavs" https://github.com/rastating/joomlavs.git \
        "${TOOLS_DIR}/joomlavs" joomlavs "${BIN_DIR}/joomlavs" && return 0
      ;;
    install_fingerprinter)
      if fingerprinter_runtime_is_usable; then
        cms_git_tool_is_current "Fingerprinter" \
          https://github.com/erwanlr/Fingerprinter.git \
          "${TOOLS_DIR}/fingerprinter" fingerprinter "${BIN_DIR}/fingerprinter" && return 0
      else
        log "INFO: Fingerprinter source freshness check bypassed because its reviewed runtime is unhealthy"
      fi
      ;;
    install_autowpscan)
      # The previous guard passed "${VENV_DIR}/bin/python", which is always
      # executable and proves nothing about AutoWPScan: the tool was skipped,
      # its pip repair never ran, and verify_install_artifacts then failed the
      # whole installer with no way out. The health probe below is the gate.
      if cms_repair_autowpscan_environment "${COMPAT_DIR}/autowpscan-src" && \
        autowpscan_runtime_is_usable; then
        cms_git_tool_is_current "AutoWPScan" \
          https://github.com/password123456/autowpscan.git \
          "${TOOLS_DIR}/AutoWPScan" AutoWPScan && return 0
      else
        log "INFO: AutoWPScan source freshness check bypassed because its runtime is unhealthy"
      fi
      ;;
    install_aem_detector)
      if cms_aem_detector_runtime_is_usable; then
        cms_git_tool_is_current "AEM Detector" https://github.com/0ang3el/aem-hacker.git \
          "${TOOLS_DIR}/aem-hacker" aem-hacker \
          "${BIN_DIR}/aem-hacker" "${BIN_DIR}/aem-discoverer" && return 0
      else
        log "INFO: AEM source freshness check bypassed because its detector adapter needs repair"
      fi
      ;;
  esac
  return 1
}

run_tool_installer() {
  local installer_function="$1"
  local installed_before=${#INSTALLED[@]}
  local skipped_before=${#SKIPPED[@]}
  local failed_before=${#FAILED[@]}
  local installer_rc=0
  local settle_rc=0
  local outcome_count=0
  local outcome="failure"

  clear_pending_managed_source
  if cms_installer_is_current "${installer_function}"; then
    return 0
  fi
  # A failed evidence acknowledgement is not an unhealthy installed tool.
  # Never turn that failure into permission to reinstall a healthy component.
  [[ "${CMS_EVENT_FAILURE_STATUS:-0}" -eq 0 ]] || return "$CMS_EVENT_FAILURE_STATUS"
  if "${installer_function}"; then
    installer_rc=0
  else
    installer_rc=$?
  fi

  [[ "${#INSTALLED[@]}" -eq "${installed_before}" ]] || {
    outcome_count=$((outcome_count + 1))
    outcome="success"
  }
  [[ "${#SKIPPED[@]}" -eq "${skipped_before}" ]] || {
    outcome_count=$((outcome_count + 1))
    outcome="skipped"
  }
  [[ "${#FAILED[@]}" -eq "${failed_before}" ]] || {
    outcome_count=$((outcome_count + 1))
    outcome="failure"
  }

  if [[ "${installer_rc}" -ne 0 || "${outcome_count}" -ne 1 ]]; then
    INSTALLED=("${INSTALLED[@]:0:${installed_before}}")
    settle_pending_managed_source failure || true
    if [[ "${#FAILED[@]}" -eq "${failed_before}" ]]; then
      mark_failed "${installer_function}" \
        "installer returned ${installer_rc} and recorded ${outcome_count} outcomes"
    fi
    return 1
  fi

  if settle_pending_managed_source "${outcome}"; then
    settle_rc=0
  else
    settle_rc=$?
    INSTALLED=("${INSTALLED[@]:0:${installed_before}}")
    if [[ "${#FAILED[@]}" -eq "${failed_before}" ]]; then
      mark_failed "${installer_function}" \
        "managed source settlement failed with exit ${settle_rc}"
    fi
    return 1
  fi
  [[ "${outcome}" != failure ]] || return 1
  return 0
}

# Clone tool repo or update existing checkout.
repo_clone_or_update() {
  local repo_url="$1"
  local repo_dir="$2"
  local alternate_repo_url="${3:-}"
  local tool_label="${repo_dir##*/}"
  local status_output=""
  local after_commit=""
  local repo_top=""
  local repo_real=""
  local top_real=""
  local remote_url=""
  local upstream_ref=""
  local remote_branch=""
  local managed_snapshot="${COMPAT_DIR}/upstream/${tool_label}"
  local managed_commit=""

  EFFECTIVE_REPO_DIR="${repo_dir}"
  EFFECTIVE_WRAPPER_REPO_DIR="${repo_dir}"

  if [[ "${UPDATE_EXISTING}" -eq 0 && -d "${managed_snapshot}" ]]; then
    EFFECTIVE_REPO_DIR="${managed_snapshot}"
    EFFECTIVE_WRAPPER_REPO_DIR="${managed_snapshot}"
    log "INFO: Reusing managed ${tool_label} source snapshot because updates are disabled."
    mark_update_skipped "${tool_label} source" "disabled by --no-update"
    return 0
  fi

  # Top-level project staging deliberately excludes every .git directory. A
  # staged tools/<name> path is therefore a reviewed source snapshot, not a
  # corrupt checkout. Refresh the separately managed snapshot when possible;
  # if the network or a retired primary URL is unavailable, retain the bundled
  # commit instead. Invalid non-staged paths continue through the strict Git
  # checkout validation below.
  if [[ "${VANTAGE_STAGED_INSTALL:-0}" == 1 &&
        -d "${managed_snapshot}" && ! -L "${managed_snapshot}" ]]; then
    managed_commit="$(vantage_git_checkout_commit "${managed_snapshot}" || true)"
    [[ -n "${managed_commit}" ]] || {
      mark_update_failed "${tool_label} source" \
        "bundled managed snapshot has no valid upstream commit: ${managed_snapshot}"
      return 1
    }
    if activate_managed_upstream_checkout \
      "${repo_url}" "${tool_label}" "" 1; then
      log "INFO: Refreshing staged ${tool_label} from ${repo_url}."
      return 0
    fi
    if [[ -n "${alternate_repo_url}" ]] && \
      activate_managed_upstream_checkout \
        "${alternate_repo_url}" "${tool_label}" "" 1; then
      log "INFO: Refreshing staged ${tool_label} from fallback repository ${alternate_repo_url}."
      return 0
    fi
    EFFECTIVE_REPO_DIR="${managed_snapshot}"
    EFFECTIVE_WRAPPER_REPO_DIR="${managed_snapshot}"
    mark_update_skipped "${tool_label} source" \
      "upstream refresh unavailable; retained bundled managed snapshot ${managed_commit:0:12}"
    return 0
  fi

  if [[ -e "${repo_dir}" || -L "${repo_dir}" ]]; then
    repo_top="$(capture_user_cmd git -C "${repo_dir}" rev-parse --show-toplevel 2>/dev/null || true)"
    repo_real="$(capture_user_cmd readlink -f "${repo_dir}" 2>/dev/null || true)"
    top_real="$(capture_user_cmd readlink -f "${repo_top}" 2>/dev/null || true)"
    if [[ -z "${repo_real}" || -z "${top_real}" || "${repo_real}" != "${top_real}" ]]; then
      mark_update_failed "${tool_label} source" "existing path is not a valid Git checkout: ${repo_dir}"
      return 1
    fi
    remote_url="$(capture_user_cmd git -C "${repo_dir}" remote get-url origin 2>/dev/null || true)"
    if [[ -z "${remote_url}" || ( "${remote_url}" != "${repo_url}" && "${remote_url}" != "${alternate_repo_url}" ) ]]; then
      mark_update_failed "${tool_label} source" "unexpected origin URL: ${remote_url:-<missing>}"
      return 1
    fi
    upstream_ref="$(capture_user_cmd git -C "${repo_dir}" rev-parse \
      --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -n "${upstream_ref}" && "${upstream_ref}" == */* ]]; then
      remote_branch="${upstream_ref#*/}"
    else
      remote_branch="$(capture_user_cmd git -C "${repo_dir}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    fi

    if [[ "$UPDATE_EXISTING" -eq 1 ]]; then
      status_output="$(capture_user_cmd git -C "${repo_dir}" status --porcelain 2>/dev/null || true)"
      if [[ -n "${status_output}" ]]; then
        log "INFO: ${tool_label} has local changes; the checkout will remain untouched."
      fi
      if ! activate_managed_upstream_checkout \
        "${remote_url}" "${tool_label}" "${remote_branch}" 1; then
        mark_update_failed "${tool_label} source" "unable to build a clean managed upstream snapshot; checkout left untouched"
        return 1
      fi
      log "INFO: ${tool_label} checkout left untouched at ${repo_dir}; validating managed upstream source."
    else
      log "INFO: Using existing checkout ${repo_dir}"
      mark_update_skipped "${tool_label} source" "disabled by --no-update"
    fi
  else
    if ! run_git_user_cmd clone --depth 1 "$repo_url" "$repo_dir"; then
      return 1
    fi
    EFFECTIVE_REPO_DIR="${repo_dir}"
    EFFECTIVE_WRAPPER_REPO_DIR="${repo_dir}"
    after_commit="$(capture_user_cmd git -C "${repo_dir}" rev-parse HEAD 2>/dev/null || true)"
    mark_updated "${tool_label} source (fresh checkout ${after_commit:0:12})"
  fi
}

repo_is_reachable() {
  local repo_url="$1"
  if has_cmd timeout; then
    capture_user_cmd timeout --signal=TERM --kill-after=10s "${GIT_UPDATE_TIMEOUT}" \
      env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git ls-remote --heads "$repo_url" >/dev/null 2>&1
  else
    capture_user_cmd env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo \
      git ls-remote --heads "$repo_url" >/dev/null 2>&1
  fi
}

# Try primary repository first, then fallback URL if unavailable.
repo_clone_with_fallback() {
  local tool_name="$1"
  local primary_url="$2"
  local fallback_url="$3"
  local repo_dir="$4"

  # Existing checkouts must be updated from their configured upstream. URL
  # reachability probes are only needed when choosing a source for a new clone.
  if [[ -e "${repo_dir}" || -L "${repo_dir}" || \
        ( "${UPDATE_EXISTING}" -eq 0 && -d "${COMPAT_DIR}/upstream/${repo_dir##*/}" ) ]]; then
    repo_clone_or_update "${primary_url}" "${repo_dir}" "${fallback_url}"
    return $?
  fi

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
  local phase_operation="${name,,}"
  phase_operation="${phase_operation//[^a-z0-9_.-]/_}"
  local VI_PHASE=inspect
  case "$name" in
    Preflight) VI_PHASE=preflight ;;
    'System Dependencies'|'Canonical Python Environment') VI_PHASE=dependencies ;;
    'Tool Installation') VI_PHASE=acquire ;;
    'Scanner Database Updates') VI_PHASE=configure ;;
    'Post-Install Verification') VI_PHASE=verify ;;
    'Encrypted Bundle and cmsscan Wrapper') VI_PHASE=build ;;
  esac

  cms_installer_event START "cms.phase.$phase_operation" running phase_started "$name" || return $?
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

  if [[ "$rc" -eq 0 ]]; then
    cms_installer_event END "cms.phase.$phase_operation" succeeded phase_verified "$name (${elapsed}s)" || return $?
  else
    cms_installer_event FAIL "cms.phase.$phase_operation" failed phase_failed "$name (exit $rc, ${elapsed}s)" || return $?
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

# Return success only when the install user's primary group follows the
# user-private-group model. Group-write on a venv is harmless in that model
# because no second account belongs to the group.
install_user_primary_group_is_private() {
  local getent_cmd=""
  local group_line=""
  local group_name=""
  local group_gid=""
  local group_members=""
  local member=""
  local passwd_line=""
  local passwd_name=""
  local passwd_gid=""
  local -a group_fields=()
  local -a group_members_array=()
  local -a passwd_fields=()

  getent_cmd="$(system_cmd_path getent || true)"
  [[ -n "${getent_cmd}" ]] || return 1
  group_line="$("${getent_cmd}" group "${INSTALL_GID}" 2>/dev/null || true)"
  IFS=':' read -r -a group_fields <<<"${group_line}"
  group_name="${group_fields[0]:-}"
  group_gid="${group_fields[2]:-}"
  group_members="${group_fields[3]:-}"
  [[ "${group_name}" == "${INSTALL_USER}" && "${group_gid}" == "${INSTALL_GID}" ]] || return 1

  IFS=',' read -r -a group_members_array <<<"${group_members}"
  for member in "${group_members_array[@]}"; do
    [[ -z "${member}" || "${member}" == "${INSTALL_USER}" ]] || return 1
  done

  while IFS= read -r passwd_line; do
    IFS=':' read -r -a passwd_fields <<<"${passwd_line}"
    passwd_name="${passwd_fields[0]:-}"
    passwd_gid="${passwd_fields[3]:-}"
    if [[ "${passwd_gid}" == "${INSTALL_GID}" && \
          "${passwd_name}" != "${INSTALL_USER}" ]]; then
      return 1
    fi
  done < <("${getent_cmd}" passwd)
  return 0
}

canonical_venv_interpreter_matches() {
  local expected_real="$1"

  run_user_cmd env EXPECTED_VENV_REAL="${expected_real}" \
    "${VENV_DIR}/bin/python" - <<'PY'
import os
import sys

expected = os.environ["EXPECTED_VENV_REAL"]
if os.path.realpath(sys.prefix) != expected or sys.prefix == sys.base_prefix:
    raise SystemExit(1)
PY
}

# Create or validate the Python environment owned by the CMS scanner component.
# Its public path is deliberately not configurable. A user-owned venv symlink is
# supported so the physical environment can live on another local filesystem;
# the resolved target is validated before it is used.
ensure_canonical_venv() {
  local expected_venv="${INSTALL_HOME}/.local/share/vantage/cms_scanner/venv"
  local acl_output=""
  local find_cmd=""
  local getfacl_cmd=""
  local group_owner=""
  local home_real=""
  local pyvenv_owner=""
  local readlink_cmd=""
  local stat_cmd=""
  local symlink_owner=""
  local private_primary_group=0
  local venv_dev=""
  local venv_ino=""
  local venv_mode=""
  local venv_owner=""
  local venv_real=""
  local venv_real_after_probe=""
  local venv_is_symlink=0
  local unsafe_entry=""

  if [[ "${VENV_DIR}" != "${expected_venv}" ]]; then
    mark_failed "Python environment" "refusing non-canonical path: ${VENV_DIR} (expected ${expected_venv})"
    return 1
  fi

  ensure_install_user_dir "$(dirname "${expected_venv}")" || return 1

  readlink_cmd="$(system_cmd_path readlink || true)"
  stat_cmd="$(system_cmd_path stat || true)"
  if [[ -z "${readlink_cmd}" || -z "${stat_cmd}" ]]; then
    mark_failed "Python environment" "system readlink/stat commands are required for canonical venv validation"
    return 1
  fi

  if [[ -L "${VENV_DIR}" ]]; then
    venv_is_symlink=1
    symlink_owner="$("${stat_cmd}" -c '%u' -- "${VENV_DIR}" 2>/dev/null || true)"
    if [[ "${symlink_owner}" != "${INSTALL_UID}" ]]; then
      mark_failed "Python environment" \
        "canonical venv symlink must be owned by ${INSTALL_USER}: ${VENV_DIR}"
      return 1
    fi
  fi

  if [[ -e "${VENV_DIR}" && ! -x "${VENV_DIR}/bin/python" ]]; then
    mark_failed "Python environment" "${VENV_DIR} exists but is not a usable virtual environment; repair or remove it explicitly"
    return 1
  fi

  if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    if ! run_user_cmd /usr/bin/python3 -m venv "${VENV_DIR}"; then
      mark_failed "Python environment" "python3 could not create ${VENV_DIR}"
      return 1
    fi
  fi

  home_real="$("${readlink_cmd}" -f -- "${INSTALL_HOME}" 2>/dev/null || true)"
  venv_real="$("${readlink_cmd}" -f -- "${VENV_DIR}" 2>/dev/null || true)"
  venv_owner="$("${stat_cmd}" -L -c '%u' -- "${VENV_DIR}" 2>/dev/null || true)"
  group_owner="$("${stat_cmd}" -L -c '%g' -- "${VENV_DIR}" 2>/dev/null || true)"
  venv_dev="$("${stat_cmd}" -L -c '%d' -- "${VENV_DIR}" 2>/dev/null || true)"
  venv_ino="$("${stat_cmd}" -L -c '%i' -- "${VENV_DIR}" 2>/dev/null || true)"
  venv_mode="$("${stat_cmd}" -L -c '%a' -- "${VENV_DIR}" 2>/dev/null || true)"
  pyvenv_owner="$("${stat_cmd}" -L -c '%u' -- "${VENV_DIR}/pyvenv.cfg" 2>/dev/null || true)"
  if [[ -z "${home_real}" || -z "${venv_real}" || \
        "${venv_real}" == "/" || ! -d "${venv_real}" || \
        ! "${venv_dev}" =~ ^[0-9]+$ || ! "${venv_ino}" =~ ^[0-9]+$ || \
        "${venv_owner}" != "${INSTALL_UID}" || \
        "${pyvenv_owner}" != "${INSTALL_UID}" || \
        ! -f "${venv_real}/pyvenv.cfg" || \
        -L "${venv_real}/pyvenv.cfg" ]]; then
    mark_failed "Python environment" \
      "canonical venv must resolve to a usable ${INSTALL_USER}-owned virtual environment"
    return 1
  fi
  if [[ "${venv_is_symlink}" -eq 0 && \
        "${venv_real}" != "${home_real}/.local/share/vantage/cms_scanner/venv" ]]; then
    mark_failed "Python environment" \
      "canonical venv resolved outside ${INSTALL_HOME}: ${venv_real}"
    return 1
  fi
  if [[ ! "${venv_mode}" =~ ^[0-7]{3,4}$ ]]; then
    mark_failed "Python environment" \
      "could not validate canonical venv permissions: ${venv_real}"
    return 1
  fi
  if (( (8#${venv_mode} & 0002) != 0 )); then
    mark_failed "Python environment" \
      "canonical venv target is world-writable: ${venv_real} (mode ${venv_mode})"
    return 1
  fi
  if install_user_primary_group_is_private; then
    private_primary_group=1
  fi
  if (( (8#${venv_mode} & 0020) != 0 )); then
    if [[ "${group_owner}" != "${INSTALL_GID}" ]] || \
        [[ "${private_primary_group}" -ne 1 ]]; then
      mark_failed "Python environment" \
        "canonical venv target is writable by a non-private group: ${venv_real} (gid ${group_owner:-unknown}, mode ${venv_mode})"
      return 1
    fi
    log "INFO: Accepting group-writable canonical venv owned by private group ${INSTALL_USER} (${INSTALL_GID})"
  fi
  if ! canonical_venv_interpreter_matches "${venv_real}"; then
    mark_failed "Python environment" \
      "interpreter does not identify the resolved virtual environment: ${venv_real}"
    return 1
  fi
  venv_real_after_probe="$("${readlink_cmd}" -f -- "${VENV_DIR}" 2>/dev/null || true)"
  venv_dev="$("${stat_cmd}" -c '%d' -- "${venv_real}" 2>/dev/null || true)"
  venv_ino="$("${stat_cmd}" -c '%i' -- "${venv_real}" 2>/dev/null || true)"
  if [[ "${venv_real_after_probe}" != "${venv_real}" || \
        ! "${venv_dev}" =~ ^[0-9]+$ || ! "${venv_ino}" =~ ^[0-9]+$ ]]; then
    mark_failed "Python environment" \
      "canonical venv changed while its interpreter was being validated"
    return 1
  fi
  if ! verify_install_user_tree_ownership "${venv_real}"; then
    log "INFO: Repairing stale root-owned entries in canonical venv ${venv_real}"
    repair_canonical_venv_root_ownership \
      "${venv_real}" "${venv_dev}" "${venv_ino}" \
      "${private_primary_group}" || true
  fi
  if ! verify_install_user_tree_ownership "${venv_real}"; then
    mark_failed "Python environment" \
      "canonical venv contains entries not owned by ${INSTALL_USER}:${INSTALL_GID}: ${venv_real}"
    return 1
  fi
  find_cmd="$(system_cmd_path find || true)"
  if [[ -z "${find_cmd}" ]]; then
    mark_failed "Python environment" "system find is required for canonical venv validation"
    return 1
  fi
  if ! unsafe_entry="$(
    "${find_cmd}" -P "${venv_real}" -xdev ! -type l -perm -0002 \
      -print -quit 2>/dev/null
  )"; then
    mark_failed "Python environment" "could not inspect canonical venv permissions"
    return 1
  fi
  if [[ -n "${unsafe_entry}" ]]; then
    mark_failed "Python environment" \
      "canonical venv contains a world-writable entry: ${unsafe_entry}"
    return 1
  fi
  if [[ "${private_primary_group}" -ne 1 ]]; then
    if ! unsafe_entry="$(
      "${find_cmd}" -P "${venv_real}" -xdev ! -type l -perm -0020 \
        -print -quit 2>/dev/null
    )"; then
      mark_failed "Python environment" "could not inspect canonical venv group permissions"
      return 1
    fi
    if [[ -n "${unsafe_entry}" ]]; then
      mark_failed "Python environment" \
        "canonical venv contains an entry writable by a non-private group: ${unsafe_entry}"
      return 1
    fi
  fi
  getfacl_cmd="$(system_cmd_path getfacl || true)"
  if [[ -n "${getfacl_cmd}" ]]; then
    if ! acl_output="$("${getfacl_cmd}" -R -P -c -p \
        --one-file-system -- "${venv_real}" 2>/dev/null)"; then
      mark_failed "Python environment" "could not inspect canonical venv ACLs"
      return 1
    fi
    if grep -Eq '^default:|^(user|group):[^:]+:' <<<"${acl_output}"; then
      mark_failed "Python environment" \
        "canonical venv contains named user/group ACL entries: ${venv_real}"
      return 1
    fi
  fi
  if ! run_as_install_user test -w "${venv_real}" 2>/dev/null || \
      ! run_as_install_user test -w "${venv_real}/bin" 2>/dev/null; then
    mark_failed "Python environment" \
      "canonical venv target is not writable by ${INSTALL_USER}: ${venv_real}"
    return 1
  fi
  if ! canonical_venv_interpreter_matches "${venv_real}"; then
    mark_failed "Python environment" \
      "interpreter does not identify the resolved virtual environment: ${venv_real}"
    return 1
  fi
  if [[ "${venv_is_symlink}" -eq 1 ]]; then
    log "INFO: Using validated canonical venv symlink ${VENV_DIR} -> ${venv_real}"
  fi

  if ! run_user_cmd "${VENV_DIR}/bin/python" -m pip --version; then
    run_user_cmd "${VENV_DIR}/bin/python" -m ensurepip --upgrade || return 1
  fi

  cleanup_venv_artifacts "${VENV_DIR}" || true
  record_pip_check_baseline || return 1
  if [[ "${UPDATE_EXISTING}" -eq 1 ]]; then
    local -a web_requirements=()
    local requirement=""
    if vantage_pypi_package_current "${VENV_DIR}/bin/python" pip; then
      mark_update_skipped "Canonical Python pip" "installed version is current/newer than PyPI"
    else
      run_user_cmd "${VENV_DIR}/bin/python" -m pip install \
        --no-cache-dir --constraint "${SHARED_ENV_CONSTRAINTS}" --upgrade pip || return 1
      mark_updated "Canonical Python pip"
    fi
    # `six` is a runtime dependency of the reviewed Python 3 compatibility
    # copies for Clusterd and WPForce. Keep it in the component baseline even
    # when their upstream source revisions are already current.
    for requirement in requests beautifulsoup4 click six; do
      if vantage_pypi_package_current "${VENV_DIR}/bin/python" "${requirement}"; then
        mark_update_skipped "Python ${requirement}" "installed version is current/newer than PyPI"
      else
        web_requirements+=("${requirement}")
      fi
    done
    if [[ "${#web_requirements[@]}" -gt 0 ]]; then
      if ! scanner_pip_install "${web_requirements[@]}"; then
        mark_failed "Python environment" \
          "could not upgrade WA-SCAN web requirements in ${VENV_DIR}"
        return 1
      fi
      mark_updated "WA-SCAN Python web requirements"
    else
      mark_update_skipped "WA-SCAN Python web requirements" \
        "all installed versions are current/newer than PyPI"
    fi
  else
    mark_update_skipped "Canonical Python pip" "disabled by --no-update"
  fi
  cleanup_venv_artifacts "${VENV_DIR}" || true
}

# Remove stale/partial temp distributions that can break repeat installs.
cleanup_venv_artifacts() {
  local venv_path="$1"
  local venv_real=""
  local stale=""
  local stale_real=""

  [[ -x "${venv_path}/bin/python" ]] || return 0

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

  venv_real="$(readlink -f "${venv_path}" 2>/dev/null || true)"
  [[ -n "${venv_real}" && "${venv_real}" != "/" && -d "${venv_real}/lib" ]] || return 0
  while IFS= read -r -d '' stale; do
    stale_real="$(readlink -m "${stale}" 2>/dev/null || true)"
    case "${stale_real}" in
      "${venv_real}"/lib/python*/site-packages/~*)
        log "INFO: Removing stale root-owned temp distribution ${stale_real}"
        run_privileged rm -rf -- "${stale_real}" || true
        ;;
      *) warn "Refusing stale-artifact path outside the canonical venv: ${stale}" ;;
    esac
  done < <(find "${venv_real}/lib" -mindepth 3 -maxdepth 3 -name '~*' -print0 2>/dev/null)
}

# Accept only the fixed VAPT-local cleanup helper when it is owned by root or
# the resolved install user and cannot be modified by another group/user.
cleanup_helper_is_trusted() {
  local helper_path="${VANTAGE_INSTALLER_CLEANUP_HELPER}"
  local helper_owner=""
  local helper_mode=""
  local stat_cmd=""

  [[ -f "${helper_path}" && ! -L "${helper_path}" && -r "${helper_path}" ]] || return 1
  stat_cmd="$(system_cmd_path stat || true)"
  [[ -n "${stat_cmd}" ]] || return 1
  helper_owner="$("${stat_cmd}" -Lc '%u' -- "${helper_path}" 2>/dev/null || true)"
  helper_mode="$("${stat_cmd}" -Lc '%a' -- "${helper_path}" 2>/dev/null || true)"
  [[ "${helper_owner}" =~ ^[0-9]+$ && "${helper_mode}" =~ ^[0-7]{3,4}$ ]] || return 1
  (( (8#${helper_mode} & 0022) == 0 )) || return 1
  [[ "${helper_owner}" == "0" || \
     ( -n "${INSTALL_UID}" && "${helper_owner}" == "${INSTALL_UID}" ) ]]
}

# Execute the helper's CLI as the install user. This keeps repository-owned
# shell code out of the privileged-capable installer process.
run_post_install_cleanup() {
  local cleanup_root="${1:-${SCRIPT_DIR}}"
  local bash_cmd=""
  # Bash resolves an argument-less `return` inside a trap handler from the
  # status that triggered the trap, not from the helper run here, so the
  # helper status must be captured and returned explicitly.
  local helper_status=0

  # The top-level installer removes the complete private stage after this
  # child returns. Checkout cleanup as aiuser cannot cross the root-owned
  # staged project root and is both redundant and guaranteed to fail;
  # registered temporary paths are still removed by installer_exit_cleanup.
  if [[ "${VANTAGE_STAGED_INSTALL:-0}" == 1 ]]; then
    return 0
  fi

  [[ -e "${VANTAGE_INSTALLER_CLEANUP_HELPER}" ]] || return 0
  if ! cleanup_helper_is_trusted; then
    log "WARN: Refusing unsafe cleanup helper: ${VANTAGE_INSTALLER_CLEANUP_HELPER}"
    return 1
  fi
  bash_cmd="$(system_cmd_path bash || true)"
  [[ -n "${bash_cmd}" ]] || return 1

  run_user_cmd "${bash_cmd}" \
    "${VANTAGE_INSTALLER_CLEANUP_HELPER}" "${cleanup_root}"
  helper_status=$?
  return "${helper_status}"
}

# Recognize only the one incomplete legacy layout observed for Droopescan. The
# validator runs before any deletion and rejects symlinks, foreign ownership,
# nested filesystems, empty site-packages, and every unexpected sibling.
legacy_partial_droopescan_venv_is_safe() {
  local partial_root="$1"
  local lib_dir="${partial_root}/lib"
  local python_dir=""
  local site_packages=""
  local path=""
  local path_uid=""
  local path_dev=""
  local root_dev=""
  local stat_cmd=""
  local find_cmd=""
  local -a entries=()

  [[ "${partial_root##*/}" == "droopescan" && \
     -d "${partial_root}" && ! -L "${partial_root}" && \
     "${INSTALL_UID}" =~ ^[0-9]+$ ]] || return 1
  find_cmd="$(system_cmd_path find || true)"
  stat_cmd="$(system_cmd_path stat || true)"
  [[ -n "${find_cmd}" && -n "${stat_cmd}" ]] || return 1

  mapfile -d '' -t entries < <(
    "${find_cmd}" -P "${partial_root}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null
  )
  [[ "${#entries[@]}" -eq 1 && "${entries[0]}" == "${lib_dir}" && \
     -d "${lib_dir}" && ! -L "${lib_dir}" ]] || return 1

  entries=()
  mapfile -d '' -t entries < <(
    "${find_cmd}" -P "${lib_dir}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null
  )
  [[ "${#entries[@]}" -eq 1 && -d "${entries[0]}" && ! -L "${entries[0]}" ]] || return 1
  python_dir="${entries[0]}"
  [[ "${python_dir##*/}" =~ ^python[0-9]+\.[0-9]+$ ]] || return 1

  site_packages="${python_dir}/site-packages"
  entries=()
  mapfile -d '' -t entries < <(
    "${find_cmd}" -P "${python_dir}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null
  )
  [[ "${#entries[@]}" -eq 1 && "${entries[0]}" == "${site_packages}" && \
     -d "${site_packages}" && ! -L "${site_packages}" ]] || return 1
  IFS= read -r -d '' path < <(
    "${find_cmd}" -P "${site_packages}" -mindepth 1 -print0 -quit 2>/dev/null
  ) || true
  [[ -n "${path}" ]] || return 1

  root_dev="$("${stat_cmd}" -c '%d' -- "${partial_root}" 2>/dev/null || true)"
  [[ "${root_dev}" =~ ^[0-9]+$ ]] || return 1
  while IFS= read -r -d '' path; do
    [[ ! -L "${path}" ]] || return 1
    path_uid="$("${stat_cmd}" -c '%u' -- "${path}" 2>/dev/null || true)"
    path_dev="$("${stat_cmd}" -c '%d' -- "${path}" 2>/dev/null || true)"
    [[ "${path_uid}" == "${INSTALL_UID}" && "${path_dev}" == "${root_dev}" ]] || return 1
  done < <("${find_cmd}" -P "${partial_root}" -xdev -print0 2>/dev/null)
}

# Older revisions created one project-local venv per CMS tool. Current code
# mandates one CMS-scoped venv outside the project and excludes .venvs from
# deployment bundles. Remove
# the legacy tree only when every immediate child is a complete Python venv or
# the narrowly validated partial Droopescan remnant above.
cleanup_legacy_project_venvs() {
  local project_root="${1:-${SCRIPT_DIR}}"
  local project_real=""
  local legacy_dir="${project_root}/.venvs"
  local legacy_real=""
  local canonical_real=""
  local entry=""
  local find_cmd=""
  local readlink_cmd=""

  [[ -e "${legacy_dir}" || -L "${legacy_dir}" ]] || return 0
  if [[ -L "${legacy_dir}" || ! -d "${legacy_dir}" ]]; then
    log "WARN: Refusing non-directory legacy venv path: ${legacy_dir}"
    return 1
  fi

  readlink_cmd="$(system_cmd_path readlink || true)"
  [[ -n "${readlink_cmd}" ]] || return 1
  project_real="$("${readlink_cmd}" -f -- "${project_root}" 2>/dev/null || true)"
  legacy_real="$("${readlink_cmd}" -f -- "${legacy_dir}" 2>/dev/null || true)"
  canonical_real="$("${readlink_cmd}" -f -- "${VENV_DIR}" 2>/dev/null || true)"
  if [[ -z "${project_real}" || -z "${legacy_real}" || \
        "${legacy_real}" != "${project_real}/.venvs" || \
        "${legacy_real}" == "/" || \
        ( -n "${canonical_real}" && "${legacy_real}" == "${canonical_real}" ) ]]; then
    log "WARN: Refusing unexpected legacy venv cleanup path: ${legacy_dir}"
    return 1
  fi

  find_cmd="$(system_cmd_path find || true)"
  [[ -n "${find_cmd}" ]] || return 1
  while IFS= read -r -d '' entry; do
    if [[ ! -L "${entry}" && -d "${entry}" && \
          -f "${entry}/pyvenv.cfg" && ! -L "${entry}/pyvenv.cfg" ]]; then
      continue
    fi
    if legacy_partial_droopescan_venv_is_safe "${entry}"; then
      continue
    fi
    log "WARN: Retaining ${legacy_dir}; unexpected or unsafe legacy venv entry: ${entry}"
    return 1
  done < <("${find_cmd}" -P "${legacy_dir}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

  # -P and -xdev avoid following symlinks or crossing into a mounted tree.
  run_as_install_user "${find_cmd}" -P "${legacy_dir}" -xdev -depth -delete || return 1
  log "INFO: Removed obsolete project-local CMS virtual environments: ${legacy_dir}"
}

# Dropbox conflict resolution can leave sibling files such as
# ".git/index (host's conflicted copy YYYY-MM-DD)". Git never reads those
# names. Remove only that exact sidecar shape when a canonical sibling index
# exists; all real Git metadata remains protected.
cleanup_git_index_conflict_sidecars() {
  local project_root="${1:-${SCRIPT_DIR}}"
  local project_real=""
  local sidecar=""
  local sidecar_name=""
  local canonical_index=""
  local find_cmd=""
  local readlink_cmd=""
  local rm_cmd=""
  local removed=0
  local sidecar_re="^index \\(.+'s conflicted copy [0-9]{4}-[0-9]{2}-[0-9]{2}\\)$"

  readlink_cmd="$(system_cmd_path readlink || true)"
  find_cmd="$(system_cmd_path find || true)"
  rm_cmd="$(system_cmd_path rm || true)"
  [[ -n "${readlink_cmd}" && -n "${find_cmd}" && -n "${rm_cmd}" ]] || return 1
  project_real="$("${readlink_cmd}" -f -- "${project_root}" 2>/dev/null || true)"
  [[ -n "${project_real}" && "${project_real}" != "/" ]] || return 1

  while IFS= read -r -d '' sidecar; do
    sidecar_name="${sidecar##*/}"
    [[ "${sidecar_name}" =~ ${sidecar_re} ]] || continue
    case "${sidecar}" in
      "${project_real}"/.git/*|"${project_real}"/*/.git/*) ;;
      *)
        log "WARN: Refusing Git-index sidecar outside a .git tree: ${sidecar}"
        return 1
        ;;
    esac
    canonical_index="${sidecar%/*}/index"
    if [[ ! -f "${canonical_index}" || -L "${canonical_index}" ]]; then
      log "WARN: Retaining Git-index sidecar without a canonical sibling: ${sidecar}"
      continue
    fi
    if ! run_as_install_user "${rm_cmd}" -f -- "${sidecar}"; then
      log "WARN: Could not remove Git-index conflict sidecar: ${sidecar}"
      return 1
    fi
    removed=$((removed + 1))
  done < <(
    "${find_cmd}" -P "${project_real}" -type f \
      -name "index (*'s conflicted copy ????-??-??)" -print0 2>/dev/null
  )

  if [[ "${removed}" -gt 0 ]]; then
    log "INFO: Removed ${removed} Dropbox-conflicted Git index sidecar(s)"
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
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    export PATH="${SYSTEM_PATH}"
  elif [[ -n "${USER_GEM_BIN}" ]]; then
    export PATH="${BIN_DIR}:${VENV_DIR}/bin:${USER_GEM_BIN}:${BASE_PATH}"
  else
    export PATH="${BIN_DIR}:${VENV_DIR}/bin:${BASE_PATH}"
  fi
}

ensure_cms_nmap_dependency() {
  local managed_installer="${VANTAGE_ROOT_DIR}/SA-SCAN/nmap_scanner/installer.sh"
  local -a installer_args=()

  if ! vantage_nmap_assess; then
    mark_failed "Nmap dependency" \
      "no complete installation or usable package/source metadata is available"
    return 1
  fi

  case "$VANTAGE_NMAP_PLAN" in
    current)
      log "SKIP: Nmap ${VANTAGE_NMAP_SELECTED_VERSION} is current/newer than official ${VANTAGE_NMAP_LATEST_VERSION}"
      ;;
    retain-offline)
      log "SKIP: Official Nmap metadata unavailable; retaining complete Nmap ${VANTAGE_NMAP_SELECTED_VERSION}"
      ;;
    package)
      apt_install_packages "Nmap dependency" nmap || return 1
      hash -r
      ;;
    source)
      [[ -r "$managed_installer" ]] || {
        mark_failed "Nmap dependency" \
          "verified SA Nmap source installer is missing: ${managed_installer}"
        return 1
      }
      vantage_nmap_force_requested && installer_args+=(--force)
      log "Installing verified official Nmap through the canonical SA managed backend..."
      bash "$managed_installer" "${installer_args[@]}" || {
        mark_failed "Nmap dependency" "verified source installation failed"
        return 1
      }
      ;;
    *)
      mark_failed "Nmap dependency" \
        "unsupported canonical plan: ${VANTAGE_NMAP_PLAN:-none}"
      return 1
      ;;
  esac

  vantage_nmap_select_best || {
    mark_failed "Nmap dependency" \
      "installation produced no complete executable/NSE pair"
    return 1
  }
  if [[ -n "$VANTAGE_NMAP_LATEST_VERSION" ]] &&
     ! vantage_nmap_version_ge "$VANTAGE_NMAP_SELECTED_VERSION" "$VANTAGE_NMAP_LATEST_VERSION"; then
    mark_failed "Nmap dependency" \
      "installed ${VANTAGE_NMAP_SELECTED_VERSION} is older than required ${VANTAGE_NMAP_LATEST_VERSION}"
    return 1
  fi
  export INFRA_NMAP_BIN="$VANTAGE_NMAP_SELECTED_BIN"
}

install_system_dependencies() {
  if [[ "$INSTALL_SYSTEM_DEPS" -ne 1 ]]; then
    return 0
  fi

  log "Installing system dependencies via apt..."
  if ! vantage_refresh_apt_metadata run_privileged apt-get; then
    mark_failed "System dependencies" "APT metadata is unusable (need sudo/root and valid package state)"
    return 1
  fi
  APT_UPDATED=1

  if ! apt_install_packages "System dependencies" \
    git curl perl ruby ruby-dev build-essential \
    python3 python3-pip python3-venv \
    libxml2-dev libxslt1-dev zlib1g-dev liblzma-dev libcurl4-openssl-dev \
    tor torsocks; then
    mark_failed "System dependencies" "core apt packages failed"
    return 1
  fi
  ensure_cms_nmap_dependency || return 1

  # WPForce and Clusterd are converted to Python 3 and run from the canonical
  # user venv. Do not add Python 2 or system-pip package locations here.
}

# -----------------------------------------------------------------------------
# Encrypted INFRA bundle and compiled command wrapper
# -----------------------------------------------------------------------------

ensure_7z_present() {
  if has_cmd apt-get; then
    apt_install_packages "Encrypted CMS bundle" p7zip-full || return 1
    has_cmd 7z
    return $?
  fi
  has_cmd 7z
}

resolve_infrauth_path() {
  local candidate=""
  for candidate in "$INFRAUTH_PATH" "$INFRAUTH_FALLBACK_PATH"; do
    [[ -n "${candidate}" ]] || continue
    if [[ -f "${candidate}" && ! -L "${candidate}" ]] && \
      run_as_install_user test -r "${candidate}" 2>/dev/null; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

ensure_infrauth_readable() {
  local target="${INFRAUTH_PATH}"
  local target_dir=""
  local tmp_auth=""
  local link_count=""
  local runtime_group="${VANTAGE_RUNTIME_GROUP:-aiuser}"

  target_dir="$(dirname "${target}")"
  getent group "${runtime_group}" >/dev/null 2>&1 || return 1
  if [[ -L "${target_dir}" || ( -e "${target_dir}" && ! -d "${target_dir}" ) ]]; then
    return 1
  fi
  if [[ -L "${target}" || ( -e "${target}" && ! -f "${target}" ) ]]; then
    return 1
  fi
  if [[ ! -e "${target}" ]]; then
    vantage_make_temp tmp_auth || return 1
    printf '%s\n' 'echo www.infrascan.net' >"${tmp_auth}"
    if [[ -L "${target_dir}" || ( -e "${target_dir}" && ! -d "${target_dir}" ) ]]; then
      rm -f "${tmp_auth}"
      return 1
    fi
    if [[ ! -d "${target_dir}" ]] && ! run_privileged install -d -m 755 "${target_dir}"; then
      rm -f "${tmp_auth}"
      return 1
    fi
    if ! run_privileged install -o root -g "${runtime_group}" -m 0640 \
      "${tmp_auth}" "${target}"; then
      rm -f "${tmp_auth}"
      return 1
    fi
    rm -f "${tmp_auth}"
    log "Created default infrauth script: ${target}"
  fi
  link_count="$(stat -c '%h' -- "${target}" 2>/dev/null || true)"
  [[ -f "${target}" && ! -L "${target}" && "${link_count}" == 1 ]] || return 1
  run_privileged chown "root:${runtime_group}" "${target}" || return 1
  run_privileged chmod 0640 "${target}" || return 1
  run_as_install_user test -r "${target}" 2>/dev/null
}

derive_archive_password() {
  local raw=""
  local derived=""
  local auth_path=""

  if [[ -n "${INFRA_ARCHIVE_PASSWORD:-}" ]]; then
    printf '%s' "${INFRA_ARCHIVE_PASSWORD}"
    return 0
  fi

  ensure_infrauth_readable >/dev/null || return 1
  auth_path="$(resolve_infrauth_path || true)"
  [[ -n "${auth_path}" ]] || return 1

  raw="$(capture_user_cmd env -i PATH=/usr/bin:/bin bash --noprofile --norc \
    "${auth_path}" 2>/dev/null || true)"
  raw="$(printf '%s' "${raw}" | head -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -n "${raw}" ]] || return 1

  derived="${raw/www./info@}"
  [[ -n "${derived}" ]] || return 1
  printf '%s' "${derived}"
}

sha256_file() {
  local path="$1"
  if has_cmd sha256sum; then
    sha256sum "${path}" | awk '{print $1}'
  elif has_cmd shasum; then
    shasum -a 256 "${path}" | awk '{print $1}'
  elif has_cmd openssl; then
    openssl dgst -sha256 "${path}" | awk '{print $NF}'
  else
    return 1
  fi
}

write_cmsscan_archive_manifest() {
  local archive_path="$1"
  local manifest_path="$2"
  local content_root="${3:-${SCRIPT_DIR}}"
  local tmp_manifest=""
  local archive_sha=""
  local rel_path=""
  local file_sha=""
  local entry=""
  local -a critical_paths=(
    "run_cms_scanner.sh"
    "installer.sh"
    "scripts/cmsscan.wrapper"
    "scripts/patch_vulnx_detector.py"
  )
  local -a critical_hashes=()

  [[ -f "${archive_path}" ]] || return 1
  archive_sha="$(sha256_file "${archive_path}")" || return 1
  vantage_make_temp tmp_manifest || return 1

  for rel_path in "${critical_paths[@]}"; do
    if [[ ! -f "${content_root}/${rel_path}" ]]; then
      rm -f "${tmp_manifest}"
      warn "CMS bundle manifest critical file missing: ${rel_path}"
      return 1
    fi
    if ! file_sha="$(sha256_file "${content_root}/${rel_path}")"; then
      rm -f "${tmp_manifest}"
      return 1
    fi
    critical_hashes+=("${rel_path} ${file_sha}")
  done

  {
    printf 'manifest_version=1\n'
    printf 'archive_name=%s\n' "$(basename "${archive_path}")"
    printf 'archive_sha256=%s\n' "${archive_sha}"
    for entry in "${critical_hashes[@]}"; do
      printf 'critical_file %s\n' "${entry}"
    done
  } >"${tmp_manifest}"

  if ! run_privileged install -o root -g aiuser -m 640 "${tmp_manifest}" "${manifest_path}"; then
    rm -f "${tmp_manifest}"
    return 1
  fi
  rm -f "${tmp_manifest}"
}

verify_cmsscan_archive_manifest() {
  local archive_path="$1"
  local manifest_path="$2"
  local expected=""
  local actual=""

  [[ -f "${manifest_path}" ]] || return 1
  expected="$(awk -F= '$1=="archive_sha256"{print $2; exit}' "${manifest_path}")"
  [[ "${expected}" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  actual="$(sha256_file "${archive_path}")" || return 1
  [[ "${actual}" == "${expected}" ]]
}

install_cmsscan_bundle_pair() {
  local archive_source="$1"
  local manifest_source="$2"
  local archive_stage="${INFRA_ARCHIVE_PATH}.new.$$"
  local manifest_stage="${INFRA_ARCHIVE_MANIFEST_PATH}.new.$$"
  local archive_old="${INFRA_ARCHIVE_PATH}.old.$$"
  local manifest_old="${INFRA_ARCHIVE_MANIFEST_PATH}.old.$$"
  local had_archive=0
  local had_manifest=0

  vantage_register_temp_path "${archive_stage}" || return 1
  vantage_register_temp_path "${manifest_stage}" || return 1

  [[ -f "${archive_source}" && -f "${manifest_source}" && \
     ! -e "${archive_stage}" && ! -e "${manifest_stage}" && \
     ! -e "${archive_old}" && ! -e "${manifest_old}" ]] || return 1
  run_privileged install -d -m 755 "${INFRA_LIB_DIR}" || return 1
  if ! run_privileged install -o root -g aiuser -m 640 "${archive_source}" "${archive_stage}" || \
    ! run_privileged install -o root -g aiuser -m 640 "${manifest_source}" "${manifest_stage}"; then
    run_privileged rm -f "${archive_stage}" "${manifest_stage}" || true
    return 1
  fi

  if [[ -e "${INFRA_ARCHIVE_PATH}" ]]; then
    if ! run_privileged mv -T "${INFRA_ARCHIVE_PATH}" "${archive_old}"; then
      run_privileged rm -f "${archive_stage}" "${manifest_stage}" || true
      return 1
    fi
    had_archive=1
  fi
  if [[ -e "${INFRA_ARCHIVE_MANIFEST_PATH}" ]]; then
    if ! run_privileged mv -T "${INFRA_ARCHIVE_MANIFEST_PATH}" "${manifest_old}"; then
      [[ "${had_archive}" -eq 0 ]] || run_privileged mv -T "${archive_old}" "${INFRA_ARCHIVE_PATH}" || true
      run_privileged rm -f "${archive_stage}" "${manifest_stage}" || true
      return 1
    fi
    had_manifest=1
  fi

  if ! run_privileged mv -T "${archive_stage}" "${INFRA_ARCHIVE_PATH}"; then
    [[ "${had_archive}" -eq 0 ]] || run_privileged mv -T "${archive_old}" "${INFRA_ARCHIVE_PATH}" || true
    [[ "${had_manifest}" -eq 0 ]] || run_privileged mv -T "${manifest_old}" "${INFRA_ARCHIVE_MANIFEST_PATH}" || true
    run_privileged rm -f "${archive_stage}" "${manifest_stage}" || true
    return 1
  fi
  if ! run_privileged mv -T "${manifest_stage}" "${INFRA_ARCHIVE_MANIFEST_PATH}"; then
    run_privileged rm -f "${INFRA_ARCHIVE_PATH}" || true
    [[ "${had_archive}" -eq 0 ]] || run_privileged mv -T "${archive_old}" "${INFRA_ARCHIVE_PATH}" || true
    [[ "${had_manifest}" -eq 0 ]] || run_privileged mv -T "${manifest_old}" "${INFRA_ARCHIVE_MANIFEST_PATH}" || true
    run_privileged rm -f "${manifest_stage}" || true
    return 1
  fi

  if ! verify_cmsscan_archive_manifest "${INFRA_ARCHIVE_PATH}" "${INFRA_ARCHIVE_MANIFEST_PATH}"; then
    run_privileged rm -f "${INFRA_ARCHIVE_PATH}" "${INFRA_ARCHIVE_MANIFEST_PATH}" || true
    [[ "${had_archive}" -eq 0 ]] || run_privileged mv -T "${archive_old}" "${INFRA_ARCHIVE_PATH}" || true
    [[ "${had_manifest}" -eq 0 ]] || run_privileged mv -T "${manifest_old}" "${INFRA_ARCHIVE_MANIFEST_PATH}" || true
    return 1
  fi

  [[ "${had_archive}" -eq 0 ]] || run_privileged rm -f "${archive_old}" || return 1
  [[ "${had_manifest}" -eq 0 ]] || run_privileged rm -f "${manifest_old}" || return 1
}

cms_repair_runner_logger() {
  # The root-owned staged runner is trusted installer source, not a writable
  # scanner checkout. Use the system interpreter and retain its owner/mode.
  run_privileged /usr/bin/python3 - "$1" <<'PY_CMS_RUNNER_LOGGER'
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

path = Path(sys.argv[1])
metadata = path.lstat()
if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
    raise SystemExit(f"Unsupported CMS runner file: {path}")
original = path.read_bytes()
legacy_cleanup = b'''cleanup() {
  local rc=$?
  rm -rf "${TMP_DIR:-}" >/dev/null 2>&1 || true
  apply_output_ownership "${REPORT_FILE:-}" "${TOOL_LOG_DIR:-}" "${REPORTS_DIR:-}" "${LOGS_DIR:-}"
  return "${rc}"
}'''
modern_cleanup = b'''cleanup() {
  local rc=$? logger_rc=0
  trap - EXIT
  if [[ -n "${CMS_LOGGER_PID:-}" ]]; then
    # Closing the writer sends EOF; wait for both logs to finish before the
    # dispatcher can inspect this worker's process group or publish reports.
    exec 1>&"${CMS_LOGGER_STDOUT_FD}" 2>&"${CMS_LOGGER_STDERR_FD}"
    exec {CMS_LOGGER_STDOUT_FD}>&- {CMS_LOGGER_STDERR_FD}>&-
    if wait "${CMS_LOGGER_PID}"; then
      logger_rc=0
    else
      logger_rc=$?
    fi
    CMS_LOGGER_PID=""
    if (( logger_rc != 0 )); then
      printf 'cmsscan: runtime logger failed (status %s)\\n' "${logger_rc}" >&2
      (( rc != 0 )) || rc="${logger_rc}"
    fi
  fi
  rm -rf "${TMP_DIR:-}" >/dev/null 2>&1 || true
  apply_output_ownership "${REPORT_FILE:-}" "${TOOL_LOG_DIR:-}" "${REPORTS_DIR:-}" "${LOGS_DIR:-}"
  exit "${rc}"
}'''
legacy_redirect = b'exec > >(tee -a "${LOG_FILE}" "${LEGACY_LOG_FILE}") 2>&1'
modern_redirect = b'''# VANTAGE_CMS_RUNNER_JOINED_LOGGER_V1
exec {CMS_LOGGER_STDOUT_FD}>&1 {CMS_LOGGER_STDERR_FD}>&2
exec > >(exec tee -a "${LOG_FILE}" "${LEGACY_LOG_FILE}") 2>&1
CMS_LOGGER_PID=$!'''
repaired = original
for legacy, modern in [(legacy_cleanup, modern_cleanup), (legacy_redirect, modern_redirect)]:
    if repaired.count(legacy) + repaired.count(modern) != 1:
        raise SystemExit(f"Unsupported CMS runner logger source: {path}")
    repaired = repaired.replace(legacy, modern)
if subprocess.run(['/bin/bash', '-n'], input=repaired, capture_output=True).returncode:
    raise SystemExit("CMS runner logger repair failed shell syntax validation")
if repaired != original:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".cms-runner-logger-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(repaired)
            os.fchown(stream.fileno(), metadata.st_uid, metadata.st_gid)
            os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        print(f"Repaired CMS runner logger lifecycle: {path}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
PY_CMS_RUNNER_LOGGER
}

bundle_cmsscan_archive() {
  local parent_dir=""
  local source_name=""
  local tmp_dir=""
  local archive_tmp=""
  local archive_password=""
  local archive_log=""
  local manifest_tmp=""
  local manifest_root=""
  local bundle_7z_level="${INFRA_7Z_LEVEL:-3}"
  local bundle_7z_dict_size="${INFRA_7Z_DICT_SIZE:-16m}"
  local bundle_7z_threads="${INFRA_7Z_THREADS:-1}"

  if [[ ! -f "${SCRIPT_DIR}/run_cms_scanner.sh" ]]; then
    mark_failed "CMS encrypted bundle" "run_cms_scanner.sh not found"
    return 1
  fi
  if [[ ! -f "${INFRA_CMSSCAN_WRAPPER_SOURCE}" ]]; then
    mark_failed "CMS encrypted bundle" "wrapper not found: ${INFRA_CMSSCAN_WRAPPER_SOURCE}"
    return 1
  fi
  if [[ -n "${INFRA_CMSSCAN_ALIAS}" && -d "${INFRA_CMSSCAN_ALIAS}" && \
        ! -L "${INFRA_CMSSCAN_ALIAS}" ]]; then
    mark_failed "cmsscan wrapper" "alias destination is a directory: ${INFRA_CMSSCAN_ALIAS}"
    return 1
  fi

  ensure_7z_present || {
    mark_failed "CMS encrypted bundle" "7z is unavailable"
    return 1
  }
  archive_password="$(derive_archive_password || true)"
  if [[ -z "${archive_password}" ]]; then
    mark_failed "CMS encrypted bundle" "unable to derive archive password from infrauth"
    return 1
  fi

  if [[ ! "${bundle_7z_level}" =~ ^[0-9]$ ]]; then
    warn "Invalid INFRA_7Z_LEVEL=${bundle_7z_level}; using 3"
    bundle_7z_level="3"
  fi
  if [[ ! "${bundle_7z_dict_size}" =~ ^[0-9]+[kKmMgG]?$ ]]; then
    warn "Invalid INFRA_7Z_DICT_SIZE=${bundle_7z_dict_size}; using 16m"
    bundle_7z_dict_size="16m"
  fi
  if [[ ! "${bundle_7z_threads}" =~ ^[0-9]+$ || "${bundle_7z_threads}" == "0" ]]; then
    warn "Invalid INFRA_7Z_THREADS=${bundle_7z_threads}; using 1"
    bundle_7z_threads="1"
  fi

  parent_dir="$(dirname "${SCRIPT_DIR}")"
  source_name="$(basename "${SCRIPT_DIR}")"
  vantage_make_temp tmp_dir -d || {
    mark_failed "CMS encrypted bundle" "unable to create temporary workspace"
    return 1
  }
  [[ -n "${tmp_dir}" && -d "${tmp_dir}" ]] || {
    mark_failed "CMS encrypted bundle" "temporary workspace is unavailable"
    return 1
  }
  archive_tmp="${tmp_dir}/${INFRA_ARCHIVE_NAME}"
  manifest_tmp="${tmp_dir}/${INFRA_ARCHIVE_NAME}.manifest"
  manifest_root="${tmp_dir}/manifest-content"
  archive_log="${tmp_dir}/7z.log"

  local -a archive_args=(
    a
    -t7z
    -m0=lzma2
    "-mx=${bundle_7z_level}"
    "-md=${bundle_7z_dict_size}"
    "-mmt=${bundle_7z_threads}"
    -mhe=on
    -bso0
    -bsp0
    -bse0
    "-p${archive_password}"
    "${archive_tmp}"
    "${source_name}"
    "-xr!.git"
    "-xr!.venv"
    "-xr!.venvs"
    "-xr!venv"
    "-xr!__pycache__"
    "-xr!*.pyc"
    "-xr!*.pyo"
    "-xr!.pytest_cache"
    "-xr!.ruff_cache"
    "-xr!.mypy_cache"
    "-xr!*.egg-info"
    "-xr!*.log"
    "-xr!*.orig"
    "-xr!*.rej"
    "-xr!*.wrapper.x"
    "-xr!*.wrapper.x.c"
    "-xr!*conflicted copy*"
    "-xr!build"
    "-xr!dist"
    "-xr!htmlcov"
    "-xr!node_modules"
    "-xr!logs"
    "-xr!reports"
    "-xr!works"
    "-x!${source_name}/logs"
    "-xr!${source_name}/logs/*"
    "-x!${source_name}/reports"
    "-xr!${source_name}/reports/*"
    "-x!${source_name}/works"
    "-xr!${source_name}/works/*"
  )

  log "Creating encrypted CMS scanner bundle: ${INFRA_ARCHIVE_PATH}"
  if ! (cd "${parent_dir}" && 7z "${archive_args[@]}" >/dev/null 2>"${archive_log}"); then
    if [[ -s "${archive_log}" ]]; then
      warn "7z error details:"
      sed -n '1,12p' "${archive_log}" >&2
    fi
    rm -rf "${tmp_dir}"
    mark_failed "CMS encrypted bundle" "7z archive creation failed"
    return 1
  fi
  if [[ -f "${archive_tmp}.7z" && ! -f "${archive_tmp}" ]]; then
    mv -f "${archive_tmp}.7z" "${archive_tmp}"
  fi
  if [[ ! -f "${archive_tmp}" ]]; then
    rm -rf "${tmp_dir}"
    mark_failed "CMS encrypted bundle" "archive file was not created"
    return 1
  fi
  if ! 7z t "-p${archive_password}" "${archive_tmp}" >/dev/null 2>>"${archive_log}"; then
    if [[ -s "${archive_log}" ]]; then
      warn "7z verification details:"
      sed -n '1,12p' "${archive_log}" >&2
    fi
    rm -rf "${tmp_dir}"
    unset archive_password
    mark_failed "CMS encrypted bundle" "encrypted archive self-test failed"
    return 1
  fi
  if ! mkdir -p "${manifest_root}" || \
    ! 7z x -t7z "-p${archive_password}" -y "-o${manifest_root}" \
      "${archive_tmp}" \
      "${source_name}/run_cms_scanner.sh" \
      "${source_name}/installer.sh" \
      "${source_name}/scripts/cmsscan.wrapper" \
      "${source_name}/scripts/patch_vulnx_detector.py" \
      >/dev/null 2>>"${archive_log}"; then
    rm -rf "${tmp_dir}"
    unset archive_password
    mark_failed "CMS encrypted bundle" "unable to read critical files back from archive"
    return 1
  fi
  unset archive_password

  write_cmsscan_archive_manifest \
    "${archive_tmp}" "${manifest_tmp}" "${manifest_root}/${source_name}" || {
    rm -rf "${tmp_dir}"
    mark_failed "CMS encrypted bundle" "manifest creation failed"
    return 1
  }
  verify_cmsscan_archive_manifest "${archive_tmp}" "${manifest_tmp}" || {
    rm -rf "${tmp_dir}"
    mark_failed "CMS encrypted bundle" "manifest verification failed"
    return 1
  }
  if ! install_cmsscan_bundle_pair "${archive_tmp}" "${manifest_tmp}"; then
    rm -rf "${tmp_dir}"
    mark_failed "CMS encrypted bundle" "archive/manifest installation failed"
    return 1
  fi
  rm -rf "${tmp_dir}"

  verify_cmsscan_archive_manifest "${INFRA_ARCHIVE_PATH}" "${INFRA_ARCHIVE_MANIFEST_PATH}" || {
    mark_failed "CMS encrypted bundle" "installed manifest verification failed"
    return 1
  }

  mark_installed "CMS encrypted bundle (${INFRA_ARCHIVE_PATH})"
}

resolve_shc_cmd() {
  if has_cmd shc; then
    command -v shc
    return 0
  fi
  if [[ -x /usr/local/bin/shc ]]; then
    printf '%s\n' /usr/local/bin/shc
    return 0
  fi
  return 1
}

shc_package_available() {
  local candidate=""

  if ! has_cmd apt-cache; then
    return 1
  fi

  candidate="$(apt-cache policy shc 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
  [[ -n "${candidate}" && "${candidate}" != "(none)" ]]
}

download_shc_file() {
  local url="$1"
  local dest="$2"

  if has_cmd curl; then
    curl -fL --progress-bar "${url}" -o "${dest}"
    return
  fi
  if has_cmd wget; then
    wget --progress=bar:force:noscroll -O "${dest}" "${url}"
    return
  fi

  return 1
}

install_shc_from_source() {
  local shc_tag=""
  local shc_api_url="https://api.github.com/repos/neurobin/shc/releases/latest"
  local shc_url=""
  local alt_tag=""
  local build_dir=""
  local archive_path=""
  local src_dir=""
  local jobs=1
  local -a build_packages=()

  shc_tag="${SHC_VERSION:-}"
  if [[ -z "${shc_tag}" ]] && has_cmd curl && has_cmd jq; then
    shc_tag="$(curl -fsSL "${shc_api_url}" | jq -r '.tag_name // empty' || true)"
  fi
  if [[ -z "${shc_tag}" ]]; then
    shc_tag="4.0.3"
  fi

  if ! has_cmd make; then
    build_packages+=("make")
  fi
  if ! has_cmd cc && ! has_cmd gcc; then
    build_packages+=("gcc")
  fi
  if ! has_cmd tar; then
    build_packages+=("tar")
  fi
  if ! has_cmd curl && ! has_cmd wget; then
    build_packages+=("curl")
  fi
  if ((${#build_packages[@]} > 0)); then
    apt_install_packages "shc source build dependencies" "${build_packages[@]}" >/dev/null 2>&1 || true
  fi

  if ! has_cmd make || { ! has_cmd cc && ! has_cmd gcc; } || ! has_cmd tar || { ! has_cmd curl && ! has_cmd wget; }; then
    return 1
  fi

  vantage_make_temp build_dir -d /tmp/shc_build_XXXXXX || return 1
  [[ -n "${build_dir}" && -d "${build_dir}" ]] || return 1
  archive_path="${build_dir}/shc.tar.gz"
  shc_url="https://github.com/neurobin/shc/archive/refs/tags/${shc_tag}.tar.gz"

  log "Downloading shc source: ${shc_url}"
  if ! download_shc_file "${shc_url}" "${archive_path}"; then
    if [[ "${shc_tag#v}" != "${shc_tag}" ]]; then
      alt_tag="${shc_tag#v}"
    else
      alt_tag="v${shc_tag}"
    fi
    shc_url="https://github.com/neurobin/shc/archive/refs/tags/${alt_tag}.tar.gz"
    log "Retrying shc source download: ${shc_url}"
    if ! download_shc_file "${shc_url}" "${archive_path}"; then
      rm -rf "${build_dir}"
      return 1
    fi
  fi

  if ! tar -xf "${archive_path}" -C "${build_dir}"; then
    rm -rf "${build_dir}"
    return 1
  fi
  src_dir="$(find "${build_dir}" -mindepth 1 -maxdepth 1 -type d -name 'shc-*' | head -n 1)"
  if [[ -z "${src_dir}" ]]; then
    rm -rf "${build_dir}"
    return 1
  fi

  if [[ ! -x "${src_dir}/configure" && -x "${src_dir}/autogen.sh" ]]; then
    apt_install_packages "shc autogen dependencies" autoconf automake >/dev/null 2>&1 || true
    (cd "${src_dir}" && ./autogen.sh)
  fi

  if [[ ! -x "${src_dir}/configure" ]]; then
    rm -rf "${build_dir}"
    return 1
  fi

  if has_cmd nproc; then
    jobs="$(nproc)"
  fi

  if ! (cd "${src_dir}" && ./configure); then
    rm -rf "${build_dir}"
    return 1
  fi
  if ! make -C "${src_dir}" -j"${jobs}"; then
    rm -rf "${build_dir}"
    return 1
  fi
  if ! run_privileged make -C "${src_dir}" install; then
    rm -rf "${build_dir}"
    return 1
  fi

  rm -rf "${build_dir}"
}

ensure_shc_present() {
  local shc_cmd=""
  local shc_tag="${SHC_VERSION:-}"
  local installed_version=""

  if [[ -z "${shc_tag}" ]] && has_cmd curl; then
    shc_tag="$(curl -fsSL https://api.github.com/repos/neurobin/shc/releases/latest 2>/dev/null |
      sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' |
      head -n 1)"
  fi
  [[ -n "${shc_tag}" ]] || shc_tag="4.0.3"

  if vantage_shc_current "${shc_tag}"; then
    installed_version="$(vantage_shc_installed_version)"
    log "SKIP: shc - installed ${installed_version} is current/newer than online ${shc_tag#v}"
    return 0
  fi

  if shc_package_available; then
    log "Checking shc package from apt."
    apt_install_packages "shc compiler" shc >/dev/null 2>&1 || true
    if vantage_shc_current "${shc_tag}"; then
      return 0
    fi
  fi

  log "shc is missing, unusable, or older than ${shc_tag#v}; building from source."
  SHC_VERSION="${shc_tag}" install_shc_from_source || return 1

  if ! resolve_shc_cmd >/dev/null 2>&1 && [[ -x /usr/local/bin/shc ]]; then
    run_privileged ln -sfnT /usr/local/bin/shc /usr/bin/shc >/dev/null 2>&1 || true
  fi

  shc_cmd="$(resolve_shc_cmd || true)"
  [[ -n "${shc_cmd}" ]]
}

compile_cmsscan_wrapper() {
  local shc_cmd=""
  local tmp_dir=""
  local tmp_source=""
  local tmp_bin=""
  local staged_bin="${INFRA_CMSSCAN_BIN}.new.$$"
  local previous_bin="${INFRA_CMSSCAN_BIN}.old.$$"
  local had_previous=0

  vantage_register_temp_path "${staged_bin}" || return 1

  if [[ ! -f "${INFRA_CMSSCAN_WRAPPER_SOURCE}" ]]; then
    mark_failed "cmsscan wrapper" "wrapper not found: ${INFRA_CMSSCAN_WRAPPER_SOURCE}"
    return 1
  fi

  ensure_shc_present || {
    mark_failed "cmsscan wrapper" "shc is unavailable"
    return 1
  }
  shc_cmd="$(resolve_shc_cmd)"

  vantage_make_temp tmp_dir -d || {
    mark_failed "cmsscan wrapper" "unable to create temporary build workspace"
    return 1
  }
  [[ -n "${tmp_dir}" && -d "${tmp_dir}" ]] || {
    mark_failed "cmsscan wrapper" "temporary build workspace is unavailable"
    return 1
  }
  tmp_source="${tmp_dir}/cmsscan.wrapper"
  tmp_bin="${tmp_dir}/cmsscan"
  if ! sed '1 s|^#!.*$|#!/bin/bash|' "${INFRA_CMSSCAN_WRAPPER_SOURCE}" >"${tmp_source}"; then
    rm -rf "${tmp_dir}"
    mark_failed "cmsscan wrapper" "failed to prepare wrapper source"
    return 1
  fi
  chmod 700 "${tmp_source}"

  log "Compiling ${INFRA_CMSSCAN_WRAPPER_SOURCE} with shc into ${INFRA_CMSSCAN_BIN}"
  if ! "${shc_cmd}" -f "${tmp_source}" -o "${tmp_bin}" >/dev/null 2>&1; then
    rm -rf "${tmp_dir}"
    mark_failed "cmsscan wrapper" "shc compilation failed"
    return 1
  fi
  run_privileged install -d -o root -g aiuser -m 750 /opt/infrascan/bin || return 1
  if [[ -e "${staged_bin}" || -e "${previous_bin}" ]] || \
    ! run_privileged install -o root -g aiuser -m 750 "${tmp_bin}" "${staged_bin}"; then
    rm -rf "${tmp_dir}"
    mark_failed "cmsscan wrapper" "cannot stage ${INFRA_CMSSCAN_BIN}"
    return 1
  fi
  # Hardened hosts commonly mount /tmp with noexec. Smoke-test the compiled
  # candidate only after staging it beside the final executable.
  if ! run_as_install_user env VANTAGE_DISPATCHED=1 "${staged_bin}" --help >/dev/null 2>&1; then
    run_privileged rm -f "${staged_bin}" || true
    rm -rf "${tmp_dir}"
    mark_failed "cmsscan wrapper" "staged wrapper smoke test failed"
    return 1
  fi
  if [[ -e "${INFRA_CMSSCAN_BIN}" || -L "${INFRA_CMSSCAN_BIN}" ]]; then
    if ! run_privileged mv "${INFRA_CMSSCAN_BIN}" "${previous_bin}"; then
      run_privileged rm -f "${staged_bin}" || true
      rm -rf "${tmp_dir}"
      mark_failed "cmsscan wrapper" "cannot preserve previous ${INFRA_CMSSCAN_BIN}"
      return 1
    fi
    had_previous=1
  fi
  if ! run_privileged mv "${staged_bin}" "${INFRA_CMSSCAN_BIN}"; then
    [[ "${had_previous}" -eq 0 ]] || run_privileged mv "${previous_bin}" "${INFRA_CMSSCAN_BIN}" || true
    rm -rf "${tmp_dir}"
    mark_failed "cmsscan wrapper" "cannot activate ${INFRA_CMSSCAN_BIN}"
    return 1
  fi
  run_privileged test -x /usr/bin/infra-scan-main || return 1
  run_privileged ln -sfnT /usr/bin/infra-scan-main "${INFRA_CMSSCAN_PUBLIC_BIN}" || return 1
  if [[ -n "${INFRA_CMSSCAN_ALIAS}" ]]; then
    run_privileged ln -sfnT /usr/bin/infra-scan-main "${INFRA_CMSSCAN_ALIAS}" || {
      run_privileged rm -f "${INFRA_CMSSCAN_BIN}" || true
      [[ "${had_previous}" -eq 0 ]] || run_privileged mv "${previous_bin}" "${INFRA_CMSSCAN_BIN}" || true
      rm -rf "${tmp_dir}"
      mark_failed "cmsscan wrapper" "cannot install alias ${INFRA_CMSSCAN_ALIAS}"
      return 1
    }
  fi
  [[ "${had_previous}" -eq 0 ]] || run_privileged rm -f "${previous_bin}" || \
    warn "cmsscan wrapper: previous binary remains at ${previous_bin}"
  rm -rf "${tmp_dir}"

  CMS_PUBLICATION_COMPLETE=1
  mark_installed "cmsscan wrapper (${INFRA_CMSSCAN_BIN})"
}

# -----------------------------------------------------------------------------
# Tool installers (one function per integrated scanner/tool)
# -----------------------------------------------------------------------------

resolve_real_wpscan_path() {
  local wrapper_path=""
  local candidate=""
  local candidate_real=""
  local -a candidates=()

  wrapper_path="$(readlink -f "${BIN_DIR}/wpscan" 2>/dev/null || true)"
  if [[ -n "${USER_GEM_BIN}" ]]; then
    candidates+=("${USER_GEM_BIN}/wpscan")
  fi
  candidates+=(
    "${INSTALL_HOME}"/.local/share/gem/ruby/*/bin/wpscan
    /usr/local/bin/wpscan
    /usr/bin/wpscan
  )

  for candidate in "${candidates[@]}"; do
    [[ -x "${candidate}" ]] || continue
    candidate_real="$(readlink -f "${candidate}" 2>/dev/null || printf '%s' "${candidate}")"
    if [[ -n "${wrapper_path}" && "${candidate_real}" == "${wrapper_path}" ]]; then
      continue
    fi
    printf '%s\n' "${candidate}"
    return 0
  done

  return 1
}

# WordPress scanner (system package or gem install fallback).
# install_wpscan is supplied by scripts/install/tools/wpscan.sh.

# CMSmap source install + runtime patching for exploitdb/bootstrap behavior.
# install_cmsmap is supplied by scripts/install/tools/cmsmap.sh.

# CMSeek source install + wrapper.
# install_cmseek is supplied by scripts/install/tools/cmseek.sh.

# Droopescan install with Python-version compatibility handling.
# install_droopescan is supplied by scripts/install/tools/droopescan.sh.

# Joomla scanner installed from OWASP repo.
# install_joomscan is supplied by scripts/install/tools/joomscan.sh.

# Drupwn source install from staged copy to avoid root-owned build artifacts.
# install_drupwn is supplied by scripts/install/tools/drupwn.sh.

# vBulletin scanner (Perl).
# install_vbscan is supplied by scripts/install/tools/vbscan.sh.

# CMSScan server/runtime installation.
# install_cmsscan is supplied by scripts/install/tools/cmsscan.sh.

# VulnX installation + detector hardening patch.
# install_vulnx is supplied by scripts/install/tools/vulnx.sh.

# Clusterd Python2-era code auto-converted and shimmed for Python3 runtime.
# install_clusterd is supplied by scripts/install/tools/clusterd.sh.

# WPSeku source install.
# install_wpseku is supplied by scripts/install/tools/wpseku.sh.

# WPXF gem install + wrapper.
# install_wpxf is supplied by scripts/install/tools/wpxf.sh.

# WPForce is Python 2-era code. Convert a compatibility copy and run it only
# with the canonical Python 3 environment; never install to a Python 2 user
# site or create a separate environment.
# install_wpforce is supplied by scripts/install/tools/wpforce.sh.

# JoomlaVS install with direct gem deps on modern Ruby.
# install_joomlavs is supplied by scripts/install/tools/joomlavs.sh.

# Fingerprinter install from its canonical public repo with runtime compatibility patches.
# install_fingerprinter is supplied by scripts/install/tools/fingerprinter.sh.

# AutoWPScan install with optional-token patching and safer parsing behavior.
# install_autowpscan is supplied by scripts/install/tools/autowpscan.sh.

# The integrated AEM selector is a detector, not the upstream callback-based
# attack workflow. Reuse actual GET-only upstream fingerprints without opening
# a listener, inventing a callback host, posting nodes, or guessing credentials.
cms_aem_detector_wrapper_body() {
  local source_root="$1"
  printf 'exec "${CANONICAL_PYTHON}" - "%s/aem_discoverer.py" "$@" <<"PY_AEM_READ_ONLY_DETECTOR"\n' "$source_root"
  cat <<'PY_AEM_READ_ONLY_DETECTOR'
# VANTAGE_AEM_READ_ONLY_DETECTOR_V1
import argparse
import concurrent.futures
import importlib.util
import sys
import threading
import time
from pathlib import Path
from urllib.parse import urlsplit

source = Path(sys.argv[1])
parser = argparse.ArgumentParser(
    prog="aem-hacker",
    description="AEM Detector: read-only upstream fingerprints; no callback listener or state-changing checks.",
)
parser.add_argument("-u", "--url", required=True, help="HTTP(S) target URL")
parser.add_argument("--workers", type=int, default=4, help="Concurrent fingerprint checks, 1 through 4")
parser.add_argument("--timeout", type=float, default=5, help="Per-request timeout in seconds, at most 60")
parser.add_argument("--proxy", help="HTTP(S) proxy URL")
parser.add_argument("--debug", action="store_true", help="Print upstream fingerprint diagnostics")
args = parser.parse_args(sys.argv[2:])
parts = urlsplit(args.url)
if parts.scheme not in ("http", "https") or not parts.hostname or parts.username or parts.password:
    parser.error("--url must be an HTTP(S) URL without embedded credentials")
if not 1 <= args.workers <= 4:
    parser.error("--workers must be between 1 and 4")
if not 0 < args.timeout <= 60:
    parser.error("--timeout must be greater than zero and at most 60")

try:
    spec = importlib.util.spec_from_file_location("vantage_aem_upstream_detector", source)
    if spec is None or spec.loader is None:
        raise RuntimeError("upstream detector module cannot be loaded")
    upstream = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(upstream)
    names = (
        "by_login_page", "by_csrf_token", "by_geometrixx_page",
        "by_get_servlet", "by_bin_receive", "by_css_js", "by_siren_api",
    )
    methods = [getattr(upstream, name) for name in names]
    if not all(callable(method) for method in methods):
        raise RuntimeError("upstream fingerprint interface is incomplete")
    proxy = {"http": args.proxy, "https": args.proxy} if args.proxy else {}
    lock = threading.Lock()
    errors = []
    request_count = [0]
    deadline = time.monotonic() + 120

    # Upstream catches request exceptions inside its detectors. Retain them
    # separately so a broken transport cannot be mistaken for a clean scan.
    def readonly_request(url, method="GET", data=None, additional_headers=None, proxy=None):
        try:
            if method.upper() != "GET" or data is not None:
                raise RuntimeError("state-changing fingerprint request was refused")
            with lock:
                request_count[0] += 1
                if request_count[0] > 512:
                    raise RuntimeError("detector request budget exceeded")
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError("detector time budget exceeded")
            headers = {"User-Agent": "VANTAGE-AEM-ReadOnly-Detector"}
            if additional_headers:
                headers.update(additional_headers)
            return upstream.requests.request(
                "GET", url, headers=headers, proxies=proxy or {},
                timeout=min(args.timeout, remaining), verify=False,
                allow_redirects=False,
            )
        except Exception as exc:
            with lock:
                errors.append(str(exc))
            raise

    upstream.http_request = readonly_request
    initial = readonly_request(args.url, proxy=proxy)
    if initial.status_code >= 400:
        raise RuntimeError("target preflight returned HTTP %s" % initial.status_code)
    print("AEM detector mode: read-only upstream fingerprints (no callback listener)")
    print("Target: " + args.url)
    matched = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        tasks = {pool.submit(method, args.url, args.debug, proxy): name
                 for name, method in zip(names, methods)}
        for future in concurrent.futures.as_completed(tasks):
            name = tasks[future]
            if future.result():
                matched.append(name)
    if errors:
        raise RuntimeError("fingerprint transport failed: " + errors[0])
    if matched:
        print("AEM detected by: " + ", ".join(sorted(matched)))
    else:
        print("No AEM fingerprint matched; checked %d upstream methods" % len(methods))
    print("Requests: %d" % request_count[0])
except Exception as exc:
    print("AEM detector error: " + str(exc), file=sys.stderr)
    raise SystemExit(2)
PY_AEM_READ_ONLY_DETECTOR
  printf '%s\n' 'PY_AEM_READ_ONLY_DETECTOR'
}

cms_aem_detector_runtime_is_usable() {
  [[ -x "${BIN_DIR}/aem-hacker" && -x "${BIN_DIR}/aem-discoverer" ]] || return 1
  grep -Fq 'VANTAGE_AEM_READ_ONLY_DETECTOR_V1' "${BIN_DIR}/aem-hacker" || return 1
  cms_runtime_probe_is_usable "0" 'AEM Detector: read-only upstream fingerprints' \
    "${BIN_DIR}/aem-hacker" --help
}

# AEM detector/discoverer wrappers from aem-hacker project.
# install_aem_detector is supplied by scripts/install/tools/aem_detector.sh.

# -----------------------------------------------------------------------------
# Post-install scanner database/signature updates
# -----------------------------------------------------------------------------

cms_update_progress_stop() {
  if [[ -n "${CMS_UPDATE_PROGRESS_PID:-}" ]]; then
    kill "${CMS_UPDATE_PROGRESS_PID}" 2>/dev/null || true
    wait "${CMS_UPDATE_PROGRESS_PID}" 2>/dev/null || true
    CMS_UPDATE_PROGRESS_PID=""
  fi
}

cms_update_progress_start() {
  local label="$1"
  local owner_pid="$BASHPID"
  local interval="${CMS_INSTALLER_UPDATE_PROGRESS_SECONDS:-15}"
  local started="$SECONDS"
  [[ "$interval" =~ ^[1-9][0-9]*$ ]] || interval=15
  cms_update_progress_stop
  CMS_UPDATE_PROGRESS_STARTED="$started"
  log "UPDATE: ${label}: started" >&2
  (
    # A heartbeat never owns installation cleanup. Stop and reap its current
    # sleep as well as the worker itself when the foreground operation ends.
    trap - EXIT
    sleep_pid=""
    trap '[[ -z "$sleep_pid" ]] || { kill "$sleep_pid" 2>/dev/null || true; wait "$sleep_pid" 2>/dev/null || true; }; exit 0' HUP INT TERM
    while kill -0 "$owner_pid" 2>/dev/null; do
      sleep "$interval" &
      sleep_pid=$!
      wait "$sleep_pid" || exit 0
      sleep_pid=""
      kill -0 "$owner_pid" 2>/dev/null || exit 0
      log "UPDATE: ${label}: running ($((SECONDS - started))s elapsed)" >&2
    done
  ) &
  CMS_UPDATE_PROGRESS_PID=$!
}

cms_update_progress_finish() {
  local label="$1" status="$2"
  cms_update_progress_stop
  log "UPDATE: ${label}: finished in $((SECONDS - CMS_UPDATE_PROGRESS_STARTED))s (exit ${status})" >&2
}

run_timed_user_update() {
  local timeout_seconds="$1"
  shift
  local rc=0 label="${CMS_UPDATE_PROGRESS_LABEL:-Scanner database update}"

  cms_update_progress_start "$label"
  if has_cmd timeout; then
    run_user_cmd timeout --signal=INT --kill-after=10s "${timeout_seconds}" "$@" || rc=$?
  else
    run_user_cmd "$@" || rc=$?
  fi
  cms_update_progress_finish "$label" "$rc"
  return "$rc"
}

run_timed_user_update_capture() {
  local output_file="$1"
  local timeout_seconds="$2"
  shift 2
  local preview=""
  local rc=0
  local label="${CMS_UPDATE_PROGRESS_LABEL:-Scanner database update}"
  local -a update_cmd=("$@")

  if has_cmd timeout; then
    update_cmd=(timeout --signal=INT --kill-after=10s "${timeout_seconds}" "${update_cmd[@]}")
  fi
  preview="$(command_preview "${update_cmd[@]}")"
  log "RUN(user:${INSTALL_USER}): ${preview}"
  cms_update_progress_start "$label"
  if run_and_capture_output "${output_file}" run_as_install_user "${update_cmd[@]}"; then
    rc=0
  else
    rc=$?
  fi
  cms_update_progress_finish "$label" "$rc"
  if [[ "${SHOW_COMMAND_OUTPUT}" -eq 1 ]]; then
    cat "${output_file}"
  fi
  return "${rc}"
}

# Restore a mutable directory with same-filesystem renames. If any step fails,
# the caller's backup is left intact and the previous live directory is put
# back whenever possible.
restore_directory_from_backup() {
  local backup_dir="$1"
  local target_dir="$2"
  local restore_dir=""
  local displaced_dir="${target_dir}.failed-restore.$$"

  [[ -n "${backup_dir}" && -d "${backup_dir}" && -n "${target_dir}" && \
     "${target_dir}" != "/" && -d "${target_dir}" && ! -e "${displaced_dir}" ]] || return 1
  restore_dir="$(capture_user_cmd mktemp -d "${target_dir}.restore.XXXXXX" 2>/dev/null || true)"
  [[ -z "${restore_dir}" ]] || vantage_register_temp_path "${restore_dir}" || return 1
  [[ -n "${restore_dir}" && -d "${restore_dir}" ]] || return 1
  if ! run_user_cmd cp -a "${backup_dir}/." "${restore_dir}/"; then
    run_user_cmd rm -rf "${restore_dir}" || true
    return 1
  fi
  if ! run_user_cmd mv "${target_dir}" "${displaced_dir}"; then
    run_user_cmd rm -rf "${restore_dir}" || true
    return 1
  fi
  if ! run_user_cmd mv "${restore_dir}" "${target_dir}"; then
    run_user_cmd mv "${displaced_dir}" "${target_dir}" || true
    return 1
  fi
  run_user_cmd rm -rf "${displaced_dir}" || return 1
}

update_wpscan_database() {
  local name="WPScan database"

  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    mark_update_skipped "$name" "disabled by --no-update"
    return 0
  fi
  if [[ ! -x "${BIN_DIR}/wpscan" ]]; then
    mark_update_failed "$name" "wpscan command is unavailable"
    return 1
  fi
  if ! CMS_UPDATE_PROGRESS_LABEL="$name" run_timed_user_update "${SCANNER_DATA_UPDATE_TIMEOUT}" \
    env VANTAGE_DISPATCHED=1 "${BIN_DIR}/wpscan" --update; then
    mark_update_failed "$name" "wpscan --update failed"
    return 1
  fi
  mark_updated "$name"
}

update_cmsmap_database() {
  local name="CMSmap helper data"
  local data_dir=""
  local candidate_dir=""
  local previous_dir=""

  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    mark_update_skipped "$name" "disabled by --no-update"
    return 0
  fi
  data_dir="$(capture_user_cmd bash -lc \
    "for d in \"${VENV_DIR}\"/lib/python*/site-packages/cmsmap/data; do if [[ -d \"\${d}\" ]]; then printf '%s\\n' \"\${d}\"; break; fi; done" || true)"
  if [[ -z "${data_dir}" || ! -d "${data_dir}" ]]; then
    mark_update_failed "$name" "installed CMSmap data directory is unavailable"
    return 1
  fi
  if ! prepare_runtime_candidate "${data_dir}" "${data_dir}"; then
    mark_update_failed "$name" "unable to prepare a staged data candidate"
    return 1
  fi
  candidate_dir="${RUNTIME_CANDIDATE}"

  if ! CMS_UPDATE_PROGRESS_LABEL="$name" run_timed_user_update "${SCANNER_DATA_UPDATE_TIMEOUT}" \
    env CMSMAP_DATA_DIR="${candidate_dir}" "${VENV_DIR}/bin/python" - <<'PY'
import os
import re
import subprocess
from pathlib import Path

data = Path(os.environ["CMSMAP_DATA_DIR"])

helper_lists = [
    "wp_plugins_small.txt", "joo_plugins_small.txt", "dru_plugins_small.txt",
    "wp_themes_small.txt",
    "wp_defaultfiles.txt", "wp_defaultfolders.txt",
    "joo_defaultfiles.txt", "joo_defaultfolders.txt",
    "dru_defaultfiles.txt", "dru_defaultfolders.txt",
    "moo_defaultfiles.txt", "moo_defaultfolders.txt",
]
for filename in helper_lists:
    source = data / filename
    values = sorted(set(
        line.strip() for line in source.read_text(encoding="utf-8", errors="ignore").splitlines()
        if line.strip()
    ), key=str.casefold)
    if not values:
        raise SystemExit(f"CMSmap native/generated helper list is empty: {source}")
    source.write_text("\n".join(values) + "\n", encoding="utf-8")

repositories = {
    "wp_versions.txt": "https://github.com/WordPress/wordpress-develop.git",
    "joo_versions.txt": "https://github.com/joomla/joomla-cms.git",
    "dru_versions.txt": "https://github.com/drupal/drupal.git",
    "moo_versions.txt": "https://github.com/moodle/moodle.git",
}

def version_key(value):
    return (tuple(int(part) for part in re.findall(r"\d+", value)), value.lower())

for filename, repo in repositories.items():
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "--refs", repo],
        check=True,
        capture_output=True,
        text=True,
        timeout=240,
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_ASKPASS": "/bin/echo"},
    )
    versions = set()
    for line in result.stdout.splitlines():
        if "refs/tags/" not in line:
            continue
        tag = line.split("refs/tags/", 1)[1]
        # CMSmap later checks out tags/<stored value>; preserve the exact Git
        # tag spelling (notably Moodle's leading "v") while selecting stable
        # numeric release tags only.
        stable_pattern = r"^v\d+(?:\.\d+){2}$" if filename == "moo_versions.txt" else r"^\d+(?:\.\d+){1,3}$"
        if not re.fullmatch(stable_pattern, tag):
            continue
        # Joomla publishes numeric test tags with patch/build values >= 100;
        # they are not release versions even though their spelling is numeric.
        if filename == "joo_versions.txt":
            parts = [int(part) for part in tag.split(".")]
            if parts[0] in {11, 12, 13} or parts[-1] >= 100:
                continue
        versions.add(tag)
    if not versions:
        raise SystemExit(f"no release tags returned for {repo}")
    ordered = sorted(versions, key=version_key, reverse=True)
    (data / filename).write_text("\n".join(ordered) + "\n", encoding="utf-8")

required = [
    "wp_plugins_small.txt", "joo_plugins_small.txt", "dru_plugins_small.txt",
    "wp_themes_small.txt",
    "wp_versions.txt", "joo_versions.txt", "dru_versions.txt", "moo_versions.txt",
    "wp_defaultfiles.txt", "wp_defaultfolders.txt",
    "joo_defaultfiles.txt", "joo_defaultfolders.txt",
    "dru_defaultfiles.txt", "dru_defaultfolders.txt",
    "moo_defaultfiles.txt", "moo_defaultfolders.txt",
]
for filename in required:
    path = data / filename
    if not path.exists() or path.stat().st_size == 0:
        raise SystemExit(f"CMSmap helper data is empty: {path}")
PY
  then
    discard_runtime_candidate "${candidate_dir}" "${data_dir}" || true
    mark_update_failed "$name" "helper/tag refresh failed; previous data left intact"
    return 1
  fi

  if ! activate_runtime_candidate "${candidate_dir}" "${data_dir}"; then
    discard_runtime_candidate "${candidate_dir}" "${data_dir}" || true
    mark_update_failed "$name" "unable to activate refreshed data"
    return 1
  fi
  previous_dir="${RUNTIME_PREVIOUS}"
  finalize_runtime_activation "${previous_dir}" "${data_dir}" || \
    warn "${name}: previous data remains at ${previous_dir}"
  mark_updated "$name"
}

update_droopescan_database() {
  local name="Droopescan signatures"
  local plugins_dir=""
  local backup=""
  local workspace=""
  local update_ok=0

  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    mark_update_skipped "$name" "disabled by --no-update"
    return 0
  fi
  if [[ ! -x "${VENV_DIR}/bin/droopescan" ]]; then
    mark_update_failed "$name" "droopescan command is unavailable"
    return 1
  fi
  plugins_dir="$(capture_user_cmd "${VENV_DIR}/bin/python" -c \
    'import pathlib, dscan; print(pathlib.Path(dscan.__file__).resolve().parent / "plugins")' \
    2>/dev/null || true)"
  backup="$(capture_user_cmd mktemp -d || true)"
  workspace="$(capture_user_cmd mktemp -d || true)"
  [[ -z "${backup}" ]] || vantage_register_temp_path "${backup}" || return 1
  [[ -z "${workspace}" ]] || vantage_register_temp_path "${workspace}" || return 1
  if [[ -z "${plugins_dir}" || ! -d "${plugins_dir}" || \
        -z "${backup}" || ! -d "${backup}" || \
        -z "${workspace}" || ! -d "${workspace}" ]] || \
    ! run_user_cmd cp -a "${plugins_dir}/." "${backup}/"; then
    [[ -z "${backup}" || ! -d "${backup}" ]] || run_user_cmd rm -rf "${backup}" || true
    [[ -z "${workspace}" || ! -d "${workspace}" ]] || run_user_cmd rm -rf "${workspace}" || true
    mark_update_failed "$name" "unable to prepare signature backup/workspace"
    return 1
  fi
  # This supported updater is intentionally hidden from Droopescan's top-level
  # help. Wheel installs have no Git metadata, but upstream's age check calls
  # `git log` on files in site-packages. Use the installed file timestamp for
  # this update process so the native updater also works outside a Git clone.
  # Its relative .update-workspace remains isolated from the project/archive.
  # shellcheck disable=SC2016 # Positional parameters expand in the inner bash.
  if CMS_UPDATE_PROGRESS_LABEL="$name" run_timed_user_update "${SCANNER_DATA_UPDATE_TIMEOUT}" bash -c \
    'cd "$1" && exec "$2" -' \
    _ "${workspace}" "${VENV_DIR}/bin/python" <<'PY'
import os
import sys
from datetime import datetime

import dscan.common.update_api as update_api


def installed_file_mtime(path):
    return datetime.fromtimestamp(os.path.getmtime(path))


update_api.file_mtime = installed_file_mtime
sys.argv = ["droopescan", "update"]
from dscan import droopescan

droopescan.main()
PY
  then
    if run_user_cmd "${VENV_DIR}/bin/python" - "${plugins_dir}" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(sys.argv[1])
xml_files = list(root.glob("*/versions.xml"))
data_files = list(root.glob("*/plugins.txt")) + list(root.glob("*/themes.txt"))
if not xml_files or not data_files:
    raise SystemExit("Droopescan signature files are missing")
for path in xml_files:
    ET.parse(path)
for path in data_files:
    if path.stat().st_size == 0:
        raise SystemExit(f"Droopescan produced an empty signature file: {path}")
PY
    then
      update_ok=1
    fi
  fi

  run_user_cmd rm -rf "${workspace}" || true
  if [[ "${update_ok}" -eq 1 ]]; then
    run_user_cmd rm -rf "${backup}" || true
    mark_updated "$name"
    return 0
  fi

  if restore_directory_from_backup "${backup}" "${plugins_dir}"; then
    run_user_cmd rm -rf "${backup}" || true
    mark_update_failed "$name" "droopescan update failed validation; previous signatures restored"
  else
    mark_update_failed "$name" "update and rollback failed; temporary backup will be removed at installer exit"
  fi
  return 1
}

update_drupwn_database() {
  local name="Drupwn Drupal wordlist"
  local runtime_src="${COMPAT_DIR}/drupwn-src"
  local wordlist="${runtime_src}/plugins/wordlists/plugins.txt"
  local backup=""
  local entry_count=0
  local previous_entry_count=0
  local required_entry_count="${DRUPWN_MIN_WORDLIST_ENTRIES}"
  local retained_entry_floor=0
  local update_ok=0

  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    mark_update_skipped "$name" "disabled by --no-update"
    return 0
  fi
  if [[ ! -f "${runtime_src}/drupwn" || ! -f "${wordlist}" ]]; then
    mark_update_failed "$name" "staged Drupwn runtime is unavailable"
    return 1
  fi

  backup="$(capture_user_cmd mktemp || true)"
  [[ -z "${backup}" ]] || vantage_register_temp_path "${backup}" || return 1
  if [[ -z "${backup}" || ! -f "${backup}" ]] || ! run_user_cmd cp "${wordlist}" "${backup}"; then
    [[ -z "${backup}" || ! -f "${backup}" ]] || run_user_cmd rm -f "${backup}" || true
    mark_update_failed "$name" "unable to back up the current wordlist"
    return 1
  fi
  previous_entry_count="$(capture_user_cmd awk 'NF { count++ } END { print count + 0 }' \
    "${backup}" 2>/dev/null || true)"
  if [[ "${previous_entry_count}" =~ ^[0-9]+$ && \
        "${previous_entry_count}" -gt "${DRUPWN_MIN_WORDLIST_ENTRIES}" ]]; then
    retained_entry_floor=$((previous_entry_count * 80 / 100))
    if [[ "${retained_entry_floor}" -gt "${required_entry_count}" ]]; then
      required_entry_count="${retained_entry_floor}"
    fi
  fi

  # Upstream uses relative paths and truncates the list before downloading it.
  # The staged entrypoint exits after the update, and a failed/timed-out refresh
  # is rolled back below.
  # shellcheck disable=SC2016 # Positional parameters expand in the inner bash.
  if CMS_UPDATE_PROGRESS_LABEL="$name" run_timed_user_update "${SCANNER_DATA_UPDATE_TIMEOUT}" bash -c \
    'cd "$1" && exec "$2" "$1/drupwn" --update' \
    _ "${runtime_src}" "${VENV_DIR}/bin/python"; then
    entry_count="$(capture_user_cmd awk 'NF { count++ } END { print count + 0 }' "${wordlist}" 2>/dev/null || true)"
    if [[ "${entry_count}" =~ ^[0-9]+$ && "${entry_count}" -ge "${required_entry_count}" ]]; then
      update_ok=1
    else
      log "ERROR: Drupwn updater produced ${entry_count:-0} entries; at least ${required_entry_count} are required."
    fi
  fi

  if [[ "${update_ok}" -eq 1 ]]; then
    run_user_cmd rm -f "${backup}" || true
    mark_updated "${name} (${entry_count} entries)"
    return 0
  fi

  if run_user_cmd cp "${backup}" "${wordlist}" && capture_user_cmd cmp -s "${backup}" "${wordlist}"; then
    run_user_cmd rm -f "${backup}" || true
    mark_update_failed "$name" "drupwn --update failed validation; previous wordlist restored"
  else
    mark_update_failed "$name" "update and rollback failed; temporary backup will be removed at installer exit"
  fi
  return 1
}

update_fingerprinter_database() {
  local name="Fingerprinter fingerprint database"
  local runtime_src="${COMPAT_DIR}/fingerprinter-src"
  local backup=""
  local output_file=""
  local update_rc=0
  local update_ok=0

  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    mark_update_skipped "$name" "disabled by --no-update"
    return 0
  fi
  if [[ ! -x "${BIN_DIR}/fingerprinter" || ! -d "${runtime_src}/db" ]]; then
    mark_update_failed "$name" "staged Fingerprinter runtime is unavailable"
    return 1
  fi

  backup="$(capture_user_cmd mktemp -d || true)"
  output_file="$(capture_user_cmd mktemp || true)"
  [[ -z "${backup}" ]] || vantage_register_temp_path "${backup}" || return 1
  [[ -z "${output_file}" ]] || vantage_register_temp_path "${output_file}" || return 1
  if [[ -z "${backup}" || ! -d "${backup}" || -z "${output_file}" || ! -f "${output_file}" ]] || \
    ! run_user_cmd cp -a "${runtime_src}/db/." "${backup}/"; then
    [[ -z "${backup}" || ! -d "${backup}" ]] || run_user_cmd rm -rf "${backup}" || true
    [[ -z "${output_file}" || ! -f "${output_file}" ]] || run_user_cmd rm -f "${output_file}" || true
    mark_update_failed "$name" "unable to back up the current database"
    return 1
  fi

  # Upstream deliberately exits 1 after --update-all, but it also catches
  # per-application failures and exits 1. Accept the status only when output
  # contains no updater errors and every resulting JSON database is valid.
  if CMS_UPDATE_PROGRESS_LABEL="$name" run_timed_user_update_capture "${output_file}" "${SCANNER_DATA_UPDATE_TIMEOUT}" \
    env VANTAGE_DISPATCHED=1 "${BIN_DIR}/fingerprinter" --update-all; then
    update_rc=0
  else
    update_rc=$?
  fi
  if [[ "${update_rc}" -eq 0 || "${update_rc}" -eq 1 ]] && \
    ! grep -Eiq 'An error occur(red|ed):|(^|[[:space:]])Error:' "${output_file}"; then
    if run_user_cmd "${VENV_DIR}/bin/python" - "${runtime_src}/db" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
files = list(root.glob("*.json"))
if not files:
    raise SystemExit("Fingerprinter produced no JSON databases")
for path in files:
    if path.stat().st_size <= 2:
        raise SystemExit(f"Fingerprinter produced an empty database: {path}")
    with path.open("r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise SystemExit(f"Fingerprinter database is not an object: {path}")
PY
    then
      update_ok=1
    fi
  fi
  run_user_cmd rm -f "${output_file}" || true

  if [[ "${update_ok}" -eq 1 ]]; then
    run_user_cmd rm -rf "${backup}" || true
    mark_updated "$name"
    return 0
  fi

  if restore_directory_from_backup "${backup}" "${runtime_src}/db" && \
    capture_user_cmd diff -qr "${backup}" "${runtime_src}/db" >/dev/null 2>&1; then
    run_user_cmd rm -rf "${backup}" || true
    mark_update_failed "$name" "fingerprinter update failed validation; previous database restored"
  else
    mark_update_failed "$name" "update and rollback failed; temporary backup will be removed at installer exit"
  fi
  return 1
}

phase_update_scanner_data() {
  local failures_before=${#UPDATE_FAILED[@]}
  local first_status=0 updater_status=0 event_status=0 failures_for_hook index
  local CMS_UPDATE_OPERATION_ID=""
  local -a hooks=(update_wpscan_database update_cmsmap_database
    update_droopescan_database update_drupwn_database update_fingerprinter_database)
  local -a names=("WPScan database" "CMSmap helper data" "Droopescan signatures"
    "Drupwn Drupal wordlist" "Fingerprinter fingerprint database")
  local -a retained_reasons=("" ""
    "validated package data retained; use --full-data-refresh for the native refresh"
    "validated managed-source data retained; use --full-data-refresh for the bulk refresh"
    "validated managed-source data retained; use --full-data-refresh for the bulk rebuild")

  for index in "${!hooks[@]}"; do
    CMS_UPDATE_OPERATION_ID="${hooks[$index]#update_}"
    CMS_UPDATE_OPERATION_ID="cms.update.${CMS_UPDATE_OPERATION_ID%_database}"
    if (( index >= 2 && UPDATE_EXISTING != 0 && RUN_FULL_DATA_REFRESH != 1 )); then
      event_status=0
      mark_update_skipped "${names[$index]}" "${retained_reasons[$index]}" || event_status=$?
      if (( event_status != 0 )); then
        (( first_status != 0 )) || first_status=$event_status
        return "$first_status"
      fi
      continue
    fi

    failures_for_hook=${#UPDATE_FAILED[@]}
    updater_status=0
    "${hooks[$index]}" || updater_status=$?
    if (( updater_status != 0 )); then
      (( first_status != 0 )) || first_status=$updater_status
      # Infrastructure failures can return before an updater records its own
      # outcome. They are still required failures when this hook is selected.
      if [[ "${#UPDATE_FAILED[@]}" -eq "$failures_for_hook" ]]; then
        mark_update_failed "${names[$index]}" \
          "required updater exited $updater_status before recording failure" || true
      fi
    elif [[ "${#UPDATE_FAILED[@]}" -gt "$failures_for_hook" ]]; then
      (( first_status != 0 )) || first_status=1
    fi
    # Cancellation owns the exit status and prevents later updater mutations.
    if (( updater_status >= 128 )); then return "$updater_status"; fi
    # An unavailable evidence channel must not permit more updater mutations.
    if [[ "${CMS_EVENT_FAILURE_STATUS:-0}" -ne 0 ]]; then
      (( first_status != 0 )) || first_status=$CMS_EVENT_FAILURE_STATUS
      return "$first_status"
    fi
  done

  (( first_status == 0 )) || return "$first_status"
  [[ "${#UPDATE_FAILED[@]}" -eq "${failures_before}" ]]
}

# Run a bounded, output-aware probe against the final published wrapper. Some
# upstream CLIs intentionally return 1 after printing help, so callers provide
# the accepted statuses as well as text that proves the expected program ran.
verify_final_tool_probe() {
  local label="$1"
  local accepted_statuses="$2"
  local expected_pattern="$3"
  shift 3
  local output_file=""
  local rc=0
  local preview=""
  local -a probe_cmd=("$@")

  [[ "${RUN_SMOKE_TESTS}" -eq 1 ]] || return 0
  vantage_make_temp output_file || {
    mark_failed "Final tool verification" "${label}: unable to create output capture"
    return 1
  }
  if has_cmd timeout; then
    probe_cmd=(timeout --signal=TERM --kill-after=5s "${SMOKE_TEST_TIMEOUT}" "${probe_cmd[@]}")
  fi
  preview="$(command_preview "${probe_cmd[@]}")"
  log "VERIFY(user:${INSTALL_USER}): ${label}: ${preview}"
  if run_and_capture_output "${output_file}" run_as_install_user \
    env VANTAGE_DISPATCHED=1 "${probe_cmd[@]}"; then
    rc=0
  else
    rc=$?
  fi

  if [[ ",${accepted_statuses}," == *",${rc},"* ]] && \
    grep -Eiq -- "${expected_pattern}" "${output_file}"; then
    rm -f "${output_file}"
    log "VERIFY OK: ${label}"
    return 0
  fi

  if [[ -s "${output_file}" ]]; then
    tail -n 20 "${output_file}" >&2 || true
  fi
  rm -f "${output_file}"
  mark_failed "Final tool verification" \
    "${label}: unexpected status/output (exit ${rc}; expected status ${accepted_statuses})"
  return 1
}

# Verify generated wrappers, the final shared dependency set, and every tool's
# non-network entrypoint after all package and signature updates have finished.
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

  if ! verify_shared_python_dependencies; then
    mark_failed "Shared Python dependencies" "pip check found incompatible package requirements in ${VENV_DIR}"
    missing=1
  fi

  if [[ "${RUN_SMOKE_TESTS}" -eq 1 ]]; then
    verify_final_tool_probe "WPScan" "0" '[0-9]+\.[0-9]+' \
      "${BIN_DIR}/wpscan" --version || missing=1
    verify_final_tool_probe "CMSmap" "0,1" '^[[:space:]]*usage:[[:space:]]+cmsmap|CMSmap tool v' \
      "${BIN_DIR}/cmsmap" -h || missing=1
    verify_final_tool_probe "CMSeek" "0" 'usage:|CMSeeK|CMSeek' \
      "${BIN_DIR}/cmseek" --help || missing=1
    verify_final_tool_probe "Droopescan" "0" 'usage:.*droopescan|droopescan' \
      "${BIN_DIR}/droopescan" --help || missing=1
    verify_final_tool_probe "JoomScan" "0,1" '^[[:space:]]*Usage:' \
      "${BIN_DIR}/joomscan" --help || missing=1
    verify_final_tool_probe "Drupwn" "0" 'usage:.*drupwn|drupwn' \
      "${BIN_DIR}/drupwn" --help || missing=1
    verify_final_tool_probe "VBScan" "0,1" '^[[:space:]]*Usage:' \
      "${BIN_DIR}/vbscan" --help || missing=1
    verify_final_tool_probe "CMSScan server/runtime" "0" 'CMSScan server runtime OK' \
      env CMSSCAN_RUNTIME="${COMPAT_DIR}/cmsscan-src" "${BIN_DIR}/cmsscan-python" -c \
      'import os,runpy,sys,threading; r=os.environ["CMSSCAN_RUNTIME"]; os.chdir(r); sys.path.insert(0,r); import db; from plugins import scanners; db.init_db=lambda app: None; scanners.update_wpscan=lambda: None; threading.Thread.start=lambda self: None; ns=runpy.run_path(os.path.join(r,"app.py"),run_name="cmsscan_server_probe"); assert callable(scanners.find_cms) and hasattr(ns["app"],"route"); print("CMSScan server runtime OK")' || missing=1
    verify_final_tool_probe "CMSScan production server" "0" 'gunicorn[[:space:]]+\(version|gunicorn[[:space:]]+[0-9]' \
      "${BIN_DIR}/cmsscan-server" --version || missing=1
    verify_final_tool_probe "VulnX" "0" 'usage:.*vulnx|VulnX' \
      "${BIN_DIR}/vulnx" --help || missing=1
    verify_final_tool_probe "Clusterd (auxiliary)" "0" 'usage:.*clusterd|clusterd' \
      "${BIN_DIR}/clusterd" --help || missing=1
    verify_final_tool_probe "WPSeku" "0" 'usage:|WPSeku|wpseku' \
      "${BIN_DIR}/wpseku" --help || missing=1
    verify_final_tool_probe "WPXF" "0" '(^|[^0-9])[0-9]+\.[0-9]+\.[0-9]+([^0-9]|$)' \
      "${BIN_DIR}/wpxf" --version || missing=1
    verify_final_tool_probe "WPForce" "0" 'usage:|WPForce|wpforce' \
      "${BIN_DIR}/wpforce" -h || missing=1
    verify_final_tool_probe "joomlavs" "0" 'usage:|joomlavs|Joomla' \
      "${BIN_DIR}/joomlavs" || missing=1
    verify_final_tool_probe "Fingerprinter" "0" 'usage:|fingerprinter|CMS' \
      "${BIN_DIR}/fingerprinter" --help || missing=1
    verify_final_tool_probe "AutoWPScan" "0" 'AutoWPScan runtime OK' \
      env AUTOWPSCAN_RUNTIME="${COMPAT_DIR}/autowpscan-src" "${BIN_DIR}/cmsscan-python" -c \
      'import importlib.util,os,pathlib; p=pathlib.Path(os.environ["AUTOWPSCAN_RUNTIME"])/"main.py"; s=importlib.util.spec_from_file_location("autowpscan_final_check",p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); assert callable(m.run_wpscan); print("AutoWPScan runtime OK")' || missing=1
    verify_final_tool_probe "AEM Detector" "0" 'usage:|aem.hacker|AEM' \
      "${BIN_DIR}/aem-hacker" --help || missing=1
    verify_final_tool_probe "AEM Discoverer" "0" 'usage:|aem.discoverer|AEM' \
      "${BIN_DIR}/aem-discoverer" --help || missing=1
    if [[ -x "${VENV_DIR}/bin/humanfriendly" ]]; then
      verify_final_tool_probe "Humanfriendly (dependency CLI)" "0" 'Usage:|humanfriendly' \
        "${VENV_DIR}/bin/humanfriendly" --help || missing=1
    fi
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
  if ! vantage_installer_ensure_runtime_account; then
    mark_failed "Install identity" \
      "the fixed aiuser account could not be created or validated"
    return 1
  fi
  if ! resolve_install_user; then
    mark_failed "Install identity" \
      "the frozen pre-sudo installer identity is missing or inconsistent"
    return 1
  fi
  COMPAT_DIR="${TOOLS_DIR}/.compat"

  ensure_sudo_access || return 1
  ensure_dirs || return 1

  if [[ ! "${GIT_UPDATE_TIMEOUT}" =~ ^[1-9][0-9]*$ || \
        ! "${SCANNER_DATA_UPDATE_TIMEOUT}" =~ ^[1-9][0-9]*$ || \
        ! "${SMOKE_TEST_TIMEOUT}" =~ ^[1-9][0-9]*$ || \
        ! "${DRUPWN_MIN_WORDLIST_ENTRIES}" =~ ^[1-9][0-9]*$ ]]; then
    mark_failed "Update settings" "timeouts and DRUPWN_MIN_WORDLIST_ENTRIES must be positive integers"
    return 1
  fi

  log "Installing user-level dependencies as: ${INSTALL_USER}"
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    log "Detected root execution; pip/gem/git steps will run as ${INSTALL_USER}."
  fi
  prepare_env
}

phase_python_environment() {
  ensure_canonical_venv || return 1
  prepare_env
}

phase_system_dependencies() {
  install_system_dependencies || return 1
  prepare_env
}

cms_repair_humanfriendly_cli() {
  run_user_cmd "${VENV_DIR}/bin/python" - <<'PY_HUMANFRIENDLY_CLI'
import importlib.metadata
import importlib.util
import os
from pathlib import Path
import stat
import sys
import tempfile

spec = importlib.util.find_spec("humanfriendly")
if spec is None:
    raise SystemExit(0)
if not spec.origin:
    raise SystemExit("Unsupported humanfriendly package location")
path = Path(spec.origin).parent / "cli.py"
if Path(sys.prefix).resolve() not in path.resolve().parents:
    raise SystemExit("Refusing to modify humanfriendly outside the CMS virtual environment")
metadata = path.lstat()
if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
    raise SystemExit(f"Unsupported humanfriendly CLI file: {path}")
original = path.read_bytes()
legacy = b"\nimport pipes\n"
modern = b"\nimport shlex as pipes\n"
if legacy not in original and modern not in original:
    raise SystemExit(0)
if importlib.metadata.version("humanfriendly") != "10.0":
    raise SystemExit("Unsupported humanfriendly pipes compatibility version")
if original.count(legacy) + original.count(modern) != 1 or original.count(b"pipes.quote") != 1:
    raise SystemExit("Unsupported humanfriendly pipes compatibility source")
repaired = original.replace(legacy, modern)
compile(repaired, str(path), "exec")
if repaired != original:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".humanfriendly-cli-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(repaired)
            os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        print(f"Repaired humanfriendly10.0 Python3.13 CLI compatibility: {path}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
PY_HUMANFRIENDLY_CLI
}

phase_install_tools() {
  local failed_before=${#FAILED[@]}
  local update_failed_before=${#UPDATE_FAILED[@]}

  if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    mark_failed "Python environment" "CMS-scoped interpreter is unavailable: ${VENV_DIR}/bin/python"
    return 1
  fi

  local tool_hook="" tool_status=0
  for tool_hook in "${CMS_INSTALL_TOOL_HOOKS[@]}"; do
    cms_tool_run "$tool_hook" || tool_status=$?
    [[ "${CMS_EVENT_FAILURE_STATUS:-0}" -eq 0 ]] || return "$CMS_EVENT_FAILURE_STATUS"
  done
  [[ "$tool_status" -eq 0 ]] || return "$tool_status"
  if ! cms_repair_humanfriendly_cli; then
    mark_failed "Humanfriendly CLI" "unable to repair the known Python3.13 pipes import"
  fi

  if [[ ${#FAILED[@]} -gt "${failed_before}" || \
        ${#UPDATE_FAILED[@]} -gt "${update_failed_before}" ]]; then
    return 1
  fi
  return 0
}

phase_package_cmsscan() {
  local tools_real=""
  local bin_real=""
  local default_tools_real=""
  local default_bin_real=""

  tools_real="$(readlink -m "${TOOLS_DIR}" 2>/dev/null || printf '%s' "${TOOLS_DIR}")"
  bin_real="$(readlink -m "${BIN_DIR}" 2>/dev/null || printf '%s' "${BIN_DIR}")"
  default_tools_real="$(readlink -m "${SCRIPT_DIR}/tools" 2>/dev/null || printf '%s' "${SCRIPT_DIR}/tools")"
  default_bin_real="$(readlink -m "${SCRIPT_DIR}/bin" 2>/dev/null || printf '%s' "${SCRIPT_DIR}/bin")"
  if [[ "${tools_real}" != "${default_tools_real}" || "${bin_real}" != "${default_bin_real}" ]]; then
    SKIPPED+=("CMS encrypted bundle: custom nonportable paths")
    log "NOT APPLICABLE: CMS encrypted bundle - custom --tools-dir/--bin-dir paths are not portable"
    cms_installer_event decision cms.bundle not_applicable custom_paths "Custom tool paths are not packaged" || return $?
    return 0
  fi
  if ! cms_repair_runner_logger "${SCRIPT_DIR}/run_cms_scanner.sh"; then
    mark_failed "CMS runtime logger" "unable to stage a joined runtime logger"
    return 1
  fi
  bundle_cmsscan_archive || return 1
  local VI_PHASE=publish
  cms_installer_event START cms.launcher running publication_started "Publish the verified CMS launcher" || return $?
  compile_cmsscan_wrapper || return $?
  cms_installer_event END cms.launcher succeeded publication_verified "Published CMS launcher" || return $?
}

# Print deterministic end-of-run summary for CI/log parsing.
print_summary() {
  log "==================== INSTALL SUMMARY ===================="
  log "Install user: ${INSTALL_USER} (${INSTALL_HOME})"
  log "CMS-scoped Python venv: ${VENV_DIR}"
  log "Encrypted archive: ${INFRA_ARCHIVE_PATH}"
  log "Archive manifest: ${INFRA_ARCHIVE_MANIFEST_PATH}"
  log "System wrapper: ${INFRA_CMSSCAN_BIN}"
  if [[ -n "${INFRA_CMSSCAN_ALIAS}" ]]; then
    log "System wrapper alias: ${INFRA_CMSSCAN_ALIAS}"
  fi
  local tool_id installed_tools=0 reused_tools=0 failed_tools=0
  for tool_id in "${CMS_INSTALL_TOOL_IDS[@]}"; do
    case "${CMS_TOOL_OUTCOMES[$tool_id]:-not_attempted}" in
      failed) failed_tools=$((failed_tools + 1)) ;;
      succeeded)
        if [[ "${CMS_TOOL_ACTIONS[$tool_id]}" == reuse ]]; then
          reused_tools=$((reused_tools + 1))
        else installed_tools=$((installed_tools + 1)); fi ;;
    esac
  done
  log "Tools: installed=${installed_tools}, reused=${reused_tools}, failed=${failed_tools}"
  for tool_id in "${CMS_INSTALL_TOOL_IDS[@]}"; do
    log "  - ${tool_id}: ${CMS_TOOL_ACTIONS[$tool_id]:---} ${CMS_TOOL_OUTCOMES[$tool_id]:-not_attempted}"
  done
  log "Publication completed: ${CMS_PUBLICATION_COMPLETE}"
  log "Recorded installation failures: ${#FAILED[@]}"
  for item in "${FAILED[@]}"; do log "  - ${item}"; done

  log "Warnings: ${#WARNINGS[@]}"
  for item in "${WARNINGS[@]}"; do
    log "  - ${item}"
  done

  log "Successful/current updates: ${#UPDATED[@]}"
  for item in "${UPDATED[@]}"; do
    log "  - ${item}"
  done

  log "Skipped updates: ${#UPDATE_SKIPPED[@]}"
  for item in "${UPDATE_SKIPPED[@]}"; do
    log "  - ${item}"
  done

  log "Failed updates: ${#UPDATE_FAILED[@]}"
  for item in "${UPDATE_FAILED[@]}"; do
    log "  - ${item}"
  done

  log "Phase results: ${#PHASE_RESULTS[@]}"
  for item in "${PHASE_RESULTS[@]}"; do
    log "  - ${item}"
  done

  if [[ "${CMS_PUBLICATION_COMPLETE}" -eq 1 ]]; then
    log "Installed command: /usr/bin/cmsscan (alias /usr/bin/cmscan)"
  else
    log "Public command publication was not completed by this run."
  fi
}

# -----------------------------------------------------------------------------
# Main entrypoint
# -----------------------------------------------------------------------------

main() {
  local python_environment_ok=0
  local system_dependencies_ok=0
  local verification_ok=0
  local tool_install_ok=0
  local required_phases_ok=1
  local database_update_status=0

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
      --force)
        # Retained as explicit CLI state for the version guard.
        # shellcheck disable=SC2034
        FORCE_INSTALL=1
        UPDATE_EXISTING=1
        ;;
      --full-data-refresh)
        RUN_FULL_DATA_REFRESH=1
        ;;
      --strict)
        STRICT_MODE=1
        ;;
      --tools-dir)
        require_option_arg "$1" "${2:-}"
        TOOLS_DIR="$2"
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

  # Parse all informational/invalid invocations before arming an EXIT handler
  # that can clean or restore ownership in the checkout.
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap installer_exit_cleanup EXIT
  fi
  VANTAGE_SHARED_CLEANUP_ARMED=1

  if ! run_phase "Preflight" phase_preflight; then
    print_summary
    exit 1
  fi

  if run_phase "System Dependencies" phase_system_dependencies; then
    system_dependencies_ok=1
  else
    required_phases_ok=0
  fi
  if [[ "${system_dependencies_ok}" -eq 1 ]]; then
    if run_phase "Canonical Python Environment" phase_python_environment; then
      python_environment_ok=1
    else
      required_phases_ok=0
    fi
  else
    PHASE_RESULTS+=("Canonical Python Environment: skipped (system dependency failure)")
    log "SKIP PHASE: Canonical Python Environment - system dependency failure"
  fi
  if [[ "${python_environment_ok}" -eq 1 ]]; then
    if run_phase "Tool Installation" phase_install_tools; then
      tool_install_ok=1
    else
      required_phases_ok=0
    fi
  elif [[ "${system_dependencies_ok}" -ne 1 ]]; then
    PHASE_RESULTS+=("Tool Installation: skipped (system dependency failure)")
    log "SKIP PHASE: Tool Installation - system dependency failure"
  else
    PHASE_RESULTS+=("Tool Installation: skipped (canonical Python environment failure)")
    log "SKIP PHASE: Tool Installation - canonical Python environment failure"
  fi
  if [[ "${tool_install_ok}" -eq 1 ]]; then
    run_phase "Scanner Database Updates" phase_update_scanner_data || database_update_status=$?
    if (( database_update_status >= 128 )); then return "$database_update_status"; fi
    if (( database_update_status != 0 )); then required_phases_ok=0; fi
    if run_phase "Post-Install Verification" verify_install_artifacts; then
      verification_ok=1
    else
      required_phases_ok=0
    fi
  else
    PHASE_RESULTS+=("Scanner Database Updates: skipped (prior tool installation failure)")
    log "SKIP PHASE: Scanner Database Updates - prior tool installation failure"
    PHASE_RESULTS+=("Post-Install Verification: skipped (prior tool installation failure)")
    log "SKIP PHASE: Post-Install Verification - prior tool installation failure"
  fi
  if [[ "${required_phases_ok}" -eq 1 && "${verification_ok}" -eq 1 && \
        ${#FAILED[@]} -eq 0 && ${#UPDATE_FAILED[@]} -eq 0 ]]; then
    run_phase "Encrypted Bundle and cmsscan Wrapper" phase_package_cmsscan || required_phases_ok=0
  else
    PHASE_RESULTS+=("Encrypted Bundle and cmsscan Wrapper: skipped (prior install/update/verification failure)")
    log "SKIP PHASE: Encrypted Bundle and cmsscan Wrapper - prior install/update/verification failure"
  fi

  cleanup_legacy_project_venvs "${SCRIPT_DIR}" || \
    warn "Obsolete project-local CMS virtual environments were retained"
  cleanup_git_index_conflict_sidecars "${SCRIPT_DIR}" || \
    warn "Dropbox-conflicted Git index sidecars were retained"

  print_summary

  # Phase helpers can propagate external command failures before adding a
  # tool/update failure. Their exit statuses must still prevent a success claim.
  if [[ "${required_phases_ok}" -ne 1 || ${#FAILED[@]} -gt 0 || ${#UPDATE_FAILED[@]} -gt 0 ]]; then
    exit 1
  fi
  if [[ "${STRICT_MODE}" -eq 1 && ( ${#WARNINGS[@]} -gt 0 || ${#SKIPPED[@]} -gt 0 ) ]]; then
    exit 1
  fi
  printf '%s\n' \
    '================================================================' \
    '[+] CMS Scanner installation completed successfully.' \
    '================================================================'
}

installer_exit_cleanup() {
  local exit_status=$?
  local cleanup_status=0
  local ownership_status=0
  local finalizer_status=0

  trap - EXIT
  set +e
  cms_update_progress_stop
  if [[ "${VANTAGE_SHARED_CLEANUP_ARMED:-0}" == 1 ]]; then
    run_post_install_cleanup "${SCRIPT_DIR}" || cleanup_status=$?
  fi
  vantage_cleanup_registered_temps
  vantage_restore_installer_ownership || ownership_status=$?
  if [[ "$cleanup_status" -ne 0 && "$ownership_status" -eq 0 ]]; then
    cleanup_status=0
    run_post_install_cleanup "${SCRIPT_DIR}" || cleanup_status=$?
  fi
  if [[ "$cleanup_status" -ne 0 ]]; then
    printf 'WARN: Reproducible CMS scanner checkout cleanup did not complete\n' >&2
    finalizer_status="$cleanup_status"
  fi
  if [[ "$ownership_status" -ne 0 ]]; then
    printf 'WARN: CMS scanner checkout ownership restoration did not complete\n' >&2
    finalizer_status="$ownership_status"
  fi
  exit_status="$(vantage_merge_exit_status "$exit_status" "$finalizer_status")"
  exit "$exit_status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
