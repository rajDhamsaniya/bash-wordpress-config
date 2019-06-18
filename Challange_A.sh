#! /bin/bash
# WP_DB_USERNAME='root'

# echo 'Please, provide a domain name: '
# read DOMAIN_NAME;
# echo 'Provide Password for MySql root(If not installed it will take it as root): '
# read -s MYSQL_ROOT_PASSWORD;
WP_DB_PASSWORD=""
WP_DB_USERNAME=""
DOMAIN_NAME=""

function help(){

	echo -e "\t -d, --domain"
	echo -e "\t\t For providing domain name."
	echo -e "\n\t -h , --help"
	echo -e "\t\t Help Menu"
	echo -e "\n\t -p, --dbpass"
	echo -e "\t\t Password for provided username if MySql already installed"
	echo -e "\n\t -r, --remove"
	echo -e "\t\t remove installed wordpress website only."
	echo -e "\n\t -u, --dbuser"
	echo -e "\t\t UserName for MySql Database if already installed"
}

# WordPress Documentation: https://codex.wordpress.org/Installing_WordPress
function installPHP(){
	sudo add-apt-repository -sy universe
	sudo apt install -y php-fpm php-mysql
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
	sudo apt update
	sudo apt install -y nginx
	sudo ufw allow 'Nginx HTTP'
}

# WordPress Documentation: https://codex.wordpress.org/Installing_WordPress
function installMySql(){
	MYSQL_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1);
	WP_DB_PASSWORD=$MYSQL_ROOT_PASSWORD;
	WP_DB_USERNAME="root"
	echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
	echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
	sudo apt install -y mysql-server
	echo -e "MySql is installed for root user with password : \e[1m\e[32m$MYSQL_ROOT_PASSWORD"
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

function removeHost() {
	ETC_HOSTS=/etc/hosts
    if [ -n "$(grep $REMOVE_DOMAIN /etc/hosts)" ]
    then
        echo "$REMOVE_DOMAIN Found in your $ETC_HOSTS, Removing now...";
        sudo sed -i".bak" "/$REMOVE_DOMAIN/d" $ETC_HOSTS
    else
        echo "$REMOVE_DOMAIN was not found in your $ETC_HOSTS";
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
# sudo rm /etc/nginx/sites-available/default
sudo unlink /etc/nginx/sites-enabled/default
}


function documentRootDir(){
	sudo mkdir -p /var/www/html/$DOMAIN_NAME;
	cd /tmp/ && wget https://wordpress.org/latest.tar.gz;
	tar -zxf latest.tar.gz --strip-components=1;
	sudo cp -R ./* /var/www/html/$DOMAIN_NAME;
}


function createDB(){
WP_DB_NAME_a="\`${DOMAIN_NAME}_db\`"

sudo mysql -u $WP_DB_USERNAME -p$MYSQL_ROOT_PASSWORD << EOF
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

function removeDB(){
WP_DB_NAME_a="\`${DOMAIN_NAME}_db\`"

sudo mysql -u $WP_DB_USERNAME -p$MYSQL_ROOT_PASSWORD << EOF
DROP DATABASE '${WP_DB_NAME_a}';
EOF
}

function configDB(){
	sudo cp /var/www/html/${DOMAIN_NAME}/wp-config-sample.php /var/www/html/${DOMAIN_NAME}/wp-config.php;
	cd /var/www/html/${DOMAIN_NAME}
	sed -i s/database_name_here/${DOMAIN_NAME}_db/ wp-config.php;
	sed -i s/username_here/$WP_DB_USERNAME/ wp-config.php;
	sed -i s/password_here/$WP_DB_PASSWORD/ wp-config.php;


	SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
	STRING='put your unique phrase here'
	printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php
}

function configWebsite(){
curl "http://$DOMAIN_NAME/wp-admin/install.php?step=1" \
--data-urlencode "weblog_title=$DOMAIN_NAME"\
--data-urlencode "user_name=$WP_ADMIN_USERNAME" \
--data-urlencode "admin_email=$WP_ADMIN_EMAIL" \
--data-urlencode "pass1-text=$WP_ADMIN_PASSWORD" \
--data-urlencode "pw_weak=1" \
--data-urlencode "blog_public=0"

# curl "http://$DOMAIN_NAME/wp-login.php" \
# --data-urlencode "user_login=$WP_ADMIN_USERNAME" \
# --data-urlencode "admin_pass=$WP_ADMIN_PASSWORD" \
# --data-urlencode "rememberme=1"

}

function remove(){
	removeHost
	sudo unlink /etc/nginx/sites-enabled/$REMOVE_DOMAIN;
	sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/;
	sudo rm -rf /etc/nginx/sites-available/$REMOVE_DOMAIN;
	sudo rm -rf /var/www/html/$DOMAIN_NAME
	removeDB
}


###################################################################################################################

while [[ -n "$1" ]]; do
	case "$1" in 
		-d | --domain) 	shift
						DOMAIN_NAME="$1"
						;;
		-h | --help) 	shift
						help
						;;
		-p | --dbpass)  shift
						WP_DB_PASSWORD="$1"
						;;
		-r | --remove)	shift
						REMOVE_DOMAIN="$1"
						remove
						exit 
						;;
		-u | --dbuser)  shift
						WP_DB_USERNAME="$1"
						;;
		*)				echo "Unknown Command Please refer help guide."
						help
						exit
						;;
	esac
	shift
done	

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

find=$(dpkg --list | grep 'php7.2-cli');
if [ -n $find ] 2>/dev/null
then 
	#echo "in install php";
	installPHP;
else
	echo "php is already installed";
fi;

checkPHPPackages php-fpm php-common php-mbstring php-xmlrpc php-soap php-gd php-xml php-intl php-mysql php-cli php-zip php-curl

sudo systemctl restart nginx.service
sudo systemctl restart php-fpm.service

addHost

configureDomain

sudo systemctl reload nginx

documentRootDir

createDB

configDB

sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

sudo nginx -t
sudo systemctl restart nginx

# configWebsite

sudo service nginx restart
echo "Complete the installation with providing user info at http://$DOMAIN_NAME/wp-admin/install.php"
echo "after that you can go to http://$DOMAIN_NAME happily."
# echo -e "\n\t MYSQL_ROOT_PASSWORD = $MYSQL_ROOT_PASSWORD" 

#References:
# manual pages of all the shell codes
# https://www.digitalocean.com/ - different of links from this site
# https://websiteforstudents.com/setup-nginx-server-blocks-multiple-wordpress-blogs/ - Easy for first time user
# https://codex.wordpress.org/ - Documentation
# https://stackoverflow.com/ - For troubleshooting purpose
# https://gist.github.com/irazasyed/a7b0a079e7727a4315b9 - a function is used from it
# And some miscellaneous.
