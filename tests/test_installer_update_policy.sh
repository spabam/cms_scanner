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

# Copyright © 2026 Andrea Bodei — www.andreabodei.com
# The harness deliberately sources the installer dynamically and replaces
# functions that ShellCheck cannot see being called through the sourced code.
# shellcheck disable=SC1091,SC2034,SC2317
set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="${TEST_DIR}/../installer.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cms-scanner-update-policy.XXXXXX")"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  case "${TEST_ROOT}" in
    "${TMPDIR:-/tmp}"/cms-scanner-update-policy.*)
      rm -rf -- "${TEST_ROOT}"
      ;;
  esac
}
trap cleanup EXIT

fail_assertion() {
  printf '    %s\n' "$*" >&2
  return 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local context="$3"

  [[ "${actual}" == "${expected}" ]] || {
    printf '    %s\n      expected: %q\n      actual:   %q\n' \
      "${context}" "${expected}" "${actual}" >&2
    return 1
  }
}

run_test() {
  local name="$1"
  shift

  if "$@"; then
    printf 'ok - %s\n' "${name}"
    ((PASS_COUNT += 1))
  else
    printf 'not ok - %s\n' "${name}" >&2
    ((FAIL_COUNT += 1))
  fi
}

test_default_update_policy() (
  local trace="${TEST_ROOT}/default.trace"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }

  UPDATE_EXISTING=1
  RUN_FULL_DATA_REFRESH=0
  UPDATE_FAILED=()
  UPDATE_SKIPPED=()

  record_update() {
    printf '%s\n' "$1" >>"${trace}"
    return 0
  }
  update_wpscan_database() { record_update wpscan; }
  update_cmsmap_database() { record_update cmsmap; }
  update_droopescan_database() { record_update droopescan; }
  update_drupwn_database() { record_update drupwn; }
  update_fingerprinter_database() { record_update fingerprinter; }

  phase_update_scanner_data || return 1

  assert_equal $'wpscan\ncmsmap' "$(<"${trace}")" \
    "default policy should invoke only the bounded refreshes" || return 1
  assert_equal "3" "${#UPDATE_SKIPPED[@]}" \
    "default policy skipped-update count" || return 1
  assert_equal \
    "Droopescan signatures: validated package data retained; use --full-data-refresh for the native refresh" \
    "${UPDATE_SKIPPED[0]}" "Droopescan default skip" || return 1
  assert_equal \
    "Drupwn Drupal wordlist: validated managed-source data retained; use --full-data-refresh for the bulk refresh" \
    "${UPDATE_SKIPPED[1]}" "Drupwn default skip" || return 1
  assert_equal \
    "Fingerprinter fingerprint database: validated managed-source data retained; use --full-data-refresh for the bulk rebuild" \
    "${UPDATE_SKIPPED[2]}" "Fingerprinter default skip" || return 1
)

test_full_update_policy() (
  local trace="${TEST_ROOT}/full.trace"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }

  UPDATE_EXISTING=1
  RUN_FULL_DATA_REFRESH=1
  UPDATE_FAILED=()
  UPDATE_SKIPPED=()

  record_update() {
    printf '%s\n' "$1" >>"${trace}"
    return 0
  }
  update_wpscan_database() { record_update wpscan; }
  update_cmsmap_database() { record_update cmsmap; }
  update_droopescan_database() { record_update droopescan; }
  update_drupwn_database() { record_update drupwn; }
  update_fingerprinter_database() { record_update fingerprinter; }

  phase_update_scanner_data || return 1

  assert_equal $'wpscan\ncmsmap\ndroopescan\ndrupwn\nfingerprinter' \
    "$(<"${trace}")" "full policy invocation order" || return 1
  assert_equal "0" "${#UPDATE_SKIPPED[@]}" \
    "full policy should not add policy-level skips" || return 1
)

test_no_update_delegates_to_every_updater() (
  local trace="${TEST_ROOT}/no-update.trace"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }

  UPDATE_EXISTING=0
  RUN_FULL_DATA_REFRESH=0
  UPDATE_FAILED=()
  UPDATE_SKIPPED=()

  record_no_update() {
    local key="$1"
    local label="$2"

    [[ "${UPDATE_EXISTING}" -eq 0 ]] || return 1
    printf '%s\n' "${key}" >>"${trace}"
    mark_update_skipped "${label}" "disabled by --no-update"
  }
  update_wpscan_database() {
    record_no_update wpscan "WPScan database"
  }
  update_cmsmap_database() {
    record_no_update cmsmap "CMSmap helper data"
  }
  update_droopescan_database() {
    record_no_update droopescan "Droopescan signatures"
  }
  update_drupwn_database() {
    record_no_update drupwn "Drupwn Drupal wordlist"
  }
  update_fingerprinter_database() {
    record_no_update fingerprinter "Fingerprinter fingerprint database"
  }

  phase_update_scanner_data || return 1

  assert_equal $'wpscan\ncmsmap\ndroopescan\ndrupwn\nfingerprinter' \
    "$(<"${trace}")" "--no-update delegation order" || return 1
  assert_equal "5" "${#UPDATE_SKIPPED[@]}" \
    "each updater should record its own --no-update result" || return 1
  local item=""
  for item in "${UPDATE_SKIPPED[@]}"; do
    [[ "${item}" == *": disabled by --no-update" ]] || {
      fail_assertion "unexpected --no-update record: ${item}"
      return 1
    }
  done
)

test_wpscan_uses_exact_wrapper_path() (
  local case_root="${TEST_ROOT}/wpscan"
  local exact_bin="${case_root}/exact-bin"
  local login_bin="${case_root}/login-bin"
  local missing_bin="${case_root}/missing-bin"
  local has_user_cmd_marker="${case_root}/has-user-cmd.called"

  mkdir -p "${exact_bin}" "${login_bin}" "${missing_bin}"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${exact_bin}/wpscan"
  printf '#!/usr/bin/env bash\nexit 88\n' >"${login_bin}/wpscan"
  chmod +x "${exact_bin}/wpscan" "${login_bin}/wpscan"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }

  UPDATE_EXISTING=1
  BIN_DIR="${exact_bin}"
  PATH="${login_bin}"
  UPDATE_FAILED=()
  UPDATED=()
  declare -a captured_update=()

  # A regression to command discovery would call this and choose the PATH
  # decoy. The update policy must instead inspect BIN_DIR/wpscan directly.
  has_user_cmd() {
    printf 'called\n' >"${has_user_cmd_marker}"
    return 0
  }
  run_timed_user_update() {
    captured_update=("$@")
    return 0
  }

  update_wpscan_database || return 1

  assert_equal "5" "${#captured_update[@]}" \
    "WPScan timed-update argument count" || return 1
  assert_equal "${SCANNER_DATA_UPDATE_TIMEOUT}" "${captured_update[0]}" \
    "WPScan timeout argument" || return 1
  assert_equal "env" "${captured_update[1]}" \
    "WPScan dispatched environment command" || return 1
  assert_equal "VANTAGE_DISPATCHED=1" "${captured_update[2]}" \
    "WPScan dispatcher marker" || return 1
  assert_equal "${exact_bin}/wpscan" "${captured_update[3]}" \
    "WPScan exact wrapper path" || return 1
  assert_equal "--update" "${captured_update[4]}" \
    "WPScan update argument" || return 1
  [[ ! -e "${has_user_cmd_marker}" ]] || {
    fail_assertion "WPScan update unexpectedly used PATH command discovery"
    return 1
  }

  # A PATH-only decoy must not satisfy the wrapper precondition.
  BIN_DIR="${missing_bin}"
  UPDATE_FAILED=()
  captured_update=()
  if update_wpscan_database; then
    fail_assertion "WPScan update accepted a PATH-only executable"
    return 1
  fi
  assert_equal "0" "${#captured_update[@]}" \
    "missing exact wrapper must not invoke the updater" || return 1
  assert_equal "1" "${#UPDATE_FAILED[@]}" \
    "missing exact wrapper failure count" || return 1
  assert_equal "WPScan database: wpscan command is unavailable" \
    "${UPDATE_FAILED[0]}" "missing exact wrapper failure" || return 1
)

test_main_skips_later_phases_after_tool_failure() (
  local phase_trace="${TEST_ROOT}/main-phases.trace"
  local log_trace="${TEST_ROOT}/main-log.trace"
  local status=0

  # shellcheck source=../installer.sh
  source "${INSTALLER}"

  FAILED=()
  UPDATE_FAILED=()
  PHASE_RESULTS=()
  log() {
    printf '%s\n' "$*" >>"${log_trace}"
  }
  print_summary() { :; }
  run_phase() {
    local name="$1"

    printf '%s\n' "${name}" >>"${phase_trace}"
    if [[ "${name}" == "Tool Installation" ]]; then
      FAILED+=("mock tool: intentional failure")
      return 1
    fi
    return 0
  }

  if (main); then
    fail_assertion "main unexpectedly succeeded after a tool failure"
    return 1
  else
    status=$?
  fi

  assert_equal "1" "${status}" "main failure status" || return 1
  assert_equal \
    $'Preflight\nSystem Dependencies\nCanonical Python Environment\nTool Installation' \
    "$(<"${phase_trace}")" "phases run before the tool-failure cutoff" || return 1
  [[ "$(<"${log_trace}")" == *"SKIP PHASE: Scanner Database Updates - prior tool installation failure"* ]] || {
    fail_assertion "main did not report the scanner-data phase skip"
    return 1
  }
  [[ "$(<"${log_trace}")" == *"SKIP PHASE: Post-Install Verification - prior tool installation failure"* ]] || {
    fail_assertion "main did not report the verification phase skip"
    return 1
  }
)

test_main_stops_tool_phase_after_environment_failure() (
  local phase_trace="${TEST_ROOT}/environment-failure-phases.trace"
  local log_trace="${TEST_ROOT}/environment-failure-log.trace"
  local status=0

  # shellcheck source=../installer.sh
  source "${INSTALLER}"

  FAILED=()
  UPDATE_FAILED=()
  PHASE_RESULTS=()
  log() {
    printf '%s\n' "$*" >>"${log_trace}"
  }
  print_summary() { :; }
  run_phase() {
    local name="$1"

    printf '%s\n' "${name}" >>"${phase_trace}"
    if [[ "${name}" == "Canonical Python Environment" ]]; then
      FAILED+=("Python environment: intentional test failure")
      return 1
    fi
    return 0
  }

  if (main); then
    fail_assertion "main unexpectedly succeeded after an environment failure"
    return 1
  else
    status=$?
  fi

  assert_equal "1" "${status}" "environment failure status" || return 1
  assert_equal \
    $'Preflight\nSystem Dependencies\nCanonical Python Environment' \
    "$(<"${phase_trace}")" "phases run before the environment-failure cutoff" || \
    return 1
  [[ "$(<"${log_trace}")" == *"SKIP PHASE: Tool Installation - canonical Python environment failure"* ]] || {
    fail_assertion "main did not report the tool-installation phase skip"
    return 1
  }
)

test_system_dependency_phase_propagates_failure() (
  local prepare_marker="${TEST_ROOT}/system-deps-prepare.called"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }
  install_system_dependencies() { return 29; }
  prepare_env() { : >"${prepare_marker}"; }

  if phase_system_dependencies; then
    fail_assertion "system dependency phase masked an installation failure"
    return 1
  fi
  [[ ! -e "${prepare_marker}" ]] || {
    fail_assertion "environment preparation ran after dependency failure"
    return 1
  }
)

test_main_stops_after_system_dependency_failure() (
  local phase_trace="${TEST_ROOT}/system-dependency-phases.trace"
  local log_trace="${TEST_ROOT}/system-dependency-log.trace"
  local status=0

  # shellcheck source=../installer.sh
  source "${INSTALLER}"

  FAILED=()
  UPDATE_FAILED=()
  PHASE_RESULTS=()
  log() { printf '%s\n' "$*" >>"${log_trace}"; }
  print_summary() { :; }
  run_phase() {
    local name="$1"
    printf '%s\n' "${name}" >>"${phase_trace}"
    if [[ "${name}" == "System Dependencies" ]]; then
      FAILED+=("System dependencies: intentional test failure")
      return 1
    fi
    return 0
  }

  if (main); then
    fail_assertion "main unexpectedly succeeded after dependency failure"
    return 1
  else
    status=$?
  fi
  assert_equal "1" "${status}" "dependency failure status" || return 1
  assert_equal $'Preflight\nSystem Dependencies' "$(<"${phase_trace}")" \
    "phases run before dependency cutoff" || return 1
  [[ "$(<"${log_trace}")" == *"SKIP PHASE: Canonical Python Environment - system dependency failure"* ]] || {
    fail_assertion "canonical Python skip was not reported"
    return 1
  }
  [[ "$(<"${log_trace}")" == *"SKIP PHASE: Tool Installation - system dependency failure"* ]] || {
    fail_assertion "tool-installation skip was not reported"
    return 1
  }
)

test_required_phase_failure_without_tool_outcome() (
  local failed_phase="$1"
  local trace="${TEST_ROOT}/required-phase-${failed_phase// /_}.trace"
  local output=""
  local status=0

  # Exercise the real phase runner and main with a command failure that has no
  # FAILED/UPDATE_FAILED side effect, as with ensurepip or a pip upgrade error.
  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  FAILED=()
  UPDATE_FAILED=()
  PHASE_RESULTS=()
  log() { printf '%s\n' "$*"; }
  print_summary() {
    printf 'failure-counts:%s:%s\n' "${#FAILED[@]}" "${#UPDATE_FAILED[@]}"
  }
  cleanup_legacy_project_venvs() { return 0; }
  cleanup_git_index_conflict_sidecars() { return 0; }
  mock_phase() {
    printf '%s\n' "$1" >>"${trace}"
    [[ "$1" != "${failed_phase}" ]] || return 29
  }
  phase_preflight() { mock_phase "Preflight"; }
  phase_system_dependencies() { mock_phase "System Dependencies"; }
  phase_python_environment() { mock_phase "Canonical Python Environment"; }
  phase_install_tools() { mock_phase "Tool Installation"; }
  phase_update_scanner_data() { mock_phase "Scanner Database Updates"; }
  verify_install_artifacts() { mock_phase "Post-Install Verification"; }
  phase_package_cmsscan() { mock_phase "Encrypted Bundle and cmsscan Wrapper"; }

  if output="$(main 2>&1)"; then
    fail_assertion "main succeeded after ${failed_phase} failed without a tool outcome"
    return 1
  else
    status=$?
  fi

  assert_equal "1" "${status}" "${failed_phase} failure status" || return 1
  [[ "${output}" == *"PHASE FAIL: ${failed_phase} (rc=29,"* && \
     "${output}" == *"failure-counts:0:0"* ]] || {
    fail_assertion "${failed_phase}: missing phase failure or unexpected tool outcome"
    return 1
  }
  [[ "${output}" != *"CMS Scanner installation completed successfully."* ]] || {
    fail_assertion "${failed_phase}: failure printed the success banner"
    return 1
  }
  if [[ "${failed_phase}" != "Encrypted Bundle and cmsscan Wrapper" ]]; then
    if grep -Fxq "Encrypted Bundle and cmsscan Wrapper" "${trace}"; then
      fail_assertion "${failed_phase}: published the bundle after a required phase failed"
      return 1
    fi
  fi
)

test_tool_runner_rejects_missing_outcome() (
  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }
  INSTALLED=()
  SKIPPED=()
  FAILED=()
  UPDATE_FAILED=()
  outcome_less_installer() { return 0; }

  if run_tool_installer outcome_less_installer; then
    fail_assertion "outcome-less tool installer was accepted"
    return 1
  fi
  assert_equal "0" "${#INSTALLED[@]}" "outcome-less installed count" || return 1
  assert_equal "1" "${#FAILED[@]}" "outcome-less failed count" || return 1
)

test_tool_runner_rolls_back_installed_outcome_on_settlement_failure() (
  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }
  INSTALLED=()
  SKIPPED=()
  FAILED=()
  UPDATE_FAILED=()
  installed_stub() { mark_installed "stub tool"; }
  settle_pending_managed_source() { return 41; }

  if run_tool_installer installed_stub; then
    fail_assertion "managed-source settlement failure was accepted"
    return 1
  fi
  assert_equal "0" "${#INSTALLED[@]}" \
    "failed settlement retained a false installed outcome" || return 1
  assert_equal "1" "${#FAILED[@]}" "failed settlement failure count" || return 1
)

test_cmseek_smoke_failure_records_failure() (
  local wrapper_marker="${TEST_ROOT}/cmseek-wrapper.called"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }
  TOOLS_DIR="${TEST_ROOT}/cmseek-tools"
  VENV_DIR="${TEST_ROOT}/cmseek-venv"
  INSTALLED=()
  SKIPPED=()
  FAILED=()
  repo_clone_or_update() {
    EFFECTIVE_REPO_DIR="${TOOLS_DIR}/CMSeeK"
    EFFECTIVE_WRAPPER_REPO_DIR="${TOOLS_DIR}/CMSeeK"
    return 0
  }
  run_user_cmd() { return 0; }
  tool_smoke_test() { return 1; }
  create_wrapper() { : >"${wrapper_marker}"; }

  install_cmseek
  assert_equal "0" "${#INSTALLED[@]}" "CMSeek false installed count" || return 1
  assert_equal "1" "${#FAILED[@]}" "CMSeek smoke failure count" || return 1
  [[ "${FAILED[0]}" == "CMSeek: smoke test failed" ]] || {
    fail_assertion "CMSeek smoke failure detail was unexpected: ${FAILED[0]}"
    return 1
  }
  [[ ! -e "${wrapper_marker}" ]] || {
    fail_assertion "CMSeek wrapper was published after failed smoke test"
    return 1
  }
)

test_generated_probes_set_dispatch_marker() (
  local case_root="${TEST_ROOT}/probe-dispatch"
  local health_trace="${case_root}/health.args"
  local final_trace="${case_root}/final.args"
  local fixture_output_file="${case_root}/probe.output"

  mkdir -p "${case_root}"
  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }
  has_cmd() { return 1; }

  capture_user_cmd() {
    printf '%s\n' "$@" >"${health_trace}"
    printf '%s\n' 'fixture runtime ready'
  }

  cms_runtime_probe_is_usable "0" 'fixture runtime ready' \
    /fixture/bin/scanner --help || {
      fail_assertion "runtime-health fixture probe was rejected"
      return 1
    }
  assert_equal \
    $'env\nVANTAGE_DISPATCHED=1\n/fixture/bin/scanner\n--help' \
    "$(<"${health_trace}")" \
    "runtime-health probe command" || return 1

  RUN_SMOKE_TESTS=1
  INSTALL_USER="fixture-user"
  vantage_make_temp() {
    local destination_var="$1"
    : >"${fixture_output_file}"
    printf -v "${destination_var}" '%s' "${fixture_output_file}"
  }
  run_and_capture_output() {
    local destination="$1"
    shift
    printf '%s\n' "$@" >"${final_trace}"
    printf '%s\n' 'fixture runtime ready' >"${destination}"
    return 0
  }

  verify_final_tool_probe "fixture scanner" "0" 'fixture runtime ready' \
    /fixture/bin/scanner --help || {
      fail_assertion "final fixture probe was rejected"
      return 1
    }
  assert_equal \
    $'run_as_install_user\nenv\nVANTAGE_DISPATCHED=1\n/fixture/bin/scanner\n--help' \
    "$(<"${final_trace}")" \
    "final verification probe command" || return 1
)

test_staged_snapshot_without_git_uses_commit_stamp() (
  local case_root="${TEST_ROOT}/staged-snapshot"
  local repo_dir="${case_root}/tools/FixtureTool"
  local managed_snapshot="${case_root}/compat/upstream/FixtureTool"
  local refresh_trace="${case_root}/refresh.trace"
  local commit="0123456789abcdef0123456789abcdef01234567"

  mkdir -p "${managed_snapshot}"
  printf '%s\n' "${commit}" >"${managed_snapshot}/.vantage-upstream-commit"
  [[ ! -e "${managed_snapshot}/.git" ]] || return 1

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }
  COMPAT_DIR="${case_root}/compat"
  UPDATE_EXISTING=1
  VANTAGE_STAGED_INSTALL=1
  UPDATED=()
  UPDATE_SKIPPED=()
  UPDATE_FAILED=()
  activate_managed_upstream_checkout() {
    printf '%s\n' "$1" >>"${refresh_trace}"
    return 1
  }

  repo_clone_or_update \
    https://primary.example.invalid/fixture.git "${repo_dir}" \
    https://fallback.example.invalid/fixture.git || {
      fail_assertion "staged managed snapshot with a valid commit stamp was rejected"
      return 1
    }

  assert_equal "${managed_snapshot}" "${EFFECTIVE_REPO_DIR}" \
    "effective staged source" || return 1
  assert_equal "${managed_snapshot}" "${EFFECTIVE_WRAPPER_REPO_DIR}" \
    "effective staged wrapper source" || return 1
  assert_equal "0" "${#UPDATE_FAILED[@]}" \
    "staged snapshot failure count" || return 1
  assert_equal "1" "${#UPDATE_SKIPPED[@]}" \
    "staged snapshot retained-update count" || return 1
  [[ "${UPDATE_SKIPPED[0]}" == *"retained bundled managed snapshot ${commit:0:12}"* ]] || {
    fail_assertion "staged snapshot retention did not report its commit stamp"
    return 1
  }
  assert_equal \
    $'https://primary.example.invalid/fixture.git\nhttps://fallback.example.invalid/fixture.git' \
    "$(<"${refresh_trace}")" \
    "offline staged refresh attempts" || return 1
)

test_staged_checkout_cleanup_is_skipped() (
  local case_root="${TEST_ROOT}/staged-cleanup"
  local helper="${case_root}/cleanup-helper.sh"
  local invocation_marker="${case_root}/cleanup.invoked"

  mkdir -p "${case_root}/checkout"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${helper}"
  chmod 0755 "${helper}"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  VANTAGE_INSTALLER_CLEANUP_HELPER="${helper}"
  cleanup_helper_is_trusted() { return 0; }
  run_user_cmd() {
    : >"${invocation_marker}"
    return 0
  }

  VANTAGE_STAGED_INSTALL=1
  run_post_install_cleanup "${case_root}/checkout" || {
    fail_assertion "staged checkout cleanup did not return success"
    return 1
  }
  [[ ! -e "${invocation_marker}" ]] || {
    fail_assertion "staged checkout invoked the cleanup helper"
    return 1
  }

  VANTAGE_STAGED_INSTALL=0
  run_post_install_cleanup "${case_root}/checkout" || return 1
  [[ -f "${invocation_marker}" ]] || {
    fail_assertion "non-staged control did not invoke the cleanup helper"
    return 1
  }
)

run_test "default update policy" test_default_update_policy
run_test "full data-refresh policy" test_full_update_policy
run_test "--no-update delegates to all update functions" \
  test_no_update_delegates_to_every_updater
run_test "WPScan update uses BIN_DIR/wpscan exactly" \
  test_wpscan_uses_exact_wrapper_path
run_test "main stops costly phases after tool installation failure" \
  test_main_skips_later_phases_after_tool_failure
run_test "main stops tool installation after Python environment failure" \
  test_main_stops_tool_phase_after_environment_failure
run_test "system dependency phase propagates failure" \
  test_system_dependency_phase_propagates_failure
run_test "main stops after system dependency failure" \
  test_main_stops_after_system_dependency_failure
for failed_required_phase in \
  "System Dependencies" "Canonical Python Environment" "Tool Installation" \
  "Scanner Database Updates" "Post-Install Verification" \
  "Encrypted Bundle and cmsscan Wrapper"; do
  run_test "main rejects ${failed_required_phase} failure without a tool outcome" \
    test_required_phase_failure_without_tool_outcome "${failed_required_phase}"
done
run_test "tool runner rejects a missing outcome" \
  test_tool_runner_rejects_missing_outcome
run_test "tool runner rejects managed-source settlement failure" \
  test_tool_runner_rolls_back_installed_outcome_on_settlement_failure
run_test "CMSeek smoke failure records a failed outcome" \
  test_cmseek_smoke_failure_records_failure
run_test "generated runtime probes set the dispatcher marker" \
  test_generated_probes_set_dispatch_marker
run_test "staged source snapshot accepts a commit stamp without .git" \
  test_staged_snapshot_without_git_uses_commit_stamp
run_test "staged checkout cleanup is delegated to the parent" \
  test_staged_checkout_cleanup_is_skipped

if ((FAIL_COUNT != 0)); then
  printf '%s test(s) failed; %s passed.\n' "${FAIL_COUNT}" "${PASS_COUNT}" >&2
  exit 1
fi

printf 'All %s installer update-policy tests passed.\n' "${PASS_COUNT}"
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
