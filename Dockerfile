FROM debian:jessie

# Install all necessary packages and upgrade the current debian distro
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get -yy -q install --no-install-recommends \
	curl \
	git \
	mercurial \
	ca-certificates \
	nginx-full \
	php5 \
	php5-common \
	php5-fpm \
	php5-mysql \
	php5-cli \
	php5-cgi \
	php5-gd \
	php5-mcrypt \
	php5-tidy \
	php5-curl \
	php5-json \
	php-apc \
	php-pear \
	mysql-client \
	locales \
	&& DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# The user should mount the site repository into SOURCE_DIR. The relevant parts of SOURCE_DIR will be copied to DEST_DIR, where nginx is serving
ENV SOURCE_DIR=/source
ENV DEST_DIR=/var/www

# Set locale, download composer, config php5-fpm to use localhost:9000, redirect access.log and error.log to std{out,err} and enable the default site
RUN sed -e "s|# sv_FI.UTF-8|sv_FI.UTF-8|g;s|# fi_FI.UTF-8|fi_FI.UTF-8|g;s|# en_US.UTF-8|en_US.UTF-8|g" -i /etc/locale.gen \
	&& locale-gen \
	&& curl -sSL https://getcomposer.org/composer.phar > /usr/local/bin/composer \
	&& chmod +x /usr/local/bin/composer \
	&& sed -e "s|listen = /var/run/php5-fpm.sock|listen = 127.0.0.1:9000|g;" -i /etc/php5/fpm/pool.d/www.conf \
	&& sed -e "s|error_log /var/log/nginx/error.log;|error_log /var/log/nginx/error.log;\n    log_format  main  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '\n                  '\$status \$body_bytes_sent \"\$http_referer\" '\n                  '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';|g" -i /etc/nginx/nginx.conf \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& rm /etc/nginx/sites-enabled/default \
	&& ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/


# This variable is overridable when building: docker build --build-arg SILVERSTRIPE_VERSION=3.x.y -t gambitlabs/silverstripe:3.x.y .
ARG SILVERSTRIPE_VERSION=3.4.0

# Install SilverStripe via composer
RUN rm -r ${DEST_DIR} && composer create-project silverstripe/installer ${DEST_DIR} ${SILVERSTRIPE_VERSION}

# Copy over important configuration files
COPY nginx-silverstripe.conf /etc/nginx/silverstripe.conf
COPY nginx-default.conf /etc/nginx/sites-available/default

# This script is executed by default when the docker container starts
COPY docker-entrypoint.sh /
CMD ["/docker-entrypoint.sh"]

# If this is used as a base image, copy the current directory into the source directory
ONBUILD ADD . ${SOURCE_DIR}
