#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Exercise installer compatibility and actual parsed methods without HTTP."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text() + '\n' + (ROOT / 'scripts/install/tools/wpseku.sh').read_text()
REPAIR = SOURCE.split("<<'PY_WPSEKU_JSON'\n", 1)[1].split('\nPY_WPSEKU_JSON', 1)[0]
LEGACY = b'''from json import loads\r
class wpusers(Request):\r
    def wpjson(self):\r
        resp = self.send()\r
        json = loads(resp.content, encoding="utf-8")\r
        return [(user['name'], user['slug']) for user in json]\r
    def wpjson2(self):\r
        resp = self.send()\r
        json = loads(resp.content, encoding="utf-8")\r
        return [(user['name'], user['slug']) for user in json]\r
'''

class WPSekuJSONRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def fixture(self, name='tool', source=LEGACY):
        root = self.root / name
        path = root / 'modules/discovery/users/wpusers.py'
        path.parent.mkdir(parents=True)
        path.write_bytes(source)
        path.chmod(0o640)
        return root, path

    def repair(self, *roots):
        return subprocess.run([sys.executable, '-', *(str(p) for p in roots)],
                              input=REPAIR, text=True, capture_output=True)

    def test_parses_utf8_response_bytes_in_both_real_methods(self):
        root, path = self.fixture()
        result = self.repair(root)
        self.assertEqual(result.returncode, 0, result.stderr)
        namespace = {'Request': object}
        exec(compile(path.read_bytes(), str(path), 'exec'), namespace)
        tool = namespace['wpusers']()
        tool.send = lambda: SimpleNamespace(content='[{"name":"Náme","slug":"user"}]'.encode())
        self.assertEqual(tool.wpjson(), [('Náme', 'user')])
        self.assertEqual(tool.wpjson2(), [('Náme', 'user')])
        self.assertEqual(path.stat().st_mode & 0o777, 0o640)
        self.assertEqual(path.read_bytes().count(b'\r\n'), LEGACY.count(b'\r\n'))

    def test_real_fallback_method_handles_non_json_response(self):
        import ast
        import json
        import warnings
        upstream = ROOT / 'tools/.compat/upstream/WPSeku/modules/discovery/users/wpusers.py'
        root, path = self.fixture(source=upstream.read_bytes())
        result = self.repair(root)
        self.assertEqual(result.returncode, 0, result.stderr)
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', SyntaxWarning)
            tree = ast.parse(path.read_bytes())
        cls = next(node for node in tree.body if isinstance(node, ast.ClassDef))
        method = next(node for node in cls.body if isinstance(node, ast.FunctionDef) and node.name == 'wpjson2')
        namespace = {'loads': json.loads, 'Path': lambda *args: 'fixture'}
        exec(compile(ast.Module(body=[method], type_ignores=[]), str(path), 'exec'), namespace)
        target = SimpleNamespace(url='fixture', send=lambda **kwargs: SimpleNamespace(
            status_code=200, content=b'<html>ordinary page, not JSON</html>'))
        self.assertEqual(namespace['wpjson2'](target), [])
        self.assertNotIn(b'except json.decoder.JSONDecodeError:', path.read_bytes())
        self.assertEqual(self.repair(root).returncode, 0)

    def test_repair_is_idempotent(self):
        root, path = self.fixture()
        self.assertEqual(self.repair(root).returncode, 0)
        repaired = path.read_bytes()
        self.assertEqual(self.repair(root).returncode, 0)
        self.assertEqual(path.read_bytes(), repaired)

    def test_unsupported_call_preserved_before_any_candidate_changes(self):
        root, path = self.fixture()
        other, unsupported = self.fixture('unknown', LEGACY.replace(b'encoding="utf-8"', b'encoding="ascii"', 1))
        before = unsupported.read_bytes()
        self.assertNotEqual(self.repair(root, other).returncode, 0)
        self.assertEqual(unsupported.read_bytes(), before)
        self.assertEqual(path.read_bytes(), LEGACY)

    def test_linked_source_is_rejected(self):
        root, path = self.fixture()
        target = self.root / 'original'
        path.rename(target)
        path.symlink_to(target)
        self.assertNotEqual(self.repair(root).returncode, 0)
        self.assertEqual(target.read_bytes(), LEGACY)
        path.unlink()
        os.link(target, path)
        self.assertNotEqual(self.repair(root).returncode, 0)
        self.assertEqual(target.read_bytes(), LEGACY)

    def test_fresh_and_reuse_paths_apply_compatibility(self):
        fresh = SOURCE.split('install_wpseku() {', 1)[1].split('# WPXF gem', 1)[0]
        self.assertIn('cms_repair_wpseku_json "${repo}"', fresh)
        self.assertIn('"${TOOLS_DIR}/WPSeku" "${COMPAT_DIR}/upstream/WPSeku"', SOURCE)

if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
