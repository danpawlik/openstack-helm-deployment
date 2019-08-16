#!/bin/bash

set -x
RELEASE=$(lsb_release -sc)
INSTALL_CEPH=${INSTALL_CEPH:-'false'}

if [ "$(hostname --fqdn)" != "$(hostname)" ]; then
    echo "Hostname doesn't match to this one set in /etc/hosts."
    echo "Fixing..."
    HOSTNAME=$(hostname --fqdn)
    sudo tee  /etc/hostname <<EOF
$HOSTNAME
EOF
    sudo hostname "${HOSTNAME}"
    echo "You should reboot host"
fi

if [ "${RELEASE}" = "bionic" ]; then
    sudo tee  /etc/apt/sources.list <<EOF
deb http://ubuntu.mirrors.ovh.net/ubuntu/ bionic main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ bionic-security main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ bionic-updates main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ bionic-proposed main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ bionic-backports main restricted universe multiverse
EOF
elif [ "${RELEASE}" = "xenial" ]; then
    sudo tee  /etc/apt/sources.list <<EOF
deb http://ubuntu.mirrors.ovh.net/ubuntu/ xenial main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ xenial-security main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ xenial-updates main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ xenial-proposed main restricted universe multiverse
deb http://ubuntu.mirrors.ovh.net/ubuntu/ xenial-backports main restricted universe multiverse
EOF

fi

echo 'ubuntu  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

# From https://docs.openstack.org/openstack-helm/latest/install/common-requirements.html
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive \
     apt install --no-install-recommends \
        ca-certificates git make jq nmap \
        curl uuid-runtime -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y python-pip python3-pip
sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y

if [ "${INSTALL_CEPH}" = "true" ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt install -y ceph ceph-common nfs-common
fi

sudo chown -R ubuntu:ubuntu /opt/

ln -f -s /opt/openstack-helm-infra/tools /home/ubuntu/tools
