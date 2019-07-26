#!/bin/bash

test=""

# System setup: Manager and Worker nodes
# In case of multiple IPs, user is asked to provide one or one will be picked randomly
# fix it to identify if there are multiple IPs on host
echo -e "\n================================================\n"
echo -e "Specify leader's IP address or type 'any' to pick\nany listening address of the system (<IP>/any):"
read leader
if [[ $leader == "any" ]]; then 
  docker node ls 2> /dev/null | grep "Leader"
  leader_IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
  if [ $? -ne 0 ]; then
    echo "IP ${leader_IP} on device is already used on a swarm system. Re-run and specify another one."
    exit 0
  fi
else 
  leader_IP=$leader
fi
leader_name=$(hostname)

# Initialize swarm system with host as Leader (manager)
echo -e "\nCreating swarm system . . ."
docker swarm init --advertise-addr ${leader_IP}

# Visualizer option (localhost:5000)
echo -e "Run visualizer (localhost:5000) . . ."
docker run -it -d -p 5000:8080 -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer

# Registry option
#docker service create --name registry --publish published=5001,target=5001 registry:2
#docker-compose push

echo -e "\n================================================\n"
echo -e "Choose one of the options described below.\n"
echo -e "(1) I want to use existing machines"
echo -e "\tChoosing this option, you will have to provide a list\n\tof IPs and add manually every node to swarm system and\n\tgluster cluster by following the insctructions provided.\n"
echo -e "(2) Vagrant option\n\tAutomatically create new VMs and add them to swarm\n\tand gluster cluster. Feel free to change the specs\n\tof each VM through the Vagrantfile provided."
echo -e "\nType 1 or 2:"
read option
echo -e "\n================================================\n"
echo "Enter number of workers:"
read num_workers
replicas=$((num_workers + 1))

if [[ $option == 1 ]]; then
  echo -e "\n================================================\n"
  echo -e "Provide each node's IP address line per line\n"
  ip_list=[]
  for(( i=1; i<="$num_workers"; i++)); do
    read node_ip
    ip_list+=${node_ip}
  done
fi

# worker token
worker_join_token=$(docker swarm join-token -q worker)

# GlusterFS cluster's network
echo -e "Creating overlay network for gluster cluster . . ."
docker network create -d overlay --attachable netgfsc

# Init some dirs
sudo mkdir /etc/glusterfs
sudo mkdir /var/lib/glusterd
sudo mkdir /var/log/glusterfs
sudo mkdir -p /bricks/brick1/gv0

sudo mkdir swstorage
sudo mount --bind ./swstorage ./swstorage # there won't be an ncp on host, just plain storage
sudo mount --make-shared ./swstorage

echo -e "Creating gluster server on manager's node . . ."
docker run --restart=always --name gfsc0 -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=$(pwd)/swstorage,target=$(pwd)/swstorage,bind-propagation=rshared -d --privileged=true --net=netgfsc -v /dev/:/dev gluster/gluster-centos

echo -e "\n=============================================="
echo -e "\nExecute the following command on every machine\nyou want to add to the swarm cluster:\n"
echo -e "\tdocker swarm join --token ${worker_join_token} ${leader_IP}:2377\n\n"
if [[ $option == 1 ]]; then
  echo "Type ready when every node is added . . ."
  while true; do
    read ready
    if [[ $ready == "ready" || $ready == "Ready" ]] ; then
      break
    fi
    echo -e "Type ready when every node is added . . ."
  done
else
  # Create vagrant workers and add to swarm
  echo -e "Creating vagrant workers..."
  for(( i=1; i<="$num_workers"; i++)); do
    ./new_worker_vagrant.sh ${leader_IP}
    cd vagrant_workers/worker${i}
    vagrant up
    vagrant ssh -c "docker swarm join --token ${worker_join_token} ${leader_IP}:2377"
    cd ../..
  done
fi

echo -e "Creating NCP stack on swarm system . . ."
# Set manager to drain so that ncp replicas are distributed to workers
docker node update --availability drain ${leader_name}

# Stack NCP start
docker deploy --compose-file ../docker-compose.yml NCP${test}
docker service scale NCP${test}_nextcloudpi=${num_workers}

docker node update --availability active ${leader_name}

# Setup gluster server on each node
echo -e "Setting up gluster server on each worker . . ."

if [[ $option == 2 ]]; then
  for(( i=1; i<="$num_workers"; i++)); do
    cd vagrant_workers/worker${i}
    vagrant ssh -c "./gluster_setup.sh ${test}"
    cd ../..
  done
else
  # Message to workers to create their gluster container
  echo -e "\n=============================================="
  echo -e "\nExecute the following commands on every worker\nnode of the swarm cluster.\nAlternatively, you can use script gluster_setup.sh.\n"
  echo -e "In the last command, gfsc<X> should be replaced with the id number of each worker\n"
  echo -e "sudo mount --bind /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files\n"
  echo -e "sudo mount --make-shared /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files\n"
  echo -e "docker run --restart=always --name gfsc<X> -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files,target=/var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files,bind-propagation=rshared -d --privileged=true --net=netgfsc -v /dev/:/dev gluster/gluster-centos"
  echo -e "\nType ready when all workers are running gluster container . . ."
  while true; do
    read ready
    if [[ $ready == "ready" || $ready == "Ready" ]] ; then
      break
    fi
      echo -e "Type ready when all workers are running gluster container . . ."
  done
fi

# Gluster volume setup
echo -e "Creating gluster volume . . ."
replicas_gfs=""
for(( i=1; i<="$num_workers"; i++)); do
  # Connect node's gluster container to the gluster cluster
  docker exec -it gfsc0 gluster peer probe gfsc${i}
  replicas_gfs+="gfsc${i}:/bricks/brick1/gv0 "
done

# Create replicated volume
docker exec -it gfsc0 gluster volume create gv0 replica ${replicas} gfsc0:/bricks/brick1/gv0 ${replicas_gfs}
docker exec -it gfsc0 gluster volume start gv0
docker exec -it gfsc0 mount.glusterfs gfsc0:/gv0 $(pwd)/swstorage

if [[ $option == 2 ]]; then
  for(( i=1; i<="$num_workers"; i++)); do
    cd vagrant_workers/worker${i}
    vagrant ssh -c "./gluster_volume.sh ${test}"
    cd ../..
  done
else
  echo -e "\n=============================================="
  echo -e "\nExecute the following command on every node\nworker to mount the gluster volume.\nAlternatively you can use script gluster_volume.sh.\n"
  echo -e "docker exec -it gfsc<X> mount.glusterfs gfsc<X>:/gv0 /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files\n"
  echo -e "Type ready when volume is mounted on every gluster server\n"
  while true; do
    read ready
    if [[ $ready == "ready" || $ready == "Ready" ]] ; then
      break
    fi
    echo -e "Type ready when volume is mounted on every gluster server . . ."
  done
fi
