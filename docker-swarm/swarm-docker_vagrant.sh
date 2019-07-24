#!/bin/bash

test="24"

# System setup: Manager and Worker nodes
# In case of multiple IPs, user is asked to provide one or one will be picked randomly
# fix it to identify if there are multiple IPs on host
echo "Specify Leader's IP address. Type any to pick any listening address to the system:"
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
docker swarm init --advertise-addr ${leader_IP}

# Visualizer option (localhost:5000)
docker run -it -d -p 5000:8080 -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer

# Registry option
#docker service create --name registry --publish published=5001,target=5001 registry:2
#docker-compose push

echo "Enter number of workers:"
read num_workers
replicas=$((num_workers + 1))

# Create vagrant workers VMs option
for(( i=1; i<="$num_workers"; i++)); do
  ./new_worker_vagrant.sh ${leader_IP}
  cd vagrant_workers/worker${i} && vagrant up && cd ../..
done

# Setup Worker machines/nodes

worker_join_token=$(docker swarm join-token -q worker)

# Setup GlusterFS

# Cluster's network
docker network create -d overlay --attachable netgfsc

# Init some dirs
sudo mkdir /etc/glusterfs
sudo mkdir /var/lib/glusterd
sudo mkdir /var/log/glusterfs
sudo mkdir -p /bricks/brick1/gv0

sudo mkdir swstorage
sudo mount --bind ./swstorage ./swstorage # there won't be an ncp on host, no dir exists: /var/lib/docker/volumes/NCP_ncdata/_data /var/lib/docker/volumes/NCP_ncdata/_data
sudo mount --make-shared ./swstorage

docker run --restart=always --name gfsc0 -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=$(pwd)/swstorage,target=$(pwd)/swstorage,bind-propagation=rshared -d --privileged=true --net=netgfsc -v /dev/:/dev gluster/gluster-centos

echo -e "\n\nPlease make sure to run the following command on every machine you want to add to the swarm:\n"
echo -e "docker swarm join --token ${worker_join_token} ${leader_IP}:2377\n\n"
echo "Type ready when every node is added . . ."
while true; do
  read ready
  if [[ $ready == "ready" || $ready == "Ready" ]] ; then
    break
  fi
  echo -e "Type ready when every node is added . . ."
done

# Vagrant option can use the provided script gluster_setup <no_test>
# Message to workers to create their gluster container
echo -e "\nMake sure to run the following commands on every worker node (or execure gluster_setup.sh):"
echo -e "In the last command, gfsc<X> should be replaced with the id number of each worker\n"
echo -e "sudo mount --bind /var/lib/docker/volumes/NCP${test}_ncdata/_data /var/lib/docker/volumes/NCP${test}_ncdata/_data"
echo -e "sudo mount --make-shared /var/lib/docker/volumes/NCP${test}_ncdata/_data"
echo -e "docker run --restart=always --name gfsc<X> -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/var/lib/docker/volumes/NCP${test}_ncdata/_data,target=/var/lib/docker/volumes/NCP${test}_ncdata/_data,bind-propagation=rshared -d --privileged=true --net=netgfsc -v /dev/:/dev gluster/gluster-centos"
echo -e "\nType ready when all workers are running gluster container . . ."
while true; do
  read ready
  if [[ $ready == "ready" || $ready == "Ready" ]] ; then
    break
  fi
  echo -e "Type ready when all workers are running gluster container . . ."
done

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

echo -e "On every node execute the following command to mount the gluster volume (or execute gluster_volume.sh), then type ready\n"
echo -e "docker exec -it gfsc<X> mount.glusterfs gfsc<X>:/gv0 /var/lib/docker/volumes/NCP${test}_ncdata/_data\n"
while true; do
  read ready
  if [[ $ready == "ready" || $ready == "Ready" ]] ; then
    break
  fi
  echo -e "Type ready when volume is mounted on every gluster node . . ."
done

# Set manager to drain so that ncp replicas are distributed to workers
docker node update --availability drain ${leader_name}

# Service ncp start - leader's IP
docker deploy --compose-file ../docker-compose.yml NCP${test}
docker service scale NCP${test}_nextcloudpi=${num_workers}

docker node update --availability active ${leader_name}

