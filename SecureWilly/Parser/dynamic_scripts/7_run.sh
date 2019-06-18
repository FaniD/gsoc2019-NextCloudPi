#!/bin/bash
 
IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
echo "${IP}"
docker run -d -t -p 4443:4443 -p 443:443 -p 80:80 -v ncdata:/data --name nextcloudpi ownyourbits/nextcloudpi-x86:latest ${IP}
export MOZ_HEADLESS=1
sleep 60
./../../tests/activation_tests.py ${IP}
sleep 60
./../../tests/nextcloud_tests.py ${IP}
sleep 5
./../../tests/system_tests.py ncp@${IP}
docker kill nextcloudpi
