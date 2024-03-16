#!/bin/bash

# Variables de configuración
VM_NAME="AlpineVM"
ALPINE_ISO_PATH="./linux/alpine.iso"
# VM_HD_PATH="$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
VM_HD_PATH="./vm/$VM_NAME/$VM_NAME.vdi" # Cambia esto por la ruta donde quieres almacenar los archivos de la VM
VM_RAM="1024"
VM_VRAM="64"
VM_HD_SIZE="5000"
VM_CPUS="1"

# Verificar si la imagen ISO existe
if [ ! -f "$ALPINE_ISO_PATH" ]; then
    echo "Error: Alpine ISO no encontrada en $ALPINE_ISO_PATH"
    exit 1
fi

# Crear una máquina virtual
VBoxManage createvm --name $VM_NAME --ostype "Linux26_64" --register || { echo "Error creando VM"; exit 1; }

# Configurar la máquina virtual
VBoxManage modifyvm $VM_NAME --ioapic on \
                             --memory $VM_RAM \
                             --vram $VM_VRAM \
                             --cpus $VM_CPUS \
                             --graphicscontroller vmsvga \
                             --accelerate3d on \
                             --nic1 nat || { echo "Error configurando VM"; exit 1; }

# Habilitar la virtualización anidada (para virtualización dentro de la VM)
# VBoxManage modifyvm $VM_NAME --nested-hw-virt on

# Configurar reenvío de puertos para SSH
VBoxManage modifyvm $VM_NAME --natpf1 "guestssh,tcp,,2222,,22" || { echo "Error configurando reenvío de puertos SSH"; exit 1; }
VBoxManage modifyvm $VM_NAME --natpf1 "guest8080,tcp,,8080,,8080" || { echo "Error configurando reenvío de puerto 8080"; exit 1; }


# Crear y adjuntar disco duro virtual
VBoxManage createhd --filename "$VM_HD_PATH" --size $VM_HD_SIZE --format VDI && \
VBoxManage storagectl $VM_NAME --name "SATA Controller" --add sata --controller IntelAHCI && \
VBoxManage storageattach $VM_NAME --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_HD_PATH" || { echo "Error en disco duro virtual"; exit 1; }

# Configurar y montar la unidad de DVD con la ISO
VBoxManage storagectl $VM_NAME --name "IDE Controller" --add ide && \
VBoxManage storageattach $VM_NAME --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $ALPINE_ISO_PATH || { echo "Error configurando unidad de DVD"; exit 1; }


# Iniciar la máquina virtual
VBoxManage startvm $VM_NAME || { echo "Error iniciando VM"; exit 1; }
