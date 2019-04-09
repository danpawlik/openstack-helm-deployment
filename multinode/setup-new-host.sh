#!/bin/bash
set -xe

if [ $(hostname --fqdn) != $(hostname) ]; then
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
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-backports main restricted universe multiverse<Paste>
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
sudo apt-get install --no-install-recommends \
        ca-certificates git make jq nmap \
        curl uuid-runtime -y

echo 'ubuntu  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

sudo apt install -y python-pip python3-pip
