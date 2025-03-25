#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Variables
GITLAB_NAMESPACE="gitlab"
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
GITLAB_URL="http://gitlab-webservice-default.gitlab.svc.cluster.local:8181"
GITLAB_PROJECT_NAME="iot-application"
GITLAB_PROJECT_PATH="root/$GITLAB_PROJECT_NAME"
GITLAB_API="$GITLAB_URL/api/v4"

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Asegurarse de que kubectl y jq están instalados
if ! command -v kubectl &> /dev/null; then
    handle_error "kubectl no está instalado. Ejecuta install-tools.sh primero."
fi

if ! command -v jq &> /dev/null; then
    echo -e "${CYAN}==> Instalando jq para procesamiento de JSON...${NC}"
    sudo apt-get update && sudo apt-get install -y jq || handle_error "No se pudo instalar jq"
fi

# Obtener token de GitLab para root
echo -e "${CYAN}==> Obteniendo credenciales de GitLab...${NC}"
GITLAB_ROOT_PASSWORD=$(kubectl -n $GITLAB_NAMESPACE get secret gitlab-root-password -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$GITLAB_ROOT_PASSWORD" ]; then
    handle_error "No se pudo obtener la contraseña de root de GitLab"
fi

echo -e "${CYAN}==> Esperando a que GitLab esté completamente disponible...${NC}"
echo -e "${YELLOW}Esto puede tardar un momento mientras GitLab termina de inicializarse...${NC}"

# Función para verificar si GitLab está listo
check_gitlab_ready() {
    # Intentamos hacer una petición simple a la API de GitLab
    # Usamos kubectl exec para hacerlo desde dentro del clúster
    kubectl -n $GITLAB_NAMESPACE exec deploy/gitlab-webservice-default -- curl -s -k --connect-timeout 5 "$GITLAB_URL/api/v4/version" > /dev/null
    return $?
}

# Esperar hasta que GitLab esté listo
COUNTER=0
MAX_RETRIES=30
while ! check_gitlab_ready; do
    COUNTER=$((COUNTER+1))
    if [ $COUNTER -ge $MAX_RETRIES ]; then
        echo -e "${YELLOW}GitLab aún no está completamente listo después de varios intentos.${NC}"
        echo -e "${YELLOW}Continuaremos, pero algunos pasos podrían fallar. Intenta ejecutar este script de nuevo más tarde.${NC}"
        break
    fi
    echo -e "${YELLOW}Esperando a que GitLab esté disponible (intento $COUNTER/$MAX_RETRIES)...${NC}"
    sleep 10
done

# Crear un token de acceso personal para el usuario root
echo -e "${CYAN}==> Creando token de acceso personal en GitLab...${NC}"

# Usamos kubectl exec para ejecutar curl dentro del contenedor de GitLab
GITLAB_TOKEN=$(kubectl -n $GITLAB_NAMESPACE exec deploy/gitlab-webservice-default -- curl -s -k -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_ROOT_PASSWORD" \
    "$GITLAB_URL/api/v4/users/1/personal_access_tokens" \
    -d "name=argocd-integration&scopes[]=api&scopes[]=read_repository&scopes[]=write_repository" | \
    grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$GITLAB_TOKEN" ]; then
    echo -e "${YELLOW}No se pudo crear un nuevo token, intentando usar la contraseña de root como token...${NC}"
    GITLAB_TOKEN=$GITLAB_ROOT_PASSWORD
fi

# Crear proyecto en GitLab
echo -e "${CYAN}==> Creando proyecto en GitLab...${NC}"
kubectl -n $GITLAB_NAMESPACE exec deploy/gitlab-webservice-default -- curl -s -k -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "$GITLAB_API/projects" \
    -d "name=$GITLAB_PROJECT_NAME&visibility=public" > /dev/null

# Clonar el repositorio actual y empujarlo a GitLab
echo -e "${CYAN}==> Preparando código para subirlo a GitLab...${NC}"
TMP_DIR=$(mktemp -d)
mkdir -p $TMP_DIR/dev

# Crear archivos YAML para la aplicación simple (versión 1)
cat > $TMP_DIR/dev/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iot-app
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iot-app
  template:
    metadata:
      labels:
        app: iot-app
    spec:
      containers:
      - name: iot-app
        image: wil42/playground:v1
        ports:
        - containerPort: 8888
---
apiVersion: v1
kind: Service
metadata:
  name: iot-app
  namespace: dev
spec:
  selector:
    app: iot-app
  ports:
  - port: 8888
    targetPort: 8888
    nodePort: 30080
  type: NodePort
EOF

# Configurar el repositorio local de Git
cd $TMP_DIR
git init
git config --local user.email "admin@example.com"
git config --local user.name "Admin"
git add .
git commit -m "Initial commit with app v1"

# Configurar GitLab como remoto y hacer push
GITLAB_REPO_URL="http://root:$GITLAB_TOKEN@gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/$GITLAB_PROJECT_NAME.git"

# Intentamos hacer push al repositorio de GitLab
git remote add origin "$GITLAB_REPO_URL"
if ! git push -u origin master; then
    echo -e "${YELLOW}No se pudo hacer push al repositorio de GitLab directamente.${NC}"
    echo -e "${YELLOW}Esta parte del proceso puede requerir pasos manuales adicionales.${NC}"
    echo -e "${YELLOW}Cuando GitLab esté completamente disponible, realiza estos pasos:${NC}"
    echo -e "${YELLOW}1. Crea un nuevo proyecto en GitLab llamado '$GITLAB_PROJECT_NAME'${NC}"
    echo -e "${YELLOW}2. Clona y configura tu repositorio como se muestra a continuación:${NC}"
    echo -e "${YELLOW}   git clone https://github.com/hanjelito/juan-gon-iot.git${NC}"
    echo -e "${YELLOW}   cd juan-gon-iot${NC}"
    echo -e "${YELLOW}   git remote add gitlab http://root:password@gitlab.local:8929/root/$GITLAB_PROJECT_NAME.git${NC}"
    echo -e "${YELLOW}   git push -u gitlab main${NC}"
fi

# Crear secret en ArgoCD para acceder a GitLab
echo -e "${CYAN}==> Configurando ArgoCD para usar GitLab...${NC}"
kubectl -n $ARGOCD_NAMESPACE create secret generic gitlab-credentials \
    --from-literal=url="$GITLAB_URL/root/$GITLAB_PROJECT_NAME.git" \
    --from-literal=username=root \
    --from-literal=password="$GITLAB_TOKEN" || handle_error "Error al crear secret para GitLab en ArgoCD"

# Actualizar la aplicación de ArgoCD para usar GitLab
cat > ../confs/argocd-gitlab-application.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-application-gitlab
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $GITLAB_URL/root/$GITLAB_PROJECT_NAME.git
    targetRevision: master
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

kubectl apply -f ../confs/argocd-gitlab-application.yaml || handle_error "Error al aplicar la Application de ArgoCD para GitLab"

echo -e "${GR}==> Integración de GitLab con ArgoCD configurada correctamente!${NC}"
echo -e "${GR}GitLab URL: $GITLAB_URL${NC}"
echo -e "${GR}Usuario: root${NC}"
echo -e "${GR}Contraseña: $GITLAB_ROOT_PASSWORD${NC}"
echo -e "${GR}Proyecto: $GITLAB_PROJECT_NAME${NC}"

echo -e "${CYAN}==> Instrucciones para cambiar de versión:${NC}"
echo -e "${GR}1. Accede a tu instancia de GitLab y busca el archivo deployment.yaml${NC}"
echo -e "${GR}2. Modifica la línea 'image: wil42/playground:v1' a 'image: wil42/playground:v2'${NC}"
echo -e "${GR}3. Haz commit y push de los cambios${NC}"
echo -e "${GR}4. ArgoCD detectará y aplicará los cambios automáticamente${NC}"
echo -e "${GR}5. Para verificar: curl http://localhost:8888${NC}"

echo -e "${YELLOW}Nota: La comunicación entre ArgoCD y GitLab puede tardar en establecerse por completo.${NC}"
echo -e "${YELLOW}      Si encuentras problemas, verifica los logs de ArgoCD para diagnosticar los errores.${NC}"