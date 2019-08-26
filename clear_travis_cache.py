#!/usr/bin/env python3

"""

Automatic clearing travis cache

Before each build in Travis the cache
should be clean, for having a new clean
environment.
Before running this script, generate a
token on Github page 
(https://github.com/settings/tokens)
and export it on host machine as an
env var named GITHUB_TOKEN 
(EXPORT GITHUB_TOKEN=<github token>)

    python clear_travis_cache.py

"""

import subprocess, re, os, signal, sys

# Killing the running container of travis-cli
def docker_kill():
    subprocess.run("docker kill travis-cli", shell=True)
    return

def main():

    # Travis cli configuration

    # Build the travis cli docker image
    subprocess.run("cd .travis/travis-cli && docker build . -t travis-cli && cd ../..", shell=True)

    # Clearing cache needs to be made interactively so that travis login is verified
    subprocess.run("docker run --name travis-cli --rm -t -d -v $(pwd):/project --entrypoint=/bin/sh travis-cli", shell=True)

    # Get github token env var
    gh_token = os.environ['GITHUB_TOKEN']

    # Enter the running container with docker exec and login to travis
    command_docker = "docker exec travis-cli travis login --pro --org --github-token "
    command_docker += gh_token
    subprocess.run(command_docker, shell=True)

    # Run travis cache to delete all caches of the repo
    subprocess.run("docker exec travis-cli travis cache -f --delete", shell=True)

    # Kill travis-cli docker container
    docker_kill()

if __name__ == '__main__':
    try:
        main()
    except:
        print ('Caught error. Killing travis-cli container...')
        docker_kill()
        e = sys.exc_info()[0]
        print('Error:', e)
