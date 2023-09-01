FROM ubuntu:22.04

ARG RELEASE_DATE="2016-06-21"
ARG RELEASE_DATE_SIGN=""
ARG VERSION="8.9.0.190"
ARG SOURCE_REPO_URL="deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main"
ARG DEBIAN_FRONTEND=noninteractive
ARG PACKAGE_SYSNAME="onlyoffice"

ARG ELK_DIR=/usr/share/elasticsearch
ARG ELK_INDEX_DIR=/var/www/${PACKAGE_SYSNAME}/Data/Index
ARG ELK_LOG_DIR=/var/log/${PACKAGE_SYSNAME}/Index
ARG ELK_LIB_DIR=${ELK_DIR}/lib
ARG ELK_MODULE_DIR=${ELK_DIR}/modules

LABEL ${PACKAGE_SYSNAME}.community.release-date="${RELEASE_DATE}" \
      ${PACKAGE_SYSNAME}.community.version="${VERSION}" \
      description="Community Server is a free open-source collaborative system developed to manage documents, projects, customer relationship and emails, all in one place." \
      maintainer="Ascensio System SIA <support@${PACKAGE_SYSNAME}.com>" \
      securitytxt="https://www.${PACKAGE_SYSNAME}.com/.well-known/security.txt"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    ELASTICSEARCH_VERSION=7.16.3

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
    echo "deb [signed-by=/usr/share/keyrings/xamarin.gpg] https://download.mono-project.com/repo/ubuntu stable-focal/snapshots/6.8.0.123 main" | tee /etc/apt/sources.list.d/mono-official.list && \
    echo "deb [signed-by=/usr/share/keyrings/mono-extra.gpg] https://d2nlctn12v279m.cloudfront.net/repo/mono/ubuntu focal main" | tee /etc/apt/sources.list.d/mono-extra.list && \
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/onlyoffice.gpg --import && \
	chmod 644 /usr/share/keyrings/onlyoffice.gpg && \
    curl -fsSL https://download.mono-project.com/repo/xamarin.gpg | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/xamarin.gpg --import && \
	chmod 644 /usr/share/keyrings/xamarin.gpg && \
	curl -fsSL https://d2nlctn12v279m.cloudfront.net/repo/mono/mono.key | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/mono-extra.gpg --import && \
	chmod 644 /usr/share/keyrings/mono-extra.gpg && \
    wget http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/multiarch-support_2.27-3ubuntu1_amd64.deb && \
    apt-get install ./multiarch-support_2.27-3ubuntu1_amd64.deb && \
    rm -f ./multiarch-support_2.27-3ubuntu1_amd64.deb && \
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list && \
    wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    sudo dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    printf "Package: * \nPin: origin \"packages.microsoft.com\"\nPin-Priority: 1001" > /etc/apt/preferences && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/nodesource.gpg --import && \
    chmod 644 /usr/share/keyrings/nodesource.gpg && \
    apt-get -y update && \
    apt-get install -yq gnupg2 \
                        ca-certificates \
                        software-properties-common \
                        cron \
                        rsyslog \
			ruby-dev \
			ruby-god \
                        nodejs \
                        nginx \
                        gdb \
                        mono-complete \
                        ca-certificates-mono \
                        python3-certbot-nginx \
                        htop \
                        nano \
                        dnsutils \
                        redis-server \
                        python3-pip \
                        multiarch-support \
                        iproute2 \
                        ffmpeg \
                        jq \
                        apt-transport-https \
                        elasticsearch=${ELASTICSEARCH_VERSION} && \
    mkdir -p ${ELK_INDEX_DIR}/v${ELASTICSEARCH_VERSION} && \
    mkdir -p ${ELK_LOG_DIR} && \
    chmod -R u=rwx /var/www/${PACKAGE_SYSNAME} && \
    chmod -R g=rx /var/www/${PACKAGE_SYSNAME} && \
    chmod -R o=rx /var/www/${PACKAGE_SYSNAME} && \
    chown -R elasticsearch:elasticsearch ${ELK_INDEX_DIR}/v${ELASTICSEARCH_VERSION} && \
    chown -R elasticsearch:elasticsearch ${ELK_LOG_DIR} && \
    chmod -R u=rwx ${ELK_INDEX_DIR}/v${ELASTICSEARCH_VERSION} && \
    chmod -R g=rs ${ELK_INDEX_DIR}/v${ELASTICSEARCH_VERSION} && \
    chmod -R o= ${ELK_INDEX_DIR}/v${ELASTICSEARCH_VERSION} && \
    apt-get install -yq \
                        mono-webserver-hyperfastcgi=0.4-8 \
                        dotnet-sdk-7.0 \
                        ${PACKAGE_SYSNAME}-communityserver \
                        ${PACKAGE_SYSNAME}-xmppserver && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY config /app/config/
COPY assets /app/assets/
COPY run-community-server.sh /app/run-community-server.sh

RUN chmod -R 755 /app/*.sh

VOLUME ["/sys/fs/cgroup","/var/log/${PACKAGE_SYSNAME}", "/var/www/${PACKAGE_SYSNAME}/Data", "/var/lib/mysql", "/etc/letsencrypt"]

EXPOSE 80 443 5222 3306 9865 9888 9866 9871 9882 5280

CMD ["/app/run-community-server.sh"];
