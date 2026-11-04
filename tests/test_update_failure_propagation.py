#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
"""Required update outcomes with actual hooks and disposable/stubbed mutations."""
import ast
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "installer.sh"
ENGINE = INSTALLER.parents[2] / "orchestra/suite-installer/lib/engine.py"
HOOKS = ("wpscan", "cmsmap", "droopescan", "drupwn", "fingerprinter")


class UpdateFailurePropagationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cms-update-outcomes-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def run_case(self, body):
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith(("VI_", "BASH_FUNC_"))}
        environment["CMS_TEST_ROOT"] = str(self.root)
        setup = r'''
set -euo pipefail
source "$1"
log() { :; }
CASE="$CMS_TEST_ROOT"
vi_event() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${VI_COMPONENT_ID:-wa.cms}" "$VI_PHASE" "${1^^}" "$2" "$3" "$4" "$5" >>"$CASE/events"
}
UPDATE_FAILED=(); UPDATED=(); UPDATE_SKIPPED=(); FAILED=(); WARNINGS=(); SKIPPED=()
CMS_EVENT_FAILURE_STATUS=0
UPDATE_EXISTING=1; RUN_FULL_DATA_REFRESH=1
'''
        return subprocess.run(["/bin/bash", "-c", setup + body, "fixture", str(INSTALLER)],
                              env=environment, text=True, capture_output=True, timeout=20)

    def success_hooks(self, exclude=""):
        return "\n".join(f'update_{name}_database() {{ mark_updated {name}; }}'
                         for name in HOOKS if name != exclude) + "\n"

    def records(self):
        target = self.root / "events"
        fields = ("component_id", "phase", "kind", "operation", "status", "code", "message")
        return [dict(zip(fields, line.split("\t", 6))) for line in target.read_text().splitlines()]

    def result_reduction(self, records):
        # Exercise the real final-result reduction and warning-count expression
        # without entering frontend(), provisioning, or creating a run context.
        tree = ast.parse(ENGINE.read_text())
        frontend = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "frontend")
        # The reduction loop and warning-count dict may live inside nested blocks
        # (e.g. the InstallerProgress context manager), so walk the whole function
        # rather than only its top-level body.
        def assigns_optional(loop):
            return any(isinstance(target, ast.Subscript) and isinstance(target.value, ast.Name)
                       and target.value.id == "optional_operations"
                       for inner in ast.walk(loop) if isinstance(inner, ast.Assign)
                       for target in inner.targets)
        reduction = min((node for node in ast.walk(frontend)
                         if isinstance(node, ast.For) and assigns_optional(node)),
                        key=lambda node: node.lineno)
        warning = next(keyword.value for node in ast.walk(frontend) if isinstance(node, ast.Assign)
                       and isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name)
                       and node.value.func.id == "dict" for keyword in node.value.keywords
                       if keyword.arg == "warning_count")
        states = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign)
                      and any(isinstance(target, ast.Name) and target.id == "STATES" for target in node.targets))
        namespace = dict(records=records, STATES=states, terminal_operations={}, optional_operations={})
        exec(compile(ast.Module(body=[reduction], type_ignores=[]), str(ENGINE), "exec"), namespace)
        count = eval(compile(ast.Expression(warning), str(ENGINE), "eval"), namespace)
        return namespace["terminal_operations"], namespace["optional_operations"], count

    def test_unrecorded_failure_preserves_native_status_after_later_success(self):
        result = self.run_case(self.success_hooks("wpscan") + r'''
update_wpscan_database() { return 37; }
status=0; phase_update_scanner_data || status=$?
[[ "$status" == 37 && ${#UPDATE_FAILED[@]} == 1 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        terminal, _, _ = self.result_reduction(self.records())
        self.assertEqual(terminal[("wa.cms", "configure", "cms.update.wpscan")]["status"], "failed")
        self.assertEqual(terminal[("wa.cms", "configure", "cms.update.fingerprinter")]["status"], "succeeded")
        self.assertIn("exited 37", terminal[("wa.cms", "configure", "cms.update.wpscan")]["message"])

    def test_recorded_failure_is_not_duplicated(self):
        result = self.run_case(self.success_hooks("wpscan") + r'''
update_wpscan_database() { mark_update_failed wpscan simulated; return 23; }
status=0; phase_update_scanner_data || status=$?
[[ "$status" == 23 && ${#UPDATE_FAILED[@]} == 1 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_recorded_failure_returning_zero_still_fails(self):
        result = self.run_case(self.success_hooks("wpscan") + r'''
update_wpscan_database() { mark_update_failed wpscan simulated; return 0; }
status=0; phase_update_scanner_data || status=$?
[[ "$status" == 1 && ${#UPDATE_FAILED[@]} == 1 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def main_stubs(self):
        return r'''
phase_preflight() { :; }; phase_system_dependencies() { :; }
phase_python_environment() { :; }; phase_install_tools() { :; }
verify_install_artifacts() { printf 'verified\n' >"$CASE/verified"; }
phase_package_cmsscan() { printf 'published\n' >"$CASE/packaged"; }
cleanup_legacy_project_venvs() { :; }; cleanup_git_index_conflict_sidecars() { :; }
print_summary() { printf 'failures=%s\n' "${#UPDATE_FAILED[@]}"; }
'''

    def test_real_bulk_temp_registration_failures_block_main_and_packaging(self):
        for name in HOOKS[2:]:
            with self.subTest(hook=name):
                (self.root / "events").unlink(missing_ok=True)
                body = self.success_hooks(name) + self.main_stubs() + r'''
VENV_DIR="$CASE/venv"; BIN_DIR="$CASE/bin"; COMPAT_DIR="$CASE/compat"
mkdir -p "$VENV_DIR/bin" "$BIN_DIR" "$CASE/plugins" \
  "$COMPAT_DIR/drupwn-src/plugins/wordlists" "$COMPAT_DIR/fingerprinter-src/db"
: >"$VENV_DIR/bin/droopescan"; chmod 700 "$VENV_DIR/bin/droopescan"
: >"$BIN_DIR/fingerprinter"; chmod 700 "$BIN_DIR/fingerprinter"
: >"$COMPAT_DIR/drupwn-src/drupwn"
printf 'fixture\n' >"$COMPAT_DIR/drupwn-src/plugins/wordlists/plugins.txt"
: >"$CASE/prepared-backup"
capture_user_cmd() {
  if [[ "$1" == mktemp ]]; then printf '%s\n' "$CASE/prepared-backup";
  else printf '%s\n' "$CASE/plugins"; fi
}
vantage_register_temp_path() { printf 'registration\n' >>"$CASE/registration"; return 17; }
main --full-data-refresh
'''
                result = self.run_case(body)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("failures=1", result.stdout)
                self.assertFalse((self.root / "packaged").exists())
                self.assertTrue((self.root / "registration").exists())
                self.assertTrue(any(record["operation"] == f"cms.update.{name}" and record["status"] == "failed"
                                    for record in self.records()))
                self.assertTrue(any(record["operation"] == "cms.phase.scanner_database_updates" and record["kind"] == "FAIL"
                                    for record in self.records()))

    def test_success_retains_five_separate_final_operation_ids(self):
        result = self.run_case(self.success_hooks() + "phase_update_scanner_data\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        terminal, _, _ = self.result_reduction(self.records())
        self.assertEqual(set(terminal), {("wa.cms", "configure", "cms.update." + name) for name in HOOKS})
        self.assertTrue(all(record["status"] == "succeeded" for record in terminal.values()))

    def test_default_policy_does_not_run_opt_in_bulk_hooks(self):
        body = self.success_hooks() + r'''
RUN_FULL_DATA_REFRESH=0
update_droopescan_database() { printf 'unexpected'; return 99; }
update_drupwn_database() { printf 'unexpected'; return 99; }
update_fingerprinter_database() { printf 'unexpected'; return 99; }
phase_update_scanner_data
'''
        result = self.run_case(body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("unexpected", result.stdout)
        skipped = {record["operation"] for record in self.records() if record["status"] == "not_applicable"}
        self.assertEqual(skipped, {"cms.update." + name for name in HOOKS[2:]})

    def test_unscoped_tool_update_records_remain_compatible(self):
        result = self.run_case("mark_updated source-probe\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.records()[0]["operation"], "cms.update")

    def test_cancellation_stops_later_updaters_and_main(self):
        result = self.run_case(self.success_hooks("wpscan") + self.main_stubs() + r'''
update_wpscan_database() { return 143; }
update_cmsmap_database() { printf 'unexpected' >"$CASE/later-updater"; }
main --full-data-refresh
''')
        self.assertEqual(result.returncode, 143, result.stderr)
        self.assertFalse((self.root / "later-updater").exists())
        self.assertFalse((self.root / "verified").exists())
        self.assertFalse((self.root / "packaged").exists())

    def test_optional_warning_history_survives_latest_shared_key_success(self):
        common = dict(component_id="wa.zap.common", phase="configure", operation="zap.addons")
        records = [dict(common, kind="WARNING", status="failed", code="17"),
                   dict(common, kind="RESULT", status="succeeded", code="0")]
        terminal, optional, warnings = self.result_reduction(records)
        key = ("wa.zap.common", "configure", "zap.addons")
        self.assertEqual(terminal[key]["status"], "succeeded")
        self.assertEqual(optional[key]["status"], "failed")
        self.assertEqual(warnings, 1)
        records.append(dict(common, kind="OPTIONAL", status="succeeded", code="0"))
        _, optional, warnings = self.result_reduction(records)
        self.assertEqual(optional[key]["status"], "succeeded")
        self.assertEqual(warnings, 1)
        self.assertEqual(len(records), 3)


if __name__ == "__main__":
    unittest.main()
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
