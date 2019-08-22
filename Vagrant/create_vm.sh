#!/bin/bash

debian_version="buster"
VAGRANT_HOME="~/.vagrant.d" # Default value

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
  local networking=$1
  local parentIP=$2

  if [[ $networking == "1" ]]; then
    # Public networking

    local hostIP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    local ip_mask=$(ip addr | grep ${hostIP} | awk '$1 ~ /^inet/ {print $2}')
    local prefix=$(cut -d'/' -f2 <<<"$ip_mask")

    IFS=. read -r io1 io2 io3 io4 <<< "$hostIP"
    IFS=. read -r xx mo1 mo2 mo3 mo4 <<< $(for a in $(seq 1 32); do if [ $(((a - 1) % 8)) -eq 0 ]; then echo -n .; fi; if [ $a -le $prefix ]; then echo -n 1; else echo -n 0; fi; done)
    local net_addr="$((io1 & mo1)).$((io2 & mo2)).$((io3 & mo3)).$((io4 & mo4))"

    local base="${io1}.${io2}.${io3}"
    local lsv=$(cut -d'.' -f4 <<<"$net_addr")

  else
    # Private networking

    # Default DHCP range. This may have been changed manually
    local base="172.28.128"
    local lsv=3
  fi

  while [ $lsv -le 255 ]; do
    lsv=$(( lsv + 1 ))
    starting="${base}.${lsv}"
    try_ip="${base}.${lsv}"
    if valid_ip $try_ip && ! reserved_ip $try_ip && [[ $parentIP != $try_ip ]]; then
      echo "${try_ip}"
      return 0
    fi      
  done
}


# Setup a new NCP VM
# Either create it from scratch
# Or clone an existing NCP vm

# Vagrant is a requirement
while true; do
  if [[ ! -f /usr/bin/vagrant ]]; then
    echo -e "Before we proceed, please install vagrant package."
    echo -e "Type enter when you're finished."
    read ready
    [[ $ready == "" ]] && break
  else
    break
  fi
done

# Virtual Box is a requirement
while true; do
  if [[ ! -f /usr/bin/virtualbox ]]; then
    echo -e "Before we proceed, please install virtual box package."
    echo -e "Type enter when you're finished."
    read ready
    [[ $ready == "" ]] && break
  else
    break
  fi
done

# New or Clone
# vm_dir should point to NCP_VM or NCP_VM_clone respectively
echo -e "\n===================================================\n"
while true; do 
  echo -e "Please enter number (1/2):"
  echo -e "(1) for new VM"
  echo -e "(2) for clone VM"
  read choice
  if [[ $choice == "1" ]]; then
    vm_dir="$(pwd)/NextCloudPi"
    vm_name="NextCloudPi"
    break
  elif [[ $choice == "2" ]]; then
    vm_dir="$(pwd)/NextCloudPi_clone"
    vm_name="NextCloudPi_clone"
    break
  else
    echo -e "Wrong input...\n"
  fi 
done

echo -e "\n===================================================\n"
while true; do
  echo -e "Enter new VM's name (default is ${vm_name}):"
  read name
  [[ $name == "" ]] && name=${vm_name}
  if [[ -f /usr/bin/VBoxManage ]]; then
    name_exists=$(VBoxManage list vms | awk '{print $1}' | grep "\"${name}"\"| wc -l)
    if [[ $name_exists == 1 ]]; then
      echo -e "${name} is used by another VM. Enter new name.\n"
      continue
   elif [[ -d "$(pwd)/${name}" ]]; then
      echo -e "This name seems to be taken. Please choose another name.\n"
      continue
    else
      vm_name="${name}"
      vm_dir="$(pwd)/${name}"
      break
    fi
  fi
done

# Choose networking: public or private
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

# If new, parent variables will be empty
# If clone, choose either clone via Vagrantfile or VBox Name
parent_dir=""
parent_ip=""
[[ $choice == "2" ]] && {
  pack=2
  metadata=1
  echo -e "\n===================================================\n"
  while true; do
    echo -e "Specify the parent NCP VM you wish to clone, by providing:"
    echo -e "(1) Absolute path to parent's VM Vagrantfile"
    echo -e "(2) Parent VM's VirtualBox Name"
    echo -e "Type 1 or 2:"
    read parent_option
    if [[ $parent_option != "1" && $parent_option != "2" ]]; then
      echo -e "Wrong input..."
      continue
    fi

    [[ $parent_option == "1" ]] && {
      # If Vagrantfile path is given we check for existing package.box or metadata
      echo -e "\n===================================================\n"
      echo -e "Give path of the parent's VM Vagrantfile (absolute path)\nyou want to clone or type enter for default\n($(pwd)/NextCloudPi):"
      read parent_dir
      [[ $parent_dir == "" ]] && parent_dir="$(pwd)/NextCloudPi"

      # if dir does not exist
      if [[ ! -d ${parent_dir} ]]; then
        echo -e "\nPath ${parent_dir} does not exist.\nPlease enter an existing directory.\n"
	continue

      # if there is no vagrantfile in the dir
      elif [[ ! -f ${parent_dir}/Vagrantfile ]]; then # Vagrantfile does not exist
        echo -e "\nPath ${parent_dir} does not contain a Vagrantfile.\n"
	continue
      fi

      # Box name should be the path to package.box
      box="${parent_dir}/package.box"

      # get parent's IP through Vagrantfile so that cloned VM is not assigned the same
      parent_ip="$(cat ${parent_dir}/Vagrantfile | grep public_network | cut -d'"' -f6)"
      # If the Vagrantfile template this script is using, is used for parent
      # Private ip will be the same as in public network command - although the public network command will be commented out later
      if [[ $parent_ip == "" ]]; then
        # Vagrantfile could not provide us with parent's IP so search for private networking
        parent_ip="$(cat ${parent_dir}/Vagrantfile | grep private_network | cut -d'"' -f6)"
      fi
   
      # Before we clone we check if a package of the VM exists
      # Check path for package.box
      # Check Vagrant's metadata for name of the path

      # If package.box exists in parent directory ask if it should be used or create new
      if [[ -f ${parent_dir}/package.box ]]; then
        echo -e "\n===================================================\n"
        while true; do
          echo -e "A box of this VM already exists.\nDo you want to use the existing box or create a new? (1/2)"
          echo -e "(1) Use existing box"
          echo -e "(2) Create new box"
          read pack
          if [[ $pack == "1" ]]; then
	    # Since the package exist it may be newer than the box added as metadata
	    # So we clean metadata and use the box
	    vagrant box remove ${parent_dir}/package.box
	    metadata=3 # We should not worry about metadata when pack=1
            break
	  elif [[ $pack == "2" ]]; then
	    # Delete the box and clean its metadata
	    rm ${parent_dir}/package.box
            vagrant box remove ${parent_dir}/package.box
	    break
	  else
	    echo -e "Wrong input..."
          fi
        done
        break
      fi

      # Package may contain newer version (somebody could have just run vagrant package)
      # But metadata of the package could only be added after the package was created, if
      # somebody run vagrant up. So it's a double catch actually..
      # Metadata is only checked if package.box does not exists in the directory

      vagrant_box_added=$(vagrant box list | grep ${parent_dir}/package.box | wc -l)
      if [[ $vagrant_box_added == 1 ]]; then
	pack=3 # Package does not worry us anymore, it does not exist
        echo -e "\n===================================================\n"
        while true; do
          echo -e "A box of this VM is already added in Vagrant.\nDo you want to use the existing box or create a new? (1/2)"
          echo -e "(1) Use existing box"
          echo -e "(2) Create new box"
          read metadata
          if [[ $metadata == "1" ]]; then
            # Box did not exist, so we just keep metadata
            break
	  elif [[ $metadata == "2" ]]; then
	    # Clean metadata, box did not exist anyway
	    vagrant box remove ${parent_dir}/package.box
            break
          fi
        done
      fi
      break
    }

    # If user chose to specify Virtual Box Name of the VM
    # we do not check for metadata, we erase it anyway
    # because name can be the same by mistake
    # while path - which we checked in Vagrantfile option - is not so possible to be the same by mistake
    # So this option just clones right away
    if [[ $parent_option == 2 ]]; then
      # The new box will be created in NCP_VM_clone and have this path as a name
      box="${vm_dir}/package.box"

      # This option needs name of VM in order to clone
      # Also, parent VM should be running so that it's assigned an IP
      # And when reserved_ip will ping parent VM, it will not assign the same IP to cloned VM
      # We don't need to know this IP, we just need parent VM to have an IP 
      echo -e "\n===================================================\n"
      echo -e "Enter parent's VirtualBox VM name:"
      read VBox_name

      # If VBoxManage exists, it checks for the existence of VBox name
      # and starts parent VM if it exists
      if [[ -f /usr/bin/VBoxManage ]]; then
	name_exists=$(VBoxManage list vms | awk '{print $1}' | grep "\"${VBox_name}"\"| wc -l)
        if [[ $name_exists != 1 ]]; then
	  echo -e "${VBox_name} does not correspond to an existing VM..."
        else
          VBoxManage startvm ${VBox_name} --type headless 2> /dev/null
	  break
	fi
	# remove metadata if they exist
	vagrant box remove ${VBox_name}
      else
	# If VBoxManage does not exist, ask user to turn on the parent VM manually
        echo -e "In order to proceed the parent VM should be running.\nPlease make sure to start it if it's not running.\nPress ready when you're finished."
	while true; do
	  read ready
	  if [[ $ready == "Ready" || $ready == "ready" ]]; then
	    break
	  fi
	done
      fi
      break
    fi

  done
}

# Choose specific IP or let the script pick any available
# IP will be checked if it's valid or reserved by another device
# Works for both public and private networking
echo -e "\n===================================================\n"
while true; do 
  echo -e "Please choose between using a specific IP\nor picking any IP available?"
  echo -e "Type either the IP within the LAN you want to use\nor type 'any' (default) [<IP>/any]:"
  read IP
  if valid_ip $IP && ! reserved_ip $IP; then 
    break
  elif [[ $IP == "any" || $IP == "" ]]; then
    IP=$(pick_ip ${network} ${parent_ip})
    break
  else
    if reserved_ip $IP; then
      echo -e "IP is allocated, please enter another IP..."
    else
      echo -e "Wrong input...\n"
    fi
  fi
done

# Specify resources for the VM
# They can be changed afterwards manually
echo -e "\n===================================================\n"
echo -e "Specify the resources of the new VM."
echo -e "Memory (default 2048):"
read memory
[[ $memory == "" ]] && memory=2048
echo -e "Cores (default 2):"
read cpus
[[ $cpus == "" ]] && cpus=2

# Host interface should be specified for networking commands
host_ip=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
host_interface=$(ip addr | grep ${host_ip} | awk '$1 ~ /^inet/ {print $9}')


# Create new Vagrantfile
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

  # First boot use vagrant insecure key
  config.ssh.private_key_path = '${VAGRANT_HOME}/insecure_private_key'
  config.ssh.insert_key = false

  #Box settings
  #config.vm.box = "debian/${debian_version}64"
  #config.vm.box = "${box}"
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
    # VM name
    v.name = "${vm_name}"

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
    source etc/library.sh
    run_app_unsafe post-inst.sh
    cd -
    rm -r /tmp/nextcloudpi

    # Create insecure vagrant key so that VM can be cloned
    mkdir -p /home/vagrant/.ssh
    chmod 0700 /home/vagrant/.ssh
    wget --no-check-certificate \
    https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub \
    -O /home/vagrant/.ssh/authorized_keys
    chmod 0600 /home/vagrant/.ssh/authorized_keys
    chown -R vagrant /home/vagrant/.ssh

    poweroff
  SHELL

  # Provision the VM
  config.vm.provision "shell", inline: $script

end
EOF

# Fix network command
if [[ $network == "1" ]]; then
    sed -i 's,#config.vm.network "public_network",config.vm.network "public_network",' ${vm_dir}/Vagrantfile
else
    sed -i 's,#config.vm.network "private_network",config.vm.network "private_network",' ${vm_dir}/Vagrantfile
fi

# Fix box name for new VM
[[ $choice == "1" ]] && sed -i '22s,#,,' ${vm_dir}/Vagrantfile

parent_vm=0
[[ $choice == "2" ]] && {
  # Package if user wants new package.box
  if [[ $parent_option == "1" ]]; then
    if [[ $pack == 2 || $metadata == 2 ]]; then
      cd ${parent_dir}
      #Turn off parent VM
      echo -e "Parent VM will be temporarily turned off in order to\nget cloned.\n"
      vagrant halt
      #Export a box from the parent VM
      vagrant package > check_pack
      parent_vm=$(cat check_pack | grep "VM not created" | wc -l)
      rm check_pack
    fi
  else
    # package.box will be saved in clone's directory
    # export a box from VBox Machine
    cd ${vm_dir}
    vagrant package --base ${VBox_name} > check_pack
    parent_vm=$(cat check_pack | grep "VM not created" | wc -l)
    rm check_pack
  fi
  
  # Parent VM is not created
  # This will only happen if VBoxManage does not exist
  # If VBoxManage exists, it catches this when providing input
  if [[ $parent_vm == 1 ]]; then
    echo -e "\n===================================================\n"
    echo -e "ERROR: The VM you want to clone is not created.\nPlease create it and run the script again."
    rm -r ${vm_dir}
    exit 1
  fi

  # Fix clone's box name
  sed -i '23s,#,,' ${vm_dir}/Vagrantfile

  # All commands of the first Vagrantfile are not needed
  # NCP is already installed in parent VM
  sed -i '50,73s/^#*/#/' ${vm_dir}/Vagrantfile
}

# Setup VM
echo -e "\nVM setting up . . .\nPlease wait . . ."
cd ${vm_dir}
vagrant up

echo -e "\n===================================================\n"
echo -e "Your NCP VM is ready."
echo -e "Start the VM through VirtualBox GUI (Start->Headless Start)"
[[ -f /usr/bin/VBoxManage ]] && echo -e "or execute command\n\t'VBoxManage startvm ${vm_name} --type headless'"
echo -e "and type https://${IP} to your web browser\nto activate it.\n"
