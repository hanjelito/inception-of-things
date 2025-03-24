#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl openssh-server openssh-client sshpass

server_ip=$1

# Configurar SSH sin contraseña
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
ssh-keygen -t rsa -b 4096 -f /home/vagrant/.ssh/id_rsa -N "" -C "vagrant@server"

#permisos
touch /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Configuracion para acceso sin verificación de host al worker
cat > /home/vagrant/.ssh/config << EOF
Host 192.168.56.111
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
chmod 600 /home/vagrant/.ssh/config
chown vagrant:vagrant /home/vagrant/.ssh/config

# Configurar K3s para el servidor
export INSTALL_K3S_EXEC="--bind-address=$server_ip --flannel-iface=eth1"
curl -sfL https://get.k3s.io | sh -
echo "K3s instalado en el servidor"

NODE_TOKEN="/var/lib/rancher/k3s/server/node-token"
while [ ! -e ${NODE_TOKEN} ]; do
    sleep 2
done
echo "Token generado"

sudo mkdir -p /vagrant/confs
sudo cp ${NODE_TOKEN} /vagrant/confs/
sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/

KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
sudo sed -i "s/127.0.0.1/${server_ip}/g" ${KUBE_CONFIG}
sudo cp ${KUBE_CONFIG} /vagrant/confs/
chmod -R 664 /etc/rancher/k3s/k3s.yaml

echo "Esperando a que el worker esté disponible..."
sleep 30

echo "Copiando clave SSH al worker..."
sshpass -p "vagrant" ssh-copy-id -o StrictHostKeyChecking=no vagrant@192.168.56.111

echo "Configuración del servidor completada"