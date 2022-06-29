#! /bin/bash

set -e
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $ROOT

# start postfix
# postconf -e "myorigin = ecosis.org"
# postconf -e "myhostname = ecosis.org"
# service postfix start

# let PG and Solr start up
# TODO: add wait-for script
./wait-for-it.sh postgres:5432
./wait-for-it.sh solr:8983
./wait-for-it.sh redis:6379

./setup-ini.sh
./init-pg.sh

#paster --plugin=ckan search-index rebuild --config=/etc/ckan/docker.ini
#paster db upgrade --config=/etc/ckan/docker.ini

# cd /etc/ckan
# paster serve /etc/ckan/docker.ini
# ckan run --disable-reloader --host 0.0.0.0

gunicorn -w 4 --bind 0.0.0.0:5000 wsgi:application