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

# Función para esperar a que los recursos estén listos
wait_for_resource() {
    local namespace=$1
    local resource_type=$2
    local resource_name=$3
    local condition=$4
    local timeout=$5
    local count=0
    local max_attempts=30
    local sleep_time=10

    echo -e "${YELLOW}Waiting for $resource_type/$resource_name in namespace $namespace to be $condition...${NC}"
    
    while [ $count -lt $max_attempts ]; do
        if kubectl get $resource_type $resource_name -n $namespace &>/dev/null; then
            if [ "$condition" == "created" ]; then
                echo -e "${GR}$resource_type/$resource_name in namespace $namespace is created.${NC}"
                return 0
            elif kubectl wait --for=$condition $resource_type/$resource_name -n $namespace --timeout=$timeout &>/dev/null; then
                echo -e "${GR}$resource_type/$resource_name in namespace $namespace is $condition.${NC}"
                return 0
            fi
        fi
        echo "Attempt $((count+1))/$max_attempts. Waiting $sleep_time seconds..."
        sleep $sleep_time
        count=$((count+1))
    done

    handle_error "$resource_type/$resource_name in namespace $namespace not $condition after $(($max_attempts * $sleep_time)) seconds"
}

# Comprobar si k3d está instalado
if ! command -v k3d &> /dev/null; then
    handle_error "k3d no está instalado. Ejecuta install-tools.sh primero."
fi

echo -e "${CYAN}==> Deleting existing k3d cluster (if any)...${NC}"
k3d cluster delete $CLUSTER_NAME &>/dev/null || true

echo -e "${CYAN}==> Creating k3d cluster...${NC}"
k3d cluster create $CLUSTER_NAME -p "8888:30080@loadbalancer" || handle_error "Failed to create k3d cluster"

echo -e "${CYAN}==> Verifying cluster is up and running...${NC}"
kubectl cluster-info || handle_error "Kubernetes cluster is not running"

echo -e "${CYAN}==> Creating namespace for ArgoCD...${NC}"
kubectl create namespace $ARGOCD_NAMESPACE || handle_error "Failed to create ArgoCD namespace"

echo -e "${CYAN}==> Installing ArgoCD in the k3d cluster...${NC}"
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || handle_error "Failed to install ArgoCD"

echo -e "${CYAN}==> Waiting for ArgoCD pods to be ready...${NC}"
# Wait for the server deployment to be available
wait_for_resource $ARGOCD_NAMESPACE "deployment" "argocd-server" "condition=Available" "5m"
# Wait for other critical components
for component in "argocd-repo-server" "argocd-application-controller" "argocd-dex-server"; do
    wait_for_resource $ARGOCD_NAMESPACE "deployment" $component "condition=Available" "5m"
done

echo -e "${CYAN}==> Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $ARGOCD_NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$ARGOCD_PASSWORD" ]; then
    handle_error "Failed to get ArgoCD password"
fi
echo -e "${GR}ArgoCD Username: admin${NC}"
echo -e "${GR}ArgoCD Password: $ARGOCD_PASSWORD${NC}"

echo -e "${CYAN}==> Creating namespace for development...${NC}"
kubectl create namespace $DEV_NAMESPACE || handle_error "Failed to create dev namespace"

echo -e "${CYAN}==> Creating ArgoCD Application...${NC}"
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

echo -e "${CYAN}==> Applying ArgoCD Application...${NC}"
kubectl apply -f ../confs/application.yaml || handle_error "Failed to apply Application CRD"

echo -e "${CYAN}==> Waiting for application to be created in dev namespace...${NC}"
sleep 20  # Give some time for the Application to be processed

# Check if there are pods in the dev namespace
echo -e "${CYAN}==> Waiting for pods in dev namespace...${NC}"
attempt=1
max_attempts=30
while [ $attempt -le $max_attempts ]; do
    POD_COUNT=$(kubectl get pods -n $DEV_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$POD_COUNT" -gt 0 ]; then
        echo -e "${GR}Pods detected in dev namespace.${NC}"
        break
    fi
    echo "Attempt $attempt/$max_attempts. Waiting for pods in dev namespace..."
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${YELLOW}Warning: No pods detected in dev namespace after $(($max_attempts * 10)) seconds.${NC}"
    echo -e "${YELLOW}This could be because the repository doesn't have the correct configuration or ArgoCD couldn't sync.${NC}"
    echo -e "${YELLOW}Continuing with setup...${NC}"
else
    # Wait for pods to be ready
    echo -e "${CYAN}==> Waiting for pods in dev namespace to be ready...${NC}"
    kubectl wait --for=condition=Ready pods --all -n $DEV_NAMESPACE --timeout=5m || echo -e "${YELLOW}Warning: Not all pods are ready. Check their status.${NC}"
fi

echo -e "${CYAN}==> Starting port forwarding for ArgoCD UI...${NC}"
# Start port forwarding in the background and save the PID
kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443 > /dev/null 2>&1 &
ARGOCD_PID=$!
echo -e "${GR}ArgoCD UI is available at: https://localhost:8080${NC}"
echo -e "${YELLOW}(You'll need to accept the self-signed certificate warning)${NC}"

echo -e "${CYAN}==> Checking application availability...${NC}"
echo -e "${GR}Your application should be available at: http://localhost:8888${NC}"
echo -e "${GR}To test the application, run: curl http://localhost:8888${NC}"

echo -e "${CYAN}==> Instructions for version update:${NC}"
echo -e "${GR}1. Go to your GitHub repository: $GITHUB_REPO${NC}"
echo -e "${GR}2. Update the image tag from 'v1' to 'v2' in the deployment YAML${NC}"
echo -e "${GR}3. Commit and push the changes${NC}"
echo -e "${GR}4. ArgoCD will automatically detect and apply the changes${NC}"
echo -e "${GR}5. To verify the update, run: curl http://localhost:8888${NC}"

echo -e "${GR}Setup complete! Keep this terminal open to maintain port forwarding.${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop port forwarding when done.${NC}"

# Wait for Ctrl+C to stop port forwarding
wait $ARGOCD_PID
