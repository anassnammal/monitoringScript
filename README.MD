## Bash script that prints system information to the wall command. The system information includes

<b>Architecture:</b> Outputs the output of the uname -a command, which displays information about the current operating system and hardware platform<br>
<b>CPU physical:</b> Outputs the number of physical sockets on the system, as obtained by parsing the output of the lscpu command using grep and awk<br>
<b>vCPU:</b> Outputs the number of virtual CPUs on the system, as obtained by parsing the output of the lscpu command using grep and awk<br>
<b>Memory usage:</b> Outputs the current and total amount of memory in the system, as well as the percentage of memory that is in use, as obtained by parsing the output of the free -m command using awk<br>
<b>Disk usage:</b> Outputs the current and total amount of disk space in the system, as well as the percentage of disk space that is in use, as obtained by parsing the output of the df -m --total command using grep and awk<br>
<b>CPU load:</b> Outputs the current CPU load as a percentage, as obtained by parsing the output of the top -bn1 command using grep and awk<br>
<b>Last boot:</b> Outputs the date and time of the last system boot, as obtained by parsing the output of the who -b command using awk<br>
<b>LVM use:</b> Outputs whether the system is using logical volume management (LVM), as determined by searching for the presence of LVM block devices using lsblk and grep<br>
<b>Connection TCP:</b> Outputs the number of established TCP connections on the system, as obtained by parsing the output of the netstat -t command using grep and wc<br>
<b>User log:</b> Outputs the number of logged-in users on the system, as obtained by parsing the output of the who command using cut, sort, and wc<br>
<b>Network:</b> Outputs the system's IP address and the name of the network interface, as obtained by running the hostname -I and ip commands and parsing their output using awk<br>
<b>Sudo:</b> Outputs the number of sudo commands that have been run on the system, as obtained by parsing the /var/log/auth.log file using grep and wc<br>


