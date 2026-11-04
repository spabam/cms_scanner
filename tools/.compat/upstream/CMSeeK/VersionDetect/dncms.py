#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# This is a part of CMSeeK, check the LICENSE file for more information
# Copyright (c) 2018 - 2020 Tuhinshubhra

# Danneo CMS version detection
# Rev 1

import cmseekdb.basic as cmseek
import re

def start(url, ua):
    kurama = cmseek.getsource(url, ua)
    header = kurama[2].split('\n')
    regex = []
    for tail in header:
        if 'X-Powered-By: CMS Danneo' in tail:
            regex = re.findall(r'X-Powered-By: CMS Danneo (.*)', tail)
    if regex != []:
        cmseek.success('Danneo CMS version ' + cmseek.bold + cmseek.fgreen + regex[0] + cmseek.cln + ' detected')
        return regex[0]
    else:
        cmseek.error('Version detection failed!')
        return '0'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
