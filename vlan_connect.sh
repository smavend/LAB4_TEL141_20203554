#!/bin/bash

if [ $# -lt 2 ]; then
	echo "2 arguments needed. Use: bash $0 <VLAN_ID1> <VLAN_ID2>"
	exit 1
fi

vlanID1="$1"
vlanID2="$2"

echo 1 >/proc/sys/net/ipv4/ip_forward

iptables -A FORWARD -i vlan$vlanID1 -o vlan$vlanID2 -j ACCEPT
iptables -A FORWARD -i vlan$vlanID2 -o vlan$vlanID1 -j ACCEPT

echo "Closing script..."
