# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
from src.platform.weblogic.interfaces import WINTERFACES, WLConsole


class FPrint(WLConsole):

    def __init__(self):
        super(FPrint, self).__init__()
        self.version = "12"
        self.title = WINTERFACES.WLS
        self.port = 9002
        self.ssl = True
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
