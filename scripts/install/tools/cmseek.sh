#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_cmseek() {
  local name="CMSeek"
  local repo="${TOOLS_DIR}/CMSeeK"
  local wrapper_repo=""
  local venv="${VENV_DIR}"

  if ! repo_clone_or_update https://github.com/Tuhinshubhra/CMSeeK.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  wrapper_repo="${EFFECTIVE_WRAPPER_REPO_DIR}"
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  if ! tool_smoke_test "$name" env PYTHONWARNINGS=ignore::SyntaxWarning \
    "${venv}/bin/python" "${repo}/cmseek.py" --help; then
    mark_failed "$name" "smoke test failed"
    return 0
  fi
  if ! create_wrapper "cmseek" \
    "exec env PYTHONWARNINGS=ignore::SyntaxWarning \"\${CANONICAL_PYTHON}\" \"${wrapper_repo}/cmseek.py\" \"\$@\""; then
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
