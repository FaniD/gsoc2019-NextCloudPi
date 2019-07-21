#!/bin/bash

leader_ip=$1

workers=$(ls vagrant_workers | wc -l)
new_id=$((workers)) # +1 already counted by Vagrantfile
mkdir vagrant_workers/worker${new_id}
cp vagrant_workers/Vagrantfile vagrant_workers/worker${new_id}

sed -i "s,workerX,worker${new_id},g" vagrant_workers/worker${new_id}/Vagrantfile
base_ip=$(cut -d. -f4 <<<${leader_ip})
new_ip=$((base_ip + new_id))
sed -i "s,192.168.1.21,192.168.1.${new_ip}," vagrant_workers/worker${new_id}/Vagrantfile

sudo cp gluster_setup.sh vagrant_workers/worker${new_id}/
#vagrant up
