#!/bin/bash

set -x

# NOTE: this script for some reason (probably sudoers problem)
# doesn't work correctly. Please use ansible playbook instead.

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

echo "ubuntu  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
sudo cat /etc/sudoers | sed "/^root/d" | sudo tee /etc/sudoers
echo "root  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

git clone https://opendev.org/airship/treasuremap.git /home/ubuntu/treasuremap
cd /home/ubuntu/treasuremap || ls
./tools/deployment/airskiff/developer/000-install-packages.sh
./tools/deployment/airskiff/developer/005-clone-dependencies.sh
./tools/deployment/airskiff/developer/010-deploy-k8s.sh

sudo usermod -aG docker ubuntu
sudo su - $USER -c bash <<'END_SCRIPT'
if echo $(groups) | grep -qv 'docker'; then
    echo "You need to logout to apply group permissions"
    echo "Please logout and login"
    exit 1
fi
cd /home/ubuntu/treasuremap
sudo chown -R ubuntu:ubuntu /home/ubuntu
sudo ./tools/deployment/airskiff/developer/020-setup-client.sh
sudo ./tools/deployment/airskiff/developer/030-armada-bootstrap.sh
sudo ./tools/deployment/airskiff/developer/100-deploy-osh.sh
END_SCRIPT
