#!/bin/bash

# test id
existing_workers=$(ls vagrant_workers | wc -l)
existing_workers=$((existing_workers - 1))
workers="${1:-$existing_workers}"

echo $"{
  "max-concurrent-downloads": ${workers}
}" | sudo tee /etc/docker/daemon.json
sudo service docker restart
