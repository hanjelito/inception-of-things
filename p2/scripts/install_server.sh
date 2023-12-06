#!/bin/sh

apk update
apk add curl

server_ip=$1

export INSTALL_K3S_EXEC="--bind-address-=$server_ip --flannel-iface=eth1"
curl -sfL https://get.k3s.io | sh -

#echo in color red
echo -e "\e[31m k3s installed \e[0m"
NODE_TOKEN="/var/lib/rancher/k3s/server/node-token"
while [ ! -e ${NODE_TOKEN} ]
do
	sleep 2
done
echo -e "\e[31m token created \e[0m"
sudo cp ${NODE_TOKEN} /vagrant/confs/
sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/

KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
sudo cp ${KUBE_CONFIG} /vagrant/confs/