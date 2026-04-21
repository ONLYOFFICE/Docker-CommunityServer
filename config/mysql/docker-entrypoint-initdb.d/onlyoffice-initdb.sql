CREATE DATABASE IF NOT EXISTS onlyoffice CHARACTER SET "utf8" COLLATE "utf8_general_ci";
CREATE DATABASE IF NOT EXISTS onlyoffice_mailserver CHARACTER SET "utf8" COLLATE "utf8_general_ci";

ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'my-secret-pw';
CREATE USER IF NOT EXISTS 'onlyoffice_user'@'%' IDENTIFIED WITH mysql_native_password BY 'onlyoffice_pass';
CREATE USER IF NOT EXISTS 'mail_admin'@'%' IDENTIFIED WITH mysql_native_password BY 'Isadmin123';

GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'onlyoffice_user'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'mail_admin'@'%';

FLUSH PRIVILEGES;
