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
# The harness sources the installer and replaces external operations with local
# deterministic doubles. No repository, package manager, network, or scanner is
# invoked by these tests.
# shellcheck disable=SC1091,SC2034,SC2317
set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="${TEST_DIR}/../installer.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cms-fingerprinter-health.XXXXXX")"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  case "${TEST_ROOT}" in
    "${TMPDIR:-/tmp}"/cms-fingerprinter-health.*)
      find -P "${TEST_ROOT}" -xdev -depth -delete 2>/dev/null || true
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

assert_trace_arg() {
  local trace="$1"
  local expected="$2"
  local context="$3"

  grep -Fxq -- "${expected}" "${trace}" || {
    printf '    %s: missing argument %q\n' "${context}" "${expected}" >&2
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

write_executable_fixture() {
  local path="$1"

  mkdir -p "$(dirname -- "${path}")"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${path}"
  chmod 0755 "${path}"
}

configure_health_fixture() {
  local case_dir="$1"

  TOOLS_DIR="${case_dir}/tools"
  COMPAT_DIR="${TOOLS_DIR}/.compat"
  BIN_DIR="${case_dir}/bin"
  INSTALL_HOME="${case_dir}/home"
  INSTALL_USER="$(id -un)"
  INSTALL_UID="$(id -u)"
  INSTALL_GID="$(id -g)"
  USER_GEM_BIN="${case_dir}/gem-home/bin"
  FINGERPRINTER_LOCKFILE="${case_dir}/canonical/Gemfile.lock"

  mkdir -p \
    "${COMPAT_DIR}/fingerprinter-src" \
    "${BIN_DIR}" \
    "${INSTALL_HOME}" \
    "${USER_GEM_BIN}" \
    "$(dirname -- "${FINGERPRINTER_LOCKFILE}")"
  printf 'GEM\n  specs:\n\nBUNDLED WITH\n   2.5.22\n' \
    >"${FINGERPRINTER_LOCKFILE}"
  write_executable_fixture "${USER_GEM_BIN}/bundle"
}

test_health_rejects_incomplete_or_drifted_runtime() (
  local case_dir="${TEST_ROOT}/preconditions"
  local runtime="${case_dir}/tools/.compat/fingerprinter-src"
  local wrapper="${case_dir}/bin/fingerprinter"

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  configure_health_fixture "${case_dir}"

  # Preserve the real comparison while replacing every executable runtime
  # probe. This keeps the test offline and makes lock drift observable.
  run_as_install_user() {
    if [[ "${1:-}" == "cmp" ]]; then
      command "$@"
    else
      return 0
    fi
  }

  if fingerprinter_runtime_is_usable "${runtime}" "${wrapper}"; then
    fail_assertion "runtime health accepted a missing published wrapper"
    return 1
  fi

  write_executable_fixture "${wrapper}"
  if fingerprinter_runtime_is_usable "${runtime}" "${wrapper}"; then
    fail_assertion "runtime health accepted a missing Gemfile"
    return 1
  fi

  printf 'source "https://example.invalid"\n' >"${runtime}/Gemfile"
  if fingerprinter_runtime_is_usable "${runtime}" "${wrapper}"; then
    fail_assertion "runtime health accepted a missing Gemfile.lock"
    return 1
  fi

  cp "${FINGERPRINTER_LOCKFILE}" "${runtime}/Gemfile.lock"
  fingerprinter_runtime_is_usable "${runtime}" "${wrapper}" || {
    fail_assertion "complete fixture runtime was not considered healthy"
    return 1
  }

  printf '# unreviewed lock drift\n' >>"${runtime}/Gemfile.lock"
  if fingerprinter_runtime_is_usable "${runtime}" "${wrapper}"; then
    fail_assertion "runtime health accepted a lockfile that differs from the canonical lock"
    return 1
  fi
)

test_bundle_probe_uses_published_runtime_environment() (
  local case_dir="${TEST_ROOT}/probe-environment"
  local runtime="${case_dir}/tools/.compat/fingerprinter-src"
  local wrapper="${case_dir}/bin/fingerprinter"
  local trace="${case_dir}/probe.args"
  local ruby_program=""

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  configure_health_fixture "${case_dir}"
  printf 'source "https://example.invalid"\n' >"${runtime}/Gemfile"
  cp "${FINGERPRINTER_LOCKFILE}" "${runtime}/Gemfile.lock"
  write_executable_fixture "${wrapper}"

  run_as_install_user() {
    if [[ "${1:-}" == "cmp" ]]; then
      command "$@"
      return
    fi
    {
      printf '%s\n' '--- call ---'
      printf '%s\n' "$@"
    } >>"${trace}"
    return 0
  }

  fingerprinter_bundle_is_usable "${runtime}" || {
    fail_assertion "the complete fixture bundle did not pass its mocked probe"
    return 1
  }
  fingerprinter_runtime_is_usable "${runtime}" "${wrapper}" || {
    fail_assertion "the complete fixture runtime did not pass its mocked probe"
    return 1
  }

  assert_trace_arg "${trace}" "HOME=${INSTALL_HOME}" "Fingerprinter HOME" || return 1
  assert_trace_arg "${trace}" "GEM_HOME=${USER_GEM_BIN%/bin}" "Fingerprinter GEM_HOME" || return 1
  grep -Fq -- "GEM_PATH=${USER_GEM_BIN%/bin}" "${trace}" || {
    fail_assertion "Fingerprinter GEM_PATH does not begin with the install-user gem home"
    return 1
  }
  assert_trace_arg "${trace}" "BUNDLE_GEMFILE=${runtime}/Gemfile" \
    "Fingerprinter BUNDLE_GEMFILE" || return 1
  assert_trace_arg "${trace}" "BUNDLE_FROZEN=true" \
    "Fingerprinter frozen bundle setting" || return 1
  assert_trace_arg "${trace}" "BUNDLE_IGNORE_CONFIG=true" \
    "Fingerprinter isolated Bundler config" || return 1
  assert_trace_arg "${trace}" "RUBYOPT=-W0 -W:no-deprecated" \
    "Fingerprinter RUBYOPT" || return 1
  assert_trace_arg "${trace}" \
    "FINGERPRINTER_BUNDLER_VERSION=2.5.22" \
    "Fingerprinter Bundler version" || return 1
  assert_trace_arg "${trace}" "ruby" "Fingerprinter Ruby probe" || return 1
  assert_trace_arg "${trace}" "-e" "Fingerprinter Ruby probe mode" || return 1
  ruby_program="$(grep -F 'bundler/setup' "${trace}" | head -n 1 || true)"
  [[ "${ruby_program}" == *'gem "bundler"'* && \
     "${ruby_program}" == *'require "bundler/setup"'* ]] || {
    fail_assertion "Ruby probe did not activate exact Bundler and load bundler/setup"
    return 1
  }
  assert_trace_arg "${trace}" "${wrapper}" "published wrapper probe" || return 1
  assert_trace_arg "${trace}" "--help" "published wrapper help probe" || return 1
)

test_runtime_health_precedes_source_freshness() (
  local case_dir="${TEST_ROOT}/decision-matrix"
  local trace="${case_dir}/trace"
  local runtime_healthy=0
  local source_current=0

  mkdir -p "${case_dir}"
  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  log() { :; }

  fingerprinter_runtime_is_usable() {
    printf 'health\n' >>"${trace}"
    [[ "${runtime_healthy}" -eq 1 ]]
  }
  cms_git_tool_is_current() {
    printf 'source\n' >>"${trace}"
    if [[ "${source_current}" -eq 1 ]]; then
      mark_skipped "Fingerprinter" "mock source is current"
      mark_update_skipped "fingerprinter source" "mock source is current"
      return 0
    fi
    return 1
  }
  install_fingerprinter() {
    printf 'install\n' >>"${trace}"
    mark_installed "Fingerprinter"
  }

  run_matrix_case() {
    local health="$1"
    local current="$2"
    local expected_trace="$3"
    local expected_installed="$4"
    local expected_skipped="$5"
    local actual_trace=""

    runtime_healthy="${health}"
    source_current="${current}"
    : >"${trace}"
    INSTALLED=()
    SKIPPED=()
    FAILED=()
    UPDATED=()
    UPDATE_SKIPPED=()
    UPDATE_FAILED=()
    FORCE_INSTALL=0
    UPDATE_EXISTING=1

    run_tool_installer install_fingerprinter || return 1
    actual_trace="$(paste -sd, "${trace}")"
    assert_equal "${expected_trace}" "${actual_trace}" \
      "health/source/install decision order" || return 1
    assert_equal "${expected_installed}" "${#INSTALLED[@]}" \
      "installed outcome count" || return 1
    assert_equal "${expected_skipped}" "${#SKIPPED[@]}" \
      "skipped outcome count" || return 1
  }

  # A broken runtime must bypass source freshness even when its Git checkout is
  # current. A healthy runtime may skip only when its source is also current.
  run_matrix_case 0 1 'health,install' 1 0 || return 1
  run_matrix_case 0 0 'health,install' 1 0 || return 1
  run_matrix_case 1 1 'health,source' 0 1 || return 1
  run_matrix_case 1 0 'health,source,install' 1 0 || return 1
)

test_installer_uses_the_reviewed_bundle_contract() (
  local function_body=""
  local flat_body=""

  # shellcheck source=../installer.sh
  source "${INSTALLER}"
  function_body="$(declare -f install_fingerprinter)"
  flat_body="$(printf '%s\n' "${function_body}" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')"

  assert_equal "2.5.22" "${FINGERPRINTER_BUNDLER_VERSION}" \
    "reviewed Fingerprinter Bundler version" || return 1
  [[ "${flat_body}" != *'locked_gems'* ]] || {
    fail_assertion "Fingerprinter still uses a hand-maintained transitive gem list"
    return 1
  }
  [[ "${flat_body}" == *'FINGERPRINTER_LOCKFILE'* ]] || {
    fail_assertion "Fingerprinter install does not publish the canonical lockfile"
    return 1
  }
  [[ "${flat_body}" == *'BUNDLE_FROZEN=true'* ]] || {
    fail_assertion "Fingerprinter bundle installation is not frozen"
    return 1
  }
  [[ "${flat_body}" == *' install --jobs 1 --retry 2'* ]] || {
    fail_assertion "Fingerprinter does not install the complete bundle with bounded retries"
    return 1
  }
  [[ "${flat_body}" == *' check'* ]] || {
    fail_assertion "Fingerprinter does not run bundle check"
    return 1
  }
  [[ "${flat_body}" == *'fingerprinter.rb" --help'* ]] || {
    fail_assertion "Fingerprinter candidate smoke test is missing"
    return 1
  }
  [[ "${flat_body}" == *'activate_runtime_candidate'* ]] || {
    fail_assertion "Fingerprinter candidate activation is missing"
    return 1
  }
)

run_test \
  "runtime health rejects missing artifacts and canonical-lock drift" \
  test_health_rejects_incomplete_or_drifted_runtime
run_test \
  "bundle and wrapper probes use the published install-user environment" \
  test_bundle_probe_uses_published_runtime_environment
run_test \
  "runtime health is evaluated before the four source-freshness outcomes" \
  test_runtime_health_precedes_source_freshness
run_test \
  "installer uses the reviewed frozen lockfile contract" \
  test_installer_uses_the_reviewed_bundle_contract

printf '\nRESULT: %d passed, %d failed\n' "${PASS_COUNT}" "${FAIL_COUNT}"
[[ "${FAIL_COUNT}" -eq 0 ]]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
