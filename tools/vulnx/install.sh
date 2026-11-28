#!/bin/bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036

SCRIPT_DIR="$(cd -P -- "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VANTAGE_VERSION_GUARD="${SCRIPT_DIR}/../../../scripts/installer_version_guard.sh"
CMS_RUNTIME_HELPER="${SCRIPT_DIR}/../../scripts/cms_component_runtime.sh"
if [[ -r "${VANTAGE_VERSION_GUARD}" ]]; then
    # shellcheck source=../../../scripts/installer_version_guard.sh
    source "${VANTAGE_VERSION_GUARD}"
else
    echo "Missing WA-SCAN version guard: ${VANTAGE_VERSION_GUARD}" >&2
    exit 1
fi
if [[ ! -r "${CMS_RUNTIME_HELPER}" || -L "${CMS_RUNTIME_HELPER}" ]]; then
    echo "Missing CMS component runtime helper: ${CMS_RUNTIME_HELPER}" >&2
    exit 69
fi
trap vantage_cleanup_registered_temps EXIT

# shellcheck disable=SC2034 # consumed by the sourced version guard.
FORCE_INSTALL=0
for installer_arg in "$@"; do
    case "${installer_arg}" in
        --force) FORCE_INSTALL=1 ;;
        -h|--help)
            echo "Usage: ./install.sh [--force]"
            exit 0
            ;;
        *)
            echo "Unknown option: ${installer_arg}" >&2
            exit 2
            ;;
    esac
done
export FORCE_INSTALL

red="\e[0;31m"
# shellcheck disable=SC2034 # retained upstream output-palette compatibility.
blue="\e[0;94m"
green="\e[0;32m"
off="\e[0m"

vantage_require_runtime_identity || exit $?
vantage_runtime_resolve_identity || exit $?
# shellcheck source=/dev/null
source "${CMS_RUNTIME_HELPER}"
cms_component_runtime_bind || exit $?
canonical_python="${CMS_RUNTIME_PYTHON}"

# The shared version guard delegates Python metadata checks through this local
# spelling. Keep those checks in the same CMS-scoped environment as installs.
function vantage_runtime_python_exec() {
    local python_bin="${1:-}"
    [[ -n "${python_bin}" ]] || return 64
    shift
    cms_component_runtime_run_as_user "${python_bin}" "$@"
}

function ensureCanonicalPython() {
    if [ ! -x "${canonical_python}" ]; then
        [ -x /usr/bin/python3 ] || return 69
        cms_component_runtime_run_as_user /usr/bin/mkdir -p \
            "${CMS_RUNTIME_ROOT}"
        cms_component_runtime_run_as_user /usr/bin/python3 -m venv \
            "${CMS_RUNTIME_VENV}"
    fi
}

function sourceCommit() {
    git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || true
}

function onlineCommit() {
    vantage_git_remote_head https://github.com/anouarbensaad/vulnx.git || true
}

function vulnxComponentRuntimeIsUsable() {
    [[ -x "${canonical_python}" ]] || return 1
    cms_component_runtime_run_as_user "${canonical_python}" -c \
        'import bs4, requests' >/dev/null 2>&1
}

function installedSourceIsCurrent() {
    local install_root="$1"
    local wrapper="$2"
    local bundled_wrapper="${SCRIPT_DIR}/../../bin/vulnx"
    local installed_commit=""
    local online_commit=""

    vantage_force_requested && return 1
    vulnxComponentRuntimeIsUsable || return 1
    online_commit="$(onlineCommit)"
    [[ "${online_commit}" =~ ^[0-9a-fA-F]{40,64}$ ]] || return 1

    if [[ -x "${wrapper}" && -f "${install_root}/.vantage-upstream-commit" ]]; then
        installed_commit="$(head -n 1 "${install_root}/.vantage-upstream-commit" 2>/dev/null || true)"
        if [[ "${installed_commit}" =~ ^[0-9a-fA-F]{40,64}$ &&
              "${installed_commit,,}" == "${online_commit,,}" ]]; then
            return 0
        fi
    fi

    # The WA-SCAN CMS installer manages this same checkout through its own
    # functional wrapper. Treat that installation as authoritative so a direct
    # invocation of this bundled installer does not create a duplicate
    # /usr/share/vulnx installation when the managed copy is already current.
    installed_commit="$(sourceCommit)"
    [[ -x "${bundled_wrapper}" &&
       "${installed_commit}" =~ ^[0-9a-fA-F]{40,64}$ &&
       "${installed_commit,,}" == "${online_commit,,}" ]]
}

function installPythonRequirements() {
    local requirement=""
    local package=""
    local -a pending=()
    local -a force_args=()

    for requirement in requests bs4; do
        package="${requirement}"
        if vantage_pypi_package_current "${canonical_python}" "${package}"; then
            echo -e "$red [$green+$red]$off Skipping ${package}; installed version is current/newer than PyPI."
        else
            pending+=("${requirement}")
        fi
    done
    [[ "${#pending[@]}" -gt 0 ]] || return 0
    vantage_force_requested && force_args=(--force-reinstall)
    cms_component_runtime_run_as_user "${canonical_python}" -m pip install --no-cache-dir \
        --upgrade --upgrade-strategy only-if-needed \
        "${force_args[@]}" "${pending[@]}"
}

function writeSourceStamp() {
    local install_root="$1"
    local commit=""

    commit="$(sourceCommit)"
    [[ "${commit}" =~ ^[0-9a-fA-F]{40,64}$ ]] || commit="$(onlineCommit)"
    [[ "${commit}" =~ ^[0-9a-fA-F]{40,64}$ ]] || return 1
    printf '%s\n' "${commit}" >"${install_root}/.vantage-upstream-commit"
}

function writeVulnxLauncher() {
    local destination="$1"
    local runtime_script="$2"
    local shell_path="$3"

    [[ "${runtime_script}" == /* && "${shell_path}" == /* ]] || return 77
    {
        printf '#!%s\n' "${shell_path}"
        printf 'VULNX_SCRIPT=%q\n' "${runtime_script}"
        /usr/bin/cat <<'LAUNCHER'
set -euo pipefail
RUNTIME_HELPER=/usr/libexec/vantage/runtime-identity.sh
if [[ ! -f "${RUNTIME_HELPER}" || -L "${RUNTIME_HELPER}" ||
      ! -r "${RUNTIME_HELPER}" ]]; then
    printf 'vulnx: trusted VANTAGE runtime helper is unavailable\n' >&2
    exit 69
fi
runtime_metadata="$(/usr/bin/stat -c '%u:%a:%h' -- "${RUNTIME_HELPER}" 2>/dev/null || true)"
runtime_mode="${runtime_metadata#*:}"
runtime_mode="${runtime_mode%%:*}"
if [[ "${runtime_metadata%%:*}" != 0 || "${runtime_metadata##*:}" != 1 ||
      ! "${runtime_mode}" =~ ^[0-7]{3,4}$ ]] ||
    (( (8#${runtime_mode} & 8#022) != 0 )); then
    printf 'vulnx: trusted VANTAGE runtime helper has unsafe metadata\n' >&2
    exit 77
fi
# shellcheck source=/dev/null
source "${RUNTIME_HELPER}"
vantage_runtime_resolve_identity || exit $?
CMS_RUNTIME_ROOT="${VANTAGE_RUNTIME_HOME}/.local/share/vantage/cms_scanner"
CMS_RUNTIME_VENV="${CMS_RUNTIME_ROOT}/venv"
CMS_RUNTIME_PYTHON="${CMS_RUNTIME_VENV}/bin/python"
CMS_RUNTIME_PATH="${CMS_RUNTIME_VENV}/bin:${VANTAGE_RUNTIME_PRIVATE_DIR}:${VANTAGE_RUNTIME_HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
[[ -x "${CMS_RUNTIME_PYTHON}" && -f "${VULNX_SCRIPT}" ]] || exit 69
vantage_runtime_run_as_user /usr/bin/env \
    "HOME=${VANTAGE_RUNTIME_HOME}" \
    "USER=${VANTAGE_RUNTIME_USER}" \
    "LOGNAME=${VANTAGE_RUNTIME_USER}" \
    "VIRTUAL_ENV=${CMS_RUNTIME_VENV}" \
    "PATH=${CMS_RUNTIME_PATH}" \
    PYTHONNOUSERSITE=1 \
    PIP_REQUIRE_VIRTUALENV=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    "${CMS_RUNTIME_PYTHON}" "${VULNX_SCRIPT}" "$@"
LAUNCHER
    } >"${destination}"
}

#vulnx install function for Android. termux
function banner(){
    echo -e "===== VULNX INSTALL ====="
}

function termuxOS() {
    local launcher_tmp=""
    if installedSourceIsCurrent \
        "/data/data/com.termux/files/usr/share/vulnx" \
        "/data/data/com.termux/files/usr/bin/vulnx"; then
        echo -e "$red [$green+$red]$off VulnX is already at the current upstream revision; skipping."
        return 0
    fi
    echo -e "$red [$green+$red]$off Installing Python ...";
    if vantage_force_requested; then
        pkg reinstall python
    elif ! vantage_apt_package_current python; then
        pkg install python
    fi
    echo -e "$red [$green+$red]$off Installing Packages ...";
    ensureCanonicalPython
    installPythonRequirements
    echo -e "$red [$green+$red]$off Checking directories ..."
    if [ -e "/data/data/com.termux/files/usr/share/vulnx" ]; then
        echo -e "$red [$green+$red]$off A previous installation was found Do you want to replace it? [Y/n]: "
        read replace
        if [ "$replace" == "y" ] || [ "$replace" == "Y" ] || [ -z "$replace" ]; then
            rm -r "/data/data/com.termux/files/usr/share/vulnx"
            rm "/data/data/com.termux/files/usr/bin/vulnx"
        else
            echo -e "$red [$green✘$red]$off If You Want To Install You Must Remove Previous Installations";
            echo -e "$red [$green✘$red]$off Installation Failed";
            exit
        fi
    fi
    echo -e "$red [$green+$red]$off Installing ...";
    mkdir "/data/data/com.termux/files/usr/share/vulnx" 
    cp "vulnx.py" "/data/data/com.termux/files/usr/share/vulnx"
    cp "install.sh" "/data/data/com.termux/files/usr/share/vulnx"
    cp "update.sh" "/data/data/com.termux/files/usr/share/vulnx"
    cp -r "./common" "/data/data/com.termux/files/usr/share/vulnx"
    cp -r "./modules" "/data/data/com.termux/files/usr/share/vulnx"
    cp -r "./shell" "/data/data/com.termux/files/usr/share/vulnx"
    writeSourceStamp "/data/data/com.termux/files/usr/share/vulnx"
    chmod +x /data/data/com.termux/files/usr/share/vulnx/update.sh
    echo -e "$red [$green+$red]$off Creating Symbolic Link ...";
    vantage_make_temp launcher_tmp || return 1
    writeVulnxLauncher "${launcher_tmp}" \
        /data/data/com.termux/files/usr/share/vulnx/vulnx.py \
        /data/data/com.termux/files/usr/bin/bash || return 1
    chmod +x "${launcher_tmp}"
    cp "${launcher_tmp}" "/data/data/com.termux/files/usr/bin/vulnx"
    chmod +x "/data/data/com.termux/files/usr/bin/vulnx"
    if [ -d "/data/data/com.termux/files/usr/share/vulnx" ] ;
    then
        echo -e "$red [$green+$red]$off Tool successfully installed and will start in 5s!";
        echo -e "$red [$green+$red]$off You can execute tool by typing vulnx"
        sleep 5;
        cms_component_runtime_run_as_user "${canonical_python}" \
            /data/data/com.termux/files/usr/share/vulnx/vulnx.py
    else
        echo -e "$red [$green✘$red]$off Tool Cannot Be Installed On Your System! Use It As Portable !";
        exit
    fi
}

#vulnx install function for debian operating system. linux.
function debianOS(){
    local -a apt_packages=()
    local launcher_tmp=""
    if installedSourceIsCurrent "/usr/share/vulnx" "/usr/local/bin/vulnx"; then
        echo -e "$red [$green+$red]$off VulnX is already at the current upstream revision; skipping."
        return 0
    fi
    echo -e "$red [$green+$red]$off Installing python3... ";
    sudo apt-get update -qq
    mapfile -t apt_packages < <(vantage_filter_apt_packages python3 python3-venv)
    if [[ "${#apt_packages[@]}" -gt 0 ]]; then
        if vantage_force_requested; then
            sudo apt-get install -y --reinstall "${apt_packages[@]}"
        else
            sudo apt-get install -y "${apt_packages[@]}"
        fi
    fi
    ensureCanonicalPython
    installPythonRequirements
    echo -e "$red [$green+$red]$off Checking directories... "
    if [ -d "/usr/share/VulnX" ]; then
        echo -e "$red [$green+$red]$off A Directory VulnX Was Found! Do You Want To Replace It? [Y/n]:" ;
        read replace
        if [ "$replace" == "y" ] || [ "$replace" == "Y" ] || [ -z "$replace" ]; then
            sudo rm -r "/usr/share/vulnx"
            sudo rm "/usr/share/icons/vulnxicon.png"
            sudo rm "/usr/share/applications/vulnx.desktop"
            sudo rm "/usr/local/bin/vulnx"
        else
            echo -e "$red [$green✘$red]$off If You Want To Install You Must Remove Previous Installations";
            echo -e "$red [$green✘$red]$off Installation Failed";
            exit
        fi
    fi 
    echo -e "$red [$green+$red]$off Installing ...";
    echo -e "$red [$green+$red]$off Creating Symbolic Link ...";
    vantage_make_temp launcher_tmp || return 1
    writeVulnxLauncher "${launcher_tmp}" /usr/share/vulnx/vulnx.py /bin/bash || return 1
    chmod +x "${launcher_tmp}";
    if [[ ! -d "/usr/share/vulnx" ]];then
    sudo mkdir "/usr/share/vulnx"
    fi
    sudo cp "install.sh" "/usr/share/vulnx"
    sudo cp "update.sh" "/usr/share/vulnx"
    sudo cp -r "./common" "/usr/share/vulnx/"
    sudo cp -r "./modules" "/usr/share/vulnx/"
    sudo cp -r "./shell" "/usr/share/vulnx/"
    source_commit="$(sourceCommit)"
    [[ "${source_commit}" =~ ^[0-9a-fA-F]{40,64}$ ]] || source_commit="$(onlineCommit)"
    if [[ "${source_commit}" =~ ^[0-9a-fA-F]{40,64}$ ]]; then
        printf '%s\n' "${source_commit}" |
            sudo tee "/usr/share/vulnx/.vantage-upstream-commit" >/dev/null
    fi
    sudo chmod +x /usr/share/vulnx/update.sh
    sudo cp "vulnx.py" "/usr/share/vulnx"
    sudo cp "bin/vulnxicon.png" "/usr/share/icons"
    sudo cp "bin/vulnx.desktop" "/usr/share/applications"
    sudo cp "${launcher_tmp}" "/usr/local/bin/vulnx"
    if [ -d "/usr/share/vulnx" ] ;
    then
        echo -e "$red [$green+$red]$off Tool Successfully Installed And Will Start In 5s!";
        echo -e "$red [$green+$red]$off You can execute tool by typing vulnx"
        sleep 5;
        cms_component_runtime_run_as_user "${canonical_python}" \
            /usr/share/vulnx/vulnx.py
    else
        echo -e "$red [$green✘$red]$off Tool Cannot Be Installed On Your System! Use It As Portable !";
        exit
    fi 
}
#main
if [[ $UID -eq 0 ]]; then
if [ -d "/data/data/com.termux/files/usr/" ]; then
    banner
    echo -e "$red [$green+$red]$off Vulnx Will Be Installed In Your System";
    termuxOS
elif [ -d "/usr/bin/" ];then
    banner
    echo -e "$red [$green+$red]$off Vulnx Will Be Installed In Your System";
    debianOS
else
    echo -e "$red [$green✘$red]$off Tool Cannot Be Installed On Your System! Use It As Portable !";
    exit
fi
else
    echo "You must run as root..."
fi
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
