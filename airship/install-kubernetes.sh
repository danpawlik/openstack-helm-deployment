#!/bin/bash

sudo apt update
sudo apt install -y curl git vim

# Install Docker CE
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install apt-transport-https ca-certificates curl software-properties-common -y

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

#curl -L https://get.docker.com | bash

if [ $(hostname --fqdn) != $(hostname) ]; then
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


### Add Docker apt repository.
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

## Install Docker CE.
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install docker-ce=18.06.2~ce~3-0~ubuntu -y

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

#echo "deb http://apt.kubernetes.io/ kubernetes-$(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt update

sudo DEBIAN_FRONTEND=noninteractive apt install linux-image-extra-virtual ca-certificates curl software-properties-common -y
sudo DEBIAN_FRONTEND=noninteractive apt install kubelet kubeadm kubectl  -y

sudo kubeadm init --pod-network-cidr 192.168.0.0/16 \
                  --service-cidr 10.96.0.0/12 \
                  --service-dns-domain "svc.cluster.local" \
                  --apiserver-advertise-address "${LOCAL_IP}"


mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml

source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k=kubectl" >> ~/.bashrc
echo "complete -F __start_kubectl k" >> ~/.bashrc

# allow master run pod:
kubectl taint nodes --all node-role.kubernetes.io/master-

# install helm
curl -L https://git.io/get_helm.sh | sudo bash

# create serviceaccount
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade
