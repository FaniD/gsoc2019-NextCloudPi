#!/bin/bash

leader_ip=$1

workers=$(ls workers | wc -l)
new_id=$((workers)) # +1 already counted by Vagrantfile
mkdir workers/worker${new_id}
cp workers/Vagrantfile workers/worker${new_id}

sed -i "s,workerX,worker${new_id},g" workers/worker${new_id}/Vagrantfile
base_ip=$(cut -d. -f4 <<<${leader_ip})
new_ip=$((base_ip + new_id))
sed -i "s,192.168.1.21,192.168.1.${new_ip}," workers/worker${new_id}/Vagrantfile
#vagrant up
