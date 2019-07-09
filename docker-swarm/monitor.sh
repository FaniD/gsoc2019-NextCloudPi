#!/bin/bash

echo "Docker Images:"
docker ps 

echo -e "\nNodes of swarm system:"
docker node ls

echo -e "\nDocker machines:"
docker-machine ls

echo -e "\nDocker services:"
docker service ls
