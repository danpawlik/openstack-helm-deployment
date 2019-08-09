#!/bin/bash

NAMESPACE=${NAMESPACE:-'openstack'}
SCALE_SERVICES=${SCALE_SERVICES:-'true'}
NODES_COUNT=$(kubectl get nodes --no-headers | wc -l)
OS_SERVICES="glance-api keystone-api neutron-server nova-api-metadata nova-api-osapi"

for service in $OS_SERVICES;
do
    SERVICE_COUNT=$(kubectl -n "${NAMESPACE}" get deployment "${service}" -o json | jq .status.replicas)
    if [ "${SERVICE_COUNT}" -le "${NODES_COUNT}" ] && \
       [ "${SERVICE_COUNT}" != "${NODES_COUNT}" ]; then
        echo "Service is not scaled."
        if [ "${SCALE_SERVICES}" = "true" ]; then
            echo "Scaling service: ${service}"
            kubectl -n "${NAMESPACE}" scale deployment "${service}" --replicas="${NODES_COUNT}"
        fi
    fi
done
