#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
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

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${TEST_DIR}/../installer.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cms-version-skip.XXXXXX")"
trap 'rm -rf -- "${TEST_ROOT}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# shellcheck source=../installer.sh
source "${INSTALLER}"

TOOLS_DIR="${TEST_ROOT}/tools"
COMPAT_DIR="${TOOLS_DIR}/.compat"
BIN_DIR="${TEST_ROOT}/bin"
VENV_DIR="${TEST_ROOT}/venv"
mkdir -p "${TOOLS_DIR}/CMSmap/.git" "${COMPAT_DIR}/upstream" "${BIN_DIR}" "${VENV_DIR}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"${BIN_DIR}/cmsmap"
chmod 0755 "${BIN_DIR}/cmsmap"

log() { :; }
vantage_git_checkout_current() { return 0; }
RUNTIME_HEALTHY=1
cmsmap_runtime_is_usable() { [[ "${RUNTIME_HEALTHY}" -eq 1 ]]; }
install_cmsmap() {
  printf 'called\n' >>"${TEST_ROOT}/calls"
  mark_installed CMSmap
}

INSTALLED=()
SKIPPED=()
FAILED=()
UPDATED=()
UPDATE_SKIPPED=()
UPDATE_FAILED=()
FORCE_INSTALL=0
UPDATE_EXISTING=1
run_tool_installer install_cmsmap || fail "current CMSmap guard returned failure"
[[ ! -e "${TEST_ROOT}/calls" ]] ||
  fail "current Git tool still invoked its installer"
[[ "${#SKIPPED[@]}" -eq 1 ]] ||
  fail "current Git tool did not record exactly one skip"

INSTALLED=()
SKIPPED=()
FAILED=()
UPDATED=()
UPDATE_SKIPPED=()
UPDATE_FAILED=()
RUNTIME_HEALTHY=0
FORCE_INSTALL=0
run_tool_installer install_cmsmap || fail "unhealthy current CMSmap repair returned failure"
[[ "$(<"${TEST_ROOT}/calls")" == called ]] ||
  fail "unhealthy runtime did not bypass the current-source skip"
[[ "${#INSTALLED[@]}" -eq 1 && "${#SKIPPED[@]}" -eq 0 ]] ||
  fail "unhealthy current runtime recorded the wrong repair outcome"

INSTALLED=()
SKIPPED=()
FAILED=()
UPDATED=()
UPDATE_SKIPPED=()
UPDATE_FAILED=()
rm -f "${TEST_ROOT}/calls"
RUNTIME_HEALTHY=1
FORCE_INSTALL=1
run_tool_installer install_cmsmap || fail "forced CMSmap reinstall returned failure"
[[ "$(<"${TEST_ROOT}/calls")" == called ]] ||
  fail "--force did not invoke the Git tool installer"
[[ "${#INSTALLED[@]}" -eq 1 && "${#SKIPPED[@]}" -eq 0 ]] ||
  fail "forced Git tool reinstall recorded the wrong outcome"

test_runtime_health_gate_matrix() (
  local trace="${TEST_ROOT}/health-gate-trace"
  local runtime_healthy=0
  local installer_function=""
  local expected_health=""
  local actual_trace=""

  cmsmap_runtime_is_usable() {
    printf 'cmsmap-health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  drupwn_runtime_is_usable() {
    printf 'drupwn-health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  cmsscan_runtime_is_usable() {
    printf 'cmsscan-health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  clusterd_runtime_is_usable() {
    printf 'clusterd-health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  wpforce_runtime_is_usable() {
    printf 'wpforce-health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  wpseku_runtime_is_usable() {
    printf 'wpseku-health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  cms_wrapper_has_scoped_syntaxwarning_filter() { return 0; }
  cms_git_tool_is_current() {
    printf 'source\n' >>"${trace}"
    mark_skipped "$1" "mock source is current"
    mark_update_skipped "$4 source" "mock source is current"
  }
  install_cmsmap() { printf 'install\n' >>"${trace}"; mark_installed CMSmap; }
  install_drupwn() { printf 'install\n' >>"${trace}"; mark_installed Drupwn; }
  install_cmsscan() { printf 'install\n' >>"${trace}"; mark_installed CMSScan; }
  install_clusterd() { printf 'install\n' >>"${trace}"; mark_installed Clusterd; }
  install_wpforce() { printf 'install\n' >>"${trace}"; mark_installed WPForce; }
  install_wpseku() { printf 'install\n' >>"${trace}"; mark_installed WPSeku; }

  for installer_function in \
    install_cmsmap install_drupwn install_cmsscan install_clusterd \
    install_wpforce install_wpseku; do
    case "${installer_function}" in
      install_cmsmap) expected_health="cmsmap-health" ;;
      install_drupwn) expected_health="drupwn-health" ;;
      install_cmsscan) expected_health="cmsscan-health" ;;
      install_clusterd) expected_health="clusterd-health" ;;
      install_wpforce) expected_health="wpforce-health" ;;
      install_wpseku) expected_health="wpseku-health" ;;
    esac

    INSTALLED=()
    SKIPPED=()
    FAILED=()
    UPDATED=()
    UPDATE_SKIPPED=()
    UPDATE_FAILED=()
    FORCE_INSTALL=0
    UPDATE_EXISTING=1
    runtime_healthy=0
    : >"${trace}"
    run_tool_installer "${installer_function}" ||
      fail "${installer_function}: unhealthy-current repair returned failure"
    actual_trace="$(paste -sd, "${trace}")"
    [[ "${actual_trace}" == "${expected_health},install" ]] ||
      fail "${installer_function}: unhealthy-current order was ${actual_trace}"
    [[ "${#INSTALLED[@]}" -eq 1 && "${#SKIPPED[@]}" -eq 0 ]] ||
      fail "${installer_function}: unhealthy runtime did not install"

    INSTALLED=()
    SKIPPED=()
    FAILED=()
    UPDATED=()
    UPDATE_SKIPPED=()
    UPDATE_FAILED=()
    runtime_healthy=1
    : >"${trace}"
    run_tool_installer "${installer_function}" ||
      fail "${installer_function}: healthy-current skip returned failure"
    actual_trace="$(paste -sd, "${trace}")"
    [[ "${actual_trace}" == "${expected_health},source" ]] ||
      fail "${installer_function}: healthy-current order was ${actual_trace}"
    [[ "${#INSTALLED[@]}" -eq 0 && "${#SKIPPED[@]}" -eq 1 ]] ||
      fail "${installer_function}: healthy current runtime did not skip"
  done

  # --no-update may retain healthy source, but it must not retain a wrapper
  # whose runtime dependencies are missing. These installers supply `six`
  # during their normal repair paths.
  for installer_function in install_clusterd install_wpforce; do
    case "${installer_function}" in
      install_clusterd) expected_health="clusterd-health" ;;
      install_wpforce) expected_health="wpforce-health" ;;
    esac
    INSTALLED=()
    SKIPPED=()
    FAILED=()
    UPDATED=()
    UPDATE_SKIPPED=()
    UPDATE_FAILED=()
    FORCE_INSTALL=0
    UPDATE_EXISTING=0
    runtime_healthy=0
    : >"${trace}"
    run_tool_installer "${installer_function}" ||
      fail "${installer_function}: --no-update runtime repair returned failure"
    actual_trace="$(paste -sd, "${trace}")"
    [[ "${actual_trace}" == "${expected_health},install" ]] ||
      fail "${installer_function}: --no-update retained unhealthy runtime (${actual_trace})"
    [[ "${#INSTALLED[@]}" -eq 1 && "${#SKIPPED[@]}" -eq 0 ]] ||
      fail "${installer_function}: --no-update did not repair unhealthy runtime"
  done
)

test_runtime_health_gate_matrix || fail "runtime health-gate matrix failed"

test_six_dependent_runtime_probes() (
  local dependency_marker="${TEST_ROOT}/six-installed"

  # This unit isolates the bounded probe result; runtime-identity transition is
  # covered by the installer helper tests.
  run_as_install_user() { "$@"; }

  # cms_runtime_probe_is_usable executes as the resolved install user. The
  # fixture root contains no secrets, so make its path traversable just like a
  # staged installer tree.
  chmod 0755 "${TEST_ROOT}" "${BIN_DIR}"

  cat >"${BIN_DIR}/clusterd" <<EOF
#!/usr/bin/env bash
[[ -f "${dependency_marker}" ]] || {
  printf '%s\n' "ModuleNotFoundError: No module named 'six'" >&2
  exit 1
}
printf '%s\n' 'usage: clusterd --help'
EOF
  cat >"${BIN_DIR}/wpforce" <<EOF
#!/usr/bin/env bash
[[ -f "${dependency_marker}" ]] || {
  printf '%s\n' "ModuleNotFoundError: No module named 'six'" >&2
  exit 1
}
printf '%s\n' 'WPForce usage:'
EOF
  chmod 0755 "${BIN_DIR}/clusterd" "${BIN_DIR}/wpforce"
  mkdir -p "${COMPAT_DIR}/clusterd-src/src/core"
  printf '%s\n' '# VANTAGE_CLUSTERD_STDLIB_PLATFORM_V1' > \
    "${COMPAT_DIR}/clusterd-src/src/core/sitecustomize.py"

  rm -f "${dependency_marker}"
  ! clusterd_runtime_is_usable ||
    fail "Clusterd health probe accepted a runtime missing six"
  ! wpforce_runtime_is_usable ||
    fail "WPForce health probe accepted a runtime missing six"

  : >"${dependency_marker}"
  clusterd_runtime_is_usable ||
    fail "Clusterd health probe rejected a healthy runtime"
  wpforce_runtime_is_usable ||
    fail "WPForce health probe rejected a healthy runtime"
)

test_six_dependent_runtime_probes || fail "six-dependent runtime probes failed"

grep -Fq 'for requirement in requests beautifulsoup4 click six; do' "${INSTALLER}" ||
  fail "canonical CMS venv baseline does not include six"

printf 'CMS installer skip/force tests passed.\n'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
