#!/bin/bash

NAMESPACE=${NAMESPACE:-'openstack'}
SCALE_SERVICES=${SCALE_SERVICES:-'true'}
OS_SERVICES="glance-api keystone-api neutron-server nova-api-metadata nova-api-osapi"
REPLICATION_COUNT=${REPLICATION_COUNT:-''}

if [ -z "${REPLICATION_COUNT}" ]; then
    REPLICATION_COUNT=$(kubectl get nodes --no-headers | wc -l)
fi

for service in $OS_SERVICES;
do
    SERVICE_COUNT=$(kubectl -n "${NAMESPACE}" get deployment "${service}" -o json | jq .status.replicas)
    if [ "${SERVICE_COUNT}" -le "${REPLICATION_COUNT}" ] && \
       [ "${SERVICE_COUNT}" != "${REPLICATION_COUNT}" ]; then
        echo "Service is not scaled."
        if [ "${SCALE_SERVICES}" = "true" ]; then
            echo "Scaling service: ${service}"
            kubectl -n "${NAMESPACE}" scale deployment "${service}" --replicas="${REPLICATION_COUNT}"
            # FIXME: or maybe this one when k8s is 1.15:
            #kubectl -n "${NAMESPACE}" scale deployment "${service}"--min="${REPLICATION_COUNT}" --max=$((REPLICATION_COUNT * 2)) --cpu-percent=80
        fi
    fi
done
