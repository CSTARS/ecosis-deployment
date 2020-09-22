#! /bin/bash

###
# Submit a new build to google cloud.  While this repository is wired
# up to CI triggers, it can be usefull in development to manually cut
# docker images without having to commit code.
###

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR/..

echo "Submitting build to Google Cloud..."
gcloud builds submit \
  --config ./gcloud/cloudbuild.yaml \
  --substitutions=REPO_NAME=$(basename $(git remote get-url origin)),TAG_NAME=$(git describe --tags --abbrev=0),BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD),SHORT_SHA=$(git log -1 --pretty=%h) \
  .