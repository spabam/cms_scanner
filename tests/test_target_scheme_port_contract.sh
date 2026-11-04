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

# Regression coverage for the cmsscan target contract: an explicitly supplied
# scheme or port is part of the authorized scope and must never be replaced by
# an nmap probe. The historical bug used `[[ -z PROTO || -z PORT ]]`, so
# `cmsscan example.com:8080` probed 443, found it open, and silently rescoped
# the run to https://example.com:443.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT_DIR}/run_cms_scanner.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cms-target-contract.XXXXXX")"

cleanup() {
  find "$TEST_ROOT" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Replay the runner's resolution stage in isolation: source only the parser,
# then run the same scheme/port decision the runner makes. `port_open_nmap` is
# stubbed to always report "open" — exactly the condition under which the old
# code silently overrode an explicit scheme or port.
resolve_target() {
  local raw="$1"

  RAW_TARGET="$raw" RUNNER="$RUNNER" bash -c '
    set -Eeuo pipefail

    # Pull in only extract_host_port_path from the runner.
    eval "$(sed -n "/^extract_host_port_path() {/,/^}/p" "$RUNNER")"

    port_open_nmap() { return 0; }          # 443 and 80 always "open"
    url_reachable_via_tor() { return 0; }
    TOR_ENABLED=0
    NMAP_443_OUT=/dev/null
    NMAP_80_OUT=/dev/null

    IFS="|" read -r INPUT_PROTO INPUT_HOST INPUT_PORT INPUT_PATH \
      < <(extract_host_port_path "$RAW_TARGET")

    PROTO="$INPUT_PROTO"
    HOST="$INPUT_HOST"
    PORT="$INPUT_PORT"
    URL_PATH="$INPUT_PATH"

    # Replay the resolution block from the runner verbatim.
    eval "$(sed -n "/^# Probing may only run when BOTH/,/^fi$/p" "$RUNNER")"

    printf "%s://%s:%s%s\n" "$PROTO" "$HOST" "$PORT" "$URL_PATH"
  '
}

# --- an explicit port is never overridden -----------------------------------
got="$(resolve_target 'example.com:8080')"
[[ "$got" == 'http://example.com:8080' ]] \
  || fail "explicit port was overridden: got '$got', want 'http://example.com:8080'"

got="$(resolve_target 'example.com:8443')"
[[ "$got" == 'https://example.com:8443' ]] \
  || fail "explicit alt-https port was overridden: got '$got'"

got="$(resolve_target 'example.com:8080/wp')"
[[ "$got" == 'http://example.com:8080/wp' ]] \
  || fail "explicit port with a path was overridden: got '$got'"

# --- an explicit scheme is never overridden ---------------------------------
got="$(resolve_target 'http://example.com')"
[[ "$got" == 'http://example.com:80' ]] \
  || fail "explicit http scheme was upgraded: got '$got', want 'http://example.com:80'"

got="$(resolve_target 'https://example.com')"
[[ "$got" == 'https://example.com:443' ]] \
  || fail "explicit https scheme did not derive port 443: got '$got'"

# --- an explicit scheme AND port are both preserved -------------------------
got="$(resolve_target 'http://example.com:8080/path')"
[[ "$got" == 'http://example.com:8080/path' ]] \
  || fail "explicit scheme+port pair was rewritten: got '$got'"

# --- only a bare host still probes ------------------------------------------
got="$(resolve_target 'example.com')"
[[ "$got" == 'https://example.com:443' ]] \
  || fail "bare host did not use the nmap probe result: got '$got'"

printf 'CMS scanner target scheme/port contract tests passed.\n'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
