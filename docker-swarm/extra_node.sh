#!/bin/bash

# test id
test="${1:-""}"

echo -e "\n================================================\n"
echo -e "Choose one of the options below:"
echo -e "(1) I will use an existing machine"
echo -e "\tChoosing this option, you will have to provide some\n\tinfo about the machine in order to add the node to\n\tswarm system and gluster cluster by following the\n\tinsctructions provided.\n\tThe only requirement for the machine is to have\n\tdocker installed and ssh server enabled."
echo -e "(2) Vagrant option\n\tA new VM will be created automatically and added to swarm\n\tand gluster cluster. Feel free to change the specs\n\tof the VM through the Vagrantfile provided"
echo -e "\nType 1 or 2:"
read option

leader_name=$(hostname)
leader_IP=$(docker node inspect self --format '{{ .Status.Addr  }}')
worker_id=$(ls vagrant_workers | wc -l)

if [[ $option == 1 ]]; then
  echo -e "\n================================================\n"
  echo -e "\nTo fully automate the whole process, manager's public\nkey should be added to authorized_keys file on worker node."
  echo -e "You can either add the public key manually or \nprovide the credentials of the node to fix it automatically.\n"
  echo -e "Choose one of the following options:\n"
  echo -e "(1) Manually add manager's public key to authorized_keys files on worker node."
  echo -e "\tThis option requires to provide as input for worker node:\n\t* IP address\n\t* Username (a sudoer user)\n\tMake sure that the sudoer user provided should be able\n\tto execute privileged actions without asking for password in\n\torder for the script to work automatically."
  echo -e "(2) Fix it for me automatically."
  echo -e "\tThis option requires to provide as input for worker node:\n\t* IP address\n\t* Username (a sudoer user)\n\t* Password\n\tMake sure PasswordAuthentication is enabled in /etc/ssh/sshd_config\n\ton worker node.\n"
  echo -e "Type 1 or 2:"
  read ssh_option

  echo -e "\n================================================\n"
  echo -e "\nProvide worker node's information below as asked:"
  while true; do
    echo -e "\n===Worker${worker_id}==="
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
      break;
    fi
  done

  if [[ $ssh_option == 1 ]]; then
    echo -e "\n================================================\n"
    echo -e "Please make sure to add manager's public key to\nthe authorized_keys file of worker node manually.\nRun 'ssh-add -L' to list host's keys in OpenSSH format.\nAlso configure users to be able to execute privileged actions without password."
    echo -e "Type ready when you're finished"
    while true; do
      read ready
      if [[ $ready == "ready" || $ready == "Ready" ]] ; then
        break
      fi
      echo -e "Type ready when you're finished . . ."
    done
  else
    echo -e "\n================================================\n"
    echo -e "Identity id_rsa.pub will be used. Type 'y' to confirm, or type other identity (y/<id>):"
    read identity
    if [[ $identity == "y" || $identity == "Y" ]]; then
      identity="id_rsa"
    else
      # if .pub is included fix it
      if [[ $identity == *".pub"* ]]; then
        identity=$(cut -d'.' -f1 <<< ${identity})
      fi
    fi
    ssh-add ~/.ssh/${identity}

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

worker_join_token=$(docker swarm join-token -q worker)

if [[ $option == 1 ]]; then
  if [[ $ssh_option == 2 ]]; then
    sshpass -p ${node_psw} ssh-copy-id -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ~/.ssh/${identity}.pub ${node_user}@${node_ip}
  fi
  ssh ${node_user}@${node_ip} "docker swarm join --token ${worker_join_token} ${leader_IP}:2377"
else
  ./new_worker_vagrant.sh ${leader_IP}
  cd vagrant_workers/worker${worker_id}
  vagrant up
  vagrant ssh -c "docker swarm join --token ${worker_join_token} ${leader_IP}:2377"
  cd ../..
fi 

docker node update --availability drain ${leader_name}
docker service scale NCP${test}_nextcloudpi=${worker_id}

docker node update --availability active ${leader_name}

sleep 25

if [[ $option == 1 ]]; then
  scp gluster_setup.sh ${node_user}@${node_ip}:~/
  if [[ $ssh_option == 1 ]]; then
    ssh ${node_user}@${node_ip} "sudo ./gluster_setup.sh ${test} ${worker_id}"
  else
    echo ${node_psw} | ssh -tt ${node_user}@${node_ip} "sudo ./gluster_setup.sh ${test} ${worker_id}"
  fi
else
  cd vagrant_workers/worker${worker_id}
  vagrant ssh -c "sudo ./gluster_setup.sh ${test}"
  cd ../..
fi

sleep 15

replicas=$(( $worker_id + 1 ))

docker exec gfsc0 gluster peer probe gfsc${worker_id}
sleep 5
docker exec gfsc0 gluster volume add-brick gv0 replica ${replicas} gfsc${worker_id}:/bricks/brick1/gv0

sleep 15

if [[ $option == 1 ]]; then
  scp gluster_volume.sh ${node_user}@${node_ip}:~/
  ssh ${node_user}@${node_ip} "./gluster_volume.sh ${test} ${worker_id}"
  if [[ $ssh_option == 1 ]]; then
    ssh ${node_user}@${node_ip} "sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm"
  else
    echo ${node_psw} | ssh -tt ${node_user}@${node_ip} "sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm"
  fi
else
  cd vagrant_workers/worker${worker_id}
  vagrant ssh -c "./gluster_volume.sh ${test}"
  vagrant ssh -c "sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files; sudo chown www-data:www-data /var/lib/docker/volumes/NCP${test}_ncdata/_data/nextcloud/data/ncp/files/swarm"
  cd ../..
fi
