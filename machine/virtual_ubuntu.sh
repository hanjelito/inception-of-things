#!/bin/bash

# Variables de configuración
VM_NAME="UbuntuVM"
UBUNTU_ISO_PATH="./linux/ubuntu-server.iso"  # Asegúrate de que la ruta a la ISO sea correcta
VM_HD_PATH="$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
VM_RAM="1024"  # En MB, Ubuntu podría necesitar más RAM que Alpine
VM_VRAM="64"  # En MB
VM_HD_SIZE="8000"  # En MB (20 GB)
VM_CPUS="2"    # Número de CPUs

# Crear una máquina virtual
VBoxManage createvm --name $VM_NAME --ostype "Ubuntu_64" --register

# Configurar la memoria, CPU, y red
VBoxManage modifyvm $VM_NAME --ioapic on
VBoxManage modifyvm $VM_NAME --memory $VM_RAM --vram $VM_VRAM --cpus $VM_CPUS
VBoxManage modifyvm $VM_NAME --graphicscontroller vmsvga

# Habilitar la virtualización anidada (para virtualización dentro de la VM)
VBoxManage modifyvm $VM_NAME --nested-hw-virt on

# Configurar red NAT
VBoxManage modifyvm $VM_NAME --nic1 nat

# Configurar reenvío de puertos para SSH
VBoxManage modifyvm $VM_NAME --natpf1 "guestssh,tcp,,2222,,22"

# Crear disco duro virtual
VBoxManage createhd --filename "$VM_HD_PATH" --size $VM_HD_SIZE --format VDI

# Adjuntar disco duro virtual
VBoxManage storagectl $VM_NAME --name "SATA Controller" --add sata --controller IntelAHCI
VBoxManage storageattach $VM_NAME --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_HD_PATH"

# Configurar unidad de DVD y montar la ISO
VBoxManage storagectl $VM_NAME --name "IDE Controller" --add ide
VBoxManage storageattach $VM_NAME --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $UBUNTU_ISO_PATH

# Iniciar la máquina virtual
VBoxManage startvm $VM_NAME
