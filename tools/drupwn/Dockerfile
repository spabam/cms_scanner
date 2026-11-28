# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM alpine:latest
ENV PATH="/root/.venv/bin:${PATH}"

RUN apk update
RUN apk add python3 py3-pip

ADD . /opt/drupwn

WORKDIR /opt/drupwn

RUN python3 -m venv /root/.venv && \
    /root/.venv/bin/python -m pip install .

ENTRYPOINT ["/root/.venv/bin/drupwn"]
CMD ["--help"]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
