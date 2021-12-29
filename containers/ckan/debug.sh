#! /bin/bash

if [ ! -f /etc/ckan/docker.ini ]; then
  /etc/ckan/setup-ini.sh 
fi

echo "Waiting for debugger to attach on port 5687"
python3 -m debugpy --listen 0.0.0.0:5678 --wait-for-client /etc/ckan/debug_server.py