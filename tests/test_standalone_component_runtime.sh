#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
set -euo pipefail

TEST_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -P -- "${TEST_DIR}/.." && pwd)"
RUNTIME_HELPER="${PROJECT_ROOT}/scripts/cms_component_runtime.sh"
SETUP_ENTRYPOINT="${PROJECT_ROOT}/tools/CMSScan/setup.sh"
SERVER_ENTRYPOINT="${PROJECT_ROOT}/tools/CMSScan/run.sh"
VULNX_ENTRYPOINT="${PROJECT_ROOT}/tools/vulnx/install.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cms-standalone-runtime.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# shellcheck source=/dev/null
source "$RUNTIME_HELPER"

relocated_home="${TEST_ROOT}/srv/aiuser"
runtime_uid=42424
VANTAGE_RUNTIME_USER=aiuser
VANTAGE_RUNTIME_UID="$runtime_uid"
VANTAGE_RUNTIME_HOME="$relocated_home"
VANTAGE_RUNTIME_PRIVATE_DIR=/opt/infrascan/priv
cms_component_runtime_bind || fail 'relocated passwd home was rejected'

[[ "$CMS_RUNTIME_ROOT" == \
  "${relocated_home}/.local/share/vantage/cms_scanner" ]] ||
  fail 'component data root did not follow the resolved passwd home'
[[ "$CMS_RUNTIME_VENV" == \
  "${relocated_home}/.local/share/vantage/cms_scanner/venv" ]] ||
  fail 'component venv did not follow the resolved passwd home'
[[ "$CMS_RUNTIME_PYTHON" == "${CMS_RUNTIME_VENV}/bin/python" ]] ||
  fail 'component interpreter is inconsistent with the component venv'
[[ "${CMS_RUNTIME_PATH%%:*}" == "${CMS_RUNTIME_VENV}/bin" ]] ||
  fail 'component venv is not first in the sanitized PATH'
if [[ "$CMS_RUNTIME_PATH" == *"${relocated_home}/.venv"* ]]; then
  fail 'sanitized component PATH retained the shared runtime venv'
fi

vantage_runtime_resolve_identity() {
  VANTAGE_RUNTIME_USER=aiuser
  VANTAGE_RUNTIME_UID="$runtime_uid"
  VANTAGE_RUNTIME_HOME="$relocated_home"
  VANTAGE_RUNTIME_PRIVATE_DIR=/opt/infrascan/priv
}
dispatch_log="${TEST_ROOT}/dispatch.log"
vantage_runtime_run_as_user() {
  printf '%s\n' "$1" >>"$dispatch_log"
  "$@"
}

mkdir -p "$CMS_RUNTIME_VENV/bin"
runtime_environment="$({
  HOME=/caller/home \
  VIRTUAL_ENV=/caller/shared-venv \
  PATH=/caller/bin \
    cms_component_runtime_run_as_user /bin/sh -c \
      'printf "%s\n" "$HOME" "$VIRTUAL_ENV" "$PATH" "${PIP_REQUIRE_VIRTUALENV:-}"'
})" || fail 'component command dispatcher rejected a legitimate command'
expected_environment="$(printf '%s\n' \
  "$relocated_home" "$CMS_RUNTIME_VENV" "$CMS_RUNTIME_PATH" 1)"
[[ "$runtime_environment" == "$expected_environment" ]] ||
  fail 'caller HOME, VIRTUAL_ENV, or PATH reached the component command'
[[ "$(cat "$dispatch_log")" == /usr/bin/env ]] ||
  fail 'component command bypassed the fixed runtime-user dispatcher'

vantage_runtime_resolve_identity() {
  VANTAGE_RUNTIME_USER=aiuser
  VANTAGE_RUNTIME_UID="$runtime_uid"
  VANTAGE_RUNTIME_HOME="${relocated_home}/changed"
  VANTAGE_RUNTIME_PRIVATE_DIR=/opt/infrascan/priv
}
if cms_component_runtime_run_as_user /bin/true; then
  fail 'runtime identity drift was accepted after component path binding'
fi

if (
  VANTAGE_RUNTIME_USER=aiuser
  VANTAGE_RUNTIME_UID=0
  VANTAGE_RUNTIME_HOME="$relocated_home"
  VANTAGE_RUNTIME_PRIVATE_DIR=/opt/infrascan/priv
  cms_component_runtime_bind
); then
  fail 'uid 0 was accepted as the CMS runtime identity'
fi
if (
  VANTAGE_RUNTIME_USER=aiuser
  VANTAGE_RUNTIME_UID="$runtime_uid"
  VANTAGE_RUNTIME_HOME=relative/home
  VANTAGE_RUNTIME_PRIVATE_DIR=/opt/infrascan/priv
  export VANTAGE_RUNTIME_USER VANTAGE_RUNTIME_UID VANTAGE_RUNTIME_HOME
  export VANTAGE_RUNTIME_PRIVATE_DIR
  cms_component_runtime_bind
); then
  fail 'a relative passwd home was accepted'
fi

for entrypoint in \
  "$SETUP_ENTRYPOINT" "$SERVER_ENTRYPOINT" "$VULNX_ENTRYPOINT"; do
  grep -Fq 'cms_component_runtime.sh' "$entrypoint" ||
    fail "entrypoint does not use the component runtime helper: $entrypoint"
  if grep -Fq 'VANTAGE_RUNTIME_VENV' "$entrypoint" ||
    grep -Eq '(^|[^[:alnum:]_])\.venv(/|[^[:alnum:]_]|$)' "$entrypoint"; then
    fail "entrypoint still selects a shared .venv: $entrypoint"
  fi
done

grep -Fq \
  'cms_component_runtime_run_as_user /usr/bin/python3 -m venv "$CMS_RUNTIME_VENV"' \
  "$SETUP_ENTRYPOINT" ||
  fail 'CMSScan setup does not create its venv as the runtime user'
grep -Fq \
  'cms_component_runtime_run_as_user "${canonical_python}" -m pip install' \
  "$SETUP_ENTRYPOINT" ||
  fail 'CMSScan setup does not install packages as the runtime user'
if grep -Eq 'cms_component_runtime_run_as_user[[:space:]]+(/usr/bin/)?git' \
  "$SETUP_ENTRYPOINT"; then
  fail 'CMSScan setup still modifies the checkout as the scan runtime user'
fi
grep -Fq 'case "$current_uid" in' "$SETUP_ENTRYPOINT" ||
  fail 'CMSScan setup does not gate source updates on the invoking UID'
grep -Fq "''|0|*[!0-9]*)" "$SETUP_ENTRYPOINT" ||
  fail 'CMSScan setup does not refuse root-owned source updates'
grep -Fq '/usr/bin/stat -c' "$SETUP_ENTRYPOINT" ||
  fail 'CMSScan setup does not verify checkout ownership'
grep -Fq '/usr/bin/git -C "$SCRIPT_DIR" submodule update' \
  "$SETUP_ENTRYPOINT" ||
  fail 'CMSScan setup no longer updates sources as the checkout owner'
grep -Fq 'exec "$CMS_RUNTIME_PYTHON" -m gunicorn' "$SERVER_ENTRYPOINT" ||
  fail 'CMSScan server does not execute the component interpreter'
grep -Fq 'vantage_runtime_resolve_identity || exit $?' "$SERVER_ENTRYPOINT" ||
  fail 'CMSScan server does not resolve the fixed passwd identity'
grep -Fq 'cms_component_runtime_run_as_user /usr/bin/env VANTAGE_DISPATCHED=1' \
  "$SERVER_ENTRYPOINT" ||
  fail 'CMSScan server does not redispatch direct invocations to aiuser'
grep -Fq '"${VANTAGE_DISPATCHED:-0}" != 1' "$SERVER_ENTRYPOINT" ||
  fail 'CMSScan server does not guard against a redispatch loop'
grep -Fq \
  'cms_component_runtime_run_as_user /usr/bin/python3 -m venv' \
  "$VULNX_ENTRYPOINT" ||
  fail 'VulnX installer does not create its venv as the runtime user'
grep -Fq \
  'cms_component_runtime_run_as_user "${canonical_python}" -m pip install' \
  "$VULNX_ENTRYPOINT" ||
  fail 'VulnX installer does not install packages as the runtime user'
grep -Fq 'vulnxComponentRuntimeIsUsable || return 1' "$VULNX_ENTRYPOINT" ||
  fail 'VulnX source-current skip ignores a missing component runtime'
grep -Fq 'RUNTIME_HELPER=/usr/libexec/vantage/runtime-identity.sh' \
  "$VULNX_ENTRYPOINT" ||
  fail 'generated VulnX launcher does not use the trusted runtime helper'
grep -Fq 'vantage_runtime_run_as_user /usr/bin/env' "$VULNX_ENTRYPOINT" ||
  fail 'generated VulnX launcher does not transition to the runtime user'
grep -Fq \
  'CMS_RUNTIME_VENV="${CMS_RUNTIME_ROOT}/venv"' "$VULNX_ENTRYPOINT" ||
  fail 'generated VulnX launcher does not select the component venv'

# Exercise the direct-entrypoint transition without needing a real aiuser or
# touching the live component environment.  The trusted identity fixture
# records the exact command it would execute instead of changing credentials.
fixture_vapt="${TEST_ROOT}/runtime-fixture/VAPT"
fixture_project="${fixture_vapt}/WA-SCAN/cms_scanner"
fixture_server_dir="${fixture_project}/tools/CMSScan"
fixture_runtime_home="${TEST_ROOT}/srv/relocated-aiuser"
fixture_dispatch_log="${TEST_ROOT}/server-dispatch.log"
fixture_current_uid="$(/usr/bin/id -u)"
fixture_uid=$((fixture_current_uid + 1))
(( fixture_uid > 0 )) || fixture_uid=42424
mkdir -p "$fixture_server_dir" "${fixture_project}/scripts"
cp "$SERVER_ENTRYPOINT" "${fixture_server_dir}/run.sh"
cp "$RUNTIME_HELPER" "${fixture_project}/scripts/cms_component_runtime.sh"
cat >"${fixture_vapt}/.runtime_identity.sh" <<'EOF'
#!/usr/bin/env bash
vantage_runtime_resolve_identity() {
  VANTAGE_RUNTIME_USER=aiuser
  VANTAGE_RUNTIME_UID="$CMS_TEST_RUNTIME_UID"
  VANTAGE_RUNTIME_HOME="$CMS_TEST_RUNTIME_HOME"
  VANTAGE_RUNTIME_PRIVATE_DIR=/opt/infrascan/priv
  export VANTAGE_RUNTIME_USER VANTAGE_RUNTIME_UID VANTAGE_RUNTIME_HOME
  export VANTAGE_RUNTIME_PRIVATE_DIR
}
vantage_runtime_run_as_user() {
  printf '%s\0' "$@" >"$CMS_TEST_DISPATCH_LOG"
}
EOF
chmod 0755 "${fixture_server_dir}/run.sh"
CMS_TEST_RUNTIME_UID="$fixture_uid" \
CMS_TEST_RUNTIME_HOME="$fixture_runtime_home" \
CMS_TEST_DISPATCH_LOG="$fixture_dispatch_log" \
HOME=/caller/home VIRTUAL_ENV=/caller/shared-venv PATH=/caller/bin \
  "${fixture_server_dir}/run.sh" --standalone-probe ||
  fail 'direct CMSScan server invocation did not enter the runtime dispatcher'
mapfile -d '' -t server_dispatch <"$fixture_dispatch_log"
[[ "${server_dispatch[0]:-}" == /usr/bin/env ]] ||
  fail 'direct CMSScan server dispatch bypassed the sanitized environment'
printf '%s\n' "${server_dispatch[@]}" | grep -Fxq \
  "HOME=${fixture_runtime_home}" ||
  fail 'direct CMSScan server dispatch trusted the caller HOME'
printf '%s\n' "${server_dispatch[@]}" | grep -Fxq \
  "VIRTUAL_ENV=${fixture_runtime_home}/.local/share/vantage/cms_scanner/venv" ||
  fail 'direct CMSScan server dispatch did not select the component venv'
printf '%s\n' "${server_dispatch[@]}" | grep -Fxq VANTAGE_DISPATCHED=1 ||
  fail 'direct CMSScan server dispatch omitted its loop-prevention marker'
printf '%s\n' "${server_dispatch[@]}" | grep -Fxq \
  "${fixture_server_dir}/run.sh" ||
  fail 'direct CMSScan server dispatch did not preserve the standalone entrypoint'
printf '%s\n' "${server_dispatch[@]}" | grep -Fxq -- --standalone-probe ||
  fail 'direct CMSScan server dispatch did not preserve arguments'

printf 'CMS standalone component-runtime tests passed.\n'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
