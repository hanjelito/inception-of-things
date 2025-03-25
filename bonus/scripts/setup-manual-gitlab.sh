#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Variables configurables
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
GITLAB_URL="http://localhost:8929"
GITLAB_PROJECT_NAME="iot-application"

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

echo -e "${GR}==============================================================${NC}"
echo -e "${GR}      CONFIGURACIÓN MANUAL DE GITLAB E INTEGRACIÓN CON ARGOCD  ${NC}"
echo -e "${GR}==============================================================${NC}"

echo -e "${CYAN}Sigue estos pasos para configurar manualmente la integración:${NC}"

echo -e "${GR}Paso 1: Accede a GitLab${NC}"
echo -e "URL: $GITLAB_URL"
echo -e "Usuario: root"
echo -e "Contraseña: (la que se mostró durante la instalación)"

echo -e "\n${GR}Paso 2: Crea un nuevo proyecto en GitLab${NC}"
echo -e "1. En GitLab, ve a New Project > Create blank project"
echo -e "2. Nombre del proyecto: $GITLAB_PROJECT_NAME"
echo -e "3. Visibilidad: Public"
echo -e "4. Haz clic en 'Create project'"

echo -e "\n${GR}Paso 3: Prepara el repositorio local${NC}"
echo -e "Ejecuta estos comandos en una nueva terminal:"
echo -e "\n${CYAN}# Crea un directorio temporal para el repositorio${NC}"
echo -e "mkdir -p ~/iot-app-repo/dev"
echo -e "\n${CYAN}# Crea el archivo deployment.yaml${NC}"
echo -e "cat > ~/iot-app-repo/dev/deployment.yaml << EOF
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
EOF"

echo -e "\n${CYAN}# Inicializa el repositorio Git y haz el primer commit${NC}"
echo -e "cd ~/iot-app-repo"
echo -e "git init"
echo -e "git add ."
echo -e "git commit -m \"Initial commit with v1 app\""

echo -e "\n${CYAN}# Configura el repositorio remoto de GitLab${NC}"
echo -e "git remote add origin $GITLAB_URL/root/$GITLAB_PROJECT_NAME.git"

echo -e "\n${CYAN}# Opcional: Si GitLab te pide credenciales, configura Git para guardarlas${NC}"
echo -e "git config credential.helper store"

echo -e "\n${CYAN}# Sube los cambios a GitLab${NC}"
echo -e "git push -u origin master"

echo -e "\n${GR}Paso 4: Configura ArgoCD para usar el repositorio de GitLab${NC}"

echo -e "\n${CYAN}# Crea el namespace dev si no existe${NC}"
echo -e "kubectl create namespace $DEV_NAMESPACE"

echo -e "\n${CYAN}# Crea la aplicación en ArgoCD usando el GUI o este comando:${NC}"
echo -e "cat > ~/argocd-app.yaml << EOF
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
EOF"

echo -e "\nkubectl apply -f ~/argocd-app.yaml"

echo -e "\n${GR}Paso 5: Accede a la UI de ArgoCD para verificar${NC}"
echo -e "URL: https://localhost:8080 (deberás aceptar el certificado autofirmado)"
echo -e "Usuario: admin"
echo -e "Contraseña: Ejecuta este comando para obtenerla:"
echo -e "kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 --decode; echo"

echo -e "\n${GR}Paso 6: Para probar la integración, cambia la versión de la aplicación${NC}"
echo -e "1. En GitLab, edita el archivo dev/deployment.yaml"
echo -e "2. Cambia 'image: wil42/playground:v1' a 'image: wil42/playground:v2'"
echo -e "3. Guarda el archivo (Commit changes)"
echo -e "4. ArgoCD detectará el cambio y actualizará la aplicación automáticamente"
echo -e "5. Verifica la actualización con: curl http://localhost:8888"

echo -e "\n${GR}==============================================================${NC}"
echo -e "${GR}                ¡CONFIGURACIÓN COMPLETADA!                    ${NC}"
echo -e "${GR}==============================================================${NC}"