#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_vbscan() {
  local name="VBScan"
  local repo="${TOOLS_DIR}/vbscan"
  local wrapper_repo=""
  if ! ensure_perl_runtime; then
    mark_failed "$name" "perl runtime unavailable"
    return 0
  fi
  if ! repo_clone_or_update https://github.com/OWASP/vbscan.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  wrapper_repo="${EFFECTIVE_WRAPPER_REPO_DIR}"
  if [[ ! -f "${repo}/vbscan.pl" ]] || ! run_user_cmd perl -c "${repo}/vbscan.pl"; then
    mark_failed "$name" "vbscan.pl is missing or failed Perl syntax validation"
    return 0
  fi
  if ! create_wrapper "vbscan" "exec perl \"${wrapper_repo}/vbscan.pl\" \"\$@\""; then
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
