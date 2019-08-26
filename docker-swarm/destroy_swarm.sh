#!/bin/bash

test="${1:-""}"

# Kill visualizer
visualizer=$(docker ps | grep dockersamples/visualizer)
visualizer_id=$(cut -d' ' -f1 <<<"$visualizer")
docker kill ${visualizer_id}

docker swarm leave --force 

docker volume rm NCP${test}_ncdata
docker network rm netgfsc

# Kill gluster
docker kill gfsc0
docker rm gfsc0

sudo rm -r /etc/glusterfs
sudo rm -r /var/lib/glusterd
sudo rm -r /var/log/glusterfs

sudo rm -r /bricks/brick1/gv0

sudo umount swstorage
sudo rm -r swstorage
