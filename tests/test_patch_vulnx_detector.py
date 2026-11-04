#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# VANTAGE / INFRA AI OU PROJECT NOTICE
# Project-maintained VAPT integration by Andrea Bodei and INFRA AI OU for the
# VANTAGE project under the European Commission DIGITAL programme.
# AUTHORIZED USE ONLY: governments, companies, professionals, and other entities
# may use these tools only with explicit permission to perform VAPT against each
# specific target and only within the approved scope and rules of engagement.
# This repository grants no explicit or implicit authorization to test any target.
# Andrea Bodei, INFRA AI OU, the VANTAGE project, the DIGITAL programme, and the
# European Commission disclaim responsibility for unauthorized use or misuse.
# See PROJECT_NOTICE.md; applicable licenses and upstream notices remain authoritative.

# Copyright © 2026 Andrea Bodei — www.andreabodei.com
"""Focused tests for the bounded VulnX detector hardening patch."""

from __future__ import annotations

import ast
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import stat
import sys
import tempfile
import types
import unittest

PATCHER_PATH = (
    Path(__file__).resolve().parents[1] / "scripts" / "patch_vulnx_detector.py"
)
SPEC = importlib.util.spec_from_file_location("patch_vulnx_detector", PATCHER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"unable to load {PATCHER_PATH}")
PATCHER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PATCHER
SPEC.loader.exec_module(PATCHER)


# This preserves the relevant layout and whitespace of upstream master
# bcf451d20941c674005f2b42407cb24fb69cfdab.
PRISTINE_DETECTOR = """\
class CMS(object):

    def __init__(
        self,url,
        headers=None,
        exploit=False,
        domain=False,
        webinfo=False,
        serveros=False,
        cmsinfo=False,
        dnsdump=False,
        port=False
        ):

        self.url = url
        self.headers = headers
        self.exploit = exploit
        self.domain = domain
        self.webinfo = webinfo
        self.serveros = serveros
        self.cmsinfo = cmsinfo
        self.dnsdump = dnsdump
        self.port = port

    
    def __getlmcontent__(self):
        lm_content = self.url + '/smiley/1.gif'
        return requests.get(lm_content, headers=self.headers,verify=False).text

    def __getlm2content__(self):
        lm2_content = self.url + '/rss.xml'
        return requests.get(lm2_content, headers=self.headers,verify=False).text
    
    def __getcontent__(self):
        return requests.get(self.url, headers=self.headers,verify=False).text
"""


class PatchVulnxDetectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.directory = Path(self.temporary_directory.name)

    def detector(self, source: str = PRISTINE_DETECTOR, mode: int = 0o640) -> Path:
        path = self.directory / "detector.py"
        path.write_text(source, encoding="utf-8", newline="")
        os.chmod(path, mode)
        return path

    def assert_unmodified_after_failure(self, path: Path) -> None:
        before_data = path.read_bytes()
        before_mode = stat.S_IMODE(path.stat().st_mode)
        before_entries = sorted(item.name for item in path.parent.iterdir())
        with self.assertRaises(PATCHER.PatchError):
            PATCHER.patch_detector(path)
        self.assertEqual(path.read_bytes(), before_data)
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), before_mode)
        self.assertEqual(
            sorted(item.name for item in path.parent.iterdir()),
            before_entries,
        )

    def test_pristine_current_layout_is_hardened_and_mode_is_preserved(
        self,
    ) -> None:
        path = self.detector(mode=0o751)

        self.assertTrue(PATCHER.patch_detector(path))

        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)
        helpers = [
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.FunctionDef) and node.name == "_safe_get_text"
        ]
        self.assertEqual(len(helpers), 1)
        self.assertEqual(source.count("return self._safe_get_text("), 3)
        self.assertEqual(source.count("requests.get("), 1)
        self.assertIn("timeout=12", source)
        self.assertIn("except requests.exceptions.RequestException:", source)
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o751)
        compile(source, str(path), "exec")

    def test_formatting_variations_do_not_break_structural_patch(self) -> None:
        source = PRISTINE_DETECTOR.replace(
            "        self.port = port\n\n    \n",
            "        self.port=port\n\n",
        )
        source = source.replace(
            "requests.get(lm_content, headers=self.headers,verify=False)",
            "requests.get( lm_content, verify = False, headers = self.headers )",
        )
        source = source.replace(
            "requests.get(lm2_content, headers=self.headers,verify=False)",
            "requests.get(lm2_content,verify=False,headers=self.headers)",
        )
        source = source.replace(
            "requests.get(self.url, headers=self.headers,verify=False)",
            "requests.get( self.url, headers = self.headers, verify = False )",
        )
        path = self.detector(source)

        self.assertTrue(PATCHER.patch_detector(path))
        patched = path.read_text(encoding="utf-8")
        self.assertEqual(patched.count("def _safe_get_text(self, url):"), 1)
        self.assertEqual(patched.count("return self._safe_get_text("), 3)

    def test_second_run_accepts_already_hardened_input_without_rewrite(
        self,
    ) -> None:
        path = self.detector()
        self.assertTrue(PATCHER.patch_detector(path))
        first_data = path.read_bytes()
        first_stat = path.stat()

        self.assertFalse(PATCHER.patch_detector(path))

        self.assertEqual(path.read_bytes(), first_data)
        self.assertEqual(path.stat().st_ino, first_stat.st_ino)
        self.assertEqual(path.stat().st_mtime_ns, first_stat.st_mtime_ns)

    def test_partial_patch_fails_without_modifying_source(self) -> None:
        path = self.detector()
        PATCHER.patch_detector(path)
        partial = path.read_text(encoding="utf-8").replace(
            "return self._safe_get_text(lm_content)",
            "return requests.get("
            "lm_content, headers=self.headers, verify=False).text",
        )
        path.write_text(partial, encoding="utf-8", newline="")

        self.assert_unmodified_after_failure(path)

    def test_unknown_getter_shape_fails_without_modifying_source(self) -> None:
        source = PRISTINE_DETECTOR.replace(
            "requests.get(self.url, headers=self.headers,verify=False)",
            "requests.post(self.url, headers=self.headers, verify=False)",
        )
        path = self.detector(source)

        self.assert_unmodified_after_failure(path)

    def test_extra_getter_behavior_is_treated_as_unknown(self) -> None:
        source = PRISTINE_DETECTOR.replace(
            "    def __getcontent__(self):\n",
            "    def __getcontent__(self):\n" "        audit_request(self.url)\n",
        )
        path = self.detector(source)

        self.assert_unmodified_after_failure(path)

    def test_invalid_existing_helper_fails_without_modifying_source(
        self,
    ) -> None:
        path = self.detector()
        PATCHER.patch_detector(path)
        invalid = path.read_text(encoding="utf-8").replace("timeout=12", "timeout=30")
        path.write_text(invalid, encoding="utf-8", newline="")

        self.assert_unmodified_after_failure(path)

    def test_duplicate_helper_fails_without_modifying_source(self) -> None:
        path = self.detector()
        PATCHER.patch_detector(path)
        hardened = path.read_text(encoding="utf-8")
        helper_start = hardened.index("    def _safe_get_text")
        first_getter = hardened.index("    def __getlmcontent__", helper_start)
        helper_block = hardened[helper_start:first_getter]
        duplicate = hardened[:first_getter] + helper_block + hardened[first_getter:]
        path.write_text(duplicate, encoding="utf-8", newline="")

        self.assert_unmodified_after_failure(path)

    def test_helper_runtime_uses_timeout_and_catches_request_exception(
        self,
    ) -> None:
        path = self.detector()
        PATCHER.patch_detector(path)

        class RequestException(Exception):
            pass

        class Timeout(RequestException):
            pass

        calls: list[tuple[str, dict[str, object]]] = []

        def raise_timeout(url: str, **kwargs: object) -> object:
            calls.append((url, kwargs))
            raise Timeout("timed out")

        fake_requests = types.SimpleNamespace(
            exceptions=types.SimpleNamespace(RequestException=RequestException),
            get=raise_timeout,
        )
        namespace: dict[str, object] = {"requests": fake_requests}
        exec(
            compile(
                path.read_text(encoding="utf-8"),
                str(path),
                "exec",
            ),
            namespace,
        )
        cms_class = namespace["CMS"]
        cms = cms_class("https://example.test", headers={"X-Test": "1"})

        self.assertEqual(cms.__getcontent__(), "")
        self.assertEqual(cms.__getlmcontent__(), "")
        self.assertEqual(cms.__getlm2content__(), "")
        self.assertEqual(len(calls), 3)
        for _, kwargs in calls:
            self.assertEqual(kwargs["headers"], {"X-Test": "1"})
            self.assertIs(kwargs["verify"], False)
            self.assertEqual(kwargs["timeout"], 12)

        def successful_get(url: str, **kwargs: object) -> object:
            calls.append((url, kwargs))
            return types.SimpleNamespace(text="response text")

        fake_requests.get = successful_get
        self.assertEqual(cms.__getcontent__(), "response text")

    def test_cli_accepts_detector_path_argument(self) -> None:
        path = self.detector()
        output = io.StringIO()
        errors = io.StringIO()

        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            result = PATCHER.main([str(path)])

        self.assertEqual(result, 0)
        self.assertIn("detector patched:", output.getvalue())
        self.assertEqual(errors.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
