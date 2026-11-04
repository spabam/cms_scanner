#!/bin/sh
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com

#
# This application is part of the clusterd attack framework
#

# ensure we're compiled
if [ ! -f "RailoPasswordTool.class" ]; then
    ./buildpass.sh
fi

# invoke
java RailoPasswordTool d $1 
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
