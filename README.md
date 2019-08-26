# The missing features of NextCloudPi - Google Summer of Code 2019

![NCP_gsoc logo](https://www.dropbox.com/s/vc41b0g6pzs21l6/NCP_GSOC.png?raw=1)

**NextCloudPi GSoC Project** is one of the accepted projects by GFOSS for [GSoC 2019](https://summerofcode.withgoogle.com/about/).

## Abstract

### NextCloudPi

Nextcloud requires many advanced tasks in order to be installed. NextCloudPi lowers the barrier and makes it easier to the end user by preconfiguring most of the setup. Extra features with minimal input help maintaining the installation.

Preinstalling and preconfiguring Nextcloud and all the related components (apache, php, mysql, redis, etc) as well as providing an easy to use interface makes it more user friendly to anyone who wants to take control of their private data.

*NextCloudPi* consists of code that provides the following components:
* A ready to use image for Raspberry Pi, Odroid HC1, rock64 and other boards
* Docker image (arm/arm64/x86)
* Curl Installer
* Extra features

It is an official project of Nextcloud, which is maintained by the community.

> You can find the source code on the [official project's Github repository](https://github.com/nextcloud/nextcloudpi)

> Check the full documentation at [docs.nextcloudpi.com](https://docs.nextcloudpi.com)

# NextCloudPi GSoC Project

This project aims to extend NextCloudPi with additional features. These features will not only offer end users more options, but will help NextCloudPi to become more prominent and enter the professional world.

## Branches
The several branches of the repository are explained below:
* Original branches with the latest commits of the official nextcloudpi repository:
  - origin/original-master: stable 
  - origin/original-devel: testing
* Up-to-date branches to the official nextcloudpi repository, mixed with my GSoC commits:
  - master: stable
  - devel: testing
* Outdated branches (compared to the official nextcloudpi repository), containing my GSoC commits exclusively
  - gsoc2019-master: stable
  - gsoc2019-devel: testing
* The rest branches are the development branches of each feature

## New Features

> On my [blog](https://www.fanilicious.me/category/gsoc/), under the category GSoC, there are several articles about all features created on this project.

### 1. CI/CD to build releases on GitHub  

Adapt the NextCloudPi project to the modern software development, Continuous Integration / Continuous Delivery, in order to reduce risks for each build and clear the way to get valuable features out to users faster.  

Travis CI was used to build, test and produce the docker images of NextCloudPi. 
The **travis.yml**, which triggers a build only at a tagged commit for gsoc2019-travis branch, implements 4 Build Stages with 3 parallel jobs running at each one of them.
The DockerHub credentials should be added to Travis page before using the travis.yml.

Some extra tools are implemented to provide automatic restart of failed jobs and clearing cache:
* **restart_failed_jobs.py :** Restarts any failed job, and does not return until all jobs pass. Before the execution, export you github token (export GITHUB_TOKEN=<github_token>). Execute the script after pushing a tagged commit.
* **clear_travis_cache :** Clears Travis machine cache. Before the execution, export you github token (export GITHUB_TOKEN=<github_token>). Execute the script before pushing a tagged commit, in order to have a clean cache at the new build.

The following flowchart describes the travis.yml file and how these tools are used:

![travis](https://www.dropbox.com/s/ghxqjw5mym404i9/TravisNCP.jpg?raw=1)

### 2. NextCloudPi VM on VirtualBox easy setup and clone using Vagrant**
Under the directory Vagrant, there is an automation script that creates a new NCP VM just by asking the user to provide a minimum input and can also create a clone of an existing NCP VM.
The Vagrantfile produced by the automation script differs from the one provided on the official nextcloudpi repository as it contains VirtualBox specific commands.
People who are having a hard time to setup a VM on their own will benefit from this script as it does not ask for any technical details.

**Usage:** ./create_vm.sh

[This](https://www.fanilicious.me/2019/08/23/nextcloudpi-vm-on-virtualbox-easy-setup-and-clone/) article provides a step-by-step tutorial with screenshots.


### 3. High availability option for big installations
Under the directory docker_swarm, there is a series of scripts that are used to create a distributed system of NextCloudPi, which replicates the data storage to all nodes.
Docker Swarm is used as the container orchestrator of the system and GlusterFS docker containers to provide replication and data persistence of NCP data storage.

* **IP_library.sh:** A library containing functions about the verification of IPs and choosing an available IP
* **create_swarm.sh:** The automation script that creates the NCP Docker Swarm system
* **destroy_swarm.sh:** Destroys existing NCP Swarm system
* **destroy_vagrant_vms.sh:** Destroys any vagrant workers created by the new_worker_vagrant.sh
* **docker_concurrent.sh:** Patch to increase the concurent downloads limit of Docker up to the number of workers of the Swarm
* **extra_node.sh:** Adds extra node worker to the existing Swarm system
* **gluster_setup.sh:** Setups GlusterFS on worker node
* **gluster_volume.sh:** Configures GlusterFS volume on worker node
* **monitor.sh:** Provide info about the Swarm System
* **new_worker_vagrant.sh:** Create new worker VM through Vagrant 

**Usage:** ./create_swarm.sh

![ncp_swarm](https://www.dropbox.com/s/q0placsqas5z4ey/Untitled%20Diagram%281%29.jpg?raw=1)

[This](https://ownyourbits.com/2019/08/21/make-your-nextcloudpi-highly-available/) article provides a step-by-step tutorial with screenshots.

### 3. Ansible role
Under the directory Ansible, there are Ansible playbooks of the bash scripts of NCP server. Ansible playbooks will be used to replace the execution of NCP server's bash scripts in order to provide an alternative option of configuring NCP.

**Usage (of each playbook):** ansible-playbook playbooks_name.yml --extra-vars "version=argument1 other_variable=argument2"

## Final Report Gist
You can find the final report [here](https://gist.github.com/FaniD/e3217375a38c161d7f426abfb3a84300).

## Future Work
* **Complete Ansible's task:** Sections CONFIG and SYSTEM are implemented. The rest sections should be converted also to Ansible playbook. When everything is converted, ncp-config should be updated using Ansible commands.
* **Fix travis.yml to produce native NCP images as well:** There was an issue with the Locales at the build phase of the native images. Should be resolved. Under the directory .travis/travis_instances/non-docker there are some yml files of the attempts used to produce native images.
* **Create AppArmor profile with SecureWilly tool**: An attempt was made to produce AppArmor profile for NCP but docker logs were not matching the template of SecureWilly. Needs investigation. Under the directory SecureWilly/Parser you can find the input_sample used as input to SecureWilly at this attempt.

## Members

* Google Summer of Code 2019 Participant: Fani Dimou ([FaniD](https://github.com/FaniD))
* Mentor: Panteleimon Sarantos ([Pant](https://github.com/Pant)) 
* Mentor: Efstathios Iosifidis ([iosifidis](https://github.com/iosifidis))
