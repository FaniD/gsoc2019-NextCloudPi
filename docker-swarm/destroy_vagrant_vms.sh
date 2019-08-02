#!/bin/bash

# If docker-machines exist only for this swarm, num of workers equals machines
# Otherwise needs num as input
workers=$(ls vagrant_workers | wc -l)
workers=$((workers - 1))
num_workers="${2:-$workers}"

for((i=1; i<="$num_workers"; i++)); do
  cd vagrant_workers/worker${i}
  vagrant destroy
  cd ../..
done

sudo rm -r vagrant_workers/worker*
