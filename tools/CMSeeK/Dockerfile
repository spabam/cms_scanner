# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM python:3-alpine
ENV PATH="/root/.venv/bin:${PATH}"

LABEL name CMSeeK
LABEL src "https://github.com/Tuhinshubhra/CMSeeK"
LABEL creato Tuhinshubhra
LABEL dockerfile_maintenance khast3x
LABEL desc "CMS Detection and Exploitation suite - Scan WordPress, Joomla, Drupal and 130 other CMSs."


RUN apk add --no-cache git py3-pip && git clone https://github.com/Tuhinshubhra/CMSeeK

WORKDIR CMSeeK
RUN python -m venv /root/.venv && \
    /root/.venv/bin/python -m pip install -r requirements.txt
ENTRYPOINT [ "/root/.venv/bin/python", "cmseek.py" ]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
