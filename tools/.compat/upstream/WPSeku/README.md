<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
 WPSeku - Wordpress Security Scanner
--
_Note: building of a new version is underway..._

WPSeku is a black box WordPress vulnerability scanner that can be used to scan remote WordPress installations to find security issues.

![python](https://img.shields.io/badge/python-3.x-green.svg) ![license](https://img.shields.io/badge/License-GPLv3-brightgreen.svg)

![screen_1](https://raw.githubusercontent.com/m4ll0k/WPSeku/master/screen/main.png)

## Installation
```
$ git clone https://github.com/m4ll0k/WPSeku.git wpseku
$ cd wpseku
$ pip3 install -r requirements.txt
$ python3 wpseku.py
```
## Usage
### Generic Scan

`python3 wpseku.py --url https://www.xxxxxxx.com --verbose`

* __Output__

```
----------------------------------------
 _ _ _ ___ ___ ___| |_ _ _ 
| | | | . |_ -| -_| '_| | |
|_____|  _|___|___|_,_|___|
      |_|             v0.4.0

WPSeku - Wordpress Security Scanner
by Momo Outaadi (m4ll0k)
----------------------------------------

[ + ] Target: https://www.xxxxxxx.com
[ + ] Starting: 02:38:51

[ + ] Server: Apache
[ + ] Uncommon header "X-Pingback" found, with contents: https://www.xxxxxxx.com/xmlrpc.php
[ i ] Checking Full Path Disclosure...
[ + ] Full Path Disclosure: /home/ehc/public_html/wp-includes/rss-functions.php
[ i ] Checking wp-config backup file...
[ + ] wp-config.php available at: https://www.xxxxxxx.com/wp-config.php
[ i ] Checking common files...
[ + ] robots.txt file was found at: https://www.xxxxxxx.com/robots.txt
[ + ] xmlrpc.php file was found at: https://www.xxxxxxx.com/xmlrpc.php
[ + ] readme.html file was found at: https://www.xxxxxxx.com/readme.html
[ i ] Checking directory listing...
[ + ] Dir "/wp-admin/css" listing enable at: https://www.xxxxxxx.com/wp-admin/css/
[ + ] Dir "/wp-admin/images" listing enable at: https://www.xxxxxxx.com/wp-admin/images/
[ + ] Dir "/wp-admin/includes" listing enable at: https://www.xxxxxxx.com/wp-admin/includes/
[ + ] Dir "/wp-admin/js" listing enable at: https://www.xxxxxxx.com/wp-admin/js/
......
```
### Bruteforce Login

`python3 wpseku.py --url https://www.xxxxxxx.com --brute --user test --wordlist wl.txt --verbose`

* __Output__

```
----------------------------------------
 _ _ _ ___ ___ ___| |_ _ _ 
| | | | . |_ -| -_| '_| | |
|_____|  _|___|___|_,_|___|
      |_|             v0.4.0

WPSeku - Wordpress Security Scanner
by Momo Outaadi (m4ll0k)
----------------------------------------

[ + ] Target: https://www.xxxxxxx.com
[ + ] Starting: 02:46:32

[ + ] Bruteforcing Login via XML-RPC...
[ i ] Setting user: test
[ + ] Valid Credentials: 

-----------------------------
| Username | Passowrd       |
-----------------------------
| test     | kamperasqen13  |
-----------------------------

```

### Scan plugin,theme and wordpress code

`python3 wpseku.py --scan <dir/file> --verbose`

__Note__: Testing Akismet Directory Plugin https://plugins.svn.wordpress.org/akismet

* __Output__

```
----------------------------------------
 _ _ _ ___ ___ ___| |_ _ _ 
| | | | . |_ -| -_| '_| | |
|_____|  _|___|___|_,_|___|
      |_|             v0.4.0

WPSeku - Wordpress Security Scanner
by Momo Outaadi (m4ll0k)
----------------------------------------

[ + ] Checking PHP code...
[ + ] Scanning directory...
[ i ] Scanning trunk/class.akismet.php file
----------------------------------------------------------------------------------------------------------
| Line | Possibile Vuln.      | String                                                                   |
----------------------------------------------------------------------------------------------------------
|  597 | Cross-Site Scripting | [b"$_GET['action']", b"$_GET['action']"]                                 |
|  601 | Cross-Site Scripting | [b"$_GET['for']", b"$_GET['for']"]                                       |
|  140 | Cross-Site Scripting | [b"$_POST['akismet_comment_nonce']", b"$_POST['akismet_comment_nonce']"] |
|  144 | Cross-Site Scripting | [b"$_POST['_ajax_nonce-replyto-comment']"]                               |
|  586 | Cross-Site Scripting | [b"$_POST['status']", b"$_POST['status']"]                               |
|  588 | Cross-Site Scripting | [b"$_POST['spam']", b"$_POST['spam']"]                                   |
|  590 | Cross-Site Scripting | [b"$_POST['unspam']", b"$_POST['unspam']"]                               |
|  592 | Cross-Site Scripting | [b"$_POST['comment_status']", b"$_POST['comment_status']"]               |
|  599 | Cross-Site Scripting | [b"$_POST['action']", b"$_POST['action']"]                               |
|  214 | Cross-Site Scripting | [b"$_SERVER['HTTP_REFERER']", b"$_SERVER['HTTP_REFERER']"]               |
|  403 | Cross-Site Scripting | [b"$_SERVER['REQUEST_TIME_FLOAT']", b"$_SERVER['REQUEST_TIME_FLOAT']"]   |
|  861 | Cross-Site Scripting | [b"$_SERVER['REMOTE_ADDR']", b"$_SERVER['REMOTE_ADDR']"]                 |
|  930 | Cross-Site Scripting | [b"$_SERVER['HTTP_USER_AGENT']", b"$_SERVER['HTTP_USER_AGENT']"]         |
|  934 | Cross-Site Scripting | [b"$_SERVER['HTTP_REFERER']", b"$_SERVER['HTTP_REFERER']"]               |
| 1349 | Cross-Site Scripting | [b"$_SERVER['REMOTE_ADDR']"]                                             |
----------------------------------------------------------------------------------------------------------
[ i ] Scanning trunk/wrapper.php file
[ + ] Not found vulnerabilities
[ i ] Scanning trunk/akismet.php file
-----------------------------------------------
| Line | Possibile Vuln.    | String          |
-----------------------------------------------
|   55 | Authorization Hole | [b'is_admin()'] |
-----------------------------------------------
[ i ] Scanning trunk/class.akismet-cli.php file
[ + ] Not found vulnerabilities
[ i ] Scanning trunk/class.akismet-widget.php file
[ + ] Not found vulnerabilities
[ i ] Scanning trunk/index.php file
[ + ] Not found vulnerabilities
[ i ] Scanning trunk/class.akismet-admin.php file
--------------------------------------------------------------------------------------------------------------------
| Line | Possibile Vuln.      | String                                                                             |
--------------------------------------------------------------------------------------------------------------------
|   39 | Cross-Site Scripting | [b"$_GET['page']", b"$_GET['page']"]                                               |
|  134 | Cross-Site Scripting | [b"$_GET['akismet_recheck']", b"$_GET['akismet_recheck']"]                         |
|  152 | Cross-Site Scripting | [b"$_GET['view']", b"$_GET['view']"]                                               |
|  190 | Cross-Site Scripting | [b"$_GET['view']", b"$_GET['view']"]                                               |
|  388 | Cross-Site Scripting | [b"$_GET['recheckqueue']"]                                                         |
|  841 | Cross-Site Scripting | [b"$_GET['view']", b"$_GET['view']"]                                               |
|  843 | Cross-Site Scripting | [b"$_GET['view']", b"$_GET['view']"]                                               |
|  850 | Cross-Site Scripting | [b"$_GET['action']"]                                                               |
|  851 | Cross-Site Scripting | [b"$_GET['action']"]                                                               |
|  852 | Cross-Site Scripting | [b"$_GET['_wpnonce']", b"$_GET['_wpnonce']"]                                       |
|  868 | Cross-Site Scripting | [b"$_GET['token']", b"$_GET['token']"]                                             |
|  869 | Cross-Site Scripting | [b"$_GET['token']"]                                                                |
|  873 | Cross-Site Scripting | [b"$_GET['action']"]                                                               |
|  874 | Cross-Site Scripting | [b"$_GET['action']"]                                                               |
| 1005 | Cross-Site Scripting | [b"$_GET['akismet_recheck_complete']"]                                             |
| 1006 | Cross-Site Scripting | [b"$_GET['recheck_count']"]                                                        |
| 1007 | Cross-Site Scripting | [b"$_GET['spam_count']"]                                                           |
|   31 | Cross-Site Scripting | [b"$_POST['action']", b"$_POST['action']"]                                         |
|  256 | Cross-Site Scripting | [b"$_POST['_wpnonce']"]                                                            |
|  260 | Cross-Site Scripting | [b'$_POST[$option]', b'$_POST[$option]']                                           |
|  267 | Cross-Site Scripting | [b"$_POST['key']"]                                                                 |
|  392 | Cross-Site Scripting | [b"$_POST['offset']", b"$_POST['offset']", b"$_POST['limit']", b"$_POST['limit']"] |
|  447 | Cross-Site Scripting | [b"$_POST['id']"]                                                                  |
|  448 | Cross-Site Scripting | [b"$_POST['id']"]                                                                  |
|  460 | Cross-Site Scripting | [b"$_POST['id']", b"$_POST['url']"]                                                |
|  461 | Cross-Site Scripting | [b"$_POST['id']"]                                                                  |
|  464 | Cross-Site Scripting | [b"$_POST['url']"]                                                                 |
|  388 | Cross-Site Scripting | [b"$_REQUEST['action']", b"$_REQUEST['action']"]                                   |
|  400 | Cross-Site Scripting | [b"$_SERVER['HTTP_REFERER']", b"$_SERVER['HTTP_REFERER']"]                         |
--------------------------------------------------------------------------------------------------------------------
[ i ] Scanning trunk/class.akismet-rest-api.php file
[ + ] Not found vulnerabilities

```

## Credits and Contributors
Original idea and script from WPScan Team (https://wpscan.org/)

WPScan Vulnerability Database (https://wpvulndb.com/api)

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
