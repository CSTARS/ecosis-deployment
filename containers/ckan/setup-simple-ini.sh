#! /bin/bash

set -e

# for local dev
if [ ! -f /etc/ckan/docker.ini ]; then
  CWD=$(pwd)

  cp /etc/ckan/template.ini /etc/ckan/docker.ini
  if [[ -z "$PG_CONN_STR" ]] ; then 
    PG_CONN_STR="postgresql://ckan_default:ckan_default@postgres/ckan_default";
  fi
  if [[ -z "$MONGO_CONN_STR" ]] ; then 
    MONGO_CONN_STR="mongodb://mongo:27017/";
  fi
  if [[ -z "$SOLR_URL" ]] ; then 
    SOLR_URL="http://solr:8983/solr/ckan";
  fi

  cd /ckan/src/ckan

  paster config-tool /etc/ckan/docker.ini "ecosis.mongo.url=$MONGO_CONN_STR"
  paster config-tool /etc/ckan/docker.ini "sqlalchemy.url=$PG_CONN_STR"
  paster config-tool /etc/ckan/docker.ini "solr_url=$SOLR_URL"

  cd $CWD
fi