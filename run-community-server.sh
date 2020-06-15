#!/bin/bash

set -x

echo "##########################################################"
echo "#########  Start container configuration  ################"
echo "##########################################################"


SERVER_HOST=${SERVER_HOST:-""};
APP_DIR="/var/www/onlyoffice"
APP_DATA_DIR="${APP_DIR}/Data"
APP_INDEX_DIR="${APP_DATA_DIR}/Index/v7.4.0"
APP_PRIVATE_DATA_DIR="${APP_DATA_DIR}/.private"
APP_SERVICES_DIR="${APP_DIR}/Services"
APP_SQL_DIR="${APP_DIR}/Sql"
APP_ROOT_DIR="${APP_DIR}/WebStudio"
APP_APISYSTEM_DIR="/var/www/onlyoffice/ApiSystem"
APP_MONOSERVER_PATH="/lib/systemd/system/monoserve.service";
APP_HYPERFASTCGI_PATH="/etc/hyperfastcgi/onlyoffice";
APP_MONOSERVE_COUNT=1;
APP_MODE=${APP_MODE:-"SERVER"};
APP_CRON_DIR="/etc/cron.d"
APP_CRON_PATH="/etc/cron.d/onlyoffice"
DOCKER_APP_SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -1);
DOCKER_CONTAINER_IP=$(ip addr show eth0 | awk '/inet / {gsub(/\/.*/,"",$2); print $2}' | head -1);
DOCKER_CONTAINER_NAME="onlyoffice-community-server";
DOCKER_ENABLED=${DOCKER_ENABLED:-true};
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NGINX_CONF_DIR="/etc/nginx/sites-enabled"
CPU_PROCESSOR_COUNT=${CPU_PROCESSOR_COUNT:-$(cat /proc/cpuinfo | grep -i processor | awk '{print $1}' | grep -i processor | wc -l)};
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)};
SERVICE_SSO_AUTH_HOST_ADDR=${SERVICE_SSO_AUTH_HOST_ADDR:-${CONTROL_PANEL_PORT_80_TCP_ADDR}};
DEFAULT_APP_CORE_MACHINEKEY="$(sudo sed -n '/"core.machinekey"/s!.*value\s*=\s*"\([^"]*\)".*!\1!p' ${APP_ROOT_DIR}/web.appsettings.config)";
IS_UPDATE="false"

CreateAuthToken() {
        local pkey="$1";
        local machinekey=$(echo -n "$2");
        local a=1
        local LIMIT=10
        
        while [ "$a" -le $LIMIT ]
        do
          local now=$(date +"%Y%m%d%H%M%S");
          local authkey=$(echo -n -e "${now}\n${pkey}" | openssl dgst -sha1 -binary -mac HMAC -macopt key:"$machinekey");
          authkey=$(echo -n "${authkey}" | base64);

          local result="ASC ${pkey}:${now}:${authkey}";
          a=$(($a + 1));

          if [ -z "$(echo \"$result\" | grep ==)" ]; then
                echo "$result"
                exit 0;
          fi

          sleep 1s;
        done
        
        exit 1;
}

if [ ! -e "${APP_PRIVATE_DATA_DIR}/machinekey" ]; then
   mkdir -p ${APP_PRIVATE_DATA_DIR};

   APP_CORE_MACHINEKEY=${ONLYOFFICE_CORE_MACHINEKEY:-${APP_CORE_MACHINEKEY:-${DEFAULT_APP_CORE_MACHINEKEY}}};
   echo "${APP_CORE_MACHINEKEY}" > ${APP_PRIVATE_DATA_DIR}/machinekey
else
   APP_CORE_MACHINEKEY=$(head -n 1 ${APP_PRIVATE_DATA_DIR}/machinekey)
fi

RELEASE_DATE="$(sudo sed -n '/"version.release-date"/s!.*value\s*=\s*"\([^"]*\)".*!\1!p' ${APP_ROOT_DIR}/web.appsettings.config)";
RELEASE_DATE_SIGN="$(CreateAuthToken "${RELEASE_DATE}" "${APP_CORE_MACHINEKEY}" )";

sed -i '/version.release-date.sign/s!value="[^"]*"!value=\"'"$RELEASE_DATE_SIGN"'\"!g' ${APP_ROOT_DIR}/web.appsettings.config


PREV_RELEASE_DATE=$(head -n 1 ${APP_PRIVATE_DATA_DIR}/release_date)

if [ "${RELEASE_DATE}" != "${PREV_RELEASE_DATE}" ]; then
	echo ${RELEASE_DATE} > ${APP_PRIVATE_DATA_DIR}/release_date
	IS_UPDATE="true";
fi


chmod -R 444 ${APP_PRIVATE_DATA_DIR}

if cat /proc/1/cgroup | grep -qE "docker|lxc|kubepods|libpod"; then
        DOCKER_ENABLED=true;
else
	DOCKER_ENABLED=false;
fi

if [ ! -d "$NGINX_CONF_DIR" ]; then
   mkdir -p $NGINX_CONF_DIR;
fi

if [ ! -d "${APP_DIR}/DocumentServerData" ]; then
   mkdir -p ${APP_DIR}/DocumentServerData;
fi

NGINX_ROOT_DIR="/etc/nginx"

VALID_IP_ADDRESS_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";

LOG_DEBUG="";

LOG_DIR="/var/log/onlyoffice/"

APP_HTTPS=${APP_HTTPS:-false}

SSL_CERTIFICATES_DIR="${APP_DATA_DIR}/certs"
SSL_CERTIFICATE_PATH=${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.crt}
SSL_KEY_PATH=${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.key}
SSL_CERTIFICATE_PATH_PFX=${SSL_CERTIFICATE_PATH_PFX:-${SSL_CERTIFICATES_DIR}/onlyoffice.pfx}
SSL_CERTIFICATE_PATH_PFX_PWD="onlyoffice";

SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}
SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
SSL_OCSP_CERTIFICATE_PATH=${SSL_OCSP_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/stapling.trusted.crt}
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-${SSL_CERTIFICATES_DIR}/ca.crt}
APP_HTTPS_HSTS_ENABLED=${APP_HTTPS_HSTS_ENABLED:-true}
APP_HTTPS_HSTS_MAXAGE=${APP_HTTPS_HSTS_MAXAGE:-63072000}

SYSCONF_TEMPLATES_DIR="${DIR}/config"

mkdir -p ${SYSCONF_TEMPLATES_DIR}/nginx;

SYSCONF_TOOLS_DIR="${DIR}/assets/tools"

APP_SERVICES_INTERNAL_HOST=${APP_SERVICES_PORT_9865_TCP_ADDR:-${APP_SERVICES_INTERNAL_HOST}}
APP_SERVICES_EXTERNAL=false
DOCUMENT_SERVER_ENABLED=false

DOCUMENT_SERVER_JWT_ENABLED=${DOCUMENT_SERVER_JWT_ENABLED:-false};
DOCUMENT_SERVER_JWT_SECRET=${DOCUMENT_SERVER_JWT_SECRET:-""};
DOCUMENT_SERVER_JWT_HEADER=${DOCUMENT_SERVER_JWT_HEADER:-""};
DOCUMENT_SERVER_HOST=${DOCUMENT_SERVER_HOST:-""};
DOCUMENT_SERVER_HOST_PROXY=${DOCUMENT_SERVER_HOST};
DOCUMENT_SERVER_PROTOCOL=${DOCUMENT_SERVER_PROTOCOL:-"http"};
DOCUMENT_SERVER_API_URL="";
DOCUMENT_SERVER_HOST_IP="";

CONTROL_PANEL_ENABLED=false
MAIL_SERVER_ENABLED=false

MYSQL_SERVER_ROOT_PASSWORD=${MYSQL_SERVER_ROOT_PASSWORD:-""}
MYSQL_SERVER_HOST=${MYSQL_SERVER_HOST:-"127.0.0.1"}
MYSQL_SERVER_PORT=${MYSQL_SERVER_PORT:-"3306"}
MYSQL_SERVER_DB_NAME=${MYSQL_SERVER_DB_NAME:-"onlyoffice"}
MYSQL_SERVER_USER=${MYSQL_SERVER_USER:-"root"}
MYSQL_SERVER_PASS=${MYSQL_SERVER_PASS:-${MYSQL_SERVER_ROOT_PASSWORD}}
MYSQL_SERVER_EXTERNAL=${MYSQL_SERVER_EXTERNAL:-false};

mkdir -p "${SSL_CERTIFICATES_DIR}/.well-known/acme-challenge"

check_ip_is_internal(){

	local IPRE='\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)';
	local IP=($(echo "$1" | sed -ne 's:^'"$IPRE"'/.*$:\1 \2 \3 \4:p'));
	local MASK=($(echo "$1" | sed -ne 's:^[^/]*/'"$IPRE"'$:\1 \2 \3 \4:p'))

	if [ ${#MASK[@]} -ne 4 ]; then
		local BITCNT=($(echo "$1" | sed -ne 's:^[^/]*/\([0-9]\+\)$:\1:p'))
		BITCNT=$(( ((2**${BITCNT})-1) << (32-${BITCNT}) ))
		for (( I=0; I<4; I++ )); do
				MASK[$I]=$(( ($BITCNT >> (8 * (3 - $I))) & 255 ))
		done
	fi

	local NETWORK=()

	for (( I=0; I<4; I++ )); do
		NETWORK[$I]=$(( ${IP[$I]} & ${MASK[$I]} ))
	done


	local INIP=($(echo "$2" | sed -ne 's:^'"$IPRE"'$:\1 \2 \3 \4:p'))

	for (( I=0; I<4; I++ )); do
		[[ $(( ${INIP[$I]} & ${MASK[$I]} )) -ne ${NETWORK[$I]} ]] && return 1; #false
	done

	return 0; #true
}

normalize_subnet(){
        local IPRE='\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)';
        local IP=($(echo "$1" | sed -ne 's:^'"$IPRE"'/.*$:\1 \2 \3 \4:p'));

        local MASK=($(echo "$1" | sed -ne 's:^[^/]*/'"$IPRE"'$:\1 \2 \3 \4:p'))

        if [ ${#MASK[@]} -ne 4 ]; then
                local BITCNT=($(echo "$1" | sed -ne 's:^[^/]*/\([0-9]\+\)$:\1:p'))
                BITCNT=$(( ((2**${BITCNT})-1) << (32-${BITCNT}) ))
                for (( I=0; I<4; I++ )); do
                        MASK[$I]=$(( ($BITCNT >> (8 * (3 - $I))) & 255 ))
                done
        fi

        local NETWORK=()

        for (( I=0; I<4; I++ )); do
                NETWORK[$I]=$(( ${IP[$I]} & ${MASK[$I]} ))
        done

        local IP_MASK=$(echo "$1" | sed -ne 's:^[^/]*/\([0-9]\+\)$:\1:p');


        echo ${NETWORK[0]}.${NETWORK[1]}.${NETWORK[2]}.${NETWORK[3]}/$IP_MASK
}

if [ ${DOCKER_APP_SUBNET} ]; then
	DOCKER_APP_SUBNET=$(normalize_subnet $DOCKER_APP_SUBNET);
fi

check_partnerdata(){
	PARTNER_DATA_FILE="${APP_DATA_DIR}/json-data.txt";

	if [ -f ${PARTNER_DATA_FILE} ]; then
		for serverID in $(seq 1 ${APP_MONOSERVE_COUNT});
		do
			index=$serverID;

			if [ $index == 1 ]; then
				index="";
			fi

			cp ${PARTNER_DATA_FILE} ${APP_ROOT_DIR}${index}/App_Data/static/partnerdata/
		done
	fi
}


log_debug () {
  echo "onlyoffice: [Debug] $1"
}


check_partnerdata

re='^[0-9]+$'

if ! [[ ${APP_MONOSERVE_COUNT} =~ $re ]] ; then
	echo "error: APP_MONOSERVE_COUNT not a number";
	APP_MONOSERVE_COUNT=2;
fi

# if [ "${APP_MONOSERVE_COUNT}" -eq "2" ] ; then
#	KERNER_CPU=$(nproc);
	
#	if [ "${KERNER_CPU}" -gt "${APP_MONOSERVE_COUNT}" ]; then
#		APP_MONOSERVE_COUNT=${KERNER_CPU};
#	fi	
# fi

if [ ! -f /proc/net/if_inet6 ]; then
	sed '/listen\s*\[::\]:80/d' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common-ssl.conf.template
	sed '/listen\s*\[::\]:443/d' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common-ssl.conf.template
fi

cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-nginx.conf.template ${NGINX_ROOT_DIR}/nginx.conf

sed 's/^worker_processes.*/'"worker_processes ${CPU_PROCESSOR_COUNT};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf
sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf

cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common-init.conf.template ${NGINX_CONF_DIR}/onlyoffice

if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
        sed 's,{{SSL_CERTIFICATE_PATH}},'"${SSL_CERTIFICATE_PATH}"',' -i ${NGINX_CONF_DIR}/onlyoffice
        sed 's,{{SSL_KEY_PATH}},'"${SSL_KEY_PATH}"',' -i ${NGINX_CONF_DIR}/onlyoffice
else
	sed '/{{SSL_CERTIFICATE_PATH}}/d' -i ${NGINX_CONF_DIR}/onlyoffice
	sed '/{{SSL_KEY_PATH}}/d' -i ${NGINX_CONF_DIR}/onlyoffice
	sed '/listen\s*443/d' -i ${NGINX_CONF_DIR}/onlyoffice
fi

rm -f ${NGINX_ROOT_DIR}/conf.d/*.conf

service nginx restart

#if ! grep -q "thread_pool.index.size" /etc/elasticsearch/elasticsearch.yml; then
#	echo "thread_pool.index.size: $CPU_PROCESSOR_COUNT" >> /etc/elasticsearch/elasticsearch.yml
#else
#	sed -i "s/thread_pool.index.size.*/thread_pool.index.size: $CPU_PROCESSOR_COUNT/" /etc/elasticsearch/elasticsearch.yml
#fi

if ! grep -q "thread_pool.write.size" /etc/elasticsearch/elasticsearch.yml; then
	echo "thread_pool.write.size: $CPU_PROCESSOR_COUNT" >> /etc/elasticsearch/elasticsearch.yml
else
	sed -i "s/thread_pool.write.size.*/thread_pool.write.size: $CPU_PROCESSOR_COUNT/" /etc/elasticsearch/elasticsearch.yml
fi

TOTAL_MEMORY=$(free -m | grep -oP '\d+' | head -n 1);
MEMORY_REQUIREMENTS=12228; #RAM ~4*3Gb

if [ ${TOTAL_MEMORY} -gt ${MEMORY_REQUIREMENTS} ]; then
	if ! grep -q "-Xms1g" /etc/elasticsearch/jvm.options; then
		echo "-Xms4g" >> /etc/elasticsearch/jvm.options
	else
		sed -i "s/-Xms1g/-Xms4g/" /etc/elasticsearch/jvm.options
	fi

	if ! grep -q "-Xmx1g" /etc/elasticsearch/jvm.options; then
		echo "-Xmx4g" >> /etc/elasticsearch/jvm.options
	else
		sed -i "s/-Xmx1g/-Xmx4g/" /etc/elasticsearch/jvm.options
	fi
fi

if [ ${APP_SERVICES_INTERNAL_HOST} ]; then
	APP_SERVICES_EXTERNAL=true;

	sed '/endpoint/s/http:\/\/localhost:9865\/teamlabJabber/http:\/\/'${APP_SERVICES_INTERNAL_HOST}':9865\/teamlabJabber/' -i ${APP_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9866\/teamlabSearcher/http:\/\/'${APP_SERVICES_INTERNAL_HOST}':9866\/teamlabSearcher/' -i ${APP_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9871\/teamlabNotify/http:\/\/'${APP_SERVICES_INTERNAL_HOST}':9871\/teamlabNotify/' -i ${APP_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9882\/teamlabBackup/http:\/\/'${APP_SERVICES_INTERNAL_HOST}':9882\/teamlabBackup/' -i ${APP_ROOT_DIR}/Web.config

        sed '/BoshPath/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${APP_SERVICES_INTERNAL_HOST}':5280\/http-poll\/\"!' -i  ${APP_ROOT_DIR}/web.appsettings.config

	sed '/<endpoint/s!\"netTcpBinding\"!\"basicHttpBinding\"!' -i ${APP_ROOT_DIR}/Web.config;

	if [ ${LOG_DEBUG} ]; then
		log_debug "Change connections for ${1} then ${2}";
	fi

	if [ "${DOCKER_ENABLED}" == "true" ]; then
		while ! bash ${SYSCONF_TOOLS_DIR}/wait-for-it.sh ${APP_SERVICES_INTERNAL_HOST}:9871 --quiet -s -- echo "ONLYOFFICE SERVICES is up"; do
    			sleep 1
		done
	fi

fi

if [ ${DOCUMENT_SERVER_HOST} ]; then
	DOCUMENT_SERVER_ENABLED=true;
	DOCUMENT_SERVER_API_URL="${DOCUMENT_SERVER_PROTOCOL}:\/\/${DOCUMENT_SERVER_HOST}";
elif [ ${DOCUMENT_SERVER_PORT_80_TCP_ADDR} ]; then
	DOCUMENT_SERVER_ENABLED=true;
	DOCUMENT_SERVER_HOST=${DOCUMENT_SERVER_PORT_80_TCP_ADDR};
	DOCUMENT_SERVER_HOST_PROXY="localhost\/ds-vpath";
	DOCUMENT_SERVER_API_URL="\/ds-vpath";
fi

if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ] && [ $DOCKER_APP_SUBNET ] && [ -z "$SERVER_HOST" ]; then
	DOCUMENT_SERVER_HOST_IP=$(dig +short ${DOCUMENT_SERVER_HOST});

	if check_ip_is_internal $DOCKER_APP_SUBNET $DOCUMENT_SERVER_HOST_IP; then
		_DOCKER_CONTAINER_IP=$(dig +short ${DOCKER_CONTAINER_NAME});

		if [ "${DOCKER_CONTAINER_IP}" == "${_DOCKER_CONTAINER_IP}" ]; then
			SERVER_HOST=${DOCKER_CONTAINER_NAME};
		else
			SERVER_HOST=${DOCKER_CONTAINER_IP};
		fi
	fi
fi


if [ ${MYSQL_SERVER_HOST} != "localhost" ] && [ ${MYSQL_SERVER_HOST} != "127.0.0.1" ]; then
	MYSQL_SERVER_EXTERNAL=true;
fi

if [ ${MYSQL_SERVER_PORT_3306_TCP} ]; then
	MYSQL_SERVER_EXTERNAL=true;
	MYSQL_SERVER_HOST=${MYSQL_SERVER_PORT_3306_TCP_ADDR};
	MYSQL_SERVER_PORT=${MYSQL_SERVER_PORT_3306_TCP_PORT};
	MYSQL_SERVER_DB_NAME=${MYSQL_SERVER_ENV_MYSQL_DATABASE:-${MYSQL_SERVER_DB_NAME}};
	MYSQL_SERVER_USER=${MYSQL_SERVER_ENV_MYSQL_USER:-${MYSQL_SERVER_USER}};
	MYSQL_SERVER_PASS=${MYSQL_SERVER_ENV_MYSQL_PASSWORD:-${MYSQL_SERVER_ENV_MYSQL_ROOT_PASSWORD:-${MYSQL_SERVER_PASS}}};

	if [ ${LOG_DEBUG} ]; then
		log_debug "MYSQL_SERVER_HOST: ${MYSQL_SERVER_HOST}";
		log_debug "MYSQL_SERVER_PORT: ${MYSQL_SERVER_PORT}";
		log_debug "MYSQL_SERVER_DB_NAME: ${MYSQL_SERVER_DB_NAME}";
		log_debug "MYSQL_SERVER_USER: ${MYSQL_SERVER_USER}";
		log_debug "MYSQL_SERVER_PASS: ${MYSQL_SERVER_PASS}";
	fi
fi


if [ ${CONTROL_PANEL_PORT_80_TCP} ]; then
	CONTROL_PANEL_ENABLED=true;
fi

MAIL_SERVER_API_PORT=${MAIL_SERVER_API_PORT:-${MAIL_SERVER_PORT_8081_TCP_PORT:-8081}};
MAIL_SERVER_API_HOST=${MAIL_SERVER_API_HOST:-${MAIL_SERVER_PORT_8081_TCP_ADDR}};
MAIL_SERVER_DB_HOST=${MAIL_SERVER_DB_HOST:-${MAIL_SERVER_PORT_3306_TCP_ADDR}};
MAIL_SERVER_DB_PORT=${MAIL_SERVER_DB_PORT:-${MAIL_SERVER_PORT_3306_TCP_PORT:-3306}};
MAIL_SERVER_DB_NAME=${MAIL_SERVER_DB_NAME:-"onlyoffice_mailserver"};
MAIL_SERVER_DB_USER=${MAIL_SERVER_DB_USER:-"mail_admin"};
MAIL_SERVER_DB_PASS=${MAIL_SERVER_DB_PASS:-"Isadmin123"};

if [ ${MAIL_SERVER_DB_HOST} ]; then
	MAIL_SERVER_ENABLED=true;

	if [ -z "${MAIL_SERVER_API_HOST}" ]; then
	        if [[ $MAIL_SERVER_DB_HOST =~ $VALID_IP_ADDRESS_REGEX ]]; then
			MAIL_SERVER_API_HOST=${MAIL_SERVER_DB_HOST};
        	elif [[ "$(dig +short $MAIL_SERVER_DB_HOST)" =~ $VALID_IP_ADDRESS_REGEX ]]; then
			MAIL_SERVER_API_HOST=$(dig +short ${MAIL_SERVER_DB_HOST});
	   	else
		    echo "MAIL_SERVER_API_HOST is empty";
	            exit 502;
       		fi
	else
		if [[ ! $MAIL_SERVER_API_HOST =~ $VALID_IP_ADDRESS_REGEX ]]; then
			MAIL_SERVER_API_HOST=$(dig +short ${MAIL_SERVER_API_HOST});
		fi

		if [ -z "${MAIL_SERVER_API_HOST}" ]; then
		    echo "MAIL_SERVER_API_HOST not correct";

                    exit 502;
		fi

	fi
fi


if [ ${MAIL_SERVER_API_HOST} ]; then
 if [ ! bash ${SYSCONF_TOOLS_DIR}/wait-for-it.sh  ${MAIL_SERVER_API_HOST}:25 --timeout=300 --quiet -s -- echo "MailServer is up" ]; then
	unset MAIL_SERVER_DB_HOST;
	unset MAIL_SERVER_PORT_3306_TCP_ADDR;
	MAIL_SERVER_DB_HOST="";
	echo "";
 fi
fi



REDIS_SERVER_HOST=${REDIS_SERVER_PORT_3306_TCP_ADDR:-${REDIS_SERVER_HOST}};
REDIS_SERVER_CACHEPORT=${REDIS_SERVER_PORT_3306_TCP_PORT:-${REDIS_SERVER_CACHEPORT:-"6379"}};
REDIS_SERVER_PASSWORD=${REDIS_SERVER_PASSWORD:-""};
REDIS_SERVER_SSL=${REDIS_SERVER_SSL:-"false"};
REDIS_SERVER_DATABASE=${REDIS_SERVER_DATABASE:-"0"};
REDIS_SERVER_CONNECT_TIMEOUT=${REDIS_SERVER_CONNECT_TIMEOUT:-"5000"};
REDIS_SERVER_EXTERNAL=false;

if [ ${REDIS_SERVER_HOST} ]; then
        sed 's/<add\s*host=".*"\s*cachePort="[0-9]*"\s*\/>/<add host="'${REDIS_SERVER_HOST}'" cachePort="'${REDIS_SERVER_CACHEPORT}'" \/>/' -i ${APP_ROOT_DIR}/Web.config
        sed -E 's/<redisCacheClient\s*ssl="(false|true)"\s*connectTimeout="[0-9]*"\s*database="[0-9]*"\s*password=".*">/<redisCacheClient ssl="'${REDIS_SERVER_SSL}'" connectTimeout="'${REDIS_SERVER_CONNECT_TIMEOUT}'" database="'${REDIS_SERVER_DATABASE}'" password="'${REDIS_SERVER_PASSWORD}'">/' -i ${APP_ROOT_DIR}/Web.config

        sed 's/<add\s*host=".*"\s*cachePort="[0-9]*"\s*\/>/<add host="'${REDIS_SERVER_HOST}'" cachePort="'${REDIS_SERVER_CACHEPORT}'" \/>/' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
        sed -E 's/<redisCacheClient\s*ssl="(false|true)"\s*connectTimeout="[0-9]*"\s*database="[0-9]*"\s*password=".*">/<redisCacheClient ssl="'${REDIS_SERVER_SSL}'" connectTimeout="'${REDIS_SERVER_CONNECT_TIMEOUT}'" database="'${REDIS_SERVER_DATABASE}'" password="'${REDIS_SERVER_PASSWORD}'">/' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config

	APP_SERVICES_SOCKET_IO_PATH=${APP_SERVICES_DIR}/ASC.Socket.IO/config/config.json;

	jq '.redis |= . + {"host":"'${REDIS_SERVER_HOST}'","port":'${REDIS_SERVER_CACHEPORT}',"db":'${REDIS_SERVER_DATABASE}',"pass":"'${REDIS_SERVER_PASSWORD}'"}'\
	 ${APP_SERVICES_SOCKET_IO_PATH} > ${APP_SERVICES_SOCKET_IO_PATH}.tmp && mv ${APP_SERVICES_SOCKET_IO_PATH}.tmp ${APP_SERVICES_SOCKET_IO_PATH}

        REDIS_SERVER_EXTERNAL=true;
fi

if [ "${REDIS_SERVER_EXTERNAL}" == "false" ]; then
	if [ -e /etc/redis/redis.conf ]; then
 	 sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf
	fi
fi

ELASTICSEARCH_SERVER_HOST=${ELASTICSEARCH_SERVER_ADDR:-${ELASTICSEARCH_SERVER_HOST}};
ELASTICSEARCH_SERVER_HTTPPORT=${ELASTICSEARCH_SERVER_HTTP_PORT:-${ELASTICSEARCH_SERVER_HTTPPORT:-"9200"}};

if grep -q '<section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" />' ${APP_ROOT_DIR}/Web.config; then
    echo "This entry is already there"
else
  if [ ${ELASTICSEARCH_SERVER_HOST} ]; then
    sed -i '/<section name="redisCacheClient" type="StackExchange.Redis.Extensions.LegacyConfiguration.RedisCachingSectionHandler, StackExchange.Redis.Extensions.LegacyConfiguration" \/>/a <section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" \/>' ${APP_ROOT_DIR}/Web.config
    sed -i 's/<section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" \/>/    <section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" \/>/' ${APP_ROOT_DIR}/Web.config
    sed -i '/<section name="redisCacheClient" type="StackExchange.Redis.Extensions.LegacyConfiguration.RedisCachingSectionHandler, StackExchange.Redis.Extensions.LegacyConfiguration" \/>/a <section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" \/>' ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
    sed -i 's/<section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" \/>/    <section name="elastic" type="ASC.ElasticSearch.Config.ElasticSection, ASC.ElasticSearch" \/>/' ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config

    if [ ${ELASTICSEARCH_SERVER_HTTPPORT} ]; then
        sed -i '/<\/configSections>/a <elastic scheme="http" host="'${ELASTICSEARCH_SERVER_HOST}'" port="'${ELASTICSEARCH_SERVER_HTTPPORT}'" \/>' ${APP_ROOT_DIR}/Web.config
        sed -i 's/<elastic scheme="http" host="'${ELASTICSEARCH_SERVER_HOST}'" port="'${ELASTICSEARCH_SERVER_HTTPPORT}'" \/>/  <elastic scheme="http" host="'${ELASTICSEARCH_SERVER_HOST}'" port="'${ELASTICSEARCH_SERVER_HTTPPORT}'" \/>/' ${APP_ROOT_DIR}/Web.config

        sed -i '/<\/configSections>/a <elastic scheme="http" host="'${ELASTICSEARCH_SERVER_HOST}'" port="'${ELASTICSEARCH_SERVER_HTTPPORT}'" \/>' ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
        sed -i 's/<elastic scheme="http" host="'${ELASTICSEARCH_SERVER_HOST}'" port="'${ELASTICSEARCH_SERVER_HTTPPORT}'" \/>/  <elastic scheme="http" host="'${ELASTICSEARCH_SERVER_HOST}'" port="'${ELASTICSEARCH_SERVER_HTTPPORT}'" \/>/' ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
    fi
  fi
fi

mysql_scalar_exec(){
	local queryResult="";

	if [ "$2" == "opt_ignore_db_name" ]; then
		queryResult=$(mysql --silent --skip-column-names -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} -e "$1");
	else
		queryResult=$(mysql --silent --skip-column-names -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} -D ${MYSQL_SERVER_DB_NAME} -e "$1");
	fi
	echo $queryResult;
}

mysql_list_exec(){
	local queryResult="";

	if [ "$2" == "opt_ignore_db_name" ]; then
		queryResult=$(mysql --silent --skip-column-names -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} -e "$1");
	else
		queryResult=$(mysql --silent --skip-column-names -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} -D ${MYSQL_SERVER_DB_NAME} -e "$1");
	fi

	read -ra vars <<< ${queryResult};
	for i in "${vars[0][@]}"; do
		echo $i
	done
}

mysql_batch_exec(){
	mysql --silent --skip-column-names -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} -D ${MYSQL_SERVER_DB_NAME} < "$1";
}

mysql_check_connection() {

	if [ ${LOG_DEBUG} ]; then
		log_debug "Mysql check connection for ${MYSQL_SERVER_HOST}";
	fi
	

	while ! mysqladmin ping -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} --silent; do
    		sleep 1
	done
}


change_connections(){
	sed '/'${1}'/s/\(connectionString\s*=\s*\"\)[^\"]*\"/\1Server='${MYSQL_SERVER_HOST}';Port='${MYSQL_SERVER_PORT}';Database='${MYSQL_SERVER_DB_NAME}';User ID='${MYSQL_SERVER_USER}';Password='${MYSQL_SERVER_PASS}';Pooling=true;Character Set=utf8;AutoEnlist=false;SSL Mode=none;AllowPublicKeyRetrieval=true;Connection Timeout=30;Maximum Pool Size=300;\"/' -i ${2}
}

if [ "${MYSQL_SERVER_EXTERNAL}" == "false" ]; then
	chown -R mysql:mysql /var/lib/mysql/
	chmod -R 755 /var/lib/mysql/

	if [ ! -f /var/lib/mysql/ibdata1 ]; then
		# cp /etc/mysql/my.cnf /usr/share/mysql/my-default.cnf
		mysql_install_db || true
		# mysqld --initialize-insecure --user=mysql || true
	fi

	if [ ${LOG_DEBUG} ]; then
		log_debug "Fix docker bug volume mapping for mysql";
	fi

	myisamchk -q -r /var/lib/mysql/mysql/proc || true

        systemctl enable mysql.service
	service mysql start

	if [ ! -f /var/lib/mysql/mysql_upgrade_info ]; then
		if mysqladmin --silent ping -u root | grep -q "mysqld is alive" ; then
			mysql_upgrade
		else
			mysql_upgrade --password=${MYSQL_SERVER_ROOT_PASSWORD};
		fi
	
		service mysql restart;
	fi


	if [ -n "$MYSQL_SERVER_ROOT_PASSWORD" ] && mysqladmin --silent ping -u root | grep -q "mysqld is alive" ; then
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY "$MYSQL_SERVER_ROOT_PASSWORD";
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF



		if [ "$MYSQL_SERVER_USER" != "root" ]; then
mysql "-p${MYSQL_SERVER_ROOT_PASSWORD}" <<EOF
CREATE USER IF NOT EXISTS "$MYSQL_SERVER_USER"@"localhost" IDENTIFIED WITH mysql_native_password BY "$MYSQL_SERVER_PASS";
GRANT ALL PRIVILEGES ON *.* TO "$MYSQL_SERVER_USER"@'localhost';
FLUSH PRIVILEGES;
EOF

		fi
	fi

	DEBIAN_SYS_MAINT_PASS=$(grep "password" /etc/mysql/debian.cnf | head -1 | sed 's/password\s*=\s*//' | tr -d '[[:space:]]');
	mysql_scalar_exec "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '${DEBIAN_SYS_MAINT_PASS}'"


	#mysql_scalar_exec "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost'" "opt_ignore_db_name";

else
	service mysql stop
        systemctl disable mysql.service
fi

mysql_check_connection;

DB_IS_EXIST=$(mysql_scalar_exec "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
DB_CHARACTER_SET_NAME=$(mysql_scalar_exec "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
DB_COLLATION_NAME=$(mysql_scalar_exec "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
DB_TABLES_COUNT=$(mysql_scalar_exec "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_SERVER_DB_NAME}'");

if [ -z ${DB_IS_EXIST} ]; then
	mysql_scalar_exec "CREATE DATABASE ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci" "opt_ignore_db_name";
	DB_CHARACTER_SET_NAME="utf8";
	DB_COLLATION_NAME="utf8_general_ci";
	DB_TABLES_COUNT=0;

fi

if [ ${DB_CHARACTER_SET_NAME} != "utf8" ]; then
	mysql_scalar_exec "ALTER DATABASE ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci";
fi

# change mysql config files
change_connections "default" "${APP_ROOT_DIR}/web.connections.config";
change_connections "teamlabsite" "${APP_ROOT_DIR}/web.connections.config";
change_connections "default" "${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config";
change_connections "default" "${APP_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config";
change_connections "default" "${APP_SERVICES_DIR}/MailAggregator/ASC.Mail.EmlDownloader.exe.config";
change_connections "default" "${APP_SERVICES_DIR}/MailWatchdog/ASC.Mail.Watchdog.Service.exe.config";
change_connections "default" "${APP_SERVICES_DIR}/MailCleaner/ASC.Mail.StorageCleaner.exe.config";
change_connections "default" "${APP_APISYSTEM_DIR}/Web.config";

sed "s!\"host\":.*,!\"host\":\"${MYSQL_SERVER_HOST}\",!" -i ${APP_SERVICES_DIR}/ASC.UrlShortener/config/config.json
sed "s!\"user\":.*,!\"user\":\"${MYSQL_SERVER_USER}\",!" -i ${APP_SERVICES_DIR}/ASC.UrlShortener/config/config.json
sed "s!\"password\":.*,!\"password\":\"${MYSQL_SERVER_PASS}\",!" -i ${APP_SERVICES_DIR}/ASC.UrlShortener/config/config.json
sed "s!\"database\":.*!\"database\":\"${MYSQL_SERVER_DB_NAME}\"!" -i ${APP_SERVICES_DIR}/ASC.UrlShortener/config/config.json

if [ "${DB_TABLES_COUNT}" -eq "0" ]; then
      	mysql_batch_exec ${APP_SQL_DIR}/onlyoffice.sql
       	mysql_batch_exec ${APP_SQL_DIR}/onlyoffice.data.sql
       	mysql_batch_exec ${APP_SQL_DIR}/onlyoffice.resources.sql
elif [ "${IS_UPDATE}" == "true" ]; then
	# update mysql db
	for i in $(ls ${APP_SQL_DIR}/onlyoffice.upgrade*); do
        	mysql_batch_exec ${i};
	done
fi


# setup HTTPS
if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
	cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common-ssl.conf.template ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	mkdir -p ${LOG_DIR}/nginx

	# configure nginx
	sed 's,{{SSL_CERTIFICATE_PATH}},'"${SSL_CERTIFICATE_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	sed 's,{{SSL_KEY_PATH}},'"${SSL_KEY_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	# if dhparam path is valid, add to the config, otherwise remove the option
	if [ ! -f ${SSL_DHPARAM_PATH} ]; then
		 sudo openssl dhparam -out dhparam.pem 2048
		 mv dhparam.pem ${SSL_DHPARAM_PATH};
	fi

	sed 's,{{SSL_DHPARAM_PATH}},'"${SSL_DHPARAM_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	if [ ! -f ${SSL_CERTIFICATE_PATH_PFX} ]; then
		openssl pkcs12 -export -out ${SSL_CERTIFICATE_PATH_PFX} -inkey ${SSL_KEY_PATH} -in ${SSL_CERTIFICATE_PATH} -password pass:${SSL_CERTIFICATE_PATH_PFX_PWD};
		chown onlyoffice:onlyoffice ${SSL_CERTIFICATE_PATH_PFX}
	fi

	# if dhparam path is valid, add to the config, otherwise remove the option
	if [ -r "${SSL_OCSP_CERTIFICATE_PATH}" ]; then
		sed 's,{{SSL_OCSP_CERTIFICATE_PATH}},'"${SSL_OCSP_CERTIFICATE_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/ssl_stapling/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
		sed '/ssl_stapling_verify/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
		sed '/ssl_trusted_certificate/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
		sed '/resolver/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
		sed '/resolver_timeout/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi


	sed 's,{{SSL_VERIFY_CLIENT}},'"${SSL_VERIFY_CLIENT}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	if [ -f "${CA_CERTIFICATES_PATH}" ]; then
		sed 's,{{CA_CERTIFICATES_PATH}},'"${CA_CERTIFICATES_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/{{CA_CERTIFICATES_PATH}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi

	if [ "${APP_HTTPS_HSTS_ENABLED}" == "true" ]; then
		sed 's/{{APP_HTTPS_HSTS_MAXAGE}}/'"${APP_HTTPS_HSTS_MAXAGE}"'/' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/{{APP_HTTPS_HSTS_MAXAGE}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi

	sed '/certificate"/s!\(value\s*=\s*\"\).*\"!\1'${SSL_CERTIFICATE_PATH_PFX}'\"!' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
	sed '/certificatePassword/s/\(value\s*=\s*\"\).*\"/\1'${SSL_CERTIFICATE_PATH_PFX_PWD}'\"/' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
	sed '/startTls/s/\(value\s*=\s*\"\).*\"/\1optional\"/' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config;

	sed '/mail\.default-api-scheme/s/\(value\s*=\s*\"\).*\"/\1https\"/' -i ${APP_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config;

else
	cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common.conf.template ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
fi


sed -i '1d' /etc/logrotate.d/nginx
sed '1 i\/var/log/nginx/*.log /var/log/onlyoffice/nginx.*.log {' -i /etc/logrotate.d/nginx

if [ ${DOCKER_APP_SUBNET} ]; then
	sed 's,{{DOCKER_APP_SUBNET}},'"${DOCKER_APP_SUBNET}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
else
	sed '/{{DOCKER_APP_SUBNET}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
fi

if [ ${APP_SERVICES_INTERNAL_HOST} ]; then
	sed "s/localhost/${APP_SERVICES_INTERNAL_HOST}/" -i ${NGINX_CONF_DIR}/includes/onlyoffice-communityserver-services.conf
fi

if [ "${DOCUMENT_SERVER_JWT_ENABLED}" == "true" ]; then
	sed '/files\.docservice\.secret/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_JWT_SECRET}'\"!' -i ${APP_ROOT_DIR}/web.appsettings.config
	sed '/files\.docservice\.secret.header/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_JWT_HEADER}'\"!' -i ${APP_ROOT_DIR}/web.appsettings.config
	sed '/files\.docservice\.secret/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_JWT_SECRET}'\"!' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
	sed '/files\.docservice\.secret.header/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_JWT_HEADER}'\"!' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
fi

if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ]; then

    cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-documentserver.conf.template ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-documentserver.conf;

    sed 's,{{DOCUMENT_SERVER_HOST_ADDR}},'"${DOCUMENT_SERVER_PROTOCOL}:\/\/${DOCUMENT_SERVER_HOST}"',' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-documentserver.conf;

    # change web.appsettings link to editor
    sed '/files\.docservice\.url\.internal/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/\"!' -i  ${APP_ROOT_DIR}/web.appsettings.config
    sed '/files\.docservice\.url\.public/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_API_URL}'\/\"!' -i ${APP_ROOT_DIR}/web.appsettings.config

    sed '/files\.docservice\.url\.internal/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/\"!' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
    sed '/files\.docservice\.url\.public/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_API_URL}'\/\"!' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config

    if [ -n "${DOCKER_APP_SUBNET}" ] && [ -n "${SERVER_HOST}" ]; then
        sed '/files\.docservice\.url\.portal/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${SERVER_HOST}'\"!' -i ${APP_ROOT_DIR}/web.appsettings.config
        sed '/files\.docservice\.url\.portal/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${SERVER_HOST}'\"!' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
    fi

fi

if [ "${MAIL_SERVER_ENABLED}" == "true" ]; then

    timeout=120;
    interval=10;

    while [ "$interval" -lt "$timeout" ] ; do
        interval=$((${interval} + 10));

        MAIL_SERVER_HOSTNAME=$(mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
            --port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
            --password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" -e "SELECT Comment from greylisting_whitelist where Source='SenderIP:${MAIL_SERVER_API_HOST}' limit 1;");
        if [[ "$?" -eq "0" ]] && [[ -n ${MAIL_SERVER_HOSTNAME} ]]; then
            break;
        fi
        
	sleep 10;

	if [ ${LOG_DEBUG} ]; then
		log_debug "Waiting MAIL SERVER DB...";
	fi

    done

    # change web.appsettings
    sed -r '/web\.hide-settings/s/,AdministrationPage//' -i ${APP_ROOT_DIR}/web.appsettings.config

    MYSQL_MAIL_SERVER_ID=$(mysql_scalar_exec "select id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");


    echo "MYSQL mail server id '${MYSQL_MAIL_SERVER_ID}'";

    SENDER_IP="";

	if check_ip_is_internal $DOCKER_APP_SUBNET $MAIL_SERVER_API_HOST; then
		SENDER_IP=$(hostname -i);
	elif [[ "$(dig +short myip.opendns.com @resolver1.opendns.com)" =~ $VALID_IP_ADDRESS_REGEX ]]; then
		SENDER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com);
        	log_debug "External ip $SENDER_IP is valid";
	else
		SENDER_IP=$(hostname -i);
	fi


        mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
            --port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
            --password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" \
	    -e "DELETE FROM greylisting_whitelist WHERE Comment='onlyoffice-community-server';";

        mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
            --port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
            --password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" \
            -e "REPLACE INTO greylisting_whitelist (Source, Comment, Disabled) VALUES (\"SenderIP:${SENDER_IP}\", 'onlyoffice-community-server', 0);";

    if [ -z ${MYSQL_MAIL_SERVER_ID} ]; then


        mysql_scalar_exec <<END
        ALTER TABLE mail_server_server CHANGE COLUMN connection_string connection_string TEXT NOT NULL AFTER mx_record;
        ALTER TABLE mail_server_domain ADD COLUMN date_checked DATETIME NOT NULL DEFAULT '1975-01-01 00:00:00' AFTER date_added;
        ALTER TABLE mail_server_domain ADD COLUMN is_verified TINYINT(1) UNSIGNED NOT NULL DEFAULT '0' AFTER date_checked;
END

        id1=$(mysql_scalar_exec "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'imap', '${MAIL_SERVER_HOSTNAME}', 143, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");
        if [ ${LOG_DEBUG} ]; then
            log_debug "id1 is '${id1}'";
        fi

        id2=$(mysql_scalar_exec "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'smtp', '${MAIL_SERVER_HOSTNAME}', 587, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");

        if [ ${LOG_DEBUG} ]; then
            log_debug "id2 is '${id2}'";
        fi
        
    else
        id1=$(mysql_scalar_exec "select imap_settings_id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");
        if [ ${LOG_DEBUG} ]; then
            log_debug "id1 is '${id1}'";
        fi

        id2=$(mysql_scalar_exec "select smtp_settings_id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");
        if [ ${LOG_DEBUG} ]; then
            log_debug "id2 is '${id2}'";
        fi

        mysql_scalar_exec <<END
        UPDATE mail_mailbox_server SET id_provider=-1, hostname='${MAIL_SERVER_HOSTNAME}' WHERE id in (${id1}, ${id2});
END
    fi

    interval=10;
    while [ "$interval" -lt "$timeout" ] ; do
        interval=$((${interval} + 10));

        MYSQL_MAIL_SERVER_ACCESS_TOKEN=$(mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
            --port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
            --password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" \
            -e "select access_token from api_keys where id=1;");
        if [[ "$?" -eq "0" ]] && [[ -n ${MYSQL_MAIL_SERVER_ACCESS_TOKEN} ]]; then
            break;
        fi
        sleep 10;
    done

    if [ ${LOG_DEBUG} ]; then
        echo "mysql mail server access token is ${MYSQL_MAIL_SERVER_ACCESS_TOKEN}";
    fi

    MAIL_SERVER_API_HOST_ADDRESS=${MAIL_SERVER_API_HOST};
    if [[ $MAIL_SERVER_DB_HOST == "onlyoffice-mail-server" ]]; then
    MAIL_SERVER_API_HOST_ADDRESS=${MAIL_SERVER_DB_HOST};
    fi

    mysql_scalar_exec "DELETE FROM mail_server_server;"
    mysql_scalar_exec "INSERT INTO mail_server_server (mx_record, connection_string, server_type, smtp_settings_id, imap_settings_id) \
                       VALUES ('${MAIL_SERVER_HOSTNAME}', '{\"DbConnection\" : \"Server=${MAIL_SERVER_DB_HOST};Database=${MAIL_SERVER_DB_NAME};User ID=${MAIL_SERVER_DB_USER};Password=${MAIL_SERVER_DB_PASS};Pooling=True;Character Set=utf8;AutoEnlist=false;SSL Mode=None;Connection Timeout=30;Maximum Pool Size=300;\", \"Api\":{\"Protocol\":\"http\", \"Server\":\"${MAIL_SERVER_API_HOST_ADDRESS}\", \"Port\":\"${MAIL_SERVER_API_PORT}\", \"Version\":\"v1\",\"Token\":\"${MYSQL_MAIL_SERVER_ACCESS_TOKEN}\"}}', 2, '${id2}', '${id1}');"
fi

if [ "${CONTROL_PANEL_ENABLED}" == "true" ]; then
        cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf.template ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf;
	sed 's,{{CONTROL_PANEL_HOST_ADDR}},'"${CONTROL_PANEL_PORT_80_TCP_ADDR}"',' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf;
	sed 's,{{SERVICE_SSO_AUTH_HOST_ADDR}},'"${SERVICE_SSO_AUTH_HOST_ADDR}"',' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf;

	# change web.appsettings link to controlpanel
	sed '/web\.controlpanel\.url/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/controlpanel\/\"/' -i  ${APP_ROOT_DIR}/web.appsettings.config;
	sed '/web\.controlpanel\.url/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/controlpanel\/\"/' -i ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config;

fi

if [ "${APP_MODE}" == "SERVER" ]; then


for serverID in $(seq 1 ${APP_MONOSERVE_COUNT});
do
	 if [ $serverID == 1 ]; then
                sed '/web.warmup.count/s/value=\"\S*\"/value=\"'${APP_MONOSERVE_COUNT}'\"/g' -i  ${APP_ROOT_DIR}/web.appsettings.config
                sed '/web.warmup.domain/s/value=\"\S*\"/value=\"localhost\/warmup\"/g' -i  ${APP_ROOT_DIR}/web.appsettings.config
                sed "/core.machinekey/s!value=\".*\"!value=\"${APP_CORE_MACHINEKEY}\"!g" -i  ${APP_ROOT_DIR}/web.appsettings.config
		sed "/core.machinekey/s!value=\".*\"!value=\"${APP_CORE_MACHINEKEY}\"!g" -i  ${APP_APISYSTEM_DIR}/Web.config
                sed "/core.machinekey/s!value=\".*\"!value=\"${APP_CORE_MACHINEKEY}\"!g" -i  ${APP_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.config
		sed "/core\.machinekey/s!\"core\.machinekey\".*!\"core\.machinekey\":\"${APP_CORE_MACHINEKEY}\",!" -i ${APP_SERVICES_DIR}/ASC.Socket.IO/config/config.json
		sed "s!machine_key\s*=.*!machine_key = ${APP_CORE_MACHINEKEY}!g" -i  ${APP_SERVICES_DIR}/TeamLabSvc/radicale.config
		sed "s!\"core\.machinekey\":.*,!\"core\.machinekey\":\"${APP_CORE_MACHINEKEY}\",!g" -i ${APP_SERVICES_DIR}/ASC.UrlShortener/config/config.json
                sed "/core.machinekey/s!value=\".*\"!value=\"${APP_CORE_MACHINEKEY}\"!g" -i  ${APP_SERVICES_DIR}/MailAggregator/ASC.Mail.EmlDownloader.exe.config
                sed "/core.machinekey/s!value=\".*\"!value=\"${APP_CORE_MACHINEKEY}\"!g" -i  ${APP_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config
		sed "/core.machinekey/s!value=\".*\"!value=\"${APP_CORE_MACHINEKEY}\"!g" -i  ${APP_SERVICES_DIR}/MailCleaner/ASC.Mail.StorageCleaner.exe.config

                continue;
        fi

	rm -rfd ${APP_ROOT_DIR}$serverID;

    if [ -d "${APP_ROOT_DIR}$serverID" ]; then
        rm -rfd ${APP_ROOT_DIR}$serverID;
    fi

	cp -R ${APP_ROOT_DIR} ${APP_ROOT_DIR}$serverID;
	chown -R onlyoffice:onlyoffice ${APP_ROOT_DIR}$serverID;

	sed '/web.warmup.count/s/value=\"\S*\"/value=\"'${APP_MONOSERVE_COUNT}'\"/g' -i  ${APP_ROOT_DIR}$serverID/web.appsettings.config
	sed '/web.warmup.domain/s/value=\"\S*\"/value=\"localhost\/warmup'${serverID}'\"/g' -i  ${APP_ROOT_DIR}$serverID/web.appsettings.config

        sed '/conversionPattern\s*value=\"%folder{LogDirectory}/s!web!web'${serverID}'!g' -i ${APP_ROOT_DIR}$serverID/web.log4net.config;


	cp ${APP_MONOSERVER_PATH} ${APP_MONOSERVER_PATH}$serverID;

	sed 's/monoserve/monoserve'${serverID}'/g' -i ${APP_MONOSERVER_PATH}$serverID;
	sed 's/onlyoffice\.socket/onlyoffice'${serverID}'\.socket/g' -i ${APP_MONOSERVER_PATH}$serverID;
	sed 's/\/etc\/hyperfastcgi\/onlyoffice/\/etc\/hyperfastcgi\/onlyoffice'${serverID}'/g' -i ${APP_MONOSERVER_PATH}$serverID;

	cp ${APP_HYPERFASTCGI_PATH} ${APP_HYPERFASTCGI_PATH}$serverID;

	sed 's,'${APP_ROOT_DIR}','${APP_ROOT_DIR}''${serverID}',g' -i ${APP_HYPERFASTCGI_PATH}$serverID;
	sed 's/onlyoffice\.socket/onlyoffice'${serverID}'\.socket/g' -i ${APP_HYPERFASTCGI_PATH}$serverID;


	sed '/onlyoffice'${serverID}'.socket/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
	sed '/onlyoffice'${serverID}'.socket/d' -i ${NGINX_CONF_DIR}/onlyoffice;

	grepLine="$(sed -n 's/onlyoffice\.socket/onlyoffice'${serverID}'.socket/p' ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice | tr -d '\t' | tr -d '\n')";

        sed '/fastcgi_backend\s*{/ a '"${grepLine}"'' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
        sed '/fastcgi_backend\s*{/ a '"${grepLine}"'' -i ${NGINX_CONF_DIR}/onlyoffice;

	sed '/monoserve'${serverID}'/d' -i ${APP_CRON_PATH};
	sed '/warmup'${serverID}'/d' -i ${APP_CRON_PATH};

        grepLine="$(sed -n 's/monoserve\s*restart/monoserve'${serverID}' restart/p' ${APP_CRON_PATH} | tr -d '\t' | tr -d '\n')";

        sed '$a\'"${grepLine}"'' -i ${APP_CRON_PATH};

        grepLine="$(sed -n 's/warmup1/warmup'${serverID}'/p' ${APP_CRON_PATH} | tr -d '\t' | tr -d '\n')";

        sed '$a\'"${grepLine}"'' -i ${APP_CRON_PATH};
done


fi

sed 's/{{APP_NIGNX_KEEPLIVE}}/'$((32*${APP_MONOSERVE_COUNT}))'/g' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;

bash -c 'echo "onlyoffice ALL=(ALL) NOPASSWD: /usr/sbin/service" | (EDITOR="tee -a" visudo)'


ping_onlyoffice() {
    timeout=6;
    interval=1;

    while [ "$interval" -le "$timeout" ] ; do
        interval=$((${interval} + 1));
        status_code=$(curl -LI $1 -o /dev/null -w '%{http_code}\n' -s);

        echo "ping monoserve get status_code: $status_code";

        if [ "$status_code" == "200" ]; then
            wget -qO- --retry-connrefused --no-check-certificate --waitretry=15 -t 0 --continue $1 &> /dev/null;
            break;
        fi

        sleep 5s;
    done

}

if [ "${REDIS_SERVER_EXTERNAL}" == "true" ]; then
	sed '/redis-cli/d' -i ${APP_CRON_PATH}

	service redis-server stop
        systemctl disable redis-server.service
else
        systemctl enable redis-server.service
	service redis-server start

	redis-cli config set save ""
	redis-cli config rewrite
	redis-cli flushall

	service redis-server stop
fi

if [ "${APP_MODE}" == "SERVICES" ]; then
        systemctl disable nginx.service
        systemctl disable monoserveApiSystem.service

	rm -f /lib/systemd/system.d/monoserveApiSystem.service

	for serverID in $(seq 1 ${APP_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
		fi

                systemctl stop monoserve$index
                systemctl disable monoserve$index.service

        	rm -f /lib/systemd/system/monoserve$index.service
	done

	sed '/monoserve/d' -i ${APP_CRON_PATH}
	sed '/warmup/d' -i ${APP_CRON_PATH}

else
        systemctl enable monoserveApiSystem.service

	for serverID in $(seq 1 ${APP_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
		fi

                systemctl enable monoserve$index.service
	done

	chown -R onlyoffice:onlyoffice /var/log/onlyoffice
	chown -R onlyoffice:onlyoffice ${APP_DIR}/DocumentServerData

        if [ "$(ls -alhd ${APP_DATA_DIR} | awk '{ print $3 }')" != "onlyoffice" ]; then
              chown -R onlyoffice:onlyoffice ${APP_DATA_DIR}
        fi

        if [ ! -d "$APP_INDEX_DIR" ]; then
		mysql_scalar_exec "TRUNCATE webstudio_index";
	fi

	mkdir -p "$LOG_DIR/Index"
	mkdir -p "$APP_INDEX_DIR"

        if [ "$(ls -alhd $APP_INDEX_DIR | awk '{ print $3 }')" != "elasticsearch" ]; then
		chown -R elasticsearch:elasticsearch "$APP_INDEX_DIR"
        fi

	chown -R elasticsearch:elasticsearch "$LOG_DIR/Index"
fi

systemctl stop onlyofficeRadicale
systemctl stop onlyofficeTelegram
systemctl stop onlyofficeSocketIO
systemctl stop onlyofficeThumb
systemctl stop onlyofficeFeed
systemctl stop onlyofficeIndex
systemctl stop onlyofficeJabber
systemctl stop onlyofficeMailAggregator
systemctl stop onlyofficeMailWatchdog
systemctl stop onlyofficeMailCleaner
systemctl stop onlyofficeNotify
systemctl stop onlyofficeBackup
systemctl stop onlyofficeStorageMigrate
systemctl stop onlyofficeStorageEncryption
systemctl stop onlyofficeUrlShortener

systemctl stop elasticsearch
systemctl stop redis-server
systemctl stop mysql
systemctl stop nginx

systemctl stop monoserveApiSystem.service
systemctl enable monoserveApiSystem.service

for serverID in $(seq 1 ${APP_MONOSERVE_COUNT});
do
	index=$serverID;

	if [ $index == 1 ]; then
		index="";
	fi


        systemctl stop monoserve$index.service
        systemctl enable monoserve$index.service
done

if [ "${APP_SERVICES_EXTERNAL}" == "true" ]; then
        systemctl disable onlyofficeRadicale.service
        systemctl disable onlyofficeTelegram.service
        systemctl disable onlyofficeSocketIO.service
        systemctl disable onlyofficeThumb.service
        systemctl disable onlyofficeFeed.service
        systemctl disable onlyofficeIndex.service
        systemctl disable onlyofficeJabber.service
        systemctl disable onlyofficeMailAggregator.service
        systemctl disable onlyofficeMailWatchdog.service
        systemctl disable onlyofficeMailCleaner.service
        systemctl disable onlyofficeNotify.service
        systemctl disable onlyofficeBackup.service
        systemctl disable onlyofficeStorageMigrate.service
        systemctl disable onlyofficeStorageEncryption.service

        systemctl disable onlyofficeUrlShortener.service

	rm -f /lib/systemd/system/onlyofficeRadicale.service
	rm -f /lib/systemd/system/onlyofficeTelegram.service
	rm -f /lib/systemd/system/onlyofficeSocketIO.service
	rm -f /lib/systemd/system/onlyofficeThumb.service
	rm -f /lib/systemd/system/onlyofficeFeed.service
	rm -f /lib/systemd/system/onlyofficeIndex.service
	rm -f /lib/systemd/system/onlyofficeJabber.service
	rm -f /lib/systemd/system/onlyofficeMailAggregator.service
	rm -f /lib/systemd/system/onlyofficeMailWatchdog.service
	rm -f /lib/systemd/system/onlyofficeMailCleaner.service
	rm -f /lib/systemd/system/onlyofficeNotify.service
	rm -f /lib/systemd/system/onlyofficeBackup.service
	rm -f /lib/systemd/system/onlyofficeStorageMigrate.sevice
	rm -f /lib/systemd/system/onlyofficeStorageEncryption.sevice
	rm -f /lib/systemd/system/onlyofficeUrlShortener.service

	sed '/onlyoffice/d' -i ${APP_CRON_PATH}
else
        systemctl enable onlyofficeRadicale.service
        systemctl enable onlyofficeTelegram.service
        systemctl enable onlyofficeSocketIO.service
        systemctl enable onlyofficeThumb.service
        systemctl enable onlyofficeFeed.service
        systemctl enable onlyofficeIndex.service
        systemctl enable onlyofficeJabber.service
        systemctl enable onlyofficeMailAggregator.service
        systemctl enable onlyofficeMailWatchdog.service
        systemctl enable onlyofficeMailCleaner.service
        systemctl enable onlyofficeNotify.service
        systemctl enable onlyofficeBackup.service
        systemctl enable onlyofficeStorageMigrate.service
        systemctl enable onlyofficeStorageEncryption.service
        systemctl enable onlyofficeUrlShortener.service
fi

if [ "${APP_MODE}" == "SERVER" ]; then
        mv ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice ${NGINX_CONF_DIR}/onlyoffice
        service nginx stop
        systemctl enable nginx.service
fi

PID=$(ps auxf | grep cron | grep -v grep | awk '{print $2}')

if [ ${ELASTICSEARCH_SERVER_HOST} ]; then
  service elasticsearch stop
  systemctl disable elasticsearch.service
else
  systemctl enable elasticsearch.service
fi

if [ -n "$PID" ]; then
  kill -9 $PID
fi

if [ "${DOCKER_ENABLED}" == "true" ]; then
   exec /lib/systemd/systemd
fi
