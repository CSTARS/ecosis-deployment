#! /bin/bash

###
# Init the /repositories folder with symbolic links to folders that exist in the same parent
# directory as this ecosis-ucd-deployment folder.
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

# CKAN source, mounted over /ckan/src/ckan by the local-dev compose file.
# It must exist and match the CKAN version installed in the image (CKAN_TAG),
# otherwise the `ckan` command in the container cannot import ckan.
git clone --depth 1 --branch ckan-$CKAN_TAG https://github.com/ckan/ckan.git ckan