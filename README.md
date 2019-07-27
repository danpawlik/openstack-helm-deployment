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

## Example: how to deploy Airskiff with K8S controller + one node

1. Check if in local inventory, you have defined:

```
  vars:
    k8s_hosts:
      k8s_contr:
        - some_contr
      k8s_minion:
        - some_minion
```

2. You can also set more minions and contr (if you want) but 1 for each is a minimum value.

To set the name, you can just export variables:
```
export CONTR_NAME=airskiff_contr-1
export MINION_1=airskiff-minion-1
```

3. Now you need to read openrc file, because playbooks will read credentials
ans spawn VMs.

```
source openrc
```

4. Now you just need to execute Ansible playbook:
```
ansible-playbook playbooks/airskiff/deploy-all.yml -vv
```

Please note, that repo and scripts are still under construction.
