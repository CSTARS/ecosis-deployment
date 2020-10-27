#! /bin/bash

set -e

root=""
script_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$script_root/setup-simple-ini.sh
$script_root/init-pg.sh
CONF_FILE="$script_root/docker.ini"

# if [ -n "$1" ]
# then
# 	root=$1
# 	CONF_FILE="$script_root/default.ini"
# fi

if [[ -z "$ZIP_FILE" ]] ; then 
	ZIP_FILE=/io/ecosis_backup.zip
fi

if [ ! -f "$ZIP_FILE" ]; then
	echo "The zip file doesn't exist: $ZIP_FILE"
	exit
fi

# init python virtual env for CKAN
if [ "$root" != "" ]; then
	echo "Initializing python virtual env for CKAN"
	. "$script_root/../../bin/activate"
fi

dir="$script_root/back_tmp"

if [ -d "$dir" ]; then
	rm -rf $dir
fi

echo "Unpacking backup"
unzip "$ZIP_FILE" -d $dir

# paster info: http://docs.ckan.org/en/latest/maintaining/paster.html

# dump entire pg db
echo "Cleaning CKAN DB"
paster --plugin=ckan db clean -c $CONF_FILE

# load backup entire pg db
echo "Loading CKAN backup"
paster --plugin=ckan db load -c $CONF_FILE "$dir/pg_ckan_backup.sql"

# Rebuild Solr
paster --plugin=ckan search-index rebuild -c $CONF_FILE
#paster db upgrade --config=/etc/ckan/docker.ini

echo "Loading MongoDB backup"
if [ "$root" != "" ]; then
	mongorestore --drop "$dir/mongodb_backup"
else
	mongorestore -h mongo --drop "$dir/mongodb_backup"
fi

echo "replacing CKAN file resources"
rm -rf $root/var/lib/ckan/*
cp -r $dir/var/lib/ckan/* $root/var/lib/ckan 

echo "cleanup"
rm -rf $dir