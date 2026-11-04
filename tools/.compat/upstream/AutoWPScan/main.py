# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
__author__ = 'https://github.com/password123456/'
__date__ = '2023.03.24'
__version__ = '1.0.0'
__status__ = 'Production'


import os
import sys
import time
import json
import uuid
import hashlib
import subprocess
import requests
from datetime import datetime, timezone, timedelta
from concurrent.futures import ProcessPoolExecutor, as_completed

_home_path = f'{os.getcwd()}'
_scan_list = f'{_home_path}/list.txt'

_wpscan_api_token = '$YOUR_WordPress Vulnerability Database API$'
_telegram_bot_token = '$YOUR_telegram_bot_token$'


class Bcolors:
    Black = '\033[30m'
    Red = '\033[31m'
    Green = '\033[32m'
    Yellow = '\033[33m'
    Blue = '\033[34m'
    Magenta = '\033[35m'
    Cyan = '\033[36m'
    White = '\033[37m'
    Endc = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def create_job_id():
    random_uuid = uuid.uuid4()
    hash_object = hashlib.sha256(str(random_uuid).encode())
    short_identifier = hash_object.hexdigest()[:12]
    return short_identifier


def raw_count(filename):
    n = 0
    mode = 'r'
    with open(filename, mode, encoding='utf-8') as f:
        for line in f:
            if not line.startswith('#'):
                n = n + 1
    return n


def convert_unix_timestamp_to_kst(unixtime):
    utc_dt = datetime.utcfromtimestamp(unixtime)
    utc_dt = utc_dt.replace(tzinfo=timezone.utc)
    kst_dt = utc_dt.astimezone(timezone(timedelta(hours=9)))
    return kst_dt.strftime('%Y-%m-%d %H:%M:%S')


def do_scan():
    submitted_url_count = 0
    scan_result = ''

    scan_start_time = time.perf_counter()

    if os.path.exists(_scan_list):
        with open(_scan_list, 'rt', encoding='utf-8') as f:
            with ProcessPoolExecutor(max_workers=3) as executor:
                for line in f:
                    if not line.startswith('#'):
                        scan_url = line.split(',')[0].strip()
                        scan_name = line.split(',')[1].strip()
                        result_chat_id = line.split(',')[2].strip()
                        if scan_url and scan_name and result_chat_id:
                            try:
                                result = [executor.submit(run_wpscan, scan_url, scan_name, result_chat_id)]
                                for future in as_completed(result, timeout=600):
                                    try:
                                        result_str = future.result()
                                        scan_duration_time = time.perf_counter() - scan_start_time
                                        submitted_url_count += 1

                                        if result_str:
                                            result_info = result_str.split("|")
                                            result_scan_ret_code = f'{result_info[0]}'
                                            result_name = f'{result_info[1]}'
                                            result_url = f'{result_info[2]}'
                                            result_telegram_chat_id = f'{result_info[3]}'
                                            result_vulnerabilities_count = f'{result_info[4]}'
                                            result_wp_banner = f'{result_info[5]}'
                                            result_scan_file_name = f'{result_info[6]}'
                                            result_vulnerabilities = f'{result_info[7]}'

                                            print(f'[{datetime.strftime(datetime.utcfromtimestamp(scan_duration_time), "%H:%M:%S.%f")}] '
                                                  f'({submitted_url_count} scanned) '
                                                  f'{Bcolors.Blue}(vulnerabilities: {result_vulnerabilities_count})'
                                                  f'{Bcolors.Endc} {result_url} (wordpress: {result_wp_banner})')

                                            message = f'>>> autowpscan <<<\n* {datetime.now()} *\n\n' \
                                                      f'{submitted_url_count}. ({result_name}) {result_url}\n' \
                                                      f'- vulnerabilities: {result_vulnerabilities_count}\n' \
                                                      f'- wordpress: {result_wp_banner}\n' \
                                                      f'- {result_scan_file_name}\n'

                                            if int(result_scan_ret_code) == 1 or int(result_scan_ret_code) == 4:
                                                contents = f'{submitted_url_count}.({result_name}) ' \
                                                           f'{result_url}\n - {result_scan_file_name}\n'
                                            else:
                                                contents = f'{submitted_url_count}.({result_name}) ' \
                                                           f'{result_url}\n - {result_scan_file_name}\n' \
                                                           f'"""\n{result_vulnerabilities}"""\n\n'

                                                message += f'"""\n{result_vulnerabilities}"""\n\n'

                                            scan_result += contents

                                            # send result to telegram chatroom
                                            verify_message_size_and_send(message, result_telegram_chat_id)
                                            send_to_telegram_document(result_scan_file_name,
                                                                      f'{result_name}_{result_url}',
                                                                      result_telegram_chat_id)

                                        else:
                                            print(f'\x1b[0;43;43m Scan Completed.! \x1b')
                                    except TimeoutError:
                                        pass
                            except Exception as e:
                                # print(e)
                                continue
                        else:
                            print(f'{Bcolors.Yellow}- scan_target or service_name is empty. '
                                  f'check {_scan_list} {Bcolors.Endc}')
                            sys.exit(1)

    if scan_result:
        print(f'\x1b[0;43;43m Scan Completed.! \x1b[0m')
        print('\n')
        print(f'[RESULT]\n{scan_result}')


def run_wpscan(scan_url, scan_name, tg_chat_id):
    today = datetime.now(timezone.utc).astimezone()
    output_file_name = f'{_home_path}/{today.strftime("%Y%m%d")}' \
                       f'_{create_job_id()}_{scan_url.replace("https://", "").replace("/", "")}_wpscan_result.json'

    command = f'wpscan --url {scan_url} --detection-mode mixed --random-user-agent ' \
              f'--output {output_file_name} --format json --api-token {_wpscan_api_token}'

    result = subprocess.run(command, shell=True, capture_output=False)

    if result.returncode == 1 or result.returncode == 4:
        result = f'{result.returncode}|{scan_name}|{scan_url}|{tg_chat_id}' \
                 f'|0|scan_aborted. wrong url or something scan failed.|{output_file_name}|0'
    else:
        vulnerabilities_count, wp_banner, vulnerabilities_list = parse_wpscan_result(output_file_name)
        result = f'{result.returncode}|{scan_name}|{scan_url}|{tg_chat_id}' \
                 f'|{vulnerabilities_count}|{wp_banner}|{output_file_name}|{vulnerabilities_list}'
    return result


def parse_wpscan_result(result_file):
    with open(result_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    wp_ver = f"{data['version']['number']}"
    i = 0
    result = ''

    if 'error' in data['vuln_api']:
        print('No WPScan API Token given, as a result vulnerability data has not been output ')
    else:
        if 'vulnerabilities' in data['version']:
            vulnerabilities = data['version']['vulnerabilities']
            if not vulnerabilities:
                contents = 'vulnerabilities key is present but empty'
                print('vulnerabilities key is present but empty')
            else:
                for item in data['version']['vulnerabilities']:
                    i += 1
                    if item['fixed_in'] is not None:
                        fixed = item['fixed_in']
                    else:
                        fixed = 'null'
                    contents = f"{i}) {item['title']} (fixed: {fixed})\n"
                    result += contents
    return i, wp_ver, result


def verify_message_size_and_send(text, chat_id):
    if len(text) <= 4096:
        send_to_telegram_message(text, chat_id)
    else:
        parts = []
        while len(text) > 0:
            if len(text) > 4060:
                part = text[:4060]
                first_lnbr = part.rfind('\n')
                if first_lnbr != -1:
                    parts.append(part[:first_lnbr])
                    text = text[first_lnbr:]
                else:
                    parts.append(part)
                    text = text[4060:]
            else:
                parts.append(text)
                break
        for idx, part in enumerate(parts):
            if idx == 0:
                send_to_telegram_message(part, chat_id)
            else:
                part = f'(Continue...)\n{part}'
                send_to_telegram_message(part, chat_id)
            time.sleep(3)


def send_to_telegram_message(message, chat_id):
    url = f'https://api.telegram.org/bot{_telegram_bot_token}/sendMessage'
    header = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) '
                            'Chrome/49.0.2623.112 Safari/537.36'}

    params = {
        'chat_id': chat_id,
        'text': message,
    }

    try:
        r = requests.get(url, headers=header, data=params, verify=True)
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f'{Bcolors.Yellow}- ::Exception:: Func:[{send_to_telegram_message.__name__}] '
              f'Line:[{sys.exc_info()[-1].tb_lineno}] [{type(e).__name__}] {e}{Bcolors.Endc}')
    else:
        r.close()


def send_to_telegram_document(file_name, file_caption, chat_id):
    url = f'https://api.telegram.org/bot{_telegram_bot_token}/sendDocument'
    header = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) '
                            'Chrome/49.0.2623.112 Safari/537.36'}

    params = {
        'chat_id': chat_id,
        'caption': file_caption,
    }

    readfile = open(file_name, 'rb')
    sendfile = {'document': readfile}

    try:
        r = requests.post(url, headers=header, data=params, files=sendfile, verify=True)
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f'{Bcolors.Yellow}- ::Exception:: Func:[{send_to_telegram_document.__name__}] '
              f'Line:[{sys.exc_info()[-1].tb_lineno}] [{type(e).__name__}] {e}{Bcolors.Endc}')
    else:
        r.close()


def main():
    banner = """
 .d8b.  db    db d888888b  .d88b.  db   d8b   db d8888b. .d8888.  .o88b.  .d8b.  d8b   db 
d8' `8b 88    88 `~~88~~' .8P  Y8. 88   I8I   88 88  `8D 88'  YP d8P  Y8 d8' `8b 888o  88 
88ooo88 88    88    88    88    88 88   I8I   88 88oodD' `8bo.   8P      88ooo88 88V8o 88 
88~~~88 88    88    88    88    88 Y8   I8I   88 88~~~     `Y8b. 8b      88~~~88 88 V8o88 
88   88 88b  d88    88    `8b  d8' `8b d8'8b d8' 88      db   8D Y8b  d8 88   88 88  V888 
YP   YP ~Y8888P'    YP     `Y88P'   `8b8' `8d8'  88      `8888Y'  `Y88P' YP   YP VP   V8P 
"""
    print(f'\n')
    print(f'{Bcolors.Cyan}{banner}{Bcolors.Endc}')
    print(f'Autowpscan {__version__}')
    print(f'- WordPress scanner that automatically scans a list of domains > analyze > send the results.')
    print(f'- Run time: {datetime.today().strftime("%Y-%m-%d %H:%M:%S")}')
    print('- For questions contact github.com/password123456\t\t')
    print('\n')
    print(f'{Bcolors.Green}------------------------------------->{Bcolors.Endc}')
    print(f'- Scan List  : {_scan_list}')
    print(f'- Scan Count : {raw_count(_scan_list)}')
    print(f'-{Bcolors.Green} O.K Here We go.!{Bcolors.Endc}')
    do_scan()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f'{Bcolors.Yellow}- ::Exception:: Func:[{__name__.__name__}] '
              f'Line:[{sys.exc_info()[-1].tb_lineno}] [{type(e).__name__}] {e}{Bcolors.Endc}')
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
