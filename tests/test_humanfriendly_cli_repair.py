#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Verify the installer repair against the actual humanfriendly10.0 CLI."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'installer.sh').read_text()
REPAIR = SOURCE.split("<<'PY_HUMANFRIENDLY_CLI'\n", 1)[1].split('\nPY_HUMANFRIENDLY_CLI', 1)[0]
UPSTREAM = Path('/home/aiuser/.local/share/vantage/cms_scanner/venv/lib/python3.13/site-packages')


class HumanfriendlyCLIRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        subprocess.run(['/usr/bin/python3', '-m', 'venv', '--without-pip', str(self.root / 'venv')], check=True)
        self.python = self.root / 'venv/bin/python'
        sites = self.root / 'venv/lib/python3.13/site-packages'
        shutil.copytree(UPSTREAM / 'humanfriendly', sites / 'humanfriendly')
        shutil.copytree(UPSTREAM / 'humanfriendly-10.0.dist-info', sites / 'humanfriendly-10.0.dist-info')
        self.path = sites / 'humanfriendly/cli.py'
        self.path.write_bytes(self.path.read_bytes().replace(b'\nimport shlex as pipes\n', b'\nimport pipes\n'))
        self.path.chmod(0o640)

    def repair(self):
        return subprocess.run([str(self.python), '-'], input=REPAIR, text=True, capture_output=True)

    def test_actual_cli_help_and_formatting_work_on_python313(self):
        broken = subprocess.run([str(self.python), '-c', 'import humanfriendly.cli'], text=True, capture_output=True)
        self.assertNotEqual(broken.returncode, 0)
        self.assertIn("No module named 'pipes'", broken.stderr)
        self.assertEqual(self.repair().returncode, 0)
        for arguments, expected in [(['--help'], 'Usage:'), (['--format-size', '1024'], '1.02 KB')]:
            run = subprocess.run([str(self.python), '-c', 'from humanfriendly.cli import main;main()', *arguments],
                                 text=True, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn(expected, run.stdout + run.stderr)

    def test_actual_command_runner_keeps_quote_and_subprocess_argument_semantics(self):
        self.assertEqual(self.repair().returncode, 0)
        run = subprocess.run([str(self.python), '-c',
            'import sys,shlex;from humanfriendly import cli;'
            'assert cli.pipes.quote("a b") == shlex.quote("a b");'
            'assert cli.pipes.quote("a\\\'b") == shlex.quote("a\\\'b");'
            'cli.run_command([sys.executable,"-c","import sys;print(repr(sys.argv[1:]))","a b","a\\\'b",""])'],
            text=True, capture_output=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("['a b',", run.stdout)
        self.assertIn("'']", run.stdout)

    def test_idempotence_and_mode(self):
        self.assertEqual(self.repair().returncode, 0)
        first = self.path.read_bytes()
        self.assertEqual(self.repair().returncode, 0)
        self.assertEqual(self.path.read_bytes(), first)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)

    def test_unknown_source_shape_is_rejected_without_changes(self):
        self.path.write_bytes(self.path.read_bytes().replace(b'pipes.quote', b'pipes.unexpected'))
        original = self.path.read_bytes()
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertEqual(original, self.path.read_bytes())

    def test_unknown_package_version_is_rejected_without_changes(self):
        metadata = self.path.parent.parent / 'humanfriendly-10.0.dist-info/METADATA'
        metadata.write_bytes(metadata.read_bytes().replace(b'Version: 10.0', b'Version: 99.0'))
        original = self.path.read_bytes()
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertEqual(original, self.path.read_bytes())

    def test_linked_cli_is_rejected(self):
        original = self.path.parent / 'original'
        self.path.rename(original)
        self.path.symlink_to(original)
        self.assertNotEqual(self.repair().returncode, 0)

    def test_installation_repairs_after_fresh_and_retained_tool_paths(self):
        phase = SOURCE.split('phase_install_tools() {', 1)[1].split('phase_package_cmsscan()', 1)[0]
        self.assertLess(phase.index('cms_tool_run "$tool_hook"'), phase.index('cms_repair_humanfriendly_cli'))
        registry = (ROOT / 'scripts/install/tools.tsv').read_text()
        self.assertIn('aem_detector\taem_detector.sh\tinstall_aem_detector', registry)
        self.assertIn('"${VENV_DIR}/bin/humanfriendly" --help', SOURCE)


if __name__ == '__main__':
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
