#!/bin/bash

set -x

if [ ! -d "$OSH_PATH" ]; then
    echo "Cloning into $OSH_PATH"
    git clone https://opendev.org/openstack/openstack-helm.git $OSH_PATH ;
fi

if [ ! -d "$OSH_INFRA_PATH" ]; then
    echo "Cloning into $OSH_INFRA_PATH"
    git clone https://opendev.org/openstack/openstack-helm-infra.git $OSH_INFRA_PATH ;
fi

sudo chown -R ubuntu: /opt
