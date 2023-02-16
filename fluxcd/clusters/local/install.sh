#!/bin/bash

set -e

CONTEXT=$(kubectl config current-context)

if [ "$CONTEXT" != "k3d-develop" ]; then
    echo "Du benutzt den falschen Context:"
    echo "Aktueller Context: ${CONTEXT}"
    echo "Gewünschter Context: k3d-develop"
    echo
    echo "Probiere mal: kubectl config use-context k3d-develop"
    exit
fi

echo Create Namespace
kubectl create namespace flux-system 
echo Add Azure Key Vault Secrets
sops exec-file azure-key-vault-secret.enc.yaml "kubectl apply -f {} -n flux-system"
echo Git Pull Secrets
sops exec-file git-pull-secret.enc.yaml "kubectl apply -f {} -n flux-system"
echo Install Components
kubectl apply -f flux-components.yaml
echo Patch to use Secrets
kubectl patch deployment kustomize-controller -n flux-system --patch "$(cat flux-deployment-kustomize-patch.yaml)"
sleep 10
echo "Install Git & Kustomize Sync"
kubectl apply -f flux-sync.yaml
