# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM alpine:latest

RUN apk update
RUN apk add python3

ADD . /opt/drupwn

WORKDIR /opt/drupwn

RUN python3 setup.py install

ENTRYPOINT ["drupwn"]
CMD ["--help"]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
