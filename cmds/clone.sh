#! /bin/bash

###
# Shallow clone repositories defined in config.sh
# WARNING: Used for gcloud builds.  This wipes
# respositories folders and starts fresh every time
###

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR/..
source config.sh

if [ -d $REPOSITORY_DIR ] ; then
  rm -rf $REPOSITORY_DIR
fi
mkdir -p $REPOSITORY_DIR

# search
$GIT_CLONE $SEARCH_REPO_URL.git \
  --branch $SEARCH_TAG \
  --depth 1 \
  $REPOSITORY_DIR/$SEARCH_REPO_NAME

# Data
$GIT_CLONE $DATA_REPO_URL.git \
  --branch $DATA_TAG \
  --depth 1 \
  $REPOSITORY_DIR/$DATA_REPO_NAME