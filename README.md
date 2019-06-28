# Deploy Openstack Helm infra using scripts

Readme is under construction. I just added small into about
how to deploy Openstack infra as multi node using ansible playbook.

## How to execute Ansible playbook
NOTE: prefered system is Ubuntu 18.04 (for contr and minions as well)

1. Install ansible
```
sudo apt update
sudo apt install -y git python3-pip python3-dev
sudo pip install ansible
```

2. Execute playbook - it will check if VM exists and if not, it will spawn
new instances.
NOTE: for now some values are hardcoded. In the future all will be set
in external file.

```
source openrc
git clone https://github.com/danpawlik/openstack-helm-deployment.git ~/openstack-helm-deployment
cd ~/openstack-helm-deployment/multinode
```

3. Execute ansible playbook
```
ansible-playbook deploy-multinode.yaml -vv
```


## How to use Ansible playbook v2
1. Install ansible
```
sudo apt update
sudo apt install -y git python3-pip python3-dev
sudo pip install ansible
```

2. Execute playbook - it will check if VM exists and if not, it will spawn
new instances.
NOTE: for now some values are hardcoded. In the future all will be set
in external file.

```
source openrc
git clone https://github.com/danpawlik/openstack-helm-deployment.git ~/openstack-helm-deployment
cd ~/openstack-helm-deployment/multinode_v2
```

3. Modify "local" inventory in:
```
roles/local_inventory/tasks/main.yaml
```

And put there names of your new vms and also how many controllers and
"minions" (k8s node) hosts should be added.
NOTE: for now it works with 1 controller and 2 minions or just 1 minion.

4. Execute ansible playbook
```
ansible-playbook deploy-all.yml -vv
```

## To deploy vm with airskiff:
1. Install ansible
```
sudo apt update
sudo apt install -y git python3-pip python3-dev
sudo pip install ansible
```

2. Execute playbook - it will check if VM exists and if not, it will spawn
new instances.
NOTE: for now some values are hardcoded. In the future all will be set
in external file.

```
source openrc
git clone https://github.com/danpawlik/openstack-helm-deployment.git ~/openstack-helm-deployment
cd ~/openstack-helm-deployment/airskiff
```

3. Execute ansible playbook
```
ansible-playbook deploy-airskiff.yml -vv
```


Please note, that repo and scripts are still under construction.
