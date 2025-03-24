#!/bin/bash

# Actualizar los paquetes del sistema
sudo apt-get update -y
sudo apt-get install -y curl

# Obtener la dirección IP del servidor desde el primer argumento
server_ip=$1

# Configurar variables de entorno para K3s
export INSTALL_K3S_EXEC="--bind-address=$server_ip --flannel-iface=eth1"

# Instalar K3s
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - server
echo -e "\e[31m k3s instalado \e[0m"

# Esperar a que K3s esté listo
echo "Esperando a que K3s esté listo..."
attempt=1
while ! /usr/local/bin/kubectl get nodes &> /dev/null; do
  echo "Intento $attempt de conectar con el clúster..."
  sleep 5
  attempt=$((attempt + 1))
done
echo "K3s está listo y los nodos están en estado 'Ready'."

# Bucle para crear espacios de nombres y desplegar aplicaciones
for app in app1 app2 app3 ingress; do
    # Desplegar la aplicación
    echo -e "\e[31m Creando $app en el espacio de nombres $app \e[0m"
    /usr/local/bin/kubectl apply -f /vagrant/confs/$app/$app.yaml
done

# Configuraciones adicionales para el usuario vagrant
echo "export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /home/vagrant/.profile
echo "alias ls='ls --color=auto'" >> /home/vagrant/.profile
chown vagrant:vagrant /home/vagrant/.profile

echo -e "\e[31m Finalizado \e[0m"
