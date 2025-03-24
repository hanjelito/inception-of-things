#!/bin/bash

# Actualizar e instalar paquetes necesarios
sudo apt-get update -y
sudo apt-get install -y curl openssh-server openssh-client sshpass

server_ip=$1

# Configurar K3s para el servidor
export INSTALL_K3S_EXEC="--bind-address=$server_ip --flannel-iface=eth1"
curl -sfL https://get.k3s.io | sh -
echo "K3s instalado en el servidor"

# Esperar a que K3s genere el token
NODE_TOKEN="/var/lib/rancher/k3s/server/node-token"
while [ ! -e ${NODE_TOKEN} ]; do
    sleep 2
done
echo "Token generado"

# Copiar token y configuración kubeconfig al directorio compartido
sudo mkdir -p /vagrant/confs
sudo cp ${NODE_TOKEN} /vagrant/confs/
sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/

# Reemplazar localhost con la IP del servidor en el archivo kubeconfig
KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
sudo sed -i "s/127.0.0.1/${server_ip}/g" ${KUBE_CONFIG}
sudo cp ${KUBE_CONFIG} /vagrant/confs/
chmod -R 664 /etc/rancher/k3s/k3s.yaml

# Configurar SSH sin contraseña (ejecutar como usuario vagrant)
echo "Configurando SSH sin contraseña..."
sudo -u vagrant bash << EOF
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "vagrant@juanS"

# Crear archivo de configuración SSH para deshabilitar comprobación de host
cat > ~/.ssh/config << EOC
Host 192.168.56.111
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOC
chmod 600 ~/.ssh/config

# Copiar la clave pública para compartirla con el worker
cp ~/.ssh/id_rsa.pub /vagrant/confs/server_id_rsa.pub
EOF

# Crear script auxiliar para configurar el worker
cat > /vagrant/confs/setup_ssh.sh << EOF
#!/bin/bash
# Este script se ejecutará en el worker para configurar SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat /vagrant/confs/server_id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
EOF

# Hacer el script ejecutable
chmod +x /vagrant/confs/setup_ssh.sh

echo "Configuración del servidor completada"