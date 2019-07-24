#!/bin/bash

# test id
test="${1:-1}"

worker_id=$(echo $(hostname)|awk '{print substr($0,length($0),1)}')

# The following commands should be run at each node worker

sudo mkdir -p /bricks/brick1/gv0
sudo mkdir -p /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files

sudo mount --bind /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files
sudo mount --make-shared /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files

# The name could also change to something like hostname_worker_id
docker run --restart=always --name gfsc${worker_id} -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files,target=/var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files,bind-propagation=rshared -d --privileged=true --net=netgfsc -v /dev/:/dev gluster/gluster-centos

docker start gfsc${worker_id}
