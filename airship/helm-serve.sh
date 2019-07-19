#!/bin/bash

sudo -E tee /etc/systemd/system/helm-serve.service << EOF
[Unit]
Description=Helm Server
After=network.target
[Service]
User=$(id -un 2>&1)
Restart=always
ExecStart=/usr/local/bin/helm serve
[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0640 /etc/systemd/system/helm-serve.service

sudo systemctl daemon-reload
sudo systemctl restart helm-serve
sudo systemctl enable helm-serve

# Remove stable repo, if present, to improve build time
helm repo remove stable || true

# Set up local helm repo
helm repo add local http://localhost:8879/charts
helm repo update
