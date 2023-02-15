#!/bin/bash

wall  $'#Architecture: '`uname -a` \
      $'\n#CPU physical: '`lscpu | grep "Socket(s):" | awk '{ print $2}'` \
      $'\n#vCPU: '`lscpu | grep "^CPU(s):" | awk '{ print $2}'` \
      $'\n'`free --mega | awk 'NR==2{ printf "#Memory Usage: %s/%sMB (%.2f%%)", $3, $2, $3 *100 / $2 }'` \
      $'\n'`df -m --total | grep total | awk '{ printf "#Disk Usage: %s/%.2fGB (%s)", $3, $2 / 1024, $5 }'` \
      $'\n'`top -bn1 | grep "Cpu(s)" | awk '{ printf "#CPU load: %.2f%%", $2 + $4 }'` \
      $'\n#Last boot: '`who -b | awk '{ print $3" "$4 }'` \
      $'\n#LVM use: '`lsblk |grep lvm | awk '{ if ($1) { print "yes";exit;} else {print "no"} }'` \
      $'\n#Connection TCP: '`netstat -t | grep ESTABLISHED |  wc -l` 'ESTABLISHED' \
      $'\n#User log: '`who | cut -d " " -f1 | sort -u | wc -l` \
      $'\nNetwork: IP '`hostname -I`"("`ip link | awk 'NR==4{ print $2 }'`")" \
      $'\n#Sudo: '`grep 'sudo' /var/log/sudo/sudo.log | wc -l`' cmd'
