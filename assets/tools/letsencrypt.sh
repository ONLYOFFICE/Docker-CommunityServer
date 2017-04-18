#!/bin/bash

_domains="";

for arg; do
    _domains="$_domains -d $arg";
done

if [ ! -f /var/www/onlyoffice/Data/certs/dhparam.pem ]; then
	sudo openssl dhparam -out dhparam.pem 2048

	mv dhparam.pem /var/www/onlyoffice/Data/certs/dhparam.pem;
fi


certbot certonly --webroot -w /var/www/onlyoffice/Data/certs --noninteractive --agree-tos --email support@$1 $_domains;

ln -sf /etc/letsencrypt/live/$1/fullchain.pem /var/www/onlyoffice/Data/certs/onlyoffice.crt
ln -sf /etc/letsencrypt/live/$1/privkey.pem /var/www/onlyoffice/Data/certs/onlyoffice.key

source default-onlyoffice-ssl.sh
