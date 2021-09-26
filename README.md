![GitHub](https://img.shields.io/github/license/d3athkai/MOTD-Login-Banner-for-Linux?style=plastic) ![GitHub](https://img.shields.io/badge/RedHat-7/8-green?style=plastic) ![GitHub](https://img.shields.io/badge/CentOS-7/8/Stream-green?style=plastic) ![GitHub](https://img.shields.io/badge/RockyLinux-All-green?style=plastic) 

# Initial Setup for Linux

This script is used to setup the following after cloning the golden Linux VM:
* hostname
* IP address
* IP Prefix
* Gateway
* Disable root account (Update */etc/passwd* to */sbin/nologin*)
  
## Assumption
* Only 1 network adapter and is named *eth0*
* Only 1 IP address to be updated
  
## Compatibility
This script tested working with Red Hat Enterprise Linux 7 & 8 / CentOS 7, 8 & Stream / Rocky Linux.  
  
## Setup
Upload the script to the server and execute it: 
```
chmod +x initial-configuration.bash
./initial-configuration.bash
```  
  
