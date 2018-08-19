WP_DB_USERNAME='root'

echo 'Please, provide a domain name: '
read DOMAIN_NAME;
echo 'Provide Password for MySql root(If not installed it will take it as root): '
read -s MYSQL_ROOT_PASSWORD;
WP_DB_PASSWORD=$MYSQL_ROOT_PASSWORD
WP_DB_USERNAME='root'



# WordPress Documentation: https://codex.wordpress.org/Installing_WordPress
function installPHP(){
	sudo apt-get install software-properties-common
	sudo add-apt-repository -sy ppa:ondrej/php
	sudo add-apt-repository -sy ppa:ondrej/nginx-mainline
	sudo apt update
}

function checkPHPPackages(){
	#echo $*;
	for i in $*
	do
		echo $i;
		find=$(dpkg --list | grep "${i}");
		if [ -n $find ] 2>/dev/null
		then
			sudo apt install -y "$i";
		fi;
	done
	sudo systemctl restart nginx.service
	sudo systemctl restart php7.2-fpm.service
	echo "all required packages are installed";
}

# WordPress Documentation: https://codex.wordpress.org/Installing_WordPress
function installNginx(){
	sudo apt install -y nginx;
}

# WordPress Documentation: https://codex.wordpress.org/Installing_WordPress
function installMySql(){
	MYSQL_ROOT_PASSWORD='root';
	WP_DB_PASSWORD='${MYSQL_ROOT_PASSWORD}';
	echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
	echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
	sudo apt install -y mysql-server
}


# A github repo code: https://gist.github.com/irazasyed/a7b0a079e7727a4315b9
function addHost() {
    IP="127.0.0.1"
    HOSTS_LINE="$IP\t$DOMAIN_NAME"
    ETC_HOSTS='/etc/hosts'
    if [ -n "$(grep $DOMAIN_NAME /etc/hosts)" ]
        then
            echo "$DOMAIN_NAME already exists : $(grep $DOMAIN_NAME $ETC_HOSTS)"
        else
            echo "Adding $DOMAIN_NAME to your $ETC_HOSTS";
            sudo -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts";

            if [ -n "$(grep $DOMAIN_NAME /etc/hosts)" ]
                then
                    echo "$DOMAIN_NAME was added succesfully \n $(grep $DOMAIN_NAME /etc/hosts)";
                else
                    echo "Failed to Add $DOMAIN_NAME, Try again!";
            fi
    fi
}

function configureDomain(){

#sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/$DOMAIN_NAME;
uri='$uri';
sudo tee /etc/nginx/sites-available/$DOMAIN_NAME <<EOF
server {
        listen 80;
        listen [::]:80;

        root /var/www/html/$DOMAIN_NAME;
        # Add index.php to the list if you are using PHP
        index index.php index.html index.htm index.nginx-debian.html;
        server_name $DOMAIN_NAME www.$DOMAIN_NAME;
        location / {
                try_files $uri ${uri}/ =404;
        }
        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;

                fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        }
}
EOF

sudo ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/;
}


function documentRootDir(){
	sudo mkdir -p /var/www/html/$DOMAIN_NAME;
	cd /tmp/ && wget http://wordpress.org/latest.tar.gz;
	tar -zxf latest.tar.gz --strip-components=1;
	sudo cp -R ./* /var/www/html/$DOMAIN_NAME;
}


function createDB(){
WP_DB_NAME_a="\`${DOMAIN_NAME}_db\`"

sudo mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
# SET GLOBAL validate_password_length = 4;
# SET GLOBAL validate_password_number_count = 0;
# SET GLOBAL validate_password_special_char_count = 0;
# SET GLOBAL validate_password_number_count = 0;
# CREATE USER '${WP_DB_USERNAME}'@'localhost' IDENTIFIED BY '${WP_DB_PASSWORD}';
CREATE DATABASE ${WP_DB_NAME_a};
GRANT ALL ON ${WP_DB_NAME_a}.* TO '${WP_DB_USERNAME}'@'localhost';
FLUSH PRIVILEGES;
EOF
}

function configDB(){
	sudo cp /var/www/html/${DOMAIN_NAME}/wp-config-sample.php /var/www/html/${DOMAIN_NAME}/wp-config.php;
	cd /var/www/html/${DOMAIN_NAME}
	sed -i s/database_name_here/${DOMAIN_NAME}_db/ wp-config.php;
	sed -i s/username_here/$WP_DB_USERNAME/ wp-config.php;
	sed -i s/password_here/$WP_DB_PASSWORD/ wp-config.php;
}

function configWebsite(){
curl "http://$DOMAIN_NAME/wp-admin/install.php?step=1" \
--data-urlencode "weblog_title=$DOMAIN_NAME"\
--data-urlencode "user_name=$WP_ADMIN_USERNAME" \
--data-urlencode "admin_email=$WP_ADMIN_EMAIL" \
--data-urlencode "pass1-text=$WP_ADMIN_PASSWORD" \
--data-urlencode "pw_weak=1" \
--data-urlencode "blog_public=0"

curl "http://$DOMAIN_NAME/wp-login.php" \
--data-urlencode "user_login=$WP_ADMIN_USERNAME" \
--data-urlencode "admin_pass=$WP_ADMIN_PASSWORD" \
--data-urlencode "rememberme=1"

}




###################################################################################################################

find=$(dpkg --list | grep 'php7.2-cli');
if [ -n $find ] 2>/dev/null
then 
	#echo "in install php";
	installPHP;
else
	echo "php is already installed";
fi;


checkPHPPackages php7.2-fpm php7.2-common php7.2-mbstring php7.2-xmlrpc php7.2-soap php7.2-gd php7.2-xml php7.2-intl php7.2-mysql php7.2-cli php7.2-zip php7.2-curl

if ! which nginx > /dev/null 2>&1
then
	installNginx;
else
	echo "Nginx is already installed";
fi

if ! which mysql > /dev/null 2>&1
then
	installMySql;
else
	echo "MySql is already installed";
fi

sudo systemctl restart nginx.service
sudo systemctl restart php7.2-fpm.service

addHost

configureDomain

documentRootDir

createDB

configDB

sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

sudo nginx -t
sudo systemctl restart nginx

#configWebsite

sudo service nginx restart
echo "Complete the installation with providing user info at http://$DOMAIN_NAME/wp-admin/install.php"
echo "after that you can go to http://$DOMAIN_NAME happily."


#References:
# manual pages of all the shell codes
# https://www.digitalocean.com/ - different of links from this site
# https://websiteforstudents.com/setup-nginx-server-blocks-multiple-wordpress-blogs/ - Easy for first time user
# https://codex.wordpress.org/ - Documentation
# https://stackoverflow.com/ - For troubleshooting purpose
# https://gist.github.com/irazasyed/a7b0a079e7727a4315b9 - a function is used from it
# And some miscellaneous.
