#!/bin/bash

if sudo grep -qv 'ubuntu' /etc/sudoers ; then
    echo -e "ubuntu  ALL=(ALL) NOPASSWD: ALL\nroot  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers && \
    sudo cat /etc/sudoers | sed "/root\tALL=(ALL:ALL)\ ALL/d" | sudo tee /etc/sudoers
fi
