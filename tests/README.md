<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
<!--
VANTAGE / INFRA AI OU PROJECT NOTICE
Project-maintained VAPT integration by Andrea Bodei and INFRA AI OU for the
VANTAGE project under the European Commission DIGITAL programme.
AUTHORIZED USE ONLY: governments, companies, professionals, and other entities
may use these tools only with explicit permission to perform VAPT against each
specific target and only within the approved scope and rules of engagement.
This repository grants no explicit or implicit authorization to test any target.
Andrea Bodei, INFRA AI OU, the VANTAGE project, the DIGITAL programme, and the
European Commission disclaim responsibility for unauthorized use or misuse.
See PROJECT_NOTICE.md; applicable licenses and upstream notices remain authoritative.
-->

# CMS Scanner Tests

**Copyright © 2026 Andrea Bodei — www.andreabodei.com**

## Summary

This test suite verifies CMS installer helpers, compatibility and
update policy, runtime identity, bounded patches, consolidated reporting, and
the public progress/log contract.

## Topics

- [Test coverage](#cms-scanner-tests)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

These offline tests cover project-maintained installer helpers, safe repair of
root-created ownership residue in the canonical Python virtualenv, update
policy, Fingerprinter locked-runtime health, version-aware skip behavior, and
the bounded VulnX detector patch. Progress tests cover the exact 32-cell
renderer, private paired `.cmsscan.<uid>.<UTC timestamp>.progress`/`.log`
identity, override precedence, atomic monotonic scalar updates,
file-preserving managed mode, and report-gated 100. The ownership cases also
verify atomic refusal of foreign ownership and protection against external
hardlinks. The mocked unit suites do not assess external targets.

Focused Python regressions also exercise the installed compatibility code:

| Test file | Coverage |
| --- | --- |
| `test_drupwn_banner_repair.py` | Known banner escape repair without changing other source |
| `test_wpseku_json_repair.py` | Actual JSON parser methods and invalid-response fallback |
| `test_aem_detector_adapter.py` | Actual GET-only upstream detectors against a temporary local HTTP fixture |
| `test_clusterd_runtime_repair.py` | Standard-library import selection and real local positive/negative fingerprints |
| `test_autowpscan_environment_repair.py` | Actual subprocess method with absent, blank, and configured optional API tokens |
| `test_humanfriendly_cli_repair.py` | Python 3.13 CLI import, formatting, and command argument handling |
| `test_cmsscan_production_launcher.py` | Literal Gunicorn startup, actual CMSScan HTTP routes, SQLite, and shutdown |
| `test_runner_logger_repair.py` | Real local CMSeeK reports, delayed/failing log writers, and protected source repair |

These regressions use private temporary copies and local fixture services.
The production-launcher check also performs CMSScan's ordinary WPScan metadata
update, so it is not fully offline. Identity and protected-source fixtures need
an administrative test session and the already provisioned CMS environment.
They do not install scanner packages or start system services.

The workspace installer owns test dependencies. Run the checks from the VAPT
workspace root explicitly as `aiuser`:

```bash
runtime_home="$(/usr/bin/getent passwd aiuser | /usr/bin/cut -d: -f6)"
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_installer_helpers.sh
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_installer_update_policy.sh
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_installer_fingerprinter_health.sh
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_installer_version_skip.sh
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_progress_contract.sh
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_standalone_component_runtime.sh
sudo -H -u aiuser "${runtime_home}/.local/share/vantage/cms_scanner/venv/bin/python" -m pytest -q WA-SCAN/cms_scanner/tests/test_patch_vulnx_detector.py
```

The shell harnesses mock installer operations and use temporary directories.
The detector-patch test above requires `pytest`; the listed compatibility files
use Python's `unittest` runner and can be invoked individually with
`sudo /usr/bin/python3 WA-SCAN/cms_scanner/tests/<test-file>.py` in the
administrative fixture environment. A green result verifies the tested
contracts, not the behavior or safety of every bundled upstream CMS tool.
The progress test uses a mocked child scanner and report, so it verifies the
parent producer contract without contacting a target.

<!-- VANTAGE-PYTHON-ENV-STANDARD:START -->
## VANTAGE Python environment standard

Every CMS scanner Python command uses the fixed passwd account `aiuser` and its
component environment at
`/home/aiuser/.local/share/vantage/cms_scanner/venv`. It never
uses the caller or root account's `HOME`, an activated environment, a project-local
environment, bare `pip` or `pip3`, or `pip --user`.

From any account, use the workspace installer; it resolves `aiuser` through the
passwd database and switches identity before creating the environment or
installing a package:

```text
sudo /home/spabam/Dropbox/Public/VANTAGE/VAPT/installer.sh --only WA-SCAN
```

Pip is always interpreter-bound (`/home/aiuser/.local/share/vantage/cms_scanner/venv/bin/python -m pip`). Managed
project installers and launchers apply the same identity transition automatically.
Before a managed installation starts, its `installer.sh` checks the system passwd
database; if `aiuser` is absent, the canonical privileged runtime helper creates
and validates the account. Help, dry-run, and read-only inspection modes never
create it. Runtime tools never install or repair packages; provision dependencies
first. Any contradictory upstream setup command elsewhere in this file is
reference-only in this integration—use the VANTAGE installer or launcher instead. A container, OS-managed
service, or dependency-incompatible upstream application may use a separate
environment only under `aiuser` (or inside its isolated filesystem) and only
when its component documentation explicitly says so.
<!-- VANTAGE-PYTHON-ENV-STANDARD:END -->
<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
