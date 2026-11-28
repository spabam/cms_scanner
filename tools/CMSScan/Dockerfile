# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM python:3
ENV PATH="/root/.venv/bin:${PATH}"
LABEL \
    name="CMSScan" \
    author="Ajin Abraham <ajin25@gmail.com>" \
    description="Scan WordPress, Joomla, vBulletin and Drupal CMS for Security issues"
RUN \
  apt-get update && \
  apt-get install -y ruby \
  ruby-dev \
  git \
  libwww-perl

RUN gem install wpscan && \
  wpscan --update

WORKDIR /usr/src/app/
COPY . .
RUN python -m venv /root/.venv && \
    /root/.venv/bin/python -m pip install --no-cache-dir -r requirements.txt

RUN git clone https://github.com/rezasp/vbscan.git
RUN git clone https://github.com/rezasp/joomscan.git

RUN mv vbscan /usr/src/app/plugins/vbscan
RUN mv joomscan /usr/src/app/plugins/joomscan

EXPOSE 7070
CMD ["/root/.venv/bin/gunicorn", "--bind", "0.0.0.0:7070", "app:app", "--workers", "3", "--timeout", "10000"]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
