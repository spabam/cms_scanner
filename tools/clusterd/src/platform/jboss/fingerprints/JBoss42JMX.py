# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036
from src.platform.jboss.interfaces import JMXInterface


class FPrint(JMXInterface):
    
    def __init__(self):
        super(FPrint, self).__init__()
        self.version = "4.2"
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
