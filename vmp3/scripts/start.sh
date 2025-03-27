#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Variables configurables
CLUSTER_NAME="iot-cluster"
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
GITHUB_REPO="https://github.com/hanjelito/juan-gon-iot.git"

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Comprobar si k3d está instalado
if ! command -v k3d &> /dev/null; then
    handle_error "k3d no está instalado. Ejecuta install-tools.sh primero."
fi

echo -e "${CYAN}==> Eliminando cluster k3d existente (si existe)...${NC}"
k3d cluster delete $CLUSTER_NAME &>/dev/null || true

echo -e "${CYAN}==> Creando cluster k3d...${NC}"
k3d cluster create $CLUSTER_NAME -p "8888:30080@loadbalancer" || handle_error "Error al crear el cluster k3d"

echo -e "${CYAN}==> Verificando que el cluster está funcionando...${NC}"
kubectl cluster-info || handle_error "El cluster de Kubernetes no está funcionando"

echo -e "${CYAN}==> Creando namespace para ArgoCD...${NC}"
kubectl create namespace $ARGOCD_NAMESPACE || handle_error "Error al crear el namespace de ArgoCD"

echo -e "${CYAN}==> Instalando ArgoCD en el cluster k3d...${NC}"
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || handle_error "Error al instalar ArgoCD"

echo -e "${CYAN}==> Esperando a que los pods de ArgoCD estén listos...${NC}"
echo -e "${YELLOW}Esto puede tardar unos minutos. Por favor, ten paciencia.${NC}"

# Esperar a que los pods más importantes estén listos
for deployment in "argocd-server" "argocd-repo-server"; do
    echo -e "${CYAN}Esperando a que $deployment esté disponible...${NC}"
    kubectl wait --for=condition=available deployment/$deployment -n $ARGOCD_NAMESPACE --timeout=5m || handle_error "Timeout esperando a $deployment"
done

echo -e "${CYAN}==> Obteniendo la contraseña de administrador de ArgoCD...${NC}"
ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$ARGOCD_PASSWORD" ]; then
    handle_error "No se pudo obtener la contraseña de ArgoCD"
fi
echo -e "${GR}Usuario de ArgoCD: admin${NC}"
echo -e "${GR}Contraseña de ArgoCD: $ARGOCD_PASSWORD${NC}"

echo -e "${CYAN}==> Creando namespace para desarrollo...${NC}"
kubectl create namespace $DEV_NAMESPACE || handle_error "Error al crear el namespace de desarrollo"

echo -e "${CYAN}==> Creando Application de ArgoCD...${NC}"
cat > ../confs/application.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-application
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $GITHUB_REPO
    targetRevision: HEAD
    path: dev
  destination: 
    server: https://kubernetes.default.svc
    namespace: $DEV_NAMESPACE
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      selfHeal: true
      prune: true
EOF

echo -e "${CYAN}==> Aplicando el recurso Application de ArgoCD...${NC}"
kubectl apply -f ../confs/application.yaml || handle_error "Error al aplicar la Application de ArgoCD"

echo -e "${CYAN}==> Iniciando reenvío de puertos para la UI de ArgoCD...${NC}"
# Iniciar reenvío de puertos en segundo plano
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
echo -e "${GR}La UI de ArgoCD está disponible en: https://$(hostname -I | awk '{print $1}'):8080${NC}"
echo -e "${YELLOW}(Deberás aceptar la advertencia de certificado autofirmado)${NC}"

echo -e "${CYAN}==> Verificando disponibilidad de la aplicación...${NC}"
echo -e "${GR}Tu aplicación debería estar disponible en: http://localhost:8888${NC}"

echo -e "${CYAN}==> Instrucciones para actualizar la versión:${NC}"
echo -e "${GR}1. Ve a tu repositorio GitHub: $GITHUB_REPO${NC}"
echo -e "${GR}2. Actualiza la etiqueta de imagen de 'v1' a 'v2' en el archivo deployment YAML${NC}"
echo -e "${GR}3. Haz commit y push de los cambios${NC}"
echo -e "${GR}4. ArgoCD detectará y aplicará los cambios automáticamente${NC}"
echo -e "${GR}5. Para verificar la actualización, ejecuta: curl http://localhost:8888${NC}"

echo -e "${GR}¡Configuración completada! Mantén esta terminal abierta para mantener el reenvío de puertos.${NC}"
echo -e "${YELLOW}Presiona Ctrl+C para detener el reenvío de puertos cuando hayas terminado.${NC}"

# Esperar a que el proceso de reenvío de puertos termine
wait $PORT_FORWARD_PID