#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_wpforce() {
  local name="WPForce"
  local repo="${TOOLS_DIR}/WPForce"
  local venv="${VENV_DIR}"
  local compat_script="${COMPAT_DIR}/wpforce.py"
  local candidate_script=""
  local previous_script="${compat_script}.old.$$"
  local failed_script="${compat_script}.failed.$$"
  if ! repo_clone_or_update https://github.com/n00py/WPForce.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"

  if ! run_user_cmd mkdir -p "${COMPAT_DIR}"; then
    mark_failed "$name" "unable to create compatibility source directory"
    return 0
  fi
  if ! scanner_pip_install modernize six; then
    mark_failed "$name" "python3 compatibility tooling install failed"
    return 0
  fi
  candidate_script="$(capture_user_cmd mktemp "${compat_script}.new.XXXXXX" 2>/dev/null || true)"
  [[ -z "${candidate_script}" ]] || vantage_register_temp_path "${candidate_script}" || return 1
  case "${candidate_script}" in
    "${compat_script}.new."*) ;;
    *)
      mark_failed "$name" "unable to create compatibility candidate"
      return 0
      ;;
  esac
  if ! run_user_cmd cp "${repo}/wpforce.py" "${candidate_script}"; then
    run_user_cmd rm -f "${candidate_script}" || true
    mark_failed "$name" "unable to stage wpforce.py for conversion"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/modernize" --no-diffs -w -n -f default "${candidate_script}"; then
    run_user_cmd rm -f "${candidate_script}" || true
    mark_failed "$name" "auto-conversion to python3 failed"
    return 0
  fi
  if ! run_user_cmd env COMPAT_SCRIPT="${candidate_script}" "${venv}/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["COMPAT_SCRIPT"])
text = path.read_text(encoding="utf-8", errors="ignore")

# Python3 integer division compatibility.
text = text.replace("slice_size = input_size / size", "slice_size = input_size // size")

# urllib.request expects bytes payload in Python3.
text = text.replace(
    "req = six.moves.urllib.request.Request(url, post, headers)",
    "req = six.moves.urllib.request.Request(url, post.encode('utf-8'), headers)"
)

path.write_text(text, encoding="utf-8")
PY
  then
    run_user_cmd rm -f "${candidate_script}" || true
    mark_failed "$name" "unable to apply python3 runtime compatibility patch"
    return 0
  fi
  if ! scanner_pip_install requests six; then
    run_user_cmd rm -f "${candidate_script}" || true
    mark_failed "$name" "python3 runtime dependencies install failed"
    return 0
  fi

  if ! run_user_cmd "${venv}/bin/python" -m py_compile "${candidate_script}"; then
    run_user_cmd rm -f "${candidate_script}" || true
    mark_failed "$name" "converted runtime validation failed"
    return 0
  fi
  if [[ "${RUN_SMOKE_TESTS}" -eq 1 ]] && \
    ! tool_smoke_test "$name" env PYTHONWARNINGS=ignore::SyntaxWarning \
      "${venv}/bin/python" "${candidate_script}" -h; then
    run_user_cmd rm -f "${candidate_script}" || true
    return 0
  fi

  if [[ -e "${compat_script}" || -L "${compat_script}" ]]; then
    if [[ -e "${previous_script}" ]] || ! run_user_cmd mv "${compat_script}" "${previous_script}"; then
      run_user_cmd rm -f "${candidate_script}" || true
      mark_failed "$name" "unable to preserve previous compatibility runtime"
      return 0
    fi
  else
    previous_script=""
  fi
  if ! run_user_cmd mv "${candidate_script}" "${compat_script}"; then
    [[ -z "${previous_script}" ]] || run_user_cmd mv "${previous_script}" "${compat_script}" || true
    mark_failed "$name" "unable to activate compatibility runtime"
    return 0
  fi
  if ! create_wrapper "wpforce" "exec env PYTHONWARNINGS=ignore::SyntaxWarning \"\${CANONICAL_PYTHON}\" \"${compat_script}\" \"\$@\""; then
    if [[ -n "${previous_script}" && ! -e "${failed_script}" ]] && \
      run_user_cmd mv "${compat_script}" "${failed_script}" && \
      run_user_cmd mv "${previous_script}" "${compat_script}"; then
      run_user_cmd rm -f "${failed_script}" || true
    else
      warn "${name}: wrapper creation failed and runtime rollback was unavailable"
    fi
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  [[ -z "${previous_script}" ]] || run_user_cmd rm -f "${previous_script}" || \
    warn "${name}: previous runtime remains at ${previous_script}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
