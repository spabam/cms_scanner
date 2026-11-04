#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_joomscan() {
  local name="JoomScan"
  local repo="${TOOLS_DIR}/joomscan"
  local wrapper_repo=""
  if ! ensure_perl_runtime; then
    mark_failed "$name" "perl runtime unavailable"
    return 0
  fi
  if ! repo_clone_or_update https://github.com/OWASP/joomscan.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  wrapper_repo="${EFFECTIVE_WRAPPER_REPO_DIR}"
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    local out
    out="$(capture_user_cmd bash -lc "cd \"$repo\" && perl \"${repo}/joomscan.pl\" --help" 2>&1 || true)"
    append_text_to_log "$out"
    if ! printf '%s' "$out" | grep -qi "Usage"; then
      mark_failed "$name" "unexpected help output"
      return 0
    fi
  fi
  if ! create_wrapper "joomscan" "cd \"${wrapper_repo}\" && exec perl \"${wrapper_repo}/joomscan.pl\" \"\$@\""; then
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
