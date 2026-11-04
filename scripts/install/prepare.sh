#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Read-only source preparation gate. Canonical origins live in the adapters;
# installers no longer need an in-place root-side source rewrite for these tools.

cms_validate_installer_sources() {
    local component="$1" file="" id module hook environment role policy extra
    local -A seen=()
    local registry="$component/scripts/install/tools.tsv"
    [[ -d "$component" && ! -L "$component" && -f "$registry" && ! -L "$registry" ]] || return 69
    for file in installer.sh scripts/install/registry.sh scripts/install/prepare.sh; do
        [[ -f "$component/$file" && ! -L "$component/$file" ]] || return 69
        /bin/bash -n "$component/$file" || return $?
    done
    while IFS=$'\t' read -r id module hook environment role policy extra || [[ -n "$id" ]]; do
        [[ -n "$id" && "$id" != \#* ]] || continue
        [[ "$id" =~ ^[a-z][a-z0-9_]*$ && "$module" == "$id.sh" &&
           "$hook" == "install_$id" && -z "$extra" && -z "${seen[$id]:-}" ]] || return 65
        seen[$id]=1
        file="$component/scripts/install/tools/$module"
        [[ -f "$file" && ! -L "$file" ]] || return 69
        /bin/bash -n "$file" || return $?
    done <"$registry"
    [[ ${#seen[@]} -eq 17 ]] || return 65
    for file in "$component/installer.sh" \
        "$component/scripts/install/tools/fingerprinter.sh" \
        "$component/scripts/install/tools/autowpscan.sh"; do
        if /usr/bin/grep -Eq 'pentesterlab/fingerprinter|ethicalhack3r/AutoWPScan' "$file"; then
            printf 'Error: retired CMS source origin remains in %s\n' "$file" >&2
            return 65
        fi
    done
    /usr/bin/grep -Fq 'https://github.com/erwanlr/Fingerprinter.git' \
        "$component/scripts/install/tools/fingerprinter.sh" || return 65
    /usr/bin/grep -Fq 'https://github.com/password123456/autowpscan.git' \
        "$component/scripts/install/tools/autowpscan.sh" || return 65
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ $# -eq 2 && "$1" == --check-sources ]]; then
        cms_validate_installer_sources "$2"
        exit $?
    fi
    printf 'Usage: %s --check-sources CMS_COMPONENT_DIRECTORY\n' "$0" >&2
    exit 2
fi
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
