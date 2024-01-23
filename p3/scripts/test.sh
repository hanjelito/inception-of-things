#!/bin/bash

# Configurar Git
# Aquí asumimos que ya tienes un repositorio de Git configurado y que estás en la rama adecuada

# Instalar K3D (asegúrate de que Docker esté instalado)
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
k3d cluster create mycluster --api-port 6550 -p "8080:80@loadbalancer" --agents 2

# Instalar Argo CD en K3D
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar hasta que Argo CD esté listo para usar
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s

# Configurar acceso a Docker Hub
# Aquí debes reemplazar 'docker_username' y 'docker_password' con tus propios datos
docker login --username=docker_username --password=docker_password

# Construir y subir la imagen de tu aplicación a Docker Hub
# Este comando depende de que tengas un Dockerfile en el directorio actual
docker build -t docker_username/mi_aplicacion:v1 .
docker push docker_username/mi_aplicacion:v1

# Crear un manifiesto de despliegue para Argo CD (esto debe ser ajustado a tu configuración)
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mi-aplicacion
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/tu_usuario/tu_repositorio.git'
    path: path/a/tu/aplicacion
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: dev
EOF

# Nota: Este script solo proporciona una estructura básica. Deberás adaptar cada comando a tu configuración específica.
