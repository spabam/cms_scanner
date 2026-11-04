#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Exercise installer-staged logging, including real local CMSeeK reports."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ast
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text()
REPAIR = SOURCE.split("<<'PY_CMS_RUNNER_LOGGER'\n", 1)[1].split('\nPY_CMS_RUNNER_LOGGER', 1)[0]
CONSTANTS = {node.targets[0].id: ast.literal_eval(node.value)
             for node in ast.parse(REPAIR).body
             if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
             and node.targets[0].id in ['legacy_cleanup', 'modern_cleanup', 'legacy_redirect', 'modern_redirect']}


class CMSRunnerLoggerRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.runner = self.root / 'run_cms_scanner.sh'
        shutil.copyfile(ROOT / 'run_cms_scanner.sh', self.runner)
        original = self.runner.read_bytes()
        for name in ['cleanup', 'redirect']:
            original = original.replace(CONSTANTS['modern_' + name], CONSTANTS['legacy_' + name])
        self.runner.write_bytes(original)
        self.runner.chmod(0o750)
        (self.root / 'bin').mkdir()
        shutil.copyfile(ROOT / 'bin/cmseek', self.root / 'bin/cmseek')
        (self.root / 'bin/cmseek').chmod(0o750)
        shutil.copytree(ROOT / 'tools/.compat/upstream/CMSeeK', self.root / 'tools/.compat/upstream/CMSeeK')
        ai = pwd.getpwnam('aiuser')
        for path in [self.root, *self.root.rglob('*')]:
            os.chown(path, ai.pw_uid, ai.pw_gid)
        self.prefix = ['/usr/sbin/runuser', '-u', 'aiuser', '--', '/usr/bin/env', '-i',
            'HOME=' + ai.pw_dir, 'USER=aiuser', 'LOGNAME=aiuser', 'VANTAGE_DISPATCHED=1', 'PATH=/usr/bin:/bin']

    def repair(self):
        return subprocess.run(self.prefix + ['/home/aiuser/.local/share/vantage/cms_scanner/venv/bin/python', '-', str(self.runner)],
                              input=REPAIR, text=True, capture_output=True)

    def tee_fixture(self, status):
        marker = self.root / 'logger-finished'
        script = self.root / 'bin/tee'
        script.write_text('#!/usr/bin/python3\nimport pathlib,sys,time\ndata=sys.stdin.buffer.read()\n'
            'time.sleep(0.25)\nfor path in sys.argv[2:]:\n'
            ' with open(path,"ab") as output:output.write(data)\n'
            'sys.stdout.buffer.write(data)\nsys.stdout.buffer.flush()\n'
            'pathlib.Path(' + repr(str(marker)) + ').write_text("complete")\n'
            'raise SystemExit(' + str(status) + ')\n')
        script.chmod(0o755)
        return marker

    def scan(self, logger_status):
        events = []
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass
            def do_GET(self):
                events.append(self.path)
                body = b'<html><meta name="generator" content="WordPress 6.4"><link href="/wordpress/wp-content/themes/fixture/style.css">powered by WordPress</html>'
                self.send_response(200)
                self.end_headers()
                self.wfile.write(body)
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        marker = self.tee_fixture(logger_status)
        before = time.monotonic()
        try:
            run = subprocess.run(self.prefix + ['/bin/bash', str(self.runner), '--scanner', 'cmseek',
                'http://127.0.0.1:' + str(server.server_port) + '/wordpress/', str(self.root / 'report.txt')],
                cwd=self.root, text=True, capture_output=True, timeout=30)
        finally:
            server.shutdown()
            thread.join()
            server.server_close()
        self.assertGreaterEqual(time.monotonic() - before, .25)
        self.assertTrue(marker.exists(), run.stderr)
        self.assertTrue(events, run.stdout + run.stderr)
        report = (self.root / 'report.txt').read_text()
        self.assertRegex(report, r'Success \(rc=0\)\s*:\s*1')
        self.assertRegex(report, r'Non-zero exits\s*:\s*0')
        self.assertIn('WordPress', report)
        canonical = next(self.root.glob('.cmsscan.*.log')).read_text()
        legacy = next((self.root / 'logs').glob('*/run.log')).read_text()
        for log in [canonical, legacy]:
            self.assertIn('100.0%', log)
            self.assertIn('Summary: success=1', log)
        return run

    def test_delayed_logger_is_joined_before_successful_actual_scan_returns(self):
        self.assertEqual(self.repair().returncode, 0)
        run = self.scan(0)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_logger_failure_is_reported_and_changes_success_to_failure(self):
        self.assertEqual(self.repair().returncode, 0)
        run = self.scan(23)
        self.assertEqual(run.returncode, 23, run.stdout + run.stderr)
        self.assertIn('runtime logger failed (status 23)', run.stderr)

    def test_original_worker_failure_wins_over_logger_failure(self):
        self.assertEqual(self.repair().returncode, 0)
        text = self.runner.read_text()
        cleanup = 'cleanup() {' + text.split('cleanup() {', 1)[1].split('\ntrap cleanup EXIT', 1)[0]
        redirect = text.split('# VANTAGE_CMS_RUNNER_JOINED_LOGGER_V1', 1)[1].split('\napply_output_ownership', 1)[0]
        self.tee_fixture(23)
        script = 'set -euo pipefail\nTMP_DIR=""\napply_output_ownership(){ :; }\n' + cleanup + '\ntrap cleanup EXIT\n' + redirect + '\nprintf "fixture output\\n"\nexit 7\n'
        run = subprocess.run(['/bin/bash', '-c', script], env={**os.environ,
            'PATH': str(self.root / 'bin') + ':/usr/bin:/bin', 'LOG_FILE': str(self.root / 'one.log'),
            'LEGACY_LOG_FILE': str(self.root / 'two.log')}, text=True, capture_output=True, timeout=5)
        self.assertEqual(run.returncode, 7, run.stderr)
        self.assertIn('runtime logger failed (status 23)', run.stderr)

    def test_repair_is_idempotent_and_preserves_mode(self):
        self.assertEqual(self.repair().returncode, 0)
        first = self.runner.read_bytes()
        self.assertEqual(self.repair().returncode, 0)
        self.assertEqual(first, self.runner.read_bytes())
        self.assertEqual(self.runner.stat().st_mode & 0o777, 0o750)

    def test_trusted_system_interpreter_repairs_root_owned_staged_source(self):
        ai = pwd.getpwnam('aiuser')
        os.chown(self.root, 0, ai.pw_gid)
        self.root.chmod(0o750)
        os.chown(self.runner, 0, ai.pw_gid)
        self.runner.chmod(0o640)
        result = subprocess.run(['/usr/bin/python3', '-', str(self.runner)], input=REPAIR,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        metadata = self.runner.stat()
        self.assertEqual((metadata.st_uid, metadata.st_gid, metadata.st_mode & 0o777),
                         (0, ai.pw_gid, 0o640))
        self.assertIn('run_privileged /usr/bin/python3 - "$1"', SOURCE)

    def test_unknown_cleanup_is_rejected_without_partial_redirect_change(self):
        original = self.runner.read_bytes().replace(b'  local rc=$?\n', b'  local changed=$?\n', 1)
        self.runner.write_bytes(original)
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertEqual(self.runner.read_bytes(), original)

    def test_linked_runner_is_rejected(self):
        target = self.root / 'linked-source'
        self.runner.rename(target)
        self.runner.symlink_to(target)
        self.assertNotEqual(self.repair().returncode, 0)

    def test_installer_repairs_runner_before_archive_creation(self):
        phase = SOURCE.split('phase_package_cmsscan() {', 1)[1].split('print_summary()', 1)[0]
        self.assertLess(phase.index('cms_repair_runner_logger "${SCRIPT_DIR}/run_cms_scanner.sh"'),
                        phase.index('bundle_cmsscan_archive'))


if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
