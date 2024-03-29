#! /bin/bash

set -e

# copy the template file
# if [ ! -f /etc/ckan/docker.ini ]; then
  CWD=$(pwd)

  echo "Initializing ini file"
  cp /etc/ckan/template.ini /etc/ckan/docker.ini

  # move to ckan root
  cd /ckan/src/ckan

  if [[ -z "$SESSION_SECRET" ]] ; then 
    echo "SESSION_SECRET not set";
    exit -1;
  fi
  if [[ -z "$INSTANCE_UUID" ]] ; then 
    echo "INSTANCE_UUID not set";
    exit -1;
  fi
  if [[ -z "$PG_CONN_STR" ]] ; then 
    PG_CONN_STR="postgresql://ckan_default:ckan_default@postgres/ckan_default";
  fi
  if [[ -z "$MONGO_CONN_STR" ]] ; then 
    MONGO_CONN_STR="mongodb://mongo:27017/";
  fi
  if [[ -z "$SOLR_URL" ]] ; then 
    SOLR_URL="http://solr:8983/solr/ckan";
  fi
  if [[ -z "$REDIS_URL" ]] ; then 
    REDIS_URL="redis://redis:6379/0";
  fi
  if [[ -z "$SITE_URL" ]] ; then 
    echo "SITE_URL not set";
    exit -1;
  fi
  if [[ -z "$SITE_ID" ]] ; then 
    echo "SITE_ID not set";
    exit -1;
  fi
  if [[ -z "$SEARCH_URL" ]] ; then 
    echo "SEARCH_URL not set";
    exit -1;
  fi
  if [[ -z "$JWT_SECRET" ]] ; then 
    echo "JWT_SECRET not set";
    exit -1;
  fi
  if [[ -z "$DOI_URL" ]] ; then echo "DOI_URL not set"; fi
  if [[ -z "$DOI_SHOULDER" ]] ; then echo "DOI_SHOULDER not set"; fi
  if [[ -z "$DOI_USERNAME" ]] ; then echo "DOI_USERNAME not set"; fi
  if [[ -z "$DOI_PASSWORD" ]] ; then echo "DOI_PASSWORD not set"; fi
  if [[ -z "$REMOTE_HOSTS" ]] ; then echo "REMOTE_HOSTS not set"; fi
  if [[ -z "$SMTP_TLS" ]] ; then SMTP_TLS=False; fi

  # apply runtime arguments
  ckan config-tool /etc/ckan/docker.ini "beaker.session.secret=$SESSION_SECRET" &>/dev/null
  ckan config-tool /etc/ckan/docker.ini "app_instance_uuid=$INSTANCE_UUID"
  ckan config-tool /etc/ckan/docker.ini "ckan.site_url=$SITE_URL"
  ckan config-tool /etc/ckan/docker.ini "ckan.site_id=$SITE_ID"
  ckan config-tool /etc/ckan/docker.ini "ckan.google_analytics_code=$DATA_GOOGLE_ANALYTICS_KEY"
  ckan config-tool /etc/ckan/docker.ini "api_token.jwt.encode.secret=string:$JWT_SECRET" &>/dev/null
  ckan config-tool /etc/ckan/docker.ini "api_token.jwt.decode.secret=string:$JWT_SECRET" &>/dev/null

  ckan config-tool /etc/ckan/docker.ini "ecosis.mongo.url=$MONGO_CONN_STR"
  ckan config-tool /etc/ckan/docker.ini "sqlalchemy.url=$PG_CONN_STR"
  ckan config-tool /etc/ckan/docker.ini "solr_url=$SOLR_URL"
  ckan config-tool /etc/ckan/docker.ini "ckan.redis.url=$REDIS_URL"

  ckan config-tool /etc/ckan/docker.ini "ecosis.search_url=$SEARCH_URL"
  ckan config-tool /etc/ckan/docker.ini "ecosis.doi.url=$DOI_URL"
  ckan config-tool /etc/ckan/docker.ini "ecosis.doi.shoulder=$DOI_SHOULDER"
  ckan config-tool /etc/ckan/docker.ini "ecosis.doi.username=$DOI_USERNAME"
  ckan config-tool /etc/ckan/docker.ini "ecosis.doi.password=$DOI_PASSWORD" &>/dev/null
  ckan config-tool /etc/ckan/docker.ini "ecosis.remote_hosts=$REMOTE_HOSTS"
  ckan config-tool /etc/ckan/docker.ini "ecosis.jwt.secret=$JWT_SECRET" &>/dev/null

  ckan config-tool /etc/ckan/docker.ini "smtp.server=$SMTP_SERVER"
  ckan config-tool /etc/ckan/docker.ini "smtp.user=$SMTP_USERNAME"
  ckan config-tool /etc/ckan/docker.ini "smtp.password=$SMTP_PASSWORD" &>/dev/null
  ckan config-tool /etc/ckan/docker.ini "smtp.starttls=$SMTP_TLS"

  cd $CWD
# fi