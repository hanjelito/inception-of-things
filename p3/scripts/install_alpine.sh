#!/bin/sh

apk update
apk upgrade

apk add curl docker openrc

rc-update add docker boot

if ! docker ps &> /dev/null
then
    echo "Iniciando Docker..."
    rc-service docker start
else
    echo "Docker ya está en ejecución."
fi

# Instalar k3d
if ! command -v k3d &> /dev/null
then
    echo "Instalando k3d..."
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
else
    echo "k3d ya está instalado."
fi

# Instalar argocd CLI
if ! command -v argocd &> /dev/null
then
    echo "Instalando argocdcli..."
    # Definir la versión de argocd que deseas instalar
    ARGOCD_VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # Descargar el binario adecuado para Linux
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
    
    # Hacer el binario ejecutable
    chmod +x /usr/local/bin/argocd
else
    echo "argocdcli ya está instalado."
fi

# Nota: Dependiendo de las necesidades, podrías tener que agregar usuarios al grupo 'docker':
# addgroup <username> docker
