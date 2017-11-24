CREATE DATABASE IF NOT EXISTS onlyoffice CHARACTER SET "utf8" COLLATE "utf8_general_ci";
CREATE DATABASE IF NOT EXISTS onlyoffice_mailserver CHARACTER SET "utf8" COLLATE "utf8_general_ci";

CREATE USER IF NOT EXISTS 'onlyoffice_user'@'%' IDENTIFIED BY 'onlyoffice_pass';
CREATE USER IF NOT EXISTS 'onlyoffice_mailserver_user'@'%' IDENTIFIED BY 'onlyoffice_mailserver_user_pass';

GRANT ALL PRIVILEGES ON onlyoffice.* TO 'onlyoffice_user'@'%';
GRANT ALL PRIVILEGES ON onlyoffice_mailserver.* TO 'onlyoffice_user'@'%';

GRANT ALL PRIVILEGES ON onlyoffice.* TO 'onlyoffice_mailserver_user'@'%';
GRANT ALL PRIVILEGES ON onlyoffice_mailserver.* TO 'onlyoffice_mailserver_user'@'%';

FLUSH PRIVILEGES;
