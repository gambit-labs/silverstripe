#!/bin/bash

# The IMAGE_AUTHOR field is overridable, if you specify your own Docker Hub name, the script will push the images to your account
IMAGE_AUTHOR=${IMAGE_AUTHOR:-gambitlabs}
IMAGE_NAME=${IMAGE_NAME:-silverstripe}
IMAGE_REVISION=${IMAGE_REVISION:-3}
IMAGE_REPO=${IMAGE_AUTHOR}/${IMAGE_NAME}

# Flag if the script should push the images
PUSH=${PUSH:-0}

# The latest SilverStripe versions for all minor releases
LATEST_MINOR_SS_VERSIONS=(
	3.4.0
	3.3.2
	3.2.4
	3.1.19
	3.0.14
)
VERSIONS=${VERSIONS:-${LATEST_MINOR_SS_VERSIONS[@]}}

# Login on beforehand if we should push
if [[ ${PUSH} == 1 ]]; then
	echo "Logging into Docker Hub. Please specify your password for the user ${IMAGE_AUTHOR}"
	docker login -u ${IMAGE_AUTHOR}
fi

# Loop through the array
for version in ${VERSIONS}; do

	# Build a specific version of SilverStripe, and tag it as the latest one for the minor release 3.x
	docker build --build-arg SILVERSTRIPE_VERSION=${version} -t ${IMAGE_REPO}:${version}-${IMAGE_REVISION} .
	docker tag ${IMAGE_REPO}:${version}-${IMAGE_REVISION} ${IMAGE_REPO}:${version}
	docker tag ${IMAGE_REPO}:${version}-${IMAGE_REVISION} ${IMAGE_REPO}:$(echo ${version} | cut -d. -f1-2)

	# And push the images if we're told to do that
	if [[ ${PUSH} == 1 ]]; then
		docker push ${IMAGE_REPO}:${version}-${IMAGE_REVISION}
		docker push ${IMAGE_REPO}:${version}
		docker push ${IMAGE_REPO}:$(echo ${version} | cut -d. -f1-2)
	fi
done
