#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_cmsmap() {
  local name="CMSmap"
  local repo="${TOOLS_DIR}/CMSmap"
  local managed_repo="${COMPAT_DIR}/upstream/CMSmap"
  local venv="${VENV_DIR}"
  local cmsmap_conf=""
  local cmsmap_pkg_dir=""
  local old_cmsmap_conf=""
  local old_data_dir=""
  local data_backup=""
  local edb_dir="${INSTALL_HOME}/.local/share/exploitdb"
  local package_installed=0

  if ! repo_clone_or_update https://github.com/Dionach/CMSmap.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"

  old_cmsmap_conf="$(capture_user_cmd bash -lc \
    "ls -1 \"${venv}\"/lib/python*/site-packages/cmsmap/cmsmap.conf 2>/dev/null | head -n 1" || true)"
  if [[ -n "${old_cmsmap_conf}" && -x "${venv}/bin/cmsmap" ]]; then
    package_installed=1
    old_data_dir="$(dirname "${old_cmsmap_conf}")/data"
    if [[ -d "${old_data_dir}" ]]; then
      data_backup="$(capture_user_cmd mktemp -d 2>/dev/null || true)"
      [[ -z "${data_backup}" ]] || vantage_register_temp_path "${data_backup}" || return 1
      if [[ -z "${data_backup}" || ! -d "${data_backup}" ]] || \
        ! run_user_cmd env CMSMAP_OLD_DATA="${old_data_dir}" CMSMAP_DATA_BACKUP="${data_backup}" \
          "${venv}/bin/python" - <<'PY'
import os
import shutil
from pathlib import Path

source = Path(os.environ["CMSMAP_OLD_DATA"])
backup = Path(os.environ["CMSMAP_DATA_BACKUP"])
mutable = {
    "wp_plugins_small.txt", "wp_themes_small.txt",
    "joo_plugins_small.txt", "dru_plugins_small.txt",
    "wp_versions.txt", "joo_versions.txt", "dru_versions.txt", "moo_versions.txt",
    "wp_defaultfiles.txt", "wp_defaultfolders.txt",
    "joo_defaultfiles.txt", "joo_defaultfolders.txt",
    "dru_defaultfiles.txt", "dru_defaultfolders.txt",
    "moo_defaultfiles.txt", "moo_defaultfolders.txt",
}
for name in mutable:
    path = source / name
    if path.is_file():
        shutil.copy2(path, backup / name)
PY
      then
        [[ -z "${data_backup}" || ! -d "${data_backup}" ]] || \
          run_user_cmd rm -rf "${data_backup}" || true
        mark_failed "$name" "unable to preserve existing mutable helper data before package update"
        return 0
      fi
    fi
  fi

  if [[ "${UPDATE_EXISTING}" -eq 0 && "${package_installed}" -eq 1 ]]; then
    mark_update_skipped "${name} Python package" "disabled by --no-update"
  else
    if ! scanner_pip_install "${repo}"; then
      mark_failed "$name" "pip install . failed; temporary mutable-data backup will be removed at installer exit"
      return 0
    fi
    case "${repo}" in
      "${managed_repo}"|"${managed_repo}.new."??????)
        if ! cleanup_managed_python_build_artifacts "${repo}" "${managed_repo}"; then
          mark_failed "$name" "unable to remove managed setuptools build output"
          return 0
        fi
        ;;
    esac
    mark_updated "${name} Python package"
  fi

  cmsmap_conf="$(capture_user_cmd bash -lc "ls -1 \"${venv}\"/lib/python*/site-packages/cmsmap/cmsmap.conf 2>/dev/null | head -n 1" || true)"
  if [[ -n "$cmsmap_conf" ]]; then
    cmsmap_pkg_dir="$(dirname "$cmsmap_conf")"
    if [[ -n "${data_backup}" ]] && ! run_user_cmd env \
      CMSMAP_DATA_BACKUP="${data_backup}" CMSMAP_NEW_DATA="${cmsmap_pkg_dir}/data" \
      "${venv}/bin/python" - <<'PY'
import os
import shutil
from pathlib import Path

backup = Path(os.environ["CMSMAP_DATA_BACKUP"])
target = Path(os.environ["CMSMAP_NEW_DATA"])
target.mkdir(parents=True, exist_ok=True)
for path in backup.iterdir():
    if path.is_file():
        destination = target / path.name
        if path.suffix == ".txt" and destination.is_file():
            # Keep generated/local entries while also accepting helper-list
            # additions shipped by the newly updated CMSmap snapshot.
            merged = []
            seen = set()
            for source in (destination, path):
                for line in source.read_text(encoding="utf-8", errors="ignore").splitlines():
                    value = line.strip()
                    if value and value not in seen:
                        seen.add(value)
                        merged.append(value)
            if merged:
                destination.write_text("\n".join(merged) + "\n", encoding="utf-8")
        else:
            shutil.copy2(path, destination)
PY
    then
      mark_failed "$name" "unable to restore mutable helper data after package update; temporary backup will be removed at installer exit"
      return 0
    fi
    if ! run_user_cmd mkdir -p "${edb_dir}"; then
      warn "${name}: unable to create local exploitdb directory ${edb_dir}"
    fi
    if ! run_user_shell "sed -i -E 's|^edbtype\\s*=.*|edbtype = apt|; s|^edbpath\\s*=.*|edbpath = ${edb_dir}/|' '${cmsmap_conf}'"; then
      warn "${name}: failed to patch cmsmap.conf exploitdb path"
    fi
    # CMSmap checks only whether generated helper files exist. Empty
    # placeholders silently disable version/plugin/default-path enumeration.
    # Preserve native/generated lists above; seed only genuinely empty files.
    if ! run_user_cmd env CMSMAP_DATA_DIR="${cmsmap_pkg_dir}/data" \
      "${venv}/bin/python" - <<'PY'
import os
from pathlib import Path

data = Path(os.environ["CMSMAP_DATA_DIR"])
data.mkdir(parents=True, exist_ok=True)

def write_if_empty(name, lines):
    path = data / name
    if path.exists() and path.stat().st_size:
        return
    values = list(dict.fromkeys(line.strip() for line in lines if line.strip()))
    if not values:
        raise SystemExit(f"no bootstrap data for {name}")
    path.write_text("\n".join(values) + "\n", encoding="utf-8")

small_seed = {
    "wp": ["akismet", "contact-form-7", "woocommerce", "wordfence", "duplicator", "wordpress-seo", "jetpack"],
    "joo": ["com_content", "com_users", "com_contact", "com_fabrik", "com_jce", "com_virtuemart", "com_k2", "com_jdownloads"],
    "dru": ["Views", "Coder", "Webform", "Token", "Services"],
}
for prefix in ("wp", "joo", "dru"):
    full = data / f"{prefix}_plugins.txt"
    if not full.exists():
        raise SystemExit(f"CMSmap source list is missing: {full}")
    available = {
        value.lower(): value
        for value in full.read_text(encoding="utf-8", errors="ignore").splitlines()
        if value.strip()
    }
    write_if_empty(
        f"{prefix}_plugins_small.txt",
        (available[value.lower()] for value in small_seed[prefix] if value.lower() in available),
    )

fallback = {
    "wp_versions.txt": ["6.0", "5.9", "5.8", "5.7", "5.6"],
    "joo_versions.txt": ["4.0.0", "3.10.0", "3.9.0", "3.8.0"],
    "dru_versions.txt": ["10.0.0", "9.5.0", "9.4.0", "9.3.0"],
    "moo_versions.txt": ["v4.0.0", "v3.11.0", "v3.10.0", "v3.9.0"],
    "wp_defaultfiles.txt": ["/license.txt", "/readme.html"],
    "wp_defaultfolders.txt": ["/wp-admin", "/wp-content", "/wp-includes"],
    "joo_defaultfiles.txt": ["/README.txt", "/LICENSE.txt", "/robots.txt"],
    "joo_defaultfolders.txt": ["/administrator", "/components", "/modules", "/templates"],
    "dru_defaultfiles.txt": ["/README.md", "/LICENSE.txt", "/robots.txt"],
    "dru_defaultfolders.txt": ["/core", "/modules", "/sites", "/themes"],
    "moo_defaultfiles.txt": ["/README.txt", "/TRADEMARK.txt"],
    "moo_defaultfolders.txt": ["/admin", "/course", "/lib", "/mod", "/theme"],
}
for name, lines in fallback.items():
    write_if_empty(name, lines)

for name in [f"{p}_plugins_small.txt" for p in ("wp", "joo", "dru")] + ["wp_themes_small.txt"] + list(fallback):
    path = data / name
    if not path.exists() or path.stat().st_size == 0:
        raise SystemExit(f"CMSmap helper data is empty: {path}")
PY
    then
      [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || true
      mark_failed "$name" "failed to bootstrap non-empty CMSmap helper data"
      return 0
    fi
    if ! run_user_shell "\"${venv}/bin/python\" - <<'PY'
from pathlib import Path

main_py = Path('${cmsmap_pkg_dir}/main.py')
if not main_py.exists():
    raise SystemExit('cmsmap main.py is missing')
text = main_py.read_text(encoding='utf-8')
desired = '    if not initializer.NoExploitdb:\\n        updater.UpdateExploitDB()\\n    updater.CheckLocalFiles()\\n'
if desired not in text:
    marker = '    updater.UpdateExploitDB()\\n    updater.CheckLocalFiles()\\n'
    if marker not in text:
        raise SystemExit('CMSmap exploitdb patch marker changed upstream')
    text = text.replace(
        marker,
        desired,
    )
    main_py.write_text(text, encoding='utf-8')
if desired not in main_py.read_text(encoding='utf-8'):
    raise SystemExit('CMSmap exploitdb guard validation failed')
PY"; then
      [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || true
      mark_failed "$name" "failed to patch/validate noedb runtime path"
      return 0
    fi
    if ! run_user_shell "\"${venv}/bin/python\" - <<'PY'
from pathlib import Path

requester_py = Path('${cmsmap_pkg_dir}/lib/requester.py')
if not requester_py.exists():
    raise SystemExit('CMSmap requester.py is missing')
text = requester_py.read_text(encoding='utf-8')
old = \"\"\"        except urllib.request.HTTPError as e:
            # Does not return  200
            self.response = e
            self.htmltext = e.read().decode('utf-8', 'ignore')
            self.status_code = e.code
\"\"\"
new = old + \"\"\"        except Exception:
            self.response = None
            self.htmltext = ''
            self.status_code = 0
\"\"\"
if '        except Exception:\\n            self.response = None\\n' not in text:
    if old not in text:
        raise SystemExit('CMSmap requester patch marker changed upstream')
    text = text.replace(old, new)
    requester_py.write_text(text, encoding='utf-8')
if '        except Exception:\\n            self.response = None\\n' not in requester_py.read_text(encoding='utf-8'):
    raise SystemExit('CMSmap requester guard validation failed')

genericchecks_py = Path('${cmsmap_pkg_dir}/lib/genericchecks.py')
if not genericchecks_py.exists():
    raise SystemExit('CMSmap genericchecks.py is missing')
text = genericchecks_py.read_text(encoding='utf-8')
guard = \"\"\"        if requester.response is None or requester.status_code in (None, 0):
            report.status(\"Unable to retrieve headers from target (connection reset/timeout)\")
            return
\"\"\"
marker = \"\"\"        requester.request(self.url, data=None)
        msg = \\\"Checking headers ...\\\"
\"\"\"
if guard not in text:
    if marker not in text:
        raise SystemExit('CMSmap generic-check patch marker changed upstream')
    text = text.replace(
        marker,
        \"\"\"        requester.request(self.url, data=None)
        if requester.response is None or requester.status_code in (None, 0):
            report.status(\\\"Unable to retrieve headers from target (connection reset/timeout)\\\")
            return
        msg = \\\"Checking headers ...\\\"
\"\"\",
    )
    genericchecks_py.write_text(text, encoding='utf-8')
if guard not in genericchecks_py.read_text(encoding='utf-8'):
    raise SystemExit('CMSmap generic-check guard validation failed')
PY"; then
      [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || true
      mark_failed "$name" "failed to patch/validate resilient network error handling"
      return 0
    fi
  else
    [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || true
    mark_failed "$name" "could not locate cmsmap.conf after installation"
    return 0
  fi

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    local out
    out="$(capture_user_cmd "${venv}/bin/cmsmap" -h 2>&1 || true)"
    append_text_to_log "$out"
    if ! printf '%s' "$out" | grep -qi "CMSmap tool"; then
      [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || true
      mark_failed "$name" "unexpected help output"
      return 0
    fi
  fi
  if ! create_wrapper "cmsmap" "exec \"\${CANONICAL_VENV}/bin/cmsmap\" \"\$@\""; then
    [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || true
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  [[ -z "${data_backup}" ]] || run_user_cmd rm -rf "${data_backup}" || \
    warn "${name}: temporary helper-data backup remains at ${data_backup}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
