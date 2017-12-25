if [[ "$EUID" -ne "$ROOT_UID" ]]; then
   echo "This script must be run as root"
   exit 1
fi

apt update && apt install nginx php-fpm php-mysql -y
read -p 'Enter your domain name: ' domain
echo "Your Domain name is $domain "
echo "127.0.0.1	$domain" >> /etc/hosts
sed -i 's/^;\?cgi\.fix\_pathinfo=.*$/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini

cat <<eof > /etc/nginx/sites-available/default
server {

    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name $domain;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.0-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

}
eof

service php7.0-fpm restart
cat <<eof > /var/www/html/info.php
<?php
phpinfo();
eof


echo "mysql-server-5.7 mysql-server/root_password password root" | sudo debconf-set-selections
echo "mysql-server-5.7 mysql-server/root_password_again password root" | sudo debconf-set-selections
apt-get -y install mysql-server-5.7

mysql -uroot -proot -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -proot -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -uroot -proot -e "DROP DATABASE IF EXISTS test;"
mysql -uroot -proot -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -uroot -proot -e "FLUSH PRIVILEGES;"
