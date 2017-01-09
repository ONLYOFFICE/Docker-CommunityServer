#!/bin/bash

SERVER_HOST="";
ONLYOFFICE_DIR="/var/www/onlyoffice"
ONLYOFFICE_DATA_DIR="${ONLYOFFICE_DIR}/Data"
ONLYOFFICE_SERVICES_DIR="${ONLYOFFICE_DIR}/Services"
ONLYOFFICE_SQL_DIR="${ONLYOFFICE_DIR}/Sql"
ONLYOFFICE_ROOT_DIR="${ONLYOFFICE_DIR}/WebStudio"
ONLYOFFICE_ROOT_DIR2="${ONLYOFFICE_DIR}/WebStudio2"
ONLYOFFICE_APISYSTEM_DIR="/var/www/onlyoffice/ApiSystem"
ONLYOFFICE_MONOSERVER_PATH="/etc/init.d/monoserve";
ONLYOFFICE_HYPERFASTCGI_PATH="/etc/hyperfastcgi/onlyoffice";
ONLYOFFICE_MONOSERVE_COUNT=${ONLYOFFICE_MONOSERVE_COUNT:-2};
ONLYOFFICE_MODE=${ONLYOFFICE_MODE:-"SERVER"};
ONLYOFFICE_GOD_DIR="/etc/god/conf.d"
ONLYOFFICE_CRON_PATH="/etc/cron.d/onlyoffice"
DOCKER_ONLYOFFICE_SUBNET=${DOCKER_ONLYOFFICE_SUBNET:-""};

NGINX_CONF_DIR="/etc/nginx/sites-enabled"
NGINX_ROOT_DIR="/etc/nginx"

VALID_IP_ADDRESS_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";


LOG_DEBUG="DEBUG";

LOG_DIR="/var/log/onlyoffice/"

ONLYOFFICE_HTTPS=${ONLYOFFICE_HTTPS:-false}

SSL_CERTIFICATES_DIR="${ONLYOFFICE_DATA_DIR}/certs"
SSL_CERTIFICATE_PATH=${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.crt}
SSL_KEY_PATH=${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.key}
SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}
SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
ONLYOFFICE_HTTPS_HSTS_ENABLED=${ONLYOFFICE_HTTPS_HSTS_ENABLED:-true}
ONLYOFFICE_HTTPS_HSTS_MAXAGE=${ONLYOFFICE_HTTPS_HSTS_MAXAG:-31536000}
SYSCONF_TEMPLATES_DIR="/app/onlyoffice/setup/config"
SYSCONF_TOOLS_DIR="/app/onlyoffice/setup/assets/tools"

ONLYOFFICE_SERVICES_INTERNAL_HOST=${ONLYOFFICE_SERVICES_PORT_9865_TCP_ADDR:-${ONLYOFFICE_SERVICES_INTERNAL_HOST}}
ONLYOFFICE_SERVICES_EXTERNAL=false
DOCUMENT_SERVER_ENABLED=false

DOCUMENT_SERVER_HOST=${DOCUMENT_SERVER_HOST:-""};
DOCUMENT_SERVER_PROTOCOL=${DOCUMENT_SERVER_PROTOCOL:-"http"};
DOCUMENT_SERVER_API_URL="\/OfficeWeb\/apps\/api\/documents\/api\.js";

CONTROL_PANEL_ENABLED=false
MAIL_SERVER_ENABLED=false
EXTERNAL_IP=${EXTERNAL_IP:-$(dig +short myip.opendns.com @resolver1.opendns.com)};

MYSQL_SERVER_HOST=${MYSQL_SERVER_HOST:-"localhost"}
MYSQL_SERVER_PORT=${MYSQL_SERVER_PORT:-"3306"}
MYSQL_SERVER_DB_NAME=${MYSQL_SERVER_DB_NAME:-"onlyoffice"}
MYSQL_SERVER_USER=${MYSQL_SERVER_USER:-"root"}
MYSQL_SERVER_PASS=${MYSQL_SERVER_PASS:-""}
MYSQL_SERVER_EXTERNAL=false;

mkdir -p "${SSL_CERTIFICATES_DIR}"

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


cp ${SYSCONF_TEMPLATES_DIR}/nginx/nginx.conf ${NGINX_ROOT_DIR}/nginx.conf
cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice-init ${NGINX_CONF_DIR}/onlyoffice
rm -f /etc/nginx/conf.d/*.conf

rsyslogd 
service nginx restart

if [ ${ONLYOFFICE_SERVICES_INTERNAL_HOST} ]; then
	ONLYOFFICE_SERVICES_EXTERNAL=true;

	sed '/endpoint/s/http:\/\/localhost:9865\/teamlabJabber/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9865\/teamlabJabber/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9888\/teamlabSignalr/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9888\/teamlabSignalr/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9866\/teamlabSearcher/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9866\/teamlabSearcher/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9871\/teamlabNotify/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9871\/teamlabNotify/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config
	sed '/endpoint/s/http:\/\/localhost:9882\/teamlabBackup/http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':9882\/teamlabBackup/' -i ${ONLYOFFICE_ROOT_DIR}/Web.config

        sed '/BoshPath/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${ONLYOFFICE_SERVICES_INTERNAL_HOST}':5280\/http-poll\/\"!' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

	sed '/<endpoint/s!\"netTcpBinding\"!\"basicHttpBinding\"!' -i ${ONLYOFFICE_ROOT_DIR}/Web.config;

	if [ ${LOG_DEBUG} ]; then
		echo "change connections for ${1} then ${2}";
	fi

	while ! bash ${SYSCONF_TOOLS_DIR}/wait-for-it.sh ${ONLYOFFICE_SERVICES_INTERNAL_HOST}:9871 --quiet -s -- echo "ONLYOFFICE SERVICES is up"; do
    		sleep 1
	done

fi

if [ ${DOCUMENT_SERVER_HOST} ]; then
	DOCUMENT_SERVER_ENABLED=true;
	DOCUMENT_SERVER_API_URL="${DOCUMENT_SERVER_PROTOCOL}://${DOCUMENT_SERVER_HOST}${DOCUMENT_SERVER_API_URL}";
elif [ ${DOCUMENT_SERVER_PORT_80_TCP_ADDR} ]; then
	DOCUMENT_SERVER_ENABLED=true;
	DOCUMENT_SERVER_HOST=${DOCUMENT_SERVER_PORT_80_TCP_ADDR};
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
		echo "MYSQL_SERVER_HOST: ${MYSQL_SERVER_HOST}";
		echo "MYSQL_SERVER_PORT: ${MYSQL_SERVER_PORT}";
		echo "MYSQL_SERVER_DB_NAME: ${MYSQL_SERVER_DB_NAME}";
		echo "MYSQL_SERVER_USER: ${MYSQL_SERVER_USER}";
		echo "MYSQL_SERVER_PASS: ${MYSQL_SERVER_PASS}";
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
        	elif [[ $EXTERNAL_IP =~ $VALID_IP_ADDRESS_REGEX ]]; then
			MAIL_SERVER_API_HOST=${EXTERNAL_IP};
	   	else
		    echo "MAIL_SERVER_API_HOST is empty";
	            exit 502;
       		fi
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
		echo "mysq check connection for ${MYSQL_SERVER_HOST}";
	fi
	

	while ! mysqladmin ping -h ${MYSQL_SERVER_HOST} -P ${MYSQL_SERVER_PORT} -u ${MYSQL_SERVER_USER} --password=${MYSQL_SERVER_PASS} --silent; do
    		sleep 1
	done
}

change_connections(){
	if [ ${LOG_DEBUG} ]; then
		echo "change connections for ${1} then ${2}";
	fi

	sed '/'${1}'/s/\(connectionString\s*=\s*\"\)[^\"]*\"/\1Server='${MYSQL_SERVER_HOST}';Port='${MYSQL_SERVER_PORT}';Database='${MYSQL_SERVER_DB_NAME}';User ID='${MYSQL_SERVER_USER}';Password='${MYSQL_SERVER_PASS}';Pooling=true;Character Set=utf8;AutoEnlist=false\"/' -i ${2}
}

if [ "${MYSQL_SERVER_EXTERNAL}" == "true" ]; then

	mysql_check_connection;

	# create db if not exist
	# DB_INFO=$(mysql_list_exec "SELECT SCHEMA_NAME, DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
	# echo ${DB_INFO};
	DB_IS_EXIST=$(mysql_scalar_exec "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
	DB_CHARACTER_SET_NAME=$(mysql_list_exec "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");
	DB_COLLATION_NAME=$(mysql_list_exec "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_SERVER_DB_NAME}'" "opt_ignore_db_name");

	#	if [ ${DB_INFO[@]} -nq 0 ]; then
	#		DB_IS_EXIST="1";
	#		DB_CHARACTER_SET_NAME=${#DB_INFO[1]};
	#		DB_COLLATION_NAME=${#DB_INFO[2]};
	#	fi

	DB_TABLES_COUNT=$(mysql_scalar_exec "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_SERVER_DB_NAME}'");

	if [ ${LOG_DEBUG} ]; then
		echo "DB_IS_EXIST: ${DB_IS_EXIST}";
		echo "DB_CHARACTER_SET_NAME: ${DB_CHARACTER_SET_NAME}";
		echo "DB_COLLATION_NAME: ${DB_COLLATION_NAME}";
		echo "DB_TABLES_COUNT: ${DB_TABLES_COUNT}";
	fi

	if [ -z ${DB_IS_EXIST} ]; then
		mysql_scalar_exec "CREATE DATABASE ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci" "opt_ignore_db_name";
		DB_CHARACTER_SET_NAME="utf8";	
		DB_COLLATION_NAME="utf8_general_ci";

		if [ ${LOG_DEBUG} ]; then
			echo "create db ${MYSQL_SERVER_DB_NAME}";
		fi
	fi

	if [ ${DB_CHARACTER_SET_NAME} != "utf8" ]; then
		mysql_scalar_exec "ALTER DATABASE ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci";

		if [ ${LOG_DEBUG} ]; then
			echo "change characted set name ${MYSQL_SERVER_DB_NAME}";
		fi

	fi

	if [ "${DB_TABLES_COUNT}" -eq "0" ]; then

		if [ ${LOG_DEBUG} ]; then
			echo "run filling tables...";
		fi

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
	change_connections "core" "${ONLYOFFICE_APISYSTEM_DIR}/Web.config";
	sed 's!\(sql_host\s*=\s*\)\S*!\1'${MYSQL_SERVER_HOST}'!' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/sphinx-min.conf.in;
	sed 's!\(sql_pass\s*=\s*\)\S*!\1'${MYSQL_SERVER_PASS}'!' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/sphinx-min.conf.in;
	sed 's!\(sql_user\s*=\s*\)\S*!\1'${MYSQL_SERVER_USER}'!' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/sphinx-min.conf.in;
	sed 's!\(sql_db\s*=\s*\)\S*!\1'${MYSQL_SERVER_DB_NAME}'!' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/sphinx-min.conf.in;
	sed 's!\(sql_port\s*=\s*\)\S*!\1'${MYSQL_SERVER_PORT}'!' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/sphinx-min.conf.in;

else
	# create db if not exist
	if [ ! -f /var/lib/mysql/ibdata1 ]; then
		cp /etc/mysql/my.cnf /usr/share/mysql/my-default.cnf
		mysql_install_db || true
		service mysql start

		echo "CREATE DATABASE onlyoffice CHARACTER SET utf8 COLLATE utf8_general_ci" | mysql;

		mysql -D "onlyoffice" < ${ONLYOFFICE_SQL_DIR}/onlyoffice.sql
		mysql -D "onlyoffice" < ${ONLYOFFICE_SQL_DIR}/onlyoffice.data.sql
		mysql -D "onlyoffice" < ${ONLYOFFICE_SQL_DIR}/onlyoffice.resources.sql
	else
		chown -R mysql:mysql /var/lib/mysql/

		if [ ${LOG_DEBUG} ]; then
			echo "fix docker bug volume mapping for mysql";
		fi

		myisamchk -q -r /var/lib/mysql/mysql/proc || true
		service mysql start

		DEBIAN_SYS_MAINT_PASS=$(grep "password" /etc/mysql/debian.cnf | head -1 | sed 's/password\s*=\s*//' | tr -d '[[:space:]]');
		mysql_scalar_exec "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '${DEBIAN_SYS_MAINT_PASS}'"

	fi
fi

# update mysql db
for i in $(ls ${ONLYOFFICE_SQL_DIR}/onlyoffice.upgrade*); do
        mysql_batch_exec ${i};
done


# setup HTTPS
if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
	cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice-ssl ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	mkdir -p ${LOG_DIR}/nginx

	# configure nginx
	sed 's,{{SSL_CERTIFICATE_PATH}},'"${SSL_CERTIFICATE_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	sed 's,{{SSL_KEY_PATH}},'"${SSL_KEY_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	# if dhparam path is valid, add to the config, otherwise remove the option
	if [ -r "${SSL_DHPARAM_PATH}" ]; then
		sed 's,{{SSL_DHPARAM_PATH}},'"${SSL_DHPARAM_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/ssl_dhparam {{SSL_DHPARAM_PATH}};/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi

	sed 's,{{SSL_VERIFY_CLIENT}},'"${SSL_VERIFY_CLIENT}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	if [ -f /usr/local/share/ca-certificates/ca.crt ]; then
		sed 's,{{CA_CERTIFICATES_PATH}},'"${CA_CERTIFICATES_PATH}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/{{CA_CERTIFICATES_PATH}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi

	if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
		sed 's/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/'"${ONLYOFFICE_HTTPS_HSTS_MAXAGE}"'/' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	else
		sed '/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
	fi

	sed '/mail\.default-api-scheme/s/\(value\s*=\s*\"\).*\"/\1https\"/' -i ${ONLYOFFICE_SERVICES_DIR}/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config;

else
	cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice;
fi

if [ ${DOCKER_ONLYOFFICE_SUBNET} ]; then
	sed 's,{{DOCKER_ONLYOFFICE_SUBNET}},'"${DOCKER_ONLYOFFICE_SUBNET}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
else
	sed '/{{DOCKER_ONLYOFFICE_SUBNET}}/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
fi


echo "Start=No" >> /etc/init.d/sphinxsearch 

if ! grep -q "name=\"textindex\"" ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config; then
	sed -i 's/.*<add\s*name="default"\s*connectionString=.*/&\n<add name="textindex" connectionString="Server=localhost;Port=9306;Pooling=True;Character Set=utf8;AutoEnlist=false" providerName="MySql.Data.MySqlClient"\/>/' ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config; 
fi

if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ]; then
    sed 's,{{DOCUMENT_SERVER_HOST_ADDR}},'"${DOCUMENT_SERVER_PROTOCOL}:\/\/${DOCUMENT_SERVER_HOST}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

    # change web.appsettings link to editor
    sed '/files\.docservice\.url\.converter/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/ConvertService\.ashx\"!' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    sed '/files\.docservice\.url\.api/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_API_URL}'\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    sed '/files\.docservice\.url\.storage/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/FileUploader\.ashx\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    sed '/files\.docservice\.url\.command/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/coauthoring\/CommandService\.ashx\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

    if [ -n "${DOCKER_ONLYOFFICE_SUBNET}" ] && [ -n "${SERVER_HOST}" ]; then
	sed '/files\.docservice\.url\.portal/s!\(value\s*=\s*\"\)[^\"]*\"!\1http:\/\/'${SERVER_HOST}'\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	
    fi


    if ! grep -q "files\.docservice\.url\.command" ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config; then
          sed '/files\.docservice\.url\.storage/a <add key=\"files\.docservice\.url\.command\" value=\"'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/coauthoring\/CommandService\.ashx\" \/>/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    else
          sed '/files\.docservice\.url\.command/s!\(value\s*=\s*\"\)[^\"]*\"!\1'${DOCUMENT_SERVER_PROTOCOL}':\/\/'${DOCUMENT_SERVER_HOST}'\/coauthoring\/CommandService\.ashx\"!' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
    fi
	
	mysql_scalar_exec "REPLACE INTO webstudio_settings (TenantID, ID, UserID, Data) VALUES (-1, 'a3acbfc4-155b-4ea8-8367-bbc586319553', '00000000-0000-0000-0000-000000000000', '{\"NewScheme\":true,\"RequestedScheme\":true}');";
else
	# delete documentserver section
	sed '/coauthoring/,/}$/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
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
		echo "waiting MAIL SERVER DB...";
	fi

    done

    # change web.appsettings
    sed -r '/web\.hide-settings/s/,AdministrationPage//' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

    MYSQL_MAIL_SERVER_ID=$(mysql_scalar_exec "select id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");

    echo "MYSQL mail server id '${MYSQL_MAIL_SERVER_ID}'";
    if [ -z ${MYSQL_MAIL_SERVER_ID} ]; then
        
        VALID_IP_ADDRESS_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
        if [[ $EXTERNAL_IP =~ $VALID_IP_ADDRESS_REGEX ]]; then
            echo "External ip $EXTERNAL_IP is valid";
        else
            echo "External ip $EXTERNAL_IP is not valid";
            exit 502;
        fi

        mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
            --port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
            --password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" \
            -e "INSERT INTO greylisting_whitelist (Source, Comment, Disabled) VALUES (\"SenderIP:${EXTERNAL_IP}\", '', 0);";

        mysql_scalar_exec <<END
        ALTER TABLE mail_server_server CHANGE COLUMN connection_string connection_string TEXT NOT NULL AFTER mx_record;
        ALTER TABLE mail_server_domain ADD COLUMN date_checked DATETIME NOT NULL DEFAULT '1975-01-01 00:00:00' AFTER date_added;
        ALTER TABLE mail_server_domain ADD COLUMN is_verified TINYINT(1) UNSIGNED NOT NULL DEFAULT '0' AFTER date_checked;
END

        id1=$(mysql_scalar_exec "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'imap', '${MAIL_SERVER_HOSTNAME}', 143, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");
        if [ ${LOG_DEBUG} ]; then
            echo "id1 is '${id1}'";
        fi

        id2=$(mysql_scalar_exec "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'smtp', '${MAIL_SERVER_HOSTNAME}', 587, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");

        if [ ${LOG_DEBUG} ]; then
            echo "id2 is '${id2}'";
        fi
        
        sed '/mail\.certificate-permit/s/\(value *= *\"\).*\"/\1true\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        sed '/mail\.certificate-permit/s/\(value *= *\"\).*\"/\1true\"/' -i  ${ONLYOFFICE_DIR}/Services/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config
    else
        id1=$(mysql_scalar_exec "select imap_settings_id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");
        if [ ${LOG_DEBUG} ]; then
            echo "id1 is '${id1}'";
        fi

        id2=$(mysql_scalar_exec "select smtp_settings_id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");
        if [ ${LOG_DEBUG} ]; then
            echo "id2 is '${id2}'";
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
	sed 's,{{CONTROL_PANEL_HOST_ADDR}},'"http:\/\/${CONTROL_PANEL_PORT_80_TCP_ADDR}"',' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice

	# change web.appsettings link to controlpanel
	sed '/web\.controlpanel\.url/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/controlpanel\/\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config;
	sed '/web\.controlpanel\.url/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/controlpanel\/\"/' -i ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config;

else
	# delete controlpanel section from nginx template
	sed '/controlpanel/,/}$/d' -i ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice
fi

if [ "${ONLYOFFICE_MODE}" == "SERVER" ]; then


for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
do
	
	if [ $serverID == 1 ]; then
		sed '/web.warmup.count/s/value=\"\S*\"/value=\"'${ONLYOFFICE_MONOSERVE_COUNT}'\"/g' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
		sed '/web.warmup.domain/s/value=\"\S*\"/value=\"localhost\/warmup\"/g' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	
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

wget_retry() {
    timeout=120;
    interval=10;

    while [ "$interval" -lt "$timeout" ] ; do
        interval=$((${interval} + 10));
        wget -qO- --retry-connrefused --no-check-certificate --waitretry=1 --read-timeout=20 --timeout=15 $1 &> /dev/null;
        if [[ "$?" -eq "0" ]]; then
            break;
        fi
        sleep 10;
    done
}

if [ "${REDIS_SERVER_EXTERNAL}" == "true" ]; then
	rm -f "${ONLYOFFICE_GOD_DIR}"/redis.god;
else
	service redis-server start
fi

if [ "${MYSQL_SERVER_EXTERNAL}" == "true" ]; then
	rm -f "${ONLYOFFICE_GOD_DIR}"/mysql.god;
fi

if [ "${ONLYOFFICE_MODE}" == "SERVICES" ]; then
	service nginx stop
	rm -f "${ONLYOFFICE_GOD_DIR}"/monoserve.god;
	rm -f "${ONLYOFFICE_GOD_DIR}"/nginx.god;
else
	if [ ${LOG_DEBUG} ]; then
		echo "fix docker bug volume mapping for onlyoffice";
	fi

	chown -R onlyoffice:onlyoffice /var/log/onlyoffice	
	chown -R onlyoffice:onlyoffice /var/www/onlyoffice/DocumentServerData
	chown -R onlyoffice:onlyoffice /var/www/onlyoffice/Data/certs
	
        if [ "$(ls -alhd /var/www/onlyoffice/Data | awk '{ print $3 }')" != "onlyoffice" ]; then
              chown -R onlyoffice:onlyoffice /var/www/onlyoffice/Data
        fi

	for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
		fi
		
		
		service monoserve$index start
		service monoserve$index stop
		service monoserve$index start
	done

	sleep 10s;

	service monoserveApiSystem start
	service monoserveApiSystem stop
	service monoserveApiSystem start
	cron
fi

if [ "${ONLYOFFICE_SERVICES_EXTERNAL}" == "true" ]; then
	rm -f "${ONLYOFFICE_GOD_DIR}"/onlyoffice.god;
else
	service onlyofficeFeed start
	service onlyofficeIndex start
	service onlyofficeJabber start
	service onlyofficeMailAggregator start
	service onlyofficeMailWatchdog start
	service onlyofficeNotify start
	service onlyofficeBackup start
	#service onlyofficeHealthCheck start
fi

service god start

if [ "${ONLYOFFICE_MODE}" == "SERVER" ]; then
	for serverID in $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
			wget -qO- --no-check-certificate --timeout=1 -t 1 "http://localhost/warmup/Default.aspx" &> /dev/null;
		fi

		wget -qO- --no-check-certificate --timeout=1 -t 1 "http://localhost/warmup'${index}'/Default.aspx" &> /dev/null;
	done

	for serverID in  $(seq 1 ${ONLYOFFICE_MONOSERVE_COUNT});
	do
		index=$serverID;

		if [ $index == 1 ]; then
			index="";
			wget_retry "http://localhost/warmup/Default.aspx";
		fi

		if [ ${LOG_DEBUG} ]; then
			echo "run monoserve warmup$index";
		fi

		wget_retry "http://localhost/warmup$index/Default.aspx";

	done

	mv ${SYSCONF_TEMPLATES_DIR}/nginx/prepare-onlyoffice ${NGINX_CONF_DIR}/onlyoffice

	service nginx reload

	if [ ${LOG_DEBUG} ]; then
		echo "reload nginx config";
	fi

	if [ ${LOG_DEBUG} ]; then
		echo "FINISH";
	fi
fi
