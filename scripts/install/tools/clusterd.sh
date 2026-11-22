#!/usr/bin/env bash
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Installer-only adapter; sourcing declares functions and performs no work.

cms_disable_shared_fuze_login() {
  run_user_cmd /usr/bin/python3 - "$@" <<'PY'
import os
import re
import stat
import sys
import tempfile
from pathlib import Path

for root in map(Path, sys.argv[1:]):
    path = root / "src/lib/coldfusion/fuze.cfml"
    if not path.exists():
        continue
    if path.is_symlink() or not path.is_file():
        raise SystemExit("Refusing an unexpected Fuze asset")
    source = path.read_bytes()
    disabled = b"<cfabort> <!--- Shared login disabled in this distribution. --->"
    if source.startswith(disabled):
        continue
    # Stop before any CFML is evaluated, and remove any stored login hash.
    source = re.sub(rb'(?im)^\s*<cfset\s+Password\s*=.*?>([^\r\n]*)', b'', source)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as output:
        staged = Path(output.name)
        try:
            output.write(disabled + b"\n" + source)
            output.flush()
            os.fchmod(output.fileno(), stat.S_IMODE(path.stat().st_mode))
            os.replace(staged, path)
        finally:
            staged.unlink(missing_ok=True)
PY
}

install_clusterd() {
  local name="Clusterd"
  local repo="${TOOLS_DIR}/clusterd"
  local venv="${VENV_DIR}"
  local build_src="${COMPAT_DIR}/clusterd-src"
  local candidate_src=""
  local previous_src=""
  local candidate_py_path=""
  local py_path=""

  if ! repo_clone_or_update https://github.com/hatRiot/clusterd.git "$repo"; then
    mark_failed "$name" "repository checkout failed"
    return 0
  fi
  repo="${EFFECTIVE_REPO_DIR}"
  if ! cms_disable_shared_fuze_login "$repo" "${TOOLS_DIR}/clusterd" "${COMPAT_DIR}/upstream/clusterd"; then
    mark_failed "$name" "unable to disable the bundled shared login"
    return 0
  fi
  if ! scanner_pip_install -r "${repo}/requirements.txt"; then
    mark_failed "$name" "requirements installation failed"
    return 0
  fi
  if ! scanner_pip_install modernize six; then
    mark_failed "$name" "python3 compatibility tooling install failed"
    return 0
  fi

  if ! prepare_runtime_candidate "${repo}" "${build_src}"; then
    mark_failed "$name" "unable to stage source for python3 conversion"
    return 0
  fi
  candidate_src="${RUNTIME_CANDIDATE}"
  if ! run_user_cmd "${venv}/bin/modernize" --no-diffs -w -n -f default -x import -x imports_six -x itertools_imports_six -x urllib_six "${candidate_src}"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "auto-conversion to python3 failed"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/commands.py\" <<'PY'
import subprocess


def getoutput(cmd):
    return subprocess.getoutput(cmd)
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply python3 commands shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/sitecustomize.py\" <<'PY'
import importlib.machinery
import importlib.util
import os
import sys


class _LoaderShim:
    def __init__(self, loader, default_name):
        self._loader = loader
        self._default_name = default_name

    def load_module(self, fullname):
        name = fullname or self._default_name
        if name in sys.modules:
            return sys.modules[name]
        if hasattr(self._loader, 'load_module'):
            return self._loader.load_module(name)
        spec = importlib.util.spec_from_loader(name, self._loader)
        if spec is None:
            raise ImportError(name)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        self._loader.exec_module(module)
        return module


def _find_module(self, fullname, path=None):
    spec = self.find_spec(fullname)
    if spec is not None and spec.loader is not None:
        return _LoaderShim(spec.loader, fullname)

    base_path = getattr(self, 'path', None)
    if base_path:
        module_path = os.path.join(base_path, fullname + '.py')
        if os.path.isfile(module_path):
            loader = importlib.machinery.SourceFileLoader(fullname, module_path)
            return _LoaderShim(loader, fullname)
    return None


if not hasattr(importlib.machinery.FileFinder, 'find_module'):
    importlib.machinery.FileFinder.find_module = _find_module
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply module loader compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/HTMLParser.py\" <<'PY'
from html.parser import HTMLParser
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply HTMLParser compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/urlparse.py\" <<'PY'
from urllib.parse import *
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply urlparse compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/ConfigParser.py\" <<'PY'
from configparser import *
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply ConfigParser compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/Queue.py\" <<'PY'
from queue import *
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply Queue compatibility shim"
    return 0
  fi
  if ! run_user_shell "cat > \"${candidate_src}/src/core/httplib.py\" <<'PY'
from http.client import *
PY"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to apply httplib compatibility shim"
    return 0
  fi
  if ! run_user_cmd sed -i 's/len(fingerengine\\.fingerprints) is 0/len(fingerengine.fingerprints) == 0/' "${candidate_src}/clusterd.py"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to patch python3 syntax compatibility in clusterd.py"
    return 0
  fi
  if ! run_user_cmd sed -i 's/timeout is not 10/timeout != 10/; s/timeout is 0/timeout == 0/' "${candidate_src}/src/module/deploy_utils.py"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to patch python3 syntax compatibility in deploy_utils.py"
    return 0
  fi
  if ! run_user_cmd sed -i "s/re.findall('\\\\d+\\/open',item)/re.findall(r'\\\\d+\\/open', item)/" "${candidate_src}/src/module/discovery.py"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to patch regex compatibility in discovery.py"
    return 0
  fi
  if ! run_user_cmd env CLUSTERD_BUILD="${candidate_src}" "${venv}/bin/python" - <<'PY'
import os
from pathlib import Path

base = Path(os.environ["CLUSTERD_BUILD"])

# Python2 urllib import compatibility in older auxiliaries/deployers.
for rel, old, new in [
    ("src/platform/jboss/auxiliary/verb_tamper.py", "from urllib import quote_plus", "from urllib.parse import quote_plus"),
    ("src/platform/coldfusion/deployers/lfi_stager.py", "from urllib import quote_plus", "from urllib.parse import quote_plus"),
    ("src/platform/railo/deployers/log_injection.py", "from urllib import quote", "from urllib.parse import quote"),
    ("src/platform/jboss/deployers/seam_upload.py", "from urllib import quote_plus", "from urllib.parse import quote_plus"),
]:
    path = base / rel
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")

# Ignore duplicate module flags generated by legacy plugin set to keep argparse stable.
auxengine = base / "src/core/auxengine.py"
if auxengine.exists():
    text = auxengine.read_text(encoding="utf-8", errors="ignore")
    if 'opt = "--%s" % mod.flag' not in text:
        old = """        if 'enable_args' in dir(mod) and mod.enable_args:
            egroup.add_argument("--%s" % mod.flag, action='store', help=SUPPRESS)
        else:
            egroup.add_argument("--%s" % mod.flag, action='store_true', dest=mod.flag,
                            help=SUPPRESS)
"""
        new = """        opt = "--%s" % mod.flag
        if opt in egroup._option_string_actions:
            continue

        if 'enable_args' in dir(mod) and mod.enable_args:
            egroup.add_argument(opt, action='store', help=SUPPRESS)
        else:
            egroup.add_argument(opt, action='store_true', dest=mod.flag,
                            help=SUPPRESS)
"""
        if old in text:
            auxengine.write_text(text.replace(old, new), encoding="utf-8")
PY
  then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to patch python3 runtime compatibility in converted source"
    return 0
  fi

  if ! cms_repair_clusterd_runtime "${candidate_src}"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to repair Python3 platform imports and Tomcat text fingerprints"
    return 0
  fi

  candidate_py_path="$(capture_user_cmd bash -lc "find \"${candidate_src}/src\" -type d | paste -sd: -" 2>/dev/null || true)"
  if [[ -z "${candidate_py_path}" ]] || \
    ! run_user_cmd "${venv}/bin/python" -m py_compile "${candidate_src}/clusterd.py"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to assemble runtime PYTHONPATH"
    return 0
  fi

  if [[ "$RUN_SMOKE_TESTS" -eq 1 ]]; then
    if ! run_user_shell "cd \"${candidate_src}\" && env PYTHONWARNINGS=ignore::SyntaxWarning PYTHONPATH=\"${candidate_py_path}:\${PYTHONPATH:-}\" \"${venv}/bin/python\" \"${candidate_src}/clusterd.py\" --help"; then
      discard_runtime_candidate "${candidate_src}" "${build_src}" || true
      mark_failed "$name" "runtime compatibility smoke test failed on current platform"
      return 0
    fi
  fi
  if ! activate_runtime_candidate "${candidate_src}" "${build_src}"; then
    discard_runtime_candidate "${candidate_src}" "${build_src}" || true
    mark_failed "$name" "unable to activate converted runtime"
    return 0
  fi
  previous_src="${RUNTIME_PREVIOUS}"
  py_path="$(capture_user_cmd bash -lc "find \"${build_src}/src\" -type d | paste -sd: -" 2>/dev/null || true)"
  if [[ -z "${py_path}" ]] || \
    ! create_wrapper "clusterd" "cd \"${build_src}\" && exec env PYTHONWARNINGS=ignore::SyntaxWarning PYTHONPATH=\"${py_path}:\${PYTHONPATH:-}\" \"\${CANONICAL_PYTHON}\" \"${build_src}/clusterd.py\" \"\$@\""; then
    rollback_runtime_activation "${previous_src}" "${build_src}" || \
      warn "${name}: wrapper creation failed and runtime rollback was unavailable"
    mark_failed "$name" "unable to create executable wrapper"
    return 0
  fi
  finalize_runtime_activation "${previous_src}" "${build_src}" || \
    warn "${name}: previous runtime remains at ${previous_src}"
  mark_installed "$name"
}
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
