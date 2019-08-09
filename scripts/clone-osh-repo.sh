#!/bin/bash

set -x

sudo chown -R ubuntu: /opt

OSH_PATH="/opt/openstack-helm"
OSH_INFRA_PATH="/opt/openstack-helm-infra"

if [ ! -d "$OSH_PATH" ]; then
    echo "Cloning into $OSH_PATH"
    git clone https://opendev.org/openstack/openstack-helm.git $OSH_PATH ;
fi

if [ ! -d "$OSH_INFRA_PATH" ]; then
    echo "Cloning into $OSH_INFRA_PATH"
    git clone https://opendev.org/openstack/openstack-helm-infra.git $OSH_INFRA_PATH ;
fi
