#!/bin/bash

USE_PROXY=${USE_PROXY:-}
PROXY_ADDRESS=${PROXY_ADDRESS:-}
DATA_BACKEND=${DATA_BACKEND:-CEPH}
CHOOSEN_BACKEND=''
DNS_ADDRESS=${DNS_ADDRESS:-}

export OSH_PATH=/opt/openstack-helm
export OSH_INFRA_PATH=/opt/openstack-helm-infra

if (( $EUID = 0 )); then
  echo "Please do not run the script as root!"
  exit 1
fi

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

# If you want to use CEPH backend, make sure that
# linux-generic-hwe is installed
# https://docs.openstack.org/openstack-helm/latest/install/developer/requirements-and-host-config.html#requirements
RELEASE=$(lsb_release -c -s)
if [ "${DATA_BACKEND}" = "CEPH" ] && [ "${RELEASE}" = "xenial" ]; then
    # If package is not installed, raise error
    if ! (dpkg -l | grep -qv "linux-generic-hwe-$(lsb_release -c -r)"); then
        echo -e "CEPH backend require to install additional packages: \n"
        echo -e "\n\nlinux-generic-hwe-$(lsb_release -c -r) \n\n"
        echo -e "which is not installed. Quiting..."
        exit 1
    else
    	echo "Setting Ceph..."
        CHOOSEN_BACKEND='CEPH'
    fi
fi

if [ -z "${CHOOSEN_BACKEND}" ] && [ -z "${DATA_BACKEND}" ]; then
    CHOOSEN_BACKEND="NFS"
fi

if [ -n "${USE_PROXY}" ] && [ -z "${PROXY_ADDRESS}" ]; then
    echo "If you want to use proxy, pls export PROXY_ADDRESS"
    exit 1
fi

if [ -n "${USE_PROXY}" ]; then
    echo "Acquire::http::proxy http://${PROXY_ADDRESS}/;" | sudo tee -a /etc/apt/apt.conf
    echo "Acquire::ftp::proxy ftp://${PROXY_ADDRESS}/;" | sudo tee -a /etc/apt/apt.conf
    echo "Acquire::https::proxy https://${PROXY_ADDRESS}/;" | sudo tee -a /etc/apt/apt.conf

    export http_proxy="http://${PROXY_ADDRESS}/"
    export https_proxy="https://${PROXY_ADDRESS}/"
fi

# setup docker.io if bionic; they have hardcoded docker.io from xenial
if [ "${RELEASE}" = "bionic" ]; then
    sudo tee  /etc/apt/sources.list <<EOF
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic main restricted
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-updates main restricted
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ bionic universe

deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-proposed main restricted universe multiverse
deb http://nova.clouds.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse
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
        ca-certificates \
        git \
        make \
        jq \
        nmap \
        curl \
        uuid-runtime -y

echo 'ubuntu  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
sudo chown -R ubuntu:ubuntu /opt
git clone https://github.com/openstack/openstack-helm.git "${OSH_PATH}"
git clone https://git.openstack.org/openstack/openstack-helm-infra.git "${OSH_INFRA_PATH}"

# Change interface ip address
HOST_IFACE=$(ip route | grep "^default" | head -1 | awk '{ print $5 }');
LOCAL_IP=$(ip addr | awk "/inet/ && /${HOST_IFACE}/{sub(/\/.*$/,\"\",\$2); print \$2}");
echo "${LOCAL_IP} $(hostname)" | sudo tee -a /etc/hosts;

export no_proxy=$LOCAL_IP,127.0.0.1,172.17.0.1,.svc.cluster.local
export NO_PROXY=$LOCAL_IP,127.0.0.1,172.17.0.1,.svc.cluster.local

# IT IS REALLY IMPORTANT - WITHOUT THIS COMMAND, KEYSTONE WILL HAVE ERROR: net/http: request canceled
find "${OSH_PATH}" -type f -exec sed -i -e "s/eth0/${HOST_IFACE}/g" {} \; ;
find "${OSH_INFRA_PATH}" -type f -exec sed -i -e "s/eth0/${HOST_IFACE}/g" {} \; ;

if [ -n "${USE_PROXY}" ]; then
    echo "\
    proxy:
      http: http://${PROXY_ADDRESS}/
      https: https://${PROXY_ADDRESS}/
      noproxy: 127.0.0.1,${LOCAL_IP},localhost,172.17.0.1,.svc.cluster.local" > "${OSH_PATH}/tools/gate/playbooks/vars.yaml"

    echo "\
    proxy:
      http: http://${PROXY_ADDRESS}/
      https: https://${PROXY_ADDRESS}/
      noproxy: 127.0.0.1,${LOCAL_IP},localhost,172.17.0.1,.svc.cluster.local" >> "${OSH_INFRA_PATH}/tools/gate/devel/local-vars.yaml"
fi

# Set different DNS
if [ -n "${DNS_ADDRESS}" ] ; then
    sed -i -e "s/8.8.8.8/$DNS_ADDRESS/g" "${OSH_INFRA_PATH}/tools/images/kubeadm-aio/assets/opt/playbooks/vars.yaml"
fi

# Install and configure Helm and K8S with basic Openstack-Helm requirements
cd "${OSH_PATH}" || exit 1
./tools/deployment/developer/common/010-deploy-k8s.sh
./tools/deployment/developer/common/020-setup-client.sh
./tools/deployment/developer/common/030-ingress.sh

if [ "${CHOOSEN_BACKEND}" = "NFS" ]; then
    echo "Configuring Helm cluster with NFS"
    # do it in paralell
    ./tools/deployment/developer/nfs/040-nfs-provisioner.sh;
    ./tools/deployment/developer/nfs/050-mariadb.sh;
    ./tools/deployment/developer/nfs/060-rabbitmq.sh;
    ./tools/deployment/developer/nfs/070-memcached.sh;

    ./tools/deployment/developer/nfs/080-keystone.sh;
    ./tools/deployment/developer/nfs/090-heat.sh;
    ./tools/deployment/developer/nfs/120-glance.sh &

    ./tools/deployment/developer/nfs/140-openvswitch.sh ;
    ./tools/deployment/developer/nfs/150-libvirt.sh ;
    ./tools/deployment/developer/nfs/160-compute-kit.sh ;

    ./tools/deployment/common/wait-for-pods.sh openstack

    ./tools/deployment/developer/nfs/170-setup-gateway.sh ;
elif [ "${CHOOSEN_BACKEND}" = "CEPH" ]; then
    echo "Configuring Helm cluster with CEPH"
    # do it in paralell
    ./tools/deployment/developer/ceph/040-ceph.sh;
    ./tools/deployment/developer/ceph/045-ceph-ns-activate.sh;
    ./tools/deployment/developer/ceph/050-mariadb.sh;
    ./tools/deployment/developer/ceph/060-rabbitmq.sh;
    ./tools/deployment/developer/ceph/070-memcached.sh ;

    ./tools/deployment/developer/ceph/080-keystone.sh;
    ./tools/deployment/developer/ceph/090-heat.sh;
    ./tools/deployment/developer/ceph/110-ceph-radosgateway.sh;
    ./tools/deployment/developer/ceph/120-glance.sh &
    ./tools/deployment/developer/ceph/130-cinder.sh &

    ./tools/deployment/developer/ceph/140-openvswitch.sh ;
    ./tools/deployment/developer/ceph/150-libvirt.sh ;
    ./tools/deployment/developer/ceph/160-compute-kit.sh ;

    ./tools/deployment/common/wait-for-pods.sh openstack

    ./tools/deployment/developer/ceph/170-setup-gateway.sh;
else
    echo "Unrecognized data backend. Exit"
    exit 1
fi

# Export openrc file
cat << EOF > "${HOME}/openrc"
export OS_USERNAME='admin'
export OS_PASSWORD='password'
export OS_PROJECT_NAME='admin'
export OS_PROJECT_DOMAIN_NAME='default'
export OS_USER_DOMAIN_NAME='default'
export OS_AUTH_URL='http://keystone.openstack.svc.cluster.local/v3'
EOF
