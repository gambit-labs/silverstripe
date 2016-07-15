FROM debian:jessie

# Install all necessary packages and upgrade the current debian distro
COPY nginx/pgp.key /etc/nginx/pgp.key
RUN echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" > /etc/apt/sources.list.d/nginx.list \
	&& apt-key add /etc/nginx/pgp.key \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get -yy -q install --no-install-recommends \
	curl \
	git \
	ca-certificates \
	locales \
	mysql-client \
	nginx \
	patch \
	php5 \
	php5-cli \
	php5-cgi \
	php5-common \
	php5-curl \
	php5-fpm \
	php5-gd \
	php5-json \
	php5-mysqlnd \
	php5-tidy \
	sendmail \
	socat \
	&& DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# The user should mount the site repository into SOURCE_DIR. The relevant parts of SOURCE_DIR will be copied to WWW_DIR, where nginx is serving
ENV SOURCE_DIR=/source \
	WWW_DIR=/var/www \
	CERT_DIR=/certs \
	SS_OVERRIDE_DIR=/etc/nginx/silverstripe.d

# Set locale, download composer, config php5-fpm to use localhost:9000, redirect access.log and error.log to std{out,err} and enable the default site
RUN sed -e "s|# sv_FI.UTF-8|sv_FI.UTF-8|g;s|# fi_FI.UTF-8|fi_FI.UTF-8|g;s|# en_US.UTF-8|en_US.UTF-8|g" -i /etc/locale.gen \
	&& locale-gen \
	&& curl -sSL https://getcomposer.org/composer.phar > /usr/local/bin/composer \
	&& chmod +x /usr/local/bin/composer \
	&& sed -e "s|listen = /var/run/php5-fpm.sock|listen = 127.0.0.1:9000|g;" -i /etc/php5/fpm/pool.d/www.conf \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stdout /var/log/php5-fpm.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& rm -f /etc/nginx/conf.d/default.conf \
	&& mkdir -p ${SOURCE_DIR} ${WWW_DIR} ${CERT_DIR} ${SS_OVERRIDE_DIR}

# This variable is overridable when building: docker build --build-arg SILVERSTRIPE_VERSION=3.x.y -t gambitlabs/silverstripe:3.x.y .
ARG SILVERSTRIPE_VERSION=3.4.0

# Install SilverStripe via composer and remove unnecessary files
RUN rm -r ${WWW_DIR} && composer create-project --no-dev silverstripe/installer ${WWW_DIR} ${SILVERSTRIPE_VERSION} \
	&& composer clear-cache \
	&& cd ${WWW_DIR} \
	&& find cms -maxdepth 1 -type f | grep -v "php" | xargs rm \
	&& find framework -maxdepth 1 -type f | grep -v "php" | grep -v sake | xargs rm \
	&& ([ -d reports ] && find reports -maxdepth 1 -type f | grep -v "php" | xargs rm || echo "ok") \
	&& ([ -d siteconfig ] && find siteconfig -maxdepth 1 -type f | grep -v "php" | xargs rm || echo "ok") \
	&& find themes/simple -maxdepth 1 -type f | xargs rm \
	&& rm -rf \
	README.md .editorconfig \
	cms/.tx framework/.tx siteconfig/.tx \
	web.config assets/web.config \
	.gitignore assets/.gitignore \
	.htaccess assets/.htaccess mysite/.htaccess \
	composer.json composer.lock \
	install-frameworkmissing.html \
	&& echo "${SILVERSTRIPE_VERSION}" > ${WWW_DIR}/framework/silverstripe_version \
	&& echo "${SILVERSTRIPE_VERSION}" > ${WWW_DIR}/cms/silverstripe_version

ENV SILVERSTRIPE_VERSION=${SILVERSTRIPE_VERSION}
# Copy over important configuration files
COPY nginx/nginx.conf nginx/silverstripe.conf nginx/ssl.conf nginx/php.conf /etc/nginx/
COPY nginx/http-default.conf /etc/nginx/sites-available/default-http
COPY nginx/https-default.conf /etc/nginx/sites-available/default-https

# This script is executed by default when the docker container starts
COPY docker-entrypoint.sh /
CMD ["/docker-entrypoint.sh"]

# If this is used as a base image, copy the current directory into the source directory
ONBUILD ADD . ${SOURCE_DIR}
