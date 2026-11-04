#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Source-safe installer adapter loader. Registry fields are data, never eval.

cms_install_registry_load() {
  local registry="$1" directory="$2" id module hook environment role data_policy extra
  local -A seen=()
  CMS_INSTALL_TOOL_IDS=()
  CMS_INSTALL_TOOL_HOOKS=()
  [[ -f "$registry" && ! -L "$registry" ]] || return 69
  while IFS=$'\t' read -r id module hook environment role data_policy extra || [[ -n "$id" ]]; do
    [[ -n "$id" && "$id" != \#* ]] || continue
    [[ "$id" =~ ^[a-z][a-z0-9_]*$ && "$module" == "$id.sh" &&
       "$hook" == "install_$id" && -z "$extra" &&
       -z "${seen[$id]:-}" ]] || return 65
    case "$environment" in ruby|perl|cms-python) ;; *) return 65 ;; esac
    case "$role" in required|auxiliary-required) ;; *) return 65 ;; esac
    case "$data_policy" in none|bounded-required|opt-in-required) ;; *) return 65 ;; esac
    [[ -f "$directory/$module" && ! -L "$directory/$module" ]] || return 69
    # Module names cannot contain separators and only trusted colocated
    # first-party definitions are loaded. No arbitrary registry code runs.
    source "$directory/$module" || return $?
    declare -F "$hook" >/dev/null 2>&1 || return 69
    seen[$id]=1
    CMS_INSTALL_TOOL_IDS+=("$id")
    CMS_INSTALL_TOOL_HOOKS+=("$hook")
  done <"$registry"
  [[ ${#CMS_INSTALL_TOOL_IDS[@]} -gt 0 ]]
}

CMS_EVENT_FAILURE_STATUS=0
cms_installer_event() {
  local VI_PHASE="${VI_PHASE:-inspect}"
  case "$2" in cms.update*) VI_PHASE=configure ;; cms.bundle) VI_PHASE=build ;; esac
  if [[ "${CMS_EVENT_FAILURE_STATUS:-0}" -ne 0 ]]; then
    return "$CMS_EVENT_FAILURE_STATUS"
  fi
  if declare -F vi_event >/dev/null 2>&1; then
    vi_event "$@" || { CMS_EVENT_FAILURE_STATUS=$?; return "$CMS_EVENT_FAILURE_STATUS"; }
  fi
  return 0
}

# Tool and artifact counts are separate. Legacy buckets remain available for
# --strict compatibility, while these results describe actual tool actions.
declare -A CMS_TOOL_ACTIONS=() CMS_TOOL_OUTCOMES=()
cms_tool_run() {
  local hook="$1" id="${1#install_}" skipped_before=${#SKIPPED[@]} status=0
  cms_installer_event START "cms.tool.$id" running inspection_started "$id" || return $?
  if run_tool_installer "$hook"; then status=0; else status=$?; fi
  if [[ "$status" -ne 0 ]]; then
    CMS_TOOL_ACTIONS[$id]=repair
    CMS_TOOL_OUTCOMES[$id]=failed
    cms_installer_event FAIL "cms.tool.$id" failed tool_failed "$id; exit $status" || return $?
    return "$status"
  fi
  CMS_TOOL_OUTCOMES[$id]=succeeded
  if [[ ${#SKIPPED[@]} -gt "$skipped_before" ]]; then
    CMS_TOOL_ACTIONS[$id]=reuse
  else
    CMS_TOOL_ACTIONS[$id]=install
  fi
  cms_installer_event END "cms.tool.$id" succeeded "${CMS_TOOL_ACTIONS[$id]}" "$id verified" || return $?
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
