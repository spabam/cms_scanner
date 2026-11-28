# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
FROM debian:stretch-slim
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
	    
# Install Git,
RUN apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends --no-install-suggests && \
        git        && \
	rm -rf /var/lib/apt/lists/* && \
    apt-get clean &&  \
    rm -rf /tmp/* /var/tmp/* /usr/share/doc/*

# Make Vulnx Directory & Clonning Vulnx From Github
RUN mkdir -p /usr/share/vulnx && cd usr/share/vulnx && \
    git clone https://www.github.com/anouarbensaad/vulnx

# Make vulnx group
RUN addgroup vulnx

# added \\vulnx [group] secondary group to vulnx.
RUN adduser -G vulnx -g "vulnx user" -s /bin/sh -D vulnx

# change vulnx owner of directory of project.
RUN chown -R vulnx vulnx

# Install Python before switching to the runtime user.
RUN apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends \
        python3        \
        python3-pip    \
        python3-venv && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /usr/share/doc/*

# Switch user.
USER vulnx
ENV PATH="/home/vulnx/.venv/bin:${PATH}"

# Working−Directory
WORKDIR vulnx

# Install packages in the runtime user's one canonical environment.
RUN python3 -m venv /home/vulnx/.venv && \
    /home/vulnx/.venv/bin/python -m pip install requests bs4

# Add Mount Volume Docker To Save All changes.
VOLUME [ "/vulnx" ]

#run container with it mode & run python3 vulnx.py -u ...
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
