#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cmsscan-progress-test.XXXXXXXX")"

cleanup() {
  if [[ -d "${WORK_DIR}" && ! -L "${WORK_DIR}" ]]; then
    find "${WORK_DIR}" -depth -delete
  fi
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "${WORK_DIR}/bin" "${WORK_DIR}/run" "${WORK_DIR}/reports" \
  "${WORK_DIR}/logs" "${WORK_DIR}/tmp"
RUNTIME_HOME="${WORK_DIR}/runtime-home"
mkdir -p "${RUNTIME_HOME}/.local/share/vantage/cms_scanner/venv/bin"
ln -s "$(command -v python3)" \
  "${RUNTIME_HOME}/.local/share/vantage/cms_scanner/venv/bin/python"
cat >"${WORK_DIR}/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"${WORK_DIR}/bin/nmap" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf '%s\n' 'Nmap version 7.991 ( https://nmap.org )'
fi
exit 0
EOF
cat >"${WORK_DIR}/bin/cmseek" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'mock CMSeeK completed'
EOF
cat >"${WORK_DIR}/bin/id" <<'EOF'
#!/usr/bin/env bash
if [[ "$#" == 1 && "$1" == -un ]]; then
  printf '%s\n' aiuser
  exit 0
fi
exec /usr/bin/id "$@"
EOF
cat >"${WORK_DIR}/bin/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == passwd && "\${2:-}" == aiuser ]]; then
  printf 'aiuser:x:%s:%s::${RUNTIME_HOME}:/bin/bash\n' \
    "\$(/usr/bin/id -u)" "\$(/usr/bin/id -g)"
  exit 0
fi
exec /usr/bin/getent "\$@"
EOF
chmod 0755 "${WORK_DIR}/bin/curl" "${WORK_DIR}/bin/nmap" \
  "${WORK_DIR}/bin/cmseek" "${WORK_DIR}/bin/id" "${WORK_DIR}/bin/getent"

# Production identity resolution uses absolute paths. Exercise a private test
# copy whose two account commands are replaced with deterministic fixtures;
# do not weaken the maintained runner with a source-test bypass.
sed -e "s|/usr/bin/id|${WORK_DIR}/bin/id|g" \
    -e "s|/usr/bin/getent|${WORK_DIR}/bin/getent|g" \
    "${CMS_DIR}/run_cms_scanner.sh" >"${WORK_DIR}/run/run_cms_scanner.sh"
chmod 0755 "${WORK_DIR}/run/run_cms_scanner.sh"
chmod -R a+rX "${WORK_DIR}"
chmod 0777 "${WORK_DIR}/run" "${WORK_DIR}/reports" "${WORK_DIR}/logs" "${WORK_DIR}/tmp"

run_fixture() {
  local managed="$1" progress_file="$2" log_file="$3"
  local -a command=(
    env
    "PATH=${WORK_DIR}/bin:${PATH}"
    "VANTAGE_RUNTIME_PATH=${WORK_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    "VANTAGE_DISPATCHED=1"
    "VANTAGE_RUNTIME_UID=$(/usr/bin/id -u)"
    "TMPDIR=${WORK_DIR}/tmp"
    "CMS_SCANNER_REPORTS_DIR=${WORK_DIR}/reports"
    "CMS_SCANNER_LOGS_DIR=${WORK_DIR}/logs"
    "VAPTSCAN_MANAGED_PROGRESS=${managed}"
    bash "${WORK_DIR}/run/run_cms_scanner.sh"
    --scanner cmseek
    --progress-file "${progress_file}"
    --log-file "${log_file}"
    https://example.test:443
  )
  if [[ "${EUID}" -eq 0 ]] && command -v runuser >/dev/null 2>&1; then
    (cd "${WORK_DIR}/run" && runuser -u nobody -- "${command[@]}")
  else
    (cd "${WORK_DIR}/run" && "${command[@]}")
  fi
}

progress_file="${WORK_DIR}/run/cmsscan.progress"
log_file="${WORK_DIR}/run/cmsscan.log"
# Simulate reusing an explicit path left at 100 by an earlier invocation. The
# direct runner must reset it to zero before advancing this run.
printf '100' >"${progress_file}"
output="$(run_fixture 0 "${progress_file}" "${log_file}" 2>&1)"

[[ "$(<"${progress_file}")" == 100 ]] || fail 'successful report did not publish 100'
[[ -s "${log_file}" ]] || fail 'paired log was not written'
[[ "$(stat -c '%a' "${progress_file}")" == 600 ]] || fail 'progress mode is not 0600'
[[ "$(stat -c '%a' "${log_file}")" == 600 ]] || fail 'log mode is not 0600'
grep -Fq 'Progress: [--------------------------------]   0.0%' <<<"${output}" \
  || fail 'canonical zero line missing'
grep -Fq 'Progress: [################################] 100.0%' <<<"${output}" \
  || fail 'canonical completion line missing'
grep -Fq 'Progress: [##############################--]  94.0%' <<<"${output}" \
  || fail 'selected activity did not reach the dynamic activity boundary'
find "${WORK_DIR}/reports" -type f -name '*.cms.txt' -size +0c -print -quit | grep -q . \
  || fail 'mock consolidated report was not published'

managed_progress="${WORK_DIR}/run/managed.progress"
managed_log="${WORK_DIR}/run/managed.log"
managed_output="$(run_fixture 1 "${managed_progress}" "${managed_log}" 2>&1)"
[[ "$(<"${managed_progress}")" == 100 ]] || fail 'managed progress did not reach 100'
if grep -q 'Progress:' <<<"${managed_output}"; then
  fail 'managed mode leaked progress to stdout'
fi
grep -Fq 'Progress: [################################] 100.0%' "${managed_log}" \
  || fail 'managed mode did not preserve progress in the paired log'

printf '%s\n' 'PASS: cmsscan progress contract (no network)'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
