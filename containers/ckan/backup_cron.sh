#! /bin/bash

# if [[ -z "$BACKUP_ENV" ]] ; then 
#     echo "BACKUP_ENV not set";
#     exit -1;
# fi

# BACKUP_NAME="-$BACKUP_ENV"
# if [[ $BACKUP_ENV == "prod" ]] ; then
#     BACKUP_NAME=""
# fi

if [[ -z "$BACKUP_BUCKET" ]] ; then 
    echo "BACKUP_BUCKET not set";
    exit -1;
fi

ROOT=/backup
ZIP=$ROOT/ecosis_backup.zip

if [ -e $ZIP ]; then
  echo "removing old ecosis backup"
  rm -f $ZIP
fi

BACKUP_FILE=s3://$BACKUP_BUCKET-backups/ecosis_backup_`date -I`.zip
echo "running ecosis backup to $BACKUP_FILE"
/etc/ckan/create_backup.sh
aws s3 cp $ZIP $BACKUP_FILE
echo "ecosis backup complete"