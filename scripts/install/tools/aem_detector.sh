#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_aem_detector() {
  local name="AEM Detector"
  local repo="${TOOLS_DIR}/aem-hacker"
  local wrapper_repo=""
  local venv="${VENV_DIR}"

  if ! repo_clone_or_update https://github.com/0ang3el/aem-hacker.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  wrapper_repo="${EFFECTIVE_WRAPPER_REPO_DIR}"
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  if [[ ! -f "${repo}/aem_hacker.py" || ! -f "${repo}/aem_discoverer.py" ]] || \
    ! run_user_cmd "${venv}/bin/python" -m py_compile \
      "${repo}/aem_hacker.py" "${repo}/aem_discoverer.py" || \
    ! tool_smoke_test "$name" "${venv}/bin/python" "${repo}/aem_hacker.py" --help || \
    ! tool_smoke_test "AEM Discoverer" "${venv}/bin/python" "${repo}/aem_discoverer.py" --help; then
    mark_failed "$name" "entrypoint validation failed"
    return 0
  fi
  local detector_body=""
  if ! detector_body="$(cms_aem_detector_wrapper_body "${wrapper_repo}")"; then
    mark_failed "$name" "unable to prepare the read-only detector adapter"
    return 0
  fi
  if ! create_wrapper_pair \
    "aem-hacker" "${detector_body}" \
    "aem-discoverer" "exec \"\${CANONICAL_PYTHON}\" \"${wrapper_repo}/aem_discoverer.py\" \"\$@\""; then
    mark_failed "$name" "unable to create executable wrappers"
    return 0
  fi
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
