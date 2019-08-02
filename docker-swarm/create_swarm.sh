#!/bin/bash

test="36"

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

echo -e "\n================================================\n"
echo -e "Choose one of the options described below.\n"
echo -e "(1) I want to use existing machines as workers"
echo -e "\tChoosing this option, you will have to provide some\n\tinfo about each node in order to add every node to\n\tswarm system and gluster cluster by following the\n\tinsctructions provided.\n\tThe only requirement for these machines is to have\n\tdocker installed and ssh server enabled."
echo -e "(2) Vagrant option\n\tAutomatically create new VMs and add them to swarm\n\tand gluster cluster. Feel free to change the specs\n\tof each VM through the Vagrantfile provided."
echo -e "\nType 1 or 2:"
read option
echo -e "\n================================================\n"
echo "Enter number of workers:"
read num_workers
replicas=$((num_workers + 1))

if [[ $option == 1 ]]; then
  echo -e "\n================================================\n"
  echo -e "\nTo fully automate the whole process, manager's public\nkey should be added to authorized_keys file on every\nworker node."
  echo -e "You can either add the public key manually or \nprovide the credentials for each node to fix it automatically.\n"
  echo -e "Choose one of the following options:\n"
  echo -e "(1) Manually add manager's public key to authorized_keys files on every node."
  echo -e "\tThis option requires to provide as input for each node:\n\t* IP address\n\t* Username (a sudoer user)\n\t"
  echo -e "(2) Fix it for me automatically."
  echo -e "\tThis option requires to provide as input for each node:\n\t* IP address\n\t* Username (a sudoer user)\n\t* Password\n\tMake sure PasswordAuthentication is enabled in /etc/ssh/sshd_config\n\ton every node.\n"
  echo -e "Type 1 or 2:"
  read ssh_option
  
  echo -e "\n================================================\n"
  echo -e "\nProvide worker node's information below as asked:"
  ip_list=[]
  username_list=[]
  if [[ $ssh_option == 2 ]]; then
	  psw_list=[]
  fi
  for(( i=1; i<="$num_workers"; i++)); do
    while true; do
      echo -e "\n===Worker${i}==="
      echo -e "IP address:"
      read node_ip
      echo -e "Username:"
      read node_user
      if [[ $ssh_option == 2 ]]; then
        echo -e "Password:"
        read node_psw
      fi
      echo -e "\nIf the information above is correct hit enter, otherwise type 'no' to re-write it (<enter>/no)"
      read info_ok
      if [[ $info_ok != "no" ]]; then
	ip_list+=( ${node_ip} )
	username_list+=( ${node_user} )
	if [[ $ssh_option == 2 ]]; then
          psw_list+=( ${node_psw} )
	fi
        break;
      fi
    done
  done

  if [[ $ssh_option == 1 ]]; then
    echo -e "\n================================================\n"
    echo -e "Please make sure to add manager's public key to\nthe authorized_keys file of every swarm worker manually."
    echo -e "Type ready when you're finished"
    while true; do
      read ready
      if [[ $ready == "ready" || $ready == "Ready" ]] ; then
        break
      fi
      echo -e "Type ready when you're finished . . ."
    done
  else
    if [[ ! -f /usr/bin/sshpass ]]; then
      echo -e "\n================================================\n"
      echo -e "Please install package sshpass before we continue."
      echo -e "Type ready when you're finished"
      while true; do
        read ready
        if [[ $ready == "ready" || $ready == "Ready" ]] ; then
          break
        fi
        echo -e "Type ready when you're finished . . ."
      done
    fi
  fi
fi

while true; do
  # Initialize swarm system with host as Leader (manager)
  echo -e "\nCreating swarm system . . ."
  docker swarm init --advertise-addr ${leader_IP}

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

  sleep 15

  docker exec gfsc0 gluster peer status > status
  if [[ $( cat status ) != *"Connection failed. Please check if gluster daemon is operational."* ]]; then
    rm status
    break
  fi
  rm status
  ./destroy_swarm.sh ${test}
done

# Visualizer option (localhost:5000)
echo -e "Run visualizer (localhost:5000) . . ."
docker run -it -d -p 5000:8080 -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer

# worker token
worker_join_token=$(docker swarm join-token -q worker)

echo -e "\nAttaching worker nodes to the swarm"
if [[ $option == 1 ]]; then
  for(( i=1; i<="$num_workers"; i++)); do
    if [[ $ssh_option == 2 ]]; then
      sudo sshpass -p ${psw_list[${i}]} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${username_list[${i}]}@${ip_list[${i}]}
    fi
    ssh ${username_list[${i}]}@${ip_list[${i}]} "docker swarm join --token ${worker_join_token} ${leader_IP}:2377"
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
  for(( i=1; i<="$num_workers"; i++)); do
    scp gluster_setup.sh ${username_list[${i}]}@${ip_list[${i}]}:~/
    ssh ${username_list[${i}]}@${ip_list[${i}]} "./gluster_setup.sh ${test} ${i}"
  done
fi

sleep 15

# Gluster volume setup
echo -e "Creating gluster volume . . ."
replicas_gfs=""
for(( i=1; i<="$num_workers"; i++)); do
  # Connect node's gluster container to the gluster cluster
  docker exec gfsc0 gluster peer probe gfsc${i}
  replicas_gfs+="gfsc${i}:/bricks/brick1/gv0 "
done

sleep 15

# Create replicated volume
docker exec gfsc0 gluster volume create gv0 replica ${replicas} gfsc0:/bricks/brick1/gv0 ${replicas_gfs}
docker exec gfsc0 gluster volume start gv0
docker exec gfsc0 mount.glusterfs gfsc0:/gv0 $(pwd)/swstorage

if [[ $option == 2 ]]; then
  for(( i=1; i<="$num_workers"; i++)); do
    cd vagrant_workers/worker${i}
    vagrant ssh -c "./gluster_volume.sh ${test}"
    vagrant ssh -c "sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm"
    cd ../..
  done
else
  for(( i=1; i<="$num_workers"; i++)); do
    scp gluster_volume.sh ${username_list[${i}]}@${ip_list[${i}]}:~/
    ssh ${username_list[${i}]}@${ip_list[${i}]} "./gluster_volume.sh ${test} ${i}"
    ssh ${username_list[${i}]}@${ip_list[${i}]} "sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm"
  done
fi
