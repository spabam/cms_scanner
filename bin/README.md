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

# CMS Compatibility Launchers

**Copyright © 2026 Andrea Bodei — www.andreabodei.com**

## Summary

This directory contains installer-managed compatibility launchers that give
vendored CMS tools stable private entrypoints and the required language,
identity, state, and runtime paths.

## Topics

- [Launcher contract](#cms-compatibility-launchers)
- [Progress ownership](#progress-ownership)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

This directory contains project-maintained shell launchers generated or
refreshed by `../installer.sh`. Each launcher provides a stable command for an
upstream CMS tool while directing Python, Ruby, Perl, state, and compatibility
paths to the environment prepared by the installer.

These files are private support entrypoints, not independent operator
interfaces. The aggregate interface is `/usr/bin/cmsscan` or
`/usr/bin/cmscan`; both cross the central dispatcher to `aiuser` once before
the private worker uses these launchers. `cmsscan-python` supplies the component
interpreter. The private `cmsscan-server` adapter serves the optional CMSScan
browser interface through Gunicorn at `127.0.0.1:5000`; administrative use inside
the dispatched CMS runtime can pass `--bind 127.0.0.1:5050` or other Gunicorn
options. `clusterd` is installed as an auxiliary command but is not selected
by the aggregate runner.

The `aem-hacker` adapter performs seven bounded upstream GET-only fingerprints.
The upstream full callback-based CLI remains a separate source entrypoint with
its own required configuration.

## Progress ownership

The maintained `cmsscan`/`cmscan` parent owns progress for every selected
upstream launcher. It publishes the exact 32-cell terminal line and one private
hidden pair, `.cmsscan.<uid>.<UTC timestamp>.progress` and `.log`; path
overrides and quiet/managed behavior are documented in
[`../README.md`](../README.md#runtime-progress-contract). These compatibility
launchers do not create extra top-level progress identities, and VAPTScan must
not count them in addition to their parent. Raw upstream commands have their own
interfaces and sit outside the public progress/report contract; maintained
adapters continue to require the dispatched `aiuser` identity.
The parent alone publishes 100, after its consolidated report has been
verified.

The launchers may contain installation-specific absolute paths and can be
regenerated. Do not run active, exploit, or credential-oriented upstream tools
unless the target and technique are explicitly authorized.

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
