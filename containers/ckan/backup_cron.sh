#! /bin/bash

if [[ -z "$BACKUP_ENV" ]] ; then 
    echo "BACKUP_ENV not set";
    exit -1;
fi

BACKUP_NAME="-$BACKUP_ENV"
if [[ $BACKUP_ENV == "prod" ]] ; then
    BACKUP_NAME=""
fi

ROOT=/backup
ZIP=$ROOT/ecosis_backup.zip

if [ -e $ZIP ]; then
  echo "removing old ecosis backup"
  rm -f $ZIP
fi

echo "running ecosis backup"
/etc/ckan/create_backup.sh
aws s3 cp $ZIP s3://ecosis$BACKUP_NAME-backups/ecosis_backup_`date -I`.zip
echo "ecosis backup complete"