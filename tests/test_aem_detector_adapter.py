#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Exercise the installer-emitted adapter against real upstream fingerprints."""
from __future__ import annotations

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text() + '\n' + (ROOT / 'scripts/install/tools/aem_detector.sh').read_text()
HELPER = SOURCE.split('cms_aem_detector_wrapper_body() {', 1)[1].split('\ncms_aem_detector_runtime_is_usable()', 1)[0]
HELPER = 'cms_aem_detector_wrapper_body() {' + HELPER
UPSTREAM = ROOT / 'tools/.compat/upstream/aem-hacker/aem_discoverer.py'


class FixtureHandler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.server.events.append(('GET', self.path))
        if self.path == '/':
            status, body, kind = 200, b'ordinary fixture', 'text/html'
        elif self.server.mode == 'positive' and self.path.endswith('/libs/granite/core/content/login.html'):
            status, body, kind = 200, b'Welcome to Adobe Experience Manager', 'text/html'
        elif self.server.mode == 'positive' and self.path.endswith('/libs/granite/csrf/token.json'):
            status, body, kind = 200, b'{"token":"fixture-token"}', 'application/json'
        elif self.server.mode == 'transport-error' and self.path.endswith('/libs/granite/core/content/login.html'):
            self.connection.close()
            return
        else:
            status, body, kind = 404, b'not found', 'text/html'
        self.send_response(status)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        self.server.events.append(('POST', self.path))
        self.send_response(500)
        self.end_headers()


class AEMDetectorAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name) / 'source with spaces'
        self.directory.mkdir()
        shutil.copyfile(UPSTREAM, self.directory / 'aem_discoverer.py')
        self.wrapper = self.directory.parent / 'adapter'
        body = subprocess.run(['/bin/bash', '-c', HELPER + '\ncms_aem_detector_wrapper_body "$1"', '_', str(self.directory)],
                              capture_output=True, text=True, check=True).stdout
        self.wrapper.write_text('#!/bin/bash\nCANONICAL_PYTHON=' + repr(sys.executable) + '\n' + body)
        self.wrapper.chmod(0o700)
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), FixtureHandler)
        self.server.mode = 'positive'
        self.server.events = []
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server)
        self.url = 'http://127.0.0.1:%s/' % self.server.server_address[1]

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def run_adapter(self, *extra):
        return subprocess.run([str(self.wrapper), '-u', self.url, '--workers', '2', '--timeout', '1', *extra],
                              capture_output=True, text=True, timeout=30)

    def test_generated_shell_syntax_and_help_are_inert(self):
        syntax = subprocess.run(['/bin/bash', '-n', str(self.wrapper)], capture_output=True, text=True)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)
        self.assertEqual(syntax.stderr, '')
        result = subprocess.run([str(self.wrapper), '--help'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('read-only upstream fingerprints', result.stdout)
        self.assertEqual(self.server.events, [])

    def test_positive_actual_upstream_fingerprints_execute_get_only(self):
        result = self.run_adapter()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('AEM detected by: by_csrf_token, by_login_page', result.stdout)
        paths = [path for _, path in self.server.events]
        for path in ['/libs/granite/core/content/login.html', '/libs/granite/csrf/token.json',
                     '/etc/clientlibs/wcm/foundation/main.css', '/api/content.json']:
            self.assertIn(path, paths)
        self.assertTrue(all(method == 'GET' for method, _ in self.server.events))
        self.assertNotIn('HTTPServer', self.wrapper.read_text())
        self.assertNotIn('run_detector', self.wrapper.read_text())

    def test_404_fingerprint_responses_are_not_positive(self):
        self.server.mode = 'negative'
        result = self.run_adapter()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('No AEM fingerprint matched', result.stdout)
        self.assertNotIn('AEM detected by:', result.stdout)

    def test_transport_errors_swallowed_by_upstream_still_fail_adapter(self):
        self.server.mode = 'transport-error'
        result = self.run_adapter()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('fingerprint transport failed', result.stderr)

    def test_invalid_limits_rejected_before_any_request(self):
        for extra in [('--workers', '0'), ('--workers', '5'), ('--timeout', '0'), ('--timeout', '61')]:
            result = self.run_adapter(*extra)
            self.assertEqual(result.returncode, 2)
        self.assertEqual(self.server.events, [])

    def test_unexpected_future_upstream_post_is_blocked(self):
        source = 'import requests\n' + '''
def by_login_page(url, debug, proxy):
    try:
        return http_request(url, method="POST")
    except Exception:
        return False
'''
        for name in ['by_csrf_token', 'by_geometrixx_page', 'by_get_servlet', 'by_bin_receive', 'by_css_js', 'by_siren_api']:
            source += '\ndef %s(url, debug, proxy):\n    return False\n' % name
        (self.directory / 'aem_discoverer.py').write_text(source)
        result = self.run_adapter()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('state-changing fingerprint request was refused', result.stderr)
        self.assertTrue(all(method == 'GET' for method, _ in self.server.events))

    def test_old_adapter_cannot_take_current_source_reuse_shortcut(self):
        guard = SOURCE.split('    install_aem_detector)', 1)[1].split('      ;;', 1)[0]
        self.assertIn('if cms_aem_detector_runtime_is_usable', guard)
        self.assertIn('cms_git_tool_is_current', guard)
        install = SOURCE.split('\ninstall_aem_detector() {', 1)[1].split('\n# ---', 1)[0]
        self.assertIn('cms_aem_detector_wrapper_body "${wrapper_repo}"', install)
        self.assertIn('"aem-hacker" "${detector_body}"', install)


if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
