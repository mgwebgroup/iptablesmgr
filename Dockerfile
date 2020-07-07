FROM debian:buster

ARG wdir="/opt"
WORKDIR $wdir

RUN apt-get update && apt-get install -y iptables sudo nano

# Debian 10 (Buster) uses nftables instead of iptables, however iptables is still provided
# see https://wiki.debian.org/iptables for details
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy
RUN update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
# The following two give error about not being registered:
#RUN update-alternatives --set arptables /usr/sbin/arptables-legacy
#RUN update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# Copy application files
COPY iptablesmgr.sh .
COPY paths_get .
COPY paths_post .
COPY iptablesmgr .

# Copy sample Apache log
COPY access.log .

CMD /bin/bash
