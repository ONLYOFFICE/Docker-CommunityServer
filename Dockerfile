FROM ubuntu:18.04

ARG RELEASE_DATE="2016-06-21"
ARG RELEASE_DATE_SIGN=""
ARG VERSION="8.9.0.190"
ARG SOURCE_REPO_URL="deb http://static.teamlab.com.s3.amazonaws.com/repo/debian squeeze main"
ARG DEBIAN_FRONTEND=noninteractive
ARG PACKAGE_SYSNAME="onlyoffice"

LABEL ${PACKAGE_SYSNAME}.community.release-date="${RELEASE_DATE}" \
      ${PACKAGE_SYSNAME}.community.version="${VERSION}" \
      maintainer="Ascensio System SIA <support@${PACKAGE_SYSNAME}.com>" \
      securitytxt="https://www.${PACKAGE_SYSNAME}.com/.well-known/security.txt"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y dist-upgrade && \
    addgroup --system --gid 107 ${PACKAGE_SYSNAME} && \
    adduser -uid 104 --quiet --home /var/www/${PACKAGE_SYSNAME} --system --gid 107 ${PACKAGE_SYSNAME} && \
    addgroup --system --gid 104 elasticsearch && \
    adduser -uid 103 --quiet --home /nonexistent --system --gid 104 elasticsearch && \
    apt-get -yq install systemd \
                        systemd-sysv \
                        locales \
                        software-properties-common \
                        curl \
                        wget \
                        sudo && \
    cd /lib/systemd/system/sysinit.target.wants/ && ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp* && \
    locale-gen en_US.UTF-8 && \
    echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    echo "${SOURCE_REPO_URL}" >> /etc/apt/sources.list && \
    echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic/snapshots/6.10.0.104 main" | tee /etc/apt/sources.list.d/mono-official.list && \
    echo "deb https://d2nlctn12v279m.cloudfront.net/repo/mono/ubuntu bionic main" | tee /etc/apt/sources.list.d/mono-extra.list && \    
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    wget http://nginx.org/keys/nginx_signing.key && \
    apt-key add nginx_signing.key && \
    echo "deb http://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list.d/nginx.list && \
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list && \
    add-apt-repository -y ppa:certbot/certbot && \
    add-apt-repository -y ppa:chris-lea/redis-server && \
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - && \
    apt-get install -yq gnupg2 \
                        ca-certificates \
                        software-properties-common \
                        cron \
                        rsyslog \
                        nodejs \
                        nginx \
                        gdb \
                        mono-complete \
                        ca-certificates-mono \
                        python-certbot-nginx \
                        htop \
                        nano \
                        dnsutils \
                        redis-server \
                        python3-pip \
                        multiarch-support \
                        iproute2 \
                        ffmpeg \
                        jq \
                        openjdk-8-jre-headless \
                        apt-transport-https \
                        elasticsearch=7.4.0 \
                        mono-webserver-hyperfastcgi=0.4-7 \
                        ${PACKAGE_SYSNAME}-communityserver \
                        ${PACKAGE_SYSNAME}-xmppserver && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY config /app/config/
COPY assets /app/assets/
COPY run-community-server.sh /app/run-community-server.sh

RUN chmod -R 755 /app/*.sh

VOLUME ["/sys/fs/cgroup","/var/log/${PACKAGE_SYSNAME}", "/var/www/${PACKAGE_SYSNAME}/Data", "/var/lib/mysql"]

EXPOSE 80 443 5222 3306 9865 9888 9866 9871 9882 5280

CMD ["/app/run-community-server.sh"];
