#!/bin/bash

NODE_ADDRESS=${NODE_ADDRESS:-$1}
SSH_KEY=${SSH_KEY:-"/home/ubuntu/.ssh/id_rsa"}

if [ -z "${NODE_ADDRESS}" ]; then
    echo "You need to put NODE_ADDRESS or set it as first argument!"
    exit 1
fi

if [ ! -f "${SSH_KEY}" ]; then
    echo "Can't find key to login into the minion node"
    exit 1
fi

JOIN_COMMAND="sudo $(kubeadm token create --print-join-command)"
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "ubuntu@${NODE_ADDRESS}" "${JOIN_COMMAND}"
