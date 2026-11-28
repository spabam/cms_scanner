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
canonical_python="${CMS_RUNTIME_PYTHON}"

cms_component_runtime_run_as_user /bin/sh -c \
    'command -v gem >/dev/null 2>&1' || \
    { echo "gem not found in this system. Exiting."; exit 1; }
cms_component_runtime_run_as_user gem install --user-install wpscan
cms_component_runtime_run_as_user wpscan --update

[ -x /usr/bin/python3 ] || { echo "python3 not found in this system. Exiting."; exit 1; }
if [ ! -x "${canonical_python}" ]; then
    cms_component_runtime_run_as_user /usr/bin/mkdir -p "$CMS_RUNTIME_ROOT"
    cms_component_runtime_run_as_user /usr/bin/python3 -m venv "$CMS_RUNTIME_VENV"
fi
cms_component_runtime_run_as_user "${canonical_python}" -m pip install --upgrade pip
cms_component_runtime_run_as_user "${canonical_python}" -m pip install \
    --no-cache-dir -r "${SCRIPT_DIR}/requirements.txt"

# Source-control updates belong to the checkout owner, not to the fixed scan
# account.  In particular, never let a root invocation modify a user checkout
# and never ask aiuser to write into an unrelated caller's working tree.
update_checkout_sources() {
    local current_uid="" owner="" path=""
    local -a owned_paths=(
        "$SCRIPT_DIR"
        "$SCRIPT_DIR/.git"
        "$SCRIPT_DIR/plugins"
        "$SCRIPT_DIR/plugins/vbscan"
        "$SCRIPT_DIR/plugins/vbscan/.git"
        "$SCRIPT_DIR/plugins/joomscan"
        "$SCRIPT_DIR/plugins/joomscan/.git"
    )

    current_uid="$(/usr/bin/id -u)" || return 69
    case "$current_uid" in
        ''|0|*[!0-9]*)
            printf 'Skipping CMSScan source updates: invoke setup as the non-root checkout owner.\n' >&2
            return 0
            ;;
    esac
    for path in "${owned_paths[@]}"; do
        if [[ ! -e "$path" || -L "$path" ]]; then
            printf 'Skipping CMSScan source updates: unsafe or incomplete checkout metadata.\n' >&2
            return 0
        fi
        owner="$(/usr/bin/stat -c '%u' -- "$path" 2>/dev/null)" || return 73
        if [[ "$owner" != "$current_uid" ]]; then
            printf 'Skipping CMSScan source updates: the invoking user does not own the checkout.\n' >&2
            return 0
        fi
    done

    [[ -x /usr/bin/git ]] || \
        { echo "git not found in this system. Exiting."; return 1; }
    /usr/bin/git -C "$SCRIPT_DIR" submodule update --init --recursive
    /usr/bin/git -C "$SCRIPT_DIR/plugins/vbscan" pull origin master
    /usr/bin/git -C "$SCRIPT_DIR/plugins/joomscan" pull origin master
}

update_checkout_sources
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
