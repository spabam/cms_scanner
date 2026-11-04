<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
# CMS Scanner Reports

**Copyright © 2026 Andrea Bodei — www.andreabodei.com**

## Summary

This directory documents consolidated CMS scan reports, auxiliary upstream
artifacts, their progress-completion boundary, and handling requirements for
sensitive generated evidence.

## Topics

- [Report contents and naming](#cms-scanner-reports)
- [Progress completion boundary](#progress-completion-boundary)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

When no report path is supplied, `/usr/bin/cmsscan` writes a consolidated
`<normalized-target>[_<port>].cms.txt` report in its dispatcher-assigned
`aiuser` results spool. An operator may supply a report destination, which the
dispatcher resolves and validates before invoking the private worker.

Choose an explicit absolute writable destination when retaining this native
text report. `.cms.txt` reports and per-tool logs are outside the standard
canonical JSON/HTML copyback list, and private spools are retired after the run.
Ensure the intended operators can read the selected destination.

Each text report records the normalized target, selected scanners, command
status, captured tool output, skips, failures, and summary counters. Upstream
tools may also create auxiliary artifacts in this directory.

## Progress completion boundary

The public `.cmsscan.<uid>.<UTC timestamp>.progress` file stays below 100 while
the consolidated report is being assembled. Values 96–99 cover final report
work; 100 is published only after the non-empty report and its final summary
have been verified. A parent failure or interruption before that boundary
retains its last incomplete scalar. A nested child tool's non-zero exit or
timeout is instead recorded in the consolidated summary because the parent
continues the remaining selected work. The private hidden
`.progress`/`.log` pair uses the same basename, and the
canonical 32-cell progress line remains available there when terminal progress
is suppressed by `--quiet` or `VAPTSCAN_MANAGED_PROGRESS=1`. CLI path overrides
precede command-specific and generic environment overrides. See the
[component contract](../README.md#runtime-progress-contract)
for path overrides and aggregation ownership.

Reports can disclose vulnerabilities, URLs, software versions, usernames, and
credential-audit results. They are generated assessment evidence: restrict
access, do not treat them as source files, and follow the agreed retention and
destruction policy.

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
