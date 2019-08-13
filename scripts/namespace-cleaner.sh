#!/bin/bash

NAMESPACE=${NAMESPACE:-''}

if [ -z "${NAMESPACE}" ]; then
    echo "Please set NAMESPACE variable"
    exit 1
fi

helm list -a | grep $NAMESPACE | awk '{print $1}' | xargs helm delete --purge
sleep 10

kubectl delete all --all -n $NAMESPACE
kubectl delete namespace $NAMESPACE

for resource in $(kubectl get all -n $NAMESPACE  --no-headers  | awk '{print $1}');
do
    echo $resource;
    kubectl delete -n $NAMESPACE $resource --wait=False --grace-period=0 --force;
done

for pv in $(kubectl get pv -n $NAMESPACE --no-headers | grep -i $NAMESPACE | awk '{print $1}');
do
    kubectl delete pv -n $NAMESPACE $pv --wait=False
done

for pvc in $(kubectl get pvc -n $NAMESPACE --no-headers | grep -i $NAMESPACE | awk '{print $1}');
do
    kubectl delete pvc -n $NAMESPACE $pvc --wait=False
done

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


for configmap in $(kubectl get configmap -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting configmap: $configmap"
    kubectl delete configmap $configmap -n $NAMESPACE --wait=False
done

for componentstatus in $(kubectl get componentstatus -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting componentstatus: $componentstatus"
    kubectl delete componentstatus $componentstatus -n $NAMESPACE --wait=False
done

for customresourcedefinition in $(kubectl get customresourcedefinition -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting customresourcedefinition: $customresourcedefinition"
    kubectl delete customresourcedefinition $customresourcedefinition -n $NAMESPACE --wait=False
done

for cronjob in $(kubectl get cronjob -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting cronjob: $cronjob"
    kubectl delete cronjob $cronjob -n $NAMESPACE --wait=False
done

for deployment in $(kubectl get deployment -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting deployment: $deployment"
    kubectl delete deployment $deployment -n $NAMESPACE --wait=False
done

for daemonset in $(kubectl get daemonset -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting daemonset: $daemonset"
    kubectl delete daemonset $daemonset -n $NAMESPACE --wait=False
done

for endpoint in $(kubectl get endpoint -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting endpoint: $endpoint"
    kubectl delete endpoint $endpoint -n $NAMESPACE --wait=False
done

for jb in $(kubectl get jobs.batch -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting jobs.batch: $jb"
    kubectl delete jobs.batch $jb -n $NAMESPACE --wait=False
done

for limitranges in $(kubectl get limitranges -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting limitranges: $limitranges"
    kubectl delete limitranges $limitranges -n $NAMESPACE --wait=False
done

for pods in $(kubectl get pods -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting pods: $pods"
    kubectl delete pods $pods -n $NAMESPACE --wait=False
done

for podtemplates in $(kubectl get podtemplates -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting podtemplates: $podtemplates"
    kubectl delete podtemplates $podtemplates -n $NAMESPACE --wait=False
done

for replicaset in $(kubectl get replicaset -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting replicaset: $replicaset"
    kubectl delete replicaset $replicaset -n $NAMESPACE --wait=False
done

for secret in $(kubectl get secret -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting secret: $secret"
    kubectl delete secret $secret -n $NAMESPACE --wait=False
done

for service in $(kubectl get service -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting service: $service"
    kubectl delete service $service -n $NAMESPACE --wait=False
done

for statefulset in $(kubectl get statefulset -n $NAMESPACE --no-headers | awk '{print $1}');
do
    echo "Deleting statefulset: $statefulset"
    kubectl delete statefulset $statefulset -n $NAMESPACE --wait=False
done

#for service in $(kubectl get service -n $NAMESPACE --no-headers | awk '{print $1}');
#do
#    echo "Deleting service: $service"
#    kubectl delete service $service -n $NAMESPACE --wait=False
#done
