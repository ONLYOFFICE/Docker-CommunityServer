FROM ubuntu:14.04
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

RUN echo "deb http://static.teamlab.com.s3.amazonaws.com/repo/debian/ squeeze main" >>  /etc/apt/sources.list && \
    echo "deb http://download.mono-project.com/repo/debian wheezy/snapshots/3.12.0 main" | sudo tee /etc/apt/sources.list.d/mono-xamarin.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D9D0BF019CC8AC0D && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    DEBIAN_FRONTEND=noninteractive  && \
    locale-gen en_US.UTF-8 && \
    apt-get -y update && \
    apt-get install --force-yes -yq software-properties-common && \
    add-apt-repository -y ppa:builds/sphinxsearch-rel22 && \
    echo "Start=No" >> /etc/init.d/sphinxsearch && \
    apt-get -y update && \
    apt-get install --force-yes -yq mono-devel mono-complete ca-certificates-mono && \
    echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get install --force-yes -yq  mysql-server mysql-client sphinxsearch  onlyoffice-communityserver wget htop nano dnsutils monit && \
    mkdir -p /app/onlyoffice/setup/data/mysql && mysqldump onlyoffice > /app/onlyoffice/setup/data/mysql/onlyoffice.sql && \
    rm -rf /var/lib/apt/lists/*

ADD config /app/onlyoffice/setup/config/
ADD run-community-server.sh /app/onlyoffice/run-community-server.sh
RUN chmod 755 /app/onlyoffice/*.sh

VOLUME ["/var/log/onlyoffice"]
VOLUME ["/var/www/onlyoffice/Data"]
VOLUME ["/var/lib/mysql"]

EXPOSE 80
EXPOSE 443
EXPOSE 5222

CMD bash -C '/app/onlyoffice/run-community-server.sh';'bash'
