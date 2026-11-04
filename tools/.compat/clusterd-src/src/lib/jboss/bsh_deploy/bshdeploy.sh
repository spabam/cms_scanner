#!/bin/sh
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com

#
# This application is part of the clusterd attack framework.
#

# ensure we're compiled
if [ ! -f "bshdeploy.class" ]; then
    ./buildbsh.sh
fi

# invoke
java -cp .:../console-mgr-classes.jar:../jbossall-client.jar bshdeploy $1 $2 $3 $4 $5
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
