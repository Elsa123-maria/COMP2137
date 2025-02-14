#!/bin/bash

# System Report Header
USERNAME=$(whoami)
DATE_TIME=$(date)

echo ""
echo "System Report generated by $USERNAME, $DATE_TIME"
echo ""

# System Information
echo "System Information"
echo "------------------"
echo "Hostname: $(hostname)"
echo "OS: $(grep '^PRETTY_NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '\"')"
echo "Uptime: $(uptime -p)"
echo ""

# Hardware Information
echo "Hardware Information"
echo "--------------------"
echo "CPU: $(lscpu | grep 'Model name' | awk -F ': ' '{print $2}')"
echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "Disk(s):"
lsblk -d -o NAME,MODEL,SIZE | grep -v "NAME"
echo "Video: $(lspci | grep -i vga | awk -F ': ' '{print $2}')"
echo ""

# Network Configuration
echo "Network Information"
echo "-------------------"
echo "FQDN: $(hostname -f)"
echo "Host Address: $(ip route get 1 | awk '{print $7; exit}')"
echo "Gateway IP: $(ip route | grep default | awk '{print $3}')"
echo "DNS Server: $(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')"
echo ""

# System Status
echo "System Status"
echo "-------------"
echo "Users Logged In: $(who | awk '{print $1}' | sort | uniq | paste -sd ',' -)"
echo "Disk Space:"
df -h --output=target,avail | awk 'NR>1 {print $1, $2}'

echo "Process Count: $(ps aux --no-heading | wc -l)"
echo "Load Averages: $(awk '{print $1, $2, $3}' /proc/loadavg)"
echo "Listening Network Ports: $(ss -tuln | awk 'NR>1 {print $5}' | cut -d':' -f2 | sort -n | uniq | paste -sd ',' -)"
echo "UFW Status: $(sudo ufw status | grep -o 'Status:.*' | awk '{print $2}')"
echo ""
