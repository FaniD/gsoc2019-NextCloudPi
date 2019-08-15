#!/bin/bash

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

function reserved_ip() {
  local ip=$1
  local stat

  if ping -c1 -w3 ${ip} >/dev/null 2>&1 ; then
    echo "IP address is allocated" >&2
    stat=0
  else
    echo "IP address is either free or firewalled" >&2
    stat=1
  fi
  return $stat
}

echo -e "===================================\n"
while true; do 
  echo -e "Please enter number (1/2):"
  echo -e "(1) for new VM"
  echo -e "(2) for clone VM" #Should be under the dir of an existing one
  read choice
  if [[ $choice != "1" && $choice != "2" ]]; then
    echo -e "Wrong input...\n"
  else
    break
  fi 
done

echo -e "===================================\n"
while true; do 
  echo -e "Specify prefered way of networking:"
  echo -e "(1) Public network (Bridged Networking)\n\tThe IP of new VM will be visible to everyone inside the LAN"
  echo -e "(2) Private network (Host-Only)\n\tThis type of networking makes the IP of the new VM visible only to the host machine"
  read network
  if [[ $network != "1" && $network != "2" ]]; then
    echo -e "Wrong input...\n"
  else
    break
  fi
done

echo -e "==================================\n"
while true; do 
  echo -e "Please choose between using a specific IP\nor picking any IP available?"
  echo -e "Type either the IP within the LAN you want to use or 'any' (<IP>/any):"
  read IP
  if valid_ip $IP && ! reserved_ip $IP; then 
    break
  elif [[ $IP == "any" ]]; then
    break
  else
    echo -e "Wrong input...\n"
  fi
done

if [[ $choice == "1" ]]; then
  vm_dir="NCP_VM"
else
  vm_dir="NCP_VM_clone"
fi 

host_interface=$(ip addr | grep 192.168.1.18 | cut -d' ' -f13)

mkdir -p ${vm_dir}
touch ${vm_dir}/Vagrantfile

cat << 'EOF' > ${vm_dir}/Vagrantfile
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

Vagrant.configure("2") do |config|

  vmname = "NCP Debian VM"

  #Box settings
  config.vm.box = "debian/stretch64"
  config.vm.box_check_update = false

  #VM settings
  config.vm.hostname = "ncp-vm"

  #Networking

  #Public IP
  
  config.vm.network "public_network", bridge: "${host_interface}", ip: "${IP}"

  #Private IP
  #config.vm.network "private_network", ip: "192.168.50.4"
  #config.vm.network "private_network", type: "dhcp"

  #Provider settings
  config.vm.provider "virtualbox" do |v|
    #Resources
    v.memory = 4096
    v.cpus = 4

    #VM name
    v.name = "NextCloudPi"

  end


  config.vm.synced_folder '.', '/vagrant', disabled: true

  $script = <<-SHELL
    sudo su
    BRANCH=gsoc2019-master
    #BRANCH=gsoc2019-devel  # uncomment to install devel
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git

    # indicate that this will be an image build
    touch /.ncp-image

    # install
    git clone -b "$BRANCH" https://github.com/eellak/gsoc2019-NextCloudPi.git /tmp/nextcloudpi
    cd /tmp/nextcloudpi

    # uncomment to install devel
    #sed -i 's|^BRANCH=gsoc2019-master|BRANCH=gsoc2019-devel|' install.sh ncp.sh

    bash install.sh

    # cleanup
    source etc/library.sh
    run_app_unsafe post-inst.sh
    cd -
    rm -r /tmp/nextcloudpi
    systemctl disable sshd
    poweroff
  SHELL

  # Provision the VM
  config.vm.provision "shell", inline: $script

end
EOF

[[ ($choice == "1") ]] && {
  #Setup origin VM, according to the existing Vagrantfile
#  mkdir NCP_VM

  cd NCP_VM
#  vagrant up
  echo -e "\nYour NCP VM is ready. Type localhost:8000 to your web browser to activate it."
  return 0
}

[[ ($choice == "2") ]] && {
  #Turn off parent VM
  vagrant halt 
  #Export a box from the parent VM
  vagrant package

  #Create new dir and new Vagrantfile - comment out every command in Vagranfile's script except for power off
  mkdir NCP_VM_clone
  cd NCP_VM_clone
  cp ../Vagrantfile .
  sed -i 's,v.name = "NextCloudPi",v.name = "NextcloudPi_clone",' Vagrantfile
  sed -i 's,config.vm.box = "debian/stretch64",config.vm.box = "../package.box",' Vagrantfile
  sed -i '50,74s/^#*/#/' Vagrantfile
  sed -i '75s/#//' Vagrantfile

  #Setup the new cloned VM
  #vagrant up

  return 0
}
