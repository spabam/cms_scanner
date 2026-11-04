<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
# CMS Scanner Logs

**Copyright © 2026 Andrea Bodei — www.andreabodei.com**

## Summary

This directory documents CMS scanner runtime and installer log layers, their
separate progress ownership, and the controls required for generated evidence
that may contain targets, tokens, or credential-audit output.

## Topics

- [Runtime log layers](#runtime-log-layers)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

## Runtime log layers

Every maintained `/usr/bin/cmsscan` or `/usr/bin/cmscan` invocation creates a
private hidden pair in its dispatcher-assigned `aiuser` spool:

```text
.cmsscan.<aiuser-uid>.<UTC timestamp>.progress
.cmsscan.<aiuser-uid>.<UTC timestamp>.log
```

The paired log records the canonical 32-cell progress lines even when
`--quiet` or `VAPTSCAN_MANAGED_PROGRESS=1` suppresses them on stdout. Both
files are mode `0600`; validated `--progress-file` and `--log-file` options can
relocate them without changing runtime identity.
The public scalar reaches 100 only after the consolidated report is verified.

Separately, CMS scans create one detailed run directory named
`<timestamp>_<normalized-target>/` beneath the assigned run's `logs/` directory.
This checkout directory holds historical or explicitly directed logs. A run contains
`run.log`, per-tool logs, probe output, and tool-specific runtime state.
Installer diagnostics may also appear directly here. These detailed child
logs do not create additional progress activities: the `cmsscan` parent owns
the selected upstream work.

The runner waits for its log writer to finish before returning, so the canonical
paired log and `run.log` finish flushing together. Writer failure is returned
as a nonzero status when no earlier worker failure already applies. Current
private-spool logs are retired with the run. Use an explicit absolute
`--log-file` for the canonical runtime log and an explicit report destination
for the per-tool output captured in the consolidated report.

Per-run directories and log files are generated evidence and are not
documented or modified individually. They may contain target details,
commands, upstream scanner output, tokens supplied to tools, or credential
testing results. Keep the directory private and apply the engagement's
retention policy.

The naming, override precedence, and report-gated completion rules are in the
[component progress contract](../README.md#runtime-progress-contract).

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
