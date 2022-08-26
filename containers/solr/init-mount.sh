#! /bin/bash

# this script goes in the /docker-entrypoint-initdb.d dir
# It must be run AFTER the container is started, when the
# data directory is mounted.  In docker this mount point
# is mounted as root, causing solr to fail
sudo chown -R solr:solr /opt/solr/server/solr/ckan/data