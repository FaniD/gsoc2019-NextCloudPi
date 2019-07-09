#!/bin/bash

# System setup: Manager and Worker nodes
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
docker swarm init --advertise-addr ${leader_IP}
docker service create --name registry --publish published=5001,target=5001 registry:2
docker-compose push

echo "Enter number of workers:"
read num_workers

worker_join_token=$(docker swarm join-token -q worker)
for(( i=1; i<="$num_workers"; i++)); do
  docker-machine create --driver virtualbox worker${i}
  docker-machine ssh worker${i} "docker swarm join --token ${worker_join_token} ${leader_IP}:2377"
  machine_IP=$(docker-machine ip worker${i})
  export IP=${machine_IP}
  docker stack deploy --compose-file docker-compose.yml
  #docker-machine ssh worker1 "docker run -d -p 4443:4443 -p 443:443 -p 80:80 -v ncdata:/data --name nextcloudpi ownyourbits/nextcloudpi-x86:latest ${machine_IP}"
done

# Services

#docker service create nextcloudpi-x86 --name ncp
#docker deploy --compose-file docker-compose.yml
#docker service scale nextcloudpi=${num_workers}

# Visualizer (localhost:5000)

docker run -it -d -p 5000:8080 -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer
