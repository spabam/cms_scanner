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

# CMS Scanner Support Scripts

**Copyright © 2026 Andrea Bodei — www.andreabodei.com**

## Summary

These scripts implement the encrypted private worker, installer helpers,
compatibility staging, report return, and progress/log boundary behind the CMS
scanner's public commands.

## Topics

- [Support-script inventory](#cms-scanner-support-scripts)
- [Progress implementation boundary](#progress-implementation-boundary)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

This directory holds the maintained support layer for `cms_scanner`.

- `cmsscan.wrapper` is the private worker invoked after the central dispatcher
  has crossed to `aiuser`. It decrypts the installed runtime archive into a private
  temporary directory, launches the bundled `run_cms_scanner.sh`, returns the requested
  report, initializes and delegates the public progress paths, and removes
  temporary material. The installer compiles this wrapper with `shc`; that
  packaging is obfuscation, not a security boundary.
- `patch_vulnx_detector.py` applies and validates the narrowly scoped HTTP
  compatibility patch required by the bundled VulnX integration.

Inputs originate from the workspace installer or `/usr/bin/cmsscan`
invocation. Operators do not invoke these scripts directly. Consolidated scan output is a text report; detailed per-tool logs
and temporary artifacts are described in `../README.md`.

## Progress implementation boundary

The wrapper initializes the public hidden
`.cmsscan.<uid>.<UTC timestamp>.progress` and `.log` pair, then delegates those
same paths to the runner. Selected upstream CMS commands are nested children,
not new VAPTScan activities. The wrapper and runner preserve file/log updates in
`--quiet` and `VAPTSCAN_MANAGED_PROGRESS=1` modes, render the exact 32-cell
line when stdout is enabled, and withhold 100 until the consolidated report is
present and valid. CLI overrides precede `CMSSCAN_*`/`CMSCAN_*`, then
`INFRA_*`. The [component contract](../README.md#runtime-progress-contract) is
authoritative.

The installer also stages the runner's log-writer lifecycle repair before
building its encrypted archive. The runner closes the logging pipe and waits
for its writer during cleanup, preserving the original worker failure or
returning a logger failure when the assessment otherwise completed.

Focused tests live in `../tests/`. The wrapper handles authentication-derived
archive material, so logs and extracted temporary content must not be
published. Run only against explicitly authorized targets.

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
