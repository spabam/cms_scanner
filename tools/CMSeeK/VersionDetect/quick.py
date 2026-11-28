#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036
# This is a part of CMSeeK, check the LICENSE file for more information
# Copyright (c) 2018 - 2020 Tuhinshubhra

# Quick.Cms version detection
# Rev 1

import cmseekdb.basic as cmseek
import re

def start(ga_content):
    ga_content = ga_content.lower()
    regex = re.findall(r'quick.cms v(.*)', ga_content)
    if regex != []:
        version = regex[0]
        cmseek.success('Quick.Cms version ' + cmseek.bold + cmseek.fgreen + version + cmseek.cln + ' detected')
        return version
    else:
        cmseek.error('Version detection failed!')
        return '0'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
