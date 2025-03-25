#!/bin/bash
echo "Iniciando reenvío de puertos para GitLab..."
kubectl -n gitlab port-forward svc/gitlab-webservice-default 8929:8181 > /dev/null 2>&1 &
echo "Iniciando reenvío de puertos para ArgoCD..."
kubectl -n argocd port-forward svc/argocd-server 8080:443 > /dev/null 2>&1 &
echo "Iniciando reenvío de puertos para la aplicación IoT..."
kubectl port-forward -n dev svc/iot-app 8888:8888 > /dev/null 2>&1 &
echo "Todos los servicios están disponibles:"
echo "GitLab: http://localhost:8929 (usuario: root, contraseña: +9kYuegR8aa0+GQY)"
echo "ArgoCD: https://localhost:8080"
echo "Aplicación: http://localhost:8888"