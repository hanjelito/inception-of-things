#!/bin/bash

# Actualizar e instalar curl
sudo apt-get update -y
sudo apt-get install -y curl

server_ip=$1

# Configurar K3s para el agente
export INSTALL_K3S_EXEC="--bind-address=$server_ip --flannel-iface=eth1"
curl -sfL https://get.k3s.io | sh -
echo "K3s instalado en el agente"

NODE_TOKEN="/var/lib/rancher/k3s/server/node-token"
while [ ! -e ${NODE_TOKEN} ]; do
    sleep 2
done
echo "Token generado"

# Copiar token y configuración kubeconfig al directorio compartido
sudo cp ${NODE_TOKEN} /vagrant/confs/
sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/

KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
sudo cp ${KUBE_CONFIG} /vagrant/confs/
chmod -R 664 /etc/rancher/k3s/k3s.yaml

# Opcional: limpiar directorio compartido
# sudo rm -rf /vagrant/confs/*
