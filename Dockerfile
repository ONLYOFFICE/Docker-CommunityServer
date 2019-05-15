FROM ubuntu:18.04

ARG RELEASE_DATE="2016-06-21"
ARG RELEASE_DATE_SIGN=""
ARG VERSION="8.9.0.190"
ARG SOURCE_REPO_URL="deb http://static.teamlab.com.s3.amazonaws.com/repo/debian squeeze main"
ARG DEBIAN_FRONTEND=noninteractive

LABEL onlyoffice.community.release-date="${RELEASE_DATE}" \
      onlyoffice.community.version="${VERSION}" \
      maintainer="Ascensio System SIA <support@onlyoffice.com>"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get -y update && \
    apt-get -yq install gnupg2 ca-certificates && \
    apt-get install -yq sudo locales && \
    addgroup --system --gid 107 onlyoffice && \
    adduser -uid 104 --quiet --home /var/www/onlyoffice --system --gid 107 onlyoffice && \
    addgroup --system --gid 104 elasticsearch && \
    adduser -uid 103 --quiet --home /nonexistent --system --gid 104 elasticsearch && \
    echo "${SOURCE_REPO_URL}" >> /etc/apt/sources.list && \
    echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official.list && \
    echo "deb http://download.onlyoffice.com/repo/mono/ubuntu bionic main" | tee /etc/apt/sources.list.d/mono-onlyoffice.list && \    
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    locale-gen en_US.UTF-8 && \
    apt-get -y update && \
    apt-get install -yq software-properties-common wget curl cron rsyslog && \
    wget http://nginx.org/keys/nginx_signing.key && \
    apt-key add nginx_signing.key && \
    echo "deb http://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list.d/nginx.list && \
    echo "deb-src http://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list.d/nginx.list && \
    apt-get install -yq openjdk-8-jre-headless && \
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    apt-get install -yq apt-transport-https && \
    echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list && \
    apt-get update && \
    apt-get install -yq elasticsearch=6.5.0 && \
    add-apt-repository -y ppa:certbot/certbot && \
    add-apt-repository -y ppa:chris-lea/redis-server && \
    add-apt-repository -y ppa:jonathonf/ffmpeg-4 && \
    curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && \
    apt-get install -y nodejs && \
    apt-get -y update && \
    apt-get install -yq nginx gdb mono-complete ca-certificates-mono && \
    echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get install -yq dumb-init python-certbot-nginx htop nano dnsutils redis-server python3-pip multiarch-support iproute2 ffmpeg && \
    apt-get install -yq mono-webserver-hyperfastcgi=0.4-7 && \    
    apt-get install -yq onlyoffice-communityserver && \
    rm -rf /var/lib/apt/lists/*

ADD config /app/onlyoffice/config/
ADD assets /app/onlyoffice/assets/
ADD run-community-server.sh /app/onlyoffice/run-community-server.sh
RUN chmod -R 755 /app/onlyoffice/*.sh

VOLUME ["/var/log/onlyoffice", "/var/www/onlyoffice/Data", "/var/lib/mysql"]

EXPOSE 80 443 5222 3306 9865 9888 9866 9871 9882 5280

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/app/onlyoffice/run-community-server.sh"];
