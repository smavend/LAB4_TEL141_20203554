#!/bin/bash

if [ $# -lt 4 ]; then
	echo "4 arguments needed. Use: bash $0 <VMname> <OvSname> <vlanID> <VNCport>"
	exit 1
fi

VMname=$(echo "$1" | sed 's/ /_/g')
ovsName=$(echo "$2" | sed 's/ /_/g')

if ! [[ "$3" =~ ^[0-9]+$ ]]; then
	echo "vlanID must be a number."
	exit 1
fi

vlanID=$(($2))

if ((vlanID < 1)) || ((vlanID > 4094)); then
	echo "Invalid vlanID."
	exit 1
fi

if ! [[ "$4" =~ ^[0-9]+$ ]]; then
	echo "VNCport must be a number."
	exit 1
fi

vncPort=$(($4))

wget -c https://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img

ip tuntap add mode tap name $VMname-tap

qemu-system-x86_64 \
	-enable-kvm \
	-vnc 0.0.0.0:"$vncPort" \
	-netdev tap,id="$VMname"-tap,ifname="$VMname"-tap,script=no,downscript=no \
	-device e1000,netdev="$VMname"-tap,mac=ca:fe:20:20:35:54 \
	-daemonize \
	-snapshot \
	cirros-0.5.1-x86_64-disk.img

sudo ovs-vsctl add-port $ovsName $VMname-tap

sudo ovs-vsctl add-port br-int $ovsName tag=$vlanID $VMname-tap0 -- set interface $VMname-tap0 type=internal

ip link set $VMname-tap0 netns ns_1

sudo ip netns exec ns_1 ip link set dev lo up
sudo ip netns exec ns_1 ip link ser dev $VMname-tap0 up

sudo ip link set dev $VMname-tap up
