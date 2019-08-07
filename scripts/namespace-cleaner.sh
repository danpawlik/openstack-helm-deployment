#!/bin/bash

NAMESPACE=${NAMESPACE:-''}

helm list -a | grep $NAMESPACE | awk '{print $1}' | xargs helm delete --purge
kubectl get pv -n $NAMESPACE --no-headers | grep $NAMESPACE | awk '{print $1}' | xargs kubectl delete pv --wait=false
kubectl get pvc -n $NAMESPACE --no-headers | grep $NAMESPACE | awk '{print $1}' | xargs kubectl delete pvc --wait=false
kubectl get all -n $NAMESPACE --no-headers | awk '{print $1}' | xargs kubectl -n $NAMESPACE --wait=false delete
kubectl delete configmaps --all --namespace=$NAMESPACE
#kubectl delete componentstatuses  --all --namespace=$NAMESPACE
#kubectl delete customresourcedefinitions --all --namespace=$NAMESPACE
kubectl delete cronjobs --all --namespace=$NAMESPACE
kubectl delete deployments --all --namespace=$NAMESPACE
kubectl delete daemonsets --all --namespace=$NAMESPACE
kubectl delete events --all --namespace=$NAMESPACE
kubectl delete endpoints --all --namespace=$NAMESPACE
kubectl delete events --all --namespace=$NAMESPACE
kubectl delete jobs.batch  --all --namespace=$NAMESPACE
kubectl delete limitranges --all --namespace=$NAMESPACE
kubectl delete pods --all --namespace=$NAMESPACE
kubectl delete podtemplates --all --namespace=$NAMESPACE
kubectl delete replicasets --all --namespace=$NAMESPACE
kubectl delete secrets --all --namespace=$NAMESPACE
kubectl delete serviceaccounts --all --namespace=$NAMESPACE
kubectl delete services --all --namespace=$NAMESPACE
kubectl delete statefulsets --all --namespace=$NAMESPACE
