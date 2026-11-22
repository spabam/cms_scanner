#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# VANTAGE / INFRA AI OU PROJECT NOTICE
# Project-maintained VAPT integration by Andrea Bodei and INFRA AI OU for the
# VANTAGE project under the European Commission DIGITAL programme.
# AUTHORIZED USE ONLY: governments, companies, professionals, and other entities
# may use these tools only with explicit permission to perform VAPT against each
# specific target and only within the approved scope and rules of engagement.
# This repository grants no explicit or implicit authorization to test any target.
# Andrea Bodei, INFRA AI OU, the VANTAGE project, the DIGITAL programme, and the
# European Commission disclaim responsibility for unauthorized use or misuse.
# See PROJECT_NOTICE.md; applicable licenses and upstream notices remain authoritative.

# Copyright © 2026 Andrea Bodei — www.andreabodei.com
# Copyright (c) 2026-2036 Andrea Bodei <info at andreabodei.com>
set -Eeuo pipefail

# Every scan, including help-time dependency probes, uses the managed account.
vantage_aiuser_entry="$(/usr/bin/getent passwd aiuser 2>/dev/null || true)"
vantage_aiuser_uid="$(printf '%s\n' "$vantage_aiuser_entry" | /usr/bin/awk -F: 'NR == 1 {print $3}')"
if [[ "${VAPT_CONTAINER:-0}" != 1 ]] &&
   [[ -z "$vantage_aiuser_uid" ||
      "$(/usr/bin/id -u)" != "$vantage_aiuser_uid" ||
      "${VANTAGE_DISPATCHED:-0}" != 1 ]]; then
  if [[ -f /usr/bin/infra-scan-main && ! -L /usr/bin/infra-scan-main &&
        -x /usr/bin/infra-scan-main ]]; then
    exec /usr/bin/infra-scan-main cmsscan "$@"
  fi
  echo "CMS scans require trusted /usr/bin/infra-scan-main." >&2
  exit 77
fi
unset vantage_aiuser_entry vantage_aiuser_uid

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
INVOCATION_DIR="${VANTAGE_RESULTS_DIR:-$(pwd -P)}"
REPORTS_DIR="${CMS_SCANNER_REPORTS_DIR:-${INVOCATION_DIR}/reports}"
LOGS_DIR="${CMS_SCANNER_LOGS_DIR:-${INVOCATION_DIR}/logs}"

# Every Python scanner uses the fixed account's CMS-scoped environment.
resolve_python_home() {
  local runtime_home
  runtime_home="$(/usr/bin/getent passwd aiuser 2>/dev/null | /usr/bin/cut -d: -f6)"
  [[ -n "${runtime_home}" ]] || return 77
  printf '%s\n' "${runtime_home}"
}

PYTHON_HOME="$(resolve_python_home)"
PYTHON_VENV="${PYTHON_HOME}/.local/share/vantage/cms_scanner/venv"
PYTHON_BIN="${PYTHON_VENV}/bin/python"
export HOME="${PYTHON_HOME}" USER=aiuser LOGNAME=aiuser PYTHONNOUSERSITE=1
export VIRTUAL_ENV="${PYTHON_VENV}"
unset PYTHONHOME PYTHONPATH
export PATH="${PYTHON_VENV}/bin:${VANTAGE_RUNTIME_PATH:-${PYTHON_HOME}/.local/bin:/opt/infrascan/priv:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

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
SELECTED_SCANNER="all"
TOR_ENABLED=0
TOR_SOCKS_HOST="${TOR_SOCKS_HOST:-127.0.0.1}"
TOR_SOCKS_PORT="${TOR_SOCKS_PORT:-9050}"
TOR_PROXY_URL="socks5h://${TOR_SOCKS_HOST}:${TOR_SOCKS_PORT}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cmsscan.XXXXXXXX")"
OUTPUT_OWNER=""
OUTPUT_GROUP=""
declare -a SKIPPED_ITEMS=()
declare -a SUCCESS_ITEMS=()
declare -a NONZERO_ITEMS=()
declare -a TIMEOUT_ITEMS=()
declare -a REPORT_NOTES=()

# Public progress/log contract.  The installed cmsscan/cmscan wrapper forwards
# these paths into this project-owned runner; direct invocations use the same
# defaults in the caller's working directory.
PROGRESS_FILE_OPTION=""
RUNTIME_LOG_FILE_OPTION=""
QUIET_PROGRESS=0
CMSSCAN_PROGRESS_PATH=""
CMSSCAN_LOG_PATH=""
CMSSCAN_PROGRESS_LAST=-1
CMSSCAN_ACTIVITY_TOTAL=0
CMSSCAN_ACTIVITY_DONE=0

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
  esac
  return 1
}

runtime_absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${INVOCATION_DIR}" "$1" ;;
  esac
}

progress_line() {
  local value="$1" filled empty filled_text empty_text
  filled=$((value * 32 / 100))
  (( filled <= 32 )) || filled=32
  empty=$((32 - filled))
  printf -v filled_text '%*s' "${filled}" ''
  printf -v empty_text '%*s' "${empty}" ''
  filled_text="${filled_text// /#}"
  empty_text="${empty_text// /-}"
  LC_NUMERIC=C printf 'Progress: [%s%s] %5.1f%%' \
    "${filled_text}" "${empty_text}" "${value}"
}

write_progress() {
  local value="${1:-0}" directory temporary line
  [[ "${value}" =~ ^[0-9]+$ ]] || return 1
  (( value >= 0 )) || value=0
  (( value <= 100 )) || value=100
  (( value > CMSSCAN_PROGRESS_LAST )) || return 0
  directory="$(dirname -- "${CMSSCAN_PROGRESS_PATH}")"
  temporary="$(mktemp "${directory}/.cmsscan-progress.XXXXXXXX")" || return 1
  if ! printf '%s' "${value}" >"${temporary}" \
      || ! chmod 0600 "${temporary}" \
      || ! mv -f -- "${temporary}" "${CMSSCAN_PROGRESS_PATH}"; then
    rm -f -- "${temporary}" >/dev/null 2>&1 || true
    return 1
  fi
  CMSSCAN_PROGRESS_LAST="${value}"
  line="$(progress_line "${value}")"
  printf '%s\n' "${line}" >>"${CMSSCAN_LOG_PATH}" 2>/dev/null || true
  if [[ "${QUIET_PROGRESS}" -eq 0 ]] \
      && ! truthy "${VAPTSCAN_MANAGED_PROGRESS:-0}"; then
    printf '%s\n' "${line}"
  fi
}

initialize_runtime_artifacts() {
  local uid timestamp stem progress_value log_value
  uid="${VANTAGE_RUNTIME_UID:-$(/usr/bin/id -u)}"
  timestamp="$(date -u +'%Y%m%dT%H%M%S%NZ')"
  stem="${INVOCATION_DIR}/.cmsscan.${uid}.${timestamp}"
  progress_value="${PROGRESS_FILE_OPTION:-${CMSSCAN_PROGRESS_FILE:-${CMSCAN_PROGRESS_FILE:-${INFRA_PROGRESS_FILE:-${stem}.progress}}}}"
  log_value="${RUNTIME_LOG_FILE_OPTION:-${CMSSCAN_LOG_FILE:-${CMSCAN_LOG_FILE:-${INFRA_LOG_FILE:-${stem}.log}}}}"
  CMSSCAN_PROGRESS_PATH="$(runtime_absolute_path "${progress_value}")"
  CMSSCAN_LOG_PATH="$(runtime_absolute_path "${log_value}")"
  [[ "${CMSSCAN_PROGRESS_PATH}" != "${CMSSCAN_LOG_PATH}" ]] || {
    echo "Progress and log paths must be different" >&2
    return 1
  }
  mkdir -p -- "$(dirname -- "${CMSSCAN_PROGRESS_PATH}")" \
    "$(dirname -- "${CMSSCAN_LOG_PATH}")"
  touch -- "${CMSSCAN_LOG_PATH}"
  chmod 0600 "${CMSSCAN_LOG_PATH}" >/dev/null 2>&1 || true
  # An override may point at a completed file from an earlier invocation. A
  # new direct run always starts a fresh monotonic sequence at zero.
  CMSSCAN_PROGRESS_LAST=-1
  write_progress 0
}

configure_activity_progress() {
  local scanner
  CMSSCAN_ACTIVITY_TOTAL=0
  for scanner in wpscan cmsmap cmseek joomscan drupwn vbscan vulnx wpseku \
      wpforce wpxf joomlavs fingerprinter autowpscan aem-hacker \
      aem-discoverer cmsscan; do
    if scanner_selected "${scanner}"; then
      CMSSCAN_ACTIVITY_TOTAL=$((CMSSCAN_ACTIVITY_TOTAL + 1))
    fi
  done
  if scanner_selected droopescan; then
    CMSSCAN_ACTIVITY_TOTAL=$((CMSSCAN_ACTIVITY_TOTAL + 5))
  fi
  (( CMSSCAN_ACTIVITY_TOTAL > 0 )) || CMSSCAN_ACTIVITY_TOTAL=1
  CMSSCAN_ACTIVITY_DONE=0
}

complete_activity() {
  local count="${1:-1}" value
  CMSSCAN_ACTIVITY_DONE=$((CMSSCAN_ACTIVITY_DONE + count))
  (( CMSSCAN_ACTIVITY_DONE <= CMSSCAN_ACTIVITY_TOTAL )) \
    || CMSSCAN_ACTIVITY_DONE="${CMSSCAN_ACTIVITY_TOTAL}"
  value=$((10 + CMSSCAN_ACTIVITY_DONE * 84 / CMSSCAN_ACTIVITY_TOTAL))
  write_progress "${value}"
}

# -----------------------------------------------------------------------------
# Filesystem ownership and lifecycle helpers
# -----------------------------------------------------------------------------

# Resolve which user should own generated reports/logs.
# This prevents root-owned artifacts when the script is launched with sudo.
resolve_output_owner() {
  printf '%s\n' aiuser
}

apply_output_ownership() {
  local target=""
  local owner_group="${OUTPUT_GROUP:-${OUTPUT_OWNER}}"

  : "${target:-}" "${owner_group:-}"
  return 0
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
  local cmd
  cmd="$(basename "$0")"
  cat <<EOF
Copyright (c) 2026-2036 Andrea Bodei - info at andreabodei.com

Usage:
  ${cmd} [--tor] [--scanner NAME] <target> [report_output]
  ${cmd} -h|--help

Description:
  Runs the INFRA CMS scanner workflow against one authorized web target.
  The runner normalizes the target, detects the likely CMS, launches the
  compatible CMS tools, and writes one consolidated text report plus per-tool
  logs.

Arguments:
  target
      Required. Accepted forms:
        example.com
        example.com:8080
        example.com/path
        http://example.com
        https://example.com:8443/path

      An explicitly supplied scheme or port is always honoured and is never
      replaced by probing. Only when BOTH are omitted does the runner probe
      443 and 80 with nmap and choose https or http from the first open web
      port it finds. When only the scheme is given the port is derived from it
      (https -> 443, http -> 80); when only the port is given the scheme is
      derived from it (443 and 8443 -> https, anything else -> http).

  report_output
      Optional. Controls where the consolidated report is written.
      If omitted:
        ./reports/<normalized-target>.cms.txt
      If a directory or trailing slash is provided:
        <directory>/<normalized-target>.cms.txt
      If a bare filename is provided:
        ./reports/<filename>
      If a path is provided:
        <path>

Options:
  --tor
      Route CMS detection and scanner connections through the Tor SOCKS proxy
      at ${TOR_SOCKS_HOST}:${TOR_SOCKS_PORT}. Requires torsocks and a running
      Tor service. DNS lookups are also resolved through Tor.

  --scanner NAME
      Run only one scanner. If omitted, all scanners run by default.
      Use --scanner all to force the default behavior.

      Supported names:
        all
        wpscan, cmsmap, cmseek, droopescan, joomscan, drupwn, vbscan
        vulnx, wpseku, wpforce, wpxf, joomlavs, fingerprinter
        autowpscan, aem-hacker, aem-discoverer, cmsscan

  --progress-file PATH
      Override the scalar progress file. Precedence is CLI, CMSSCAN_* (or the
      CMSCAN alias), INFRA_*, then .cmsscan.<uid>.<UTC timestamp>.progress.

  --log-file PATH
      Override the paired runtime log using the same precedence.

  --quiet
      Suppress progress lines on stdout. Progress and log files remain active.

  -h, --help, help
      Show this help and exit.

Output:
  Consolidated report:
      <resolved report_output>
  Per-tool logs:
      <logs-dir>/<normalized-target>-<timestamp>/

Exit status:
  0  Scan workflow completed and report was written.
  1  Invalid arguments, missing runtime dependency, or fatal setup failure.

Examples:
  ${cmd} web.vulnweb.com
  ${cmd} --tor --scanner wpscan https://web.vulnweb.com
  ${cmd} --scanner droopescan https://example.com reports/droopescan.txt
  ${cmd} http://web.vulnweb.com
  ${cmd} https://web.vulnweb.com:443
  ${cmd} example.com reports/example.cms.txt
  ${cmd} https://example.com /tmp/example.cms.txt
EOF
}

has_help_arg() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -h|--help|help)
        return 0
        ;;
    esac
  done
  return 1
}

normalize_scanner_name() {
  local value="$1"
  value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  value="${value//_/-}"
  case "${value}" in
    all)
      printf '%s\n' "all"
      ;;
    wpscan|wp-scan)
      printf '%s\n' "wpscan"
      ;;
    cmsmap|cms-map)
      printf '%s\n' "cmsmap"
      ;;
    cmseek|cm-seek)
      printf '%s\n' "cmseek"
      ;;
    droopescan|droope-scan)
      printf '%s\n' "droopescan"
      ;;
    joomscan|joom-scan)
      printf '%s\n' "joomscan"
      ;;
    drupwn)
      printf '%s\n' "drupwn"
      ;;
    vbscan|vb-scan)
      printf '%s\n' "vbscan"
      ;;
    vulnx|vuln-x)
      printf '%s\n' "vulnx"
      ;;
    wpseku|wp-seku)
      printf '%s\n' "wpseku"
      ;;
    wpforce|wp-force)
      printf '%s\n' "wpforce"
      ;;
    wpxf|wp-xf)
      printf '%s\n' "wpxf"
      ;;
    joomlavs|joomla-vs)
      printf '%s\n' "joomlavs"
      ;;
    fingerprinter|finger-printer)
      printf '%s\n' "fingerprinter"
      ;;
    autowpscan|auto-wpscan|auto-wp-scan)
      printf '%s\n' "autowpscan"
      ;;
    aem|aem-hacker|aem-detector)
      printf '%s\n' "aem-hacker"
      ;;
    aem-discoverer|aemdiscoverer)
      printf '%s\n' "aem-discoverer"
      ;;
    cmsscan|cms-scan)
      printf '%s\n' "cmsscan"
      ;;
    *)
      return 1
      ;;
  esac
}

scanner_selected() {
  local scanner="$1"
  [[ "${SELECTED_SCANNER}" == "all" || "${SELECTED_SCANNER}" == "${scanner}" ]]
}

parse_args() {
  local scanner_value=""
  local normalized=""
  local option=""
  local -a positionals=()

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        usage
        exit 0
        ;;
      --tor)
        TOR_ENABLED=1
        ;;
      --quiet)
        QUIET_PROGRESS=1
        ;;
      --progress-file|--log-file)
        option="$1"
        shift
        if [[ "$#" -eq 0 || -z "${1:-}" || "$1" == --* ]]; then
          echo "Missing path for ${option}" >&2
          exit 1
        fi
        if [[ "${option}" == "--progress-file" ]]; then
          PROGRESS_FILE_OPTION="$1"
        else
          RUNTIME_LOG_FILE_OPTION="$1"
        fi
        ;;
      --progress-file=*)
        PROGRESS_FILE_OPTION="${1#*=}"
        [[ -n "${PROGRESS_FILE_OPTION}" ]] || { echo "Missing path for --progress-file" >&2; exit 1; }
        ;;
      --log-file=*)
        RUNTIME_LOG_FILE_OPTION="${1#*=}"
        [[ -n "${RUNTIME_LOG_FILE_OPTION}" ]] || { echo "Missing path for --log-file" >&2; exit 1; }
        ;;
      --scanner|--tool|--only)
        shift
        if [[ "$#" -eq 0 || -z "${1:-}" || "${1}" == --* ]]; then
          echo "Missing scanner name for --scanner" >&2
          usage >&2
          exit 1
        fi
        scanner_value="$1"
        ;;
      --scanner=*|--tool=*|--only=*)
        scanner_value="${1#*=}"
        if [[ -z "${scanner_value}" ]]; then
          echo "Missing scanner name for --scanner" >&2
          usage >&2
          exit 1
        fi
        ;;
      --)
        shift
        while [[ "$#" -gt 0 ]]; do
          positionals+=("$1")
          shift
        done
        break
        ;;
      --*)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
      *)
        positionals+=("$1")
        ;;
    esac
    shift
  done

  if [[ -n "${scanner_value}" ]]; then
    normalized="$(normalize_scanner_name "${scanner_value}" || true)"
    if [[ -z "${normalized}" ]]; then
      echo "Unknown scanner: ${scanner_value}" >&2
      usage >&2
      exit 1
    fi
    SELECTED_SCANNER="${normalized}"
  fi

  if [[ "${#positionals[@]}" -lt 1 || "${#positionals[@]}" -gt 2 ]]; then
    usage >&2
    exit 1
  fi

  RAW_TARGET="${positionals[0]}"
  REPORT_OUTPUT_ARG="${positionals[1]:-}"
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

  if [[ -x "${PYTHON_BIN}" ]]; then
    "${PYTHON_BIN}" - "$src_file" "$dst_file" <<'PY'
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

resolve_runtime_nmap() {
  local candidate=""
  local resolved=""
  local first_line=""

  for candidate in \
    "${CMS_NMAP_BIN:-}" \
    "${INFRA_NMAP_BIN:-}" \
    "${NMAP_BIN:-}" \
    nmap; do
    [[ -n "$candidate" ]] || continue
    if [[ "$candidate" == */* ]]; then
      resolved="$candidate"
    else
      resolved="$(command -v -- "$candidate" 2>/dev/null || true)"
    fi
    [[ -x "$resolved" && ! -d "$resolved" ]] || continue
    first_line="$("$resolved" --version 2>/dev/null | sed -n '1p' || true)"
    [[ "$first_line" == Nmap\ version\ * ]] || continue
    printf '%s\n' "$resolved"
    return 0
  done
  return 1
}

port_open_nmap() {
  local host="$1"
  local port="$2"
  local out_file="$3"
  "$CMS_NMAP_COMMAND" -Pn -p "${port}" --open --host-timeout 20s --max-retries 1 "${host}" >"${out_file}" 2>&1 || true
  grep -qE "^${port}/tcp[[:space:]]+open" "${out_file}"
}

tor_proxy_is_reachable() {
  timeout 3 bash -c "exec 3<>/dev/tcp/${TOR_SOCKS_HOST}/${TOR_SOCKS_PORT}" >/dev/null 2>&1
}

url_reachable_via_tor() {
  local url="$1"
  curl -kLsS --proxy "${TOR_PROXY_URL}" --max-time 20 --connect-timeout 8 \
    -o /dev/null "${url}" >/dev/null 2>&1
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
  if [[ -x "${PYTHON_BIN}" ]]; then
    printf '%s\n' "${PYTHON_BIN}"
    return 0
  fi
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

  local -a proxy_args=()
  if [[ "${TOR_ENABLED}" -eq 1 ]]; then
    proxy_args=(--proxy "${TOR_PROXY_URL}")
  fi

  body="$(curl -kLs --max-time 20 --connect-timeout 8 "${proxy_args[@]}" \
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

redact_command_preview() {
  local arg=""
  local -a redacted=()

  for arg in "$@"; do
    case "${arg}" in
      *TOKEN=*|*PASSWORD=*|*SECRET=*|*KEY=*)
        redacted+=("${arg%%=*}=<redacted>")
        ;;
      *)
        redacted+=("${arg}")
        ;;
    esac
  done

  printf '%s' "${redacted[*]}"
}

run_tool() {
  local name="$1"
  local timeout_sec="$2"
  shift 2
  local cmd=( "$@" )
  local out_file
  local clean_out_file
  local started_at
  local finished_at
  local start_epoch
  local end_epoch
  local duration
  local status_label
  local rc

  out_file="${TOOL_LOG_DIR}/$(sanitize_name "${name}").log"
  : >"${out_file}"
  chmod 0600 "${out_file}" >/dev/null 2>&1 || true
  clean_out_file="${out_file}.clean"
  started_at="$(timestamp)"
  start_epoch="$(date +%s)"
  append_section_header "${name}"
  {
    echo "Tool Name   : ${name}"
    echo "Command     : $(redact_command_preview "${cmd[@]}")"
    echo "Tool Log    : ${out_file}"
    echo "Started     : ${started_at}"
  } >>"${REPORT_FILE}"

  set +e
  if [[ "${TOR_ENABLED}" -eq 1 ]]; then
    timeout --signal=INT --kill-after=10s "${timeout_sec}" \
      torsocks -a "${TOR_SOCKS_HOST}" -P "${TOR_SOCKS_PORT}" "${cmd[@]}" >"${out_file}" 2>&1
  else
    timeout --signal=INT --kill-after=10s "${timeout_sec}" "${cmd[@]}" >"${out_file}" 2>&1
  fi
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

parse_args "$@"
initialize_runtime_artifacts
configure_activity_progress

require_cmd timeout
require_cmd bash

if [[ "${TOR_ENABLED}" -eq 1 ]]; then
  require_cmd curl
  require_cmd torsocks
  if ! tor_proxy_is_reachable; then
    echo "Tor SOCKS proxy is not reachable at ${TOR_SOCKS_HOST}:${TOR_SOCKS_PORT}" >&2
    exit 1
  fi
else
  CMS_NMAP_COMMAND="$(resolve_runtime_nmap || true)"
  if [[ -z "$CMS_NMAP_COMMAND" ]]; then
    echo "A functional Nmap executable is required (CMS_NMAP_BIN, INFRA_NMAP_BIN, NMAP_BIN, or PATH)." >&2
    exit 1
  fi
fi

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

# Probing may only run when BOTH the scheme and the port were omitted: an
# explicitly supplied scheme or port is part of the authorized scope and is
# never overridden. When exactly one of the two is given, the other is derived
# from it instead of probed.
if [[ -z "${PROTO}" && -z "${PORT}" ]]; then
  if [[ "${TOR_ENABLED}" -eq 1 ]]; then
    if url_reachable_via_tor "https://${HOST}:443${URL_PATH}"; then
      PROTO="https"
      PORT="443"
      DETECTION_NOTE="Auto-detected through Tor: HTTPS reachable on 443/tcp"
    elif url_reachable_via_tor "http://${HOST}:80${URL_PATH}"; then
      PROTO="http"
      PORT="80"
      DETECTION_NOTE="Auto-detected through Tor: HTTP reachable on 80/tcp"
    else
      echo "Target is not reachable through Tor; specify protocol and port explicitly if it uses a non-standard web port" >&2
      exit 1
    fi
  elif port_open_nmap "${HOST}" 443 "${NMAP_443_OUT}"; then
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
elif [[ -z "${PORT}" ]]; then
  if [[ "${PROTO}" == "https" ]]; then
    PORT="443"
  else
    PORT="80"
  fi
  DETECTION_NOTE="Port derived from the requested ${PROTO} scheme: ${PORT}/tcp"
elif [[ -z "${PROTO}" ]]; then
  if [[ "${PORT}" == "443" || "${PORT}" == "8443" ]]; then
    PROTO="https"
  else
    PROTO="http"
  fi
  DETECTION_NOTE="Scheme derived from the requested port ${PORT}/tcp: ${PROTO}"
fi

# Assemble canonical URL and report naming inputs.
if [[ -z "${URL_PATH}" ]]; then
  URL_PATH=""
fi

TARGET_URL="${PROTO}://${HOST}:${PORT}${URL_PATH}"
write_progress 5
REPORT_BASENAME="$(sanitize_name "${HOST}")"
if [[ "${PORT}" != "80" && "${PORT}" != "443" ]]; then
  REPORT_BASENAME="${REPORT_BASENAME}_${PORT}"
fi

OUTPUT_OWNER="$(resolve_output_owner || true)"
if [[ -n "${OUTPUT_OWNER}" ]] && id -u "${OUTPUT_OWNER}" >/dev/null 2>&1; then
  OUTPUT_GROUP="$(/usr/bin/id -gn "${OUTPUT_OWNER}" 2>/dev/null || true)"
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
LEGACY_LOG_FILE="${TOOL_LOG_DIR}/run.log"
LOG_FILE="${CMSSCAN_LOG_PATH}"
# Preserve the historical per-target run.log while publishing the canonical
# paired cmsscan log consumed by the parent orchestrator.
: >"${LEGACY_LOG_FILE}"
chmod 0600 "${LEGACY_LOG_FILE}" >/dev/null 2>&1 || true
exec > >(tee -a "${LOG_FILE}" "${LEGACY_LOG_FILE}") 2>&1
apply_output_ownership "${LOG_FILE}" "${LEGACY_LOG_FILE}"

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
write_progress 10

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
  echo "Selected scanner: ${SELECTED_SCANNER}"
  if [[ "${TOR_ENABLED}" -eq 1 ]]; then
    echo "Tor routing: enabled (${TOR_PROXY_URL})"
  else
    echo "Tor routing: disabled"
  fi
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
log "Selected scanner   : ${SELECTED_SCANNER}"
log "Tor routing        : $([[ "${TOR_ENABLED}" -eq 1 ]] && printf 'enabled (%s)' "${TOR_PROXY_URL}" || printf 'disabled')"
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
if scanner_selected "wpscan"; then
  if should_run_for_detected_cms "wordpress"; then
    if [[ -n "${WPSCAN_CMD}" ]]; then
      run_tool "WPScan" "${DEFAULT_TIMEOUT}" "${WPSCAN_CMD}" --url "${TARGET_URL}" --detection-mode mixed --random-user-agent --no-banner --cache-dir "${WPSCAN_CACHE_DIR}" --cookie-jar "${WPSCAN_COOKIE_JAR}"
    else
      append_skip "WPScan" "wpscan executable not found"
    fi
  else
    skip_not_applicable "WPScan" "wordpress"
  fi
  complete_activity
fi

# 2) CMSmap
if scanner_selected "cmsmap"; then
  if run_tool_if_available "CMSmap" "${DEFAULT_TIMEOUT}" "cmsmap" cmsmap "${TARGET_URL}" --noedb --default; then
    if [[ "${LAST_TOOL_RC}" -ne 0 ]] && [[ -f "${LAST_TOOL_LOG}" ]] && grep -qE "ExploitDB (APT path was not found|Git repository was not found|GIT or APT settings not found)|git repo has not been found\\. Cloning|Unable to locate package exploitdb" "${LAST_TOOL_LOG}"; then
      reclassify_last_tool_as_skip "CMSmap bootstrap/exploitdb prerequisites not ready in this environment"
      {
        echo "Post-Processing: Reclassified as SKIP"
        echo "Reason         : CMSmap bootstrap/exploitdb prerequisites not ready in this environment"
        echo
      } >>"${REPORT_FILE}"
    fi
  fi
  complete_activity
fi

# 3) CMSeeK
if scanner_selected "cmseek"; then
  run_tool_if_available "CMSeeK" "${DEFAULT_TIMEOUT}" "cmseek" cmseek -u "${TARGET_URL}" --batch --light-scan || true
  complete_activity
fi

# 4) Droopescan
if scanner_selected "droopescan"; then
  if command -v droopescan >/dev/null 2>&1; then
    for mode in wordpress drupal joomla moodle silverstripe; do
      if [[ "${DETECTED_CMS}" == "unknown" || "${DETECTED_CMS}" == "${mode}" ]]; then
        run_tool "Droopescan (${mode})" "${DEFAULT_TIMEOUT}" droopescan scan "${mode}" -u "${TARGET_URL}" --enumerate v -t 4 --timeout 15 --hide-progressbar
      else
        skip_not_applicable "Droopescan (${mode})" "${mode}"
      fi
      complete_activity
    done
  else
    append_skip "Droopescan" "droopescan executable not found"
    complete_activity 5
  fi
fi

# 5) JoomScan
if scanner_selected "joomscan"; then
  run_cms_tool_if_available "JoomScan" "joomla" "${DEFAULT_TIMEOUT}" "joomscan" joomscan --url "${TARGET_URL}" -ec --no-report || true
  complete_activity
fi

# 6) Drupwn
if scanner_selected "drupwn"; then
  run_cms_tool_if_available "Drupwn" "drupal" "${DEFAULT_TIMEOUT}" "drupwn" drupwn --mode enum --target "${TARGET_URL}" --users --nodes --modules --dfiles --themes --thread 4 || true
  complete_activity
fi

# 7) VBScan
if scanner_selected "vbscan"; then
  run_cms_tool_if_available "VBScan" "vbulletin" "${DEFAULT_TIMEOUT}" "vbscan" vbscan "${TARGET_URL}" || true
  complete_activity
fi

# 8) VulnX
if scanner_selected "vulnx"; then
  run_tool_if_available "VulnX" "${DEFAULT_TIMEOUT}" "vulnx" vulnx -u "${TARGET_URL}" --cms || true
  complete_activity
fi

# 9) WPSeku
if scanner_selected "wpseku"; then
  run_cms_tool_if_available "WPSeku" "wordpress" "${DEFAULT_TIMEOUT}" "wpseku" env PYTHONWARNINGS=ignore::SyntaxWarning wpseku --url "${TARGET_URL}" || true
  complete_activity
fi

# 10) WPForce (requires username and password lists)
if scanner_selected "wpforce"; then
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
  complete_activity
fi

# 11) WPXF (interactive framework, scripted best-effort)
if scanner_selected "wpxf"; then
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
  complete_activity
fi

# 12) joomlavs
if scanner_selected "joomlavs"; then
  run_cms_tool_if_available "joomlavs" "joomla" "${DEFAULT_TIMEOUT}" "joomlavs" joomlavs -u "${TARGET_URL}" -q --hide-banner || true
  complete_activity
fi

# 13) Fingerprinter (repo script)
if scanner_selected "fingerprinter"; then
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
      run_tool "Fingerprinter" "${DEFAULT_TIMEOUT}" bash -c \
        'cd "$1" && exec ruby fingerprinter.rb --app-name "$2" --passive-fingerprint "$3" --verbose' \
        _ "${TOOLS_DIR}/fingerprinter" "${FINGERPRINTER_APP}" "${TARGET_URL}"
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
  complete_activity
fi

# 14) AutoWPScan (single-target function call)
AUTOWPSCAN_RUNTIME_DIR="${TOOLS_DIR}/.compat/autowpscan-src"
if scanner_selected "autowpscan"; then
  if should_run_for_detected_cms "wordpress"; then
    if [[ ! -x "${PYTHON_BIN}" ]]; then
      append_skip "AutoWPScan" "canonical Python runtime not found at ${PYTHON_BIN}"
    elif [[ -f "${AUTOWPSCAN_RUNTIME_DIR}/main.py" ]]; then
      run_tool "AutoWPScan" "${DEFAULT_TIMEOUT}" env TARGET_URL_ENV="${TARGET_URL}" AUTOWPSCAN_SRC_ENV="${AUTOWPSCAN_RUNTIME_DIR}" AUTOWPSCAN_HOME_ENV="${REPORTS_DIR}" WPSCAN_API_TOKEN="${WPSCAN_API_TOKEN:-}" WPSCAN_CACHE_DIR="${WPSCAN_CACHE_DIR}" WPSCAN_COOKIE_JAR="${WPSCAN_COOKIE_JAR}" "${PYTHON_BIN}" -c "import os,sys; sys.path.insert(0,os.environ['AUTOWPSCAN_SRC_ENV']); import main; main._home_path=os.environ['AUTOWPSCAN_HOME_ENV']; main._wpscan_api_token=os.environ.get('WPSCAN_API_TOKEN',''); print(main.run_wpscan(os.environ['TARGET_URL_ENV'],'single-target','0'))"
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
        reclassify_last_tool_as_skip "AutoWPScan returned scan_aborted; likely upstream/rate-limit related"
        {
          echo "Post-Processing: Reclassified as SKIP"
          echo "Reason         : AutoWPScan returned scan_aborted; likely upstream/rate-limit related"
          echo
        } >>"${REPORT_FILE}"
      fi
    else
      append_skip "AutoWPScan" "AutoWPScan main.py not found"
    fi
  else
    skip_not_applicable "AutoWPScan" "wordpress"
  fi
  complete_activity
fi

# 15) AEM Detector (aem-hacker)
if scanner_selected "aem-hacker"; then
  run_cms_tool_if_available "AEM Detector (aem-hacker)" "aem" "${DEFAULT_TIMEOUT}" "aem-hacker" aem-hacker -u "${TARGET_URL}" --workers 4 || true
  complete_activity
fi

# 16) AEM discoverer
if scanner_selected "aem-discoverer"; then
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
  complete_activity
fi

# 17) CMSScan workflow
CMSSCAN_RUNTIME_DIR="${TOOLS_DIR}/.compat/cmsscan-src"
if [[ ! -f "${CMSSCAN_RUNTIME_DIR}/plugins/scanners.py" ]]; then
  CMSSCAN_RUNTIME_DIR="${TOOLS_DIR}/CMSScan"
fi
if scanner_selected "cmsscan"; then
  if [[ -d "${CMSSCAN_RUNTIME_DIR}" ]]; then
    CMSSCAN_PY="$(find_cmsscan_python || true)"
    if [[ -n "${CMSSCAN_PY}" ]]; then
      if [[ "${CMSSCAN_FULL_WORKFLOW}" == "1" ]]; then
        run_tool "CMSScan (plugin workflow)" "${CMSSCAN_FULL_TIMEOUT}" env TARGET_URL_ENV="${TARGET_URL}" CMSSCAN_SRC_ENV="${CMSSCAN_RUNTIME_DIR}" "${CMSSCAN_PY}" -c "import os,sys; sys.path.insert(0,os.environ['CMSSCAN_SRC_ENV']); from plugins.scanners import find_cms,wpscan,droopescan,joomscan,vbscan; u=os.environ['TARGET_URL_ENV']; c=find_cms(u); print('detected_cms='+c); print((wpscan(u) if c=='wordpress' else droopescan(u) if c=='drupal' else joomscan(u) if c=='joomla' else vbscan(u) if c=='vbulletin' else 'No mapped scanner for detected CMS'))"
      else
        run_tool "CMSScan (detector workflow)" "${DEFAULT_TIMEOUT}" env TARGET_URL_ENV="${TARGET_URL}" CMSSCAN_SRC_ENV="${CMSSCAN_RUNTIME_DIR}" "${CMSSCAN_PY}" -c "import os,sys; sys.path.insert(0,os.environ['CMSSCAN_SRC_ENV']); from plugins.scanners import find_cms; u=os.environ['TARGET_URL_ENV']; c=find_cms(u); m={'wordpress':'wpscan','drupal':'droopescan','joomla':'joomscan','vbulletin':'vbscan'}.get(c,'none'); print('detected_cms='+c); print('mapped_scanner='+m); print('full_workflow=disabled')"
      fi
    else
      append_skip "CMSScan workflow" "canonical Python runtime not found at ${PYTHON_BIN}"
    fi
  else
    append_skip "CMSScan workflow" "CMSScan runtime directory not found"
  fi
  complete_activity
fi

write_progress 96
append_section_header "Execution Overview"
{
  echo "Target URL      : ${TARGET_URL}"
  echo "Detected CMS    : ${DETECTED_CMS}"
  echo "Tor routing     : $([[ "${TOR_ENABLED}" -eq 1 ]] && printf 'enabled (%s)' "${TOR_PROXY_URL}" || printf 'disabled')"
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
write_progress 99
if [[ ! -s "${REPORT_FILE}" ]] \
    || ! grep -q '^Report generated at   :' "${REPORT_FILE}"; then
  log "ERROR: consolidated report publication could not be verified"
  exit 1
fi
write_progress 100
apply_output_ownership "${REPORT_FILE}" "${CMSSCAN_PROGRESS_PATH}" "${CMSSCAN_LOG_PATH}"
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
