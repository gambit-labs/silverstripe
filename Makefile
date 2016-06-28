# Gambit Labs SmartTrack 2016

BASE_IMAGE?=gambitlabs/silverstripe
PORT?=80

deploy-site-locally: package-site
	docker run -d -p $(PORT):80 \
		--link $(shell docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
		-e SS_DATABASE_SERVER=db \
		-v $(shell pwd):/source \
		$(SITE_REPO):$(SITE_VERSION)

EDIT_DIR?=$(shell pwd)/live
deploy-site-editable: package-site
	docker run -d -p $(PORT):80 \
		--link $(shell docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
		-e SS_DATABASE_SERVER=db \
		-e DEV_MODE=1 -v $(EDIT_DIR):/live \
		-v $(shell pwd):/source \
		$(SITE_REPO):$(SITE_VERSION)

SITE_NAME=$(shell echo $(SITE_REPO) | cut -d/ -f2)
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

TMP_DOCKERFILE:=$(shell mktemp $(SITE_DIR)/Dockerfile.XXXXX)
package-site:

ifndef SITE_DIR
    $(error SITE_DIR is undefined)
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
