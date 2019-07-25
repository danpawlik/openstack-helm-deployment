#!/bin/bash

sudo su - root -c bash <<'END_SCRIPT'
mkdir -p /root/deploy && cd "$_"
git clone https://git.openstack.org/openstack/airship-in-a-bottle
cd /root/deploy/airship-in-a-bottle/manifests/dev_single_node
./airship-in-a-bottle.sh | tee -a /home/ubuntu/airship-log
END_SCRIPT
