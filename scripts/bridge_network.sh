#!/bin/bash

BRIDGE_NAME=${BRIDGE_NAME:-'br-ex'}
BRIDGE_ADDRESS=${BRIDGE_ADDRESS:-''}
VRACK_INTERFACE=${VRACK_INTERFACE:-'ens4'}
VRACK_ADDRESS=${VRACK_ADDRESS:-""}
NETWORK_CLASS="172.24.4.0/24"
MAPPING_FILE_PATH=${MAPPING_FILE_PATH:-"$HOME/vrack_mapping.txt"}

if [ -z "${BRIDGE_ADDRESS}" ]; then
    echo "You need to provide br-ex network address"
    exit 1
fi

if [ -z "${VRACK_ADDRESS}" ] && [ -f "${MAPPING_FILE_PATH}" ]; then
    # Take value from vrack mapping file. If
    # hostname have chars ':' it will be replaced by
    # '_".
    hostname=$(sed 's/-/_/g' $HOSTNAME)
    VRACK_ADDRESS=$(grep "${hostname}" "${HOME}/vrack_mapping.txt" | cut -f2 -d'=')
fi

if [ -z "${VRACK_ADDRESS}" ]; then
    echo "You need to provide vrack network address"
    exit 1
fi

CURRENT_VRACK_IP_ADDRESS=$(ip -4 addr show $VRACK_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "${CURRENT_VRACK_IP_ADDRESS}" ]; then
    sudo ip addr add "${VRACK_ADDRESS}" dev "${VRACK_INTERFACE}"
    echo "IP address has been set for $VRACK_INTERFACE with ip address:"
    sudo ip -4 addr show $VRACK_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
fi

# Check ip address on br-ex
CURRENT_BRIDGE_IP_ADDRESS=$(ip -4 addr show $BRIDGE_NAME | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "${CURRENT_BRIDGE_IP_ADDRESS}" ]; then
    sudo ip addr add "${BRIDGE_ADDRESS}/24" dev "${BRIDGE_NAME}"
    echo "IP address has been set for bridge ${BRIDGE_NAME} with ip address:"
    sudo ip -4 addr show $BRIDGE_NAME | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
fi

sudo ip link set up dev "${BRIDGE_NAME}"

# Check if br-ex network routing is correct
CURRENT_BRIDGE_NETWORK="$( sudo ip route | grep "${BRIDGE_NAME}" | awk '{print $1}' | sort | uniq)"
if [ -z "${CURRENT_BRIDGE_NETWORK}" ]; then
    sudo ip route add "${NETWORK_CLASS}" dev "${BRIDGE_NAME}"
elif [ "${CURRENT_BRIDGE_NETWORK}" != "${NETWORK_CLASS}" ]; then
    echo "Current bridge network: ${CURRENT_BRIDGE_NETWORK} is not correct with privided one ${NETWORK_CLASS}!"
    exit 1
fi

# set routing between flat network and host
# Execute command on contr
if ip addr | grep -q "${BRIDGE_NAME}" && which kubectl; then
  for switch in $(kubectl -n openstack get pods -l component=openvswitch-vswitchd --no-headers | awk '{print $1}'); do
      if ! kubectl -n openstack exec -it $switch ovs-vsctl list-ifaces "${BRIDGE_NAME}" | grep -q "${VRACK_INTERFACE}"; then
          kubectl -n openstack exec -it $switch ovs-vsctl add-port "${BRIDGE_NAME}" "${VRACK_INTERFACE}"
      fi
  done
fi

# Finally bring the interface up
sudo ip link set up dev "${VRACK_INTERFACE}"
