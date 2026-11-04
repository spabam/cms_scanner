#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Verify the real AutoWPScan method's optional-token child environment."""
import ast
from datetime import datetime, timezone
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text() + '\n' + (ROOT / 'scripts/install/tools/autowpscan.sh').read_text()
REPAIR = SOURCE.split("<<'PY_AUTOWPSCAN_ENV'\n", 1)[1].split('\nPY_AUTOWPSCAN_ENV', 1)[0]
CONSTANTS = {node.targets[0].id: ast.literal_eval(node.value)
             for node in ast.parse(REPAIR).body
             if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
             and node.targets[0].id in ['legacy', 'modern']}


class AutoWPScanEnvironmentRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = self.root / 'main.py'
        upstream = (ROOT / 'tools/.compat/autowpscan-src/main.py').read_bytes()
        self.path.write_bytes(upstream.replace(CONSTANTS['modern'], CONSTANTS['legacy']))
        self.path.chmod(0o640)

    def repair(self):
        return subprocess.run([sys.executable, '-', str(self.path)], input=REPAIR,
                              text=True, capture_output=True)

    def run_actual_method(self, environment):
        calls = []
        def run(command, **options):
            calls.append((command, options))
            return SimpleNamespace(returncode=0)
        tree = ast.parse(self.path.read_bytes())
        method = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'run_wpscan')
        namespace = {'datetime': datetime, 'timezone': timezone, 'os': os,
                     '_home_path': str(self.root), 'create_job_id': lambda: 'fixture',
                     '_wpscan_api_token': environment.get('WPSCAN_API_TOKEN', '').strip(),
                     'subprocess': SimpleNamespace(run=run),
                     'parse_wpscan_result': lambda path: (0, '6.4', '')}
        exec(compile(ast.Module(body=[method], type_ignores=[]), str(self.path), 'exec'), namespace)
        with patch.dict(os.environ, environment, clear=True):
            result = namespace['run_wpscan']('http://127.0.0.1/wordpress/', 'fixture', '0')
            self.assertEqual(dict(os.environ), environment)
        self.assertIn('|6.4|', result)
        self.assertEqual(len(calls), 1)
        self.assertFalse(calls[0][1]['shell'])
        return calls[0]

    def test_actual_method_removes_absent_empty_and_whitespace_api_tokens(self):
        self.assertEqual(self.repair().returncode, 0)
        for value in [None, '', ' ', '\t\r\n']:
            environment = {'HOME': str(self.root), 'UNCHANGED': 'fixture'}
            if value is not None:
                environment['WPSCAN_API_TOKEN'] = value
            with self.subTest(value=value):
                command, options = self.run_actual_method(environment)
                self.assertNotIn('WPSCAN_API_TOKEN', options['env'])
                self.assertNotIn('--api-token', command)
                self.assertEqual(options['env']['UNCHANGED'], 'fixture')

    def test_actual_method_preserves_configured_api_token(self):
        self.assertEqual(self.repair().returncode, 0)
        command, options = self.run_actual_method({'WPSCAN_API_TOKEN': 'fixture-token'})
        self.assertEqual(options['env']['WPSCAN_API_TOKEN'], 'fixture-token')
        self.assertEqual(command[command.index('--api-token') + 1], 'fixture-token')

    def test_idempotence_and_file_mode(self):
        self.assertEqual(self.repair().returncode, 0)
        first = self.path.read_bytes()
        self.assertEqual(self.repair().returncode, 0)
        self.assertEqual(first, self.path.read_bytes())
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)

    def test_unknown_subprocess_call_is_rejected_without_mutation(self):
        self.path.write_bytes(self.path.read_bytes().replace(CONSTANTS['legacy'], b'    result = unsupported(command)'))
        original = self.path.read_bytes()
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertEqual(original, self.path.read_bytes())

    def test_linked_runtime_is_rejected(self):
        original = self.root / 'original'
        self.path.rename(original)
        self.path.symlink_to(original)
        self.assertNotEqual(self.repair().returncode, 0)

    def test_both_installation_paths_apply_repair(self):
        self.assertIn('cms_repair_autowpscan_environment "${candidate_src}"', SOURCE)
        self.assertIn('cms_repair_autowpscan_environment "${COMPAT_DIR}/autowpscan-src"', SOURCE)


if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
