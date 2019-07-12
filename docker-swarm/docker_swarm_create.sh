#!/bin/bash

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

# Set manager to drain so that ncp replicas are distributed to workers
docker node update --availability drain ${leader_name}

# Registry option
#docker service create --name registry --publish published=5001,target=5001 registry:2
#docker-compose push

echo "Enter number of workers:"
read num_workers
replicas=((num_workers + 1))

# Setup Worker machines/nodes

worker_join_token=$(docker swarm join-token -q worker)

# Setup GlusterFS

mkdir /etc/glusterfs
mkdir /var/lib/glusterd
mkdir /var/log/glusterfs
mkdir -p /bricks/brick1/gv0
mkdir /data
docker network create -d overlay --attachable netgfs

mount --bind /data /data
mount --make-shared /data

docker run --restart=always --name gfsc0 -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/data,target=/data,bind-propagation=rshared -d --privileged=true --net=netgfs -v /dev/:/dev gluster/gluster-centos

# Create Docker machines with Virtual Box as driver
replicas_gfs=""
for(( i=1; i<="$num_workers"; i++)); do
  docker-machine create --driver virtualbox worker${i}
  docker-machine ssh worker${i} "docker swarm join --token ${worker_join_token} ${leader_IP}:2377"
#  docker-machine ip worker${i}
  docker-machine ssh worker${i} "sudo mkdir /data"
  docker-machine ssh worker${i} "sudo mount --bind /data /data"
  docker-machine ssh worker${i} "sudo mount --make-shared /data"
  docker-machine ssh worker${i} "docker run --restart=always --name gfsc${i} -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/data,target=/data,bind-propagation=rshared -d --privileged=true --net=netgfs -v /dev/:/dev gluster/gluster-centos"

  # Connect node's gluster container to the gluster cluster
  docker exec -it gfsc0 gluster peer probe gfsc${i}
  replicas_gfs+="gfsc${i}:/bricks/brick1/gv0 "
done

# Create replicated volume
docker exec -it gfsc0 gluster volume create gv0 replica ${replicas} ${replicas_gfs}
docker exec -it gfsc0 gluster volume start gv0
docker exec -it gfsc0 mount.glusterfs gfsc0:/gv0 /data

# Service ncp start - leader's IP
#machine_IP=$(docker-machine ip worker1)
export IP=${leader_IP}
docker deploy --compose-file ../docker-compose.yml NCP

# Services
#docker service scale NCP_nextcloudpi=${num_workers}
docker service scale NCP_nextcloudpi=${replicas}
