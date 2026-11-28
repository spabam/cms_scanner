# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM python:3-alpine
MAINTAINER BENSAAD Anouar bensaad.tig@gmail.com

# Project Informations.
LABEL name vulnx
LABEL src "https://github.com/anouarbensaad/vulnx"
LABEL creator anouarbensaad
LABEL desc "Vulnx is a cms and vulnerabilites detection, an intelligent auto shell injector,\
            fast cms detection of target and fast scanner and informations gathering like\
	    subdomains, \
	    ipaddresses,\
	    country,    \
	    org,        \
	    timezone,   \
	    region,     \
	    ans         \
	    and more ...\
            Instead of injecting shell and checking it works like all the other tools do,\
            vulnx analyses the response with and recieve if shell success uploaded or no.\
	    vulnx is searching for urls with dorks."
	    
# Clonning Vulnx From Github
RUN apk add --no-cache git && \
    git clone https://github.com/anouarbensaad/vulnx.git

# Make vulnx group
RUN addgroup vulnx

# added \\vulnx [group] secondary group to vulnx.
RUN adduser -G vulnx -g "vulnx user" -s /bin/sh -D vulnx

# change vulnx owner of directory of project.
RUN chown -R vulnx vulnx

# Switch user.
USER vulnx

ENV APP_HOME=vulnx
ENV PATH="/home/vulnx/.venv/bin:${PATH}"

# Working−Directory
WORKDIR $APP_HOME

# Install packages in the runtime user's one canonical environment.
RUN python -m venv /home/vulnx/.venv && \
    /home/vulnx/.venv/bin/python -m pip install --upgrade pip && \
    /home/vulnx/.venv/bin/python -m pip install -r ./requirements.txt

# Add Mount Volume Docker To Save All changes. 
VOLUME [ "/vulnx" ]

# Entrypoint -> Command : While Creating Container.
ENTRYPOINT [ "/home/vulnx/.venv/bin/python", "vulnx.py" ]

# Default Command When Starting The Container.
CMD ["--help"]
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
