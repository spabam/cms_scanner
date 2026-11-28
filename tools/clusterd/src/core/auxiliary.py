# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036
class Auxiliary(object):

    def __init__(self):
        self.name = None        # name of the module
        self.versions = []      # supported versions
        self.flag = None        # CLI flag

    def check(self, fingerprint):
        """ Given the fingerprint of a remote service, check whether this
        module is relevant.

        True for valid, False for not
        """

        raise NotImplementedError

    def run(self, fingerengine, fingerprint):
        """ Initiates the module
        """

        raise NotImplementedError
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
