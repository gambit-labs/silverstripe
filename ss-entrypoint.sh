#!/bin/bash

over-ss-32(){
	SS_MAJOR=$(echo ${SILVERSTRIPE_VERSION} | cut -d. -f1)
	SS_MINOR=$(echo ${SILVERSTRIPE_VERSION} | cut -d. -f2)
	if [[ ${SS_MAJOR} == 3 && $((SS_MINOR < 2)) == 1 ]]; then
		echo "false"
	else
		echo "true"
	fi
}

# SOURCE_DIR and WWW_DIR comes from an ENV variable in the Dockerfile
# Copy everything except cms, framework and _ss_environment.php from ${SOURCE_DIR} to ${WWW_DIR}
if [[ $(ls ${SOURCE_DIR}) != "" ]]; then

	# Also exclude siteconfig and reports when version is over 3.2
	if [[ $(over-ss-32) == "false" ]]; then
		(cd ${SOURCE_DIR} && cp -R $(ls ${SOURCE_DIR} | \
			grep -v 'framework' | \
			grep -v 'cms' | \
			grep -v '_ss_environment.php') ${WWW_DIR})
	else
		(cd ${SOURCE_DIR} && cp -R $(ls ${SOURCE_DIR} | \
			grep -v 'framework' | \
			grep -v 'cms' | \
			grep -v 'reports' | \
			grep -v 'siteconfig' | \
			grep -v '_ss_environment.php') ${WWW_DIR})
	fi
fi

# dev mode exposes all web data at the /live mount.
# to use it, start the docker container normally, but set DEV_MODE=1 to enable it and mount the host dir you want to see the live content to /live
# Example: Expose the web content at $(pwd)/live, where $(pwd) is the SilverStripe project root: 
# docker run -d -e DEV_MODE=1 -v $(pwd):/source -v $(pwd)/live:/live {image-name}
DEV_MODE=${DEV_MODE:-0}
DEV_DIR=${DEV_DIR:-/live}
if [[ ${DEV_MODE} == 1 ]]; then
	(cd ${WWW_DIR} && cp -R ${WWW_DIR}/* ${DEV_DIR})
	rm -r ${WWW_DIR}
	ln -s ${DEV_DIR} ${WWW_DIR}
fi

# readwrite mode copies the official source into the repo you're working on
# the site is hosted from the directory on the host
# WARNING: This will modify your current work directory
# Example: docker run -d -e RW_MODE=1 -v $(pwd):/source {image-name}
RW_MODE=${RW_MODE:-0}
if [[ ${RW_MODE} == 1 && ${DEV_MODE} == 0 ]]; then
	rm -rf ${SOURCE_DIR}/cms ${SOURCE_DIR}/framework ${SOURCE_DIR}/_ss_environment.php

	if [[ $(over-ss-32) == "true" ]]; then
		rm -rf ${SOURCE_DIR}/reports ${SOURCE_DIR}/siteconfig
	fi

	# Do not override existing files with the same name
	cp -r --no-clobber ${WWW_DIR}/* ${SOURCE_DIR}
	rm -r ${WWW_DIR}
	ln -s ${SOURCE_DIR} ${WWW_DIR}
fi

# Traverse SilverStipe patches, and apply them
if [[ -d ${WWW_DIR}/_patches/${SILVERSTRIPE_VERSION} ]]; then
	cd ${WWW_DIR}

	for file in ${WWW_DIR}/_patches/${SILVERSTRIPE_VERSION}/*.patch; do
		echo "Patching SilverStripe with file: $file"
		patch -p1 < $file
	done
fi

# SilverStripe runtime configuration options
SS_ENVIRONMENT_TYPE=${SS_ENVIRONMENT_TYPE:-dev}
SS_DATABASE_SERVER=${SS_DATABASE_SERVER:-127.0.0.1}
SS_DATABASE_PORT=${SS_DATABASE_PORT:-3306}
SS_DATABASE_USERNAME=${SS_DATABASE_USERNAME:-root}
SS_DATABASE_PASSWORD=${SS_DATABASE_PASSWORD:-root}
SS_DEFAULT_ADMIN_USERNAME=${SS_DEFAULT_ADMIN_USERNAME:-admin}
SS_DEFAULT_ADMIN_PASSWORD=${SS_DEFAULT_ADMIN_PASSWORD:-admin}
SS_ERROR_LOG=${SS_ERROR_LOG:-silverstripe.errlog}

# Variables that can be passed in as lemp-base variables, we want to use them here so pasting the defaults
NGINX_DOMAIN_NAME=${NGINX_DOMAIN_NAME:-localhost}
PHP_TIMEZONE=${PHP_TIMEZONE:-Europe/Helsinki}

cat > ${WWW_DIR}/_ss_environment.php <<EOF
<?php
ini_set('date.timezone', '${PHP_TIMEZONE}');
define('SS_ENVIRONMENT_TYPE', '${SS_ENVIRONMENT_TYPE}');
define('SS_DATABASE_SERVER', '${SS_DATABASE_SERVER}');
define('SS_DATABASE_PORT', '${SS_DATABASE_PORT}');
define('SS_DATABASE_USERNAME', '${SS_DATABASE_USERNAME}');
define('SS_DATABASE_PASSWORD', '${SS_DATABASE_PASSWORD}');
define('SS_DEFAULT_ADMIN_USERNAME', '${SS_DEFAULT_ADMIN_USERNAME}');
define('SS_DEFAULT_ADMIN_PASSWORD', '${SS_DEFAULT_ADMIN_PASSWORD}');
define('SS_ERROR_LOG', '${SS_ERROR_LOG}');
global \$_FILE_TO_URL_MAPPING;
\$_FILE_TO_URL_MAPPING['${WWW_DIR}'] = 'http://${NGINX_DOMAIN_NAME}';
EOF

# Remove install.php where the $database variable is set in _config.php, i.e. remove install.php from all real projects
if [[ ! -z $(grep "global \$database" ${WWW_DIR}/mysite/_config.php) && -z $(grep "$database = ''" ${WWW_DIR}/mysite/_config.php) ]]; then
	rm -f ${WWW_DIR}/install.php
fi

# Let the lemp-base upstream script handle the rest
exec /docker-entrypoint.sh
