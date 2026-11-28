# Third-party open-source tools (possibly modified)

The folders under `tools/` are **open-source tools written by other authors**, bundled here so the
scanner runs them from one place. They are **not the work of this project**, and the copies here
**may be modified versions** of the originals. Use the upstream project for the unmodified tool.

- Each tool keeps its own licence: the licence file in its folder is the upstream text, unchanged.
  The copyright of the original code belongs to the authors named there and upstream.
- Modifications made for this project, where present, are mostly a copyright comment added at the top
  of a file, plus small integration changes (Python environment paths, update commands, README
  sections, a few code fixes). A copyright comment added by this project covers **only those
  modifications**; it does not claim authorship of the upstream code, and the upstream licence
  still governs each file.
- The "Files differing" column counts the files of this copy that differ from the upstream commit
  listed; "Beyond comments" counts those whose change is more than an added comment or blank line.
- No warranty: see each licence. Like the rest of this repository, these tools may be used only
  against targets you are explicitly authorised to test.

| Tool | Upstream | Base commit (date) | Licence | Files differing | Beyond comments |
|---|---|---|---|---|---|
| `AutoWPScan` | [github.com/password123456/autowpscan](https://github.com/password123456/autowpscan) | `30dec37b53aa` (2023-09-06) | Apache-2.0 (`AutoWPScan/LICENSE`) | 2 | 2 |
| `CMSScan` | [github.com/ajinabraham/CMSScan](https://github.com/ajinabraham/CMSScan) | `f060b4b5c5f4` (2021-05-17) | GPL-3.0 (`CMSScan/LICENSE`) | 32 | 6 |
| `CMSeeK` | [github.com/Tuhinshubhra/CMSeeK](https://github.com/Tuhinshubhra/CMSeeK) | `20f9780d2e68` (2023-07-03) | GPL-3.0 (`CMSeeK/LICENSE`) | 114 | 4 |
| `CMSmap` | [github.com/Dionach/CMSmap](https://github.com/Dionach/CMSmap) | `59dd0e2b3b0c` (2018-10-26) | GPL-3.0 (`CMSmap/LICENSE.txt`) | 26 | 1 |
| `WPForce` | [github.com/n00py/WPForce](https://github.com/n00py/WPForce) | `b72ec640e6e2` (2021-02-16) | BSD-2-Clause (`WPForce/LICENSE`) | 4 | 1 |
| `WPSeku` | [github.com/andripwn/WPSeku](https://github.com/andripwn/WPSeku) | `9a0f400547a1` (2019-07-15) | GPL-3.0 (`WPSeku/LICENSE`) | 36 | 1 |
| `aem-hacker` | [github.com/0ang3el/aem-hacker](https://github.com/0ang3el/aem-hacker) | `3ce91f217b25` (2021-11-21) | MIT (`aem-hacker/LICENSE.txt`) | 7 | 2 |
| `clusterd` | [github.com/hatRiot/clusterd](https://github.com/hatRiot/clusterd) | `d190b2cbaa93` (2015-11-18) | MIT (`clusterd/LICENSE`) | 204 | 5 |
| `drupwn` | [github.com/immunIT/drupwn](https://github.com/immunIT/drupwn) | `818673219d50` (2020-06-18) | GPL-3.0 (`drupwn/LICENSE`) | 36 | 2 |
| `fingerprinter` | [github.com/erwanlr/Fingerprinter](https://github.com/erwanlr/Fingerprinter) | `e0078b45edd6` (2025-09-17) | CC-BY-NC-4.0 (`fingerprinter/LICENSE`) | 54 + 2 added | 6 |
| `joomlavs` | [github.com/rastating/joomlavs](https://github.com/rastating/joomlavs) | `eea7500e6047` (2018-07-06) | GPL-3.0 (`joomlavs/LICENSE`) | 27 | 1 |
| `joomscan` | [github.com/OWASP/joomscan](https://github.com/OWASP/joomscan) | `2ea8cc7792b3` (2023-11-30) | GPL-3.0 (`joomscan/LICENSE.md`) | 26 | 1 |
| `vbscan` | [github.com/OWASP/vbscan](https://github.com/OWASP/vbscan) | `2b1ce48c11b2` (2019-06-16) | GPL-3.0 (`vbscan/LICENCE.md`) | 38 | 1 |
| `vulnx` | [github.com/anouarbensaad/vulnx](https://github.com/anouarbensaad/vulnx) | `bcf451d20941` (2022-06-10) | GPL-3.0 (`vulnx/LICENSE`) | 51 | 6 |

## Files changed beyond comments

For a review of what differs from upstream, these are the files whose change is more than an
added comment or blank line:

- `AutoWPScan`: `main.py`, `README.md`
- `CMSScan`: `Dockerfile`, `plugins/joomscan`, `plugins/vbscan`, `README.md`, `run.sh`, `setup.sh`
- `CMSeeK`: `cmseekdb/basic.py`, `cmseek.py`, `Dockerfile`, `README.md`
- `CMSmap`: `README.md`
- `WPForce`: `README.md`
- `WPSeku`: `README.md`
- `aem-hacker`: `Dockerfile`, `README.md`
- `clusterd`: `README.md`, `src/lib/coldfusion/fuze.cfml`, `src/lib/coldfusion/README.md`, `src/lib/railo/README.md`, `src/lib/resources/README.md`
- `drupwn`: `Dockerfile`, `README.md`
- `fingerprinter`: `db/chamilo_lms.json`, `Gemfile`, `lib/fingerprinter/actions.rb`, `lib/ignore_pattern/php.rb`, `lib/ignore_pattern/python.rb`, `README.md`; added: `lib/ignore_pattern/php.rb`, `lib/ignore_pattern/python.rb`
- `joomlavs`: `README.md`
- `joomscan`: `README.md`
- `vbscan`: `README.md`
- `vulnx`: `docker/debian_stretch/Dockerfile`, `docker/Dockerfile`, `install.sh`, `modules/detector.py`, `README.md`, `.travis.yml`

## Licence notes

- **Fingerprinter** is licensed CC BY-NC 4.0: it may be shared and adapted with attribution, for
  **non-commercial purposes only**. Any commercial use of this repository must leave it out or
  obtain permission from its author.
- GPL-3.0 tools: this copy, with its modifications, is distributed under GPL-3.0; the source is
  this folder.
