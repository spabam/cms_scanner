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
set -Eeuo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${TESTS_DIR}/.." && pwd -P)"
INSTALLER_PATH="${PROJECT_DIR}/installer.sh"

# The path is resolved from this script so the test also works from another cwd.
# shellcheck disable=SC1090,SC1091
source "${INSTALLER_PATH}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/cms-scanner-installer-helpers.XXXXXX")"

cleanup_test_tmp() {
  if [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP}" ]]; then
    chmod -R u+rwX "${TEST_TMP}" 2>/dev/null || true
    rm -rf -- "${TEST_TMP}"
  fi
}
trap cleanup_test_tmp EXIT

fail() {
  printf '    %s\n' "$*" >&2
  return 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "${actual}" == "${expected}" ]] || \
    fail "${message}: expected '${expected}', got '${actual}'"
}

skip_test() {
  printf '    %s\n' "$*" >&2
  return 77
}

run_test() {
  local name="$1"
  local rc=0
  shift

  printf 'TEST: %s\n' "${name}"
  if ( "$@" ); then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  PASS\n'
    return 0
  else
    rc=$?
  fi

  if [[ "${rc}" -eq 77 ]]; then
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf '  SKIP\n'
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  FAIL (exit %d)\n' "${rc}" >&2
  fi
}

# Fixture-only command runner. Production installer commands remain bound to
# the fixed aiuser identity by .runtime_identity.sh; these unit fixtures use
# temporary homes and, for ownership tests, a disposable non-root account.
test_run_as_fixture_user() {
  local user_path="${BIN_DIR}:${BASE_PATH}"
  local current_uid=""
  local -a clean_env=(
    /usr/bin/env -i
    "HOME=${INSTALL_HOME}"
    "USER=${INSTALL_USER}"
    "LOGNAME=${INSTALL_USER}"
    "PATH=${user_path}"
    PYTHONNOUSERSITE=1
    PIP_DISABLE_PIP_VERSION_CHECK=1
    LANG=C.UTF-8
    LC_ALL=C.UTF-8
  )

  if [[ -n "${USER_GEM_BIN}" ]]; then
    user_path="${BIN_DIR}:${USER_GEM_BIN}:${BASE_PATH}"
    clean_env[5]="PATH=${user_path}"
  fi
  current_uid="$(id -u)" || return 69
  if [[ "${current_uid}" == "${INSTALL_UID}" ]]; then
    "${clean_env[@]}" "$@"
  elif (( current_uid == 0 )); then
    /usr/sbin/runuser -u "${INSTALL_USER}" -- "${clean_env[@]}" "$@"
  else
    /usr/bin/sudo -n -H -u "${INSTALL_USER}" -- "${clean_env[@]}" "$@"
  fi
}

# shellcheck disable=SC2317
run_as_install_user() {
  test_run_as_fixture_user "$@"
}

configure_install_context() {
  local user="$1"
  local home="$2"
  local bin_dir="$3"
  local compat_dir="$4"

  INSTALL_USER="${user}"
  INSTALL_HOME="${home}"
  INSTALL_UID="$(id -u "${user}")"
  INSTALL_GID="$(id -g "${user}")"
  BIN_DIR="${bin_dir}"
  VENV_DIR="${home}/.local/share/vantage/cms_scanner/venv"
  COMPAT_DIR="${compat_dir}"
  USER_GEM_BIN=""
  BASE_PATH="${SYSTEM_PATH}"
  LOG_FILE="${home}/installer-test.log.not-created"
  SHARED_ENV_CONSTRAINTS=""

  # These globals are consumed dynamically by functions sourced above.
  : "${INSTALL_USER}" "${INSTALL_HOME}" "${INSTALL_UID}" "${INSTALL_GID}" \
    "${BIN_DIR}" "${VENV_DIR}" "${COMPAT_DIR}" "${USER_GEM_BIN}" \
    "${BASE_PATH}" "${LOG_FILE}" "${SHARED_ENV_CONSTRAINTS}"
}

find_non_root_account() {
  local candidate=""

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && \
    id -u "${SUDO_USER}" >/dev/null 2>&1 && \
    [[ "$(id -u "${SUDO_USER}")" -gt 0 ]]; then
    printf '%s\n' "${SUDO_USER}"
    return 0
  fi
  if id -u spabam >/dev/null 2>&1 && [[ "$(id -u spabam)" -gt 0 ]]; then
    printf '%s\n' "spabam"
    return 0
  fi

  candidate="$(getent passwd | awk -F: '
    $3 >= 1000 && $3 < 65534 && first == "" { first = $1 }
    END { print first }
  ')"
  if [[ -z "${candidate}" ]]; then
    candidate="$(getent passwd | awk -F: '
      $3 > 0 && $3 < 65534 && first == "" { first = $1 }
      END { print first }
    ')"
  fi
  [[ -n "${candidate}" ]] || return 1
  printf '%s\n' "${candidate}"
}

require_root_test_account() {
  local user=""

  if [[ "${EUID}" -ne 0 ]]; then
    skip_test "requires EUID 0 to construct root-owned fixtures"
    return $?
  fi
  user="$(find_non_root_account || true)"
  if [[ -z "${user}" ]]; then
    skip_test "no non-root account is available for privilege-drop checks"
    return $?
  fi
  if [[ -z "$(system_cmd_path sudo || true)" && \
        -z "$(system_cmd_path runuser || true)" ]]; then
    skip_test "neither sudo nor runuser is available for privilege-drop checks"
    return $?
  fi
  printf '%s\n' "${user}"
}

test_command_resolution_preserves_injected_path() {
  local case_dir="${TEST_TMP}/command-resolution"
  local fake_home="${case_dir}/home"
  local fake_bin="${case_dir}/bin"
  local fake_command="${fake_bin}/installer-helper-probe"
  local profile_path=""
  local resolved=""
  local current_user=""

  mkdir -p "${fake_home}" "${fake_bin}" "${case_dir}/compat"
  printf '%s\n' \
    'PATH=/profile-reset-only' \
    'export PATH' >"${fake_home}/.profile"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${fake_command}"
  chmod 0755 "${fake_command}"

  profile_path="$(
    HOME="${fake_home}" \
      PATH="${fake_bin}:${SYSTEM_PATH}" \
      bash --noprofile --norc -c \
      '. "$HOME/.profile"; printf "%s" "$PATH"'
  )"
  assert_equal "/profile-reset-only" "${profile_path}" \
    "the fixture profile did not reset PATH" || return 1

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${fake_bin}" "${case_dir}/compat"

  has_user_cmd installer-helper-probe || \
    fail "has_user_cmd did not preserve the injected BIN_DIR" || return 1
  resolved="$(resolve_user_cmd_path installer-helper-probe)"
  assert_equal "${fake_command}" "${resolved}" \
    "resolve_user_cmd_path did not return the injected command" || return 1
}

test_canonical_venv_accepts_safe_user_symlink() {
  local case_dir="${TEST_TMP}/canonical-venv-symlink"
  local fake_home="${case_dir}/home"
  local physical_venv="${case_dir}/physical-venv"
  local shadow_bin="${case_dir}/shadow-bin"
  local current_user=""

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}/.local/share/vantage/cms_scanner" \
    "${case_dir}/bin" "${case_dir}/compat" "${shadow_bin}"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  ln -s "${physical_venv}" \
    "${fake_home}/.local/share/vantage/cms_scanner/venv"
  # The fixture must defer expansion of $last_arg until the fake command runs.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/bin/sh' \
    'for last_arg do :; done' \
    'printf "%s\n" "$last_arg"' >"${shadow_bin}/readlink"
  chmod 0755 "${shadow_bin}/readlink"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  # Globals consumed dynamically by the sourced installer helper.
  # shellcheck disable=SC2034
  UPDATE_EXISTING=0
  FAILED=()
  # shellcheck disable=SC2034
  UPDATE_SKIPPED=()
  BASE_PATH="${shadow_bin}:${SYSTEM_PATH}"
  PATH="${shadow_bin}:${PATH}"

  ensure_canonical_venv || \
    fail "safe user-owned canonical venv symlink was rejected when readlink was shadowed" || return 1
  assert_equal "0" "${#FAILED[@]}" \
    "safe canonical venv symlink failure count" || return 1
  assert_equal "${physical_venv}" \
    "$("$(system_cmd_path readlink)" -f -- "${VENV_DIR}")" \
    "canonical venv symlink target" || return 1
}

test_canonical_venv_accepts_private_group_writable_target() {
  local case_dir="${TEST_TMP}/canonical-venv-private-group"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local current_user=""
  local target_mode=""

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  install_user_primary_group_is_private || {
    skip_test "the current account does not have a verifiable private primary group"
    return $?
  }
  chgrp "${INSTALL_GID}" "${physical_venv}"
  chmod 0775 "${physical_venv}"
  # Globals consumed dynamically by the sourced installer helper.
  # shellcheck disable=SC2034
  UPDATE_EXISTING=0
  FAILED=()
  # shellcheck disable=SC2034
  UPDATE_SKIPPED=()

  ensure_canonical_venv || \
    fail "private-primary-group writable canonical venv was rejected" || return 1
  target_mode="$(stat -c '%a' "${physical_venv}")"
  assert_equal "775" "${target_mode}" \
    "private-group writable mode should be preserved" || return 1
  assert_equal "0" "${#FAILED[@]}" \
    "private-group writable canonical venv failure count" || return 1
}

test_canonical_venv_repairs_root_owned_entries() {
  local user=""
  local uid=""
  local gid=""
  local case_dir="${TEST_TMP}/canonical-venv-root-owned-entries"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local root_owned_dir="${physical_venv}/lib/root-created-cache"
  local root_owned_file="${root_owned_dir}/bytecode.pyc"
  local root_group_file="${physical_venv}/user-owned-root-group.cache"

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"
  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }

  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  chown -R "${uid}:${gid}" "${fake_home}"
  chmod 0700 "${fake_home}"

  mkdir -p "${root_owned_dir}"
  printf '%s\n' 'stale-root-bytecode' >"${root_owned_file}"
  printf '%s\n' 'stale-root-group-cache' >"${root_group_file}"
  chown -R 0:0 "${root_owned_dir}"
  chown "${uid}:0" "${root_group_file}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  # Globals consumed dynamically by the sourced installer helper.
  # shellcheck disable=SC2034
  UPDATE_EXISTING=0
  FAILED=()
  # shellcheck disable=SC2034
  UPDATE_SKIPPED=()

  ensure_canonical_venv || \
    fail "canonical venv did not repair stale root-owned entries" || return 1
  assert_equal "${uid}:${gid}" "$(stat -c '%u:%g' "${root_owned_dir}")" \
    "root-created directory ownership was not repaired" || return 1
  assert_equal "${uid}:${gid}" "$(stat -c '%u:%g' "${root_owned_file}")" \
    "root-created file ownership was not repaired" || return 1
  assert_equal "${uid}:${gid}" "$(stat -c '%u:%g' "${root_group_file}")" \
    "user-owned root-group file ownership was not repaired" || return 1
  assert_equal "0" "${#FAILED[@]}" \
    "root-owned canonical venv repair failure count" || return 1

  ensure_canonical_venv || \
    fail "canonical venv ownership repair was not idempotent" || return 1
}

test_canonical_venv_repair_preflight_is_atomic() {
  local user=""
  local uid=""
  local gid=""
  local foreign_user=""
  local foreign_uid=""
  local foreign_gid=""
  local case_dir="${TEST_TMP}/canonical-venv-repair-atomicity"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local root_candidate="${physical_venv}/a-root-candidate"
  local foreign_entry="${physical_venv}/z-foreign-entry"

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"
  foreign_user="$(getent passwd | awk -F: -v excluded="${uid}" \
    '$3 > 0 && $3 != excluded && $3 < 65534 { print $1; exit }')"
  [[ -n "${foreign_user}" ]] || {
    skip_test "no second non-root account is available for the atomicity fixture"
    return $?
  }
  foreign_uid="$(id -u "${foreign_user}")"
  foreign_gid="$(id -g "${foreign_user}")"

  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  chown -R "${uid}:${gid}" "${fake_home}"
  chmod 0700 "${fake_home}"
  printf '%s\n' root >"${root_candidate}"
  printf '%s\n' foreign >"${foreign_entry}"
  chown 0:0 "${root_candidate}"
  chown "${foreign_uid}:${foreign_gid}" "${foreign_entry}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  UPDATE_EXISTING=0
  FAILED=()
  UPDATE_SKIPPED=()

  if ensure_canonical_venv; then
    fail "canonical venv repair accepted foreign non-root ownership" || return 1
  fi
  assert_equal "0:0" "$(stat -c '%u:%g' "${root_candidate}")" \
    "preflight failure partially repaired a root-owned candidate" || return 1
  assert_equal "${foreign_uid}:${foreign_gid}" \
    "$(stat -c '%u:%g' "${foreign_entry}")" \
    "preflight failure changed the foreign-owned entry" || return 1
}

test_canonical_venv_repair_rejects_external_hardlink() {
  local user=""
  local uid=""
  local gid=""
  local case_dir="${TEST_TMP}/canonical-venv-hardlink"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local external_file="${case_dir}/outside-root-file"
  local linked_entry="${physical_venv}/root-hardlink"

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"
  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  chown -R "${uid}:${gid}" "${fake_home}"
  chmod 0700 "${fake_home}"
  printf '%s\n' external-root-data >"${external_file}"
  chown 0:0 "${external_file}"
  ln "${external_file}" "${linked_entry}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  UPDATE_EXISTING=0
  FAILED=()
  UPDATE_SKIPPED=()

  if ensure_canonical_venv; then
    fail "canonical venv repair accepted an ownership-changing hardlink" || return 1
  fi
  assert_equal "0:0" "$(stat -c '%u:%g' "${external_file}")" \
    "external hardlink inode ownership changed" || return 1
  assert_equal "external-root-data" "$(<"${external_file}")" \
    "external hardlink inode content changed" || return 1
}

test_install_identity_ignores_frozen_caller_values() {
  local user=""
  local uid=""
  local gid=""
  local home=""

  if ! id aiuser >/dev/null 2>&1; then
    skip_test "fixed runtime account aiuser is unavailable"
    return $?
  fi
  user=aiuser
  uid="$(id -u aiuser)"
  gid="$(id -g aiuser)"
  home="$(getent passwd "${user}" | cut -d: -f6)"
  export VANTAGE_INSTALLER_ORIGINAL_USER="$(id -un)"
  export VANTAGE_INSTALLER_ORIGINAL_UID="$(id -u)"
  export VANTAGE_INSTALLER_ORIGINAL_GID="$(id -g)"
  export VANTAGE_INSTALLER_ORIGINAL_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
  USER=definitely-not-the-install-user
  SUDO_USER=also-not-the-install-user

  resolve_install_user || \
    fail "fixed aiuser installer identity was rejected" || return 1
  assert_equal "${user}:${uid}:${gid}:${home}" \
    "${INSTALL_USER}:${INSTALL_UID}:${INSTALL_GID}:${INSTALL_HOME}" \
    "caller bootstrap values overrode the fixed aiuser identity" || return 1
  assert_equal "${home}/.local/share/vantage/cms_scanner/venv" \
    "${VENV_DIR}" \
    "CMS installer did not select its component-scoped venv" || return 1
}

test_canonical_venv_rejects_world_writable_target() {
  local case_dir="${TEST_TMP}/canonical-venv-world-writable"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local current_user=""
  local rc=0

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  chmod 0757 "${physical_venv}"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  FAILED=()

  if ensure_canonical_venv; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "world-writable canonical venv target was accepted" || return 1
  [[ "${#FAILED[@]}" -eq 1 && "${FAILED[0]}" == *"world-writable"* ]] || \
    fail "world-writable target did not report the expected failure" || return 1
}

test_canonical_venv_rejects_foreign_group_writable_target() {
  local case_dir="${TEST_TMP}/canonical-venv-foreign-group"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local current_user=""
  local foreign_gid=""
  local gid=""
  local rc=0

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  if [[ "${EUID}" -eq 0 ]]; then
    foreign_gid="$(getent group | awk -F: -v own="${INSTALL_GID}" \
      '$3 != own { print $3; exit }')"
  else
    for gid in $(id -G); do
      if [[ "${gid}" != "${INSTALL_GID}" ]]; then
        foreign_gid="${gid}"
        break
      fi
    done
  fi
  [[ -n "${foreign_gid}" ]] || {
    skip_test "no alternate group is available for the foreign-group fixture"
    return $?
  }
  chgrp "${foreign_gid}" "${physical_venv}" 2>/dev/null || {
    skip_test "cannot assign the foreign-group fixture"
    return $?
  }
  chmod 0775 "${physical_venv}"
  FAILED=()

  if ensure_canonical_venv; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "foreign-group writable canonical venv target was accepted" || return 1
  [[ "${#FAILED[@]}" -eq 1 && "${FAILED[0]}" == *"non-private group"* ]] || \
    fail "foreign-group target did not report the expected failure" || return 1
}

test_canonical_venv_rejects_nested_world_writable_entry() {
  local case_dir="${TEST_TMP}/canonical-venv-nested-world-write"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local unsafe_file=""
  local current_user=""

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  unsafe_file="${physical_venv}/nested-world-writable"
  : >"${unsafe_file}"
  chmod 0666 "${unsafe_file}"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  FAILED=()

  if ensure_canonical_venv; then
    fail "canonical venv accepted a nested world-writable file" || return 1
  fi
  [[ "${#FAILED[@]}" -eq 1 && "${FAILED[0]}" == *"world-writable entry"* ]] || \
    fail "nested world-write did not report the expected failure" || return 1
}

test_canonical_venv_rejects_nested_world_writable_directory() {
  local case_dir="${TEST_TMP}/canonical-venv-nested-world-write-directory"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local unsafe_directory=""
  local current_user=""

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  unsafe_directory="${physical_venv}/nested-world-writable-directory"
  mkdir "${unsafe_directory}"
  chmod 0777 "${unsafe_directory}"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  FAILED=()

  if ensure_canonical_venv; then
    fail "canonical venv accepted a nested world-writable directory" || return 1
  fi
  [[ "${#FAILED[@]}" -eq 1 && "${FAILED[0]}" == *"world-writable entry"* ]] || \
    fail "nested world-writable directory did not report the expected failure" || \
    return 1
  assert_equal "777" "$(stat -c '%a' "${unsafe_directory}")" \
    "unsafe directory mode should not be silently repaired" || return 1
}

test_shared_environment_constraints_preserve_compatible_bounds() {
  local case_dir="${TEST_TMP}/shared-environment-constraints"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local site_packages=""
  local constraints=""
  local captured_command="${case_dir}/pip-command"
  local current_user=""

  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  site_packages="$(
    "${physical_venv}/bin/python" -c \
      'import sysconfig; print(sysconfig.get_paths()["purelib"])'
  )"
  mkdir -p \
    "${site_packages}/baseline_consumer-1.0.dist-info" \
    "${site_packages}/guarded-1.0.dist-info" \
    "${site_packages}/already_broken-2.0.dist-info" \
    "${site_packages}/lower_only-1.0.dist-info"
  printf '%s\n' \
    'Metadata-Version: 2.1' \
    'Name: baseline-consumer' \
    'Version: 1.0' \
    'Requires-Dist: guarded==1.0' \
    'Requires-Dist: already-broken==1.0' \
    'Requires-Dist: lower-only>=1.0' \
    >"${site_packages}/baseline_consumer-1.0.dist-info/METADATA"
  printf '%s\n' \
    'Metadata-Version: 2.1' 'Name: guarded' 'Version: 1.0' \
    >"${site_packages}/guarded-1.0.dist-info/METADATA"
  printf '%s\n' \
    'Metadata-Version: 2.1' 'Name: already-broken' 'Version: 2.0' \
    >"${site_packages}/already_broken-2.0.dist-info/METADATA"
  printf '%s\n' \
    'Metadata-Version: 2.1' 'Name: lower-only' 'Version: 1.0' \
    >"${site_packages}/lower_only-1.0.dist-info/METADATA"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  # Consumed dynamically by write_shared_environment_constraints.
  # shellcheck disable=SC2034
  PIP_CHECK_ALLOWED_NEWER=(
    "baseline-consumer 1.0 has requirement already-broken==1.0, but you have already-broken 2.0."
  )

  write_shared_environment_constraints || \
    fail "shared-environment constraint generation failed" || return 1
  constraints="${SHARED_ENV_CONSTRAINTS}"
  grep -Fxq 'guarded==1.0' "${constraints}" || \
    fail "satisfied exact requirement was not constrained" || return 1
  grep -Fxq 'already-broken==2.0' "${constraints}" || \
    fail "accepted baseline mismatch was not constrained at its actual version" || \
    return 1
  if grep -Eq '^lower-only==' "${constraints}"; then
    fail "lower-bound-only requirement was unnecessarily constrained" || return 1
  fi

  UPDATE_EXISTING=1
  run_user_cmd() {
    printf '%s\n' "$*" >"${captured_command}"
  }
  scanner_pip_install guarded
  grep -Fq -- "--constraint ${constraints}" "${captured_command}" || \
    fail "scanner pip command omitted shared-environment constraints" || return 1
  grep -Fq -- '--upgrade-strategy only-if-needed' "${captured_command}" || \
    fail "scanner pip command did not use the conservative upgrade strategy" || \
    return 1
}

test_managed_python_build_cleanup_is_narrow() {
  local case_dir="${TEST_TMP}/managed-python-build-cleanup"
  local fake_home="${case_dir}/home"
  local compat_dir="${case_dir}/tools/.compat"
  local cmsmap_live="${compat_dir}/upstream/CMSmap"
  local cmsmap_candidate="${cmsmap_live}.new.A1B2C3"
  local user_checkout="${case_dir}/tools/CMSmap"
  local outside="${case_dir}/outside"
  local linked_candidate="${cmsmap_live}.new.L1N2K3"
  local current_user=""
  local cmsmap_function=""
  local drupwn_function=""

  mkdir -p \
    "${fake_home}" \
    "${case_dir}/bin" \
    "${cmsmap_live}/build" \
    "${cmsmap_live}/dist" \
    "${cmsmap_candidate}/build" \
    "${cmsmap_candidate}/dist" \
    "${user_checkout}/build" \
    "${outside}/build"
  touch \
    "${cmsmap_live}/build/generated.py" \
    "${cmsmap_live}/dist/generated.whl" \
    "${cmsmap_candidate}/build/generated.py" \
    "${cmsmap_candidate}/dist/generated.whl" \
    "${user_checkout}/build/keep" \
    "${outside}/build/keep"
  ln -s "${outside}" "${linked_candidate}"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${compat_dir}"

  cleanup_managed_python_build_artifacts \
    "${cmsmap_live}" "${cmsmap_live}" || \
    fail "live managed setuptools output was not cleaned" || return 1
  cleanup_managed_python_build_artifacts \
    "${cmsmap_candidate}" "${cmsmap_live}" || \
    fail "candidate managed setuptools output was not cleaned" || return 1
  [[ ! -e "${cmsmap_live}/build" && ! -e "${cmsmap_live}/dist" ]] || \
    fail "live managed setuptools output remains" || return 1
  [[ ! -e "${cmsmap_candidate}/build" && ! -e "${cmsmap_candidate}/dist" ]] || \
    fail "candidate managed setuptools output remains" || return 1

  if cleanup_managed_python_build_artifacts \
    "${user_checkout}" "${cmsmap_live}"; then
    fail "managed cleanup accepted an ordinary tool checkout" || return 1
  fi
  if cleanup_managed_python_build_artifacts \
    "${user_checkout}" "${user_checkout}"; then
    fail "managed cleanup accepted an arbitrary live directory" || return 1
  fi
  if cleanup_managed_python_build_artifacts \
    "${linked_candidate}" "${cmsmap_live}"; then
    fail "managed cleanup accepted a symlinked candidate" || return 1
  fi
  [[ -f "${user_checkout}/build/keep" && -f "${outside}/build/keep" ]] || \
    fail "rejected build content was modified" || return 1

  cmsmap_function="$(declare -f install_cmsmap)"
  drupwn_function="$(declare -f install_drupwn)"
  grep -Fq \
    "cleanup_managed_python_build_artifacts \"\${repo}\" \"\${managed_repo}\"" \
    <<<"${cmsmap_function}" || \
    fail "CMSmap install does not clean its managed pip source" || return 1
  grep -Fq \
    "cleanup_managed_python_build_artifacts \"\${candidate_src}\" \"\${build_src}\"" \
    <<<"${drupwn_function}" || \
    fail "Drupwn install does not clean its managed pip source" || return 1
}

test_canonical_venv_rejects_nested_foreign_owner() {
  local case_dir="${TEST_TMP}/canonical-venv-nested-owner"
  local fake_home="${case_dir}/home"
  local physical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local foreign_user=""
  local probe=""
  local current_user=""

  [[ "${EUID}" -eq 0 ]] || {
    skip_test "requires EUID 0 to construct a foreign-owned venv entry"
    return $?
  }
  foreign_user="$(find_non_root_account || true)"
  [[ -n "${foreign_user}" ]] || {
    skip_test "no non-root account is available for the foreign-owner fixture"
    return $?
  }
  command -v python3 >/dev/null 2>&1 || {
    skip_test "python3 is required to build the virtual-environment fixture"
    return $?
  }
  mkdir -p "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  python3 -m venv "${physical_venv}" || {
    skip_test "python3 venv support is unavailable"
    return $?
  }
  probe="${physical_venv}/nested-foreign-owner"
  : >"${probe}"
  chown "$(id -u "${foreign_user}"):$(id -g "${foreign_user}")" "${probe}"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  FAILED=()

  if ensure_canonical_venv; then
    fail "canonical venv accepted a nested foreign-owned file" || return 1
  fi
  [[ "${#FAILED[@]}" -eq 1 && "${FAILED[0]}" == *"not owned by"* ]] || \
    fail "nested foreign owner did not report the expected failure" || return 1
}

test_install_user_dir_rejects_writable_foreign_owner() {
  local user=""
  local case_dir="${TEST_TMP}/foreign-writable-dir"
  local fake_home="${case_dir}/home"
  local foreign_dir="${case_dir}/foreign"
  local before=""
  local after=""

  user="$(require_root_test_account)" || return $?
  mkdir -p "${fake_home}" "${foreign_dir}" "${case_dir}/bin" "${case_dir}/compat"
  chown -R "$(id -u "${user}"):$(id -g "${user}")" "${fake_home}"
  chown 0:0 "${foreign_dir}"
  chmod 0777 "${foreign_dir}"
  before="$(stat -c '%u:%g:%a' "${foreign_dir}")"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  if ensure_install_user_dir "${foreign_dir}"; then
    fail "writable foreign-owned directory was accepted" || return 1
  fi
  after="$(stat -c '%u:%g:%a' "${foreign_dir}")"
  assert_equal "${before}" "${after}" \
    "foreign directory metadata changed while being rejected" || return 1
}

test_install_user_dir_rejects_symlinked_home_ancestor() {
  local user=""
  local uid=""
  local gid=""
  local case_dir="${TEST_TMP}/install-dir-symlink-ancestor"
  local fake_home="${case_dir}/home"
  local external="${case_dir}/external"
  local managed_dir="${fake_home}/.local/share/vantage/cms_scanner"
  local external_managed_dir="${external}/cms_scanner"
  local before=""
  local after=""

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"

  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}/.local/share" "${external}" \
    "${case_dir}/bin" "${case_dir}/compat"
  chown -R "${uid}:${gid}" "${fake_home}"
  chown 0:0 "${external}"
  chmod 0755 "${external}"
  ln -s "${external}" "${fake_home}/.local/share/vantage"
  before="$(stat -c '%d:%i:%u:%g:%a' "${external}")"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  if ensure_install_user_dir "${managed_dir}"; then
    fail "install-user directory accepted a symlinked home ancestor" || return 1
  fi

  [[ ! -e "${external_managed_dir}" && ! -L "${external_managed_dir}" ]] || \
    fail "symlinked home ancestor caused external directory creation" || return 1
  after="$(stat -c '%d:%i:%u:%g:%a' "${external}")"
  assert_equal "${before}" "${after}" \
    "external directory metadata changed through the symlink" || return 1
}

test_install_user_dir_creates_in_root_owned_staged_project() {
  local user=""
  local uid=""
  local gid=""
  local case_dir="${TEST_TMP}/install-dir-staged-project"
  local fake_home="${case_dir}/home"
  local staged_project="${case_dir}/staged-project"
  local managed_dir="${staged_project}/generated"

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"

  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}" "${staged_project}" \
    "${case_dir}/bin" "${case_dir}/compat"
  chown "${uid}:${gid}" "${fake_home}"
  chown 0:0 "${staged_project}"
  chmod 0755 "${staged_project}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  SCRIPT_DIR="${staged_project}"
  ensure_install_user_dir "${managed_dir}" || \
    fail "root-owned staged project directory could not be prepared" || return 1
  assert_equal "${uid}:${gid}:755" \
    "$(stat -c '%u:%g:%a' "${managed_dir}")" \
    "staged project managed-directory metadata" || return 1
}

test_wpscan_repairs_root_owned_cookie() {
  local user=""
  local uid=""
  local gid=""
  local case_dir="${TEST_TMP}/wpscan-ownership"
  local fake_home="${case_dir}/home"
  local cookie="${fake_home}/.wpscan/cookie_jar.txt"
  local stale_cache="${fake_home}/.wpscan/cache/root-created.cache"
  local owner=""

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"

  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}/.wpscan/db" "${fake_home}/.wpscan/cache" \
    "${case_dir}/bin" "${case_dir}/compat"
  touch "${cookie}"
  printf '%s\n' 'stale-root-cache' >"${stale_cache}"
  chown -R "${uid}:${gid}" "${fake_home}"
  chmod 0700 "${fake_home}"
  chown 0:0 "${cookie}"
  chown "${uid}:0" "${stale_cache}"
  chmod 0644 "${cookie}" "${stale_cache}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  run_as_install_user true || \
    fail "unable to execute a command as non-root test account ${user}" || \
    return 1

  prepare_wpscan_state || \
    fail "prepare_wpscan_state did not repair the root-owned cookie" || \
    return 1

  owner="$(stat -c '%u:%g' "${cookie}")"
  assert_equal "${uid}:${gid}" "${owner}" \
    "WPScan cookie ownership was not repaired numerically" || return 1
  owner="$(stat -c '%u:%g' "${stale_cache}")"
  assert_equal "${uid}:${gid}" "${owner}" \
    "nested WPScan cache ownership was not repaired numerically" || return 1
  run_as_install_user test -w "${cookie}" || \
    fail "repaired WPScan cookie is not writable by ${user}" || return 1
  run_as_install_user test -w "${fake_home}/.wpscan/db" || \
    fail "WPScan db directory is not writable by ${user}" || return 1
  run_as_install_user test -w "${fake_home}/.wpscan/cache" || \
    fail "WPScan cache directory is not writable by ${user}" || return 1
  prepare_wpscan_state || \
    fail "prepare_wpscan_state was not idempotent after ownership repair" || \
    return 1
}

test_wpscan_rejects_cookie_symlink() {
  local case_dir="${TEST_TMP}/wpscan-symlink"
  local fake_home="${case_dir}/home"
  local cookie="${fake_home}/.wpscan/cookie_jar.txt"
  local target="${case_dir}/cookie-target"
  local before_stat=""
  local after_stat=""
  local before_content=""
  local after_content=""
  local current_user=""
  local rc=0

  mkdir -p "${fake_home}/.wpscan/db" "${fake_home}/.wpscan/cache" \
    "${case_dir}/bin" "${case_dir}/compat"
  printf '%s\n' 'do-not-change-this-target' >"${target}"
  chmod 0640 "${target}"
  ln -s "${target}" "${cookie}"
  before_stat="$(stat -c '%u:%g:%a:%s:%Y' "${target}")"
  before_content="$(<"${target}")"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  if prepare_wpscan_state; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "prepare_wpscan_state accepted a cookie symlink" || return 1
  [[ -L "${cookie}" ]] || \
    fail "prepare_wpscan_state removed or replaced the cookie symlink" || \
    return 1

  after_stat="$(stat -c '%u:%g:%a:%s:%Y' "${target}")"
  after_content="$(<"${target}")"
  assert_equal "${before_stat}" "${after_stat}" \
    "cookie symlink target metadata changed" || return 1
  assert_equal "${before_content}" "${after_content}" \
    "cookie symlink target content changed" || return 1
}

test_remove_previous_runtime_tree_handles_root_owned_file() {
  local user=""
  local uid=""
  local gid=""
  local case_dir="${TEST_TMP}/runtime-owned"
  local fake_home="${case_dir}/home"
  local compat_dir="${case_dir}/compat"
  local live_dir="${compat_dir}/clusterd-src"
  local previous="${live_dir}.old.41001"
  local blocked_dir="${previous}/src/__pycache__"
  local blocked_file="${blocked_dir}/module.pyc"

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"

  chmod 0755 "${TEST_TMP}"
  mkdir -p "${fake_home}" "${case_dir}/bin" "${live_dir}" "${blocked_dir}"
  printf '%s\n' 'root-owned-bytecode' >"${blocked_file}"
  chown -R "${uid}:${gid}" "${case_dir}"
  chmod 0755 "${case_dir}" "${compat_dir}" "${previous}" \
    "${previous}/src"
  chown 0:0 "${blocked_dir}" "${blocked_file}"
  chmod 0755 "${blocked_dir}"
  chmod 0644 "${blocked_file}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${compat_dir}"
  remove_previous_runtime_tree "${previous}" "${live_dir}" || \
    fail "failed to remove exact managed rollback tree" || return 1
  [[ ! -e "${previous}" && ! -L "${previous}" ]] || \
    fail "managed rollback tree still exists after removal" || return 1
}

test_remove_previous_runtime_tree_rejects_malformed_name() {
  local case_dir="${TEST_TMP}/runtime-malformed"
  local compat_dir="${case_dir}/compat"
  local live_dir="${compat_dir}/tool"
  local previous="${live_dir}.old.not-a-pid"
  local current_user=""
  local rc=0

  mkdir -p "${live_dir}" "${previous}"
  printf '%s\n' 'must-remain' >"${previous}/sentinel"
  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${case_dir}/home" "${case_dir}/bin" "${compat_dir}"

  if remove_previous_runtime_tree "${previous}" "${live_dir}"; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "malformed rollback name was accepted" || return 1
  [[ -f "${previous}/sentinel" ]] || \
    fail "malformed rollback path was modified" || return 1
}

test_remove_previous_runtime_tree_rejects_out_of_tree_path() {
  local case_dir="${TEST_TMP}/runtime-outside"
  local compat_dir="${case_dir}/compat"
  local outside_live="${case_dir}/outside/tool"
  local previous="${outside_live}.old.41002"
  local current_user=""
  local rc=0

  mkdir -p "${compat_dir}" "${outside_live}" "${previous}"
  printf '%s\n' 'must-remain' >"${previous}/sentinel"
  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${case_dir}/home" "${case_dir}/bin" "${compat_dir}"

  if remove_previous_runtime_tree "${previous}" "${outside_live}"; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "out-of-tree rollback path was accepted" || return 1
  [[ -f "${previous}/sentinel" ]] || \
    fail "out-of-tree rollback path was modified" || return 1
}

test_remove_previous_runtime_tree_rejects_symlink() {
  local case_dir="${TEST_TMP}/runtime-symlink"
  local compat_dir="${case_dir}/compat"
  local live_dir="${compat_dir}/tool"
  local previous="${live_dir}.old.41003"
  local target="${case_dir}/symlink-target"
  local current_user=""
  local rc=0

  mkdir -p "${live_dir}" "${target}"
  printf '%s\n' 'must-remain' >"${target}/sentinel"
  ln -s "${target}" "${previous}"
  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${case_dir}/home" "${case_dir}/bin" "${compat_dir}"

  if remove_previous_runtime_tree "${previous}" "${live_dir}"; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "rollback symlink was accepted" || return 1
  [[ -L "${previous}" ]] || \
    fail "rollback symlink was removed or replaced" || return 1
  [[ -f "${target}/sentinel" ]] || \
    fail "rollback symlink target was modified" || return 1
}

test_privileged_removal_rejects_intermediate_symlink() {
  local case_dir="${TEST_TMP}/runtime-intermediate-symlink"
  local trusted_root="${case_dir}/compat"
  local outside_parent="${case_dir}/outside"
  local outside_tree="${outside_parent}/tool.old.41004"
  local rc=0

  if [[ "${EUID}" -ne 0 ]]; then
    skip_test "requires EUID 0 to exercise isolated privileged removal"
    return $?
  fi

  mkdir -p "${trusted_root}" "${outside_tree}"
  printf '%s\n' 'must-remain' >"${outside_tree}/sentinel"
  ln -s "${outside_parent}" "${trusted_root}/redirect"

  if remove_managed_tree_privileged \
    "${trusted_root}" "redirect/tool.old.41004" >/dev/null 2>&1; then
    rc=0
  else
    rc=$?
  fi
  [[ "${rc}" -ne 0 ]] || \
    fail "descriptor-relative removal followed an intermediate symlink" || \
    return 1
  [[ -L "${trusted_root}/redirect" ]] || \
    fail "intermediate symlink was removed or replaced" || return 1
  [[ -f "${outside_tree}/sentinel" ]] || \
    fail "intermediate symlink target was modified" || return 1
}

assert_generated_wrapper_uses_numeric_aiuser_guard() {
  local wrapper="$1"
  local label="$2"
  local required=""

  for required in \
    '/usr/bin/getent passwd aiuser' \
    '/usr/bin/id -u' \
    '/usr/bin/cut -d: -f3' \
    '/usr/bin/cut -d: -f6' \
    '"${HOME:-}" != "${CANONICAL_HOME}"'; do
    grep -Fq "${required}" "${wrapper}" ||
      fail "${label} omitted numeric/passwd guard marker: ${required}" ||
      return 1
  done
  if grep -Eq '\$\((id|getent|cut)([[:space:]]|\))' "${wrapper}"; then
    fail "${label} retained a PATH-resolved identity command" || return 1
  fi
}

test_generated_tool_wrapper_requires_dispatched_aiuser() {
  local case_dir="${TEST_TMP}/generated-wrapper-root-guard"
  local marker="${case_dir}/backend-ran"
  local wrapper="${case_dir}/bin/root-guard-probe"
  local current_user=""
  local rc=0

  if [[ "${EUID}" -ne 0 ]]; then
    skip_test "requires EUID 0 to exercise the generated-wrapper identity guard"
    return $?
  fi

  mkdir -p "${case_dir}/home" "${case_dir}/bin" "${case_dir}/compat"
  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${case_dir}/home" "${case_dir}/bin" "${case_dir}/compat"
  create_wrapper \
    "root-guard-probe" \
    "printf '%s\\n' backend-ran >\"${marker}\"" || \
    fail "unable to generate root-guard wrapper fixture" || return 1
  assert_generated_wrapper_uses_numeric_aiuser_guard \
    "${wrapper}" "generated tool wrapper" || return 1
  grep -Fq \
    'CANONICAL_VENV="${CANONICAL_HOME}/.local/share/vantage/cms_scanner/venv"' \
    "${wrapper}" || \
    fail "generated tool wrapper omitted the CMS-scoped venv" || return 1
  grep -Fq 'export VIRTUAL_ENV="${CANONICAL_VENV}"' "${wrapper}" || \
    fail "generated tool wrapper does not activate the CMS-scoped venv" || \
    return 1

  if env -u SUDO_USER -u SUDO_UID -u SUDO_GID \
    "${wrapper}" scan >"${case_dir}/stdout" 2>"${case_dir}/stderr"; then
    rc=0
  else
    rc=$?
  fi
  assert_equal "77" "${rc}" \
    "generated wrapper root-refusal status" || return 1
  [[ ! -e "${marker}" ]] || \
    fail "generated wrapper invoked its backend as root" || return 1
  grep -Fq "must run as aiuser through the VANTAGE dispatcher" "${case_dir}/stderr" || \
    fail "generated wrapper omitted its fixed-identity diagnostic" || return 1

  if env -u SUDO_USER -u SUDO_UID -u SUDO_GID VANTAGE_DISPATCHED=1 \
    "${wrapper}" --help >/dev/null 2>&1; then
    fail "generated wrapper accepted a forged dispatcher marker from root" || return 1
  fi
  [[ ! -e "${marker}" ]] || \
    fail "generated wrapper invoked its backend outside dispatched aiuser" || return 1
}

test_generated_wpscan_wrapper_requires_dispatched_aiuser() {
  local case_dir="${TEST_TMP}/generated-wpscan-root-guard"
  local fake_home="${case_dir}/home"
  local fake_gem_bin="${case_dir}/gem-bin"
  local backend_marker="${case_dir}/wpscan-backend-ran"
  local wrapper="${case_dir}/bin/wpscan"
  local current_user=""
  local rc=0

  if [[ "${EUID}" -ne 0 ]]; then
    skip_test "requires EUID 0 to exercise the WPScan wrapper root guard"
    return $?
  fi

  mkdir -p \
    "${fake_home}" "${case_dir}/bin" "${case_dir}/compat" "${fake_gem_bin}"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "printf '%s\\n' backend-ran >\"${backend_marker}\"" \
    'exit 0' >"${fake_gem_bin}/wpscan"
  chmod 0755 "${fake_gem_bin}/wpscan"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  USER_GEM_BIN="${fake_gem_bin}"
  UPDATE_EXISTING=0
  RUN_SMOKE_TESTS=0
  INSTALLED=()
  SKIPPED=()
  FAILED=()
  WARNINGS=()
  UPDATE_SKIPPED=()
  # These globals are consumed dynamically by install_wpscan.
  : "${UPDATE_EXISTING}" "${RUN_SMOKE_TESTS}" "${SKIPPED[*]}" \
    "${WARNINGS[*]}" "${UPDATE_SKIPPED[*]}"
  ensure_ruby_runtime() { return 0; }

  install_wpscan
  assert_equal "1" "${#INSTALLED[@]}" \
    "generated WPScan wrapper installed count" || return 1
  assert_equal "0" "${#FAILED[@]}" \
    "generated WPScan wrapper failed count" || return 1
  [[ -x "${wrapper}" ]] || \
    fail "generated WPScan wrapper is missing" || return 1
  assert_generated_wrapper_uses_numeric_aiuser_guard \
    "${wrapper}" "generated WPScan wrapper" || return 1

  if env -u SUDO_USER -u SUDO_UID -u SUDO_GID \
    "${wrapper}" --update >"${case_dir}/stdout" 2>"${case_dir}/stderr"; then
    rc=0
  else
    rc=$?
  fi
  assert_equal "77" "${rc}" \
    "generated WPScan root-update refusal status" || return 1
  [[ ! -e "${backend_marker}" ]] || \
    fail "generated WPScan wrapper invoked its updater as root" || return 1
  grep -Fq "must run as aiuser inside a dispatched CMS scan" "${case_dir}/stderr" || \
    fail "generated WPScan wrapper omitted its fixed-identity diagnostic" || \
    return 1
}

test_legacy_project_venvs_cleanup_is_narrow() {
  local case_dir="${TEST_TMP}/legacy-project-venvs"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local canonical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local current_user=""

  mkdir -p \
    "${canonical_venv}" \
    "${project_root}/.venvs/cmseek/bin" \
    "${project_root}/.venvs/drupwn/bin" \
    "${project_root}/logs" \
    "${project_root}/reports" \
    "${project_root}/tools/.compat"
  printf 'canonical\n' >"${canonical_venv}/keep.marker"
  printf 'home = /usr/bin\n' >"${project_root}/.venvs/cmseek/pyvenv.cfg"
  printf 'home = /usr/bin\n' >"${project_root}/.venvs/drupwn/pyvenv.cfg"
  printf 'evidence\n' >"${project_root}/logs/keep.log"
  printf 'evidence\n' >"${project_root}/reports/keep.html"
  printf 'runtime\n' >"${project_root}/tools/.compat/keep.py"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  VENV_DIR="${canonical_venv}"

  cleanup_legacy_project_venvs "${project_root}" || \
    fail "recognized project-local virtual environments were not removed" || \
    return 1
  [[ ! -e "${project_root}/.venvs" ]] || \
    fail "legacy project-local .venvs directory remains" || return 1
  [[ -f "${canonical_venv}/keep.marker" ]] || \
    fail "canonical shared virtual environment was modified" || return 1
  [[ -f "${project_root}/logs/keep.log" ]] || \
    fail "scanner logs were modified" || return 1
  [[ -f "${project_root}/reports/keep.html" ]] || \
    fail "scanner reports were modified" || return 1
  [[ -f "${project_root}/tools/.compat/keep.py" ]] || \
    fail "required compatibility source was modified" || return 1
}

test_legacy_partial_droopescan_venv_cleanup_is_narrow() {
  local case_dir="${TEST_TMP}/legacy-partial-droopescan-venv"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local canonical_venv="${fake_home}/.local/share/vantage/cms_scanner/venv"
  local site_packages="${project_root}/.venvs/droopescan/lib/python3.11/site-packages"
  local current_user=""

  mkdir -p \
    "${canonical_venv}" \
    "${site_packages}/legacy_package" \
    "${project_root}/logs" \
    "${project_root}/reports"
  printf 'canonical\n' >"${canonical_venv}/keep.marker"
  printf 'legacy package\n' >"${site_packages}/legacy_package/__init__.py"
  printf 'evidence\n' >"${project_root}/logs/keep.log"
  printf 'evidence\n' >"${project_root}/reports/keep.html"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  VENV_DIR="${canonical_venv}"

  cleanup_legacy_project_venvs "${project_root}" || \
    fail "safe partial Droopescan virtual environment was not removed" || \
    return 1
  [[ ! -e "${project_root}/.venvs" ]] || \
    fail "safe partial Droopescan .venvs tree remains" || return 1
  [[ -f "${canonical_venv}/keep.marker" ]] || \
    fail "canonical shared virtual environment was modified" || return 1
  [[ -f "${project_root}/logs/keep.log" ]] || \
    fail "scanner logs were modified" || return 1
  [[ -f "${project_root}/reports/keep.html" ]] || \
    fail "scanner reports were modified" || return 1
}

test_legacy_partial_droopescan_venv_rejects_empty_site_packages() {
  local case_dir="${TEST_TMP}/legacy-partial-droopescan-empty"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local site_packages="${project_root}/.venvs/droopescan/lib/python3.11/site-packages"
  local current_user=""

  mkdir -p "${fake_home}/.local/share/vantage/cms_scanner/venv" "${site_packages}"
  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"

  if cleanup_legacy_project_venvs "${project_root}"; then
    fail "legacy cleanup accepted empty partial Droopescan site-packages" || \
      return 1
  fi
  [[ -d "${site_packages}" ]] || \
    fail "empty partial Droopescan tree was modified" || return 1
}

test_legacy_partial_droopescan_venv_rejects_symlink() {
  local case_dir="${TEST_TMP}/legacy-partial-droopescan-symlink"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local python_lib="${project_root}/.venvs/droopescan/lib/python3.11"
  local outside_packages="${case_dir}/outside-site-packages"
  local current_user=""

  mkdir -p "${fake_home}/.local/share/vantage/cms_scanner/venv" \
    "${python_lib}" "${outside_packages}"
  printf 'outside\n' >"${outside_packages}/keep.marker"
  ln -s "${outside_packages}" "${python_lib}/site-packages"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"

  if cleanup_legacy_project_venvs "${project_root}"; then
    fail "legacy cleanup accepted a symlinked partial site-packages tree" || \
      return 1
  fi
  [[ -L "${python_lib}/site-packages" ]] || \
    fail "partial Droopescan site-packages symlink was removed" || return 1
  [[ -f "${outside_packages}/keep.marker" ]] || \
    fail "partial Droopescan symlink target was modified" || return 1
}

test_legacy_partial_droopescan_venv_rejects_unexpected_sibling() {
  local case_dir="${TEST_TMP}/legacy-partial-droopescan-sibling"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local partial_root="${project_root}/.venvs/droopescan"
  local site_packages="${partial_root}/lib/python3.11/site-packages"
  local current_user=""

  mkdir -p "${fake_home}/.local/share/vantage/cms_scanner/venv" \
    "${site_packages}" "${partial_root}/bin"
  printf 'legacy package\n' >"${site_packages}/keep.marker"
  printf 'unexpected\n' >"${partial_root}/bin/unexpected"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"

  if cleanup_legacy_project_venvs "${project_root}"; then
    fail "legacy cleanup accepted an unexpected partial-venv sibling" || \
      return 1
  fi
  [[ -f "${site_packages}/keep.marker" ]] || \
    fail "recognized partial Droopescan content was partially removed" || return 1
  [[ -f "${partial_root}/bin/unexpected" ]] || \
    fail "unexpected partial-venv sibling was removed" || return 1
}

test_legacy_partial_droopescan_venv_rejects_foreign_owner() {
  local case_dir="${TEST_TMP}/legacy-partial-droopescan-foreign-owner"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local site_packages="${project_root}/.venvs/droopescan/lib/python3.11/site-packages"
  local foreign_file="${site_packages}/foreign.marker"
  local user=""
  local uid=""
  local gid=""
  local cleanup_rc=0

  user="$(require_root_test_account)" || return $?
  uid="$(id -u "${user}")"
  gid="$(id -g "${user}")"
  mkdir -p "${fake_home}/.local/share/vantage/cms_scanner/venv" "${site_packages}"
  printf 'foreign\n' >"${foreign_file}"
  chown -R "${uid}:${gid}" "${case_dir}"
  chown 0:0 "${foreign_file}"
  chmod 0711 "${TEST_TMP}" "${case_dir}"

  configure_install_context \
    "${user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"
  if cleanup_legacy_project_venvs "${project_root}"; then
    cleanup_rc=0
  else
    cleanup_rc=$?
  fi
  chmod 0700 "${TEST_TMP}"

  [[ "${cleanup_rc}" -ne 0 ]] || \
    fail "legacy cleanup accepted foreign-owned partial-venv content" || \
    return 1
  [[ -f "${foreign_file}" ]] || \
    fail "foreign-owned partial-venv content was removed" || return 1
  assert_equal "0:0" "$(stat -c '%u:%g' "${foreign_file}")" \
    "foreign-owned partial-venv marker ownership" || return 1
}

test_legacy_project_venvs_cleanup_rejects_unknown_content() {
  local case_dir="${TEST_TMP}/legacy-project-venvs-unknown"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local current_user=""

  mkdir -p "${fake_home}/.local/share/vantage/cms_scanner/venv" \
    "${project_root}/.venvs"
  printf 'user data\n' >"${project_root}/.venvs/notes.txt"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"

  if cleanup_legacy_project_venvs "${project_root}"; then
    fail "legacy cleanup accepted unrecognized .venvs content" || return 1
  fi
  [[ -f "${project_root}/.venvs/notes.txt" ]] || \
    fail "unrecognized .venvs content was removed" || return 1
}

test_git_index_conflict_cleanup_is_exact() {
  local case_dir="${TEST_TMP}/git-index-conflicts"
  local fake_home="${case_dir}/home"
  local project_root="${case_dir}/cms-scanner"
  local root_sidecar="${project_root}/.git/index (host's conflicted copy 2026-07-30)"
  local tool_sidecar="${project_root}/tools/tool-a/.git/index (host's conflicted copy 2026-07-30)"
  local module_sidecar="${project_root}/tools/tool-a/.git/modules/plugin/index (host's conflicted copy 2026-07-30)"
  local current_user=""

  mkdir -p \
    "${fake_home}/.local/share/vantage/cms_scanner/venv" \
    "${project_root}/.git/objects" \
    "${project_root}/tools/tool-a/.git/modules/plugin"
  printf 'canonical\n' >"${project_root}/.git/index"
  printf 'canonical\n' >"${project_root}/tools/tool-a/.git/index"
  printf 'canonical\n' >"${project_root}/tools/tool-a/.git/modules/plugin/index"
  printf 'sidecar\n' >"${root_sidecar}"
  printf 'sidecar\n' >"${tool_sidecar}"
  printf 'sidecar\n' >"${module_sidecar}"
  printf 'lock\n' >"${project_root}/.git/index.lock"
  printf 'object\n' >"${project_root}/.git/objects/keep"
  printf 'other\n' >"${project_root}/.git/index (manual backup)"

  current_user="$(id -un)"
  configure_install_context \
    "${current_user}" "${fake_home}" "${case_dir}/bin" "${case_dir}/compat"

  cleanup_git_index_conflict_sidecars "${project_root}" || \
    fail "exact Git-index sidecar cleanup failed" || return 1
  [[ ! -e "${root_sidecar}" && ! -e "${tool_sidecar}" && ! -e "${module_sidecar}" ]] || \
    fail "one or more exact conflict sidecars remain" || return 1
  [[ -f "${project_root}/.git/index" ]] || \
    fail "canonical Git index was removed" || return 1
  [[ -f "${project_root}/tools/tool-a/.git/index" ]] || \
    fail "nested canonical Git index was removed" || return 1
  [[ -f "${project_root}/.git/index.lock" ]] || \
    fail "Git index.lock was removed" || return 1
  [[ -f "${project_root}/.git/objects/keep" ]] || \
    fail "Git object data was removed" || return 1
  [[ -f "${project_root}/.git/index (manual backup)" ]] || \
    fail "non-matching Git metadata was removed" || return 1
}

run_test \
  "command lookup preserves installer BIN_DIR" \
  test_command_resolution_preserves_injected_path
run_test \
  "canonical venv accepts a safe user-owned symlink" \
  test_canonical_venv_accepts_safe_user_symlink
run_test \
  "canonical venv accepts private-primary-group write" \
  test_canonical_venv_accepts_private_group_writable_target
run_test \
  "canonical venv repairs stale root-owned entries" \
  test_canonical_venv_repairs_root_owned_entries
run_test \
  "canonical venv repair preflight is atomic on foreign ownership" \
  test_canonical_venv_repair_preflight_is_atomic
run_test \
  "canonical venv repair rejects external hardlinks" \
  test_canonical_venv_repair_rejects_external_hardlink
run_test \
  "CMS install identity ignores frozen caller values" \
  test_install_identity_ignores_frozen_caller_values
run_test \
  "canonical venv rejects world write" \
  test_canonical_venv_rejects_world_writable_target
run_test \
  "canonical venv rejects foreign-group write" \
  test_canonical_venv_rejects_foreign_group_writable_target
run_test \
  "canonical venv rejects nested world write" \
  test_canonical_venv_rejects_nested_world_writable_entry
run_test \
  "canonical venv rejects a nested world-writable directory" \
  test_canonical_venv_rejects_nested_world_writable_directory
run_test \
  "scanner pip updates preserve compatible shared dependency bounds" \
  test_shared_environment_constraints_preserve_compatible_bounds
run_test \
  "managed Python build cleanup is narrow and producer-wired" \
  test_managed_python_build_cleanup_is_narrow
run_test \
  "canonical venv rejects nested foreign ownership" \
  test_canonical_venv_rejects_nested_foreign_owner
run_test \
  "install-user directory rejects writable foreign ownership" \
  test_install_user_dir_rejects_writable_foreign_owner
run_test \
  "install-user directory rejects a symlinked home ancestor" \
  test_install_user_dir_rejects_symlinked_home_ancestor
run_test \
  "install-user directory supports a root-owned staged project" \
  test_install_user_dir_creates_in_root_owned_staged_project
run_test \
  "WPScan state repairs a root-owned cookie" \
  test_wpscan_repairs_root_owned_cookie
run_test \
  "WPScan state rejects a cookie symlink" \
  test_wpscan_rejects_cookie_symlink
run_test \
  "managed rollback removal handles root-owned bytecode" \
  test_remove_previous_runtime_tree_handles_root_owned_file
run_test \
  "rollback removal rejects malformed names" \
  test_remove_previous_runtime_tree_rejects_malformed_name
run_test \
  "rollback removal rejects out-of-tree paths" \
  test_remove_previous_runtime_tree_rejects_out_of_tree_path
run_test \
  "rollback removal rejects symlinks" \
  test_remove_previous_runtime_tree_rejects_symlink
run_test \
  "privileged removal rejects intermediate symlinks" \
  test_privileged_removal_rejects_intermediate_symlink
run_test \
  "generated tool wrapper requires dispatched aiuser" \
  test_generated_tool_wrapper_requires_dispatched_aiuser
run_test \
  "generated WPScan wrapper requires dispatched aiuser" \
  test_generated_wpscan_wrapper_requires_dispatched_aiuser
run_test \
  "legacy project venv cleanup preserves canonical state and evidence" \
  test_legacy_project_venvs_cleanup_is_narrow
run_test \
  "legacy project venv cleanup accepts a safe partial Droopescan remnant" \
  test_legacy_partial_droopescan_venv_cleanup_is_narrow
run_test \
  "legacy project venv cleanup rejects empty partial site-packages" \
  test_legacy_partial_droopescan_venv_rejects_empty_site_packages
run_test \
  "legacy project venv cleanup rejects partial-venv symlinks" \
  test_legacy_partial_droopescan_venv_rejects_symlink
run_test \
  "legacy project venv cleanup rejects unexpected partial-venv siblings" \
  test_legacy_partial_droopescan_venv_rejects_unexpected_sibling
run_test \
  "legacy project venv cleanup rejects foreign ownership" \
  test_legacy_partial_droopescan_venv_rejects_foreign_owner
run_test \
  "legacy project venv cleanup rejects unrecognized content" \
  test_legacy_project_venvs_cleanup_rejects_unknown_content
run_test \
  "Git index conflict cleanup removes only exact Dropbox sidecars" \
  test_git_index_conflict_cleanup_is_exact

printf '\nRESULT: %d passed, %d skipped, %d failed\n' \
  "${PASS_COUNT}" "${SKIP_COUNT}" "${FAIL_COUNT}"
[[ "${FAIL_COUNT}" -eq 0 ]]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
