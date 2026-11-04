#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# This is a part of CMSeeK, check the LICENSE file for more information
# Copyright (c) 2018 - 2020 Tuhinshubhra

import cmseekdb.basic as cmseek
# I know there is no reason at all to create a separate module for this.. there's something that's going to be added here so.. trust me!
def start(source):
    # print(source)
    if 'Joomla! Debug Console' in source or 'xdebug.org/docs/all_settings' in source:
        cmseek.success('Debug mode on!')
        return '1'
    else:
        return '0'
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
