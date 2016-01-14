#/bin/bash

ONLYOFFICE_DIR="/var/www/onlyoffice"
ONLYOFFICE_DATA_DIR="${ONLYOFFICE_DIR}/Data"
ONLYOFFICE_SERVICES_DIR="${ONLYOFFICE_DIR}/Services"
ONLYOFFICE_SQL_DIR="${ONLYOFFICE_DIR}/Sql"
ONLYOFFICE_ROOT_DIR="${ONLYOFFICE_DIR}/WebStudio"
ONLYOFFICE_MYSQL_DB_SCHEME_PATH="/app/onlyoffice/setup/data/mysql/onlyoffice.sql"

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
DOCUMENT_SERVER_ENABLED=false
MAIL_SERVER_ENABLED=false
EXTERNAL_IP=${EXTERNAL_IP:-$(dig +short myip.opendns.com @resolver1.opendns.com)};

MYSQL_SERVER_HOST=${MYSQL_SERVER_HOST:-"localhost"}
MYSQL_SERVER_PORT=${MYSQL_SERVER_PORT:-"3306"}
MYSQL_SERVER_DB_NAME=${MYSQL_SERVER_DB_NAME:-"onlyoffice"}
MYSQL_SERVER_USER=${MYSQL_SERVER_USER:-"root"}
MYSQL_SERVER_PASS=${MYSQL_SERVER_PASS:-""}
MYSQL_SERVER_EXTERNAL=false;

if [ "${MYSQL_SERVER_HOST}" != "localhost" ]; then
	MYSQL_SERVER_EXTERNAL=true;
fi

if [ "${MYSQL_SERVER_PORT_3306_TCP}" ]; then
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

if [ "${DOCUMENT_SERVER_PORT_80_TCP}" ]; then
	DOCUMENT_SERVER_ENABLED=true;
fi

if [ "${MAIL_SERVER_PORT_8081_TCP}" ]; then
	MAIL_SERVER_ENABLED=true;

	if [ "${MAIL_SERVER_ENV_MYSQL_EXTERNAL}" == "true" ];then
		MAIL_SERVER_DB_HOST=${MAIL_SERVER_ENV_MYSQL_SERVER};
		MAIL_SERVER_DB_PORT=${MAIL_SERVER_ENV_MYSQL_SERVER_PORT};
		MAIL_SERVER_DB_NAME=${MAIL_SERVER_ENV_MYSQL_SERVER_NAME};
		MAIL_SERVER_DB_USER=${MAIL_SERVER_ENV_MYSQL_ROOT_USER};
		MAIL_SERVER_DB_PASS=${MAIL_SERVER_ENV_MYSQL_ROOT_PASSWD};
	else
		MAIL_SERVER_DB_HOST=${MAIL_SERVER_PORT_3306_TCP_ADDR};
		MAIL_SERVER_DB_PORT=${MAIL_SERVER_PORT_3306_TCP_PORT};
		MAIL_SERVER_DB_NAME="onlyoffice_mailserver";
		MAIL_SERVER_DB_USER="mail_admin";
		MAIL_SERVER_DB_PASS="Isadmin123";
	fi
fi

# configuration service monit
service monit stop

sed 's/# *set httpd port 2812 and.*/set httpd port 2812 and/' -i /etc/monit/monitrc
sed 's/# *use address localhost.*/use address localhost/' -i /etc/monit/monitrc
sed 's/# *allow localhost.*/allow localhost/' -i /etc/monit/monitrc

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

change_connections(){
	if [ "${LOG_DEBUG}" ]; then
		echo "change connections for ${1} then ${2}";
	fi
	sed '/'${1}'/s/\(connectionString\s*=\s*\"\)[^\"]*\"/\1Server='${MYSQL_SERVER_HOST}';Port='${MYSQL_SERVER_PORT}';Database='${MYSQL_SERVER_DB_NAME}';User ID='${MYSQL_SERVER_USER}';Password='${MYSQL_SERVER_PASS}';Pooling=true;Character Set=utf8;AutoEnlist=false\"/' -i ${2}
}

if [ "${MYSQL_SERVER_EXTERNAL}" == "true" ]; then
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

	if [ "${LOG_DEBUG}" ]; then
		echo "DB_IS_EXIST: ${DB_IS_EXIST}";
		echo "DB_CHARACTER_SET_NAME: ${DB_CHARACTER_SET_NAME}";
		echo "DB_COLLATION_NAME: ${DB_COLLATION_NAME}";
	fi

	if [ -z "${DB_IS_EXIST}" ]; then
		mysql_scalar_exec "CREATE DATABASE ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci" "opt_ignore_db_name";
		DB_CHARACTER_SET_NAME="utf8";	
		DB_COLLATION_NAME="utf8_general_ci";
	fi

	if [ "${DB_CHARACTER_SET_NAME}" != "utf8" ]; then
		mysql_scalar_exec "ALTER DATABASE ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci";
	fi

	DB_TABLES_COUNT=$(mysql_scalar_exec "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_SERVER_DB_NAME}'");

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
else
	# create db if not exist
	if [ ! -f /var/lib/mysql/ibdata1 ]; then
		mysql_install_db
		service mysql start

		echo "CREATE DATABASE onlyoffice CHARACTER SET utf8 COLLATE utf8_general_ci" | mysql;
		mysql -D "onlyoffice" < ${ONLYOFFICE_SQL_DIR}/onlyoffice.sql
		mysql -D "onlyoffice" < ${ONLYOFFICE_SQL_DIR}/onlyoffice.data.sql
		mysql -D "onlyoffice" < ${ONLYOFFICE_SQL_DIR}/onlyoffice.resources.sql
	else
		service mysql start
	fi
fi

# update mysql db
for i in $(ls ${ONLYOFFICE_SQL_DIR}/onlyoffice.upgrade*); do
        mysql_batch_exec ${i};
done

# stop services
service monoserve stop
service nginx stop

# setup HTTPS
if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
	cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice-ssl /etc/nginx/sites-enabled/onlyoffice

	mkdir -p ${LOG_DIR}/nginx

	# configure nginx
	sed 's,{{SSL_CERTIFICATE_PATH}},'"${SSL_CERTIFICATE_PATH}"',' -i /etc/nginx/sites-enabled/onlyoffice
	sed 's,{{SSL_KEY_PATH}},'"${SSL_KEY_PATH}"',' -i /etc/nginx/sites-enabled/onlyoffice

	# if dhparam path is valid, add to the config, otherwise remove the option
	if [ -r "${SSL_DHPARAM_PATH}" ]; then
		sed 's,{{SSL_DHPARAM_PATH}},'"${SSL_DHPARAM_PATH}"',' -i /etc/nginx/sites-enabled/onlyoffice
	else
		sed '/ssl_dhparam {{SSL_DHPARAM_PATH}};/d' -i /etc/nginx/sites-enabled/onlyoffice
	fi

	sed 's,{{SSL_VERIFY_CLIENT}},'"${SSL_VERIFY_CLIENT}"',' -i /etc/nginx/sites-enabled/onlyoffice

	if [ -f /usr/local/share/ca-certificates/ca.crt ]; then
		sed 's,{{CA_CERTIFICATES_PATH}},'"${CA_CERTIFICATES_PATH}"',' -i /etc/nginx/sites-enabled/onlyoffice
	else
		sed '/{{CA_CERTIFICATES_PATH}}/d' -i /etc/nginx/sites-enabled/onlyoffice
	fi

	if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
		sed 's/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/'"${ONLYOFFICE_HTTPS_HSTS_MAXAGE}"'/' -i /etc/nginx/sites-enabled/onlyoffice
	else
		sed '/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/d' -i /etc/nginx/sites-enabled/onlyoffice
	fi
else
	cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice /etc/nginx/sites-enabled/onlyoffice
fi

echo "Start=No" >> /etc/init.d/sphinxsearch 

if ! grep -q "name=\"textindex\"" ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config; then
	sed -i 's/.*<add\s*name="default"\s*connectionString=.*/&\n<add name="textindex" connectionString="Server=localhost;Port=9306;Pooling=True;Character Set=utf8;AutoEnlist=false" providerName="MySql.Data.MySqlClient"\/>/' ${ONLYOFFICE_SERVICES_DIR}/TeamLabSvc/TeamLabSvc.exe.Config; 
fi

if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ]; then
	sed 's,{{DOCUMENT_SERVER_HOST_ADDR}},'"http:\/\/${DOCUMENT_SERVER_PORT_80_TCP_ADDR}"',' -i /etc/nginx/sites-enabled/onlyoffice

	# change web.appsettings link to editor
	sed '/files\.docservice\.url\.converter/s/\(value\s*=\s*\"\)[^\"]*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/ConvertService\.ashx\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	sed '/files\.docservice\.url\.api/s/\(value\s*=\s*\"\)[^\"]*\"/\1\/OfficeWeb\/apps\/api\/documents\/api\.js\"/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	sed '/files\.docservice\.url\.storage/s/\(value\s*=\s*\"\)[^\"]*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/FileUploader\.ashx\"/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	sed '/files\.docservice\.url\.command/s/\(value\s*=\s*\"\)[^\"]*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/coauthoring\/CommandService\.ashx\"/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

	# need deleted
	if ! grep -q "files\.docservice\.new" ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config; then
		sed '/files\.docservice\.url\.storage/a <add key=\"files\.docservice\.new\" value=\"\.xlsx\|\.xlst\|\.xls\|\.ods\|\.gsheet\|\.csv\|\.docx\|\.doct\|\.doc\|\.odt\|\.gdoc\|\.txt\|\.rtf\|\.mht\|\.html\|\.htm\|\.fb2\|\.epub\|\.pdf\|\.djvu\|\.xps"\/>/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	fi
	if ! grep -q "files\.docservice\.url\.command" ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config; then
		sed '/files\.docservice\.url\.storage/a <add key=\"files\.docservice\.url\.command\" value=\"http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/coauthoring\/CommandService\.ashx\" \/>/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	else
		sed '/files\.docservice\.url\.command/s/\(value\s*=\s*\"\)[^\"]*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/coauthoring\/CommandService\.ashx\" \/>/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	fi

	mysql_scalar_exec "REPLACE INTO webstudio_settings (TenantID, ID, UserID, Data) VALUES (-1, 'a3acbfc4-155b-4ea8-8367-bbc586319553', '00000000-0000-0000-0000-000000000000', '{\"NewScheme\":true,\"RequestedScheme\":true}');";
else
	# delete documentserver section
	sed '/coauthoring/,/}$/d' -i /etc/nginx/sites-enabled/onlyoffice
fi

if [ "${MAIL_SERVER_ENABLED}" == "true" ]; then

timeout=120;
interval=10;

while [ "$interval" -lt "$timeout" ] ; do
	interval=$((${interval} + 10));

	MAIL_SERVER_HOSTNAME=$(mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
		--port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
		--password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" -e "SELECT Comment from greylisting_whitelist where id=1 limit 1;");
	if [[ "$?" -eq "0" ]]; then
		break;
	fi
	sleep 10;
done

MYSQL_MAIL_SERVER_ID=$(mysql_scalar_exec "select id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");

echo "MYSQL mail server id '${MYSQL_MAIL_SERVER_ID}'";
	if [ -z "${MYSQL_MAIL_SERVER_ID}" ]; then
		# change web.appsettings link to editor
		sed -r '/web\.hide-settings/s/,AdministrationPage//' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
		VALID_IP_ADDRESS_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
		if [[ $EXTERNAL_IP =~ $VALID_IP_ADDRESS_REGEX ]]; then
			echo "External ip $EXTERNAL_IP is valid";
		else
			echo "External ip $EXTERNAL_IP is not valid";
			exit 0;
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
		if [ "${LOG_DEBUG}" ]; then
			echo "id1 is '${id1}'";
		fi

		id2=$(mysql_scalar_exec "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'smtp', '${MAIL_SERVER_HOSTNAME}', 587, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");

		if [ "${LOG_DEBUG}" ]; then
			echo "id2 is '${id2}'";
		fi

		MYSQL_MAIL_SERVER_ACCESS_TOKEN=$(mysql --silent --skip-column-names -h ${MAIL_SERVER_DB_HOST} \
			--port=${MAIL_SERVER_DB_PORT} -u "${MAIL_SERVER_DB_USER}" \
			--password="${MAIL_SERVER_DB_PASS}" -D "${MAIL_SERVER_DB_NAME}" \
			-e "select access_token from api_keys where id=1;");

		if [ "${LOG_DEBUG}" ]; then
			echo "mysql mail server access token is ${MYSQL_MAIL_SERVER_ACCESS_TOKEN}";
		fi

		mysql_scalar_exec "INSERT INTO mail_server_server (mx_record, connection_string, server_type, smtp_settings_id, imap_settings_id) VALUES ('${MAIL_SERVER_HOSTNAME}', '{\"DbConnection\" : \"Server=${MAIL_SERVER_PORT_3306_TCP_ADDR};Database=onlyoffice_mailserver;User ID=mail_admin;Password=Isadmin123;Pooling=True;Character Set=utf8;AutoEnlist=false\", \"Api\":{\"Protocol\":\"http\", \"Server\":\"${MAIL_SERVER_PORT_3306_TCP_ADDR}\", \"Port\":\"${MAIL_SERVER_PORT_8081_TCP_PORT}\", \"Version\":\"v1\",\"Token\":\"${MYSQL_MAIL_SERVER_ACCESS_TOKEN}\"}}', 2, '${id2}', '${id1}');"

		sed '/mail\.certificate-permit/s/\(value *= *\"\).*\"/\1true\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
		sed '/mail\.certificate-permit/s/\(value *= *\"\).*\"/\1true\"/' -i  ${ONLYOFFICE_DIR}/Services/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config
	fi
fi

service nginx stop
service monoserve start
service monoserve stop
service monoserve start
service nginx start
service onlyofficeFeed start
service onlyofficeIndex start
service onlyofficeJabber start
service onlyofficeMailAggregator start
service onlyofficeMailWatchdog start
service onlyofficeNotify start
service onlyofficeBackup start
service monit start
