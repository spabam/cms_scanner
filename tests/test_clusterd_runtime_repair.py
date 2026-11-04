#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Exercise the installer repair and real upstream read-only fingerprints."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text() + '\n' + (ROOT / 'scripts/install/tools/clusterd.sh').read_text()
REPAIR = SOURCE.split("<<'PY_CLUSTERD_RUNTIME'\n", 1)[1].split('\nPY_CLUSTERD_RUNTIME', 1)[0]
UPSTREAM = ROOT / 'tools/.compat/clusterd-src'
PYTHON = Path('/home/aiuser/.local/share/vantage/cms_scanner/venv/bin/python')


class ClusterdRuntimeRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'runtime'
        shutil.copytree(UPSTREAM, self.root)
        # Runtime source may already have been repaired by a prior installer.
        # Restore only these known legacy forms in this private test candidate.
        for relative in ['interfaces.py', 'fingerprints/Tomcat4.py',
                         'fingerprints/Tomcat41.py', 'fingerprints/Tomcat33Admin.py']:
            path = self.root / 'src/platform/tomcat' / relative
            path.write_bytes(path.read_bytes().replace(b'response.text', b'response.content'))
        shim = self.root / 'src/core/sitecustomize.py'
        shim.write_bytes(shim.read_bytes().split(b'# VANTAGE_CLUSTERD_STDLIB_PLATFORM_V1')[0])

    def repair(self):
        return subprocess.run([sys.executable, '-', str(self.root)], input=REPAIR,
                              text=True, capture_output=True)

    def environment(self):
        env = os.environ.copy()
        env['PYTHONPATH'] = ':'.join(str(p) for p in (self.root / 'src').rglob('*') if p.is_dir()) + ':' + str(self.root / 'src')
        env['PYTHONWARNINGS'] = 'ignore::SyntaxWarning'
        env['PYTHONDONTWRITEBYTECODE'] = '1'
        return env

    def test_stdlib_platform_wins_without_breaking_namespaced_package(self):
        self.assertEqual(self.repair().returncode, 0)
        run = subprocess.run([str(PYTHON), '-c',
            'import platform,src.platform; assert callable(platform.system); '
            'assert platform.system(); print("stdlib platform OK")'],
            cwd=self.root, env=self.environment(), text=True, capture_output=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn('stdlib platform OK', run.stdout)

    def scan(self, positive):
        requests = []
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass
            def do_GET(self):
                requests.append(('GET', self.path))
                routes = {'/manager/html': b'<html><h3>Apache Tomcat/7.0.109</h3></html>',
                          '/RELEASE-NOTES.txt': b'Apache Tomcat Version 7.0.109\n'} if positive else {}
                body = routes.get(self.path, b'Fixture route not found')
                self.send_response(200 if self.path in routes else 404)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.end_headers()
                self.wfile.write(body)
            def do_POST(self):
                requests.append(('POST', self.path))
                self.send_error(405)
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            run = subprocess.run([str(PYTHON), str(self.root / 'clusterd.py'),
                '-i', '127.0.0.1', '-p', str(server.server_port), '-a', 'tomcat',
                '-o', 'linux', '--fingerprint', '--timeout', '2', '-d'],
                cwd=self.root, env=self.environment(), text=True, capture_output=True, timeout=30)
        finally:
            server.shutdown()
            thread.join()
            server.server_close()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertNotIn('Exception with fingerprint:', run.stdout + run.stderr)
        self.assertNotIn('Traceback', run.stdout + run.stderr)
        self.assertTrue(requests)
        self.assertTrue(all(method == 'GET' for method, _ in requests), requests)
        return run.stdout

    def test_actual_full_fingerprint_engine_recognizes_positive_http_oracle(self):
        self.assertEqual(self.repair().returncode, 0)
        output = self.scan(True)
        self.assertIn('Matched ', output)
        self.assertIn('Tomcat Manager (version 7.0)', output)

    def test_actual_engine_does_not_identify_plain_404_responses(self):
        self.assertEqual(self.repair().returncode, 0)
        self.assertIn('No fingerprints found for service tomcat', self.scan(False))

    def test_repair_is_idempotent_and_keeps_binary_consumers_and_modes(self):
        untouched = self.root / 'src/platform/tomcat/deployers/manage_deploy.py'
        original = untouched.read_bytes()
        changed = self.root / 'src/platform/tomcat/interfaces.py'
        changed.chmod(0o640)
        self.assertEqual(self.repair().returncode, 0)
        first = changed.read_bytes()
        self.assertEqual(self.repair().returncode, 0)
        self.assertEqual(first, changed.read_bytes())
        self.assertEqual(changed.stat().st_mode & 0o777, 0o640)
        self.assertEqual(untouched.read_bytes(), original)

    def test_unsupported_pattern_fails_before_any_file_is_changed(self):
        interface = self.root / 'src/platform/tomcat/interfaces.py'
        original = interface.read_bytes()
        other = self.root / 'src/platform/tomcat/fingerprints/Tomcat41.py'
        other.write_bytes(other.read_bytes().replace(b'response.content', b'response.unexpected'))
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertEqual(interface.read_bytes(), original)

    def test_linked_file_is_rejected(self):
        target = self.root / 'src/platform/tomcat/interfaces.py'
        linked = self.root / 'linked'
        target.rename(linked)
        target.symlink_to(linked)
        self.assertNotEqual(self.repair().returncode, 0)

    def test_fresh_and_reuse_installation_apply_repair(self):
        self.assertIn('cms_repair_clusterd_runtime "${candidate_src}"', SOURCE)
        self.assertIn('cms_repair_clusterd_runtime "${COMPAT_DIR}/clusterd-src"', SOURCE)


if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
