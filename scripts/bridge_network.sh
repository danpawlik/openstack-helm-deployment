#!/bin/bash

BRIDGE_NAME=${BRIDGE_NAME:-'br-ex'}
VRACK_INTERFACE=${VRACK_INTERFACE:-'ens4'}
BRIDGE_ADDRESS=${BRIDGE_ADDRESS:-''}

if [ -z "${BRIDGE_ADDRESS}" ]; then
    echo "You need to provide br-ex network address"
    exit 1
fi

# set routing between flat network and host
if sudo ip route | grep -q br-ex; then
    echo "Show route on the br-ex interface"
    sudo ip addr list dev br-ex
else
    sudo ip addr add "${BRIDGE_ADDRESS}/24" dev "${BRIDGE_NAME}"
    echo "Added route to br-ex!"
fi

# Execute command on contr
if ip addr | grep -q "${BRIDGE_NAME}" && which kubectl; then
  for switch in $(kubectl -n openstack get pods -l component=openvswitch-vswitchd --no-headers | awk '{print $1}'); do
      kubectl -n openstack exec -it $switch ovs-vsctl add-port "${BRIDGE_NAME}" "${VRACK_INTERFACE}"
  done
fi

sudo ip link set up dev "${VRACK_INTERFACE}"
