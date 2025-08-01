#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl openssh-server openssh-client

server_ip=$1

while [ ! -f /vagrant/confs/node-token ]; do
    echo "Esperando token del servidor..."
    sleep 5
done

echo "Configurando SSH sin contraseña..."
sudo -u vagrant bash -c "
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Añadir la clave pública del servidor al archivo authorized_keys
cat /vagrant/confs/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
"

k3s_url="https://${server_ip}:6443"

# Instalación de K3s en modo worker
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-iface eth1" K3S_URL=$k3s_url K3S_TOKEN=$(sudo cat /vagrant/confs/node-token) sh -

# Configurar kubectl para los usuarios vagrant y root
mkdir -p /home/vagrant/.kube /root/.kube
sudo cp /vagrant/confs/k3s.yaml /home/vagrant/.kube/config
sudo cp /home/vagrant/.kube/config /root/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube

echo "Configuración del worker completada"