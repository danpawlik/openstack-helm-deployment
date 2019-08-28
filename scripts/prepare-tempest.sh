#!/bin/bash

set -x

OPENRC_PATH=${OPENRC_PATH:-''}
NAMESPACE=${NAMESPACE:-''}
TEMPEST_CONF_PATH=${TEMPEST_CONF_PATH:-'tempest/tempest.conf'}

if [ ! -f "${OPENRC_PATH}" ]; then
    echo "Could not find openrc file. Checking file: openrc-${NAMESPACE}"
    if [ ! -f "openrc-${NAMESPACE}" ]; then
        echo "Could not find openrc file to tempest. Exit"
        exit 1
    else
        echo "Taking file from: openrc-${NAMESPACE}"
        OPENRC_PATH="openrc-${NAMESPACE}"
    fi
fi

if [ ! -f "${TEMPEST_CONF_PATH}" ]; then
    echo "Could not find tempest file. Exit"
    exit 1
fi

source $OPENRC_PATH

IMAGES=$(openstack image list -c Name -f value)
if echo $IMAGES | grep -iqv 'Centos'; then
    if [ ! -f "/home/ubuntu/tempest/CentOS-7-x86_64-GenericCloud.qcow2" ]; then
        wget -q http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 \
           -O /home/ubuntu/tempest/CentOS-7-x86_64-GenericCloud.qcow2
    fi

    IMAGE_ID=$(uuidgen)
    openstack image create 'Centos 7' \
      --container-format bare \
      --disk-format qcow2 \
      --public --id "${IMAGE_ID}" \
      --file /home/ubuntu/tempest/CentOS-7-x86_64-GenericCloud.qcow2

    if grep -q "IMAGE_REF_ALT" "${TEMPEST_CONF_PATH}"; then
        sed -i "s/IMAGE_REF_ALT/$IMAGE_ID/g" "${TEMPEST_CONF_PATH}"
    fi
fi

if echo $IMAGES | grep -iqv 'Ubuntu'; then
    if [ ! -f "/home/ubuntu/tempest/bionic-server-cloudimg-amd64.img" ]; then
        wget -q http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img \
            -O /home/ubuntu/tempest/bionic-server-cloudimg-amd64.img
    fi

    IMAGE_ID=$(uuidgen)
    openstack image create 'Ubuntu 18.04' \
        --container-format bare \
        --disk-format qcow2 \
        --public --id "${IMAGE_ID}" \
        --file /home/ubuntu/tempest/bionic-server-cloudimg-amd64.img

    if grep -q "IMAGE_REF" "${TEMPEST_CONF_PATH}"; then
        sed -i "s/IMAGE_REF/$IMAGE_ID/g" "${TEMPEST_CONF_PATH}"
    fi
fi

FLAVOR_LIST=$(openstack flavor list -f value -c Name | grep tempest)
if echo $FLAVOR_LIST | grep -iqv "tempest"; then
    openstack flavor create tempest \
        --id aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee \
        --ram 1024 \
        --disk 10 \
        --vcpus 1 \
        --public
fi
if echo $FLAVOR_LIST | grep -iqv "tempest2"; then
    openstack flavor create tempest2 \
        --id eeeeeeee-dddd-cccc-bbbb-aaaaaaaaaaaa \
        --ram 2024 \
        --disk 20 \
        --vcpus 2 \
        --public
fi

for sec_group in $(openstack security group list -f value -c ID);
do
    openstack security group rule create --protocol icmp "${sec_group}"
    openstack security group rule create "${sec_group}"  --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0
done

OPENSTACK_ADMIN_PASSWORD=$(grep OS_PASSWORD "${OPENRC_PATH}"  | cut -f2 -d'=')
if grep -q "OPENSTACK_ADMIN_PASSWORD" "${TEMPEST_CONF_PATH}"; then
    sed -i "s/OPENSTACK_ADMIN_PASSWORD/$OPENSTACK_ADMIN_PASSWORD/g" "${TEMPEST_CONF_PATH}"
fi

OPENSTACK_AUTH_URI=$(grep OS_AUTH_URL "${OPENRC_PATH}"  | cut -f2 -d'=')
if grep -q "OPENSTACK_AUTH_URI" "${TEMPEST_CONF_PATH}"; then
    sed -i 's|OPENSTACK_AUTH_URI|'$OPENSTACK_AUTH_URI'|g' "${TEMPEST_CONF_PATH}"
fi

SUBNET_LIST=$(openstack subnet list -c Name -f value)
if echo $SUBNET_LIST | grep -iqv "public-subnet"; then
    export OSH_EXT_NET_NAME="public"
    export OSH_EXT_SUBNET_NAME="public-subnet"
    export OSH_EXT_SUBNET="172.24.4.0/24"
    export OSH_EXT_SUBNET_ALLOC_START="172.24.4.100"
    export OSH_EXT_SUBNET_ALLOC_END="172.24.4.250"
    export OSH_BR_EX_ADDR="172.24.4.1"
    export OSH_DNS_ADDRESS="10.96.0.10"
    openstack network create ${OSH_EXT_NET_NAME} \
      --external \
      --share \
      --provider-network-type flat \
      --provider-physical-network ${OSH_EXT_NET_NAME}

    openstack subnet create ${OSH_EXT_SUBNET_NAME} \
      --subnet-range ${OSH_EXT_SUBNET} \
      --allocation-pool start=${OSH_EXT_SUBNET_ALLOC_START},end=${OSH_EXT_SUBNET_ALLOC_END} \
      --gateway ${OSH_BR_EX_ADDR} \
      --dhcp \
      --dns-nameserver ${OSH_DNS_ADDRESS} \
      --network ${OSH_EXT_NET_NAME}
fi

NETWORK_ID=$(openstack network show public -f value -c id)
if grep -q "NETWORK_ID" "${TEMPEST_CONF_PATH}"; then
    sed -i "s/NETWORK_ID/$NETWORK_ID/g" "${TEMPEST_CONF_PATH}"
fi

if echo $SUBNET_LIST | grep -iqv "shared-default-subnetpool"; then
    export OSH_PRIVATE_SUBNET_POOL="10.0.0.0/8"
    export OSH_PRIVATE_SUBNET_POOL_NAME="shared-default-subnetpool"
    export OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX="24"
    openstack subnet pool create ${OSH_PRIVATE_SUBNET_POOL_NAME} \
      --default-prefix-length ${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
      --pool-prefix ${OSH_PRIVATE_SUBNET_POOL}

    if grep -q "OSH_PRIVATE_SUBNET_POOL" "${TEMPEST_CONF_PATH}"; then
        sed -i 's|OSH_PRIVATE_SUBNET_POOL|'$OSH_PRIVATE_SUBNET_POOL'|g' "${TEMPEST_CONF_PATH}"
    fi
fi
