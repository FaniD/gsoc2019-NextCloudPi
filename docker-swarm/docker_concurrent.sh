#!/bin/bash

# test id
workers="${1:-2}"

echo $'{
  "max-concurrent-downloads": ${workers}
}' | sudo tee /etc/docker/daemon.json
sudo service docker restart
