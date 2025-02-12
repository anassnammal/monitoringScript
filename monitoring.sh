#!/bin/bash

# Function to format the output with proper spacing
monitoring_info() {
    # Architecture
      echo "#Architecture:     $(uname -a)"
    
    # CPU Information
      echo "#CPU physical:     $(lscpu | grep "Socket(s):" | awk '{ print $2 }')"
      echo "#vCPU:             $(lscpu | grep "^CPU(s):" | awk '{ print $2 }')"
    
    # Memory Usage
      echo "#Memory Usage:     $(free -m | awk 'NR==2{ printf "%s/%sMB (%.2f%%)", $3, $2, $3*100/$2 }')"
    
    # Disk Usage
      echo "#Disk Usage:       $(df -m --total | grep total | awk '{ printf "%s/%.1fGB (%s)", $3, $2/1024, $5 }')"
    
    # CPU Load
      echo "#CPU load:         $(top -bn1 | grep "Cpu(s)" | awk '{ printf "%.1f%%", $2 + $4 }')"
    
    # Last Boot
      echo "#Last boot:        $(who -b | awk '{ print $3" "$4 }')"
    
    # LVM Usage
      echo "#LVM use:          $(if lsblk | grep -q "lvm"; then echo "yes"; else echo "no"; fi)"
    
    # TCP Connections
      echo "#Connections TCP:  $(netstat -ant | grep ESTABLISHED | wc -l) ESTABLISHED"
    
    # User Count
      echo "#User log:         $(who | cut -d" " -f1 | sort -u | wc -l)"
    
    # Network Information
      echo "#Network:          IP $(hostname -I | awk '{print $1}')($(ip link | grep "link/ether" | awk '{print $2}' | head -n1))"
    
    # Sudo Commands
      echo "#Sudo:             $(journalctl _COMM=sudo | grep COMMAND | wc -l) cmd"
}

# Broadcast
monitoring_info | wall
