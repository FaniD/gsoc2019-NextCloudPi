# The missing features of NextCloudPi - Google Summer of Code 2019

![NCP_gsoc logo](https://lh3.googleusercontent.com/Uyfx2IS5XAwGjKBrJoT9HXHz2tSlehIerZlnrx7C85sXMVmSl-XZu3Al7s-9KmnYWbIOuVLa4cfIVEdS81RoIyigZmeKEuYUKYF5cILAYWdY8_Znh0l6dosKIWiS85s_HkJpGluMYdcgT_s_jfoRpSnNE0DMZ7PVorPaPdLNAVyUwuwspP1X4iWG_xVohvpOeT7xe_KYzOqPGOldhzPjkYSe2M8BPUHk51bHWbKBMsE3Xp5FKPjlG877F5Haes_rMZiZR-0m6iutJZ3JYXFUCdYBbmoEQCQzdWWRzC3mbn4zt3e8eCfO8GWsbEqGeDnIQ3zydu0F4jhOyvMM2xqT-tDhS0MskfZAmrlrGWIfe6IDOI5_csIWCB-K9m2w4pGu-izlcHZET4d_PhvBUTQC4GS8wkIUhJPpGLcHdSuhEDUUlGZFyheRsbEXSUmdRHUpUnkL1BIgP_ZYSNJBvmPxoyD8ghim51rYKmdlDEGLl1cqcu573LsjxStt_7c2seY-dVt2ccfBsfuDveieLhuvzq1Z8FFVqEDwvQw3o7GR62UOi08FoIaSD8QUxAMqr949ztwbQGkP2kydvFKE5jufpwlceVSoShEXFqf9mA1pAVwvaHBlaDe4al_ZDdm_oZu4Y_u0Cv9diS_JT2mII3vLiFHYsBlFLUo=w780-h374-no)

**NextCloudPi GSoC Project** is one of the accepted projects by GFOSS for [GSoC 2019](https://summerofcode.withgoogle.com/about/).

> You can find the proposal that made this project selected [here](https://storage.googleapis.com/summerofcode-prod.appspot.com/gsoc/core_project/doc/6113984657227776_1554818502_Proposal.pdf?Expires=1557956101&GoogleAccessId=summerofcode-prod%40appspot.gserviceaccount.com&Signature=hN4y0k1e8BqXOc8QTr4DIeeWBI6dIjmmNu%2BrnnSq3fLqq58B3KSvMtbk6Hjxn%2FV3llXabBf21qOm3IPTV0kkcQLriafuzK95zsJEUBTTr2xMErzsyLgi2fhHezWJ%2F%2F7B4126iskkcjC4K9bUqYv0%2FoEtATsOjZ4RRcxbVC%2BeOg4gmQhjTowFQnAa0C2pqa3Hq3c4Y0n8f%2BcMz%2FeB29KSvDYGrJL5%2FGO%2BBHtvuKYhErWqo27A4rgDK8NNLED%2FetHM%2F%2FY0TjDPYzGm5jqEFlMJjVzfUsmxM0oQfxoU8MWdK7ZWDQd8buHRCezMpTt3I%2FmlWhr8MtUprKlP%2Fbwk%2FkD4cQ%3D%3D)

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


## Features

### 1. Nextcloud Native NCP App - Web panel

  * Convert the existing web panel for the NCP options into a native application.
  * Simple interface for the management of NCP, consisting of a welcome page displaying in boxes all of the options of ncp-config - Backups, Config, Networking, Security, System, Tools - and each one of them will display a list of its features.
  * Include a link to Netdata - a highly optimized monitoring agent - for systems and applications that could be installed on NCP (will be implemented as an option in NCP config).
  * Create Backups-Restore/Import-Export/Snapshots UI: NCP provides a plan for creating backups and restoring them and a UI but requires the users to study an uneeded complex procedure. Therefore, there is a major need to create a handy UI for these features.

### 2. CI/CD to build releases on GitHub  

Adapt the NextCloudPi project to the modern software development, Continuous Integration / Continuous Delivery, in order to reduce risks for each build and clear the way to get valuable features out to users faster.  

A CI/CD system will be used to run tests (curl installer + testing scripts) and automatically create the images (arm/docker)

### 3. Mobile App  

A Pogressive Web App (PWA) will be implemented in order to allow us to provide users with an app-like experience of NCP, without the hassle of actually building an application. Meaning we will be able to use the existing responsive UI of Nextcloud’s application. Moreover, the PWA that will be created will be available for every platform (iOS, Android, Windows mobile, Windows, MacOSX, Linux).

### 4. Ansible role  

Ansible could be used in NCP project in order to configure the NCP server. The operations (scripts) of each command in ncp-config options - Backups, Config, Networking, Security, System, Tools - will be implemented as an Ansible role, where will be able to be used in Ansible tasks and handlers which will be using Ansible facts and vars.

### 5. LDAP

The activation of an existing LDAP server will be implemented and NCP should also include the possibility of installing and configuring an LDAP server, in case of non existence of it.

### 6. OnlyOffice easy installation  

* Installing OnlyOffice on x64 machine  
    On a fresh Debian installation a bash script will be executed from ssh to install docker.io, configure the docker container of Onlyoffice (expose ports, share vol-
umes, etc) and run it. The user will be asked to provide the domain (or sub-domain) name OnlyOffice Document Server will be served from, IP or Domain at which the machine can be reached, the choice of using an SSH key or password and the password (optional).
* Developping ARM Docker containers of OnlyOffice  
   The Dockerfile from the official OnlyOffice Github repository will be used as a base and the appropriate changes will be made in order to adapt it to ARM architecture.
More specifically, the pre-compiled libraries will be compiled for the ARM architecture and will be used to create a new docker image, focusing on ARM architecture. Afterwards, the same steps we described above will be followed as in a x64 system.

### 7. Collabora online easy installation  

The implementation of Collabora online will follow the exact same steps that I described for the implementation of Onlyoffice. The only difference lies in the configuration of the docker container of Collabora online.

### 8. Mail server

An existing Docker image to use for incoming and outgoing email communication. A bash script will make the installation and configuration with minimal user actions and input. More specifically, the user will have to create an MX Record in his DNS provider, configure his router for specific ports that have to be port-forwarded and submit this domain when requested (from NCP App user interface).

### 9. Vagrant installation

NCP project already provides a Vagrantfile in the Github repository and therefore, it will be used in order to test Vagrant in several configurations.

### 10. High availability option for big installations 

This option will be implemented using a Docker Swarm system and will be easily set up through a bash script or an Ansible playbook, requiring the domain (or sub-domain) on which Nextcloud will be served, IP or Domain on which x64 machines can be reached with SSH, the choice of using an SSH key or password and the password (optional).  
The following figure illustrates the Docker Swarm system we describe.

![Docker Swarm system](https://lh3.googleusercontent.com/8mMQ9WVRkKcjzz1WRlRx34ucduzmvQduACOPo6lzfIXR2IKEkPLXdOvnCtJNV7HIbOLNbR3nO9oGLuvwWF8k_nA3f9vF-EikvtGWVokS3GXr_ORh4oB1NFuBGuxPvOYdzdaWlNqFxcjsoAh1SQEkBsSjO89igF1xMezgUQoU1lzElegbSLdEfv7Zed-C5B8Bl2OvVj8MhCtW3s4n09cMwEtbBy4wA2kxT3YO1tvQCw1-hBp9xIxxCqLzvo2VW6rsBZbbbstoeTY3bWj2ooYFzTYG_Y6wDuxmYplHQ3di4Pap3uUgOker3zbU_mu_9O-J-5pgJ9gDMfyTcuS02DbsPXIKd9Iiisj9Qm4jlt-Ue1IE3CNz1C06EMPiUAdNVC_LBR4fC8_biOWtLq-QhuRccD2ET-uVy4S0l-iP8B5z4K0T4ooHhqe8oZdIKixJQgv67ekZL2RE-J-WTYGaEPp2I0wXncCevotOOD-mGPQhu0g6yjHnAle-TZAuyMYyBMQNpoCSdHR3dQiWjzxPiqw6Wj0gy0x6t70Gji5Fd_wvjxORJVeLwBmuWfoVTkj1PctAwGcBK-A-S0gt8DpZuIpqHmIbYErL9yJGNyAvox4_cDmI9IjiCtecK5FIWOjMmXNTF2r4f0bfnIinUVx7-dlKx4u3IhpLrrU=w681-h363-no)

### 11. Nextcloud Talk

Nextcloud Talk is a shiny new feature of Nextcloud. It is a fully self hosted, on-premises audio/video and chat communication service, which takes Nextcloud to the
next level by ensuring the complete control of user’s communications.  
Easy installation will be implemented through a bash script which will be connected to a Nextcloud talk app inside the NCP.

### 12. VPN server

An easy way for someone to connect to an existing VPN server as well as the installation and pre-configuration of a VPN server (OpenVPN) would be very beneficial for NextCloudPi users. The implementation of a VPN server will be divided in two phases, based on the existance or not of a VPN server:  
  * The procedure of the connection to an existing VPN server will consist of setting up an OpenVPN client by importing a configuration file.
  * As for the installation of the VPN server in case it does not exist, Docker container would constitute again an easy solution. Thus, a bash script will be created to automatically configure and run a Docker container of OpenVPN server. Part of the installation will be the production of a client configuration file which will be used by
the user in order to connect to NextCloudPi VPN.

### 13. SecureWilly

[SecureWilly](https://github.com/FaniD/SecureWilly) is an open source software I created which automatically creates AppArmor profiles to harden the security of docker containers. This software has already been tested on a Nextcloud instance, in the context of my Diploma Thesis, and could be used to provide AppArmor profiles for any docker containers used inside the NCP project, in order to harden its security.

### 14. Documentation

After completing each task, I intend to write a documentation on it, providing examples and even create a small video for end-users, using the Openshot video editor.

# Project Timeline

_In accordance with the official [GSoC timeline](https://summerofcode.withgoogle.com/how-it-works/#timeline)._

1. Community Bonding (May 6 - May 26)
  * Configuring the communication and co-operation process with my mentors.
  * Discuss about the project's architecture and implementation details.
  * Make a thorough research on the official project's source code.
  * Get familiar with the tools that are going to be used.

2. Coding (May 27 - August 19)

![Timeline](https://lh3.googleusercontent.com/yom4jnbJuWRwjUWika9AZG1NLd1D_CzZKCGN0lYdiP64uIqTKnJ_UzB1TUR9dZr9lbyJQ6DoOoKlnqwx38ezufLACluJIbH-E6vl6kOqy8ijNZ89CnveHHCRq76m541gCgd_LIWK79h4cREThFBTZ-915XDdf5wnQ1X1z_sp9CZ5DGGIK2da33MP6eJJJMqHX-FLpfL5WjZYB5EMQY3jM5c39a_VxhAI0wU_8-Inpo8534Bn234dfeWnYVtx3sqmbn5MPvr-myvZE5zMoAzKfDCH9mwypMeeq07me0rsLsb_ttEarjahGxqlj5dpDzU8qCyJrauFvcxqgHio8dUPYGAD1n-3-tjrPMw0kcVLSMw4Zfn30MFAU0h8FeDrasg6STZRlWUQAdEPoZhs0cXDvgFWbKjF8BujQ-kYP1xgxn1i92ZK9_xRtw-lVVEp_tJRjNptNKk7PzXWkX4BFENM1np1OEvTokjxMj3itV7tvN-kF4-hiNgV6J3qJvqj-dgd170Wc5Vv42_QVplWHJhWF1Eaf8nZpeEO6PzOatazIfnVAVXCFf52qz8mEHAiE98wRPCoSYI-88f8e3fHKqoklnhPZ_9-LFpSqDZ0CaMuUwuEcEiBB3xAbylpDmLrZABvOjxEB848gX_yo8i9O3rxZmkbF8HOXLI=w705-h389-no)

## Members

* Google Summer of Code 2019 Participant: Fani Dimou ([FaniD](https://github.com/FaniD))
* Mentor: Panteleimon Sarantos ([Pant](https://github.com/Pant)) 
* Mentor: Efstathios Iosifidis ([iosifidis](https://github.com/iosifidis))
