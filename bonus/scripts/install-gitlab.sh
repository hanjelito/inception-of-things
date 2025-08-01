#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Variables configurables
CLUSTER_NAME="iot-cluster"
GITLAB_NAMESPACE="gitlab"
HELM_VERSION="3.12.3"  # Versión de Helm a instalar

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Comprobar si k3d está instalado
if ! command -v k3d &> /dev/null; then
    handle_error "k3d no está instalado. Ejecuta install-tools.sh primero."
fi

# Verificar y configurar el clúster k3d
echo -e "${CYAN}==> Verificando estado del cluster k3d...${NC}"
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo -e "${CYAN}El clúster no existe, creándolo...${NC}"
    k3d cluster create $CLUSTER_NAME -p "8888:30080@loadbalancer" || handle_error "Error al crear el clúster k3d"
    echo -e "${CYAN}Esperando a que el clúster esté listo (10 segundos)...${NC}"
    sleep 10  # Dar tiempo a que el clúster se inicialice completamente
fi

# Asegurarse de que el contexto de kubectl está configurado correctamente
echo -e "${CYAN}==> Configurando kubeconfig...${NC}"
k3d kubeconfig merge $CLUSTER_NAME --kubeconfig-switch-context || handle_error "Error al actualizar kubeconfig"

# Verificar la conexión al clúster
echo -e "${CYAN}==> Verificando conexión al clúster...${NC}"
if ! kubectl cluster-info; then
    handle_error "No se puede conectar al clúster. Verifica que el clúster está en ejecución."
fi

echo -e "${CYAN}==> Instalando Helm (si no está instalado)...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${CYAN}Instalando Helm...${NC}"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 || handle_error "No se pudo descargar el script de instalación de Helm"
    chmod 700 get_helm.sh || handle_error "No se pudo establecer permisos en el script de Helm"
    ./get_helm.sh --version v${HELM_VERSION} || handle_error "Error al instalar Helm"
    rm get_helm.sh
else
    echo -e "${GR}Helm ya está instalado.${NC}"
fi

# Verificar si existe el namespace de GitLab, si no crearlo
echo -e "${CYAN}==> Creando namespace para GitLab...${NC}"
kubectl get namespace $GITLAB_NAMESPACE &> /dev/null || kubectl create namespace $GITLAB_NAMESPACE || handle_error "Error al crear el namespace de GitLab"

echo -e "${CYAN}==> Añadiendo repositorio de GitLab Helm...${NC}"
helm repo add gitlab https://charts.gitlab.io/ || handle_error "Error al añadir el repositorio de GitLab Helm"
helm repo update || handle_error "Error al actualizar repositorios de Helm"

# Eliminar cualquier secreto TLS existente antes de crear uno nuevo
echo -e "${CYAN}==> Limpiando cualquier configuración TLS anterior...${NC}"
kubectl delete secret gitlab-tls -n $GITLAB_NAMESPACE --ignore-not-found

# Generar un certificado TLS autofirmado para GitLab
echo -e "${CYAN}==> Generando certificado TLS autofirmado para GitLab...${NC}"
mkdir -p ../confs/gitlab-certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ../confs/gitlab-certs/gitlab.key \
  -out ../confs/gitlab-certs/gitlab.crt \
  -subj "/CN=gitlab.local/O=IoT Project/C=ES" || handle_error "Error al generar certificados TLS"

# Crear un secret con los certificados TLS
kubectl create secret tls gitlab-tls --key ../confs/gitlab-certs/gitlab.key --cert ../confs/gitlab-certs/gitlab.crt -n $GITLAB_NAMESPACE || handle_error "Error al crear secret TLS"

# Crear archivo values personalizado para GitLab (versión ligera para desarrollo)
cat > ../confs/gitlab-values.yaml <<EOF
global:
  edition: ce
  hosts:
    domain: gitlab.local
    https: true
    externalIP: $(hostname -I | awk '{print $1}')
  ingress:
    configureCertmanager: false
    tls:
      secretName: gitlab-tls
  initialRootPassword:
    secret: gitlab-root-password
    key: password

certmanager:
  install: false

nginx-ingress:
  enabled: false

gitlab-runner:
  install: true

postgresql:
  persistence:
    size: 8Gi
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1
      memory: 1Gi

redis:
  master:
    persistence:
      size: 5Gi
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

minio:
  persistence:
    size: 10Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

gitlab:
  gitaly:
    persistence:
      size: 10Gi
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1
        memory: 2Gi
        
  toolbox:
    enabled: true
    backups:
      enabled: false
    resources:
      requests:
        cpu: 50m
        memory: 350Mi
      limits:
        cpu: 500m
        memory: 700Mi
        
  webservice:
    minReplicas: 1
    maxReplicas: 1
    resources:
      requests:
        cpu: 300m
        memory: 1.5Gi
      limits:
        cpu: 2
        memory: 3Gi
        
  sidekiq:
    minReplicas: 1
    maxReplicas: 1
    resources:
      requests:
        cpu: 200m
        memory: 800Mi
      limits:
        cpu: 1
        memory: 2Gi
EOF

# Eliminar cualquier secreto de contraseña root existente
echo -e "${CYAN}==> Limpiando cualquier configuración de contraseña anterior...${NC}"
kubectl delete secret gitlab-root-password -n $GITLAB_NAMESPACE --ignore-not-found

# Crear un secret para la contraseña de root
GITLAB_ROOT_PASSWORD=$(openssl rand -base64 12)
kubectl create secret generic gitlab-root-password --from-literal=password=$GITLAB_ROOT_PASSWORD -n $GITLAB_NAMESPACE || handle_error "Error al crear secret para contraseña de root"

echo -e "${CYAN}==> Instalando GitLab usando Helm (esto puede tardar varios minutos)...${NC}"
echo -e "${YELLOW}Instalación de GitLab iniciada. Este proceso puede tardar entre 5-10 minutos dependiendo de tu conexión y recursos.${NC}"

# Verificar versión del chart de GitLab disponible
echo -e "${CYAN}==> Verificando versión disponible del chart de GitLab...${NC}"
helm search repo gitlab/gitlab --versions | head -2

# Instalar GitLab con versión específica para evitar incompatibilidades
echo -e "${CYAN}==> Limpiando cualquier instalación previa...${NC}"
helm uninstall gitlab --namespace $GITLAB_NAMESPACE 2>/dev/null || true

echo -e "${CYAN}==> Instalando GitLab con configuración mínima...${NC}"
helm install gitlab gitlab/gitlab \
  --namespace $GITLAB_NAMESPACE \
  -f ../confs/gitlab-values.yaml \
  --timeout 15m \
  --set global.edition=ce \
  --set global.shell.port=22 \
  --set gitlab.toolbox.backups.enabled=false \
  --set certmanager.install=false \
  --set gitlab.migrations.enabled=true \
  --set gitlab.webservice.minReplicas=1 \
  --set gitlab.webservice.maxReplicas=1 \
  --set gitlab.sidekiq.minReplicas=1 \
  --set gitlab.sidekiq.maxReplicas=1 || handle_error "Error al instalar GitLab con Helm"

echo -e "${CYAN}==> Esperando a que los pods de GitLab estén listos...${NC}"
echo -e "${YELLOW}Esto puede tardar varios minutos. Algunos pods pueden reiniciarse varias veces durante la inicialización.${NC}"

# Esperar a que el servicio webservice esté disponible
echo -e "${CYAN}Esperando a que el servicio GitLab webservice esté disponible...${NC}"
kubectl -n $GITLAB_NAMESPACE wait --for=condition=available deployment/gitlab-webservice-default --timeout=15m || echo -e "${YELLOW}Timeout esperando a GitLab webservice, pero continuaremos. Puede que necesite más tiempo para estar completamente listo.${NC}"

echo -e "${GR}==> Información de acceso a GitLab:${NC}"
echo -e "${GR}URL: https://gitlab.local${NC}"
echo -e "${GR}Usuario: root${NC}"
echo -e "${GR}Contraseña: $GITLAB_ROOT_PASSWORD${NC}"
echo -e "${YELLOW}Nota: Necesitarás agregar 'gitlab.local' a tu archivo /etc/hosts apuntando a $(hostname -I | awk '{print $1}')${NC}"
echo -e "${YELLOW}Ejemplo: sudo sh -c \"echo '$(hostname -I | awk '{print $1}') gitlab.local' >> /etc/hosts\"${NC}"

echo -e "${CYAN}==> Configurando reenvío de puertos para GitLab...${NC}"
# Reenviar puertos para acceder a GitLab
kubectl -n $GITLAB_NAMESPACE port-forward svc/gitlab-webservice-default 8929:8181 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
echo -e "${GR}GitLab estará disponible en: http://localhost:8929${NC}"

echo -e "${GR}¡Instalación de GitLab completada!${NC}"
echo -e "${YELLOW}Mantén esta terminal abierta para el reenvío de puertos o ejecuta los comandos manualmente.${NC}"