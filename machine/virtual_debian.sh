#!/bin/bash

# Variables de configuración
VM_NAME="NestedVM"
DEBIAN_ISO_PATH="./linux/debian.iso"
VM_HD_PATH="$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
VM_RAM="2048" # Aumentado para mejor rendimiento en virtualización anidada
VM_VRAM="128" # Aumentado para mejor rendimiento gráfico
VM_HD_SIZE="20000" # Aumentado para dar más espacio para VMs internas
VM_CPUS="2" # Aumentado para mejor rendimiento

# Verificar si la imagen ISO existe
if [ ! -f "$DEBIAN_ISO_PATH" ]; then
    echo "Error: Debian ISO no encontrada en $DEBIAN_ISO_PATH"
    exit 1
fi

# Crear una máquina virtual
VBoxManage createvm --name $VM_NAME --ostype "Debian_64" --register || { echo "Error creando VM"; exit 1; }

# Configurar la máquina virtual
VBoxManage modifyvm $VM_NAME --ioapic on \
                             --memory $VM_RAM \
                             --vram $VM_VRAM \
                             --cpus $VM_CPUS \
                             --graphicscontroller vmsvga \
                             --accelerate3d on \
                             --nic1 nat || { echo "Error configurando VM"; exit 1; }

# Habilitar la virtualización anidada (importante para VMs anidadas)
VBoxManage modifyvm $VM_NAME --nested-hw-virt on

# Configurar reenvío de puertos para SSH (opcional)
VBoxManage modifyvm $VM_NAME --natpf1 "guestssh,tcp,,2222,,22" || { echo "Error configurando reenvío de puertos"; exit 1; }

# Crear y adjuntar disco duro virtual
VBoxManage createhd --filename "$VM_HD_PATH" --size $VM_HD_SIZE --format VDI && \
VBoxManage storagectl $VM_NAME --name "SATA Controller" --add sata --controller IntelAHCI && \
VBoxManage storageattach $VM_NAME --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_HD_PATH" || { echo "Error en disco duro virtual"; exit 1; }

# Configurar y montar la unidad de DVD con la ISO
VBoxManage storagectl $VM_NAME --name "IDE Controller" --add ide && \
VBoxManage storageattach $VM_NAME --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $DEBIAN_ISO_PATH || { echo "Error configurando unidad de DVD"; exit 1; }

# Iniciar la máquina virtual
VBoxManage startvm $VM_NAME || { echo "Error iniciando VM"; exit 1; }
