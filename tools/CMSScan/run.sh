#!/bin/bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036
set -eu

SCRIPT_DIR="$(cd -P -- "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_IDENTITY_HELPER="${SCRIPT_DIR}/../../../../.runtime_identity.sh"
CMS_RUNTIME_HELPER="${SCRIPT_DIR}/../../scripts/cms_component_runtime.sh"
[[ -r "$RUNTIME_IDENTITY_HELPER" && ! -L "$RUNTIME_IDENTITY_HELPER" ]] || exit 69
[[ -r "$CMS_RUNTIME_HELPER" && ! -L "$CMS_RUNTIME_HELPER" ]] || exit 69
# shellcheck source=/dev/null
. "$RUNTIME_IDENTITY_HELPER"
vantage_runtime_resolve_identity || exit $?
# shellcheck source=/dev/null
. "$CMS_RUNTIME_HELPER"
cms_component_runtime_bind || exit $?

current_uid="$(/usr/bin/id -u)" || exit 69
if [[ "$current_uid" != "$CMS_RUNTIME_UID" || \
      "${VANTAGE_DISPATCHED:-0}" != 1 ]]; then
    # The shared helper authorizes the transition (runuser for root, sudo -n
    # for an explicitly permitted local caller).  The marker prevents the
    # aiuser child from redispatching itself.
    cms_component_runtime_run_as_user /usr/bin/env VANTAGE_DISPATCHED=1 \
        "$SCRIPT_DIR/run.sh" "$@"
    exit $?
fi
unset current_uid

HOME="$CMS_RUNTIME_HOME"
USER="$CMS_RUNTIME_USER"
LOGNAME="$CMS_RUNTIME_USER"
VIRTUAL_ENV="$CMS_RUNTIME_VENV"
PATH="$CMS_RUNTIME_PATH"
PYTHONNOUSERSITE=1
PIP_REQUIRE_VIRTUALENV=1
PIP_DISABLE_PIP_VERSION_CHECK=1
export HOME USER LOGNAME VIRTUAL_ENV PATH PYTHONNOUSERSITE
export PIP_REQUIRE_VIRTUALENV PIP_DISABLE_PIP_VERSION_CHECK
unset PYTHONHOME PYTHONPATH
cd "$SCRIPT_DIR"
exec "$CMS_RUNTIME_PYTHON" -m gunicorn --bind 0.0.0.0:7070 app:app --workers 3 --timeout 10000
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
