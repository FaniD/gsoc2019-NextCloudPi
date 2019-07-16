#!/bin/bash

sudo mkdir /etc/glusterfs
sudo mkdir /var/lib/glusterd
sudo mkdir /var/log/glusterfs

# sudo mkdir /var/lib/docker/volumes/NCP_ncdata/_data/
sudo mount --bind /var/lib/docker/volumes/NCP5_ncdata/_data /var/lib/docker/volumes/NCP5_ncdata/_data
sudo mount --make-shared /var/lib/docker/volumes/NCP5_ncdata/_data

sudo mkdir -p /bricks/brick1/gv0

docker run --restart=always --name gfsc0 -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/var/lib/docker/volumes/NCP5_ncdata/_data,target=/var/lib/docker/volumes/NCP5_ncdata/_data,bind-propagation=rshared -d --privileged=true --net=netgfs -v /dev/:/dev gluster/gluster-centos
