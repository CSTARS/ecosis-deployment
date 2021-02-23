#! /bin/bash

set -e

EXISTS=`psql -U postgres -h postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='ckan_default'"`

# is this the first time we are running?  If so init the stack
if [ "$EXISTS" != "1" ]; then
  echo "Initializing CKAN"

  cd /ckan/src/ckan

  # add default user
  createuser -U postgres -h postgres -S -D -R ckan_default
  psql -U postgres -h postgres -c "ALTER ROLE ckan_default WITH PASSWORD 'ckan_default';"
  createdb -U postgres -h postgres -O ckan_default ckan_default -E utf-8
  # paster db init -c /etc/ckan/docker.ini
  ckan -c /etc/ckan/docker.ini db init

  # init the ecosis plugin tables
  # paster --plugin=ckanext-ecosis initdb -c /etc/ckan/docker.ini
  ckan -c /etc/ckan/docker.ini ecosis initdb 

  # ensure docker directories 
  mkdir -p /var/lib/ckan/resources
  mkdir -p /var/lib/ckan/storage
  mkdir -p /var/lib/ckan/workspace
fi