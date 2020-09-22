#! /bin/bash

###
# Main build process to cutting production images
###

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR/..
source config.sh

# Use buildkit to speedup local builds
# Not supported in google cloud build yet
if [[ -z $CLOUD_BUILD ]]; then
  export DOCKER_BUILDKIT=1
fi

# Additionally set local-dev tags used by 
# local development docker-compose file
if [[ ! -z $LOCAL_BUILD ]]; then
  SEARCH_TAG='local-dev'
  DATA_TAG='local-dev'
fi

SEARCH_REPO_HASH=$(git -C $REPOSITORY_DIR/$SEARCH_REPO_NAME log -1 --pretty=%h)
DATA_REPO_HASH=$(git -C $REPOSITORY_DIR/$DATA_REPO_NAME log -1 --pretty=%h)

# solr
docker build \
  -t $SOLR_IMAGE_NAME:$SOLR_TAG \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from=$SOLR_IMAGE_NAME:$DOCKER_CACHE_TAG \
  ./containers/solr

# ckan
docker build \
  -t $CKAN_IMAGE_NAME:$CKAN_TAG \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg CKAN_VERSION=${CKAN_TAG} \
  --cache-from=$CKAN_IMAGE_NAME:$DOCKER_CACHE_TAG \
  ./containers/solr

# ecosis ckan
docker build \
  -t $DATA_IMAGE_NAME:$DATA_TAG \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg CKAN_BASE=$CKAN_IMAGE_NAME:$CKAN_TAG \
  --cache-from=$DATA_IMAGE_NAME:$DOCKER_CACHE_TAG \
  $REPOSITORY_DIR/$DATA_REPO_NAME

# ecosis search
docker build \
  -t $SEARCH_IMAGE_NAME:$SEARCH_TAG \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from=$SEARCH_IMAGE_NAME:$DOCKER_CACHE_TAG \
  $REPOSITORY_DIR/$SEARCH_REPO_NAME
