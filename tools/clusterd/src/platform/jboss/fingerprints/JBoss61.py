# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036
from src.platform.jboss.interfaces import JINTERFACES
from cprint import FingerPrint


class FPrint(FingerPrint):
    
    def __init__(self):
        self.platform = "jboss"
        self.version = "6.1"
        self.title = JINTERFACES.WM
        self.uri = "/admin-console/plugins/jopr-hibernate-plugin-3.0.0.jar"
        self.port = 8080
        self.hash = "740c9a0788ffce2944b9c9783d8ce679" 
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
