#! /bin/bash

set -e

# start postfix
postconf -e "myorigin = ecosis.org"
postconf -e "myhostname = ecosis.org"
service postfix start

# let PG and Solr start up
# TODO: add wait-for script
sleep 10

./setup-ini.sh
./init-pg.sh

#paster --plugin=ckan search-index rebuild --config=/etc/ckan/docker.ini
#paster db upgrade --config=/etc/ckan/docker.ini
paster serve /etc/ckan/docker.ini