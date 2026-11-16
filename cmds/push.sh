#! /bin/bash

###
# Push docker image and $DOCKER_CACHE_TAG (currently :latest) tag to docker hub
###

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR/..
source config.sh

docker push $SEARCH_IMAGE_NAME:$SEARCH_TAG
docker tag $SEARCH_IMAGE_NAME:$SEARCH_TAG $SEARCH_IMAGE_NAME:$DOCKER_CACHE_TAG

docker push $CKAN_IMAGE_NAME:$CKAN_TAG
docker tag $CKAN_IMAGE_NAME:$CKAN_TAG $CKAN_IMAGE_NAME:$DOCKER_CACHE_TAG

docker push $DATA_IMAGE_NAME:$DATA_TAG
docker tag $DATA_IMAGE_NAME:$DATA_TAG $DATA_IMAGE_NAME:$DOCKER_CACHE_TAG

for image in "${ALL_DOCKER_BUILD_IMAGES[@]}"; do
  docker push $image:$DOCKER_CACHE_TAG || true
done