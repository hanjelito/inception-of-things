#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

echo -e "${GR}==============================================================${NC}"
echo -e "${GR}           INCEPTION OF THINGS - BONUS SETUP                  ${NC}"
echo -e "${GR}==============================================================${NC}"

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Verificar que los scripts necesarios existen
if [ ! -f "install-tools.sh" ]; then
    handle_error "No se encontró el script install-tools.sh. Asegúrate de estar en el directorio correcto."
fi

if [ ! -f "install-gitlab.sh" ]; then
    handle_error "No se encontró el script install-gitlab.sh. Asegúrate de estar en el directorio correcto."
fi

if [ ! -f "configure-gitlab-integration.sh" ]; then
    handle_error "No se encontró el script configure-gitlab-integration.sh. Asegúrate de estar en el directorio correcto."
fi

# 1. Hacer scripts ejecutables
echo -e "${CYAN}==> Haciendo scripts ejecutables...${NC}"
chmod +x install-tools.sh install-gitlab.sh configure-gitlab-integration.sh || handle_error "No se pudieron establecer permisos de ejecución"

# 2. Instalar herramientas necesarias
echo -e "${CYAN}==> Instalando herramientas necesarias...${NC}"
./install-tools.sh || handle_error "Falló la instalación de herramientas"

# Asegurarse de que los cambios en los grupos Docker surtan efecto
echo -e "${CYAN}==> Aplicando cambios de permisos de Docker...${NC}"
if groups | grep -q docker; then
    echo -e "${GR}Usuario ya en el grupo docker.${NC}"
else
    echo -e "${YELLOW}Reiniciando la sesión para aplicar permisos de Docker...${NC}"
    exec su -l $USER  # Esto reiniciará la sesión del usuario actual
fi

# 3. Crear directorios de configuración si no existen
echo -e "${CYAN}==> Creando directorios de configuración...${NC}"
mkdir -p ../confs || handle_error "No se pudo crear el directorio de configuración"

# 4. Instalar y configurar GitLab
echo -e "${CYAN}==> Instalando GitLab (esto puede tardar varios minutos)...${NC}"
./install-gitlab.sh || handle_error "Falló la instalación de GitLab"

# 5. Configurar la integración de GitLab con ArgoCD
echo -e "${CYAN}==> Configurando la integración de GitLab con ArgoCD...${NC}"
./configure-gitlab-integration.sh || handle_error "Falló la configuración de la integración de GitLab con ArgoCD"

echo -e "${GR}==============================================================${NC}"
echo -e "${GR}           CONFIGURACIÓN DEL BONUS COMPLETADA                 ${NC}"
echo -e "${GR}==============================================================${NC}"

echo -e "${CYAN}Tu entorno bonus ahora está configurado con:${NC}"
echo -e "${GR}- K3d cluster ejecutándose${NC}"
echo -e "${GR}- GitLab instalado en el namespace 'gitlab'${NC}"
echo -e "${GR}- ArgoCD configurado para usar el repositorio de GitLab${NC}"
echo -e "${GR}- Una aplicación de muestra desplegada en el namespace 'dev'${NC}"

echo -e "${CYAN}Accesos:${NC}"
echo -e "${GR}1. GitLab UI: http://localhost:8929${NC}"
echo -e "${GR}   Usuario: root${NC}"
echo -e "${GR}   Contraseña: La mostrada anteriormente en la instalación${NC}"

echo -e "${GR}2. ArgoCD UI: https://localhost:8080${NC}"
echo -e "${GR}   Usuario: admin${NC}"
echo -e "${GR}   Contraseña: La generada por ArgoCD durante la instalación${NC}"

echo -e "${GR}3. Aplicación: http://localhost:8888${NC}"

echo -e "${YELLOW}Nota: Esta configuración mantiene varios reenvíos de puertos activos.${NC}"
echo -e "${YELLOW}      Si cierras esta terminal, puedes tener que reiniciar los reenvíos manualmente.${NC}"
echo -e "${YELLOW}      Consulta los scripts individuales para ver los comandos exactos de reenvío de puertos.${NC}"