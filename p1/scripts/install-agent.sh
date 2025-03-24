#!/bin/bash

# Actualizar e instalar curl
sudo apt-get update -y
sudo apt-get install -y curl

server_ip=$1

# Asegúrate de que la URL de K3s comienza con https://
k3s_url="https://${server_ip}:6443"

# Instalación de K3s
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-iface eth1" K3S_URL=$k3s_url K3S_TOKEN=$(sudo cat /vagrant/confs/node-token) sh -

# Configurar kubectl para los usuarios vagrant y root
mkdir -p /home/vagrant/.kube /root/.kube
sudo cp /vagrant/confs/k3s.yaml /home/vagrant/.kube/config
sudo cp /home/vagrant/.kube/config /root/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube

# Opcional: comandos de ejemplo para despliegues en Kubernetes
# sudo rm -rf /vagrant/confs/node-token
# kubectl create deployment example-deployment --image=nginx
# kubectl scale deployment example-deployment --replicas=2
