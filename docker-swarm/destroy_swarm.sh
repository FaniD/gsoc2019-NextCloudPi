#!/bin/bash

test="${1:-""}"

# If docker-machines exist only for this swarm, num of workers equals machines
# Otherwise needs num as input
workers=$(ls vagrant_workers | wc -l)
workers=$((workers - 1))
num_workers="${2:-$workers}"

for((i=1; i<="$num_workers"; i++)); do
  cd vagrant_workers/worker${i}
  vagrant halt
  cd ../..
done

sudo rm -r vagrant_workers/worker*

# Kill visualizer
visualizer=$(docker ps | grep dockersamples/visualizer)
visualizer_id=$(cut -d' ' -f1 <<<"$visualizer")
docker kill ${visualizer_id}

docker swarm leave --force

# Kill gluster
docker kill gfsc0
docker rm gfsc0

docker network rm netgfsc

sudo rm -r /etc/glusterfs
sudo rm -r /var/lib/glusterd
sudo rm -r /var/log/glusterfs

sudo rm -r /bricks/brick1/gv0

sudo umount swstorage
sudo rm -r swstorage
docker volume rm NCP${test}_ncdata
