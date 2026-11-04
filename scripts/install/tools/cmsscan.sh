#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_cmsscan() {
  local name="CMSScan"
  local repo="${TOOLS_DIR}/CMSScan"
  local runtime_src="${COMPAT_DIR}/cmsscan-src"
  local candidate_src=""
  local previous_src=""
  local venv="${VENV_DIR}"

  if ! repo_clone_or_update https://github.com/ajinabraham/CMSScan.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi
  ensure_py312_compat_shims "$venv"

  # CMSScan's pinned submodules lag the standalone JoomScan/VBScan checkouts,
  # and its native setup script advances them by dirtying the parent checkout.
  # Use a staged runtime configured for the separately managed, updated tools.
  if ! prepare_runtime_candidate "${repo}" "${runtime_src}"; then
    mark_failed "$name" "unable to prepare staged runtime source"
    return 0
  fi
  candidate_src="${RUNTIME_CANDIDATE}"
  if [[ ! -f "${candidate_src}/plugins/scanners.py" ]] || \
    ! run_user_cmd sed -i \
      's/^USE_PREINSTALLED_TOOLS = False$/USE_PREINSTALLED_TOOLS = True/' \
      "${candidate_src}/plugins/scanners.py" || \
    ! capture_user_cmd grep -Eq '^USE_PREINSTALLED_TOOLS = True$' \
      "${candidate_src}/plugins/scanners.py"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to configure updated standalone scanner tools"
    return 0
  fi
  if ! run_user_cmd "${venv}/bin/python" -m py_compile \
    "${candidate_src}/app.py" "${candidate_src}/plugins/scanners.py" || \
    ! run_user_cmd env CMSSCAN_RUNTIME="${candidate_src}" "${venv}/bin/python" - <<'PY'
import os
import sys

runtime = os.environ["CMSSCAN_RUNTIME"]
sys.path.insert(0, runtime)
from plugins import scanners

assert scanners.USE_PREINSTALLED_TOOLS is True
PY
  then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "staged runtime validation failed"
    return 0
  fi

  if ! activate_runtime_candidate "${candidate_src}" "${runtime_src}"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to activate staged runtime"
    return 0
  fi
  previous_src="${RUNTIME_PREVIOUS}"

  if ! create_wrapper_pair \
    "cmsscan-server" "$(cms_cmsscan_server_wrapper_body "${runtime_src}")" \
    "cmsscan-python" "exec \"\${CANONICAL_PYTHON}\" \"\$@\""; then
    if ! rollback_runtime_activation "${previous_src}" "${runtime_src}"; then
      warn "${name}: wrapper creation failed and runtime rollback was unavailable"
    fi
    mark_failed "$name" "unable to create executable wrappers"
    return 0
  fi
  finalize_runtime_activation "${previous_src}" "${runtime_src}" || \
    warn "${name}: previous runtime remains at ${previous_src}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
