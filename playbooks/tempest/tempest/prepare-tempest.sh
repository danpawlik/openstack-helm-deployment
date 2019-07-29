#!/bin/bash

set -x

source /home/ubuntu/openrc

IMAGES=$(openstack image list -c Name -f value)
if echo $IMAGES | grep -iqv 'Ubuntu'; then
    wget http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img \
        -O /home/ubuntu/bionic-server-cloudimg-amd64.img
    openstack image create 'Ubuntu 18.04' \
        --container-format bare \
        --disk-format qcow2 \
        --public --id aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee \
        --file /home/ubuntu/bionic-server-cloudimg-amd64.img
fi

if echo $IMAGES | grep -iqv 'Centos'; then
    wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 \
       -O /home/ubuntu/CentOS-7-x86_64-GenericCloud.qcow2

    openstack image create 'Centos 7' \
      --container-format bare \
      --disk-format qcow2 \
      --public --id eeeeeeee-dddd-cccc-bbbb-aaaaaaaaaaaa \
      --file /home/ubuntu/CentOS-7-x86_64-GenericCloud.qcow2
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

OPENSTACK_ADMIN_PASSWORD=$(grep OS_PASSWORD /home/ubuntu/openrc  | cut -f2 -d'=')
if grep -q "OPENSTACK_ADMIN_PASSWORD" /home/ubuntu/tempest/tempest.conf; then
    sed -i "s/OPENSTACK_ADMIN_PASSWORD/$OPENSTACK_ADMIN_PASSWORD/g" /home/ubuntu/tempest/tempest.conf
fi

SUBNET_LIST=$(openstack subnet list -c Name -f value)
if echo $SUBNET_LIST | grep -iqv "public-subnet"; then
    export OSH_EXT_NET_NAME="public"
    export OSH_EXT_SUBNET_NAME="public-subnet"
    export OSH_EXT_SUBNET="172.24.4.0/24"
    export OSH_EXT_SUBNET_ALLOC_START="172.24.4.150"
    export OSH_EXT_SUBNET_ALLOC_END="172.24.4.250"
    export OSH_BR_EX_ADDR="172.24.4.1"
    export OSH_DNS_ADDRESS="10.96.0.10"
    openstack network create ${OSH_EXT_NET_NAME} \
      --external \
      --provider-network-type flat \
      --provider-physical-network ${OSH_EXT_NET_NAME}

    openstack subnet create ${OSH_EXT_SUBNET_NAME} \
      --subnet-range ${OSH_EXT_SUBNET} \
      --allocation-pool start=${OSH_EXT_SUBNET_ALLOC_START},end=${OSH_EXT_SUBNET_ALLOC_END} \
      --gateway ${OSH_BR_EX_ADDR} \
      --no-dhcp \
      --dns-nameserver ${OSH_DNS_ADDRESS} \
      --network ${OSH_EXT_NET_NAME}

    NETWORK_ID=$(openstack network show public -f value -c id)
    if grep -q "NETWORK_ID" /home/ubuntu/tempest/tempest.conf; then
        sed -i "s/NETWORK_ID/$NETWORK_ID/g" /home/ubuntu/tempest/tempest.conf
    fi
fi

if echo $SUBNET_LIST | grep -iqv "shared-default-subnetpool"; then
    export OSH_PRIVATE_SUBNET_POOL="10.0.0.0/8"
    export OSH_PRIVATE_SUBNET_POOL_NAME="shared-default-subnetpool"
    export OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX="24"
    openstack subnet pool create ${OSH_PRIVATE_SUBNET_POOL_NAME} \
      --default-prefix-length ${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
      --pool-prefix ${OSH_PRIVATE_SUBNET_POOL}

    openstack network create ${OSH_PRIVATE_SUBNET_POOL_NAME} \
        --share --default --prefix ${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX}

    if grep -q "OSH_PRIVATE_SUBNET_POOL" /home/ubuntu/tempest/tempest.conf; then
        sed -i 's|OSH_PRIVATE_SUBNET_POOL|'$OSH_PRIVATE_SUBNET_POOL'|g' /home/ubuntu/tempest/tempest.conf
    fi
fi
