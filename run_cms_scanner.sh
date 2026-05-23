#!/usr/bin/env bash
# Copyright (c) INFRA - Andrea Bodei 2026-2036
set -Eeuo pipefail

# Unified CMS scanner runner.
# High-level flow:
# 1) normalize target + infer protocol/port with nmap when omitted
# 2) detect probable CMS
# 3) run compatible scanners in sequence
# 4) write one unified report + per-tool logs

# Project-relative paths used by this runner.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
BIN_DIR="${SCRIPT_DIR}/bin"
REPORTS_DIR="${SCRIPT_DIR}/reports"
LOGS_DIR="${SCRIPT_DIR}/logs"

# Increase chances of finding gem-installed executables (wpscan/wpxf)
if has_ruby_user_dir="$(ruby -e 'print Gem.user_dir' 2>/dev/null)"; then
  GEM_BIN_DIR="${has_ruby_user_dir}/bin"
  if [[ -d "${GEM_BIN_DIR}" ]]; then
    export PATH="${GEM_BIN_DIR}:${PATH}"
  fi
fi
export PATH="${BIN_DIR}:${PATH}"

DEFAULT_TIMEOUT="${TOOL_TIMEOUT:-180}"
CMSSCAN_FULL_WORKFLOW="${CMSSCAN_FULL_WORKFLOW:-0}"
CMSSCAN_FULL_TIMEOUT="${CMSSCAN_FULL_TIMEOUT:-420}"
TMP_DIR="$(mktemp -d)"
OUTPUT_OWNER=""
OUTPUT_GROUP=""
declare -a SKIPPED_ITEMS=()
declare -a SUCCESS_ITEMS=()
declare -a NONZERO_ITEMS=()
declare -a TIMEOUT_ITEMS=()
declare -a REPORT_NOTES=()

# -----------------------------------------------------------------------------
# Filesystem ownership and lifecycle helpers
# -----------------------------------------------------------------------------

# Resolve which user should own generated reports/logs.
# This prevents root-owned artifacts when the script is launched with sudo.
resolve_output_owner() {
  local owner=""

  if [[ -n "${SCAN_OUTPUT_OWNER:-}" ]]; then
    printf '%s\n' "${SCAN_OUTPUT_OWNER}"
    return 0
  fi

  if [[ "${EUID}" -ne 0 ]]; then
    printf '%s\n' "${USER:-$(id -un)}"
    return 0
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && id -u "${SUDO_USER}" >/dev/null 2>&1; then
    printf '%s\n' "${SUDO_USER}"
    return 0
  fi

  if command -v stat >/dev/null 2>&1; then
    owner="$(stat -c '%U' "${SCRIPT_DIR}" 2>/dev/null || true)"
    if [[ -n "${owner}" && "${owner}" != "root" ]] && id -u "${owner}" >/dev/null 2>&1; then
      printf '%s\n' "${owner}"
      return 0
    fi
  fi

  if id -u spabam >/dev/null 2>&1; then
    printf '%s\n' "spabam"
    return 0
  fi

  printf '%s\n' ""
}

apply_output_ownership() {
  local target=""
  local owner_group="${OUTPUT_GROUP:-${OUTPUT_OWNER}}"

  if [[ "${EUID}" -ne 0 || -z "${OUTPUT_OWNER}" ]]; then
    return 0
  fi

  for target in "$@"; do
    if [[ -n "${target}" && -e "${target}" ]]; then
      chown -R "${OUTPUT_OWNER}:${owner_group}" "${target}" >/dev/null 2>&1 || true
    fi
  done
}

cleanup() {
  local rc=$?
  rm -rf "${TMP_DIR:-}" >/dev/null 2>&1 || true
  apply_output_ownership "${REPORT_FILE:-}" "${TOOL_LOG_DIR:-}" "${REPORTS_DIR:-}" "${LOGS_DIR:-}"
  return "${rc}"
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Generic utility helpers
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: ./run_cms_scanner.sh <target> [report_output]

If report_output is omitted, the report is saved to:
  ./reports/<normalized-target>.cms.txt

Examples:
  ./run_cms_scanner.sh web.vulnweb.com
  ./run_cms_scanner.sh http://web.vulnweb.com
  ./run_cms_scanner.sh https://web.vulnweb.com:443
  ./run_cms_scanner.sh https://example.com reports/custom-report.txt
  ./run_cms_scanner.sh https://example.com /tmp/myreport.txt
EOF
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

sanitize_tool_output_for_report() {
  local src_file="$1"
  local dst_file="$2"

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$src_file" "$dst_file" <<'PY'
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])

data = src.read_bytes()
text = data.decode("utf-8", errors="replace")
text = text.replace("\r", "\n")

# Remove ANSI escape/control sequences.
ansi = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
text = ansi.sub("", text)

clean = []
blank = 0
for line in text.splitlines():
    line = line.rstrip()
    # Keep ASCII printables + tab; replace other chars with '?'.
    line = "".join(ch if ch == "\t" or (32 <= ord(ch) <= 126) else "?" for ch in line)
    if not line:
        blank += 1
        if blank > 2:
            continue
    else:
        blank = 0
    clean.append(line)

dst.write_text("\n".join(clean) + ("\n" if clean else ""), encoding="utf-8")
PY
    return 0
  fi

  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' "${src_file}" | tr -cd '\11\12\15\40-\176' >"${dst_file}" || cp -f "${src_file}" "${dst_file}"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

sanitize_name() {
  local value="$1"
  value="${value//[^A-Za-z0-9._-]/_}"
  value="${value##_}"
  value="${value%%_}"
  if [[ -z "${value}" ]]; then
    value="target"
  fi
  printf '%s' "${value}"
}

resolve_report_path() {
  local report_arg="${1:-}"
  local default_name="$2"
  local resolved=""

  if [[ -z "${report_arg}" ]]; then
    resolved="${REPORTS_DIR}/${default_name}.cms.txt"
  elif [[ "${report_arg}" == */ ]] || [[ -d "${report_arg}" ]]; then
    resolved="${report_arg%/}/${default_name}.cms.txt"
  elif [[ "${report_arg}" != */* ]]; then
    resolved="${REPORTS_DIR}/${report_arg}"
  else
    resolved="${report_arg}"
  fi

  printf '%s' "${resolved}"
}

extract_host_port_path() {
  local raw="$1"
  local proto=""
  local rest="${raw}"
  local hostport=""
  local host=""
  local port=""
  local path=""

  if [[ "${raw}" =~ ^(https?)://(.+)$ ]]; then
    proto="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
  fi

  hostport="${rest%%/*}"
  if [[ "${rest}" == */* ]]; then
    path="/${rest#*/}"
  fi

  if [[ "${hostport}" =~ ^([^:]+):([0-9]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
  else
    host="${hostport}"
  fi

  printf '%s|%s|%s|%s\n' "${proto}" "${host}" "${port}" "${path}"
}

port_open_nmap() {
  local host="$1"
  local port="$2"
  local out_file="$3"
  nmap -Pn -p "${port}" --open --host-timeout 20s --max-retries 1 "${host}" >"${out_file}" 2>&1 || true
  grep -qE "^${port}/tcp[[:space:]]+open" "${out_file}"
}

find_wpscan() {
  if command -v wpscan >/dev/null 2>&1; then
    command -v wpscan
    return 0
  fi
  for p in /usr/local/bin/wpscan /usr/bin/wpscan "${HOME}"/.local/share/gem/ruby/*/bin/wpscan; do
    if [[ -x "${p}" ]]; then
      printf '%s\n' "${p}"
      return 0
    fi
  done
  return 1
}

find_wpxf() {
  if command -v wpxf >/dev/null 2>&1; then
    command -v wpxf
    return 0
  fi
  for p in "${HOME}"/.local/share/gem/ruby/*/bin/wpxf; do
    if [[ -x "${p}" ]]; then
      printf '%s\n' "${p}"
      return 0
    fi
  done
  return 1
}

find_cmsscan_python() {
  if command -v cmsscan-python >/dev/null 2>&1; then
    command -v cmsscan-python
    return 0
  fi

  if [[ -x "${HOME}/.venv/cms_scanner/cmsscan/bin/python" ]]; then
    printf '%s\n' "${HOME}/.venv/cms_scanner/cmsscan/bin/python"
    return 0
  fi

  for p in /home/*/.venv/cms_scanner/cmsscan/bin/python /root/.venv/cms_scanner/cmsscan/bin/python; do
    if [[ -x "${p}" ]]; then
      printf '%s\n' "${p}"
      return 0
    fi
  done

  return 1
}

ruby_gem_available() {
  local gem_name="$1"
  ruby -r rubygems -e "gem '${gem_name}'" >/dev/null 2>&1
}

detect_cms() {
  local target_url="$1"
  local body=""

  if ! command -v curl >/dev/null 2>&1; then
    printf 'unknown'
    return
  fi

  body="$(curl -kLs --max-time 20 --connect-timeout 8 \
    -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36' \
    "${target_url}" 2>/dev/null || true)"

  if [[ -z "${body}" ]]; then
    printf 'unknown'
    return
  fi

  if printf '%s' "${body}" | grep -Eqi '(wp-content|wp-includes|wp-json|xmlrpc\.php|powered by wordpress)'; then
    printf 'wordpress'
  elif printf '%s' "${body}" | grep -Eqi '(Drupal\.settings|/sites/default/files/|/core/misc/drupal\.js|drupal-settings-json)'; then
    printf 'drupal'
  elif printf '%s' "${body}" | grep -Eqi '(Joomla!|joomla-script-|option=com_)'; then
    printf 'joomla'
  elif printf '%s' "${body}" | grep -Eqi '(window\.vBulletin|vBulletin_)'; then
    printf 'vbulletin'
  elif printf '%s' "${body}" | grep -Eqi '(etc\.clientlibs|/libs/granite/|/content/dam/)'; then
    printf 'aem'
  else
    printf 'unknown'
  fi
}

register_skip() {
  local title="$1"
  local reason="$2"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  SKIPPED_ITEMS+=("${title}: ${reason}")
}

append_skip() {
  local title="$1"
  local reason="$2"
  append_section_header "${title}"
  echo "SKIP: ${reason}" >>"${REPORT_FILE}"
  register_skip "${title}" "${reason}"
}

remove_last_item_match() {
  local arr_name="$1"
  local needle="$2"
  local i=0
  local -n arr_ref="${arr_name}"

  for (( i=${#arr_ref[@]}-1; i>=0; i-- )); do
    if [[ "${arr_ref[$i]}" == "${needle}" ]]; then
      unset 'arr_ref[i]'
      arr_ref=( "${arr_ref[@]}" )
      return 0
    fi
  done
  return 1
}

reclassify_last_tool_as_skip() {
  local reason="$1"
  local item="${LAST_TOOL_NAME} (rc=${LAST_TOOL_RC})"

  case "${LAST_TOOL_RC}" in
    0)
      if [[ "${SUCCESS_COUNT}" -gt 0 ]]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT - 1))
      fi
      remove_last_item_match SUCCESS_ITEMS "${item}" || true
      ;;
    124|137)
      if [[ "${TIMEOUT_COUNT}" -gt 0 ]]; then
        TIMEOUT_COUNT=$((TIMEOUT_COUNT - 1))
      fi
      remove_last_item_match TIMEOUT_ITEMS "${item}" || true
      ;;
    *)
      if [[ "${NONZERO_COUNT}" -gt 0 ]]; then
        NONZERO_COUNT=$((NONZERO_COUNT - 1))
      fi
      remove_last_item_match NONZERO_ITEMS "${item}" || true
      ;;
  esac

  register_skip "${LAST_TOOL_NAME}" "${reason}"
  REPORT_NOTES+=("${LAST_TOOL_NAME}: reclassified as SKIP (${reason})")
}

skip_not_applicable() {
  local name="$1"
  local target_cms="$2"
  append_skip "${name}" "detected CMS '${DETECTED_CMS}', tool targets '${target_cms}'"
}

should_run_for_detected_cms() {
  local target_cms="$1"
  [[ "${DETECTED_CMS}" == "unknown" || "${DETECTED_CMS}" == "${target_cms}" ]]
}

append_section_header() {
  local title="$1"
  {
    echo
    echo "================================================================================"
    echo "${title}"
    echo "================================================================================"
  } >>"${REPORT_FILE}"
}

run_tool() {
  local name="$1"
  local timeout_sec="$2"
  shift 2
  local cmd=( "$@" )
  local out_file="${TOOL_LOG_DIR}/$(sanitize_name "${name}").log"
  local clean_out_file="${out_file}.clean"
  local started_at
  local finished_at
  local start_epoch
  local end_epoch
  local duration
  local status_label
  local rc

  started_at="$(timestamp)"
  start_epoch="$(date +%s)"
  append_section_header "${name}"
  {
    echo "Tool Name   : ${name}"
    echo "Command     : ${cmd[*]}"
    echo "Tool Log    : ${out_file}"
    echo "Started     : ${started_at}"
  } >>"${REPORT_FILE}"

  set +e
  timeout --signal=INT --kill-after=10s "${timeout_sec}" "${cmd[@]}" >"${out_file}" 2>&1
  rc=$?
  set -e
  end_epoch="$(date +%s)"
  duration=$((end_epoch - start_epoch))
  finished_at="$(timestamp)"

  case "${name}" in
    "WPScan")
      sed -i '/No WPScan API Token given/d' "${out_file}" >/dev/null 2>&1 || true
      ;;
    "CMSmap")
      sed -i '/^E: Unable to locate package exploitdb$/d' "${out_file}" >/dev/null 2>&1 || true
      ;;
  esac

  sanitize_tool_output_for_report "${out_file}" "${clean_out_file}"

  case "${rc}" in
    0)
      status_label="SUCCESS"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      SUCCESS_ITEMS+=("${name} (rc=${rc})")
      ;;
    124|137)
      status_label="TIMEOUT"
      TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1))
      TIMEOUT_ITEMS+=("${name} (rc=${rc})")
      ;;
    *)
      status_label="NONZERO"
      NONZERO_COUNT=$((NONZERO_COUNT + 1))
      NONZERO_ITEMS+=("${name} (rc=${rc})")
      ;;
  esac

  {
    echo "Status      : ${status_label}"
    echo "Exit Code   : ${rc}"
    echo "Finished    : ${finished_at}"
    echo "Duration    : ${duration}s"
    echo
    echo "Output:"
    echo "----------------------------------------"
    cat "${clean_out_file}"
    echo "----------------------------------------"
    echo
  } >>"${REPORT_FILE}"
  rm -f "${clean_out_file}" >/dev/null 2>&1 || true
  apply_output_ownership "${out_file}" "${REPORT_FILE}"

  LAST_TOOL_NAME="${name}"
  LAST_TOOL_LOG="${out_file}"
  LAST_TOOL_RC="${rc}"
}

run_tool_shell() {
  local name="$1"
  local timeout_sec="$2"
  local script="$3"
  run_tool "${name}" "${timeout_sec}" bash -lc "${script}"
}

# Run a tool if the command exists on PATH, otherwise emit a standardized SKIP.
run_tool_if_available() {
  local section="$1"
  local timeout_sec="$2"
  local command_name="$3"
  shift 3

  if command -v "${command_name}" >/dev/null 2>&1; then
    run_tool "${section}" "${timeout_sec}" "$@"
    return 0
  fi

  append_skip "${section}" "${command_name} executable not found"
  return 1
}

# CMS-aware wrapper around run_tool_if_available.
run_cms_tool_if_available() {
  local section="$1"
  local target_cms="$2"
  local timeout_sec="$3"
  local command_name="$4"
  shift 4

  if should_run_for_detected_cms "${target_cms}"; then
    run_tool_if_available "${section}" "${timeout_sec}" "${command_name}" "$@"
  else
    skip_not_applicable "${section}" "${target_cms}"
  fi
}

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] || [[ "${1}" == "-h" ]] || [[ "${1}" == "--help" ]]; then
  usage
  exit 1
fi

require_cmd nmap
require_cmd timeout
require_cmd bash

RAW_TARGET="$1"
REPORT_OUTPUT_ARG="${2:-}"
IFS='|' read -r INPUT_PROTO INPUT_HOST INPUT_PORT INPUT_PATH < <(extract_host_port_path "${RAW_TARGET}")

if [[ -z "${INPUT_HOST}" ]]; then
  echo "Invalid target: ${RAW_TARGET}" >&2
  exit 1
fi

DETECTION_NOTE=""
NMAP_443_OUT="${TMP_DIR}/nmap_443.txt"
NMAP_80_OUT="${TMP_DIR}/nmap_80.txt"

PROTO="${INPUT_PROTO}"
HOST="${INPUT_HOST}"
PORT="${INPUT_PORT}"
URL_PATH="${INPUT_PATH}"

if [[ -z "${PROTO}" || -z "${PORT}" ]]; then
  if port_open_nmap "${HOST}" 443 "${NMAP_443_OUT}"; then
    PROTO="https"
    PORT="443"
    DETECTION_NOTE="Auto-detected via nmap: 443/tcp open"
  elif port_open_nmap "${HOST}" 80 "${NMAP_80_OUT}"; then
    PROTO="http"
    PORT="80"
    DETECTION_NOTE="Auto-detected via nmap: 80/tcp open"
  else
    echo "Target not found, please specify protocol (http:// or https://) and port (:80 or :443)" >&2
    exit 1
  fi
fi

# Assemble canonical URL and report naming inputs.
if [[ -z "${URL_PATH}" ]]; then
  URL_PATH=""
fi

TARGET_URL="${PROTO}://${HOST}:${PORT}${URL_PATH}"
REPORT_BASENAME="$(sanitize_name "${HOST}")"
if [[ "${PORT}" != "80" && "${PORT}" != "443" ]]; then
  REPORT_BASENAME="${REPORT_BASENAME}_${PORT}"
fi

OUTPUT_OWNER="$(resolve_output_owner || true)"
if [[ -n "${OUTPUT_OWNER}" ]] && id -u "${OUTPUT_OWNER}" >/dev/null 2>&1; then
  OUTPUT_GROUP="$(id -gn "${OUTPUT_OWNER}" 2>/dev/null || true)"
fi

mkdir -p "${REPORTS_DIR}" "${LOGS_DIR}"
apply_output_ownership "${REPORTS_DIR}" "${LOGS_DIR}"
REPORT_FILE="$(resolve_report_path "${REPORT_OUTPUT_ARG}" "${REPORT_BASENAME}")"
mkdir -p "$(dirname "${REPORT_FILE}")"
apply_output_ownership "$(dirname "${REPORT_FILE}")"

RUN_ID="$(date '+%Y%m%d_%H%M%S')_${REPORT_BASENAME}"
TOOL_LOG_DIR="${LOGS_DIR}/${RUN_ID}"
mkdir -p "${TOOL_LOG_DIR}"
apply_output_ownership "${TOOL_LOG_DIR}"
LOG_FILE="${TOOL_LOG_DIR}/run.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
apply_output_ownership "${LOG_FILE}"

# Keep WPScan runtime state inside the run directory to avoid permission issues
# with stale /tmp/wpscan paths created by previous root executions.
WPSCAN_RUNTIME_DIR="${TOOL_LOG_DIR}/wpscan_runtime"
WPSCAN_CACHE_DIR="${WPSCAN_RUNTIME_DIR}/cache"
WPSCAN_COOKIE_JAR="${WPSCAN_RUNTIME_DIR}/cookie_jar.txt"
mkdir -p "${WPSCAN_CACHE_DIR}"
touch "${WPSCAN_COOKIE_JAR}"
apply_output_ownership "${WPSCAN_RUNTIME_DIR}" "${WPSCAN_CACHE_DIR}" "${WPSCAN_COOKIE_JAR}"

if [[ -f "${NMAP_443_OUT}" ]]; then
  cp -f "${NMAP_443_OUT}" "${TOOL_LOG_DIR}/nmap_443.txt"
  NMAP_443_OUT="${TOOL_LOG_DIR}/nmap_443.txt"
else
  NMAP_443_OUT="${TOOL_LOG_DIR}/nmap_443.txt"
fi

if [[ -f "${NMAP_80_OUT}" ]]; then
  cp -f "${NMAP_80_OUT}" "${TOOL_LOG_DIR}/nmap_80.txt"
  NMAP_80_OUT="${TOOL_LOG_DIR}/nmap_80.txt"
else
  NMAP_80_OUT="${TOOL_LOG_DIR}/nmap_80.txt"
fi

DETECTED_CMS="$(detect_cms "${TARGET_URL}")"

SUCCESS_COUNT=0
NONZERO_COUNT=0
TIMEOUT_COUNT=0
SKIP_COUNT=0

{
  echo "CMS Unified Scan Report"
  echo "Generated: $(timestamp)"
  echo "Input target: ${RAW_TARGET}"
  echo "Normalized target URL: ${TARGET_URL}"
  echo "Detected CMS: ${DETECTED_CMS}"
  if [[ -n "${DETECTION_NOTE}" ]]; then
    echo "Detection: ${DETECTION_NOTE}"
  fi
  echo "Working directory: ${PWD}"
  echo "Run log: ${LOG_FILE}"
  echo "Tool logs directory: ${TOOL_LOG_DIR}"
  echo
  echo "----- nmap 443 probe -----"
  [[ -f "${NMAP_443_OUT}" ]] && cat "${NMAP_443_OUT}" || echo "not executed"
  echo
  echo "----- nmap 80 probe -----"
  [[ -f "${NMAP_80_OUT}" ]] && cat "${NMAP_80_OUT}" || echo "not executed"
  echo
} >"${REPORT_FILE}"

log "Target input       : ${RAW_TARGET}"
log "Normalized target  : ${TARGET_URL}"
log "Detected CMS       : ${DETECTED_CMS}"
log "Report output      : ${REPORT_FILE}"
log "Run log            : ${LOG_FILE}"
log "Tool logs          : ${TOOL_LOG_DIR}"
if [[ -n "${OUTPUT_OWNER}" ]]; then
  log "Output owner       : ${OUTPUT_OWNER}${OUTPUT_GROUP:+:${OUTPUT_GROUP}}"
fi

# Resolve optional executables
WPSCAN_CMD="$(find_wpscan || true)"
WPXF_CMD="$(find_wpxf || true)"
LAST_TOOL_NAME=""
LAST_TOOL_LOG=""
LAST_TOOL_RC=0

# Scanner execution stage.
# Tools run sequentially, with CMS-specific ones auto-skipped when not applicable.

# 1) WPScan
if should_run_for_detected_cms "wordpress"; then
  if [[ -n "${WPSCAN_CMD}" ]]; then
    run_tool "WPScan" "${DEFAULT_TIMEOUT}" "${WPSCAN_CMD}" --url "${TARGET_URL}" --detection-mode mixed --random-user-agent --no-banner --cache-dir "${WPSCAN_CACHE_DIR}" --cookie-jar "${WPSCAN_COOKIE_JAR}"
  else
    append_skip "WPScan" "wpscan executable not found"
  fi
else
  skip_not_applicable "WPScan" "wordpress"
fi

# 2) CMSmap
if run_tool_if_available "CMSmap" "${DEFAULT_TIMEOUT}" "cmsmap" cmsmap "${TARGET_URL}" --noedb; then
  if [[ "${LAST_TOOL_RC}" -ne 0 ]] && [[ -f "${LAST_TOOL_LOG}" ]] && grep -qE "ExploitDB (APT path was not found|Git repository was not found|GIT or APT settings not found)|git repo has not been found\\. Cloning|Unable to locate package exploitdb" "${LAST_TOOL_LOG}"; then
    reclassify_last_tool_as_skip "CMSmap bootstrap/exploitdb prerequisites not ready in this environment"
    {
      echo "Post-Processing: Reclassified as SKIP"
      echo "Reason         : CMSmap bootstrap/exploitdb prerequisites not ready in this environment"
      echo
    } >>"${REPORT_FILE}"
  fi
fi

# 3) CMSeeK
run_tool_if_available "CMSeeK" "${DEFAULT_TIMEOUT}" "cmseek" cmseek -u "${TARGET_URL}" --batch --light-scan || true

# 4) Droopescan
if command -v droopescan >/dev/null 2>&1; then
  for mode in wordpress drupal joomla moodle silverstripe; do
    if [[ "${DETECTED_CMS}" == "unknown" || "${DETECTED_CMS}" == "${mode}" ]]; then
      run_tool "Droopescan (${mode})" "${DEFAULT_TIMEOUT}" droopescan scan "${mode}" -u "${TARGET_URL}" --enumerate v -t 4 --timeout 15 --hide-progressbar
    else
      skip_not_applicable "Droopescan (${mode})" "${mode}"
    fi
  done
else
  append_skip "Droopescan" "droopescan executable not found"
fi

# 5) JoomScan
run_cms_tool_if_available "JoomScan" "joomla" "${DEFAULT_TIMEOUT}" "joomscan" joomscan --url "${TARGET_URL}" -ec --no-report || true

# 6) Drupwn
run_cms_tool_if_available "Drupwn" "drupal" "${DEFAULT_TIMEOUT}" "drupwn" drupwn --mode enum --target "${TARGET_URL}" --users --nodes --modules --dfiles --themes --thread 4 || true

# 7) VBScan
run_cms_tool_if_available "VBScan" "vbulletin" "${DEFAULT_TIMEOUT}" "vbscan" vbscan "${TARGET_URL}" || true

# 8) VulnX
run_tool_if_available "VulnX" "${DEFAULT_TIMEOUT}" "vulnx" vulnx -u "${TARGET_URL}" --cms || true

# 9) WPSeku
run_cms_tool_if_available "WPSeku" "wordpress" "${DEFAULT_TIMEOUT}" "wpseku" env PYTHONWARNINGS=ignore::SyntaxWarning wpseku --url "${TARGET_URL}" || true

# 10) WPForce (requires username and password lists)
if should_run_for_detected_cms "wordpress"; then
  if command -v wpforce >/dev/null 2>&1; then
    WPFORCE_USERS="${TMP_DIR}/wpforce_users.txt"
    WPFORCE_PASS="${TMP_DIR}/wpforce_passwords.txt"
    printf 'admin\n' >"${WPFORCE_USERS}"
    printf 'admin\npassword\n123456\n' >"${WPFORCE_PASS}"
    run_tool "WPForce" "${DEFAULT_TIMEOUT}" wpforce -i "${WPFORCE_USERS}" -w "${WPFORCE_PASS}" -u "${TARGET_URL}" -t 2
  else
    append_skip "WPForce" "wpforce executable not found"
  fi
else
  skip_not_applicable "WPForce" "wordpress"
fi

# 11) WPXF (interactive framework, scripted best-effort)
if should_run_for_detected_cms "wordpress"; then
  if [[ -n "${WPXF_CMD}" ]]; then
    WPXF_SSL="false"
    WPXF_TARGET_URI="${URL_PATH:-/}"
    if [[ "${PROTO}" == "https" ]]; then
      WPXF_SSL="true"
    fi
    if [[ -z "${WPXF_TARGET_URI}" ]]; then
      WPXF_TARGET_URI="/"
    fi
    if [[ "${WPXF_TARGET_URI}" != /* ]]; then
      WPXF_TARGET_URI="/${WPXF_TARGET_URI}"
    fi

    WPXF_SCRIPT="${TMP_DIR}/wpxf_input.txt"
    {
      # Handles startup prompt about stale temporary files when present.
      # If prompt is absent, WPXF treats this as a harmless unknown command and continues.
      echo "y"
      echo "use auxiliary/info/wp_v4.7_user_info_disclosure"
      echo "set host ${HOST}"
      echo "set port ${PORT}"
      echo "set ssl ${WPXF_SSL}"
      echo "set target_uri ${WPXF_TARGET_URI}"
      echo "set vhost ${HOST}"
      echo "show options"
      echo "check"
      echo "run"
      echo "exit"
    } >"${WPXF_SCRIPT}"
    run_tool_shell "WPXF" "${DEFAULT_TIMEOUT}" "cat '${WPXF_SCRIPT}' | '${WPXF_CMD}'"
    if [[ "${LAST_TOOL_RC}" -eq 0 ]] && [[ -f "${LAST_TOOL_LOG}" ]] \
      && grep -qE "No module loaded|One or more required options not set|unknown option|usage: wpxf|is not a recognised command" "${LAST_TOOL_LOG}" \
      && ! grep -qE "Execution finished successfully|Target appears to be safe|Saved export to " "${LAST_TOOL_LOG}"; then
      reclassify_last_tool_as_skip "WPXF module workflow did not execute correctly"
      {
        echo "Post-Processing: Reclassified as SKIP"
        echo "Reason         : WPXF module workflow did not execute correctly"
        echo
      } >>"${REPORT_FILE}"
    fi
  else
    append_skip "WPXF" "wpxf executable not found"
  fi
else
  skip_not_applicable "WPXF" "wordpress"
fi

# 12) joomlavs
run_cms_tool_if_available "joomlavs" "joomla" "${DEFAULT_TIMEOUT}" "joomlavs" joomlavs -u "${TARGET_URL}" -q --hide-banner || true

# 13) Fingerprinter (repo script)
FINGERPRINTER_APP=""
case "${DETECTED_CMS}" in
  wordpress|drupal|joomla|moodle) FINGERPRINTER_APP="${DETECTED_CMS}" ;;
esac
if [[ -z "${FINGERPRINTER_APP}" ]]; then
  append_skip "Fingerprinter" "no mapped Fingerprinter app for detected CMS '${DETECTED_CMS}'"
elif command -v fingerprinter >/dev/null 2>&1; then
  run_tool "Fingerprinter" "${DEFAULT_TIMEOUT}" fingerprinter --app-name "${FINGERPRINTER_APP}" --passive-fingerprint "${TARGET_URL}" --verbose
elif [[ -f "${TOOLS_DIR}/fingerprinter/fingerprinter.rb" ]]; then
  if command -v ruby >/dev/null 2>&1 && ruby_gem_available "cms_scanner"; then
    run_tool_shell "Fingerprinter" "${DEFAULT_TIMEOUT}" "cd '${TOOLS_DIR}/fingerprinter' && ruby fingerprinter.rb --app-name '${FINGERPRINTER_APP}' --passive-fingerprint '${TARGET_URL}' --verbose"
  else
    append_skip "Fingerprinter" "fingerprinter runtime missing (ruby and cms_scanner gem are required)"
  fi
else
  append_skip "Fingerprinter" "fingerprinter.rb not found"
fi
if [[ "${LAST_TOOL_NAME}" == "Fingerprinter" ]] && [[ "${LAST_TOOL_RC}" -eq 0 ]] && [[ -f "${LAST_TOOL_LOG}" ]] && grep -qE "undefined method|Bundler::GemNotFound|No app-name supplied|fingerprinter\\.rb:[0-9]+:in" "${LAST_TOOL_LOG}"; then
  reclassify_last_tool_as_skip "Fingerprinter returned runtime error output with rc=0"
  {
    echo "Post-Processing: Reclassified as SKIP"
    echo "Reason         : Fingerprinter returned runtime error output with rc=0"
    echo
  } >>"${REPORT_FILE}"
fi

# 14) AutoWPScan (single-target function call)
if should_run_for_detected_cms "wordpress"; then
  if [[ -z "${WPSCAN_API_TOKEN:-}" ]]; then
    append_skip "AutoWPScan" "WPSCAN_API_TOKEN not set (AutoWPScan requires token-backed WPScan JSON for stable results)"
  elif [[ -f "${TOOLS_DIR}/AutoWPScan/main.py" ]]; then
    run_tool "AutoWPScan" "${DEFAULT_TIMEOUT}" env TARGET_URL_ENV="${TARGET_URL}" WPSCAN_API_TOKEN="${WPSCAN_API_TOKEN:-}" WPSCAN_CACHE_DIR="${WPSCAN_CACHE_DIR}" WPSCAN_COOKIE_JAR="${WPSCAN_COOKIE_JAR}" python3 -c "import os,sys; sys.path.insert(0,'${TOOLS_DIR}/AutoWPScan'); import main; main._home_path='${REPORTS_DIR}'; main._wpscan_api_token=os.environ.get('WPSCAN_API_TOKEN',''); print(main.run_wpscan(os.environ['TARGET_URL_ENV'],'single-target','0'))"
    AUTOWPSCAN_JSON_PATH=""
    if [[ -f "${LAST_TOOL_LOG}" ]]; then
      AUTOWPSCAN_JSON_PATH="$(awk -F'|' 'NF>=7 {print $7; exit}' "${LAST_TOOL_LOG}" | tr -d '\r' || true)"
    fi
    if [[ -n "${AUTOWPSCAN_JSON_PATH}" ]] && [[ -f "${AUTOWPSCAN_JSON_PATH}" ]] && [[ "$(dirname "${AUTOWPSCAN_JSON_PATH}")" == "${SCRIPT_DIR}" ]]; then
      AUTOWPSCAN_JSON_MOVED="${REPORTS_DIR}/$(basename "${AUTOWPSCAN_JSON_PATH}")"
      if mv -f "${AUTOWPSCAN_JSON_PATH}" "${AUTOWPSCAN_JSON_MOVED}" 2>/dev/null; then
        {
          echo "Result handling: moved AutoWPScan JSON artifact to ${AUTOWPSCAN_JSON_MOVED}"
          echo
        } >>"${REPORT_FILE}"
      fi
    fi
    if [[ "${LAST_TOOL_RC}" -eq 0 ]] && [[ -f "${LAST_TOOL_LOG}" ]] && grep -q "scan_aborted" "${LAST_TOOL_LOG}"; then
      reclassify_last_tool_as_skip "AutoWPScan returned scan_aborted; likely API token/rate-limit related"
      {
        echo "Post-Processing: Reclassified as SKIP"
        echo "Reason         : AutoWPScan returned scan_aborted; likely API token/rate-limit related"
        echo
      } >>"${REPORT_FILE}"
    fi
  else
    append_skip "AutoWPScan" "AutoWPScan main.py not found"
  fi
else
  skip_not_applicable "AutoWPScan" "wordpress"
fi

# 15) AEM Detector (aem-hacker)
run_cms_tool_if_available "AEM Detector (aem-hacker)" "aem" "${DEFAULT_TIMEOUT}" "aem-hacker" aem-hacker -u "${TARGET_URL}" --workers 4 || true

# 16) AEM discoverer
if should_run_for_detected_cms "aem"; then
  if command -v aem-discoverer >/dev/null 2>&1; then
    AEM_LIST="${TMP_DIR}/aem_targets.txt"
    printf '%s\n' "${TARGET_URL}" >"${AEM_LIST}"
    run_tool "AEM Discoverer" "${DEFAULT_TIMEOUT}" aem-discoverer --file "${AEM_LIST}" --workers 4
  else
    append_skip "AEM Discoverer" "aem-discoverer executable not found"
  fi
else
  skip_not_applicable "AEM Discoverer" "aem"
fi

# 17) CMSScan workflow
if [[ -d "${TOOLS_DIR}/CMSScan" ]]; then
  CMSSCAN_PY="$(find_cmsscan_python || true)"
  if [[ -n "${CMSSCAN_PY}" ]]; then
    if [[ "${CMSSCAN_FULL_WORKFLOW}" == "1" ]]; then
      run_tool "CMSScan (plugin workflow)" "${CMSSCAN_FULL_TIMEOUT}" env TARGET_URL_ENV="${TARGET_URL}" "${CMSSCAN_PY}" -c "import os,sys; sys.path.insert(0,'${TOOLS_DIR}/CMSScan'); from plugins.scanners import find_cms,wpscan,droopescan,joomscan,vbscan; u=os.environ['TARGET_URL_ENV']; c=find_cms(u); print('detected_cms='+c); print((wpscan(u) if c=='wordpress' else droopescan(u) if c=='drupal' else joomscan(u) if c=='joomla' else vbscan(u) if c=='vbulletin' else 'No mapped scanner for detected CMS'))"
    else
      run_tool "CMSScan (detector workflow)" "${DEFAULT_TIMEOUT}" env TARGET_URL_ENV="${TARGET_URL}" "${CMSSCAN_PY}" -c "import os,sys; sys.path.insert(0,'${TOOLS_DIR}/CMSScan'); from plugins.scanners import find_cms; u=os.environ['TARGET_URL_ENV']; c=find_cms(u); m={'wordpress':'wpscan','drupal':'droopescan','joomla':'joomscan','vbulletin':'vbscan'}.get(c,'none'); print('detected_cms='+c); print('mapped_scanner='+m); print('full_workflow=disabled (set CMSSCAN_FULL_WORKFLOW=1 to enable)')"
    fi
  else
    append_skip "CMSScan workflow" "CMSScan python runtime not found (expected cmsscan-python wrapper or cmsscan venv)"
  fi
else
  append_skip "CMSScan workflow" "CMSScan directory not found"
fi

append_section_header "Execution Overview"
{
  echo "Target URL      : ${TARGET_URL}"
  echo "Detected CMS    : ${DETECTED_CMS}"
  echo "Success (rc=0)  : ${SUCCESS_COUNT}"
  echo "Non-zero exits  : ${NONZERO_COUNT}"
  echo "Timeouts        : ${TIMEOUT_COUNT}"
  echo "Skipped         : ${SKIP_COUNT}"
  echo "Run log         : ${LOG_FILE}"
  echo "Tool logs dir   : ${TOOL_LOG_DIR}"
  echo "Report file     : ${REPORT_FILE}"
} >>"${REPORT_FILE}"

append_section_header "Skipped Tools (Consolidated)"
{
  if [[ "${#SKIPPED_ITEMS[@]}" -eq 0 ]]; then
    echo "None"
  else
    for item in "${SKIPPED_ITEMS[@]}"; do
      echo "- ${item}"
    done
  fi
} >>"${REPORT_FILE}"

append_section_header "Non-Zero And Timeout Tools"
{
  if [[ "${#NONZERO_ITEMS[@]}" -eq 0 && "${#TIMEOUT_ITEMS[@]}" -eq 0 ]]; then
    echo "None"
  else
    if [[ "${#NONZERO_ITEMS[@]}" -gt 0 ]]; then
      echo "Non-zero:"
      for item in "${NONZERO_ITEMS[@]}"; do
        echo "- ${item}"
      done
    fi
    if [[ "${#TIMEOUT_ITEMS[@]}" -gt 0 ]]; then
      echo "Timeout:"
      for item in "${TIMEOUT_ITEMS[@]}"; do
        echo "- ${item}"
      done
    fi
  fi
} >>"${REPORT_FILE}"

append_section_header "Operational Notes"
{
  if [[ "${#REPORT_NOTES[@]}" -eq 0 ]]; then
    echo "None"
  else
    for note in "${REPORT_NOTES[@]}"; do
      echo "- ${note}"
    done
  fi
} >>"${REPORT_FILE}"

append_section_header "Summary"
{
  echo "Target URL            : ${TARGET_URL}"
  echo "Detected CMS          : ${DETECTED_CMS}"
  echo "Success (rc=0)        : ${SUCCESS_COUNT}"
  echo "Non-zero exits        : ${NONZERO_COUNT}"
  echo "Timeouts              : ${TIMEOUT_COUNT}"
  echo "Skipped               : ${SKIP_COUNT}"
  echo "Run log               : ${LOG_FILE}"
  echo "Tool logs directory   : ${TOOL_LOG_DIR}"
  echo "Report generated at   : ${REPORT_FILE}"
} >>"${REPORT_FILE}"

log "Unified report written to ${REPORT_FILE}"
log "Summary: success=${SUCCESS_COUNT}, nonzero=${NONZERO_COUNT}, timeouts=${TIMEOUT_COUNT}, skipped=${SKIP_COUNT}"
