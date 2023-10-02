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

SOLR_VERSION=$SOLR_TAG

# Additionally set local-dev tags used by 
# local development docker compose file
if [[ ! -z $LOCAL_BUILD ]]; then
  echo "local build"
  SEARCH_TAG='local-dev'
  DATA_TAG='local-dev'
  SOLR_TAG='local-dev'
fi

SEARCH_REPO_HASH=$(git -C $REPOSITORY_DIR/$SEARCH_REPO_NAME log -1 --pretty=%h)
DATA_REPO_HASH=$(git -C $REPOSITORY_DIR/$DATA_REPO_NAME log -1 --pretty=%h)

echo "building solr $SOLR_IMAGE_NAME:$SOLR_TAG"
echo "building ckan $CKAN_IMAGE_NAME:$CKAN_TAG"
echo "building ecosis data $DATA_IMAGE_NAME:$DATA_TAG"
echo "building ecosis search $SEARCH_IMAGE_NAME:$SEARCH_TAG"

# solr
echo "building solr $SOLR_IMAGE_NAME:$SOLR_TAG"
docker build \
  -t $SOLR_IMAGE_NAME:$SOLR_TAG \
  --build-arg SOLR_VERSION=${SOLR_VERSION} \
  --cache-from=$SOLR_IMAGE_NAME:$DOCKER_CACHE_TAG \
  ./containers/solr

# ckan
echo "building ckan $CKAN_IMAGE_NAME:$CKAN_TAG"
docker build \
  -t $CKAN_IMAGE_NAME:$CKAN_TAG \
  --build-arg CKAN_VERSION=${CKAN_TAG} \
  --cache-from=$CKAN_IMAGE_NAME:$DOCKER_CACHE_TAG \
  ./containers/ckan

# ecosis data
echo "building ecosis data $DATA_IMAGE_NAME:$DATA_TAG"
docker build \
  -t $DATA_IMAGE_NAME:$DATA_TAG \
  --build-arg CKAN_BASE=$CKAN_IMAGE_NAME:$CKAN_TAG \
  --cache-from=$DATA_IMAGE_NAME:$DOCKER_CACHE_TAG \
  $REPOSITORY_DIR/$DATA_REPO_NAME

# ecosis search
echo "building ecosis search $SEARCH_IMAGE_NAME:$SEARCH_TAG"
docker build \
  -t $SEARCH_IMAGE_NAME:$SEARCH_TAG \
  --cache-from=$SEARCH_IMAGE_NAME:$DOCKER_CACHE_TAG \
  $REPOSITORY_DIR/$SEARCH_REPO_NAME
