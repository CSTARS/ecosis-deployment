#! /bin/bash

###
# Init the /repositories folder with symbolic links to folders that exist in the same parent
# directory as this rp-ucd-deployment folder.
# Note: This script does not checkout any repository, it simply cleans the /repositories folders
# and makes the symbolic links
###

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR/..

source ./config.sh

if [ -d "./repositories" ]; then
  rm -rf ./repositories
fi
mkdir ./repositories

cd ./repositories
for repo in "${ALL_GIT_REPOSITORIES[@]}"; do
  ln -s ../../$repo .
done