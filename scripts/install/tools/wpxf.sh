#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_wpxf() {
  local name="WPXF"
  local wpxf_path=""
  local gem_user_dir=""
  local candidate=""
  local wrapper_ok=0

  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby/gem runtime unavailable"
    return 0
  fi
  if ! install_or_update_user_gem "$name" wpxf; then
    mark_failed "$name" "gem install/update failed"
    return 0
  fi

  prepare_env
  if [[ -n "${USER_GEM_BIN}" && -x "${USER_GEM_BIN}/wpxf" ]]; then
    wpxf_path="${USER_GEM_BIN}/wpxf"
  fi
  if [[ -z "${wpxf_path}" ]]; then
    for candidate in "${INSTALL_HOME}"/.local/share/gem/ruby/*/bin/wpxf /usr/local/bin/wpxf /usr/bin/wpxf; do
      [[ -x "${candidate}" ]] || continue
      [[ "$(readlink -f "${candidate}" 2>/dev/null || printf '%s' "${candidate}")" == "$(readlink -f "${BIN_DIR}/wpxf" 2>/dev/null || true)" ]] && continue
      wpxf_path="${candidate}"
      break
    done
  fi
  if [[ -n "${USER_GEM_BIN}" ]]; then
    gem_user_dir="${USER_GEM_BIN%/bin}"
  fi
  if [[ -n "${wpxf_path}" && "${wpxf_path}" != "${BIN_DIR}/wpxf" ]]; then
    if [[ -n "${gem_user_dir}" && "${wpxf_path}" == "${USER_GEM_BIN}/"* ]]; then
      if ! tool_smoke_test "$name" env HOME="${INSTALL_HOME}" GEM_HOME="${gem_user_dir}" \
        GEM_PATH="${gem_user_dir}:${GEM_PATH:-}" "${wpxf_path}" --version; then
        mark_failed "$name" "post-update smoke test failed"
        return 0
      fi
    elif ! tool_smoke_test "$name" "${wpxf_path}" --version; then
      mark_failed "$name" "post-update smoke test failed"
      return 0
    fi
  fi
  if [[ -n "${wpxf_path}" && "${wpxf_path}" != "${BIN_DIR}/wpxf" ]]; then
    if [[ -n "${gem_user_dir}" && "${wpxf_path}" == "${USER_GEM_BIN}/"* ]]; then
      if create_wrapper "wpxf" "exec env HOME=\"${INSTALL_HOME}\" GEM_HOME=\"${gem_user_dir}\" GEM_PATH=\"${gem_user_dir}:\${GEM_PATH:-}\" \"${wpxf_path}\" \"\$@\""; then
        wrapper_ok=1
      fi
    else
      if create_wrapper "wpxf" "exec \"${wpxf_path}\" \"\$@\""; then
        wrapper_ok=1
      fi
    fi
  fi

  if [[ "${wrapper_ok}" -eq 1 && -x "${BIN_DIR}/wpxf" ]]; then
    mark_installed "$name"
  else
    mark_failed "$name" "command or executable wrapper unavailable after gem install"
  fi
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
