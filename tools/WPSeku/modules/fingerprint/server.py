# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# Copyright (c) INFRA - Andrea Bodei 2026-2036
"""Support for getting the used server daemon."""
def server(headers):
	for key in headers.keys():
		if key.lower() == 'server':
			return headers[key]
	return 
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
