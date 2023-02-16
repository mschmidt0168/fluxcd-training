#!/bin/bash

set -u

USERNAME=$1
GROUP=$2
CURRENT_CONTEXT=$(kubectl config current-context)

if [ "$USERNAME" == "" ] || [ "$GROUP" == "" ]; then
    echo $O USERNAME GROUP
    exit
fi

if [ "$CURRENT_CONTEXT" != "k3d-develop" ]; then
    echo "Falscher Context: $CURRENT_CONTEXT != k3d-develop"
    exit
fi

if [ "$USERNAME" == "" ] || [ "$GROUP" == "" ]; then
    echo $0 USERNAME GROUP
    exit
fi

mkdir -p /tmp/user

openssl req -new -newkey rsa:4096 -nodes -keyout /tmp/user/$USERNAME-k8s.key -out /tmp/user/$USERNAME-k8s.csr -subj "/CN=$USERNAME/O=$GROUP"

if uname|grep -iq linux; then
    CSR=$(cat /tmp/user/$USERNAME-k8s.csr | base64 -w 0)
else
    CSR=$(cat /tmp/user/$USERNAME-k8s.csr | base64)
fi

read -r -d '' CSR_YAML << EOM
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $USERNAME-k8s-access
spec:
  groups:
  - system:authenticated
  request: $CSR
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 864000
  usages:
  - "client auth"
EOM

kubectl delete csr $USERNAME-k8s-access --ignore-not-found=true

echo  "$CSR_YAML" | kubectl apply -f-
kubectl certificate approve $USERNAME-k8s-access

kubectl get csr $USERNAME-k8s-access -o jsonpath='{.status.certificate}' | base64 --decode > /tmp/user/$USERNAME-k8s-access.crt

kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode > /tmp/user/k8s-ca.crt

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

kubectl config set-cluster \
    $CLUSTER_NAME \
    --server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') \
    --certificate-authority=/tmp/user/k8s-ca.crt \
    --kubeconfig=/tmp/user/$USERNAME-k8s-config \
    --embed-certs

kubectl config set-credentials $USERNAME \
    --client-certificate=/tmp/user/$USERNAME-k8s-access.crt \
    --client-key=/tmp/user/$USERNAME-k8s.key \
    --kubeconfig=/tmp/user/$USERNAME-k8s-config \
    --embed-certs

kubectl config set-context $USERNAME@$CLUSTER_NAME \
    --cluster=$CLUSTER_NAME \
    --user=$USERNAME \
    --kubeconfig=/tmp/user/$USERNAME-k8s-config

kubectl config use-context $USERNAME@$CLUSTER_NAME \
    --kubeconfig=/tmp/user/$USERNAME-k8s-config

cp ~/.kube/config /tmp/user/config
export KUBECONFIG=/tmp/user/$USERNAME-k8s-config:/tmp/user/config
kubectl config view --raw > ~/.kube/config

unset KUBECONFIG
kubectl config use-context k3d-develop
