#!/bin/sh
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com

#
# This application is part of the clusterd attack framework.
# this file builds our web-console deployer.

javac -cp ..:../jbossall-client.jar:../console-mgr-classes.jar webc_deploy.java
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
