#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Exercise the generated production launcher with the actual CMSScan app."""
import os
from pathlib import Path
import pwd
import shutil
import signal
import socket
import sqlite3
import subprocess
import tempfile
import time
import unittest
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text()
# The per-tool install_cmsscan function (which invokes the shared wrapper-body
# helper) lives in its own registry module sourced at runtime by installer.sh.
CMSSCAN_TOOL = (ROOT / 'scripts/install/tools/cmsscan.sh').read_text()
HELPER = 'cms_cmsscan_server_wrapper_body() {' + SOURCE.split('cms_cmsscan_server_wrapper_body() {', 1)[1].split('\ncmsscan_runtime_is_usable()', 1)[0]
VENV = Path('/home/aiuser/.local/share/vantage/cms_scanner/venv')


class CMSScanProductionLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.runtime = self.root / 'CMS runtime with spaces'
        shutil.copytree(ROOT / 'tools/.compat/cmsscan-src', self.runtime)
        shutil.copytree(ROOT / 'bin', self.root / 'bin')
        (self.runtime / 'db.db').unlink(missing_ok=True)
        body = subprocess.run(['/bin/bash', '-c', HELPER + '\nBIN_DIR="$2"; USER_GEM_BIN=""; cms_cmsscan_server_wrapper_body "$1"',
                               '_', str(self.runtime), str(self.root / 'bin')],
                              text=True, capture_output=True, check=True).stdout
        self.wrapper = self.root / 'cmsscan-server'
        self.wrapper.write_text('#!/bin/bash\nCANONICAL_VENV=' + str(VENV) + '\nCANONICAL_PYTHON=' + str(VENV / 'bin/python') + '\n' + body)
        self.wrapper.chmod(0o700)
        ai = pwd.getpwnam('aiuser')
        for path in [self.root, *self.root.rglob('*')]:
            os.chown(path, ai.pw_uid, ai.pw_gid)
        self.prefix = ['/usr/sbin/runuser', '-u', 'aiuser', '--', '/usr/bin/env', '-i',
                       'HOME=' + ai.pw_dir, 'USER=aiuser', 'LOGNAME=aiuser',
                       'VANTAGE_DISPATCHED=1', 'PYTHONUNBUFFERED=1',
                       'PATH=/usr/bin:/bin', str(self.wrapper)]

    def test_help_version_and_shell_syntax_do_not_start_application(self):
        self.assertEqual(subprocess.run(['/bin/bash', '-n', str(self.wrapper)]).returncode, 0)
        for argument in ['--help', '--version']:
            result = subprocess.run(self.prefix + [argument], text=True, capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('gunicorn', result.stdout.lower())
            self.assertNotIn('Updating WPScan', result.stdout + result.stderr)
            self.assertFalse((self.runtime / 'db.db').exists())

    def test_literal_launcher_serves_actual_app_db_and_cleanly_stops_without_debug_warning(self):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        log = self.root / 'server.log'
        started = time.monotonic()
        with log.open('wb') as stream:
            process = subprocess.Popen(self.prefix + ['--bind', '127.0.0.1:' + str(port)],
                stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                while True:
                    self.assertIsNone(process.poll(), log.read_text())
                    try:
                        with urlopen('http://127.0.0.1:' + str(port) + '/', timeout=1) as response:
                            self.assertEqual(response.status, 200)
                            self.assertIn(b'CMS', response.read())
                        break
                    except OSError:
                        if time.monotonic() - started > 25:
                            self.fail('Actual CMS server readiness timed out: ' + log.read_text())
                        time.sleep(.1)
                with urlopen('http://127.0.0.1:' + str(port) + '/scans', timeout=2) as response:
                    self.assertEqual(response.status, 200)
                with sqlite3.connect('file:' + str(self.runtime / 'db.db') + '?mode=ro', uri=True) as db:
                    self.assertTrue(db.execute("SELECT name FROM sqlite_master WHERE name='cmsscan'").fetchone())
                while time.monotonic() - started < 45:
                    members = subprocess.check_output(['/bin/ps', '-eo', 'pgid=,stat=,args='], text=True)
                    active = [line for line in members.splitlines() if line.split(None, 2)[0] == str(process.pid)
                              and '--update' in line and 'wpscan' in line]
                    if not active:
                        break
                    time.sleep(.1)
                else:
                    self.fail('Ordinary WPScan updater exceeded its bounded deadline')
            finally:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
        text = log.read_text()
        self.assertIn('[INFO] Updating WPScan', text)
        self.assertNotRegex(text, r'Traceback|\[ERROR\]|development server|Debugger|Debug mode|Restarting with stat')
        members = subprocess.check_output(['/bin/ps', '-eo', 'pgid=,stat=,args='], text=True)
        self.assertFalse([line for line in members.splitlines() if line.split(None, 2)[0] == str(process.pid)
                          and not line.split(None, 2)[1].startswith('Z')])

    def test_unknown_runner_option_fails_without_starting_application(self):
        result = subprocess.run(self.prefix + ['--vantage-nonexistent-option'], text=True, capture_output=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Updating WPScan', result.stdout + result.stderr)
        self.assertFalse((self.runtime / 'db.db').exists())

    def test_generated_default_is_localhost_and_reuse_requires_new_launcher(self):
        body = self.wrapper.read_text()
        self.assertIn('--bind 127.0.0.1:5000 --workers 1', body)
        self.assertIn('app:app "$@"', body)
        health = SOURCE.split('cmsscan_runtime_is_usable() {', 1)[1].split('\ncms_repair_clusterd_runtime()', 1)[0]
        self.assertIn('# VANTAGE_CMSSCAN_GUNICORN_V1', health)
        self.assertIn('"${BIN_DIR}/cmsscan-server" --version', health)
        self.assertIn('"$(cms_cmsscan_server_wrapper_body "${runtime_src}")"', CMSSCAN_TOOL)


if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
