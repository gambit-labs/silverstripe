# Gambit Labs SmartTrack 2016

BASE_IMAGE?=gambitlabs/silverstripe
DEFAULT_VERSION=3.4
PORT?=80

deploy:
	docker run -d -p $(PORT):80 \
		--link $(shell docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
		-e SS_DATABASE_SERVER=db \
		$(BASE_IMAGE):$(DEFAULT_VERSION)

deploy-site-locally: package-site
	docker run -d -p $(PORT):80 \
		--link $(shell docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
		-e SS_DATABASE_SERVER=db \
		$(SITE_REPO):$(SITE_VERSION)

deploy-site-rw: package-site
	docker run -d -p $(PORT):80 \
		--link $(shell docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
		-e SS_DATABASE_SERVER=db \
		-e RW_MODE=1 -v $(SITE_DIR):/source \
		$(SITE_REPO):$(SITE_VERSION)

deploy-site-editable: package-site
	docker run -d -p $(PORT):80 \
		--link $(shell docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
		-e SS_DATABASE_SERVER=db \
		-e DEV_MODE=1 -v $(SITE_DIR)/live:/live \
		-v $(SITE_DIR):/source \
		$(SITE_REPO):$(SITE_VERSION)

SITE_NAME=$(shell basename $(SITE_REPO))
deploy-site-k8s: package-site
	sed -e "s|__REPO__|$(SITE_REPO)|g;s|__NAME__|$(SITE_NAME)|g;s|__VERSION__|$(SITE_VERSION)|g;" k8s.yaml | kubectl create -f - --validate=false

remove-site-k8s:

ifndef SITE_REPO
	$(error SITE_REPO is undefined)
endif
ifndef SITE_VERSION
	$(error SITE_VERSION is undefined)
endif
	@kubectl delete rc $(SITE_NAME)-$(SITE_VERSION)
	@kubectl delete svc $(SITE_NAME)

TMP_DOCKERFILE=$(shell mktemp $(SITE_DIR)/Dockerfile.XXXXX)
package-site:

ifndef SITE_DIR
	(error SITE_DIR is undefined)
endif
ifndef SITE_REPO
	$(error SITE_REPO is undefined)
endif
ifndef SITE_VERSION
	$(error SITE_VERSION is undefined)
endif
ifndef SS_VERSION
	$(error SS_VERSION is undefined)
endif
	echo "FROM $(BASE_IMAGE):$(SS_VERSION)" > $(TMP_DOCKERFILE)
	docker build -t $(SITE_REPO):$(SITE_VERSION) -f $(TMP_DOCKERFILE) $(SITE_DIR)
	rm $(TMP_DOCKERFILE)

#PHP_CONTAINER:=$(shell docker run -d --link $$(docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db -w / php:5-fpm-alpine)
#TMP_DIR:=$(shell mktemp -d /tmp/ss.XXXXX)
#deploy-php:
#	docker cp $(shell docker run -d -p $(PORT):80 --link $(PHP_CONTAINER):fpm -e SS_DATABASE_SERVER=db -e PHP_SERVER=fpm $(BASE_IMAGE):$(DEFAULT_VERSION)):/var/www $(TMP_DIR)
#	docker cp $(TMP_DIR)/www $(PHP_CONTAINER):/var/
#	docker exec -it $(PHP_CONTAINER) /bin/sh -c "chown -R www-data:www-data /var/www"
