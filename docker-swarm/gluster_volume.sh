#!/bin/bash

# test id
test="${1:-1}"

worker_id=$(echo $(hostname)|awk '{print substr($0,length($0),1)}')

docker exec gfsc${worker_id} mount.glusterfs gfsc${worker_id}:/gv0 /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm
