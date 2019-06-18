#!/bin/bash

set -x

NODE_ONE_IP=$(hostname -I | awk '{ print $1 }' )
NODE_TWO_IP=${NOTE_TWO_IP:-$1}
ANSIBLE_USER=${ANSIBLE_USER:-ubuntu}
ANSIBLE_USER_HOME=${ANSIBLE_USER_HOME:-/home/ubuntu}
USE_PROXY=${USE_PROXY:-}
PROXY_ADDRESS=${PROXY_ADDRESS:-}
RELEASE=$(lsb_release -s -c)
DNS_ADDRESS=${DNS_ADDRESS:-}

SSH_KEY_PATH="${ANSIBLE_USER_HOME}/.ssh/id_rsa"

export OSH_PATH=/opt/openstack-helm
export OSH_INFRA_PATH=/opt/openstack-helm-infra

if [ ! -f $SSH_KEY_PATH ]; then
    echo -e "You didn't copy an ssh key to the host, \n"
    echo -e "so ansible can't connect to the node2. \n\n"
    echo -e "Generate that using: \n\nsudo -u ubuntu ssh-keygen -t rsa -b 2048 -f /home/ubuntu/.ssh/id_rsa -q -N \"\""
    exit 1
fi

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

if [ -z "${NODE_TWO_IP}" ]; then
    echo "You need to set ip address of node 2. Exit"
    exit 1
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

echo 'ubuntu  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

# FIXME
function net_default_iface {
# sudo ip -4 route list 0/0 | awk '{ print $5; exit }'
echo "ens3"
}

sudo mkdir -p /etc/openstack-helm
sudo cp "${SSH_KEY_PATH}" /etc/openstack-helm/deploy-key.pem
sudo chown ubuntu: /etc/openstack-helm/deploy-key.pem

if [ ! -d "${OSH_PATH}" ]; then
    git clone https://git.openstack.org/openstack/openstack-helm.git $OSH_PATH
fi

if [ ! -d "${OSH_INFRA_PATH}" ]; then
    git clone https://git.openstack.org/openstack/openstack-helm-infra.git $OSH_INFRA_PATH
fi

sudo chown -R ubuntu: /opt

# Contr will be also a node
cat > "${OSH_INFRA_PATH}/tools/gate/devel/multinode-inventory.yaml" <<EOF
all:
  children:
    primary:
      hosts:
        node_one:
          ansible_port: 22
          ansible_host: $NODE_ONE_IP
          ansible_user: $ANSIBLE_USER
          ansible_ssh_private_key_file: /etc/openstack-helm/deploy-key.pem
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    nodes:
      hosts:
        node_two:
          ansible_port: 22
          ansible_host: $NODE_TWO_IP
          ansible_user: $ANSIBLE_USER
          ansible_ssh_private_key_file: /etc/openstack-helm/deploy-key.pem
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
EOF

cat > $OSH_INFRA_PATH/tools/gate/devel/multinode-vars.yaml <<EOF
kubernetes_network_default_device: $(net_default_iface)
EOF

# Change interface ip address
echo "${NODE_ONE_IP} $(hostname)" | sudo tee -a /etc/hosts;

export no_proxy=$NODE_ONE_IP,127.0.0.1,172.17.0.1,.svc.cluster.local
export NO_PROXY=$NODE_ONE_IP,127.0.0.1,172.17.0.1,.svc.cluster.local


#echo "${LOCAL_IP} $(hostname)" | sudo tee -a /etc/hosts;

if [ -n "${USE_PROXY}" ]; then
    cat << EOF >> "${OSH_INFRA_PATH}/tools/gate/devel/local-vars.yaml"
proxy:
  http: http://${PROXY_ADDRESS}/
  https: https://${PROXY_ADDRESS}/
  noproxy: 127.0.0.1,localhost,172.17.0.1,.svc.cluster.local
EOF
fi

# Set different DNS
if [ -n "${DNS_ADDRESS}" ] ; then
    sed -i -e "s/8.8.8.8/$DNS_ADDRESS/g" "${OSH_INFRA_PATH}/tools/images/kubeadm-aio/assets/opt/playbooks/vars.yaml"
fi

rsync -i "${SSH_KEY_PATH}" -aq /opt/ "ubuntu@${NODE_TWO_IP}:/opt/"

# Be really sure that ubuntu is owner, so execute chown one more time
sudo chown -R ubuntu: /opt


## TEST
sudo DEBIAN_FRONTEND=noninteractive apt install -y ceph ceph-common nfs-common
sudo ln -s /home/ubuntu/.kube /root/.kube
###

# Install helm controller, k8s and join host
set +e

cd "${OSH_INFRA_PATH}" || exit 1
make dev-deploy setup-host multinode
make dev-deploy k8s multinode

set -e

export GLANCE_BACKEND=rbd

# deploy services
cd "${OSH_PATH}" || exit 1
./tools/deployment/multinode/010-setup-client.sh
./tools/deployment/multinode/020-ingress.sh
./tools/deployment/multinode/030-ceph.sh
./tools/deployment/multinode/040-ceph-ns-activate.sh
./tools/deployment/multinode/050-mariadb.sh
./tools/deployment/multinode/060-rabbitmq.sh
./tools/deployment/multinode/070-memcached.sh
./tools/deployment/multinode/080-keystone.sh
./tools/deployment/multinode/090-ceph-radosgateway.sh
./tools/deployment/multinode/100-glance.sh
./tools/deployment/multinode/110-cinder.sh
./tools/deployment/multinode/120-openvswitch.sh
./tools/deployment/multinode/130-libvirt.sh
./tools/deployment/multinode/140-compute-kit.sh
./tools/deployment/multinode/150-heat.sh
./tools/deployment/multinode/160-barbican.sh

# Export openrc file
cat << EOF > "${HOME}/openrc"
export OS_USERNAME='admin'
export OS_PASSWORD='password'
export OS_PROJECT_NAME='admin'
export OS_PROJECT_DOMAIN_NAME='default'
export OS_USER_DOMAIN_NAME='default'
export OS_AUTH_URL='http://keystone.openstack.svc.cluster.local/v3'
EOF
exit 0
