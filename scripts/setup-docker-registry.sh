#!/bin/bash

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install \
    apt-transport-https ca-certificates curl \
    software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt-get install docker-ce=18.06.2~ce~3-0~ubuntu -y
