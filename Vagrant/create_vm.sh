#!/bin/bash

debian_version="buster"

# Return true if IP is in a valid form, otherwise return false
function valid_ip() {
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  return $stat
}

# Return true if IP is used by another device or false if ping does not respond.
function reserved_ip() {
  local ip=$1
  local stat

  if ping -c1 -w3 ${ip} >/dev/null 2>&1 ; then
    stat=0
  else
    stat=1
  fi
  return $stat
}

# Pick the first IP available starting from the minimum IP of host's network
# Not strict conditions - should be fixed to stop on max IP of network
function pick_ip() {
  local host_ip=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
  local ip_mask=$(ip addr | grep ${host_ip} | awk '$1 ~ /^inet/ {print $2}')
  local prefix=$(cut -d'/' -f2 <<<"$ip_mask")

  IFS=. read -r io1 io2 io3 io4 <<< "$host_ip"
  IFS=. read -r xx mo1 mo2 mo3 mo4 <<< $(for a in $(seq 1 32); do if [ $(((a - 1) % 8)) -eq 0 ]; then echo -n .; fi; if [ $a -le $prefix ]; then echo -n 1; else echo -n 0; fi; done)
  local net_addr="$((io1 & mo1)).$((io2 & mo2)).$((io3 & mo3)).$((io4 & mo4))"

  local base="${io1}.${io2}.${io3}"
  local lsv=$(cut -d'.' -f4 <<<"$net_addr")

  while [ $lsv -le 255 ]; do
    lsv=$(( lsv + 1 ))
    starting="${base}.${lsv}"
    try_ip="${base}.${lsv}"
    if valid_ip $try_ip && ! reserved_ip $try_ip; then
      echo "${try_ip}"
      return 0
    fi      
  done
}

# Setup a new NCP VM
# Either create it from scratch
# Or clone an existing NCP vm

echo -e "\n===================================================\n"
while true; do 
  echo -e "Please enter number (1/2):"
  echo -e "(1) for new VM"
  echo -e "(2) for clone VM"
  read choice
  if [[ $choice != "1" && $choice != "2" ]]; then
    echo -e "Wrong input...\n"
  else
    break
  fi 
done

echo -e "\n===================================================\n"
while true; do 
  echo -e "Specify prefered way of networking:"
  echo -e "(1) Public network (Bridged Networking)\n\tThe IP of new VM will be visible to everyone\n\tinside the LAN"
  echo -e "(2) Private network (Host-Only)\n\tThis type of networking makes the IP of the\n\tnew VM visible only to the host machine"
  read network
  if [[ $network != "1" && $network != "2" ]]; then
    echo -e "Wrong input...\n"
  else
    break
  fi
done

echo -e "\n===================================================\n"
while true; do 
  echo -e "Please choose between using a specific IP\nor picking any IP available?"
  echo -e "Type either the IP within the LAN you want to use\nor type 'any' (<IP>/any):"
  read IP
  if valid_ip $IP && ! reserved_ip $IP; then 
    break
  elif [[ $IP == "any" ]]; then
    IP=$(pick_ip)
    break
  else
    if reserved_ip $IP; then
      echo -e "IP is allocated, please enter another IP..."
    else
      echo -e "Wrong input...\n"
    fi
  fi
done

echo -e "\n===================================================\n"
echo -e "Specify the resources of the new VM."
echo -e "Memory (default 4096):"
read memory
[[ $memory == "" ]] && memory=4096
echo -e "Cores (default 2):"
read cpus
[[ $cpus == "" ]] && cpus=2


if [[ $choice == "1" ]]; then
  vm_dir="$(pwd)/NCP_VM"
else
  vm_dir="$(pwd)/NCP_VM_clone"
fi 

host_ip=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
host_interface=$(ip addr | grep ${host_ip} | awk '$1 ~ /^inet/ {print $9}')

mkdir -p ${vm_dir}
touch ${vm_dir}/Vagrantfile

cat <<'EOF' > ${vm_dir}/Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :

#
# Vagrantfile for the NCP Debian VM
#
# Instructions: vagrant up; vagrant ssh
#
# Notes: User/Pass is ubnt/ubnt.
# $HOME is accessible as /external. CWD is accessible as /cwd
#

EOF

cat <<EOF >> ${vm_dir}/Vagrantfile
Vagrant.configure("2") do |config|

  vmname = "NCP Debian VM"

  #Box settings
  config.vm.box = "debian/${debian_version}64"
  config.vm.box_check_update = true

  #VM settings
  config.vm.hostname = "ncp-vm"

  #Networking

  #Public IP
  #config.vm.network "public_network", bridge: "${host_interface}", ip: "${IP}"

  #Private IP
  #config.vm.network "private_network", ip: "${IP}"

  #Provider settings
  config.vm.provider "virtualbox" do |v|
    #Resources
    v.memory = ${memory}
    v.cpus = ${cpus}

    #VM name
    v.name = "NextCloudPi"

  end

  config.vm.synced_folder '.', '/vagrant', disabled: true
EOF

cat <<'EOF' >> ${vm_dir}/Vagrantfile
  $script = <<-SHELL
    sudo su
    set -e
    BRANCH=master
    #BRANCH=devel  # uncomment to install devel
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git

    # indicate that this will be an image build
    touch /.ncp-image

    # install
    git clone -b "$BRANCH" https://github.com/nextcloud/nextcloudpi.git /tmp/nextcloudpi
    cd /tmp/nextcloudpi

    # uncomment to install devel
    #sed -i 's|^BRANCH=master|BRANCH=devel|' install.sh ncp.sh

    bash install.sh

    # cleanup
    source etc/library.sh && run_app_unsafe post-inst.sh && cd - && rm -r /tmp/nextcloudpi && systemctl disable sshd
  SHELL

  # Provision the VM
  config.vm.provision "shell", inline: $script

end
EOF

if [[ $network == "1" ]]; then
    sed -i 's,#config.vm.network "public_network",config.vm.network "public_network",' ${vm_dir}/Vagrantfile
else
    sed -i 's,#config.vm.network "private_network",config.vm.network "private_network",' ${vm_dir}/Vagrantfile
fi

[[ ($choice == "2") ]] && {
  echo -e "\n===================================\n"
  while true; do 
    echo -e "Give path of the origin NCP VM (absolute path) you want\nto clone or type enter for default ($(pwd)/NCP_VM):"
    read parent_dir
    [[ $parent_dir == " " ]] && parent_dir="$(pwd)/NCP_VM"
    [[ -f ${parent_dir} ]] && break
    echo -e "Path ${parent_dir} does not exist. Please enter an existing directory of an NCP VM."
  done

  cd ${parent_dir}
  #Turn off parent VM
  echo -e "Parent VM will be temporarily turned off in order to get cloned.\n"
  vagrant halt 
  #Export a box from the parent VM
  vagrant package

  cd ${vm_dir}
  sed -i 's,v.name = "NextCloudPi",v.name = "NextcloudPi_clone",' ${vm_dir}/Vagrantfile
  sed -i "s,config.vm.box = "debian/${debian_version}64",config.vm.box = "${parent_dir}/package.box"," ${vm_dir}/Vagrantfile
  sed -i '45,69s/^#*/#/' ${vm_dir}/Vagrantfile
  cd ${parent_dir}
  vagrant up
}

# Setup origin VM, according to the existing Vagrantfile
cd ${vm_dir}
vagrant up
echo -e "\nYour NCP VM is ready. Type https://${IP} to your web browser to activate it."
