#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_fingerprinter() {
  local name="Fingerprinter"
  local repo="${TOOLS_DIR}/fingerprinter"
  local repo_url="https://github.com/erwanlr/Fingerprinter.git"
  local runtime_src="${COMPAT_DIR}/fingerprinter-src"
  local candidate_src=""
  local previous_src=""
  local gem_user_dir=""
  local bundle_cmd=""
  local wrapper_candidate=""
  local wrapper_target="${BIN_DIR}/fingerprinter"
  local wrapper_previous="${BIN_DIR}/fingerprinter.old.$$"
  local had_wrapper=0
  local -a bundle_env=()

  if [[ ! -f "${FINGERPRINTER_LOCKFILE}" || -L "${FINGERPRINTER_LOCKFILE}" ]]; then
    mark_failed "$name" "reviewed lockfile is unavailable: ${FINGERPRINTER_LOCKFILE}"
    return 0
  fi
  if ! ensure_ruby_runtime; then
    mark_failed "$name" "ruby runtime unavailable"
    return 0
  fi
  if ! run_user_cmd gem install --user-install --no-document \
    --version "${FINGERPRINTER_BUNDLER_VERSION}" bundler; then
    mark_failed "$name" \
      "Bundler ${FINGERPRINTER_BUNDLER_VERSION} installation failed"
    return 0
  fi
  refresh_user_gem_bin
  gem_user_dir="$(fingerprinter_gem_home || true)"
  bundle_cmd="${gem_user_dir}/bin/bundle"
  if [[ -z "${gem_user_dir}" || ! -x "${bundle_cmd}" ]]; then
    mark_failed "$name" \
      "Bundler ${FINGERPRINTER_BUNDLER_VERSION} executable is unavailable for ${INSTALL_USER}"
    return 0
  fi
  if ! repo_clone_or_update "$repo_url" "$repo"; then
    mark_failed "$name" "unable to clone or refresh public repository: ${repo_url}"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"

  # Keep upstream source updateable: compatibility edits and mutable fingerprint
  # databases live in a staged runtime copy, never in the Git checkout.
  if ! prepare_runtime_candidate "${repo}" "${runtime_src}"; then
    mark_failed "$name" "unable to prepare staged runtime source"
    return 0
  fi
  candidate_src="${RUNTIME_CANDIDATE}"
  if [[ -d "${runtime_src}/db" ]]; then
    if ! run_user_cmd env FINGERPRINTER_OLD_DB="${runtime_src}/db" \
      FINGERPRINTER_NEW_DB="${candidate_src}/db" "${VENV_DIR}/bin/python" - <<'PY'
import os
import shutil
from pathlib import Path

old = Path(os.environ["FINGERPRINTER_OLD_DB"])
new = Path(os.environ["FINGERPRINTER_NEW_DB"])
new.mkdir(parents=True, exist_ok=True)
for path in old.rglob("*.json"):
    relative = path.relative_to(old)
    destination = new / relative
    if path.name == ".ignore.json" and destination.exists():
        continue
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, destination)
PY
    then
      discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
      mark_failed "$name" "unable to preserve the existing fingerprint database"
      return 0
    fi
  fi

  if [[ ! -f "${candidate_src}/Gemfile" || -L "${candidate_src}/Gemfile" ]]; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "Gemfile is missing from the staged runtime"
    return 0
  fi
  if ! run_user_cmd sed -i -E \
    "s/gem 'cms_scanner', '~> 0\\.13'/gem 'cms_scanner', '~> 0.13.0'/" \
    "${candidate_src}/Gemfile"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to pin Gemfile compatibility constraint"
    return 0
  fi
  if ! run_user_cmd cp -- "${FINGERPRINTER_LOCKFILE}" \
      "${candidate_src}/Gemfile.lock" || \
    ! run_user_cmd chmod 0644 "${candidate_src}/Gemfile.lock" || \
    ! run_as_install_user cmp -s -- "${FINGERPRINTER_LOCKFILE}" \
      "${candidate_src}/Gemfile.lock"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to publish the reviewed lockfile into the staged runtime"
    return 0
  fi

  if [[ -f "${candidate_src}/lib/fingerprinter/actions.rb" ]]; then
    if ! run_user_cmd env FINGERPRINTER_ACTIONS="${candidate_src}/lib/fingerprinter/actions.rb" "${VENV_DIR}/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["FINGERPRINTER_ACTIONS"])
text = path.read_text(encoding="utf-8", errors="ignore")

if "target.respond_to?(:in_scope_uris)" not in text:
    old = "    urls              = target.in_scope_urls(Typhoeus.get(target.url, request_options.merge(followlocation: true)))\n"
    new = (
        "    response          = Typhoeus.get(target.url, request_options.merge(followlocation: true))\n"
        "    urls              = if target.respond_to?(:in_scope_urls)\n"
        "                          target.in_scope_urls(response)\n"
        "                        elsif target.respond_to?(:in_scope_uris)\n"
        "                          target.in_scope_uris(response).map(&:to_s)\n"
        "                        else\n"
        "                          []\n"
        "                        end\n"
    )
    if old not in text:
        raise SystemExit("Fingerprinter action API changed upstream")
    text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")
if "target.respond_to?(:in_scope_uris)" not in path.read_text(encoding="utf-8", errors="ignore"):
    raise SystemExit("Fingerprinter compatibility patch did not apply")
PY
    then
      discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
      mark_failed "$name" "failed to patch CMSScanner target compatibility"
      return 0
    fi
  else
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "actions.rb not found after checkout"
    return 0
  fi

  if ! run_user_cmd "${VENV_DIR}/bin/python" - "${candidate_src}/db" <<'PY'
import json
import sys
from pathlib import Path

db_dir = Path(sys.argv[1])
# Upstream ships one JavaScript-style comment in this otherwise JSON file,
# while Fingerprinter reads it with Ruby's strict JSON parser.
legacy_joomla = db_dir / "joomla_old_versions.json"
if legacy_joomla.exists():
    text = legacy_joomla.read_text(encoding="utf-8")
    cleaned = "\n".join(
        line for line in text.splitlines() if not line.lstrip().startswith("//")
    ) + ("\n" if text.endswith("\n") else "")
    legacy_joomla.write_text(cleaned, encoding="utf-8")
paths = list(db_dir.glob("*.json"))
if not paths:
    raise SystemExit("fingerprint database is missing")
for path in paths:
    if path.stat().st_size == 0:
        raise SystemExit(f"empty fingerprint database: {path}")
    if not isinstance(json.loads(path.read_text(encoding="utf-8")), dict):
        raise SystemExit(f"invalid fingerprint database: {path}")
PY
  then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "staged fingerprint database validation failed"
    return 0
  fi

  bundle_env=(
    env -u BUNDLE_BIN_PATH -u BUNDLE_GEMFILE -u RUBYGEMS_GEMDEPS
    "HOME=${INSTALL_HOME}"
    "GEM_HOME=${gem_user_dir}"
    "GEM_PATH=${gem_user_dir}${GEM_PATH:+:${GEM_PATH}}"
    "BUNDLE_GEMFILE=${candidate_src}/Gemfile"
    BUNDLE_FROZEN=true
    BUNDLE_IGNORE_CONFIG=true
    "RUBYOPT=-W0 -W:no-deprecated"
  )
  if ! run_user_cmd "${bundle_env[@]}" "${bundle_cmd}" \
      "_${FINGERPRINTER_BUNDLER_VERSION}_" install --jobs 1 --retry 2; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "installation of the complete reviewed bundle failed"
    return 0
  fi
  if ! run_user_cmd "${bundle_env[@]}" "${bundle_cmd}" \
      "_${FINGERPRINTER_BUNDLER_VERSION}_" check; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "reviewed bundle check failed"
    return 0
  fi
  if ! run_as_install_user cmp -s -- "${FINGERPRINTER_LOCKFILE}" \
      "${candidate_src}/Gemfile.lock" || \
    ! fingerprinter_bundle_is_usable "${candidate_src}"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "reviewed lockfile changed or Bundler could not load the staged runtime"
    return 0
  fi
  if ! run_user_cmd "${bundle_env[@]}" "${bundle_cmd}" \
      "_${FINGERPRINTER_BUNDLER_VERSION}_" exec \
      ruby "${candidate_src}/fingerprinter.rb" --help; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "staged runtime smoke test failed"
    return 0
  fi

  if ! prepare_wrapper_candidate "fingerprinter" \
    "cd \"${runtime_src}\" && exec env HOME=\"${INSTALL_HOME}\" GEM_HOME=\"${gem_user_dir}\" GEM_PATH=\"${gem_user_dir}\${GEM_PATH:+:\${GEM_PATH}}\" BUNDLE_GEMFILE=\"${runtime_src}/Gemfile\" BUNDLE_FROZEN=true BUNDLE_IGNORE_CONFIG=true RUBYOPT=\"-W0 -W:no-deprecated\" \"${bundle_cmd}\" _${FINGERPRINTER_BUNDLER_VERSION}_ exec ruby \"${runtime_src}/fingerprinter.rb\" \"\$@\""; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to stage the executable wrapper"
    return 0
  fi
  wrapper_candidate="${WRAPPER_CANDIDATE_PATH}"
  wrapper_target="${WRAPPER_TARGET_PATH}"
  wrapper_previous="${wrapper_target}.old.$$"
  if [[ -e "${wrapper_previous}" || -L "${wrapper_previous}" ]]; then
    rm -f -- "${wrapper_candidate}"
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "stale wrapper rollback file blocks activation: ${wrapper_previous}"
    return 0
  fi
  if [[ -e "${wrapper_target}" || -L "${wrapper_target}" ]]; then
    if ! run_user_cmd cp -aP -- "${wrapper_target}" "${wrapper_previous}"; then
      rm -f -- "${wrapper_candidate}"
      discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
      mark_failed "$name" "unable to preserve the previous wrapper"
      return 0
    fi
    had_wrapper=1
  fi

  if ! activate_runtime_candidate "${candidate_src}" "${runtime_src}"; then
    rm -f -- "${wrapper_candidate}"
    [[ "${had_wrapper}" -eq 0 ]] || run_user_cmd rm -f -- "${wrapper_previous}" || true
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to activate staged runtime"
    return 0
  fi
  previous_src="${RUNTIME_PREVIOUS}"
  if ! mv -fT -- "${wrapper_candidate}" "${wrapper_target}"; then
    rollback_runtime_activation "${previous_src}" "${runtime_src}" || \
      warn "${name}: wrapper activation failed and runtime rollback was unavailable"
    [[ "${had_wrapper}" -eq 0 ]] || run_user_cmd rm -f -- "${wrapper_previous}" || true
    mark_failed "$name" "unable to activate executable wrapper"
    return 0
  fi

  if ! fingerprinter_runtime_is_usable "${runtime_src}" "${wrapper_target}"; then
    rollback_runtime_activation "${previous_src}" "${runtime_src}" || \
      warn "${name}: published entrypoint failed and runtime rollback was unavailable"
    if [[ "${had_wrapper}" -eq 1 ]]; then
      run_user_cmd mv -fT -- "${wrapper_previous}" "${wrapper_target}" || \
        warn "${name}: previous wrapper could not be restored from ${wrapper_previous}"
    else
      run_user_cmd rm -f -- "${wrapper_target}" || true
    fi
    mark_failed "$name" "published fingerprinter --help verification failed; previous runtime retained"
    return 0
  fi

  [[ "${had_wrapper}" -eq 0 ]] || run_user_cmd rm -f -- "${wrapper_previous}" || \
    warn "${name}: previous wrapper remains at ${wrapper_previous}"
  finalize_runtime_activation "${previous_src}" "${runtime_src}" || \
    warn "${name}: previous runtime remains at ${previous_src}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
