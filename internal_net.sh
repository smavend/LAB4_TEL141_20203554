#!/bin/bash

if [ $# -lt 4 ]; then
	echo "4 arguments needed. Use: bash $0 <networkName> <vlanID> <ipCIDR> <DHCPstart>-<DHCPend>"
	exit 1
fi

networkName=$(echo "$1" | sed 's/ /_/g')

if ! [[ "$2" =~ ^[0-9]+$ ]]; then
	echo "vlanID must be a number."
	exit 1
fi

vlanID=$(($2))

if ((vlanID < 1)) || ((vlanID > 4094)); then
	echo "Invalid vlanID."
	exit 1
fi

ip_format='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'

if [[ ! "$3" =~ $ip_format ]]; then
	echo "Network IP must be in CIDR format and a valid IP address."
	exit 1
fi

ip_range_format='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\-(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'

if [[ ! "$4" =~ $ip_range_format ]]; then
	echo "DHCP IP range must be valid."
	exit 1
fi

IFS='-' read -r DHCPstart DHCPend <<<"$4"

# Getting network IP address
IFS='/' read -r ipAddress netmask <<<"$3"
netmask_stable="$((netmask))"
IFS='.' read -r -a octates <<<"$ipAddress"

toBinary() {
	printf '%08d\n' "$(echo "obase=2;$1" | bc)"
}

declare -a octates_bin

octates_bin[0]=$(toBinary "${octates[0]}")
octates_bin[1]=$(toBinary "${octates[1]}")
octates_bin[2]=$(toBinary "${octates[2]}")
octates_bin[3]=$(toBinary "${octates[3]}")

network_ip_bin=""
netmask_ip_bin=""

for ((i = 0; i < 4; i++)); do
	for ((j = 0; j < 8; j++)); do
		bit_ip="${octates_bin[$i]:$j:1}"
		if [ "$((netmasl))" -ge 1 ]; then
			netmask_ip_bin+="1"
			if [ "$((bit_ip))" -eq 1 ]; then
				network_ip_bin+="1"
			else
				network_ip_bin+="0"
			fi
		else
			netmask_ip_bin+="0"
		fi
		((netmask--))
	done
done

declare -a network_ip
network_ip[0]=$((2#${network_ip_bin:0:8}))
network_ip[1]=$((2#${network_ip_bin:8:8}))
network_ip[2]=$((2#${network_ip_bin:16:8}))
network_ip[3]=$((2#${network_ip_bin:24:8}))

declare -a netmask_ip
netmask_ip[0]=$((2#${netmask_ip_bin:0:8}))
netmask_ip[1]=$((2#${netmask_ip_bin:8:8}))
netmask_ip[2]=$((2#${netmask_ip_bin:16:8}))
netmask_ip[3]=$((2#${netmask_ip_bin:24:8}))

netmask_ip_join=${netmask_ip[0]}.${netmask_ip[1]}.${netmask_ip[2]}.${netmask_ip[3]}
network_ip_join=${network_ip[0]}.${network_ip[1]}.${network_ip[2]}.${network_ip[3]}
ip_first=${network_ip[0]}.${network_ip[1]}.${network_ip[2]}.${network_ip[3]+1}

sudo ovs-vsctl add-port br-int vlan$vlanID tag=$vlanID -- set interface vlan$vlanID type=internal
sudo ip addr add $ip_first/$netmask_stable dev vlan$vlanID #? gateway
sudo ip link set vlan$vlanID up

sudo ip netns add ns_1
ip link set vlan$vlanID netns ns_1

sudo ip netns exec ns_1 ip link set dev lo up
sudo ip netns exec ns_1 ip link set dev vlan$vlanID up

ip link set dev br-int up

ip_second=${network_ip[0]}.${network_ip[1]}.${network_ip[2]}.${network_ip[3]+2}

#sudo ip netns exec ns_1 ip address add $ip_first/$netmask_stable dev $networkName #?

sudo ip netns exec ns_1 dnsmasq --interface=vlan$vlanID --dhcp-range:"$DHCPstart","$DHCPend","$netmask_ip_join" --dhcp-option=6,8.8.8.8
