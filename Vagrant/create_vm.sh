#!/bin/bash

echo "Please enter number:"
echo "(1) for new VM"
echo "(2) for clone VM" #Should be under the dir of an existing one

read choice
[[ ($choice == "1") ]] && {
	#Setup origin VM, according to the existing Vagrantfile
	vagrant up
	return 1
}

[[ ($choice == "2") ]] && {
	#Turn off parent VM
	vagrant halt 
	#Export a box from the parent VM
	vagrant package

	#Create new dir and new Vagrantfile - comment out every command in Vagranfile's script except for power off
	mkdir clone
	cd clone
	cp ../Vagrantfile .
	sed -i 's,v.name = "NextCloudPi",v.name = "NextcloudPi_clone",' Vagrantfile
	sed -i 's,config.vm.box = "debian/stretch64",config.vm.box = "../package.box",' Vagrantfile
	sed -i '50,74s/^#*/#/' Vagrantfile
	sed -i '75s/#//' Vagrantfile

	#Setup the new cloned VM
	vagrant up

	return 1
}

echo "Wrong choice, run again"
