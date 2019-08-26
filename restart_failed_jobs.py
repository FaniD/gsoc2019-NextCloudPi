#!/usr/bin/env python3

"""

Automatic restarting failed jobs on Travis

This script constitutes an agent on host who
uses travis-cli to monitor the status of the
most recent build and restart any failed jobs.
Before running this script, generate a token on
Github page (https://github.com/settings/tokens)
and export it on host machine as an env var
named GITHUB_TOKEN
(EXPORT GITHUB_TOKEN=<github token>)
The script will return when the build passes.

    python restart_failed_jobs.py

"""

import subprocess, re, os, signal, sys

# Signal handler for termination signals
def termination_signal_handler(signalNumber, frame):
    print ('\nReceived signal no ', signalNumber, '\nKilling travis-cli container...')
    docker_kill()
    raise SystemExit (1)
    return

signal.signal(signal.SIGTERM, termination_signal_handler)
signal.signal(signal.SIGINT, termination_signal_handler)

# Killing the running container of travis-cli
def docker_kill():
    subprocess.run("docker kill travis-cli", shell=True)
    return

def main():

    # Travis cli configuration

    # Build the travis cli docker image
    subprocess.run("cd .travis/travis-cli && docker build . -t travis-cli && cd ../..", shell=True)

    # Restarts need to be made interactively so that travis login is verified
    subprocess.run("docker run --name travis-cli --rm -t -d -v $(pwd):/project --entrypoint=/bin/sh travis-cli", shell=True)

    # Get github token env var
    gh_token = os.environ['GITHUB_TOKEN']

    # Enter the running container with docker exec and login to travis
    command_docker = "docker exec travis-cli travis login --pro --org --github-token "
    command_docker += gh_token
    subprocess.run(command_docker, shell=True)

    # Travis Build

    build_state = ''
    restart_attempt = 0
    # A daemon will run this block of code until the build is successful
    while (build_state != 'passed'):

        flag_attempt = 1

        # Run travis show to get info about the build state and its jobs
        travis_show = subprocess.run("docker exec travis-cli travis show", shell=True, encoding='utf-8', stdout=subprocess.PIPE)
        travis_show = travis_show.stdout.split('\n')
        
        subprocess.run("sleep 5", shell=True)

        # Extract status and number of current build
        build_state = travis_show[1].split()[1]
        build_num = travis_show[0].split()[1].lstrip('#').rstrip(':')

        # Extract info about jobs
        jobs = []
        for line in travis_show:
            if line.startswith('#'):
                jobs.append(line)

        for job in jobs:
            if any(status in job for status in ['failed:', 'errored:', 'canceled:']):
                num = job.split()[0].split('.')[1]
                restart_job = 'docker exec travis-cli travis restart '
                restart_job += build_num + '.' + num
                if flag_attempt:
                    restart_attempt+=1
                    print ('\n===Restart attempt no ' + str(restart_attempt) + '===')
                print ('Job ' + build_num + '.' + num + ' has failed. Restarting...')
                subprocess.run(restart_job, shell=True)
                flag_attempt = 0
    
    # Kill travis-cli docker container
    docker_kill()

if __name__ == '__main__':
    try:
        main()
    except (SystemExit):
        print ('Exiting gracefully...')
    else:
        print ('Caught error. Killing travis-cli container...')
        docker_kill()
        e = sys.exc_info()[0]
        print('Error:', e)
        
