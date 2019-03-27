# !/bin/bash

		echo "==============================================================================\n"
		echo "                ************* Centos SHELL BY NEMO *************              \n"
		echo "==============================================================================\n"
		
		# --- PORT settings ---
		
		FORWARDED_PORT=8080
		
		# --- Database settings ---
		DB_USER="nemo"
		DB_PASSWORD="NEMO@wei61"
		DB_NAME="nemo"

		# --- Application settings ---
		APP_HOST="localhost"
		
		echo "*******************************************************"
		echo "************** Step 1: Environment Setup **************"
		echo "*******************************************************"
		echo "~~~~~~~~~~~~~~ Enable Required Package Repositories ~~~~~~~~~~~~~~"
		
		yum install -y epel-release
		yum update -y
		echo "~~~~~~~~~~~~~~ Install Nginx, NodeJS, Git, and Wget ~~~~~~~~~~~~~~"
		
		yum install -y nginx wget git nodejs yum-utils
		
		echo "~~~~~~~~~~~~~~ Install MySQL ~~~~~~~~~~~~~~"
		
		wget https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm && rpm -ivh mysql80-community-release-el7-1.noarch.rpm
		yum-config-manager --disable mysql80-community
		yum-config-manager --enable mysql57-community
		
		yum install -y mysql-community-server
		
		echo "~~~~~~~~~~~~~~ Install PHP ~~~~~~~~~~~~~~"
		
		wget http://rpms.remirepo.net/enterprise/remi-release-7.rpm && rpm -Uvh remi-release-7.rpm
		yum-config-manager --enable remi-php71
		yum update -y
		yum install -y php-fpm php-cli php-pdo php-mysqlnd php-xml php-soap php-gd php-mbstring php-zip php-intl php-mcrypt php-opcache
		
		echo "~~~~~~~~~~~~~~ Install Composer ~~~~~~~~~~~~~~"
		
		php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php
		php -r "unlink('composer-setup.php');"
		mv composer.phar /usr/bin/composer
		
		echo "~~~~~~~~~~~~~~ Enable Installed Services ~~~~~~~~~~~~~~"
		systemctl start mysqld php-fpm nginx 
		systemctl enable mysqld php-fpm nginx 
		echo "********************************************************************************"
		echo "************** Step 2: Pre-installation Environment Configuration **************"
		echo "********************************************************************************"
		echo "~~~~~~~~~~~~~~ Perform Security Configuration ~~~~~~~~~~~~~~"
		sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
		setenforce permissive
		echo "~~~~~~~~~~~~~~ Prepare MySQL Database ~~~~~~~~~~~~~~"
		# --- Change the MySQL Server Configuration ---
		echo "[client]" >> /etc/my.cnf
		echo "default-character-set = utf8mb4" >> /etc/my.cnf
		echo "" >> /etc/my.cnf
		echo "[mysql]" >> /etc/my.cnf
		echo "default-character-set = utf8mb4" >> /etc/my.cnf
		echo "" >> /etc/my.cnf
		echo "[mysqld]" >> /etc/my.cnf
		echo "innodb_file_per_table = 0" >> /etc/my.cnf
		echo "wait_timeout = 28800" >> /etc/my.cnf
		echo "character-set-server = utf8mb4" >> /etc/my.cnf
		echo "collation-server = utf8mb4_unicode_ci" >> /etc/my.cnf
		systemctl restart mysqld
		# --- Change the Default MySQL Password for Root User ---
		MYSQL_INSTALLED_TMP_ROOT_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
		mysqladmin --user=root --password=$MYSQL_INSTALLED_TMP_ROOT_PASSWORD password $DB_PASSWORD
		# --- Create a Database for OroPlatform Community Edition Application and a Dedicated Database User ---
		
		mysql -uroot -p$DB_PASSWORD -e "CREATE DATABASE $DB_NAME"
	  mysql -uroot -p$DB_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME.* to '$DB_USER'@'localhost' identified by '$DB_PASSWORD'"
	  mysql -uroot -p$DB_PASSWORD -e "FLUSH PRIVILEGES"
		
	  echo "~~~~~~~~~~~~~~ Configure PHP ~~~~~~~~~~~~~~"
		sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
		sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf
		sed -i 's/;catch_workers_output/catch_workers_output/g' /etc/php-fpm.d/www.conf
		sed -i 's/memory_limit = [0-9MG]*/memory_limit = 1G/g' /etc/php.ini
		sed -i 's/;realpath_cache_size = [0-9MGk]*/realpath_cache_size = 4M/g' /etc/php.ini
		sed -i 's/;realpath_cache_ttl = [0-9]*/realpath_cache_ttl = 600/g' /etc/php.ini
		sed -i 's/opcache.enable=[0-1]/opcache.enable=1/g' /etc/php.d/10-opcache.ini
		sed -i 's/;opcache.enable_cli=[0-1]/opcache.enable_cli=0/g' /etc/php.d/10-opcache.ini
		sed -i 's/opcache.memory_consumption=[0-9]*/opcache.memory_consumption=512/g' /etc/php.d/10-opcache.ini
		sed -i 's/opcache.interned_strings_buffer=[0-9]*/opcache.interned_strings_buffer=32/g' /etc/php.d/10-opcache.ini
		sed -i 's/opcache.max_accelerated_files=[0-9]*/opcache.max_accelerated_files=32531/g' /etc/php.d/10-opcache.ini
		sed -i 's/;opcache.save_comments=[0-1]/opcache.save_comments=1/g' /etc/php.d/10-opcache.ini

		mkdir /usr/share/nginx/html/web/

		touch /usr/share/nginx/html/web/index.php

		cat > /usr/share/nginx/html/web/index.php <<____PHPHELLO
<?PHP
	echo "Hello Nemo !!!";

____PHPHELLO
		
		systemctl restart php-fpm

		echo "~~~~~~~~~~~~~~ Configure Web Server ~~~~~~~~~~~~~~"

		cat > /etc/nginx/conf.d/default.conf <<____NGINXCONFIGTEMPLATE
server {
	listen $FORWARDED_PORT;
	server_name $APP_HOST www.$APP_HOST;
	root  /usr/share/nginx/html/web;
	index index.php;
	gzip on;
	gzip_proxied any;
	gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
	gzip_vary on;
	location / {
		# try to serve file directly, fallback to index.php
		try_files \$uri /index.php\$is_args\$args;
	}
	location ~ ^/(index|index_dev|config|install)\\.php(/|$) {
		fastcgi_pass 127.0.0.1:9000;
		# or
		# fastcgi_pass unix:/var/run/php/php7-fpm.sock;
		fastcgi_split_path_info ^(.+\\.php)(/.*)$;
		include fastcgi_params;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_param HTTPS off;
		fastcgi_buffers 64 64k;
		fastcgi_buffer_size 128k;
	}
	location ~* ^[^(\\.php)]+\\.(jpg|jpeg|gif|png|ico|css|pdf|ppt|txt|bmp|rtf|js)$ {
		access_log off;
		expires 1h;
		add_header Cache-Control public;
	}
	error_log /var/log/nginx/${APP_HOST}_error.log;
	access_log /var/log/nginx/${APP_HOST}_access.log;
}
____NGINXCONFIGTEMPLATE
		
		systemctl restart nginx

		echo "**********************************************************************************************************************"
		echo "************** Congratulations! You’ve Successfully **********************************"
		echo "**********************************************************************************************************************"
		echo "************** Now! Open the homepage http://$APP_HOST:$FORWARDED_PORT/ . **************"