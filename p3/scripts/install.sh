#!/bin/bash

# Verificar si Homebrew está instalado
if ! command -v brew &> /dev/null
then
    echo "Instalando Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew ya está instalado."
fi

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null
then
    echo "Instalando Docker..."
    brew install --cask docker
    open /Applications/Docker.app
else
    echo "Docker ya está instalado."
    if ! docker ps &> /dev/null
    then
        echo "Iniciando Docker..."
        open /Applications/Docker.app
    else
        echo "Docker ya está en ejecución."
    fi
fi

# Verificar si kubectl está instalado
if ! command -v kubectl &> /dev/null
then
    echo "Instalando kubectl..."
    brew install kubectl
else
    echo "kubectl ya está instalado."
fi

# Verificar si k3d está instalado
if ! command -v k3d &> /dev/null
then
    echo "Instalando k3d..."
    brew install k3d
else
    echo "k3d ya está instalado."
fi

# Instalar argocd CLI
if ! command -v argocd &> /dev/null
then
    echo "Instalando argocdcli con Homebrew..."
    brew update
    brew install argocd
else
    echo "argocdcli ya está instalado."
fi