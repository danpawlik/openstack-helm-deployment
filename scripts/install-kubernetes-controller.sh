#!/bin/bash

sudo kubeadm init --pod-network-cidr 192.168.0.0/16 \
                  --service-cidr 10.96.0.0/12 \
                  --apiserver-advertise-address "${LOCAL_IP}"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

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
