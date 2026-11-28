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

# Universal CMS Vulnerability Scanner

**Copyright © 2026 Andrea Bodei — www.andreabodei.com**

Copyright (c) 2026-2036 Andrea Bodei - info at andreabodei.com

## Summary

The Universal CMS Vulnerability Scanner coordinates multiple upstream CMS
security tools behind one target-normalizing, dispatcher-managed command with
consolidated reports and bounded runtime progress.

## Bundled open-source tools (possibly modified)

This repository **includes third-party open-source tools** in `tools/`: AutoWPScan, CMSScan,
CMSeeK, CMSmap, WPForce, WPSeku, aem-hacker, clusterd, drupwn, Fingerprinter, JoomlaVS,
OWASP JoomScan, OWASP VBScan and VulnX. They were written by their own authors, not by this
project, and **the copies here may be modified versions** of the originals: comments added at
the top of files, Python environment and path adjustments, and a few integration fixes. Each
tool keeps its upstream licence file unchanged (GPL-3.0, MIT, Apache-2.0, BSD-2-Clause, and
CC BY-NC 4.0 for Fingerprinter, which allows non-commercial use only); the original copyright
stays with the upstream authors. [`tools/THIRD_PARTY.md`](tools/THIRD_PARTY.md) lists each
tool's upstream repository, the commit this copy started from, its licence, and the files that
differ from upstream. For an unmodified tool, use its upstream project.

## Topics

- [Bundled open-source tools (possibly modified)](#bundled-open-source-tools-possibly-modified)
- [Supported tools](#supported-tools)
- [Installation and fixed runtime identity](#installation-and-fixed-runtime-identity)
- [Public commands and private workers](#public-commands-and-private-workers)
- [Quick usage](#quick-usage)
- [Scanner selection](#scanner-selection)
- [Target resolution](#target-resolution)
- [Tor behavior](#tor-behavior)
- [Reports and logs](#reports-and-logs)
- [Runtime progress contract](#runtime-progress-contract)
- [Update and compatibility policy](#update-and-compatibility-policy)
- [Offline verification](#offline-verification)
- [Documentation map](#documentation-map)
- [Legal notice](#legal-notice)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

The Universal CMS Vulnerability Scanner integrates several open-source CMS
security tools behind one maintained command. It normalizes the authorized
target, detects the CMS, selects applicable scanners, and creates a consolidated
result with per-tool evidence.

## Supported tools

| Tool | Principal coverage |
| --- | --- |
| WPScan | WordPress core, plugin, theme, and vulnerability enumeration |
| CMSmap | WordPress, Joomla, Drupal, and Moodle |
| CMSeek | Broad CMS fingerprinting and enumeration |
| Droopescan | Drupal, Joomla, SilverStripe, WordPress, and Moodle |
| JoomScan / joomlavs | Joomla |
| Drupwn | Drupal |
| VBScan | vBulletin |
| CMSScan | WordPress, Drupal, Joomla, and vBulletin detection |
| VulnX | WordPress, Joomla, Drupal, OpenCart, and PrestaShop |
| WPSeku, WPXF, WPForce, AutoWPScan | WordPress |
| Fingerprinter | CMS fingerprinting for mapped applications |
| AEM Detector / AEM Discoverer | Adobe Experience Manager; the detector uses seven upstream GET-only fingerprint routines without callback listeners or state-changing checks |

Clusterd is installed and verified as an auxiliary compatibility tool but is
not a selectable CMS-scan stage.

The optional CMSScan browser interface lets administrators schedule assessments,
review saved scans, and open their results. Its private `cmsscan-server`
component adapter requires a dispatched `aiuser` CMS runtime. It uses the
already installed Gunicorn production server and
listens at `http://127.0.0.1:5000` by default. Pass
`--bind 127.0.0.1:5050` to choose another local port; standard Gunicorn options
are supported.

The `aem-hacker` selector uses seven upstream GET-only fingerprints with bounded
workers and timeouts. The upstream callback-based full CLI remains in the
installed source for separately configured use; the universal selector does
not start that workflow.

## Installation and fixed runtime identity

Install from the VAPT workspace root:

```bash
sudo ./installer.sh --only WA-SCAN
```

The workspace installer is the supported installation interface. It:

- creates and maintains the fixed service account `aiuser`;
- creates the CMS-scoped Python environment at
  `/home/aiuser/.local/share/vantage/cms_scanner/venv`;
- executes every venv and pip operation as `aiuser`, even when the installer
  itself needs root for system packages, `/opt`, or `/usr/bin`;
- installs and verifies the encrypted CMS worker and public command aliases;
- reconciles CMS dependency constraints and rejects newly introduced
  `pip check` conflicts; and
- retains root only for the installation steps that actually require it.

The installer provisions the required Python/Ruby/Perl tools, native build and
XML/XSLT libraries, Git/download utilities, Tor/torsocks, and p7zip/SHC packaging
support selected by its dependency phase. WPScan/WPXF/joomlavs use Ruby tooling;
JoomScan/VBScan use Perl; the other integrations use their declared Python or
shell dependencies. These runtimes support the tools in the inventory above,
rather than adding extra selectable scanners.

System dependencies, the canonical Python environment, tool installation,
scanner database updates, post-install verification, and encrypted wrapper
publication are required phases. A nonzero phase result prevents the success
banner even if a tool-specific failure list is empty. Packaging is attempted
only after installation, refreshes, and verification have all passed. The
combined WA installer validates every configured child installer before it
starts the first one, so a missing or unsafe child cannot silently disappear
from its toolset.

Do not create a caller-home virtual environment, activate a project venv, run pip
manually, or invoke a component installer to choose another account. Caller
identity, privilege-invocation metadata, and caller-supplied home, Python, pip, or install-user
variables do not select the installed runtime.

For an administrative dependency check, use the fixed identity explicitly:

```bash
sudo -H -u aiuser /home/aiuser/.local/share/vantage/cms_scanner/venv/bin/python -m pip check
```

That command is for verification only. Dependency changes go through the
workspace installer.

## Public commands and private workers

Operators use only these installed entrypoints:

```text
/usr/bin/cmsscan
/usr/bin/cmscan
```

Both aliases enter `/usr/bin/infra-scan-main`. The dispatcher validates the
request, prepares a protected results/runtime spool, sanitizes caller-controlled
environment state, and changes to `aiuser` exactly once. It then invokes the
private CMS worker at `/opt/infrascan/bin/cmsscan`.

`run_cms_scanner.sh`, files under `scripts/`, source-tree Python programs, and
individual upstream tools under `tools/` are implementation details. They are
not alternate operator interfaces and must not be called to bypass the public
dispatcher.

When `/usr/bin/webscan --full` includes CMS scanning, Webscan has already made
the one dispatcher transition. Its private worker therefore invokes the exact
private CMS worker rather than recursively calling `/usr/bin/cmsscan`. This
keeps the entire nested workflow under the same `aiuser` identity and the same
parent run spool.

## Quick usage

Run the full CMS workflow:

```bash
/usr/bin/cmsscan https://target.example
```

Run a selected scanner:

```bash
/usr/bin/cmsscan --scanner wpscan https://target.example
/usr/bin/cmsscan --scanner droopescan https://target.example
```

Make the default all-scanner selection explicit:

```bash
/usr/bin/cmsscan --scanner all https://target.example
```

Use the compatibility alias:

```bash
/usr/bin/cmscan https://target.example
```

Route the workflow through the configured Tor service:

```bash
/usr/bin/cmsscan --tor --scanner wpscan https://target.example:443
```

Run every example only against a target explicitly included in the written
rules of engagement.

## Scanner selection

Accepted scanner names are:

```text
all
wpscan, cmsmap, cmseek, droopescan, joomscan, drupwn, vbscan
vulnx, wpseku, wpforce, wpxf, joomlavs, fingerprinter
autowpscan, aem-hacker, aem-discoverer, cmsscan
```

If `--scanner` is omitted, the runner attempts the complete applicable set.
`--tool` and `--only` are compatibility spellings for `--scanner`; they accept
the same single normalized selector. Public `--only` here selects a CMS scanner,
while the workspace installer's `--only` selects an installation project.
CMS-specific stages that do not match the detected platform are recorded as
not applicable. Because some stages can enumerate users, test credentials, or
make a large number of requests, prefer an explicit selection when the
authorization does not cover the full workflow.

## Target resolution

An explicit scheme or port is part of the requested scope and is retained.
Only a target that omits both is probed:

| Input | Resolution |
| --- | --- |
| `target.example` | Probe 443, then 80 |
| `target.example:8080` | Keep port; derive HTTP |
| `target.example:8443` | Keep port; derive HTTPS |
| `http://target.example` | Keep scheme; derive port 80 |
| `https://target.example:8443/path` | Keep scheme, port, and path |

In normal mode the worker uses Nmap for the limited 443/80 probe. In Tor mode
it uses proxied HTTPS/HTTP reachability checks because raw Nmap traffic cannot
travel through a SOCKS proxy. Supply the full authorized URL when outbound
probing is unavailable or would exceed scope.

## Tor behavior

`--tor` expects Tor SOCKS on `127.0.0.1:9050`. The worker validates the proxy,
routes initial HTTP detection and scanner processes through it, and uses remote
DNS resolution where supported. It exits before scanner stages if the proxy
check fails. Starting or installing the system Tor service is an administrative
operation; the scan itself still runs as `aiuser`.

## Reports and logs

The public dispatcher supplies an `aiuser`-owned run spool. The CMS worker
writes its consolidated report, per-tool logs, and progress pair within that
assigned boundary. A validated report-output argument may select a name or
directory without changing runtime identity.

Use an explicit absolute writable destination to retain the consolidated
`.cms.txt` report. That native format and the detailed child logs are outside
the standard caller-directory report-copyback list, and the dispatcher retires
its private spool after completion. Check access permissions for the intended
report readers.

The consolidated report includes:

- input and normalized target;
- detected CMS;
- target-resolution evidence;
- each applicable tool command, result, and captured output;
- explicit skip or not-applicable reasons; and
- final success, nonzero, timeout, and skipped counts.

Reports and logs may contain target URLs, discovered resources, response
metadata, and authenticated-session context. Treat them as assessment evidence,
restrict access, and apply the engagement retention policy.

## Runtime progress contract

`cmsscan` and `cmscan` publish one mode-`0600` pair per run:
`.cmsscan.<aiuser-uid>.<UTC timestamp>.progress` and `.log`. The progress file
contains one atomically replaced monotonic scalar, while terminal output uses
the exact 32-cell form
`Progress: [################----------------]  50.0%`.

The denominator is built from selected scanner activities. A single named
scanner contributes one selection; `all` includes each scanner family; and
Droopescan includes its supported CMS modes. Successful, skipped, and
not-applicable activities all complete their allotted share. Values 96–99 are
reserved for consolidated-report assembly, and 100 is published only after a
non-empty final report and summary have been verified.

Before returning, the runner closes and joins its log writer so the canonical
log and historical `run.log` finish flushing. A logger failure produces a
nonzero command status; inspect that status as well as report counters.

`--progress-file` and `--log-file` may override the assigned pair after
dispatcher validation. `--quiet` and managed-progress mode suppress progress
stdout only; the files continue to update. The universal CMS worker is the
single owner of its upstream child-tool progress. When nested in Webscan, it
remains part of that parent activity and is not registered again as a separate
top-level VAPTScan activity. See
[`../../RUNTIME_PROGRESS.md`](../../RUNTIME_PROGRESS.md) for the workspace
aggregation contract.

## Update and compatibility policy

The installer stages maintained compatibility copies of Python 2-era or
otherwise incompatible upstream tools beneath the protected installed runtime.
It validates candidates before activation and retains the prior working runtime
when a staged replacement fails. Existing source checkouts and upstream
documents are not public runtime interfaces.

Normal installer reruns update or validate managed snapshots, reconcile Python
requirements as `aiuser`, refresh bounded scanner data, republish the encrypted
bundle, and smoke-test entrypoints. `--no-update` reuses installed snapshots
where possible; `--full-data-refresh` opts into slower supported data refreshes.
Each active scanner database refresh prints its name, elapsed-time updates
every 15 seconds, and its final command status while native output is captured.
These refresh flags belong to the CMS component installer. They are not public
scan flags and must not be forwarded to unrelated WA components. Consult
`bash installer.sh --help` from the VAPT root for workspace-level options, or
`bash WA-SCAN/cms_scanner/installer.sh --help` for the component policy.

Known upstream anomalies may be classified as `SKIP` in the consolidated
report, including unavailable CMSmap bootstrap data, unsupported WPXF scripted
workflow, Fingerprinter error output despite a zero exit code, or AutoWPScan
`scan_aborted`. Other child failures and timeouts remain visible in the report;
a shell status alone is not proof that every upstream scanner succeeded.

## Offline verification

The workspace installer owns test dependencies. Run maintained offline checks
as the fixed account from the VAPT workspace root:

```bash
sudo -H -u aiuser /home/aiuser/.local/share/vantage/cms_scanner/venv/bin/python WA-SCAN/cms_scanner/tests/test_patch_vulnx_detector.py
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_progress_contract.sh
sudo -H -u aiuser bash WA-SCAN/cms_scanner/tests/test_target_scheme_port_contract.sh
```

These tests use fixtures or mocks and do not authorize or initiate a live scan.

## Documentation map

- [`bin/`](bin/README.md): private compatibility launchers
- [`scripts/`](scripts/README.md): private wrapper and support code
- [`logs/`](logs/README.md): operational evidence handling
- [`reports/`](reports/README.md): consolidated report format
- [`tests/`](tests/README.md): offline verification
- `tools/`: bundled third-party open-source tools, possibly modified, with their
  upstream licences; [`tools/THIRD_PARTY.md`](tools/THIRD_PARTY.md) lists each one's
  origin, licence and changes. Commands in upstream READMEs describe those projects,
  not the supported VANTAGE runtime

## Legal notice

Use this software only on systems you own or where explicit authorization has
been granted. This repository grants no permission to test any target.

Copyright (c) 2026-2036 Andrea Bodei - info at andreabodei.com

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
