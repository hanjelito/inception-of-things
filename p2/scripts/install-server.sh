#!/bin/sh

apk update
apk add curl

server_ip=$1

export INSTALL_K3S_EXEC="--bind-address=$server_ip --flannel-iface=eth1"

# Instala k3s
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - server
echo -e "\e[31m k3s installed \e[0m"

echo "Esperando a que k3s esté listo..."
attempt=1
while ! k3s kubectl get nodes &> /dev/null; do
  echo "Intento $attempt de conectar con el clúster..."
  sleep 5
  attempt=$((attempt + 1))
done
echo "k3s está listo y los nodos están en estado 'Ready'."

# Bucle para crear espacios de nombres y desplegar aplicaciones
# for app in app1 app2 app3; do
#     # Despliega la aplicación
#     echo -e "\e[31m Creando $app en el espacio de nombres $app \e[0m"
#     k3s kubectl apply -f /vagrant/confs/$app/$app.yaml
# done

# Configuraciones adicionales
echo "export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /home/vagrant/.profile
echo "alias ls='ls --color=auto'" >> /home/vagrant/.profile
chown vagrant:vagrant /home/vagrant/.profile

echo -e "\e[31m finish \e[0m"
