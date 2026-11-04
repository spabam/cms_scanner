<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
# autowpscan
![made-with-python][made-with-python]
![Python Versions][pyversion-button]

[pyversion-button]: https://img.shields.io/pypi/pyversions/Markdown.svg
[made-with-python]: https://img.shields.io/badge/Made%20with-Python-1f425f.svg


An automated tool that automatically scanning a list of multiple websites with wordpress at once. and send scan summary to telegram with wpscan logs.

Requires wpscan, Telegram BOT Token, WordPress Vulnerability Database API token


## Introduction
This tool takes a list of multiple websites created with wordpress, lists them according to a predefined format, and uses wpscan to perform the scanning.

Nothing special, Just simple a list of multiple websites scanner with wpscan. If you're good with code, I'm sure you can implement more sophisticated automation (e.g. Telegram bots, automatic checks on deployment via the Asset Information Report API, etc), or if you're thinking about your own DAST, this can help you with the initial development design. 

If you want to extend it further, you could create an administrative web UI and create self-service checks on the web UI, so that you can perform checks on demand.

## Requirements
- Wpscan must be installed on your system.
- WordPress Vulnerability Database API token (you can get it from [here](https://wpscan.com/api))
- One or more websites developed with wordpress. 
- Telegram BOT Token

## How to write list file?
- it's very simple.
- url, name, telegram_chat-room_id
- If you change the Telegram chat ID in the third field, you can send the result to a different Telegram chat ID.
```
ex) list.txt
https://wordpress_site.com,WordPress Site.com,12345678910
https://not_wordpress_site.com,Not Wordpress Site.com,0938342323
https://no_exist_domain.com,no_exist_domain,-34382473434
```

## Features
- Multiprocessing to scan multiple websites at the same time.
- Send a summary of the scan results, logfile (in this tool, result will send to telegram, so you have to get a chat room)

## Preview
```

 .d8b.  db    db d888888b  .d88b.  db   d8b   db d8888b. .d8888.  .o88b.  .d8b.  d8b   db 
d8' `8b 88    88 `~~88~~' .8P  Y8. 88   I8I   88 88  `8D 88'  YP d8P  Y8 d8' `8b 888o  88 
88ooo88 88    88    88    88    88 88   I8I   88 88oodD' `8bo.   8P      88ooo88 88V8o 88 
88~~~88 88    88    88    88    88 Y8   I8I   88 88~~~     `Y8b. 8b      88~~~88 88 V8o88 
88   88 88b  d88    88    `8b  d8' `8b d8'8b d8' 88      db   8D Y8b  d8 88   88 88  V888 
YP   YP ~Y8888P'    YP     `Y88P'   `8b8' `8d8'  88      `8888Y'  `Y88P' YP   YP VP   V8P 

Autowpscan 1.0.0
- WordPress scanner that automatically scans a list of domains > analyze > send the results.
- Run time: 2023-04-14 15:46:47
- For questions contact github.com/password123456		


------------------------------------->
- Scan List  : /Users/data/code/autowpscan/list.txt
- Scan Count : 4
- O.K Here We go.!
[00:00:28.474618] (1 scanned) (vulnerabilities: 26) https://wordpress_site.com (wordpress: 5.8)
[00:00:32.803166] (2 scanned) (vulnerabilities: 0) https://not_wordpress_site.com (wordpress: scan_aborted. wrong url or something scan failed.)
[00:00:40.279409] (4 scanned) (vulnerabilities: 0) https://no_exist_domain.com (wordpress: scan_aborted. wrong url or something scan failed.)
 Scan Completed.! 


[RESULT]
1.(WordPress Site.com) https://wordpress_site.com
 - /Users/data/code/autowpscan/20230414_394107f92ae4_wordpress_site.com_wpscan_result.json
"""
1) WordPress 5.4 to 5.8 - Data Exposure via REST API (fixed: 5.8.1)
2) WordPress 5.4 to 5.8 - Authenticated XSS in Block Editor (fixed: 5.8.1)
3) WordPress 5.4 to 5.8 -  Lodash Library Update (fixed: 5.8.1)
4) WordPress < 5.8.2 - Expired DST Root CA X3 Certificate (fixed: 5.8.2)
5) WordPress < 5.8.3 - SQL Injection via WP_Query (fixed: 5.8.3)
6) WordPress < 5.8.3 - Author+ Stored XSS via Post Slugs (fixed: 5.8.3)
7) WordPress 4.1-5.8.2 - SQL Injection via WP_Meta_Query (fixed: 5.8.3)
"""

2.(Not Wordpress Site.com) https://not_wordpress_site.com
 - /Users/data/code/autowpscan/20230414_d58bd67af8c4_not_wordpress_site.com_wpscan_result.json
3.(no_exist_domain) https://no_exist_domain.com
 - /Users/data/code/autowpscan/20230414_fda2354453a6_no_exist_domain.com_wpscan_result.json
```

## And...
- Please let me know if any changes are required or if additional features are needed.
- If you find this helpful, please consider giving it a "star"🌟 to support further improvements.

## Limitations
It's important to note that this tool is not a replacement for manual testing, and it may not detect all vulnerabilities present in web applications. The tool should be used as a supplement to manual testing, and the results should be verified by a human tester before any action is taken. Additionally, the tool may produce false positives or false negatives, which should be considered when interpreting the results.

Overall, this tool can be a valuable addition to your web vulnerability testing process, helping you to identify and mitigate potential security risks in a large number of web applications.

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
