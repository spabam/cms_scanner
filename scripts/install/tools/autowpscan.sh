#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

install_autowpscan() {
  local name="AutoWPScan"
  local repo="${TOOLS_DIR}/AutoWPScan"
  local runtime_src="${COMPAT_DIR}/autowpscan-src"
  local candidate_src=""
  local previous_src=""
  local repo_url="https://github.com/password123456/autowpscan.git"

  if ! repo_clone_or_update "$repo_url" "$repo"; then
    mark_failed "$name" "unable to clone or refresh public repository: ${repo_url}"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"

  if [[ -f "${repo}/requirements.txt" ]] && ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi

  if ! prepare_runtime_candidate "${repo}" "${runtime_src}"; then
    mark_failed "$name" "unable to prepare staged runtime source"
    return 0
  fi
  candidate_src="${RUNTIME_CANDIDATE}"

  if [[ -f "${candidate_src}/main.py" ]]; then
    if ! run_user_cmd env AUTOWPSCAN_MAIN="${candidate_src}/main.py" "${VENV_DIR}/bin/python" - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["AUTOWPSCAN_MAIN"])
text = path.read_text(encoding="utf-8", errors="ignore")

text = re.sub(
    r"_wpscan_api_token\s*=.*",
    "_wpscan_api_token = os.environ.get('WPSCAN_API_TOKEN', '').strip()",
    text,
    count=1,
)

def replace_or_append(src, func_name, new_block):
    pattern = rf"^def {func_name}\(.*?(?=^def |\Z)"
    if re.search(pattern, src, flags=re.S | re.M):
        return re.sub(pattern, new_block + "\n\n", src, count=1, flags=re.S | re.M)
    return src.rstrip() + "\n\n" + new_block + "\n"

new_run_wpscan = """def run_wpscan(scan_url, scan_name, tg_chat_id):
    today = datetime.now(timezone.utc).astimezone()
    output_file_name = f'{_home_path}/{today.strftime("%Y%m%d")}' \\
                       f'_{create_job_id()}_{scan_url.replace("https://", "").replace("/", "")}_wpscan_result.json'

    cache_dir = os.environ.get('WPSCAN_CACHE_DIR', '').strip()
    cookie_jar = os.environ.get('WPSCAN_COOKIE_JAR', '').strip()
    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
    if cookie_jar:
        os.makedirs(os.path.dirname(cookie_jar) or '.', exist_ok=True)

    command = [
        'wpscan', '--url', scan_url,
        '--detection-mode', 'mixed', '--random-user-agent',
        '--output', output_file_name, '--format', 'json',
    ]
    if cache_dir:
        command.extend(['--cache-dir', cache_dir])
    if cookie_jar:
        command.extend(['--cookie-jar', cookie_jar])
    if _wpscan_api_token:
        command.extend(['--api-token', _wpscan_api_token])

    result = subprocess.run(command, shell=False, capture_output=False)

    if result.returncode == 1 or result.returncode == 4:
        result = f'{result.returncode}|{scan_name}|{scan_url}|{tg_chat_id}' \\
                 f'|0|scan_aborted. wrong url or something scan failed.|{output_file_name}|0'
    else:
        vulnerabilities_count, wp_banner, vulnerabilities_list = parse_wpscan_result(output_file_name)
        if wp_banner.startswith("scan_aborted"):
            result = f'4|{scan_name}|{scan_url}|{tg_chat_id}' \\
                     f'|0|scan_aborted. wrong url or something scan failed.|{output_file_name}|0'
        else:
            result = f'{result.returncode}|{scan_name}|{scan_url}|{tg_chat_id}' \\
                     f'|{vulnerabilities_count}|{wp_banner}|{output_file_name}|{vulnerabilities_list}'
    return result"""

new_parse_wpscan = """def parse_wpscan_result(result_file):
    try:
        with open(result_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        return 0, 'scan_aborted.missing_result_file', ''

    if not isinstance(data, dict):
        return 0, 'scan_aborted.invalid_result_format', ''

    if data.get('scan_aborted'):
        return 0, f\"scan_aborted.{str(data.get('scan_aborted'))[:120]}\", ''

    version_data = data.get('version')
    if not isinstance(version_data, dict):
        return 0, 'scan_aborted.missing_version', ''

    wp_ver = str(version_data.get('number', 'unknown'))
    i = 0
    result = ''

    vulnerabilities = version_data.get('vulnerabilities')
    if isinstance(vulnerabilities, list):
        for item in vulnerabilities:
            if not isinstance(item, dict):
                continue
            i += 1
            fixed = item.get('fixed_in')
            if fixed is None:
                fixed = 'null'
            title = item.get('title', 'unknown')
            contents = f\"{i}) {title} (fixed: {fixed})\\\\n\"
            result += contents

    return i, wp_ver, result"""

text = replace_or_append(text, "run_wpscan", new_run_wpscan)
text = replace_or_append(text, "parse_wpscan_result", new_parse_wpscan)
path.write_text(text, encoding="utf-8")
PY
    then
      discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
      mark_failed "$name" "failed to patch optional WPScan API token handling"
      return 0
    fi
  else
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "main.py not found after checkout"
    return 0
  fi

  if ! cms_repair_autowpscan_environment "${candidate_src}" || \
    ! run_user_cmd "${VENV_DIR}/bin/python" -m py_compile "${candidate_src}/main.py" || \
    ! run_user_cmd env AUTOWPSCAN_RUNTIME="${candidate_src}" WPSCAN_API_TOKEN="" \
      "${VENV_DIR}/bin/python" - <<'PY'
import importlib.util
import os
from pathlib import Path

path = Path(os.environ["AUTOWPSCAN_RUNTIME"]) / "main.py"
spec = importlib.util.spec_from_file_location("autowpscan_runtime_check", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module._wpscan_api_token == ""
assert callable(module.run_wpscan)
assert callable(module.parse_wpscan_result)
PY
  then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "staged runtime validation failed"
    return 0
  fi
  if ! activate_runtime_candidate "${candidate_src}" "${runtime_src}"; then
    discard_runtime_candidate "${candidate_src}" "${runtime_src}" || true
    mark_failed "$name" "unable to activate staged runtime"
    return 0
  fi
  previous_src="${RUNTIME_PREVIOUS}"
  finalize_runtime_activation "${previous_src}" "${runtime_src}" || \
    warn "${name}: previous runtime remains at ${previous_src}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
