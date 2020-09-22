#! /bin/bash

##
# Generate docker-compose deployment and local development files based on
# config.sh parameters
##

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR/../templates

source ../config.sh

# generate main dc file
content=$(cat deployment.yaml)
for key in $(compgen -v); do
  if [[ $key == "COMP_WORDBREAKS" || $key == "content" ]]; then
    continue;
  fi
  escaped=$(printf '%s\n' "${!key}" | sed -e 's/[\/&]/\\&/g')
  content=$(echo "$content" | sed "s/{{$key}}/${escaped}/g") 
done
echo "$content" > ../docker-compose.yaml

# generate k8s files
mkdir -p ../$GKE_CONFIG_DIR

INDEXER_IMAGE_NAME_ESCAPED=$(echo $INDEXER_IMAGE_NAME | sed 's/\//\\\//g')
API_IMAGE_NAME_ESCAPED=$(echo $API_IMAGE_NAME | sed 's/\//\\\//g')
GATEWAY_IMAGE_NAME_ESCAPED=$(echo $GATEWAY_IMAGE_NAME | sed 's/\//\\\//g')
AUTH_IMAGE_NAME_ESCAPED=$(echo $AUTH_IMAGE_NAME | sed 's/\//\\\//g')
CLIENT_IMAGE_NAME_ESCAPED=$(echo $CLIENT_IMAGE_NAME | sed 's/\//\\\//g')
DEBOUNCER_IMAGE_NAME_ESCAPED=$(echo $DEBOUNCER_IMAGE_NAME | sed 's/\//\\\//g')
FUSEKI_IMAGE_NAME_ESCAPED=$(echo $FUSEKI_IMAGE_NAME | sed 's/\//\\\//g')
KAFKA_IMAGE_NAME_ESCAPED=$(echo $KAFKA_IMAGE_NAME | sed 's/\//\\\//g')
ELASTIC_SEARCH_IMAGE_NAME_ESCAPED=$(echo $ELASTIC_SEARCH_IMAGE_NAME | sed 's/\//\\\//g')

# generate local development dc file
content=$(cat local-dev.yaml)
VESSEL_TAG='local-dev'
CLIENT_TAG='local-dev'
for key in $(compgen -v); do
  if [[ $key == "COMP_WORDBREAKS" || $key == "content" ]]; then
    continue;
  fi
  escaped=$(printf '%s\n' "${!key}" | sed -e 's/[\/&]/\\&/g')
  content=$(echo "$content" | sed "s/{{$key}}/${escaped}/g") 
done
if [ ! -d "../rp-local-dev" ]; then
  mkdir ../rp-local-dev
fi

echo "$content" > ../rp-local-dev/docker-compose.yaml