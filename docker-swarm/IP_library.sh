#!/bin/bash

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

  # Public networking is used
  local hostIP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
  local ip_mask=$(ip addr | grep ${hostIP} | awk '$1 ~ /^inet/ {print $2}')
  local prefix=$(cut -d'/' -f2 <<<"$ip_mask")

  IFS=. read -r io1 io2 io3 io4 <<< "$hostIP"
  IFS=. read -r xx mo1 mo2 mo3 mo4 <<< $(for a in $(seq 1 32); do if [ $(((a - 1) % 8)) -eq 0 ]; then echo -n .; fi; if [ $a -le $prefix ]; then echo -n 1; else echo -n 0; fi; done)
  local net_addr="$((io1 & mo1)).$((io2 & mo2)).$((io3 & mo3)).$((io4 & mo4))"

  local base="${io1}.${io2}.${io3}"
  local lsv=$(cut -d'.' -f4 <<<"$net_addr")

  while [ $lsv -le 255 ]; do
    lsv=$(( lsv + 1 ))
    starting="${base}.${lsv}"
    try_ip="${base}.${lsv}"
    if valid_ip $try_ip && ! reserved_ip $try_ip ; then
      echo "${try_ip}"
      return 0
    fi
  done
}
