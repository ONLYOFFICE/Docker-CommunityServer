FROM ubuntu:16.04

ARG RELEASE_DATE="2016-06-21"
ARG RELEASE_DATE_SIGN=""
ARG VERSION="8.9.0.190"
ARG SOURCE_REPO_URL="deb http://static.teamlab.com.s3.amazonaws.com/repo/debian squeeze main"
ARG DEBIAN_FRONTEND=noninteractive

LABEL onlyoffice.community.release-date="${RELEASE_DATE}" \
      onlyoffice.community.version="${VERSION}" \
      onlyoffice.community.release-date.sign="${RELEASE_DATE_SIGN}" \
      maintainer="Ascensio System SIA <support@onlyoffice.com>"

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN apt-get -y update && \
    apt-get install -yq sudo locales && \
    echo "${SOURCE_REPO_URL}" >> /etc/apt/sources.list && \
    echo "deb http://download.mono-project.com/repo/ubuntu stable-xenial main" | tee /etc/apt/sources.list.d/mono-official.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    locale-gen en_US.UTF-8 && \
    apt-get -y update && \
    apt-get install -yq software-properties-common wget curl cron rsyslog && \
    wget http://nginx.org/keys/nginx_signing.key && \
    apt-key add nginx_signing.key && \
    echo "deb http://nginx.org/packages/mainline/ubuntu/ xenial nginx" >> /etc/apt/sources.list.d/nginx.list && \
    echo "deb-src http://nginx.org/packages/mainline/ubuntu/ xenial nginx" >> /etc/apt/sources.list.d/nginx.list && \
    apt-get install -yq default-jdk && \
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    apt-get install -yq apt-transport-https && \
    echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list && \
    apt-get update && \
    apt-get install -yq elasticsearch && \
    add-apt-repository -y ppa:certbot/certbot && \
    curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && \
    apt-get install -y nodejs && \
    apt-get -y update && \
    apt-get install -yq nginx mono-complete ca-certificates-mono && \
    echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get install -yq dumb-init python-certbot-nginx htop nano dnsutils redis-server  && \
    wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm -f get-pip.py && \
    python3 -m pip install --upgrade radicale && \
    apt-get install -yq onlyoffice-communityserver && \
    rm -rf /var/lib/apt/lists/*

ADD config /app/onlyoffice/config/
ADD assets /app/onlyoffice/assets/
ADD run-community-server.sh /app/onlyoffice/run-community-server.sh
RUN chmod -R 755 /app/onlyoffice/*.sh

VOLUME ["/var/log/onlyoffice"]
VOLUME ["/var/www/onlyoffice/Data"]
VOLUME ["/var/lib/mysql"]

EXPOSE 80 443 5222 3306 9865 9888 9866 9871 9882 5280

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/app/onlyoffice/run-community-server.sh"];
