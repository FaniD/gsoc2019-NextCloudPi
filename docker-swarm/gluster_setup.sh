#!/bin/bash

# test id
test="${1:-""}"

worker=$(echo $(hostname)|awk '{print substr($0,length($0),1)}')
worker_id="${2:-$worker}"

# The following commands should be run at each node worker

mkdir -p /bricks/brick1/gv0
mkdir -p /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm

mount --bind /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm
mount --make-shared /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm

docker run --restart=always --name gfsc${worker_id} -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm,target=/var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm,bind-propagation=rshared -d --privileged=true --net=netgfsc -v /dev/:/dev gluster/gluster-centos

docker start gfsc${worker_id}
