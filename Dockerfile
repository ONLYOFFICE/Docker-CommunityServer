FROM ubuntu:14.04
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ARG RELEASE_DATE="2016-06-21"
ARG RELEASE_DATE_SIGN=""
ARG VERSION="8.9.0.190"
ARG SOURCE_REPO_URL="deb http://static.teamlab.com.s3.amazonaws.com/repo/debian squeeze main"
ARG DEBIAN_FRONTEND=noninteractive 

LABEL onlyoffice.community.release-date="${RELEASE_DATE}" \
      onlyoffice.community.version="${VERSION}" \
      onlyoffice.community.release-date.sign="${RELEASE_DATE_SIGN}" 

ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

RUN echo "${SOURCE_REPO_URL}" >> /etc/apt/sources.list && \
    echo "deb http://download.mono-project.com/repo/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/mono-official.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    locale-gen en_US.UTF-8 && \
    apt-get -y update && \
    apt-get install --force-yes -yq software-properties-common wget curl cron rsyslog gcc make && \
    wget https://www.openssl.org/source/openssl-1.1.0f.tar.gz && \
    tar xzvf openssl-1.1.0f.tar.gz && \
    cd openssl-1.1.0f && \
    ./config && \
    make && \
    sudo make install && \
    cd .. && \
    rm -f openssl-1.1.0f.tar.gz && \
    wget http://nginx.org/keys/nginx_signing.key && \
    apt-key add nginx_signing.key && \
    echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list.d/nginx.list && \
    echo "deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list.d/nginx.list && \	
    add-apt-repository -y ppa:builds/sphinxsearch-rel22 && \
    add-apt-repository -y ppa:certbot/certbot && \
    echo "Start=No" >> /etc/init.d/sphinxsearch && \
    apt-get -y update && \
    apt-get install --force-yes -yq mono-complete ca-certificates-mono && \
    echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get install --force-yes -yq dumb-init certbot sphinxsearch onlyoffice-communityserver htop nano dnsutils && \
    rm -rf /var/lib/apt/lists/*


ADD config /app/onlyoffice/config/
ADD assets /app/onlyoffice/assets/
ADD run-community-server.sh /app/onlyoffice/run-community-server.sh
RUN chmod -R 755 /app/onlyoffice/*.sh

VOLUME ["/var/log/onlyoffice"]
VOLUME ["/var/www/onlyoffice/Data"]
VOLUME ["/var/lib/mysql"]

EXPOSE 80 443 5222 3306 9865 9888 9866 9871 9882 5280

CMD ["/app/onlyoffice/run-community-server.sh"];
