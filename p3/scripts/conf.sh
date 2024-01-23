#!/bin/bash

# Crear cluster k3d
k3d cluster create mycluster -p "80:80@loadbalancer" -p "443:443@loadbalancer" -p "8888:8888@loadbalancer"

# Crear namespaces
kubectl apply -f ../confs/dev-namespace.yaml
kubectl apply -f ../confs/argo-namespace.yaml

# Instalar Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Convertir el servicio de Argo CD en LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Esperar a que el servidor de Argo CD esté disponible
echo 'Esperando que argocd-server esté disponible...'
kubectl wait deployment/argocd-server -n argocd --for=condition=Available=true --timeout=300s

# Cambiar la contraseña del usuario admin de Argo CD
# Nota: Reemplaza 'mysupersecretpassword' con tu contraseña deseada
PASSWORD_HASH=$(htpasswd -bnBC 10 "" mysupersecretpassword | tr -d ':\n')
kubectl -n argocd patch secret argocd-secret \
    -p '{"stringData": {
        "admin.password": "'$PASSWORD_HASH'",
        "admin.passwordMtime": "'$(date +%FT%T%Z)'"
    }}'

# Crear aplicación
kubectl apply -f ../confs/application.yaml
