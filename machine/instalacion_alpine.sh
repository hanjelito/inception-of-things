vi /etc/network/interfaces

#escribit para tener internet
auto eth0
iface eth0 inet dhcp


#resetar:
service networking restart

#ping google.com

# configura alpine para conectar con sus librerias
vi /etc/apk/repositories

#escribir:
http://dl-cdn.alpinelinux.org/alpine/v3.12/main
http://dl-cdn.alpinelinux.org/alpine/v3.12/community

#acutalizar alpine
apk update

# add sudo
apk add sudo

# update
sudo apk update
sudo apk upgrade

#testear install vim
apk add vim

#instalar ssh
apk add openssh
#iniciar ssh
rc-service sshd restart
#verificar que este corriendo
netstat -tuln | grep 22




# # add user to sudoers
# vi /etc/sudoers

## add sudo:
addgroup sudo

visudo

%sudo   ALL=(ALL:ALL) ALL



# add user
adduser nuevo_usuario
# add password
# passwd nuevo_usuario

adduser nuevo_usuario sudo




# add line
# nuevo_usuario ALL=(ALL) ALL
# save and exit
# test sudo
# sudo ls -la /root




# #configuracion
# sudo apk update
# sudo apk add util-linux

# #verificar
# lscpu

# #verificar virtualizacion
# cat /proc/cpuinfo | grep -E 'vmx|svm'



#instalar curl
sudo apk add curl

#instalar k3s
curl -sfL https://get.k3s.io | sh -
k3s --version

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl cluster-info
kubectl get nodes
#configuracion:
sudo vim /etc/update-extlinux.conf
default_kernel_opts="quiet rootfstype=ext4 cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"
sudo update-extlinux
sudo reboot




# docker
groups juan-gon
sudo addgroup juan-gon docker
sudo visudo

juan-gon ALL=(ALL) NOPASSWD: /usr/bin/docker
sudo rc-service docker restart



k3d:
curl -s -o install_k3d.sh https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh
# Revisar el script
less install_k3d.sh
# Ejecutar el script
sh install_k3d.sh

#docker
apk add docker

sudo rc-update add docker boot

sudo service docker start

sudo service docker status

#test k3d
k3d cluster create mycluster


#
kubectl delete pod nginx-7854ff8877-4lkdq

kubectl delete deployment nginx
