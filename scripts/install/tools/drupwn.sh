#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_drupwn() {
  local name="Drupwn"
  local repo="${TOOLS_DIR}/drupwn"
  local venv="${VENV_DIR}"
  local build_src="${COMPAT_DIR}/drupwn-src"
  local candidate_src=""
  local previous_src=""
  local smoke_out

  if ! repo_clone_or_update https://github.com/immunIT/drupwn.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  # Build beside the live runtime and swap only after compatibility checks.
  # Drupwn's updater owns plugins.txt; themes.txt continues to track Git.
  if ! prepare_runtime_candidate "${repo}" "${build_src}"; then
    mark_failed "$name" "unable to stage source tree"
    return 0
  fi
  candidate_src="${RUNTIME_CANDIDATE}"
  if [[ -f "${build_src}/plugins/wordlists/plugins.txt" ]]; then
    if ! run_user_cmd mkdir -p "${candidate_src}/plugins/wordlists" || \
      ! run_user_cmd cp -a "${build_src}/plugins/wordlists/plugins.txt" \
        "${candidate_src}/plugins/wordlists/plugins.txt"; then
      discard_runtime_candidate "${candidate_src}" "${build_src}" || true
      mark_failed "$name" "unable to preserve the existing updater wordlist"
      return 0
    fi
  fi
  if ! run_user_cmd rm -rf "${candidate_src}/build" "${candidate_src}/dist"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to clean staged source tree"
    return 0
  fi
  if ! cms_repair_drupwn_banners "${candidate_src}/drupwn"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unsupported welcome banner; source preserved"
    return 0
  fi
  if ! run_user_cmd env DRUPWN_BUILD="${candidate_src}" "${venv}/bin/python" - <<'PY'
import os
from pathlib import Path

base = Path(os.environ["DRUPWN_BUILD"])
setup = base / "setup.py"
if setup.exists():
    text = setup.read_text(encoding="utf-8", errors="ignore")
    text = text.replace("prompt_toolkit <= 2.0.7", "prompt_toolkit >= 2.0.7")
    setup.write_text(text, encoding="utf-8")

legacy_namespace = '__import__("pkg_resources").declare_namespace(__name__)'
modern_namespace = 'from pkgutil import extend_path\n__path__ = extend_path(__path__, __name__)'
for init_file in base.rglob("__init__.py"):
    text = init_file.read_text(encoding="utf-8", errors="ignore")
    if legacy_namespace in text:
        init_file.write_text(text.replace(legacy_namespace, modern_namespace), encoding="utf-8")

# The upstream data updater uses relative paths and then falls through into a
# target scan. Run it from this staged tree and exit cleanly once it completes.
entrypoint = base / "drupwn"
if not entrypoint.exists():
    raise SystemExit("Drupwn entrypoint is missing")
text = entrypoint.read_text(encoding="utf-8", errors="ignore")
old = "    if config['update']:\n        Update(logger,config).run()"
new = old + "\n        raise SystemExit(0)"
if "raise SystemExit(0)" not in text:
    if old not in text:
        raise SystemExit("Drupwn updater block changed upstream")
    entrypoint.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
  then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to patch CMS-environment compatibility"
    return 0
  fi
  if ! scanner_pip_install "${candidate_src}"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "pip install from source failed"
    return 0
  fi
  if ! cms_repair_drupwn_banners \
      "${venv}/bin/drupwn" "${INSTALL_HOME}/.venv/bin/drupwn"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to validate installed welcome banners"
    return 0
  fi
  if ! cleanup_managed_python_build_artifacts "${candidate_src}" "${build_src}"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to remove managed setuptools build output"
    return 0
  fi

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    local rc=0
    # shellcheck disable=SC2016 # Positional parameters expand in the inner bash.
    if smoke_out="$(capture_user_cmd env PYTHONWARNINGS=ignore::SyntaxWarning,ignore::UserWarning \
      bash -c 'cd "$1" && exec "$2" "$1/drupwn" --help' \
      _ "${candidate_src}" "${venv}/bin/python" 2>&1)"; then
      rc=0
    else
      rc=$?
    fi
    append_text_to_log "$smoke_out"
    if [[ $rc -ne 0 ]]; then
      discard_runtime_candidate "${candidate_src}" "${build_src}" || true
      mark_failed "$name" "Smoke test failed"
      return 0
    fi
  fi

  if ! activate_runtime_candidate "${candidate_src}" "${build_src}"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to activate staged runtime"
    return 0
  fi
  previous_src="${RUNTIME_PREVIOUS}"
  if ! create_wrapper "drupwn" "cd \"${build_src}\" && exec env PYTHONWARNINGS=ignore::SyntaxWarning,ignore::UserWarning \"\${CANONICAL_PYTHON}\" \"${build_src}/drupwn\" \"\$@\""; then
    if ! rollback_runtime_activation "${previous_src}" "${build_src}"; then
      warn "${name}: wrapper creation failed and runtime rollback was unavailable"
    fi
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  finalize_runtime_activation "${previous_src}" "${build_src}" || \
    warn "${name}: previous runtime remains at ${previous_src}"

  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
