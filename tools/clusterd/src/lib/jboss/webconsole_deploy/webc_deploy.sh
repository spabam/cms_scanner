#!/bin/sh
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036

#
# This application is part of the clusterd attack framework.
#

# ensure we're compiled
if [ ! -f "webc_deploy.class" ]; then
    ./buildwebc.sh
fi

# invoke
java -cp .:../console-mgr-classes.jar:../jbossall-client.jar webc_deploy $1 $2 $3 $4
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
