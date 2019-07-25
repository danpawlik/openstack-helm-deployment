#!/bin/bash

export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBIAN_FRONTEND=noninteractive

INSTALL_COMPLETION=true
INSTALL_SPECIFIED_VERSION=true

# NOTE: CNI version if is installed in wrong version,
# it will raise error in installation of k8s components.
K8S_VERSION=${K8S_VERSION:-"1.13.4-00"}
K8S_CNI_VESRSION=${K8S_CNI_VESRSION:-"0.6.0-00"}

INSTALL_OSH_DEPS=true

sudo apt update
sudo apt install -y curl git vim
sudo apt-get install -y apt-transport-https ca-certificates curl \
                        software-properties-common

### FROM Openstack Helm: https://github.com/openstack/openstack-helm-infra/blob/master/tools/deployment/common/005-deploy-k8s.sh
function configure_resolvconf {
  sudo mv /etc/resolv.conf /etc/resolv.conf.backup

  sudo bash -c "echo 'search svc.cluster.local cluster.local' > /etc/resolv.conf"
  sudo bash -c "echo 'nameserver 10.96.0.10' >> /etc/resolv.conf"

  if [ -z "${HTTP_PROXY}" ]; then
    sudo bash -c "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
    sudo bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
  else
    sed -ne "s/nameserver //p" /etc/resolv.conf.backup | while read -r ns; do
      sudo bash -c "echo 'nameserver ${ns}' >> /etc/resolv.conf"
    done
  fi

  sudo bash -c "echo 'options ndots:5 timeout:1 attempts:1' >> /etc/resolv.conf"
  sudo rm /etc/resolv.conf.backup
}

sudo sed -i '/^127.0.0.1/c\127.0.0.1 localhost localhost.localdomain localhost4localhost4.localdomain4' /etc/hosts
sudo sed -i '/^::1/c\::1 localhost6 localhost6.localdomain6' /etc/hosts

configure_resolvconf

# FOR Openstack Helm deployment
if [ "${INSTALL_OSH_DEPS}" = "true" ]; then
    # Install required packages for K8s on host
    sudo apt-key adv --keyserver keyserver.ubuntu.com  --recv 460F3994
    RELEASE_NAME=$(grep 'CODENAME' /etc/lsb-release | awk -F= '{print $2}')
    sudo add-apt-repository "deb https://download.ceph.com/debian-mimic/
    ${RELEASE_NAME} main"
    sudo -E apt-get update
    # NOTE(srwilkers): Pin docker version to validated docker version for k8s 1.12.2
    sudo -E apt-get install -y \
        docker.io \
        socat \
        jq \
        util-linux \
        ceph-common \
        rbd-nbd \
        nfs-common \
        bridge-utils \
        libxtables11

    sudo -E tee /etc/modprobe.d/rbd.conf << EOF
 install rbd /bin/true
EOF

fi

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

if [ "$(hostname --fqdn)" != "$(hostname)" ]; then
    echo "Hostname doesn't match to this one set in /etc/hosts."
    echo "Fixing..."
    HOSTNAME=$(hostname --fqdn)
    sudo tee  /etc/hostname <<EOF
$HOSTNAME
EOF
fi

HOST_IFACE=$(ip route | grep "^default" | head -1 | awk '{ print $5 }');
LOCAL_IP=$(ip addr | awk "/inet/ && /${HOST_IFACE}/{sub(/\/.*$/,\"\",\$2); print \$2}");

echo "${LOCAL_IP} $(hostname)" | sudo tee -a /etc/hosts

# Install Docker
apt-get install docker.io -y

# Setup daemon.
cat << EOF | sudo tee -a /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt update
sudo apt install linux-image-extra-virtual ca-certificates curl \
                 software-properties-common -y

if [ "${INSTALL_SPECIFIED_VERSION}" = "true" ]; then
    sudo apt install -y "kubernetes-cni=${K8S_CNI_VESRSION}"
    sudo apt install -y "kubelet=${K8S_VERSION}" "kubeadm=${K8S_VERSION}" "kubectl=${K8S_VERSION}"
else
    sudo apt install -y kubelet kubeadm kubectl
fi


sudo kubeadm init --pod-network-cidr 192.168.0.0/16 \
                  --service-cidr 10.96.0.0/12 \
                  --apiserver-advertise-address "${LOCAL_IP}"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
# allow master run pod:
kubectl taint nodes --all node-role.kubernetes.io/master-

# install helm
curl -L https://git.io/get_helm.sh | sudo bash

# create serviceaccount
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade

if [ "${INSTALL_COMPLETION}" = "true" ]; then
    source <(kubectl completion bash)
    echo "source <(kubectl completion bash)" >> ~/.bashrc
    echo "alias k=kubectl" >> ~/.bashrc
    echo "complete -F __start_kubectl k" >> ~/.bashrc

    source <(helm completion bash)
    echo "source <(helm completion bash)" >> ~/.bashrc
fi
