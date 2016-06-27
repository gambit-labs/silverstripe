#!/bin/bash

# SOURCE_DIR and DEST_DIR comes from an ENV variable in the Dockerfile
# Copy everything except cms, framework and _ss_environment.php from ${SOURCE_DIR} to ${DEST_DIR}
if [[ $(ls ${SOURCE_DIR}) != "" ]]; then
	(cd ${SOURCE_DIR} && cp -R $(ls ${SOURCE_DIR} | grep -v 'framework' | grep -v 'cms' | grep -v '_ss_environment.php') ${DEST_DIR})
fi

# dev mode exposes all web data at the /live mount.
# to use it, start the docker container normally, but set DEV_MODE=1 to enable it and mount the host dir you want to see the live content to /live
# Example: Expose the web content at $(pwd)/live, where $(pwd) is the SilverStripe project root: 
# docker run -d --net host -e DEV_MODE=1 -v $(pwd):/source -v $(pwd)/live:/live {image-name}
DEV_MODE=${DEV_MODE:-0}
DEV_DIR=${DEV_DIR:-/live}
if [[ ${DEV_MODE} == 1 ]]; then
	(cd ${DEST_DIR} && cp -R ${DEST_DIR}/* ${DEV_DIR})
	rm -r ${DEST_DIR}
	ln -s ${DEV_DIR} ${DEST_DIR}
fi

# Runtime configuration options
SS_ENVIRONMENT_TYPE=${SS_ENVIRONMENT_TYPE:-dev}
SS_DATABASE_SERVER=${SS_DATABASE_SERVER:-127.0.0.1}
SS_DATABASE_PORT=${SS_DATABASE_PORT:-3306}
SS_DATABASE_USERNAME=${SS_DATABASE_USERNAME:-root}
SS_DATABASE_PASSWORD=${SS_DATABASE_PASSWORD:-root}
SS_DEFAULT_ADMIN_USERNAME=${SS_DEFAULT_ADMIN_USERNAME:-admin}
SS_DEFAULT_ADMIN_PASSWORD=${SS_DEFAULT_ADMIN_PASSWORD:-admin}

SS_TIMEZONE=${SS_TIMEZONE:-"Europe/Helsinki"}
SS_WEB_HOST=${SS_WEB_HOST:-localhost}
SS_LISTEN_PORT=${SS_LISTEN_PORT:-80}

cat > ${DEST_DIR}/_ss_environment.php <<EOF
<?php
ini_set('date.timezone', '${SS_TIMEZONE}');
define('SS_ENVIRONMENT_TYPE', '${SS_ENVIRONMENT_TYPE}');
define('SS_DATABASE_SERVER', '${SS_DATABASE_SERVER}');
define('SS_DATABASE_PORT', '${SS_DATABASE_PORT}');
define('SS_DATABASE_USERNAME', '${SS_DATABASE_USERNAME}');
define('SS_DATABASE_PASSWORD', '${SS_DATABASE_PASSWORD}');
define('SS_DEFAULT_ADMIN_USERNAME', '${SS_DEFAULT_ADMIN_USERNAME}');
define('SS_DEFAULT_ADMIN_PASSWORD', '${SS_DEFAULT_ADMIN_PASSWORD}');
global \$_FILE_TO_URL_MAPPING;
\$_FILE_TO_URL_MAPPING['${DEST_DIR}'] = 'http://${SS_WEB_HOST}';
EOF

# Replace dynamic values in the default web site config
sed -e "s|/var/www|${DEST_DIR}|g" -i /etc/nginx/sites-available/default
sed -e "s|localhost|${SS_WEB_HOST}|g" -i /etc/nginx/sites-available/default
sed -e "s|80|${SS_LISTEN_PORT}|g" -i /etc/nginx/sites-available/default

# Make the user and group www-data own the content. nginx is using that user for displaying content 
chown -R www-data:www-data ${DEST_DIR}

# Start the FastCGI server
exec php5-fpm &

# Start the nginx webserver in foreground mode. The docker container lifecycle will be tied to nginx.
exec nginx -g "daemon off;"
