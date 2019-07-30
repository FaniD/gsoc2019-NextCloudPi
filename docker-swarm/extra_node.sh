#!/bin/bash

# test id
test="${1:-""}"

echo -e "Choose one of the options below:"
echo -e "(1) I will use an existing machine"
echo -e "\tThis option requires FIX LATER according to create swarm"
echo -e "(2) Create a new VM automatically"
read option

leader_name=$(hostname)
leader_IP=$(docker node inspect self --format '{{ .Status.Addr  }}')
replicas=$(ls vagrant_workers | wc -l)
worker_id=$(( replicas -1 ))

docker node update --availability drain ${leader_name}
docker service scale NCP${test}_nextcloudpi=${worker_id}

docker node update --availability active ${leader_name}

if [[ $option == 2 ]]; then
  ./new_worker_vagrant.sh ${leader_IP}
  cd vagrant_workers/worker${worker_id}
  vagrant up
  vagrant ssh -c "./gluster_setup.sh ${test}"
  cd ../..
fi

sleep 15

docker exec gfsc0 gluster peer probe gfsc${worker_id}
docker exec gfsc0 gluster volume add-brick gv0 replica ${replicas} gfsc${worker_id}:/bricks/brick1/gv0

sleep 15

if [[ $option == 2]]; then
  cd vagrant_workers/worker${worker_id}
  vagrant ssh -c "docker exec gfsc${worker_id} mount.glusterfs gfsc${worker_id}:/gv0 /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm"
  cd ../..
fi
