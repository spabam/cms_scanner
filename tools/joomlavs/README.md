<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
# joomlavs [![Build Status](https://travis-ci.org/rastating/joomlavs.svg?branch=master)](https://travis-ci.org/rastating/joomlavs) [![Coverage Status](https://coveralls.io/repos/github/rastating/joomlavs/badge.svg?branch=development)](https://coveralls.io/github/rastating/joomlavs?branch=development) [![Code Climate](https://codeclimate.com/github/rastating/joomlavs/badges/gpa.svg)](https://codeclimate.com/github/rastating/joomlavs)
A black box, Ruby powered, Joomla vulnerability scanner

## Summary

JoomlaVS is the vendored Ruby black-box scanner for fingerprinting Joomla
installations and identifying vulnerable core, component, module, and template
versions.

## Topics

- [What is it?](#what-is-it)
- [How to install](#how-to-install)
- [Installation troubleshooting](#troubleshooting-installation)
- [How to use](#how-to-use)
- [License](#license)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

## What is it?
JoomlaVS is a Ruby application that can help automate assessing how vulnerable a Joomla installation is to exploitation. It supports basic finger printing and can scan for vulnerabilities in components, modules and templates as well as vulnerabilities that exist within Joomla itself.

## How to install
JoomlaVS has so far only been tested on Debian, but the installation process should be similar across most operating systems.

1. Ensure Ruby [2.4.4 or above] is installed on your system
2. Clone the source code using ```git clone https://github.com/rastating/joomlavs.git```
3. Install bundler and required gems using ```gem install bundler && bundle install```

## Troubleshooting Installation
If you have issues installing JoomlaVS' dependencies (in particular, Nokogiri), first make sure you have all the tooling necessary to compile C extensions:

```
sudo apt-get install build-essential patch
```

It’s possible that you don’t have important development header files installed on your system. Here’s what you should do if you should find yourself in this situation:

```
sudo apt-get install ruby-dev zlib1g-dev liblzma-dev libcurl4-openssl-dev
```

## How to use
The only required option is the ```-u``` / ```--url``` option, which specifies the address to target. To do a full scan, however, the ```--scan-all``` option should also be specified, e.g. ```ruby joomlavs.rb -u yourjoomlatarget.com --scan-all```.

A full list of options can be found below:

```
usage: joomlavs.rb [options]
Basic options
    -u, --url              The Joomla URL/domain to scan.
    --basic-auth           <username:password> The basic HTTP authentication credentials
    -v, --verbose          Enable verbose mode
Enumeration options
    -a, --scan-all         Scan for all vulnerable extensions
    -c, --scan-components  Scan for vulnerable components
    -m, --scan-modules     Scan for vulnerable modules
    -t, --scan-templates   Scan for vulnerable templates
    -q, --quiet            Scan using only passive methods
Advanced options
    --disable-tls-checks   Disable SSL/TLS certificate verification.
    --follow-redirection   Automatically follow redirections
    --no-colour            Disable colours in output
    --proxy                <[protocol://]host:port> HTTP, SOCKS4 SOCKS4A and SOCKS5 are supported. If no protocol is given, HTTP will be used
    --proxy-auth           <username:password> The proxy authentication credentials
    --threads              The number of threads to use when multi-threading requests
    --user-agent           The user agent string to send with all requests
```

## License
Copyright (C) 2015-2018 rastating

Running JoomlaVS against websites without prior mutual consent may be illegal in your country. The author and parties involved in its development accept no liability and are not responsible for any misuse or damage caused by JoomlaVS.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
