#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl openssh-server openssh-client

server_ip=$1

mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
touch /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

k3s_url="https://${server_ip}:6443"

while [ ! -f /vagrant/confs/node-token ]; do
    echo "Esperando token del servidor..."
    sleep 5
done

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-iface eth1" K3S_URL=$k3s_url K3S_TOKEN=$(sudo cat /vagrant/confs/node-token) sh -

mkdir -p /home/vagrant/.kube /root/.kube
sudo cp /vagrant/confs/k3s.yaml /home/vagrant/.kube/config
sudo cp /home/vagrant/.kube/config /root/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube

echo "Configuración del worker completada"