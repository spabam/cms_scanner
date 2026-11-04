<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
coldfusion
=========

fuze.cfml - Fuze CF shell version 1.2; full featured backdoor (default creds: god|default)

<!-- VANTAGE-PYTHON-ENV-STANDARD:START -->
## VANTAGE Python environment standard

Every managed host-side VANTAGE Python command uses the fixed passwd account
`aiuser` and its single shared environment at `/home/aiuser/.venv`. It never
uses the caller or root account's `HOME`, an activated environment, a project-local
environment, bare `pip` or `pip3`, or `pip --user`.

From any account, use the workspace dispatcher; it resolves `aiuser` through the
passwd database, constructs `<aiuser-home>/.venv`, and switches identity before
creating the environment, installing a package, or running Python:

```text
/home/spabam/Dropbox/Public/VANTAGE/VAPT/python-env.sh ensure
/home/spabam/Dropbox/Public/VANTAGE/VAPT/python-env.sh install path/to/requirements.txt
/home/spabam/Dropbox/Public/VANTAGE/VAPT/python-env.sh python path/to/script.py
/home/spabam/Dropbox/Public/VANTAGE/VAPT/python-env.sh pip check
```

Pip is always interpreter-bound (`/home/aiuser/.venv/bin/python -m pip`). Managed
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
