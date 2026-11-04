#!/bin/sh
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
. venv/bin/activate && \
gunicorn --bind 0.0.0.0:7070 app:app --workers 3 --timeout 10000
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
