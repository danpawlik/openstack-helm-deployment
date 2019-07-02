#!/bin/bash

set -x

# setup docker.io if bionic; they have hardcoded docker.io from xenial
if [ "${RELEASE}" = "bionic" ]; then
    sudo tee  /etc/apt/sources.list <<EOF
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF
elif [ "${RELEASE}" = "xenial" ]; then
    sudo tee  /etc/apt/sources.list <<EOF
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-proposed main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse
EOF
fi

# From https://docs.openstack.org/openstack-helm/latest/install/common-requirements.html
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive \
     apt install --no-install-recommends \
        ca-certificates git make jq nmap \
        curl uuid-runtime -y

sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y
