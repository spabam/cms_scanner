#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_wpseku() {
  local name="WPSeku"
  local repo="${TOOLS_DIR}/WPSeku"
  local wrapper_repo=""
  local venv="${VENV_DIR}"

  if ! repo_clone_or_update https://github.com/andripwn/WPSeku.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  wrapper_repo="${EFFECTIVE_WRAPPER_REPO_DIR}"
  if ! cms_repair_wpseku_json "${repo}"; then
    mark_failed "$name" "unsupported JSON parser; upstream source preserved"
    return 0
  fi
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  if [[ ! -f "${repo}/wpseku.py" ]] || \
    ! run_user_cmd env PYTHONWARNINGS=ignore::SyntaxWarning \
      "${venv}/bin/python" -m py_compile "${repo}/wpseku.py" || \
    ! tool_smoke_test "$name" env PYTHONWARNINGS=ignore::SyntaxWarning \
      "${venv}/bin/python" "${repo}/wpseku.py" --help; then
    mark_failed "$name" "entrypoint validation failed"
    return 0
  fi
  if ! create_wrapper "wpseku" \
    "exec env PYTHONWARNINGS=ignore::SyntaxWarning \"\${CANONICAL_PYTHON}\" \"${wrapper_repo}/wpseku.py\" \"\$@\""; then
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
