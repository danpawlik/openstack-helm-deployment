# Deploy Openstack using Openstack Helm Infra scripts

Readme is under construction. I just added small into about
how to deploy Openstack infra as multi node using ansible playbook.

## Before you start

Those playbooks can deploy:

- Airskiff with Minikube (export MINIKUBE=true)
- Airskiff with normall Kubernetes controller + additional node
- Openstack Helm + additional node using Openstack Helm + Openstack Helm Infra scripts
- Airship Armada on one host using Openstack Helm Infra script
- Execute Openstack Tempest test on this infra


## IMPORTANT NOTE

All playbooks begin work by reading "local_inventory" playbook tasks.

In this place, you can define:
- how many controllers and nodes should be
- what flavors should be taken
- what images
- etc.

Please read local_inventory playbooks before you start executing the playbooks!


## Clone and install Ansible
NOTE: prefered system is Ubuntu 18.04.

```
sudo apt update
sudo apt install -y git python3-pip python3-dev
git clone https://github.com/danpawlik/openstack-helm-deployment
sudo pip install -r requirements.txt
```

## Preparation

1. Create ssh id_rsa_ansible key in $HOME/.ssh/id_rsa_ansible location.
This key will be used by Ansible to add that key into Openstack VMs.

NOTE:
Please add also this key into authorized_keys on the Ansible server.

Example:
```
ssh-keygen -trsa 2048 $HOME/.ssh/id_rsa_ansible
```

2. Add into .ssh/config information, that Ansible can use the
id_rsa_ansible key, e.g.:
```
Host *
    User ubuntu
    IdentityFile ~/.ssh/id_rsa_ansible
```

## Example: how to deploy Airskiff with K8S controller + one node


1. Check "local inventory" in the playbook, how it is defined, e.g.:

```
  vars:
    k8s_hosts:
      k8s_contr:
        - some_contr
      k8s_minion:
        - some_minion
        - some_minion
```

2. You can also set more minions and contr (if you want) but 1 for each is a minimum value.

To set the name, you can just export variables:
```
export CONTR_NAME=airskiff_contr-1
export MINION_1_NAME=airskiff-minion-1
export MINION_2_NAME=airskiff-minion-2
```

3. Now you need to read openrc file, because playbooks will read credentials
ans spawn VMs.

```
source openrc
```

4. Now you just need to execute Ansible playbook:
```
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook playbooks/airskiff-deploy-all.yaml -vv
```

NOTE:
Available export variables:
```
export ANSIBLE_SSH_KEYNAME=id_rsa_ansible
export OPENSTACK_KEYPAIR_NAME=ansible_key

export CONTR_NAME=bob_contr
export MINION_1_NAME=stevard_minion_1
export MINION_2_NAME=kevin_minion

export KUBE_VERSION=1.13.4 # it doesn't work when SETUP_MINIKUBE is true
export SETUP_MINIKUBE=false

export DOCKER_REPO_NAME=
export DOCKER_REPO_LOGIN=
export DOCKER_REPO_PASSWORD=
```

Just for Openstack Helm multinode playbook:
```
OSH_EXTRA_HELM_ARGS
OSH_EXTRA_HELM_ARGS_BARBICAN
OSH_EXTRA_HELM_ARGS_CEPH_DEPLOY
OSH_EXTRA_HELM_ARGS_CEPH_NS_ACTIVATE
OSH_EXTRA_HELM_ARGS_CINDER
OSH_EXTRA_HELM_ARGS_GLANCE
OSH_EXTRA_HELM_ARGS_HEAT
OSH_EXTRA_HELM_ARGS_INGRESS_KUBE_SYSTEM
OSH_EXTRA_HELM_ARGS_KEYSTONE
OSH_EXTRA_HELM_ARGS_LIBVIRT
OSH_EXTRA_HELM_ARGS_MARIADB
OSH_EXTRA_HELM_ARGS_MEMCACHED
OSH_EXTRA_HELM_ARGS_NEUTRON
OSH_EXTRA_HELM_ARGS_NOVA
OSH_EXTRA_HELM_ARGS_RABBITMQ
```

Please note, that repo and scripts are still under construction.
