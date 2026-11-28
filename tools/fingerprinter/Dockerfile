# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM ruby:2.7

WORKDIR /usr/src/app

COPY Gemfile ./
RUN bundle install

COPY . .

RUN chmod +x fingerprinter.rb
ENTRYPOINT ["/usr/src/app/fingerprinter.rb"]
CMD ["--help"]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
