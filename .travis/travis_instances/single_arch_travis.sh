#!/bin/bash

echo "Which arch would you like to build?"
echo "x86/armhf/arm64"
read arch

cat <<'EOF' > travis_${arch}.yml
stages:
        - building_part1
        - building_part2
        - testing
        - release
sudo: required
language: generic
dist: xenial
branches:
  only:
        - gsoc2019-travis
cache:
  directories:
        - docker_cached
jobs:
  include:
        - stage: building_part1

          install:
          #- sudo apt-get --yes --no-install-recommends install binfmt-support qemu-user-static
          - ./.travis/configure_docker.sh
          - export DOCKER_CLI_EXPERIMENTAL=enabled #enable experimental features

          script:
          - while sleep 9m; do echo "=====[ $SECONDS seconds, build-docker still building... ]====="; done & 
          - DOCKER_BUILDKIT=1 docker build . -f docker/debian-ncp/Dockerfile -t ownyourbits/debian-ncp-amd64:latest --pull --build-arg arch=amd64 --build-arg arch_qemu=x86_64 > output
          - sed -i "/innodb_file_format=barracuda/a open_files_limit=65536" lamp.sh
          - DOCKER_BUILDKIT=1 docker build . -f docker/lamp/Dockerfile -t ownyourbits/lamp-amd64:latest --build-arg arch=amd64 > output
          - sed -i '/open_files_limit=65536/d' lamp.sh
          - docker save --output docker_cached/debian-ncp-amd64.tar ownyourbits/debian-ncp-amd64:latest
          - docker save --output docker_cached/lamp-amd64.tar ownyourbits/lamp-amd64:latest

        - stage: building_part2

          install:
          #- sudo apt-get --yes --no-install-recommends install binfmt-support qemu-user-static
          - ./.travis/configure_docker.sh
          - export DOCKER_CLI_EXPERIMENTAL=enabled #enable experimental features

          before_script:
          - docker load --input docker_cached/lamp-amd64.tar
 
          script:
          - while sleep 9m; do echo "=====[ $SECONDS seconds, build-docker still building... ]====="; done & 
          - DOCKER_BUILDKIT=1 docker build . -f docker/nextcloud/Dockerfile -t ownyourbits/nextcloud-amd64:latest --build-arg arch=amd64 > output
          - DOCKER_BUILDKIT=1 docker build . -f docker/nextcloudpi/Dockerfile -t ownyourbits/nextcloudpi-amd64:latest --build-arg arch=amd64 > output
          - docker save --output docker_cached/nextcloud-amd64.tar ownyourbits/nextcloud-amd64:latest
          - docker save --output docker_cached/nextcloudpi-amd64.tar ownyourbits/nextcloudpi-amd64:latest

        - stage: testing

          install:
          #- sudo apt-get --yes --no-install-recommends install binfmt-support qemu-user-static
          - ./.travis/configure_docker.sh
          - export DOCKER_CLI_EXPERIMENTAL=enabled #enable experimental features 
          - export MOZ_HEADLESS=1
          - sudo apt-get install python3-pip
          - sudo python3 -m pip install selenium
          - wget https://github.com/mozilla/geckodriver/releases/download/v0.24.0/geckodriver-v0.24.0-linux64.tar.gz
          - tar -xvzf geckodriver*
          - chmod +x geckodriver
          - export PATH=$PATH:$PWD

          before_script:
          - docker load --input docker_cached/nextcloudpi-amd64.tar
          - IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
          - docker run -d -p 443:443 -p 4443:4443 -p 80:80 -v ncdata:/data --name nextcloudpi ownyourbits/nextcloudpi-amd64:latest ${IP}

          script:
          - ./tests/activation_tests.py ${IP}
          - sleep 60
          - ./tests/nextcloud_tests.py ${IP}
          - sleep 5
          - ./tests/system_tests.py ncp@${IP}
 
        - stage: release

          install:
          #- sudo apt-get --yes --no-install-recommends install binfmt-support qemu-user-static
          - ./.travis/configure_docker.sh
          - export DOCKER_CLI_EXPERIMENTAL=enabled #enable experimental features

          before_script:
          - docker load --input docker_cached/debian-ncp-amd64.tar
          - docker load --input docker_cached/lamp-amd64.tar
          - docker load --input docker_cached/nextcloud-amd64.tar
          - docker load --input docker_cached/nextcloudpi-amd64.tar
          - version=$(git describe --tags --always)
          - version=${version%-*-*}

          script:
          - docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD

          - docker tag ownyourbits/debian-ncp-amd64:latest $DOCKER_USERNAME/debian-ncp-x86:"${version}"
          - docker tag ownyourbits/lamp-amd64:latest $DOCKER_USERNAME/lamp-x86:"${version}"
          - docker tag ownyourbits/nextcloud-amd64:latest $DOCKER_USERNAME/nextcloud-x86:"${version}"
          - docker tag ownyourbits/nextcloudpi-amd64:latest $DOCKER_USERNAME/nextcloudpi-x86:"${version}"

          - docker push $DOCKER_USERNAME/debian-ncp-x86:"${version}"
          - docker push $DOCKER_USERNAME/lamp-x86:"${version}"
          - docker push $DOCKER_USERNAME/nextcloud-x86:"${version}"
          - docker push $DOCKER_USERNAME/nextcloudpi-x86:"${version}"

notifications:
        email: false
EOF

if [[ "$arch" != "x86" ]]; then

  [[ "$arch" == armhf ]] && sed -i "s/amd64/armhf/g" travis_${arch}.yml && sed -i "s/arch_qemu=x86_64/arch_qemu=arm/" travis_${arch}.yml
  [[ "$arch" == arm64 ]] && sed -i "s/amd64/arm64v8/g" travis_${arch}.yml && sed -i "s/arch_qemu=x86_64/arch_qemu=aarch64/" travis_${arch}.yml

  sed -i "s/x86/${arch}/g" travis_${arch}.yml
  sed -i "20s,#,," travis_${arch}.yml
  sed -i "36s,#,," travis_${arch}.yml
  sed -i "53s,#,," travis_${arch}.yml
  sed -i "79s,#,," travis_${arch}.yml
fi

echo "Your produced travis file is: travis_${arch}.yml"
