#!/bin/bash

cols=$(tput cols)
hashes=$((($cols-34)/2))
ehashes=$(($cols-1))


echo  `printf '%*s' "$hashes" | tr ' ' '#'` `date` `printf '%*s' "$hashes" | tr ' ' '#'` \
      $'\n #\033[1;4;32mArchitecture:\033[0m\t\t '`uname -a` \
      $'\n #\033[1;4;32mCPU physical:\033[0m\t\t '`lscpu | grep "Socket(s):" | awk '{ print $2}'` \
      $'\n #\033[1;4;32mvCPU:\033[0m\t\t\t '`lscpu | grep "^CPU(s):" | awk '{ print $2}'` \
      $'\n #\033[1;4;32mMemory Usage:\033[0m\t\t '`free --mega | awk 'NR==2{ printf "%s/%sMB (%.2f%%)", $3, $2, $3 *100 / $2 }'` \
      $'\n #\033[1;4;32mDisk Usage:\033[0m\t\t '`df -m --total | grep total | awk '{ printf "%s/%.2fGB (%s)", $3, $2 / 1024, $5 }'` \
      $'\n #\033[1;4;32mCPU load:\033[0m\t\t '`top -bn1 | grep "Cpu(s)" | awk '{ printf "%.2f%%", $2 + $4 }'` \
      $'\n #\033[1;4;32mLast boot:\033[0m\t\t '`who -b | awk '{ print $3" "$4 }'` \
      $'\n #\033[1;4;32mLVM use:\033[0m\t\t '`lsblk |grep lvm | awk '{ if ($1) { print "yes";exit;} else {print "no"} }'` \
      $'\n #\033[1;4;32mConnection TCP:\033[0m\t '`netstat -t | grep ESTABLISHED |  wc -l` 'ESTABLISHED' \
      $'\n #\033[1;4;32mUser log:\033[0m\t\t '`who | cut -d " " -f1 | sort -u | wc -l` \
      $'\n #\033[1;4;32mNetwork:\033[0m\t\t IP '`hostname -I`"("`ip link | awk 'NR==4{ print $2 }'`")" \
      $'\n #\033[1;4;32mSudo:\033[0m\t\t\t '`grep 'COMMAND' /var/log/sudo/sudo.log | wc -l` ' cmd' \
      $'\n' \
      `printf '%*s' "$hashes" | tr ' ' '#'` `date` `printf '%*s' "$hashes" | tr ' ' '#'`
