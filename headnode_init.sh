#!/bin/bash

if [ $# -lt 2 ]; then
	echo "At least 2 arguments. Use: bash $0 <OvSname> <ToConnectInterfaces>"
	exit 1
fi

ovs_name=$(echo "$1" | sed 's/ /_/g')
ovs_exist=$(sudo ovs-vsctl list-br | grep -c "$ovs_name")

if [ "$ovs_exist" -eq 0 ]; then
	echo "Creating '$ovs_name' OvS..."
	sudo ovs-vsctl add-br "$ovs_name"
	echo "Succesfully created."
else
	echo "'$ovs_name' OvS already exists."
fi

for interface in "${@:2}"; do
	sudo ovs-vsctl add-port "$ovs_name" "$interface"
	if [ $? -eq 0 ]; then
		echo "Interface $interface succesfully connected to $ovs_name OvS."
	else
		echo "There was an error connecting $interface interface to $ovs_name Ovs."
	fi
done

sudo sysctl -w net.ipv4.ip_forward=1

if [ "$(sysctl -n net.ipv4.ip_forward)" -eq 1 ]; then
	echo "IP Forwarding was succesfully activated."
else
	echo "ERROR activating IP Forwarding."
fi

sudo iptables -P FORWARD DROP

if sudo iptables -L FORWARD | grep -q "policy.*DROP"; then
	echo "Chain Policy was succesfully updated to DROP."
else
	echo "ERROR updating Chain Policy to DROP."
fi

br_int="$ovs_name"

echo "Closing script..."
