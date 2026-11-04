#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Exercise the installer repair with isolated files, without sourcing/installing."""
import ast
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import warnings

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "installer.sh"
SOURCE = INSTALLER.read_text() + '\n' + (ROOT / 'scripts/install/tools/drupwn.sh').read_text()
START = "<<'PY_DRUPWN_BANNER'\n"
REPAIR = SOURCE.split(START, 1)[1].split("\nPY_DRUPWN_BANNER", 1)[0]
LEGACY_SOURCE = 'from engine.Dispatcher import Dispatcher\n__copyright__ = "Copyright 2018, ImmunIT"\n\ndef welcome():\n    print("""\n        ____\n       / __ \\_______  ______ _      ______\n      / / / / ___/ / / / __ \\ | /| / / __ \\\\\n     / /_/ / /  / /_/ / /_/ / |/ |/ / / / /\n    /_____/_/   \\__,_/ .___/|__/|__/_/ /_/\n                     /_/\n    """)\n\n'

class DrupwnBannerRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def fixture(self, name="drupwn", source=LEGACY_SOURCE):
        path = self.root / name
        path.write_text(source)
        path.chmod(0o750)
        return path

    def repair(self, *paths):
        return subprocess.run([sys.executable, "-", *(str(p) for p in paths)],
                              input=REPAIR, text=True, capture_output=True)

    def printed_value(self, text):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", SyntaxWarning)
            module = ast.parse(text)
        function = next(n for n in module.body if isinstance(n, ast.FunctionDef))
        return function.body[0].value.args[0].value

    def test_known_banner_repaired_without_changing_printed_value(self):
        path = self.fixture()
        before = self.printed_value(path.read_text())
        result = self.repair(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.printed_value(path.read_text()), before)
        with warnings.catch_warnings():
            warnings.simplefilter("error", SyntaxWarning)
            compile(path.read_text(), str(path), "exec")
        self.assertEqual(path.stat().st_mode & 0o777, 0o750)

    def test_repeated_repair_is_byte_identical(self):
        path = self.fixture()
        self.assertEqual(self.repair(path).returncode, 0)
        repaired = path.read_bytes()
        self.assertEqual(self.repair(path).returncode, 0)
        self.assertEqual(path.read_bytes(), repaired)

    def test_unsupported_banner_preserved(self):
        path = self.fixture(source=LEGACY_SOURCE.replace("____", "CHANGED", 1))
        before = path.read_bytes()
        self.assertNotEqual(self.repair(path).returncode, 0)
        self.assertEqual(path.read_bytes(), before)

    def test_all_candidates_validated_before_any_publication(self):
        first = self.fixture("scoped")
        second = self.fixture("legacy", LEGACY_SOURCE.replace("____", "CHANGED", 1))
        before = first.read_bytes()
        self.assertNotEqual(self.repair(first, second).returncode, 0)
        self.assertEqual(first.read_bytes(), before)

    def test_symlink_and_hardlink_are_not_modified(self):
        path = self.fixture()
        link = self.root / "symlink"
        link.symlink_to(path)
        before = path.read_bytes()
        self.assertNotEqual(self.repair(link).returncode, 0)
        self.assertEqual(path.read_bytes(), before)
        hard = self.root / "hardlink"
        os.link(path, hard)
        self.assertNotEqual(self.repair(hard).returncode, 0)
        self.assertEqual(path.read_bytes(), before)

    def test_missing_optional_legacy_entrypoint_is_allowed(self):
        path = self.fixture()
        self.assertEqual(self.repair(path, self.root / "missing").returncode, 0)

    def test_fresh_and_reuse_install_paths_invoke_repair(self):
        self.assertIn('cms_repair_drupwn_banners "${candidate_src}/drupwn"', SOURCE)
        self.assertIn('"${COMPAT_DIR}/drupwn-src/drupwn" "${VENV_DIR}/bin/drupwn"', SOURCE)
        self.assertIn('"${venv}/bin/drupwn" "${INSTALL_HOME}/.venv/bin/drupwn"', SOURCE)

if __name__ == "__main__":
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
