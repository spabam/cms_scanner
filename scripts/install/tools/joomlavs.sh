#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_joomlavs() {
  local name="joomlavs"
  local repo="${TOOLS_DIR}/joomlavs"
  local wrapper_repo=""
  local gem_user_dir=""
  local -a gem_args=(install --user-install)

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby runtime unavailable"
    return 0
  fi
  if ! repo_clone_or_update https://github.com/rastating/joomlavs.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  wrapper_repo="${EFFECTIVE_WRAPPER_REPO_DIR}"
  if [[ "${UPDATE_EXISTING}" -eq 0 ]]; then
    gem_args+=(--conservative)
  fi
  if ! run_user_cmd gem "${gem_args[@]}" colorize slop typhoeus; then
    mark_failed "$name" "required gems installation failed"
    return 0
  fi
  if [[ -n "${USER_GEM_BIN}" ]]; then
    gem_user_dir="${USER_GEM_BIN%/bin}"
  fi

  if [[ ! -f "${repo}/joomlavs.rb" ]] || ! run_user_cmd ruby -c "${repo}/joomlavs.rb"; then
    mark_failed "$name" "joomlavs.rb is missing or failed Ruby syntax validation"
    return 0
  fi
  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    if ! run_user_shell "cd \"$repo\" && ruby joomlavs.rb >/dev/null"; then
      mark_failed "$name" "smoke test failed"
      return 0
    fi
  fi
  if [[ -n "${gem_user_dir}" ]]; then
    if ! create_wrapper "joomlavs" "cd \"${wrapper_repo}\" && exec env HOME=\"${INSTALL_HOME}\" GEM_HOME=\"${gem_user_dir}\" GEM_PATH=\"${gem_user_dir}:\${GEM_PATH:-}\" ruby joomlavs.rb \"\$@\""; then
      mark_failed "$name" "unable to create executable wrapper"
      return 0
    fi
  else
    if ! create_wrapper "joomlavs" "cd \"${wrapper_repo}\" && exec ruby joomlavs.rb \"\$@\""; then
      mark_failed "$name" "unable to create executable wrapper"
      return 0
    fi
  fi
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
