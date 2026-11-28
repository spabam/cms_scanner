# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM python:3
ENV PATH="/root/.venv/bin:${PATH}"

RUN apt update && apt upgrade -y
RUN git clone https://github.com/0ang3el/aem-hacker.git
WORKDIR /aem-hacker
RUN python -m venv /root/.venv && \
    /root/.venv/bin/python -m pip install -r requirements.txt

ENTRYPOINT [ "/bin/bash" ]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
