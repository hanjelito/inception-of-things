#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Variable configurable
CLUSTER_NAME="iot-cluster"

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

echo -e "${CYAN}==> Script de corrección para problemas de conexión con K3d${NC}"

# Limpiar cualquier configuración existente
echo -e "${CYAN}==> Eliminando cualquier clúster K3d existente...${NC}"
k3d cluster delete $CLUSTER_NAME 2>/dev/null || true

# Asegurarse de que Docker está funcionando
echo -e "${CYAN}==> Verificando que Docker está funcionando...${NC}"
if ! docker info &>/dev/null; then
    echo -e "${YELLOW}Docker no parece estar funcionando. Intentando iniciar el servicio...${NC}"
    sudo systemctl start docker || handle_error "No se pudo iniciar Docker. Verifica la instalación de Docker."
    sleep 5
fi

# Crear un nuevo clúster K3d con configuración específica
echo -e "${CYAN}==> Creando un nuevo clúster K3d...${NC}"
k3d cluster create $CLUSTER_NAME \
    --api-port 6550 \
    -p "8888:30080@loadbalancer" \
    --wait || handle_error "Error al crear el clúster K3d"

# Explícitamente configurar KUBECONFIG para usar el nuevo clúster
echo -e "${CYAN}==> Configurando KUBECONFIG...${NC}"
export KUBECONFIG="$(k3d kubeconfig write $CLUSTER_NAME)"
echo "export KUBECONFIG=$KUBECONFIG" > ~/.k3d-env
echo -e "${GR}Se ha creado el archivo ~/.k3d-env con la configuración de KUBECONFIG${NC}"
echo -e "${GR}Ejecuta 'source ~/.k3d-env' antes de ejecutar cualquier comando kubectl${NC}"

# Verificar la conexión al clúster
echo -e "${CYAN}==> Verificando conexión al clúster...${NC}"
if kubectl cluster-info; then
    echo -e "${GR}¡Conexión al clúster establecida correctamente!${NC}"
    echo -e "${GR}Ahora puedes ejecutar './install-gitlab.sh' para continuar con la instalación.${NC}"
else
    handle_error "No se pudo conectar al clúster. Puede ser necesario reiniciar la máquina virtual."
fi