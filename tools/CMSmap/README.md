<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
CMSmap
======

CMSmap is a python open source CMS scanner that automates the process of detecting security flaws of the most popular CMSs. The main purpose of CMSmap is to integrate common vulnerabilities for different types of CMSs in a single tool.

At the moment, CMSs supported by CMSmap are WordPress, Joomla, Drupal and Moodle.

Please note that this project is an early state. As such, you might find bugs, flaws or mulfunctions.
Use it at your own risk!


## Summary

CMSmap is the vendored Python CMS scanner for detecting and assessing common
WordPress, Joomla, Drupal, and Moodle security issues.

## Topics

- [Preview](#preview)
- [Installation](#installation)
- [Usage](#usage)
- [Contribution guidelines](#contribution-guidelines)
- [Disclaimer](#disclaimer)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

Preview
=====
* https://asciinema.org/a/MELa2nUcrtATqnDLnc0ig8rcT


Installation
=====
You can download the latest version of CMSmap by cloning the GitHub repository:

     git clone https://github.com/Dionach/CMSmap

Then you need to configure the `edbtype` and `edbpath` settings in the `cmsmap.conf`. Use `GIT` if you have a local Git repository of Exploit-db :

    [exploitdb]
    edbtype = GIT
    edbpath = /opt/exploitdb/

Alternatively, use `APT` if you have installed the `debian` exploitdb package. For Kali, use the following settings :

    [exploitdb]
    edbtype = APT
    edbpath = /usr/share/exploitdb/

If you would like to run `cmsmap` from anywhere in your system, install it in the shared per-user environment:

    cd CMSmap
    $HOME/.venv/bin/python -m pip install .

To uninstall it :

    $HOME/.venv/bin/python -m pip uninstall cmsmap -y


Usage
=====
    usage: cmsmap [-f W/J/D] [-F] [-t] [-a] [-H] [-i] [-o] [-E] [-d] [-u] [-p]
                  [-x] [-k] [-w] [-v] [-h] [-D] [-U W/J/D]
                  [target]
    
    CMSmap tool v1.0 - Simple CMS Scanner
    Author: Mike Manzotti
    
    Scan:
      target                target URL (e.g. 'https://example.com:8080/')
      -f W/J/D, --force W/J/D
                            force scan (W)ordpress, (J)oomla or (D)rupal
      -F, --fullscan        full scan using large plugin lists. False positives and slow!
      -t , --threads        number of threads (Default 5)
      -a , --agent          set custom user-agent
      -H , --header         add custom header (e.g. 'Authorization: Basic ABCD...')
      -i , --input          scan multiple targets listed in a given file
      -o , --output         save output in a file
      -E, --noedb           enumerate plugins without searching exploits
      -c, --nocleanurls     disable clean urls for Drupal only
      -s, --nosslcheck      don't validate the server's certificate
      -d, --dictattack      run low intense dictionary attack during scanning (5 attempts per user)
    
    Brute-Force:
      -u , --usr            username or username file
      -p , --psw            password or password file
      -x, --noxmlrpc        brute forcing WordPress without XML-RPC
    
    Post Exploitation:
      -k , --crack          password hashes file (Require hashcat installed. For WordPress and Joomla only)
      -w , --wordlist       wordlist file
    
    Others:
      -v, --verbose         verbose mode (Default false)
      -h, --help            show this help message and exit
      -D, --default         rum CMSmap with default options
      -U, --update          use (C)MSmap, (P)lugins or (PC) for both
    
    Examples:
      $HOME/.venv/bin/python cmsmap.py https://example.com
      $HOME/.venv/bin/python cmsmap.py https://example.com -f W -F --noedb -d
      $HOME/.venv/bin/python cmsmap.py https://example.com -i targets.txt -o output.txt
      $HOME/.venv/bin/python cmsmap.py https://example.com -u admin -p passwords.txt
      $HOME/.venv/bin/python cmsmap.py -k hashes.txt -w passwords.txt


Contribution guidelines
=====
If you want to contribute to CMSmap, be sure to review the [contribution
guidelines](.github/CONTRIBUTING.md).


Disclaimer
=====
Usage of CMSmap for attacking targets without prior mutual consent is illegal.
It is the end user's responsibility to obey all applicable local, state and federal laws.
Developers assume NO liability and are NOT responsible for any misuse or damage caused by this program.

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
