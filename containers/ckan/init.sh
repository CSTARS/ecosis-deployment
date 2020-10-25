#! /bin/bash

set -e

EXISTS=`psql -U postgres -h postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='ckan_default'"`

# is this the first time we are running?  If so init the stack
if [ "$EXISTS" != "1" ]; then
  echo "Initializing CKAN"

  cd /ckan/src/ckan

  # for local dev
  if [ ! -f /etc/ckan/docker.ini ]; then
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

    paster config-tool /etc/ckan/docker.ini "ecosis.mongo.url=$MONGO_CONN_STR"
    paster config-tool /etc/ckan/docker.ini "sqlalchemy.url=$PG_CONN_STR"
    paster config-tool /etc/ckan/docker.ini "solr_url=$SOLR_URL"
  fi

  

  # add default user
  createuser -U postgres -h postgres -S -D -R ckan_default
  psql -U postgres -h postgres -c "ALTER ROLE ckan_default WITH PASSWORD 'ckan_default';"
  createdb -U postgres -h postgres -O ckan_default ckan_default -E utf-8
  paster db init -c /etc/ckan/docker.ini

  # init the ecosis plugin tables
  paster --plugin=ckanext-ecosis initdb -c /etc/ckan/docker.ini

  # ensure docker directories 
  mkdir -p /var/lib/ckan/resources
  mkdir -p /var/lib/ckan/storage
  mkdir -p /var/lib/ckan/workspace
fi