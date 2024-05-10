#!/bin/bash

if [ $# -ne 1 ]; then
	echo "1 argument required. Use: bash $0 <VLAN_ID>"
	exit 1
fi

vlan_id="$1"

echo 1 >/proc/sys/net/ipv4/ip_forward

iptables -A FORWARD -i vlan$vlan_id -o ens3 -j ACCEPT
iptables -A FORWARD -i ens3 -o vlan$vlan_id -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Closing script internet..."
