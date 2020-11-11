#! /bin/bash


# what we think the filesystem root is
root=""
script_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONF_FILE="$script_root/docker.ini"

if [ -n "$1" ]
then
	root=$1
	CONF_FILE="$script_root/default.ini"
fi


dir="$script_root/backup"
ZIP_FILE=ecosis_backup.zip

# prep tmp dir
echo "Preparing tmp dir: $dir"
if [ -d "$dir" ]; then
	rm -rf $dir
fi
mkdir $dir

if [ -f "$script_root/$ZIP_FILE" ]; then
	rm "$script_root/$ZIP_FILE"
fi

# init python virtual env for CKAN
if [ "$root" != "" ]; then
	echo "Initializing python virtual env for CKAN"
	. "$script_root/../../bin/activate"
fi

# paster info: http://docs.ckan.org/en/latest/maintaining/paster.html

# dump entire pg db
echo "Backing up CKAN PostgreSQL data"
paster --plugin=ckan db dump -c $CONF_FILE "$dir/pg_ckan_backup.sql"

# dump entire mongo db
echo "Backing up MongoDB data"
if [ "$root" != "" ]; then
	# currently the OSX mongodump stales out when exporting from mongo in docker...
	# this is the nasty workaround, for now.
	# TODO: fix this!
	docker exec ecosislocal_mongo_1 bash -c  'mongodump --out /data/backup --db ecosis'
	mkdir -p "$dir/mongodb_backup"
	mv "$root/data/backup/ecosis" "$dir/mongodb_backup"
else
	mongodump -h mongo --db ecosis --out "$dir/mongodb_backup"
fi

# link ckan data resources
mkdir -p "$dir/var/lib"
ln -s "$root/var/lib/ckan" "$dir/var/lib/"

echo "Compressing data"
cd $dir
zip -r ../$ZIP_FILE ./*

echo "cleanup"
cd .. && rm -rf $dir

mv $ZIP_FILE /io
echo "Zip Ready: $ZIP_FILE"
