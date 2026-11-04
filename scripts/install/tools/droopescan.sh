#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_droopescan() {
  local name="Droopescan"
  local venv="${VENV_DIR}"
  local smoke_out
  local old_plugins_dir=""
  local new_plugins_dir=""
  local signature_backup=""
  local package_installed=0

  if [[ -x "${venv}/bin/droopescan" ]]; then
    old_plugins_dir="$(capture_user_cmd "${venv}/bin/python" -c \
      'import pathlib, dscan; print(pathlib.Path(dscan.__file__).resolve().parent / "plugins")' \
      2>/dev/null || true)"
    if [[ -n "${old_plugins_dir}" && -d "${old_plugins_dir}" ]]; then
      package_installed=1
      signature_backup="$(capture_user_cmd mktemp -d 2>/dev/null || true)"
      [[ -z "${signature_backup}" ]] || vantage_register_temp_path "${signature_backup}" || return 1
      if [[ -z "${signature_backup}" || ! -d "${signature_backup}" ]] || \
        ! run_user_cmd env DROOPESCAN_OLD_PLUGINS="${old_plugins_dir}" \
          DROOPESCAN_SIGNATURE_BACKUP="${signature_backup}" "${venv}/bin/python" - <<'PY'
import os
import shutil
from pathlib import Path

source = Path(os.environ["DROOPESCAN_OLD_PLUGINS"])
backup = Path(os.environ["DROOPESCAN_SIGNATURE_BACKUP"])
for pattern in ("*/versions.xml", "*/plugins.txt", "*/themes.txt"):
    for path in source.glob(pattern):
        relative = path.relative_to(source)
        destination = backup / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
PY
      then
        [[ -z "${signature_backup}" || ! -d "${signature_backup}" ]] || \
          run_user_cmd rm -rf "${signature_backup}" || true
        mark_failed "$name" "unable to preserve existing signatures before package update"
        return 0
      fi
    fi
  fi

  if [[ "${UPDATE_EXISTING}" -eq 0 && "${package_installed}" -eq 1 ]]; then
    mark_update_skipped "${name} Python package" "disabled by --no-update"
  else
    if ! scanner_pip_install droopescan; then
      mark_failed "$name" "pip install droopescan failed; temporary signature backup will be removed at installer exit"
      return 0
    fi
    mark_updated "${name} Python package"
  fi

  new_plugins_dir="$(capture_user_cmd "${venv}/bin/python" -c \
    'import pathlib, dscan; print(pathlib.Path(dscan.__file__).resolve().parent / "plugins")' \
    2>/dev/null || true)"
  if [[ -n "${signature_backup}" ]]; then
    if [[ -z "${new_plugins_dir}" || ! -d "${new_plugins_dir}" ]] || ! run_user_cmd env \
      DROOPESCAN_SIGNATURE_BACKUP="${signature_backup}" DROOPESCAN_NEW_PLUGINS="${new_plugins_dir}" \
      "${venv}/bin/python" - <<'PY'
import os
import shutil
from pathlib import Path

backup = Path(os.environ["DROOPESCAN_SIGNATURE_BACKUP"])
target = Path(os.environ["DROOPESCAN_NEW_PLUGINS"])
if not target.is_dir():
    raise SystemExit("updated Droopescan plugins directory is unavailable")
for path in backup.rglob("*"):
    if path.is_file():
        relative = path.relative_to(backup)
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
PY
    then
      mark_failed "$name" "unable to restore mutable signatures after package update; temporary backup will be removed at installer exit"
      return 0
    fi
  fi
  ensure_py312_compat_shims "$venv"

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    set +e
    smoke_out="$(capture_user_cmd "${venv}/bin/droopescan" --help 2>&1)"
    local rc=$?
    set -e
    append_text_to_log "$smoke_out"
    if [[ $rc -ne 0 ]]; then
      [[ -z "${signature_backup}" ]] || run_user_cmd rm -rf "${signature_backup}" || true
      mark_failed "$name" "Smoke test failed"
      return 0
    fi
  fi
  if ! create_wrapper "droopescan" "exec \"\${CANONICAL_VENV}/bin/droopescan\" \"\$@\""; then
    [[ -z "${signature_backup}" ]] || run_user_cmd rm -rf "${signature_backup}" || true
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi

  [[ -z "${signature_backup}" ]] || run_user_cmd rm -rf "${signature_backup}" || \
    warn "${name}: temporary signature backup remains at ${signature_backup}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
