#! /bin/bash

######### DEPLOYMENT CONFIG ############
# Setup your application deployment here
########################################

# Main version number we are tagging the app with. Always update
# this when you cut a new version of the app!
APP_VERSION=v2.0.8

##
# TAGS
##

# Repository tags/branchs
# Tags should always be used for production deployments
# Branches can be used for development deployments
SEARCH_TAG=dev
DATA_TAG=dev

CKAN_TAG=2.6.2
POSTGRES_TAG=9.3
MONGO_TAG=3.4
SOLR_TAG=5.3

##
# Repositories
##

GITHUB_ORG_URL=https://github.com/cstars

# Search
SEARCH_REPO_NAME=ecosis
SEARCH_REPO_URL=$GITHUB_ORG_URL/$SEARCH_REPO_NAME

# Date
DATA_REPO_NAME=ckanext-ecosis
DATA_REPO_URL=$GITHUB_ORG_URL/$DATA_REPO_NAME

##
# Docker
##

# Docker Hub
ECOSIS_DOCKER_ORG=ecosis
DOCKER_CACHE_TAG="latest"

# Docker Images
SEARCH_IMAGE_NAME=$ECOSIS_DOCKER_ORG/ecosis-search
CKAN_IMAGE_NAME=$ECOSIS_DOCKER_ORG/ecosis-ckan
DATA_IMAGE_NAME=$ECOSIS_DOCKER_ORG/ecosis-data
SOLR_IMAGE_NAME=$ECOSIS_DOCKER_ORG/ecosis-solr

MONGO_IMAGE_NAME=mongo
POSTGRES_IMAGE_NAME=postgres

ALL_DOCKER_BUILD_IMAGES=( $SEARCH_IMAGE_NAME $CKAN_IMAGE_NAME \
 $DATA_IMAGE_NAME $SOLR_IMAGE_NAME )


# Git
##

ALL_GIT_REPOSITORIES=( $SEARCH_REPO_NAME $DATA_REPO_NAME )

# Git
GIT=git
GIT_CLONE="$GIT clone"

# directory we are going to cache our various git repos at different tags
# if using pull.sh or the directory we will look for repositories (can by symlinks)
# if local development
REPOSITORY_DIR=repositories