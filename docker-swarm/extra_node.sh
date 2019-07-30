#!/bin/bash

echo -e "Choose one of the options below:"
echo -e "(1) I will use an existing machine"
echo -e "\tThis option requires FIX LATER according to create swarm"
echo -e "(2) Create a new VM automatically"
read option

leader_IP=$(docker node inspect self --format '{{ .Status.Addr  }}')

if [[ $option == 2 ]]; then
  ./new_worker_vagrant.sh ${leader_IP}
  cd vagrant_workers/worker<new>
  vagrant up
  vagrant ssh
  ./gluster_setup.sh ${test}

worker_id="${1:-1}"

docker exec gfsc0 gluster peer probe gfsc${worker_id}

replicas=$(ls vagrant_workers | wc -l)

docker exec -it gfsc0 gluster volume add-brick gv0 replica ${replicas} gfsc${worker_id}:/bricks/brick1/gv0

echo -e "\nOn new node run the following command (or execute gluster_volume.sh)\n"
echo -e "docker exec -it gfsc${worker_id} mount.glusterfs gfsc${worker_id}:/gv0 /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files"

