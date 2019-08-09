#!/bin/bash

NAMESPACE=${NAMESPACE:-''}

if [ -z "${NAMESPACE}" ]; then
    echo "Please set NAMESPACE variable"
    exit 1
fi

helm list -a | grep $NAMESPACE | awk '{print $1}' | xargs helm delete --purge
#sleep 60

for resource in $(kubectl get all -n $NAMESPACE  --no-headers  | awk '{print $1}');
do
    echo $resource;
    kubectl delete -n $NAMESPACE $resource --wait=False;
done

kubectl get pv -n $NAMESPACE --no-headers | grep $NAMESPACE | awk '{print $1}' | xargs kubectl delete pv --wait=false
kubectl get pvc -n $NAMESPACE --no-headers | grep $NAMESPACE | awk '{print $1}' | xargs kubectl delete pvc --wait=false

kubectl delete events -all -n $NAMESPACE --wait=false

for configmap in $(kubectl get configmaps -n $NAMESPACE --no-headers | grep "$NAMESPACE" | awk '{print $1}');
do
    echo "Deleting configmap: $configmap"
    kubectl delete configmap $configmap -n $NAMESPACE --wait=false
done


for deployment in $(kubectl get deployments -n $NAMESPACE --no-headers | grep "$NAMESPACE" | awk '{print $1}');
do
    echo "Deleting deployment: $deployment"
    kubectl delete deployment $deployment -n $NAMESPACE --wait=false
done

# FIXME: add other things
TO_CLEAN="""configmaps componentstatuses
         customresourcedefinitions cronjobs deployments
         daemonsets events endpoints jobs.batch
         limitranges pods podtemplates replicasets
         secrets serviceaccounts services statefulsets"""

for CLEAN in $TO_CLEAN; do
    echo "checking $CLEAN"
    kubectl get $CLEAN -n $NAMESPACE --no-headers
done
