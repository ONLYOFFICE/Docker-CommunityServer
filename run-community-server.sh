#/bin/bash

ONLYOFFICE_DIR="/var/www/onlyoffice"
ONLYOFFICE_DATA_DIR="${ONLYOFFICE_DIR}/Data"
ONLYOFFICE_ROOT_DIR="${ONLYOFFICE_DIR}/WebStudio"
LOG_DIR="/var/log/onlyoffice/8.1"

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


if [ ${DOCUMENT_SERVER_PORT_80_TCP} ]; then
        DOCUMENT_SERVER_ENABLED=true;
fi

if [[ ${MAIL_SERVER_PORT_8081_TCP} ]]; then
        MAIL_SERVER_ENABLED=true;
fi

# configuration service monit
service monit stop

sed 's/# *set httpd port 2812 and/set httpd port 2812 and/' -i /etc/monit/monitrc
sed 's/# *use address localhost/use address localhost/' -i /etc/monit/monitrc
sed 's/# *allow localhost/allow localhost/' -i /etc/monit/monitrc

# configure monit
cp ${SYSCONF_TEMPLATES_DIR}/monit/nginx /etc/monit/conf.d/nginx
cp ${SYSCONF_TEMPLATES_DIR}/monit/mysql /etc/monit/conf.d/mysql

cp ${SYSCONF_TEMPLATES_DIR}/monit/onlyoffice /etc/monit/conf.d/onlyofficeFeed
cp ${SYSCONF_TEMPLATES_DIR}/monit/onlyoffice /etc/monit/conf.d/onlyofficeJabber
cp ${SYSCONF_TEMPLATES_DIR}/monit/onlyoffice /etc/monit/conf.d/onlyofficeIndex
cp ${SYSCONF_TEMPLATES_DIR}/monit/onlyoffice /etc/monit/conf.d/onlyofficeMailAggregator
cp ${SYSCONF_TEMPLATES_DIR}/monit/onlyoffice /etc/monit/conf.d/onlyofficeMailWatchdog
cp ${SYSCONF_TEMPLATES_DIR}/monit/onlyoffice /etc/monit/conf.d/onlyofficeNotify

sed 's/{{ONLYOFFICE_SERVICE_NAME}}/onlyofficeFeed/g'  -i /etc/monit/conf.d/onlyofficeFeed
sed 's/{{ONLYOFFICE_SERVICE_NAME}}/onlyofficeJabber/g'  -i /etc/monit/conf.d/onlyofficeJabber
sed 's/{{ONLYOFFICE_SERVICE_NAME}}/onlyofficeIndex/g'  -i /etc/monit/conf.d/onlyofficeIndex
sed 's/{{ONLYOFFICE_SERVICE_NAME}}/onlyofficeMailAggregator/g'  -i /etc/monit/conf.d/onlyofficeMailAggregator
sed 's/{{ONLYOFFICE_SERVICE_NAME}}/onlyofficeMailWatchdog/g'  -i /etc/monit/conf.d/onlyofficeMailWatchdog
sed 's/{{ONLYOFFICE_SERVICE_NAME}}/onlyofficeNotify/g'  -i /etc/monit/conf.d/onlyofficeNotify


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
sed -i 's/.*<add name="default".*connectionString=.*/&\n<add name="textindex" connectionString="Server=localhost;Port=9306;Pooling=True;Character Set=utf8;AutoEnlist=false" providerName="MySql.Data.MySqlClient"\/>/' /var/www/onlyoffice/Services/TeamLabSvc/TeamLabSvc.exe.Config 

service mysql start

if [ "${DOCUMENT_SERVER_ENABLED}" == "true" ]; then

        sed 's,{{DOCUMENT_SERVER_HOST_ADDR}},'"http:\/\/${DOCUMENT_SERVER_PORT_80_TCP_ADDR}"',' -i /etc/nginx/sites-enabled/onlyoffice

        # change web.appsettings link to editor
        sed '/files\.docservice\.url\.converter/s/\(value *= *\"\).*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/ConvertService\.ashx\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        sed '/files\.docservice\.url\.api/s/\(value *= *\"\).*\"/\1\/OfficeWeb\/apps\/api\/documents\/api\.js\"/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        sed '/files\.docservice\.url\.storage/s/\(value *= *\"\).*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/FileUploader\.ashx\"/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        sed '/files\.docservice\.url\.command/s/\(value *= *\"\).*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/coauthoring\/CommandService\.ashx\"/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

        # need deleted
        if ! grep -q "files\.docservice\.new" ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config; then
                sed '/files\.docservice\.url\.storage/a <add key=\"files\.docservice\.new\" value=\"\.xlsx\|\.xlst\|\.xls\|\.ods\|\.gsheet\|\.csv\|\.docx\|\.doct\|\.doc\|\.odt\|\.gdoc\|\.txt\|\.rtf\|\.mht\|\.html\|\.htm\|\.fb2\|\.epub\|\.pdf\|\.djvu\|\.xps"\/>/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        fi

        if ! grep -q "files\.docservice\.url\.command" ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config; then
                sed '/files\.docservice\.url\.storage/a <add key=\"files\.docservice\.url\.command\" value=\"http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/coauthoring\/CommandService\.ashx\" \/>/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	else
		sed '/files\.docservice\.url\.command/s/\(value *= *\"\).*\"/\1http:\/\/'${DOCUMENT_SERVER_PORT_80_TCP_ADDR}'\/coauthoring\/CommandService\.ashx\" \/>/' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
        fi

        mysql -D "onlyoffice" -e "REPLACE INTO webstudio_settings (TenantID, ID, UserID, Data) VALUES (-1, 'a3acbfc4-155b-4ea8-8367-bbc586319553', '00000000-0000-0000-0000-000000000000', '{\"NewScheme\":true,\"RequestedScheme\":true}');";

        #######################

else
        # delete documentserver section
        sed '/coauthoring/,/}$/d' -i /etc/nginx/sites-enabled/onlyoffice
fi

if [ "${MAIL_SERVER_ENABLED}" == "true" ]; then

timeout=120;
interval=10;

while [ "$interval" -lt "$timeout" ] ; do
        interval=$((${interval} + 10));

        MAIL_SERVER_HOSTNAME=$(mysql --silent --skip-column-names -h ${MAIL_SERVER_PORT_3306_TCP_ADDR} \
                 --protocol=${MAIL_SERVER_PORT_3306_TCP_PROTO} --port=${MAIL_SERVER_PORT_3306_TCP_PORT} -u mail_admin \
                 -pIsadmin123 -D "onlyoffice_mailserver" -e "SELECT Comment from greylisting_whitelist where id=1 limit 1;");

        if [[ "$?" -eq "0" ]]; then
                break;
        fi
	
	sleep 10;
done

MYSQL_MAIL_SERVER_ID=$(mysql --silent --skip-column-names -D "onlyoffice" -e "select id from mail_server_server where mx_record='${MAIL_SERVER_HOSTNAME}' limit 1");

echo "MYSQL mail server id '${MYSQL_MAIL_SERVER_ID}'";

        if [ -z ${MYSQL_MAIL_SERVER_ID} ]; then

                # change web.appsettings link to editor
                sed -r '/web\.hide-settings/s/,AdministrationPage//' -i ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config

		VALID_IP_ADDRESS_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";

		if [[ $EXTERNAL_IP =~ $VALID_IP_ADDRESS_REGEX ]]; then
			echo "External ip $EXTERNAL_IP is valid";
		else
			echo "External ip $EXTERNAL_IP is not valid";
		
			exit 0;
		fi

		mysql --silent --skip-column-names -h ${MAIL_SERVER_PORT_3306_TCP_ADDR} \
		 --protocol=${MAIL_SERVER_PORT_3306_TCP_PROTO} --port=${MAIL_SERVER_PORT_3306_TCP_PORT} -u mail_admin \
		 -pIsadmin123 -D "onlyoffice_mailserver" -e "INSERT INTO greylisting_whitelist (Source, Comment, Disabled) VALUES (\"SenderIP:${EXTERNAL_IP}\", '', 0);";

		
		mysql -D "onlyoffice" <<END
		ALTER TABLE mail_server_server CHANGE COLUMN connection_string connection_string TEXT NOT NULL AFTER mx_record;
		ALTER TABLE mail_server_domain ADD COLUMN date_checked DATETIME NOT NULL DEFAULT '1975-01-01 00:00:00' AFTER date_added;
		ALTER TABLE mail_server_domain ADD COLUMN is_verified TINYINT(1) UNSIGNED NOT NULL DEFAULT '0' AFTER date_checked;
		INSERT INTO greylisting_whitelist (Source, Comment, Disabled) VALUES ("SenderIP:${EXTERNAL_IP}", '', 0);
END

                id1=$(mysql --silent --skip-column-names -D "onlyoffice" -e "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'imap', '${MAIL_SERVER_HOSTNAME}', 143, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");

                echo "id1 is '${id1}'";

                id2=$(mysql --silent --skip-column-names -D "onlyoffice" -e "INSERT INTO mail_mailbox_server (id_provider, type, hostname, port, socket_type, username, authentication, is_user_data) VALUES (-1, 'smtp', '${MAIL_SERVER_HOSTNAME}', 587, 'STARTTLS', '%EMAILADDRESS%', '', 0);SELECT LAST_INSERT_ID();");

                echo "id2 is '${id2}'";

                MYSQL_MAIL_SERVER_ACCESS_TOKEN=$(mysql --silent --skip-column-names -h ${MAIL_SERVER_PORT_3306_TCP_ADDR} \
		 --protocol=${MAIL_SERVER_PORT_3306_TCP_PROTO} --port=${MAIL_SERVER_PORT_3306_TCP_PORT} -u mail_admin \
		 -pIsadmin123 -D "onlyoffice_mailserver" -e "select access_token from api_keys where id=1;");

                echo "mysql mail server access token is ${MYSQL_MAIL_SERVER_ACCESS_TOKEN}";
                mysql -D "onlyoffice" -e "INSERT INTO mail_server_server (mx_record, connection_string, server_type, smtp_settings_id, imap_settings_id) VALUES ('${MAIL_SERVER_HOSTNAME}', '{\"DbConnection\" : \"Server=${MAIL_SERVER_PORT_3306_TCP_ADDR};Database=onlyoffice_mailserver;User ID=mail_admin;Password=Isadmin123;Pooling=True;Character Set=utf8;AutoEnlist=false\", \"Api\":{\"Protocol\":\"http\", \"Server\":\"${MAIL_SERVER_PORT_3306_TCP_ADDR}\", \"Port\":\"${MAIL_SERVER_PORT_8081_TCP_PORT}\", \"Version\":\"v1\",\"Token\":\"${MYSQL_MAIL_SERVER_ACCESS_TOKEN}\"}}', 2, '${id2}', '${id1}');"

	        sed '/mail\.certificate-permit/s/\(value *= *\"\).*\"/\1true\"/' -i  ${ONLYOFFICE_ROOT_DIR}/web.appsettings.config
	        sed '/mail\.certificate-permit/s/\(value *= *\"\).*\"/\1true\"/' -i  ${ONLYOFFICE_DIR}/Services/MailAggregator/ASC.Mail.Aggregator.CollectionService.exe.config

        fi

fi

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
