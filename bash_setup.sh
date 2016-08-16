#!/bin/bash

if [ $UID != 0 ]; then
  echo "must be root to run this script"
  exit 1
fi

if [ ":$1" == ":" ]; then
  echo "password must be passed as the first argument"
  exit 1
fi

db_pass=$1

debconf-set-selections <<< 'mysql-server mysql-server/root_password password password'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password password'

apt-get update 2>&1> /dev/null
apt-get install mysql-server-5.6 apache2 php5 php5-mysql git -y 2>&1> /dev/null
rm /var/www/html/index.html

git clone https://github.com/stellimatt/greeter.git /tmp/greeter
cp /tmp/greeter/index.php /var/www/html
mysql -u root -p$db_pass < /tmp/greeter/db.seed
service apache2 restart
