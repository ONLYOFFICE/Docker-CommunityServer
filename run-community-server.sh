#!/bin/bash

set -x

SERVER_HOST=${SERVER_HOST:-""};
ONLYOFFICE_DIR="/var/www/onlyoffice"
ONLYOFFICE_DATA_DIR="${ONLYOFFICE_DIR}/Data"
ONLYOFFICE_PRIVATE_DATA_DIR="${ONLYOFFICE_DATA_DIR}/.private"
ONLYOFFICE_SERVICES_DIR="${ONLYOFFICE_DIR}/Services"
ONLYOFFICE_SQL_DIR="${ONLYOFFICE_DIR}/Sql"
ONLYOFFICE_ROOT_DIR="${ONLYOFFICE_DIR}/WebStudio"
ONLYOFFICE_APISYSTEM_DIR="/var/www/onlyoffice/ApiSystem"
ONLYOFFICE_MONOSERVER_PATH="/etc/init.d/monoserve";
ONLYOFFICE_HYPERFASTCGI_PATH="/etc/hyperfastcgi/onlyoffice";
ONLYOFFICE_MONOSERVE_COUNT=1;
ONLYOFFICE_MODE=${ONLYOFFICE_MODE:-"SERVER"};
ONLYOFFICE_GOD_DIR="/etc/god/conf.d"
ONLYOFFICE_CRON_DIR="/etc/cron.d"
ONLYOFFICE_CRON_PATH="/etc/cron.d/onlyoffice"
DOCKER_ONLYOFFICE_SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -1);
DOCKER_CONTAINER_IP=$(ip addr show eth0 | awk '/inet / {gsub(/\/.*/,"",$2); print $2}' | head -1);
DOCKER_CONTAINER_NAME="onlyoffice-community-server";
DOCKER_ENABLED=${DOCKER_ENABLED:-true};
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NGINX_CONF_DIR="/etc/nginx/sites-enabled"
NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-$(grep processor /proc/cpuinfo | wc -l)};
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)};
SERVICE_SSO_AUTH_HOST_ADDR=${SERVICE_SSO_AUTH_HOST_ADDR:-${CONTROL_PANEL_PORT_80_TCP_ADDR}};

DEFAULT_ONLYOFFICE_CORE_MACHINEKEY="$(sudo sed -n '/"core.machinekey"/s!.*value\s*=\s*"\([^"]*\)".*!\1!p' ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config)";

ONLYOFFICE_CORE_MACHINEKEY=${ONLYOFFICE_CORE_MACHINEKEY:-${DEFAULT_ONLYOFFICE_CORE_MACHINEKEY}};

if [ ! -d "${ONLYOFFICE_PRIVATE_DATA_DIR}" ]; then
   mkdir -p ${ONLYOFFICE_PRIVATE_DATA_DIR};
fi

echo "${ONLYOFFICE_CORE_MACHINEKEY}" > ${ONLYOFFICE_PRIVATE_DATA_DIR}/machinekey

chmod -R 444 ${ONLYOFFICE_PRIVATE_DATA_DIR}

if cat /proc/1/cgroup | grep -qE "docker|lxc"; then
        DOCKER_ENABLED=true;
else
	DOCKER_ENABLED=false;
fi

if [ ! -d "$NGINX_CONF_DIR" ]; then
   mkdir -p $NGINX_CONF_DIR;
fi

if [ ! -d "${ONLYOFFICE_DIR}/DocumentServerData" ]; then
   mkdir -p ${ONLYOFFICE_DIR}/DocumentServerData;
fi

NGINX_ROOT_DIR="/etc/nginx"

VALID_IP_ADDRESS_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";


LOG_DEBUG="DEBUG";

LOG_DIR="/var/log/onlyoffice/"

ONLYOFFICE_HTTPS=${ONLYOFFICE_HTTPS:-false}

SSL_CERTIFICATES_DIR="${ONLYOFFICE_DATA_DIR}/certs"
SSL_CERTIFICATE_PATH=${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.crt}
SSL_KEY_PATH=${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.key}
SSL_CERTIFICATE_PATH_PFX=${SSL_CERTIFICATE_PATH_PFX:-${SSL_CERTIFICATES_DIR}/onlyoffice.pfx}
SSL_CERTIFICATE_PATH_PFX_PWD="onlyoffice";

SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}
SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
SSL_OCSP_CERTIFICATE_PATH=${SSL_OCSP_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/stapling.trusted.crt}
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-${SSL_CERTIFICATES_DIR}/ca.crt}
ONLYOFFICE_HTTPS_HSTS_ENABLED=${ONLYOFFICE_HTTPS_HSTS_ENABLED:-true}
ONLYOFFICE_HTTPS_HSTS_MAXAGE=${ONLYOFFICE_HTTPS_HSTS_MAXAG:-63072000}

SYSCONF_TEMPLATES_DIR="${DIR}/config"

mkdir -p ${SYSCONF_TEMPLATES_DIR}/nginx;

SYSCONF_TOOLS_DIR="${DIR}/assets/tools"

ONLYOFFICE_SERVICES_INTERNAL_HOST=${ONLYOFFICE_SERVICES_PORT_9865_TCP_ADDR:-${ONLYOFFICE_SERVICES_INTERNAL_HOST}}
ONLYOFFICE_SERVICES_EXTERNAL=false
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
MYSQL_SERVER_HOST=${MYSQL_SERVER_HOST:-"localhost"}
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
	   	[[ $(( ${INIP[$I]} & ${MASK[$I]} )) -ne ${NETWORK[$I]} ]] && exit 0;
	done
	
	echo "true"
}

check_partnerdata(){
	PARTNER_DATA_FILE="${ONLYOFFICE_DATA_DIR}/json-data.txt";

	if [ -f ${PARTNER_DATA_FILE} ]; then
		for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
		do
			index=$serverID;

			if [ $index == 1 ]; then
				index="";
			fi

			cp ${PARTNER_DATA_FILE} ${ONLYOFFICE_ROOT_DIR}${index}/App_Data/static/partnerdata/
		done
	fi
}


log_debug () {
  echo "onlyoffice: [Debug] $1"
}


check_partnerdata

re='^[0-9]+$'

if ! [[ ${ONLYOFFICE_MONOSERVE_COUNT} =~ $re ]] ; then
	echo "error: ONLYOFFICE_MONOSERVE_COUNT not a number";
	ONLYOFFICE_MONOSERVE_COUNT=2;
fi

# if [ "${ONLYOFFICE_MONOSERVE_COUNT}" -eq "2" ] ; then
#	KERNER_CPU=$(nproc);
	
#	if [ "${KERNER_CPU}" -gt "${ONLYOFFICE_MONOSERVE_COUNT}" ]; then
#		ONLYOFFICE_MONOSERVE_COUNT=${KERNER_CPU};
#	fi	
# fi

cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-nginx.conf.template ${NGINX_ROOT_DIR}/nginx.conf

sed 's/^worker_processes.*/'"worker_processes ${NGINX_WORKER_PROCESSES};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf
sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf


cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common-init.conf.template ${NGINX_CONF_DIR}/onlyoffice
rm -f ${NGINX_ROOT_DIR}/conf.d/*.conf

rsyslogd
service nginx restart

if [ ${ONLYOFFICE_SERVICES_INTERNAL_HOST} ]; then
	ONLYOFFICE_SERVICES_EXTERNAL=true;

	sed '/endpoint/s/http:\/\/localhost:9865\/teamlabJabber/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9865\/teamlabJabber/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9866\/teamlabSearcher/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9866\/teamlabSearcher/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9871\/teamlabNotify/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9871\/teamlabNotify/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9882\/teamlabBackup/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9882\/teamlabBackup/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config

        sed '/BoshPath/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':5280\/http-poll\/\"!' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

	sed '/<endpoint/s!\"netTcpBinding\"!\"basicHttpBinding\"!' -i ${ONLYOFFICE_ROOT_DIR}/Web.config;

	if [ ${LOG_DEBUG} ]; then
		log_debug "Change connections for ${1} then ${2}";
	fi

	if [ "${DOCKER_ENABLED}" == "true" ]; then
		while ! bash ${SYSCONF_TOOLS_DIR}/wait-for-it.sh ${ONLYOFFICE_SERVICES_INTERNAL_HOST}:9871 --quiet -s -- echo "ONLYOFFICE SERVICES is up"; do
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

if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ] && [ $DOCKER_ONLYOFFICE_SUBNET ] && [ -z "$SERVER_HOST" ]; then
	DOCUMENT_SERVER_HOST_IP=$(dig +short ${DOCUMENT_SERVER_HOST});

	if check_ip_is_internal $DOCKER_ONLYOFFICE_SUBNET $DOCUMENT_SERVER_HOST_IP; then
		_DOCKER_CONTAINER_IP=$(dig +short ${DOCKER_CONTAINER_NAME});

		if [ "${DOCKER_CONTAINER_IP}" == "${_DOCKER_CONTAINER_IP}" ]; then
			SERVER_HOST=${DOCKER_CONTAINER_NAME};
		else
			SERVER_HOST=${DOCKER_CONTAINER_IP};
		fi
	fi
fi


if [ ${MYSQL_SERVER_HOST} != "localhost" ]; then
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
        sed 's/<add\s*host="localhost"\s*cachePort="6379"\s*\/>/<add host="'${REDIS_SERVER_HOST}'" cachePort="'${REDIS_SERVER_CACHEPORT}'" \/>/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
        sed 's/<redisCacheClient\s*ssl="false"\s*connectTimeout="5000"\s*database="0"\s*password="">/<redisCacheClient ssl="'${REDIS_SERVER_SSL}'" connectTimeout="'${REDIS_SERVER_CONNECT_TIMEOUT}'" database="'${REDIS_SERVER_DATABASE}'" password="'${REDIS_SERVER_PASSWORD}'">/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config

        sed 's/<add\s*host="localhost"\s*cachePort="6379"\s*\/>/<add host="'${REDIS_SERVER_HOST}'" cachePort="'${REDIS_SERVER_CACHEPORT}'" \/>/' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config;
        sed 's/<redisCacheClient\s*ssl="false"\s*connectTimeout="5000"\s*database="0"\s*password="">/<redisCacheClient ssl="'${REDIS_SERVER_SSL}'" connectTimeout="'${REDIS_SERVER_CONNECT_TIMEOUT}'" database="'${REDIS_SERVER_DATABASE}'" password="'${REDIS_SERVER_PASSWORD}'">/' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config;

        REDIS_SERVER_EXTERNAL=true;
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
	sed '/'${1}'/s/\(connectionString\s*=\s*\"\)[^\"]*\"/\1Server='${MYSQL_SERVER_HOST}';Port='${MYSQL_SERVER_PORT}';Database='${MYSQL_SERVER_DB_NAME}';User ID='${MYSQL_SERVER_USER}';Password='${MYSQL_SERVER_PASS}';Pooling=true;Character Set=utf8;AutoEnlist=false\"/' -i ${2}
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
SET Password=PASSWORD("$MYSQL_SERVER_ROOT_PASSWORD");
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
fi

mysql_check_connection;

DB_IS_EXIST=$(mysql_scalar_exec "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
DB_CHARACTER_SET_NAME=$(mysql_list_exec "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
DB_COLLATION_NAME=$(mysql_list_exec "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
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

if [ "${DB_TABLES_COUNT}" -eq "0" ]; then
      	mysql_batch_exec ${ONLYOFFICE_SQL_DIR}/onlyoffice.sql
       	mysql_batch_exec ${ONLYOFFICE_SQL_DIR}/onlyoffice.data.sql
       	mysql_batch_exec ${ONLYOFFICE_SQL_DIR}/onlyoffice.resources.sql
fi

# change mysql config files
change_connections "default" "${ONLYOFFICE_ROOT_DIR}/web.connections.config";
change_connections "teamlabsite" "${ONLYOFFICE_ROOT_DIR}/web.connections.config";
change_connections "default" "${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config";
change_connections "default" "${ONLYOFFICE_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config";
change_connections "default" "${ONLYOFFICE_SERVICES_DIR}/MailAggregator/ASC.Mail.EmlDownloader.exe.config";
change_connections "default" "${ONLYOFFICE_SERVICES_DIR}/MailWatchdog/ASC.Mail.Watchdog.Service.exe.config";
change_connections "default" "${ONLYOFFICE_APISYSTEM_DIR}/Web.config";


# update mysql db
for i in $(ls ${ONLYOFFICE_SQL_DIR}/onlyoffice.upgrade*); do
        mysql_batch_exec ${i};
done


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

	if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
		sed 's/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/'"${ONLYOFFICE_HTTPS_HSTS_MAXAGE}"'/' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi

	sed '/certificate"/s!\(value\s*=\s*\"\).*\"!\1'${SSL_CERTIFICATE_PATH_PFX}'\"!' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config
	sed '/certificatePassword/s/\(value\s*=\s*\"\).*\"/\1'${SSL_CERTIFICATE_PATH_PFX_PWD}'\"/' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config
	sed '/startTls/s/\(value\s*=\s*\"\).*\"/\1optional\"/' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config;

	sed '/mail\.default-api-scheme/s/\(value\s*=\s*\"\).*\"/\1https\"/' -i ${ONLYOFFICE_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config;

else
	cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-common.conf.template ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
fi


sed -i '1d' /etc/logrotate.d/nginx
sed '1 i\/var/log/nginx/*.log /var/log/onlyoffice/nginx.*.log {' -i /etc/logrotate.d/nginx

if [ ${DOCKER_ONLYOFFICE_SUBNET} ]; then
	sed 's,{{DOCKER_ONLYOFFICE_SUBNET}},'"${DOCKER_ONLYOFFICE_SUBNET}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
else
	sed '/{{DOCKER_ONLYOFFICE_SUBNET}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
fi

if [ ${ONLYOFFICE_SERVICES_INTERNAL_HOST} ]; then
	sed "s/localhost/${ONLYOFFICE_SERVICES_INTERNAL_HOST}/" -i ${NGINX_CONF_DIR}/includes/onlyoffice-communityserver-services.conf
fi


if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ]; then

    cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-documentserver.conf.template ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-documentserver.conf;

    sed 's,{{DOCUMENT_SERVER_HOST_ADDR}},'"${DOCUMENT_SERVER_PROTOCOL}:\/\/${DOCUMENT_SERVER_HOST}"',' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-documentserver.conf;

    # change web.appsettings link to editor
    sed '/files\.docservice\.url\.internal/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/\"!' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    sed '/files\.docservice\.url\.public/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_API_URL}'\/\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

    if [ "${DOCUMENT_SERVER_JWT_ENABLED}" == "true" ]; then
        sed '/files\.docservice\.secret/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_JWT_SECRET}'\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        sed '/files\.docservice\.secret.header/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_JWT_HEADER}'\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    fi

    if [ -n "${DOCKER_ONLYOFFICE_SUBNET}" ] && [ -n "${SERVER_HOST}" ]; then
        sed '/files\.docservice\.url\.portal/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${SERVER_HOST}'\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
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
        if [[ "$?" -eq "0" ]]; then
            break;
        fi
        
	sleep 10;

	if [ ${LOG_DEBUG} ]; then
		log_debug "Waiting MAIL SERVER DB...";
	fi

    done

    # change web.appsettings
    sed -r '/web\.hide-settings/s/,AdministrationPage//' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

    MYSQL_MAIL_SERVER_ID=$(mysql_scalar_exec "select id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");


    echo "MYSQL mail server id '${MYSQL_MAIL_SERVER_ID}'";

    SENDER_IP="";

	if check_ip_is_internal $DOCKER_ONLYOFFICE_SUBNET $MAIL_SERVER_API_HOST; then
		SENDER_IP=$(hostname -i);
	elif [[ "$(dig +short myip.opendns.com @resolver1.opendns.com)" =~ $VALID_IP_ADDRESS_REGEX ]]; then
		SENDER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com);
        	log_debug "External ip $EXTERNAL_IP is valid";
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
        if [[ "$?" -eq "0" ]]; then
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
                       VALUES ('${MAIL_SERVER_HOSTNAME}', '{\"DbConnection\" : \"Server=${MAIL_SERVER_DB_HOST};Database=${MAIL_SERVER_DB_NAME};User ID=${MAIL_SERVER_DB_USER};Password=${MAIL_SERVER_DB_PASS};Pooling=True;Character Set=utf8;AutoEnlist=false\", \"Api\":{\"Protocol\":\"http\", \"Server\":\"${MAIL_SERVER_API_HOST_ADDRESS}\", \"Port\":\"${MAIL_SERVER_API_PORT}\", \"Version\":\"v1\",\"Token\":\"${MYSQL_MAIL_SERVER_ACCESS_TOKEN}\"}}', 2, '${id2}', '${id1}');"
fi

if [ "${CONTROL_PANEL_ENABLED}" == "true" ]; then
        cp ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf.template ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf;
	sed 's,{{CONTROL_PANEL_HOST_ADDR}},'"${CONTROL_PANEL_PORT_80_TCP_ADDR}"',' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf;
	sed 's,{{SERVICE_SSO_AUTH_HOST_ADDR}},'"${SERVICE_SSO_AUTH_HOST_ADDR}"',' -i ${NGINX_ROOT_DIR}/includes/onlyoffice-communityserver-proxy-to-controlpanel.conf;

	# change web.appsettings link to controlpanel
	sed '/web\.controlpanel\.url/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/controlpanel\/\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config;
	sed '/web\.controlpanel\.url/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/controlpanel\/\"/' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config;

fi

if [ "${ONLYOFFICE_MODE}" == "SERVER" ]; then


for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
do
	 if [ $serverID == 1 ]; then
                sed '/web.warmup.count/s/value=\"\S*\"/value=\"'${ONLYOFFICE_MONOSERVE_COUNT}'\"/g' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
                sed '/web.warmup.domain/s/value=\"\S*\"/value=\"localhost\/warmup\"/g' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
                sed "/core.machinekey/s!value=\".*\"!value=\"${ONLYOFFICE_CORE_MACHINEKEY}\"!g" -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
				sed "/core.machinekey/s!value=\".*\"!value=\"${ONLYOFFICE_CORE_MACHINEKEY}\"!g" -i  ${ONLYOFFICE_APISYSTEM_DIR}/Web.config
                sed "/core.machinekey/s!value=\".*\"!value=\"${ONLYOFFICE_CORE_MACHINEKEY}\"!g" -i  ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config
                sed "/core\.machinekey/s!\"core\.machinekey\".*!\"core\.machinekey\":\"${ONLYOFFICE_CORE_MACHINEKEY}\",!" -i ${ONLYOFFICE_SERVICES_DIR}/ASC.Socket.IO/config/config.json
                sed "/core.machinekey/s!value=\".*\"!value=\"${ONLYOFFICE_CORE_MACHINEKEY}\"!g" -i  ${ONLYOFFICE_SERVICES_DIR}/MailAggregator/ASC.Mail.EmlDownloader.exe.config
                sed "/core.machinekey/s!value=\".*\"!value=\"${ONLYOFFICE_CORE_MACHINEKEY}\"!g" -i  ${ONLYOFFICE_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config

                continue;
        fi

	rm -rfd ${ONLYOFFICE_ROOT_DIR}$serverID;

    if [ -d "${ONLYOFFICE_ROOT_DIR}$serverID" ]; then
        rm -rfd ${ONLYOFFICE_ROOT_DIR}$serverID;
    fi

	cp -R ${ONLYOFFICE_ROOT_DIR} ${ONLYOFFICE_ROOT_DIR}$serverID;
	chown -R onlyoffice:onlyoffice ${ONLYOFFICE_ROOT_DIR}$serverID;

	sed '/web.warmup.count/s/value=\"\S*\"/value=\"'${ONLYOFFICE_MONOSERVE_COUNT}'\"/g' -i  ${ONLYOFFICE_ROOT_DIR}$serverID/web.appsettings.config
	sed '/web.warmup.domain/s/value=\"\S*\"/value=\"localhost\/warmup'${serverID}'\"/g' -i  ${ONLYOFFICE_ROOT_DIR}$serverID/web.appsettings.config

        sed "/core.machinekey/s!value=\".*\"!value=\"${ONLYOFFICE_CORE_MACHINEKEY}\"!g" -i  ${ONLYOFFICE_ROOT_DIR}$serverID/web.appsettings.config
     
        sed '/conversionPattern\s*value=\"%folder{LogDirectory}/s!web!web'${serverID}'!g' -i ${ONLYOFFICE_ROOT_DIR}$serverID/web.log4net.config;


	cp ${ONLYOFFICE_MONOSERVER_PATH} ${ONLYOFFICE_MONOSERVER_PATH}$serverID;

	sed 's/monoserve/monoserve'${serverID}'/g' -i ${ONLYOFFICE_MONOSERVER_PATH}$serverID;
	sed 's/onlyoffice\.socket/onlyoffice'${serverID}'\.socket/g' -i ${ONLYOFFICE_MONOSERVER_PATH}$serverID;
	sed 's/\/etc\/hyperfastcgi\/onlyoffice/\/etc\/hyperfastcgi\/onlyoffice'${serverID}'/g' -i ${ONLYOFFICE_MONOSERVER_PATH}$serverID;

	cp ${ONLYOFFICE_HYPERFASTCGI_PATH} ${ONLYOFFICE_HYPERFASTCGI_PATH}$serverID;

	sed 's,'${ONLYOFFICE_ROOT_DIR}','${ONLYOFFICE_ROOT_DIR}''${serverID}',g' -i ${ONLYOFFICE_HYPERFASTCGI_PATH}$serverID;
	sed 's/onlyoffice\.socket/onlyoffice'${serverID}'\.socket/g' -i ${ONLYOFFICE_HYPERFASTCGI_PATH}$serverID;

	cp ${ONLYOFFICE_GOD_DIR}/monoserve.god ${ONLYOFFICE_GOD_DIR}/monoserve$serverID.god;
	sed 's/onlyoffice\.socket/onlyoffice'${serverID}'\.socket/g' -i ${ONLYOFFICE_GOD_DIR}/monoserve$serverID.god;
	sed 's/monoserve/monoserve'${serverID}'/g' -i ${ONLYOFFICE_GOD_DIR}/monoserve$serverID.god;

	sed '/onlyoffice'${serverID}'.socket/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
	sed '/onlyoffice'${serverID}'.socket/d' -i ${NGINX_CONF_DIR}/onlyoffice;

	grepLine="$(sed -n 's/onlyoffice\.socket/onlyoffice'${serverID}'.socket/p' ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice | tr -d '\t' | tr -d '\n')";

        sed '/fastcgi_backend\s*{/ a '"${grepLine}"'' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
        sed '/fastcgi_backend\s*{/ a '"${grepLine}"'' -i ${NGINX_CONF_DIR}/onlyoffice;

	sed '/monoserve'${serverID}'/d' -i ${ONLYOFFICE_CRON_PATH};
	sed '/warmup'${serverID}'/d' -i ${ONLYOFFICE_CRON_PATH};

        grepLine="$(sed -n 's/monoserve\s*restart/monoserve'${serverID}' restart/p' ${ONLYOFFICE_CRON_PATH} | tr -d '\t' | tr -d '\n')";

        sed '$a\'"${grepLine}"'' -i ${ONLYOFFICE_CRON_PATH};

        grepLine="$(sed -n 's/warmup1/warmup'${serverID}'/p' ${ONLYOFFICE_CRON_PATH} | tr -d '\t' | tr -d '\n')";

        sed '$a\'"${grepLine}"'' -i ${ONLYOFFICE_CRON_PATH};
done


fi

sed 's/{{ONLYOFFICE_NIGNX_KEEPLIVE}}/'$((32*${ONLYOFFICE_MONOSERVE_COUNT}))'/g' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;

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
	rm -f "${ONLYOFFICE_GOD_DIR}"/redis.god;
	sed '/redis-cli/d' -i ${ONLYOFFICE_CRON_PATH}

	service redis-server stop
else
	service redis-server start
fi

if [ "${MYSQL_SERVER_EXTERNAL}" == "true" ]; then
	rm -f "${ONLYOFFICE_GOD_DIR}"/mysql.god;
fi


if [ "${ONLYOFFICE_MODE}" == "SERVICES" ]; then
	service nginx stop

	rm -f "${ONLYOFFICE_GOD_DIR}"/nginx.god;
	rm -f "${ONLYOFFICE_GOD_DIR}"/monoserveApiSystem.god;

	service monoserveApiSystem stop

	rm -f /etc/init.d/monoserveApiSystem

	for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
		fi

	rm -f "${ONLYOFFICE_GOD_DIR}"/monoserve$index.god;

        service monoserve$index stop

	rm -f /etc/init.d/monoserve$index

	done

	sed '/monoserve/d' -i ${ONLYOFFICE_CRON_PATH}
	sed '/warmup/d' -i ${ONLYOFFICE_CRON_PATH}

else
	if [ ${LOG_DEBUG} ]; then
		echo "fix docker bug volume mapping for onlyoffice";
	fi

	chown -R onlyoffice:onlyoffice /var/log/onlyoffice
	chown -R onlyoffice:onlyoffice ${ONLYOFFICE_DIR}/DocumentServerData

        if [ "$(ls -alhd ${ONLYOFFICE_DATA_DIR} | awk '{ print $3 }')" != "onlyoffice" ]; then
              chown -R onlyoffice:onlyoffice ${ONLYOFFICE_DATA_DIR}
        fi

	mkdir -p "$LOG_DIR/Index"
	mkdir -p "$ONLYOFFICE_DATA_DIR/Index"

        if [ "$(ls -alhd $ONLYOFFICE_DATA_DIR/Index | awk '{ print $3 }')" != "elasticsearch" ]; then
		chown -R elasticsearch:elasticsearch "$ONLYOFFICE_DATA_DIR/Index"
        fi

	chown -R elasticsearch:elasticsearch "$LOG_DIR/Index"


	for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
		fi

		service monoserve$index restart

#                (ping_onlyoffice "http://localhost/warmup${index}/auth.aspx") &
	done

	service monoserveApiSystem restart
fi

if [ "${ONLYOFFICE_SERVICES_EXTERNAL}" == "true" ]; then
	rm -f "${ONLYOFFICE_GOD_DIR}"/onlyoffice.god;
	rm -f "${ONLYOFFICE_GOD_DIR}"/elasticsearch.god;
	rm -f "${ONLYOFFICE_GOD_DIR}"/redis.god;
	rm -f "${ONLYOFFICE_GOD_DIR}"/mail.god;


	service onlyofficeRadicale stop
	service onlyofficeFeed stop
	service onlyofficeIndex stop
	service onlyofficeJabber stop
	service onlyofficeMailAggregator stop
	service onlyofficeMailWatchdog stop
	service onlyofficeNotify stop
	service onlyofficeBackup stop
	service onlyofficeAutoreply stop
	service onlyofficeStorageMigrate stop
	service elasticsearch stop


	rm -f /etc/init.d/elasticsearch
	rm -f /etc/init.d/onlyofficeRadicale
	rm -f /etc/init.d/onlyofficeFeed
	rm -f /etc/init.d/onlyofficeIndex
	rm -f /etc/init.d/onlyofficeJabber
	rm -f /etc/init.d/onlyofficeMailAggregator
	rm -f /etc/init.d/onlyofficeMailWatchdog
	rm -f /etc/init.d/onlyofficeNotify
	rm -f /etc/init.d/onlyofficeBackup
	rm -f /etc/init.d/onlyofficeAutoreply
	rm -f /etc/init.d/onlyofficeStorageMigrate

	sed '/onlyoffice/d' -i ${ONLYOFFICE_CRON_PATH}

else

	service onlyofficeRadicale restart
	service onlyofficeSocketIO restart
	service onlyofficeThumb restart
	service onlyofficeFeed restart
	service onlyofficeIndex restart
	service onlyofficeJabber restart
	service onlyofficeMailAggregator restart
	service onlyofficeMailWatchdog restart
	service onlyofficeNotify restart
	service onlyofficeBackup restart
 	service onlyofficeAutoreply stop
	service onlyofficeHealthCheck stop
	service onlyofficeStorageMigrate restart
	service elasticsearch restart
fi

service god restart

if [ "${ONLYOFFICE_MODE}" == "SERVER" ]; then

#        wait

        mv ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice ${NGINX_CONF_DIR}/onlyoffice

        service nginx reload

        log_debug "reload nginx config";
        log_debug "FINISH";

fi

PID=$(ps auxf | grep cron | grep -v grep | awk '{print $2}')


if [ -n "$PID" ]; then
  kill -9 $PID
fi

cron

if [ "${DOCKER_ENABLED}" == "true" ]; then
   exec tail -f /dev/null
fi
