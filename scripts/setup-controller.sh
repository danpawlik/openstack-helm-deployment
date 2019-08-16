#!/bin/bash

set -xe

NODE_ONE_IP=${NODE_ONE_IP:-""}
NODE_TWO_IP=${NODE_TWO_IP:-$1}
NODE_THREE_IP=${NODE_THREE_IP:-$2}
ANSIBLE_USER=${ANSIBLE_USER:-ubuntu}
ANSIBLE_USER_HOME=${ANSIBLE_USER_HOME:-/home/ubuntu}
USE_PROXY=${USE_PROXY:-}
PROXY_ADDRESS=${PROXY_ADDRESS:-}
RELEASE=$(lsb_release -s -c)
DNS_ADDRESS=${DNS_ADDRESS:-}
KUBE_VERSION=${KUBE_VERSION:-}

SSH_KEY_PATH="${ANSIBLE_USER_HOME}/.ssh/id_rsa"

OSH_PATH="/opt/openstack-helm"
OSH_INFRA_PATH="/opt/openstack-helm-infra"


if [ ! -f "$SSH_KEY_PATH" ]; then
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

# From https://docs.openstack.org/openstack-helm/latest/install/common-requirements.html
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive \
     apt install --no-install-recommends \
        ca-certificates git make jq nmap \
        curl uuid-runtime -y

sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y

echo 'ubuntu  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

sudo mkdir -p /etc/openstack-helm
sudo cp "${SSH_KEY_PATH}" /etc/openstack-helm/deploy-key.pem
sudo chown ubuntu: /etc/openstack-helm/deploy-key.pem

if [ ! -d "$OSH_PATH" ]; then
    echo "Cloning into $OSH_PATH"
    git clone https://opendev.org/openstack/openstack-helm.git $OSH_PATH ;
fi

if [ ! -d "$OSH_INFRA_PATH" ]; then
    echo "CLoning into $OSH_INFRA_PATH"
    git clone https://opendev.org/openstack/openstack-helm-infra.git $OSH_INFRA_PATH ;
fi

sudo chown -R ubuntu: /opt ;

# Change interface ip address
HOST_IFACE=$(ip route | grep "^default" | head -1 | awk '{ print $5 }');
NODE_ONE_IP=$(ip addr | awk "/inet/ && /${HOST_IFACE}/{sub(/\/.*$/,\"\",\$2); print \$2}");
echo "${NODE_ONE_IP} $(hostname)" | sudo tee -a /etc/hosts;

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

if [ -n "${NODE_THREE_IP}" ]; then
    cat >> "${OSH_INFRA_PATH}/tools/gate/devel/multinode-inventory.yaml" <<EOF
        node_three:
          ansible_port: 22
          ansible_host: $NODE_THREE_IP
          ansible_user: $ANSIBLE_USER
          ansible_ssh_private_key_file: /etc/openstack-helm/deploy-key.pem
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
EOF
fi

function net_default_iface {
 sudo ip -4 route list 0/0 | awk '{ print $5 }'
}


cat > $OSH_INFRA_PATH/tools/gate/devel/multinode-vars.yaml <<EOF
kubernetes_network_default_device: $(net_default_iface)
EOF

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

# set new k8s version
if [ -n "${KUBE_VERSION}" ]; then
    sed -i "s/v1.13.4/$KUBE_VERSION/g" "${OSH_INFRA_PATH}/roles/build-images/defaults/main.yml"
    sed -i "s/v1.13.4/$KUBE_VERSION/g" "${OSH_INFRA_PATH}/tools/images/kubeadm-aio/Dockerfile"
    sed -i "s/v1.13.4/$KUBE_VERSION/g" "${OSH_INFRA_PATH}/tools/images/kubeadm-aio/assets/opt/playbooks/vars.yaml"
    sed -i "s/v1.13.4/$KUBE_VERSION/g" "${OSH_INFRA_PATH}/tools/deployment/common/005-deploy-k8s.sh"
fi

echo " " > /home/ubuntu/.ssh/known_hosts
ssh-keyscan -H "$NODE_ONE_IP" >> /home/ubuntu/.ssh/known_hosts

for IP_ADDRESS in $NODE_TWO_IP $NODE_THREE_IP;
do
    echo "starting rsync: $IP_ADDRESS"
    ssh-keyscan -H "$IP_ADDRESS" >> /home/ubuntu/.ssh/known_hosts
    rsync  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" -i "${SSH_KEY_PATH}" -aq /opt/ "ubuntu@${IP_ADDRESS}:/opt/"
done

sudo chown -R ubuntu: /opt

sudo DEBIAN_FRONTEND=noninteractive apt install -y ceph ceph-common nfs-common
sudo ln -s /home/ubuntu/.kube /root/.kube

if [ -d "$OSH_PATH" ] && [ -d "$OSH_INFRA_PATH" ] ; then
    # Install helm controller, k8s and join host
    cd "${OSH_INFRA_PATH}" && ls
    set +e
    make dev-deploy setup-host multinode
    make dev-deploy k8s multinode
    set -e
fi

source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k=kubectl" >> ~/.bashrc
echo "complete -F __start_kubectl k" >> ~/.bashrc

source <(helm completion bash)
echo "source <(helm completion bash)" >> ~/.bashrc

# Export openrc file
cat << EOF > "${HOME}/openrc"
export OS_USERNAME='admin'
export OS_PASSWORD='password'
export OS_PROJECT_NAME='admin'
export OS_PROJECT_DOMAIN_NAME='default'
export OS_USER_DOMAIN_NAME='default'
export OS_AUTH_URL='http://keystone.openstack.svc.cluster.local/v3'
EOF
