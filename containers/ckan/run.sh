#! /bin/bash

set -e

# start postfix
postconf -e "myorigin = ecosis.org"
postconf -e "myhostname = ecosis.org"
service postfix start

# let PG and Solr start up
# TODO: add wait-for script
sleep 10

# copy the template file
if [ ! -f /etc/ckan/docker.ini ]; then
  echo "Initializing ini file"
  cp /etc/ckan/template.ini /etc/ckan/docker.ini

  # move to paster root
  cd /ckan/src/ckan

  if [[ ! -z "$SESSION_SECRET" ]] ; then 
    echo "SESSION_SECRET not set";
    exit -1;
  fi
  if [[ ! -z "$INSTANCE_UUID" ]] ; then 
    echo "INSTANCE_UUID not set";
    exit -1;
  fi
  if [[ ! -z "$PG_CONN_STR" ]] ; then 
    $PG_CONN_STR = "postgresql://ckan_default:ckan_default@postgres/ckan_default";
  fi
  if [[ ! -z "$MONGO_CONN_STR" ]] ; then 
    $MONGO_CONN_STR = "mongodb://mongo:27017/";
  fi
  if [[ ! -z "$SOLR_URL" ]] ; then 
    $SOLR_URL = "http://solr:8983/solr/ckan";
  fi
  if [[ ! -z "$SITE_URL" ]] ; then 
    echo "SITE_URL not set";
    exit -1;
  fi
  if [[ ! -z "$SITE_ID" ]] ; then 
    echo "SITE_ID not set";
    exit -1;
  fi
  if [[ ! -z "$SEARCH_URL" ]] ; then 
    echo "SEARCH_URL not set";
    exit -1;
  fi
  if [[ ! -z "$DOI_URL" ]] ; then echo "DOI_URL not set";
  if [[ ! -z "$DOI_SHOULDER" ]] ; then echo "DOI_SHOULDER not set";
  if [[ ! -z "$DOI_USERNAME" ]] ; then echo "DOI_USERNAME not set";
  if [[ ! -z "$DOI_PASSWORD" ]] ; then echo "DOI_PASSWORD not set";
  if [[ ! -z "$REMOTE_HOSTS" ]] ; then echo "REMOTE_HOSTS not set";
  if [[ ! -z "$JWT_SECRET" ]] ; then 
    echo "JWT_SECRET not set";
    exit -1;
  fi

  # apply runtime arguments
  paster config-tool /etc/ckan/docker.ini "beaker.session.secret=$SESSION_SECRET"
  paster config-tool /etc/ckan/docker.ini "app_instance_uuid={$INSTANCE_UUID}"
  paster config-tool /etc/ckan/docker.ini "ckan.site_url=$SITE_URL"
  paster config-tool /etc/ckan/docker.ini "ckan.site_id=$SITE_ID"

  paster config-tool /etc/ckan/docker.ini "ecosis.mongo.url=$MONGO_CONN_STR"
  paster config-tool /etc/ckan/docker.ini "sqlalchemy.url=$PG_CONN_STR"
  paster config-tool /etc/ckan/docker.ini "solr_url=$SOLR_URL"

  paster config-tool /etc/ckan/docker.ini "ecosis.search_url=$SEARCH_URL"
  paster config-tool /etc/ckan/docker.ini "ecosis.doi.url=$DOI_URL"
  paster config-tool /etc/ckan/docker.ini "ecosis.doi.shoulder=$DOI_SHOULDER"
  paster config-tool /etc/ckan/docker.ini "ecosis.doi.username=$DOI_USERNAME"
  paster config-tool /etc/ckan/docker.ini "ecosis.doi.password=$DOI_PASSWORD"
  paster config-tool /etc/ckan/docker.ini "ecosis.remote_hosts=$REMOTE_HOSTS"
  paster config-tool /etc/ckan/docker.ini "ecosis.jwt.secret=$JWT_SECRET"
fi
  
EXISTS=`psql -U postgres -h postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='ckan_default'"`

# is this the first time we are running?  If so init the stack
if [ "$EXISTS" != "1" ]; then
  echo "Initializing CKAN"

  # add default user
  createuser -U postgres -h postgres -S -D -R ckan_default
  psql -U postgres -h postgres -c "ALTER ROLE ckan_default WITH PASSWORD 'ckan_default';"
  createdb -U postgres -h postgres -O ckan_default ckan_default -E utf-8
  paster db init -c /etc/ckan/docker.ini

  # ensure docker directories 
  mkdir -p /var/lib/ckan/resources
  mkdir -p /var/lib/ckan/storage
  mkdir -p /var/lib/ckan/workspace
fi

#paster --plugin=ckan search-index rebuild --config=/etc/ckan/docker.ini
#paster db upgrade --config=/etc/ckan/docker.ini
paster serve /etc/ckan/docker.ini