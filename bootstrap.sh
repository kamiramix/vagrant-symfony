#!/usr/bin/env bash

APACHE_CONFIG_FILE="/etc/apache2/envvars"
APACHE_VHOST_FILE="/etc/apache2/sites-available/vagrant_vhost.conf"
PHP_CONFIG_FILE="/etc/php5/apache2/php.ini"
XDEBUG_CONFIG_FILE="/etc/php5/mods-available/xdebug.ini"

# Use single quotes instead of double quotes to make it work with special-character passwords
PASSWORD='12345678'
PHP_TIMEZONE='Europe/Paris'

main() {
	update_go
	#network_go
	apache_go
	php_go
	mysql_go
	phpmyadmin_go
	git_go
	composer_go
}

update_go() {
	# update / upgrade
    echo 'Running update apt-get update & upgrade'
    apt-get update >/dev/null
    sudo apt-get -y upgrade > /dev/null
    echo 'Finished running update apt-get update & upgrade'
}

apache_go() {
	# Install Apache
	echo 'Installing apache2'
	apt-get -y install apache2 > /dev/null

    echo 'Change www-data to vagrant in apache vars'
	sed -i "s/^\(.*\)www-data/\1vagrant/g" ${APACHE_CONFIG_FILE}
	chown -R vagrant:vagrant /var/log/apache2

    echo 'Create VirtualHost'
	cat << EOF > ${APACHE_VHOST_FILE}
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /vagrant/www
        LogLevel debug

        ErrorLog /var/log/apache2/error.log
        CustomLog /var/log/apache2/access.log combined

        <Directory /vagrant/www>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Require all granted
        </Directory>
</VirtualHost>
EOF


	a2dissite 000-default
	a2ensite vagrant_vhost

	a2enmod rewrite
    echo 'Reload apache2'
	service apache2 reload
}

php_go() {
	apt-get -y install php5 php5-curl php5-mysql php5-sqlite php5-xdebug > /dev/null

	sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${PHP_CONFIG_FILE}
	sed -i "s/display_errors = Off/display_errors = On/g" ${PHP_CONFIG_FILE}
    # set timezone in php.ini
    sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" ${PHP_CONFIG_FILE}

	cat << EOF > ${XDEBUG_CONFIG_FILE}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=10.0.2.2
xdebug.max_nesting_level=250
EOF

    echo 'Reload apache2'
	service apache2 reload
}

mysql_go() {
	# Install MySQL
	echo "mysql-server mysql-server/root_password password $PASSWORD" | debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password $PASSWORD" | debconf-set-selections
	apt-get -y install mysql-client mysql-server > /dev/null
}


phpmyadmin_go() {
    echo 'Installing phpMyAdmin'
    # install phpmyadmin and give password(s) to installer
    # for simplicity I'm using the same password for mysql and phpmyadmin
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${PASSWORD}"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${PASSWORD}"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${PASSWORD}"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
    sudo apt-get -y install phpmyadmin > /dev/null
}

git_go() {
    # install git
    sudo apt-get -y install git > /dev/null
}

composer_go() {
    # install Composer
    curl -s https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
}

main
exit 0