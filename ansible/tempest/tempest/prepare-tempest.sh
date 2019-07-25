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

SUBNET_LIST=$(openstack subnet list -c Name -f value)
if echo $SUBNET_LIST | grep -iqv "public-subnet"; then
    export OSH_EXT_NET_NAME="public"
    export OSH_EXT_SUBNET_NAME="public-subnet"
    export OSH_EXT_SUBNET="172.24.4.0/24"
    export OSH_BR_EX_ADDR="172.24.4.1/24"
    openstack stack create --wait \
      --parameter network_name=${OSH_EXT_NET_NAME} \
      --parameter physical_network_name=public \
      --parameter subnet_name=${OSH_EXT_SUBNET_NAME} \
      --parameter subnet_cidr=${OSH_EXT_SUBNET} \
      --parameter subnet_gateway=${OSH_BR_EX_ADDR%/*} \
      -t /opt/openstack-helm/tools/gate/files/heat-public-net-deployment.yaml \
      heat-public-net-deployment

    export OSH_PRIVATE_SUBNET_POOL="10.0.0.0/8"
    export OSH_PRIVATE_SUBNET_POOL_NAME="shared-default-subnetpool"
    export OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX="24"
    openstack stack create --wait \
      --parameter subnet_pool_name=${OSH_PRIVATE_SUBNET_POOL_NAME} \
      --parameter subnet_pool_prefixes=${OSH_PRIVATE_SUBNET_POOL} \
      --parameter subnet_pool_default_prefix_length=${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
      -t /opt/openstack-helm/tools/gate/files/heat-subnet-pool-deployment.yaml \
      heat-subnet-pool-deployment

    NETWORK_ID=$(openstack network show public -f value -c id)
    if grep -q "NETWORK_ID" /home/ubuntu/tempest.conf; then
        sed -i "s/NETWORK_ID/$NETWORK_ID/g" /home/ubuntu/tempest.conf
    fi

    if grep -q "FLOATING_IP_RANGE" /home/ubuntu/tempest.conf; then
        sed -i "s/FLOATING_IP_RANGE/$FLOATING_IP_RANGE/g" /home/ubuntu/tempest.conf
    fi
fi
