<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
# CMSScan
Scan WordPress, Drupal, Joomla, vBulletin websites for Security issues.

[![platform](https://img.shields.io/badge/platform-osx%2Flinux-green.svg)](https://github.com/ajinabraham/CMSScan/)
[![License](https://img.shields.io/:license-gpl3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.html)
[![python](https://img.shields.io/badge/python-3.6-blue.svg)](https://www.python.org/downloads/)
[![Rawsec's CyberSecurity Inventory](https://inventory.raw.pm/img/badges/Rawsec-inventoried-FF5050_flat.svg)](https://inventory.rawsec.ml/tools.html#CMSScan)

Made with ![Love](https://cloud.githubusercontent.com/assets/4301109/16754758/82e3a63c-4813-11e6-9430-6015d98aeaab.png) in India

CMSScan provides a centralized Security Dashboard for CMS Security scans. It is powered by wpscan, droopescan, vbscan and joomscan. It supports both on demand and scheduled scans and has the ability to sent email reports.

## Summary

CMSScan is the upstream dashboard that coordinates WordPress, Drupal, Joomla,
and vBulletin security scanners for on-demand or scheduled assessments and
report delivery.

## Topics

- [Install](#install)
- [Run](#run)
- [Periodic scans](#periodic-scans)
- [Basic authentication](#basic-auth)
- [Docker](#docker)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

## Install
```
# Requires ruby, ruby-dev, gem, libwww-perl, python3.6+ and git
git clone https://github.com/ajinabraham/CMSScan.git
cd CMSScan
./setup.sh
```
## Run

`./run.sh`

## Periodic Scans

You can perform periodic CMS scans with CMSScan. You must run CMSScan server separately and configure the following before running the `scheduler.py` script.

```
# SMTP SETTINGS
SMTP_SERVER = ''
FROM_EMAIL = ''
TO_EMAIL = ''

# SERVER SETTINGS
SERVER = ''

# SCAN SITES
WORDPRESS_SITES = []
DRUPAL_SITES = []
JOOMLA_SITES = []
VBULLETIN_SITES = []
```

Add a cronjob

```
crontab -e
@weekly $HOME/.venv/bin/python scheduler.py
```

## Basic Auth

By default there is no authentication. To enable basic auth, configure the following in `app.py` 

```
app.config['BASIC_AUTH_USERNAME'] = 'admin'
app.config['BASIC_AUTH_PASSWORD'] = 'password'
app.config['BASIC_AUTH_FORCE'] = True
```

## Docker

### Local
```
docker build -t cmsscan .
docker run -it -p 7070:7070 cmsscan
```

### Prebuilt Image

```
docker pull opensecurity/cmsscan
docker run -it -p 7070:7070 opensecurity/cmsscan
```

### Screenshots


![](https://user-images.githubusercontent.com/4301109/48620839-855c9100-e9c7-11e8-97c6-1e25252d2d01.png)
![](https://user-images.githubusercontent.com/4301109/48620970-03b93300-e9c8-11e8-9962-714e8fea2c6c.png)
![](https://user-images.githubusercontent.com/4301109/48670210-cf658400-eb39-11e8-8aad-fa2c2915c42a.png)

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
