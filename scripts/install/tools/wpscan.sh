#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_wpscan() {
  local name="WPScan"
  local wpscan_path=""
  local wrapper_target="${BIN_DIR}/wpscan"
  local wrapper_tmp=""

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby/gem runtime unavailable"
    return 0
  fi

  if [[ "${UPDATE_EXISTING}" -eq 1 ]]; then
    if ! install_or_update_user_gem "$name" wpscan; then
      mark_failed "$name" "unable to install/update the wpscan gem"
      return 0
    fi
    prepare_env
    wpscan_path="$(resolve_real_wpscan_path || true)"
  else
    wpscan_path="$(resolve_real_wpscan_path || true)"
    if [[ -n "${wpscan_path}" ]]; then
      mark_update_skipped "${name} software" "disabled by --no-update"
    else
      if apt_install_packages "$name" wpscan; then
        mark_updated "${name} package (fresh install)"
      else
        warn "apt install wpscan failed; trying gem install"
      fi
      refresh_user_gem_bin
      wpscan_path="$(resolve_real_wpscan_path || true)"
    fi

    if [[ -z "${wpscan_path}" ]]; then
      if ! install_or_update_user_gem "$name" wpscan; then
        mark_failed "$name" "gem install failed"
        return 0
      fi
      prepare_env
      wpscan_path="$(resolve_real_wpscan_path || true)"
    fi
  fi

  if [[ -z "${wpscan_path}" ]]; then
    mark_failed "$name" "command not found after installation attempts"
    return 0
  fi
  wrapper_tmp="$(mktemp "${wrapper_target}.new.XXXXXX")" || {
    mark_failed "$name" "unable to create executable wrapper candidate"
    return 0
  }
  vantage_register_temp_path "${wrapper_tmp}" || {
    rm -f "${wrapper_tmp}"
    mark_failed "$name" "unable to register executable wrapper candidate"
    return 0
  }
  case "${wrapper_tmp}" in
    "${wrapper_target}.new."*) ;;
    *)
      mark_failed "$name" "unsafe executable wrapper candidate path"
      return 0
      ;;
  esac
  if ! cat >"${wrapper_tmp}" <<EOF
#!/usr/bin/env bash
# Copyright © 2026 Andrea Bodei — www.andreabodei.com
set -euo pipefail

RUNTIME_PASSWD="\$(/usr/bin/getent passwd aiuser 2>/dev/null || true)"
RUNTIME_UID="\$(printf '%s\\n' "\${RUNTIME_PASSWD}" | /usr/bin/cut -d: -f3)"
CANONICAL_HOME="\$(printf '%s\\n' "\${RUNTIME_PASSWD}" | /usr/bin/cut -d: -f6)"
if [[ ! "\${RUNTIME_UID}" =~ ^[1-9][0-9]*$ ||
      "\$(/usr/bin/id -u)" != "\${RUNTIME_UID}" ||
      "\${VANTAGE_DISPATCHED:-0}" != 1 ||
      "\${CANONICAL_HOME}" != /* || "\${CANONICAL_HOME}" == / ||
      "\${HOME:-}" != "\${CANONICAL_HOME}" ]]; then
  echo "WPScan must run as aiuser inside a dispatched CMS scan" >&2
  exit 77
fi

SCRIPT_PATH="\$(readlink -f "\${BASH_SOURCE[0]}" 2>/dev/null || echo "\${BASH_SOURCE[0]}")"
WPSCAN_HOME="\${CANONICAL_HOME}/.wpscan"
DEFAULT_CACHE_DIR="\${WPSCAN_HOME}/cache"
DEFAULT_COOKIE_JAR="\${WPSCAN_HOME}/cookie_jar.txt"

prepare_wpscan_state() {
  local state_root="\$1"
  DEFAULT_CACHE_DIR="\${state_root}/cache"
  DEFAULT_COOKIE_JAR="\${state_root}/cookie_jar.txt"
  mkdir -p "\${DEFAULT_CACHE_DIR}" >/dev/null 2>&1 &&
    touch "\${DEFAULT_COOKIE_JAR}" >/dev/null 2>&1 &&
    [[ -w "\${DEFAULT_CACHE_DIR}" && -w "\${DEFAULT_COOKIE_JAR}" ]]
}

HAS_CACHE_DIR=0
HAS_COOKIE_JAR=0
INFO_ONLY=0
for arg in "\$@"; do
  case "\${arg}" in
    --cache-dir) HAS_CACHE_DIR=1 ;;
    --cookie-jar) HAS_COOKIE_JAR=1 ;;
    -h|--help|help|--version|--update) INFO_ONLY=1 ;;
  esac
done

declare -a WPSCAN_EXTRA_ARGS=()
if [[ "\${INFO_ONLY}" -eq 0 ]] && \
  { [[ "\${HAS_CACHE_DIR}" -eq 0 && -z "\${WPSCAN_CACHE_DIR:-}" ]] || \
    [[ "\${HAS_COOKIE_JAR}" -eq 0 && -z "\${WPSCAN_COOKIE_JAR:-}" ]]; }; then
  if ! prepare_wpscan_state "\${WPSCAN_HOME}"; then
    WPSCAN_FALLBACK_HOME="${INSTALL_HOME}/.cache/cms-scanner/wpscan"
    if ! prepare_wpscan_state "\${WPSCAN_FALLBACK_HOME}"; then
      echo "unable to create writable WPScan cache/cookie state" >&2
      exit 73
    fi
  fi
fi
if [[ "\${INFO_ONLY}" -eq 0 && "\${HAS_CACHE_DIR}" -eq 0 ]]; then
  WPSCAN_EXTRA_ARGS+=(--cache-dir "\${WPSCAN_CACHE_DIR:-\${DEFAULT_CACHE_DIR}}")
fi
if [[ "\${INFO_ONLY}" -eq 0 && "\${HAS_COOKIE_JAR}" -eq 0 ]]; then
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
    if [[ "\${candidate}" == "${INSTALL_HOME}"/.local/share/gem/ruby/*/bin/wpscan ]]; then
      RUNTIME_GEM_HOME="\$(dirname "\$(dirname "\${candidate}")")"
      exec env HOME="${INSTALL_HOME}" GEM_HOME="\${RUNTIME_GEM_HOME}" GEM_PATH="\${RUNTIME_GEM_HOME}:\${GEM_PATH:-}" "\${candidate}" "\${WPSCAN_EXTRA_ARGS[@]}" "\$@"
    fi
    exec env HOME="${INSTALL_HOME}" "\${candidate}" "\${WPSCAN_EXTRA_ARGS[@]}" "\$@"
  fi
done

echo "wpscan executable not found in gem or system paths" >&2
exit 127
EOF
  then
    rm -f "${wrapper_tmp}"
    mark_failed "$name" "unable to write executable wrapper"
    return 0
  fi
  if ! chmod +x "${wrapper_tmp}"; then
    rm -f "${wrapper_tmp}"
    mark_failed "$name" "unable to make wrapper executable"
    return 0
  fi
  if [[ "${EUID}" -eq 0 && "${INSTALL_USER}" != "root" ]]; then
    if ! chown "${INSTALL_UID}:${INSTALL_GID}" "${wrapper_tmp}"; then
      rm -f "${wrapper_tmp}"
      mark_failed "$name" "unable to set wrapper ownership"
      return 0
    fi
  fi
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]] && \
    ! run_user_cmd env VANTAGE_DISPATCHED=1 "${wrapper_tmp}" --version; then
    rm -f "${wrapper_tmp}"
    mark_failed "$name" "smoke test failed (wpscan --version)"
    return 0
  fi
  if ! mv -fT "${wrapper_tmp}" "${wrapper_target}"; then
    rm -f "${wrapper_tmp}"
    mark_failed "$name" "unable to activate executable wrapper"
    return 0
  fi

  if ! prepare_wpscan_state; then
    warn "${name}: unable to prepare writable state under ${INSTALL_HOME}/.wpscan; runtime fallback state will be used"
  fi

  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
