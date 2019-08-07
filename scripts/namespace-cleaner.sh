#!/bin/bash

NAMESPACE=${NAMESPACE:-''}

if [ -z "${NAMESPACE}" ]; then
    echo "Please set NAMESPACE variable"
    exit 1
fi

helm list -a | grep $NAMESPACE | awk '{print $1}' | xargs helm delete --purge
#sleep 60


TO_CLEAN="""all configmaps componentstatuses
         customresourcedefinitions cronjobs deployments
         daemonsets events endpoints events jobs.batch
         limitranges pods podtemplates replicasets
         secrets serviceaccounts services statefulsets"""

kubectl get pv -n $NAMESPACE --no-headers | grep $NAMESPACE | awk '{print $1}' | xargs kubectl delete pv --wait=false
kubectl get pvc -n $NAMESPACE --no-headers | grep $NAMESPACE | awk '{print $1}' | xargs kubectl delete pvc --wait=false

for CLEAN in $TO_CLEAN; do
    echo "checking $CLEAN"
    RESOURCE=$(kubectl get $CLEAN -n $NAMESPACE --no-headers)
    echo -e "Found resources: \n $RESOURE"
    echo $RESOURCE | awk '{print $1}' | xargs kubectl delete $CLEAN --wait=false
done
