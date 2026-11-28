<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
<p align='center'>
  <img src="https://i.imgur.com/5VYs1m2.png" alt="Logo"> <br>
  <a href="https://github.com/Tuhinshubhra/CMSeeK/releases/tag/v.1.1.3"><img src="https://img.shields.io/badge/Version-1.1.3-brightgreen.svg?style=style=flat-square" alt="version"></a>
  <a href="https://github.com/Tuhinshubhra/CMSeeK/"><img src="https://img.shields.io/badge/python-3-orange.svg?style=style=flat-square" alt="Python Version"></a>
  <a href="https://github.com/Tuhinshubhra/CMSeeK/stargazers"><img src="https://img.shields.io/github/stars/Tuhinshubhra/CMSeeK.svg" alt="GitHub stars" /></a>
  <a href="https://github.com/Tuhinshubhra/CMSeeK/blob/master/LICENSE"><img src="https://img.shields.io/github/license/Tuhinshubhra/CMSeeK.svg" alt="GitHub license" /></a>
  <a href="https://twitter.com/r3dhax0r"><img src="https://img.shields.io/twitter/url/https/github.com/Tuhinshubhra/CMSeeK.svg?style=social" alt="Twitter" /></a>
</p>

## Summary

CMSeeK is the vendored CMS detection and assessment tool for identifying many
CMS families and running deeper WordPress, Joomla, Drupal, and related checks.

## Topics

- [What is a CMS?](#what-is-a-cms)
- [Release history](#release-history)
- [Functions of CMSeeK](#functions-of-cmseek)
- [Requirements and compatibility](#requirements-and-compatibility)
- [Installation and usage](#installation-and-usage)
- [Checking for updates](#checking-for-update)
- [Detection methods](#detection-methods)
- [Supported CMSs](#supported-cmss)
- [Scan result](#scan-result)
- [Bruteforce modules](#bruteforce-modules)
- [More reasons to use CMSeeK](#need-more-reasons-to-use-cmseek)
- [Screenshots](#screenshots)
- [Issue guidelines](#guidelines-for-opening-an-issue)
- [Disclaimer](#disclaimer)
- [License](#license)
- [Follow the upstream author](#follow-me-r3dhax0r)
- [VANTAGE Python environment standard](#vantage-python-environment-standard)

## What is a CMS?
> A content management system (CMS) manages the creation and modification of digital content. It typically supports multiple users in a collaborative environment. Some noteable examples are: *WordPress, Joomla, Drupal etc*.

## Release History
```
- Version 1.1.3 [25-07-2020]
- Version 1.1.2 [19-05-2019]
- Version 1.1.1 [01-02-2019]
- Version 1.1.0 [28-08-2018]
- Version 1.0.9 [21-08-2018]
- Version 1.0.8 [14-08-2018]
- Version 1.0.7 [07-08-2018]
...
```
[Changelog File](https://github.com/Tuhinshubhra/CMSeeK/blob/master/CHANGELOG)

## Functions Of CMSeek:

- Basic CMS Detection of over 180 CMS
- Drupal version detection
- Advanced Wordpress Scans
  - Detects Version
  - User Enumeration
  - Plugins Enumeration
  - Theme Enumeration
  - Detects Users (3 Detection Methods)
  - Looks for Version Vulnerabilities and much more!
- Advanced Joomla Scans
  - Version detection
  - Backup files finder
  - Admin page finder
  - Core vulnerability detection
  - Directory listing check
  - Config leak detection
  - Various other checks
- Modular bruteforce system
  - Use pre made bruteforce modules or create your own and integrate with it

## Requirements and Compatibility:

CMSeeK is built using **python3**, you will need python3 to run this tool and is compitable with **unix based systems** as of now. Windows support will be added later. CMSeeK relies on **git** for auto-update so make sure git is installed.

## Installation and Usage:

It is fairly easy to use CMSeeK. Use the shared per-user Python environment at `$HOME/.venv` and make sure git is installed, then use the following commands:

- git clone `https://github.com/Tuhinshubhra/CMSeeK`
- cd CMSeeK
- $HOME/.venv/bin/python -m pip install -r requirements.txt

For guided scanning:

- $HOME/.venv/bin/python cmseek.py

Else:

- $HOME/.venv/bin/python cmseek.py -u <target_url> [...]

Help menu from the program:

```
USAGE:
       $HOME/.venv/bin/python cmseek.py (for guided scanning) OR
       $HOME/.venv/bin/python cmseek.py [OPTIONS] <Target Specification>

SPECIFING TARGET:
      -u URL, --url URL            Target Url
      -l LIST, --list LIST         Path of the file containing list of sites
                                   for multi-site scan (comma separated or one-per-line)

MANIPULATING SCAN:
      -i cms, --ignore--cms cms    Specify which CMS IDs to skip in order to
                                   avoid flase positive. separated by comma ","

      --strict-cms cms             Checks target against a list of provided
                                   CMS IDs. separated by comma ","

      --skip-scanned               Skips target if it's CMS was previously detected.

RE-DIRECT:
      --follow-redirect            Follows all/any redirect(s)
      --no-redirect                Skips all redirects and tests the input target(s)

USER AGENT:
      -r, --random-agent           Use a random user agent
      --googlebot                  Use Google bot user agent
      --user-agent USER_AGENT      Specify a custom user agent

OUTPUT:
      -v, --verbose                Increase output verbosity

VERSION & UPDATING:
      --update                     Update CMSeeK (Requires git)
      --version                    Show CMSeeK version and exit

HELP & MISCELLANEOUS:
      -h, --help                   Show this help message and exit
      --clear-result               Delete all the scan result
      --batch                      Never ask you to press enter after every site in a list is scanned

EXAMPLE USAGE:
      $HOME/.venv/bin/python cmseek.py -u example.com                           # Scan example.com
      $HOME/.venv/bin/python cmseek.py -l /home/user/target.txt                 # Scan the sites specified in target.txt (comma separated)
      $HOME/.venv/bin/python cmseek.py -u example.com --user-agent Mozilla 5.0  # Scan example.com using custom user-Agent Mozilla is 5.0 used here
      $HOME/.venv/bin/python cmseek.py -u example.com --random-agent            # Scan example.com using a random user-Agent
      $HOME/.venv/bin/python cmseek.py -v -u example.com                        # enabling verbose output while scanning example.com

```

## Checking For Update:

You can check for update either from the main menu or use `$HOME/.venv/bin/python cmseek.py --update` to check for update and apply auto update.

P.S: Please make sure you have `git` installed, CMSeeK uses git to apply auto update.

## Detection Methods:

CMSeek detects CMS via the following:
- HTTP Headers
- Generator meta tag
- Page source code
- robots.txt
- Directory check

## Supported CMSs:

CMSeeK currently can detect **170+** CMS. Check the list here: [cmss.py](https://github.com/Tuhinshubhra/CMSeeK/blob/master/cmseekdb/cmss.py) file which is present in the `cmseekdb` directory.
All the cmss are stored in the following way:
```
 cmsID = {
   'name':'Name Of CMS',
   'url':'Official URL of the CMS',
   'vd':'Version Detection (0 for no, 1 for yes)',
   'deeps':'Deep Scan (0 for no 1 for yes)'
 }
```

## Scan Result:

All of your scan results are stored in a json file named `cms.json`, you can find the logs inside the `Result\<Target Site>` directory, and as of the bruteforce results they're stored in a txt file under the site's result directory as well.

Here is an example of the json report log:

![Json Log](https://i.imgur.com/5dA9jQg.png)

## Bruteforce Modules:

CMSeek has a modular bruteforce system meaning you can add your custom made bruteforce modules to work with cmseek. A proper documentation for creating modules will be created shortly but in case you already figured out how to (pretty easy once you analyze the pre-made modules) all you need to do is this:

1. Add a comment exactly like this `# <Name Of The CMS> Bruteforce module`. This will help CMSeeK to know the name of the CMS using regex

2. Add another comment `### cmseekbruteforcemodule`, this will help CMSeeK to know it is a module

3. Copy and paste the module in the `brutecms` directory under CMSeeK's directory

4. Open CMSeeK and Rebuild Cache using `R` as the input in the first menu.

5. If everything is done right you'll see something like this (refer to screenshot below) and your module will be listed in bruteforce menu the next time you open CMSeeK.

<p align='center'>
  <img alt="Cache Rebuild Screenshot" width="600px" src="https://i.imgur.com/yhdzTYr.png" />
</p>

## Need More Reasons To Use CMSeeK?

If not anything you can always enjoy exiting CMSeeK *(please don't)*, it will bid you goodbye in a random goodbye message in various languages.

Also you can try reading comments in the code those are pretty random and weird!!!

## Screenshots:

<p align="center">
  <img alt="Main Menu" src="https://i.imgur.com/Eij6QvX.png" />
  <br><em>Main Menu</em><br>
  <img alt="Scan Result" src="https://i.imgur.com/u0iyLdB.png" />
  <br><em>Scan Result</em><br>
  <img alt="WordPress Scan Result" src="https://i.imgur.com/cOtCJLj.png" />
  <br><em>WordPress Scan Result</em><br>
</p>

## Guidelines for opening an issue:

Please make sure you have the following info attached when opening a new issue:
- Target
- Exact copy of error or screenshot of error
- Your operating system and python version

**Issues without these informations might not be answered!**

## Disclaimer:

**Usage of CMSeeK for testing or exploiting websites without prior mutual consistency can be considered as an illegal activity. It is the final user's responsibility to obey all applicable local, state and federal laws. Authors assume no liability and are not responsible for any misuse or damage caused by this program.**

## License:

CMSeeK is licensed under [GNU General Public License v3.0](https://github.com/Tuhinshubhra/CMSeeK/blob/master/LICENSE)

## Follow Me @r3dhax0r:

[Twitter](https://twitter.com/r3dhax0r)   

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
