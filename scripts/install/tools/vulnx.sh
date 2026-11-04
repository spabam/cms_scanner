#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_vulnx() {
  local name="VulnX"
  local repo="${TOOLS_DIR}/vulnx"
  local runtime_src="${COMPAT_DIR}/vulnx-src"
  local candidate_src=""
  local previous_src=""
  local venv="${VENV_DIR}"

  if ! repo_clone_or_update https://github.com/anouarbensaad/vulnx.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  if ! prepare_runtime_candidate "${repo}" "${runtime_src}"; then
    mark_failed "$name" "unable to prepare staged runtime source"
    return 0
  fi
  candidate_src="${RUNTIME_CANDIDATE}"

  if [[ ! -f "${candidate_src}/modules/detector.py" ]]; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "detector.py not found in staged runtime"
    return 0
  fi
  if [[ ! -f "${SCRIPTS_DIR}/patch_vulnx_detector.py" ]] || \
    ! run_user_cmd "${venv}/bin/python" "${SCRIPTS_DIR}/patch_vulnx_detector.py" \
      "${candidate_src}/modules/detector.py"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "failed to patch safe HTTP fetch handling"
    return 0
  fi

  if ! run_user_cmd "${venv}/bin/python" -m py_compile \
    "${candidate_src}/modules/detector.py" "${candidate_src}/vulnx.py"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "staged runtime validation failed"
    return 0
  fi
  # shellcheck disable=SC2016 # Positional parameters expand in the inner bash.
  if [[ "${RUN_SMOKE_TESTS}" -eq 1 ]] && \
    ! run_user_cmd bash -c 'cd "$1" && exec "$2" "$1/vulnx.py" --help' \
      _ "${candidate_src}" "${venv}/bin/python"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "Smoke test failed"
    return 0
  fi
  if ! activate_runtime_candidate "${candidate_src}" "${runtime_src}"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to activate staged runtime"
    return 0
  fi
  previous_src="${RUNTIME_PREVIOUS}"
  if ! create_wrapper "vulnx" "cd \"${runtime_src}\" && exec \"\${CANONICAL_PYTHON}\" \"${runtime_src}/vulnx.py\" \"\$@\""; then
    rollback_runtime_activation "${previous_src}" "${runtime_src}" || \
      warn "${name}: wrapper creation failed and runtime rollback was unavailable"
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  finalize_runtime_activation "${previous_src}" "${runtime_src}" || \
    warn "${name}: previous runtime remains at ${previous_src}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
