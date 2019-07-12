#!/bin/bash

mkdir /etc/glusterfs
mkdir /var/lib/glusterd
mkdir /var/log/glusterfs

sudo mkdir /data
sudo mount --bind /data /data
sudo mount --make-shared /data

sudo mkdir -p /bricks/brick1/gv0

docker run --restart=always --name gfsc0 -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/data,target=/data,bind-propagation=rshared -d --privileged=true --net=netgfs -v /dev/:/dev gluster/gluster-centos
