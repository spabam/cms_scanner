# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
import re
from urllib.parse import urlparse


def parsing_url(url):
    host = urlparse(url).netloc
    return host
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
