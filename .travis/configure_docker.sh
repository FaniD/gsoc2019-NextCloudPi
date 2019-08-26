#!/bin/bash

set -o errexit

echo "INFO:
Updating docker configuration
"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
echo $'{
  "experimental": true,
  "storage-driver": "overlay2"
}' | sudo tee /etc/docker/daemon.json
sudo service docker restart

