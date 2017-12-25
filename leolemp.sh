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


    # delete below lines for test.------------------
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    # till here-------------------

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

dbname="$domain"_db
dbuser='wpuser'
dbpass='wppass'

mysql -uroot -proot -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -proot -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -uroot -proot -e "DROP DATABASE IF EXISTS test;"
mysql -uroot -proot -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -uroot -proot -e "FLUSH PRIVILEGES;"
mysql -uroot -proot -e "CREATE DATABASE \`$dbname\`;"

mysql -uroot -proot -e "GRANT ALL ON $dbname.* TO $dbuser@'localhost' IDENTIFIED BY $dbpass; FLUSH PRIVILEGES"

sed -i 's~^try_files \$uri \$uri/ =404;$~try_files \$uri \$uri/ /index.php\$is_args$args;~' /etc/nginx/sites-available/default

service nginx restart

#When setting up our LEMP stack, we only required a very minimal set of extensions
# in order to get PHP to communicate with MySQL. WordPress and many of its plugins leverage additional PHP extensions.
apt update && apt install php-curl php-gd php-mbstring php-mcrypt php-xml php-xmlrpc -y
systemctl restart php7.0-fpm

mkdir temp3
cd temp3

curl -O https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz

cp /home/ubuntu/data/temp3/wordpress/wp-config-sample.php /home/ubuntu/data/temp3/wordpress/wp-config.php #path changes accordingly.

mkdir /home/ubuntu/data/temp3/wordpress/wp-content/upgrade
cp -a /home/ubuntu/data/temp3/wordpress/. /var/www/html

# Configure the WordPress Directory
chown -R $USER:www-data /var/www/html
find /var/www/html -type d -exec chmod g+s {} \;
chmod g+w /var/www/html/wp-content
chmod -R g+w /var/www/html/wp-content/themes
chmod -R g+w /var/www/html/wp-content/plugins

curl -s https://api.wordpress.org/secret-key/1.1/salt

bash -c "curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/html/wp-config.php"
sed -i "s/database_name_here/$dbname/" /var/www/html/wp-config.php
sed -i "s/username_here/$dbuser/" /var/www/html/wp-config.php
sed -i "s/password_here/$dbpass/" /var/www/html/wp-config.php
# cat <<eom >> /var/www/html/wp-config.php
# define('DB_NAME', $dbname);
#
# /** MySQL database username */
# define('DB_USER', $dbuser);
#
# /** MySQL database password */
# define('DB_PASSWORD', $dbpass);
#
# /** MySQL hostname */
# define('DB_HOST', localhost);
# eom

echo "Go to domain $domain on your browser"
echo "Database user $dbuser"
echo "DBpassword $dbpass"
