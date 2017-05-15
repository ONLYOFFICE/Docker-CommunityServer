#!/bin/bash

_domains="";

for arg; do
    _domains="$_domains -d $arg";
done

certbot certonly --webroot -w /var/www/onlyoffice/Data/certs --noninteractive --agree-tos --email support@$1 $_domains;

ln -sf /etc/letsencrypt/live/$1/fullchain.pem /var/www/onlyoffice/Data/certs/onlyoffice.crt
ln -sf /etc/letsencrypt/live/$1/privkey.pem /var/www/onlyoffice/Data/certs/onlyoffice.key
ln -sf /etc/letsencrypt/live/$1/chain.pem /var/www/onlyoffice/Data/certs/stapling.trusted.crt

source default-onlyoffice-ssl.sh
