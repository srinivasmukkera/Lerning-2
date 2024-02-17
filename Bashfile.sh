#!/bin/bash

#######################################
# Bash script to install WordPress on ubuntu
# Tested in Ubuntu 16.04 and Higher
## Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

## check Current directory
pwd=$(pwd)

## Set default values
wordpress_db_name="Admin"
admin_username="Admin"

## Generate random password (8 characters)
generated_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
echo "Generated Password: $generated_password"

## Save generated password to a text file
echo "$admin_username:$generated_password" > /home/ubuntu/password.txt

## Update values
db_root_password="$generated_password"

echo "WordPress Database Name: $wordpress_db_name"
echo "Database Root Password: $db_root_password"

## Update system
apt-get update -y

## Install APache
sudo apt-get install apache2 apache2-utils -y
systemctl start apache2
systemctl enable apache2

## Install PHP
apt-get install php libapache2-mod-php php-mysql -y

# Install MySQL database server
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_root_password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_root_password"
apt-get install mysql-server mysql-client -y

## Install Latest WordPress
rm /var/www/html/index.*
wget -c http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
rsync -av wordpress/* /var/www/html/

## Set Permissions
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

## Configure WordPress Database
mysql -uroot -p$db_root_password <<QUERY_INPUT
CREATE DATABASE $wordpress_db_name;
GRANT ALL PRIVILEGES ON $wordpress_db_name.* TO 'root'@'localhost' IDENTIFIED BY '$db_root_password';
FLUSH PRIVILEGES;
EXIT
QUERY_INPUT

## Add Database Credentias in wordpress
cd /var/www/html/
sudo mv wp-config-sample.php wp-config.php
perl -pi -e "s/database_name_here/$wordpress_db_name/g" wp-config.php
perl -pi -e "s/username_here/root/g" wp-config.php
perl -pi -e "s/password_here/$db_root_password/g" wp-config.php

## Enabling Mod Rewrite
a2enmod rewrite
php5enmod mcrypt

## Install PhpMyAdmin
apt-get install phpmyadmin -y

## Configure PhpMyAdmin
echo 'Include /etc/phpmyadmin/apache.conf' >> /etc/apache2/apache2.conf

## Restart Apache and Mysql
service apache2 restart
service mysql restart

## Cleaning Download
cd $pwd
rm -rf latest.tar.gz wordpress

echo "Installation is complete."
