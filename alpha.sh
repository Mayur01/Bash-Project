if [[ "$EUID" -ne "$ROOT_UID" ]]; then
   echo "This script must be run as root"
   exit 1
fi
LOGFILE=script.log
ERRORFILE=script.err


mysql_secure_installation (){
echo -e "Removing Insecure Details From MySQL"
mysql -uroot -proot -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -proot -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -uroot -proot -e "DROP DATABASE IF EXISTS test;"
mysql -uroot -proot -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -uroot -proot -e "FLUSH PRIVILEGES;"
}

apt update
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

dpkg -l | grep nginx
if [ "$?" -eq 0 ];
then
   echo -e "${GREEN}$i is Installed${NC}";
else
    apt install nginx -y >>$LOGFILE 2>>$ERRORFILE
fi

dpkg -l | grep mysql-server
if [ "$?" -eq 0 ];
then
   echo -e "${GREEN}$i is Installed${NC}";
else
  echo "mysql-server mysql-server/root_password password root" | sudo debconf-set-selections
  echo "mysql-server mysql-server/root_password_again password root" | sudo debconf-set-selections
  apt install mysql-server -y >>$LOGFILE 2>>$ERRORFILE
  mysql_secure_installation
fi


# for i in nginx mysql-server;
# do
#     echo -e "${GREEN}Checking if $i is installed${NC}";
#     dpkg -l | grep $i
#     if [ "$?" -eq 0 ];
#     then
#       echo -e "${GREEN}$i is Installed${NC}"
#     else
#       echo
#       echo "mysql-server mysql-server/root_password password root" | sudo debconf-set-selections
#       echo "mysql-server mysql-server/root_password_again password root" | sudo debconf-set-selections
#
#       echo -e "${RED}$i is not Installed.${NC}"
#       echo -e "${BLUE}Installing $i ...${NC}"
#       apt install $i -y
#     fi
#
# done

echo -e 'Enter domain name: '
read domain
echo -e "Your Domain name is $domain "
echo "127.0.0.1	$domain www.$domain" >> /etc/hosts

dbname="$domain"_db
wppass="wppass"
mysql -uroot -proot -e "CREATE DATABASE \`$dbname\`"
mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO "wordpress"@"localhost" IDENTIFIED BY '$wppass';"
mysql -uroot -proot -e "FLUSH PRIVILEGES;"




for i in curl php-fpm php-mysql mysql-client php-curl php-gd php-mbstring php-mcrypt php-xml php-xmlrpc;
do
    echo -e "${GREEN}Checking if $i is installed${NC}";
    dpkg -l | grep $i
    if [ "$?" -eq 0 ];
    then
      echo -e "${GREEN}$i is Installed${NC}"
    else
      echo -e "${RED}$i is not Installed.${NC}"
      echo -e "${BLUE}Installing $i ...${NC}"
      apt install $i -y
    fi
done

cat <<eof > /etc/nginx/sites-available/default
server {

    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name $domain;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;

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
rm /etc/nginx/sites-available/wordpress
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/wordpress
# bash -c sed -i 's#^try_files  \$uri \$uri/ =404;$#try_files \$uri \$uri/ /index.php\$is_args$args;#' /etc/nginx/sites-available/wordpress
service nginx restart

sed -i 's/^;\?cgi\.fix\_pathinfo=.*$/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
service php7.0-fpm restart
cd /tmp
curl -O https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz

cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php


cp -a /tmp/wordpress/. /var/www/html
chown -R $USER:www-data /var/www/html
find /var/www/html -type d -exec chmod g+s {} \;
chmod g+w /var/www/html/wp-content
chmod -R g+w /var/www/html/wp-content/themes
chmod -R g+w /var/www/html/wp-content/plugins
curl https://api.wordpress.org/secret-key/1.1/salt/ -o salt.txt
sed -i '49,56d;57r salt.txt' /var/www/html/wp-config.php

sed -i "s/database_name_here/$dbname/" /var/www/html/wp-config.php
sed -i "s/username_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/password_here/$wppass/" /var/www/html/wp-config.php

rm /etc/nginx/sites-available/default
echo
echo -e "WordPress installed and configured."
echo -e "Visit the site at $domain"
echo -e "WordPress Database name: $dbname"
echo -e "WordPress Database user: wordpress"
echo -e "WordPress Database password: $wppass"
echo






# echo -e "Enter Mysql Admin Password to setup MYSQL"
# read -p dbpass
# echo -e "Confirm Mysql Admin Password to setup MYSQL"
# read -ps re_dbpass
# if [$dbpass == $re_dbpass]
# then
#     echo -e "Password set for Database root"
# else
#     echo -e "Password does not match.."
# fi
#
# echo "mysql-server mysql-server/root_password password $dbpass" | sudo debconf-set-selections
# echo "mysql-server mysql-server/root_password_again password $dbpass" | sudo debconf-set-selections
# apt-get update
# apt install mysql-server -y
#
# dbname="$domain"_db
# mysql_secure_installation
# mysql -uroot -p$dbpass -e "CREATE DATABASE \`$dbname\`;"
# echo -e "Database created with name: $dbname"
# read -ps "Enter the password for wordpress database" wp_pass
# mysql -uroot -p$dbpass -e "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO "wordpress"@"localhost" IDENTIFIED BY '$wp_pass';"
# mysql -uroot -p$dbpass -e "FLUSH PRIVILEGES;"
#
# rm -f /etc/nginx/sites-available/wordpress
# cp /etc/nginx/sites-available/default /etc/nginx/sites-available/wordpress
# sed -i 's#^try_files  \$uri \$uri/ =404;$#try_files \$uri \$uri/ /index.php\$is_args$args;#' /etc/nginx/sites-available/wordpress
# service nginx reload
#
# apt-get update
# apt-get install php-curl php-gd php-mbstring php-mcrypt php-xml php-xmlrpc -y
# service php7.0-fpm restart
#
# cd /tmp
# curl -O https://wordpress.org/latest.tar.gz
# tar xzvf latest.tar.gz
# cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
# cp -a /tmp/wordpress/. /var/www/html
# chown -R $USER:www-data /var/www/html
# find /var/www/html -type d -exec chmod g+s {} \;
# chmod g+w /var/www/html/wp-content
# chmod -R g+w /var/www/html/wp-content/themes
# chmod -R g+w /var/www/html/wp-content/plugins
#
#
# curl https://api.wordpress.org/secret-key/1.1/salt/ -o salt.txt
# sed -i '49,56d;57r salt.txt' wp-config.php
# sed -i "s/database_name_here/$dbname/" /var/www/html/wp-config.php
# sed -i "s/username_here/wordpress/" /var/www/html/wp-config.php
# sed -i "s/password_here/$wp_pass/" /var/www/html/wp-config.php
#
# echo "Go to domain $domain on your browser"
# echo "Database user wordpress"
# echo "DBpassword $wp_pass"
