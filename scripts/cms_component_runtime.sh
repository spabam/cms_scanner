#!/usr/bin/env sh
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Component-scoped Python runtime binding for maintained CMS scanner entrypoints.

cms_component_runtime_bind() {
  case "${VANTAGE_RUNTIME_UID:-}" in
    ''|0|*[!0-9]*) return 77 ;;
  esac
  [ "${VANTAGE_RUNTIME_USER:-}" = aiuser ] || return 77
  case "${VANTAGE_RUNTIME_HOME:-}" in
    /) return 77 ;;
    /*) ;;
    *) return 77 ;;
  esac
  case "${VANTAGE_RUNTIME_PRIVATE_DIR:-}" in
    /) return 77 ;;
    /*) ;;
    *) return 77 ;;
  esac

  CMS_RUNTIME_USER="${VANTAGE_RUNTIME_USER}"
  CMS_RUNTIME_UID="${VANTAGE_RUNTIME_UID}"
  CMS_RUNTIME_HOME="${VANTAGE_RUNTIME_HOME}"
  CMS_RUNTIME_ROOT="${CMS_RUNTIME_HOME}/.local/share/vantage/cms_scanner"
  CMS_RUNTIME_VENV="${CMS_RUNTIME_ROOT}/venv"
  CMS_RUNTIME_PYTHON="${CMS_RUNTIME_VENV}/bin/python"
  CMS_RUNTIME_PATH="${CMS_RUNTIME_VENV}/bin:${VANTAGE_RUNTIME_PRIVATE_DIR}:${CMS_RUNTIME_HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  export CMS_RUNTIME_USER CMS_RUNTIME_UID CMS_RUNTIME_HOME CMS_RUNTIME_ROOT
  export CMS_RUNTIME_VENV CMS_RUNTIME_PYTHON CMS_RUNTIME_PATH
}

cms_component_runtime_identity_matches() {
  command -v vantage_runtime_resolve_identity >/dev/null 2>&1 || return 69
  vantage_runtime_resolve_identity || return
  [ "${VANTAGE_RUNTIME_USER:-}" = "${CMS_RUNTIME_USER:-}" ] &&
    [ "${VANTAGE_RUNTIME_UID:-}" = "${CMS_RUNTIME_UID:-}" ] &&
    [ "${VANTAGE_RUNTIME_HOME:-}" = "${CMS_RUNTIME_HOME:-}" ] &&
    [ "${CMS_RUNTIME_ROOT:-}" = "${VANTAGE_RUNTIME_HOME}/.local/share/vantage/cms_scanner" ] &&
    [ "${CMS_RUNTIME_VENV:-}" = "${CMS_RUNTIME_ROOT}/venv" ] &&
    [ "${CMS_RUNTIME_PYTHON:-}" = "${CMS_RUNTIME_VENV}/bin/python" ]
}

cms_component_runtime_run_as_user() {
  [ "$#" -gt 0 ] || return 64
  command -v vantage_runtime_run_as_user >/dev/null 2>&1 || return 69
  cms_component_runtime_identity_matches || return 77
  vantage_runtime_run_as_user /usr/bin/env \
    "HOME=${CMS_RUNTIME_HOME}" \
    "USER=${CMS_RUNTIME_USER}" \
    "LOGNAME=${CMS_RUNTIME_USER}" \
    "VIRTUAL_ENV=${CMS_RUNTIME_VENV}" \
    "PATH=${CMS_RUNTIME_PATH}" \
    PYTHONNOUSERSITE=1 \
    PIP_REQUIRE_VIRTUALENV=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    "$@"
}

# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
