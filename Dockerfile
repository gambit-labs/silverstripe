FROM gambitlabs/lemp-base:v0.4.0

# The user should mount the site repository into SOURCE_DIR. The relevant parts of SOURCE_DIR will be copied to WWW_DIR, where nginx is serving
ENV SOURCE_DIR=/source \
	SS_OVERRIDE_DIR=/etc/nginx/silverstripe.d

RUN curl -sSL https://getcomposer.org/composer.phar > /usr/local/bin/composer \
	&& chmod +x /usr/local/bin/composer \
	&& mkdir -p ${SOURCE_DIR} ${SS_OVERRIDE_DIR}

# This variable is overridable when building: docker build --build-arg SILVERSTRIPE_VERSION=3.x.y -t gambitlabs/silverstripe:3.x.y .
ARG SILVERSTRIPE_VERSION=3.4.0
ENV SILVERSTRIPE_VERSION=${SILVERSTRIPE_VERSION}

# Install SilverStripe via composer and remove unnecessary files. Also install git because composer might need it.
RUN apk --update add git \
	&& rm -r ${WWW_DIR} && composer create-project --no-dev silverstripe/installer ${WWW_DIR} ${SILVERSTRIPE_VERSION} \
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

# Copy over the silverstripe configuration and the entrypoint script
COPY silverstripe.conf /etc/nginx/conf.d/
COPY ss-entrypoint.sh /
ENTRYPOINT ["/ss-entrypoint.sh"]

# If this is used as a base image, copy the current directory into the source directory
ONBUILD ADD . ${SOURCE_DIR}
