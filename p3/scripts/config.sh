#!/bin/sh

# Define algunas funciones de utilidad para manejar errores
exit_on_failure() {
    echo "Error: $1"
    exit 1
}

check_command() {
    if ! command -v $1 &> /dev/null
    then
        exit_on_failure "$1 could not be found, please install $1"
    fi
}

# Asegurarse de que los comandos necesarios estén instalados
check_command k3d
check_command kubectl
check_command argocd

# Crear el cluster
k3d cluster create mi-cluster || exit_on_failure "Failed to create k3d cluster"

# Obtener información del cluster
kubectl cluster-info || exit_on_failure "Failed to get cluster info"

# Crear namespaces
kubectl create namespace argocd || exit_on_failure "Failed to create namespace argocd"
kubectl create namespace dev || exit_on_failure "Failed to create namespace dev"

# Obtener namespaces
kubectl get namespace || exit_on_failure "Failed to get namespaces"

# Instalar Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || exit_on_failure "Failed to install Argo CD"

# Esperar a que el servicio de Argo CD esté listo
echo "Waiting for argocd-server to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s || exit_on_failure "Argo CD server is not ready"

# Obtener la contraseña inicial del admin de ArgoCD
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PWD"

# Esperar que el usuario cambie la contraseña manualmente, ya que argocd login y argocd account update-password necesitan interacción
echo "Please login to ArgoCD UI at localhost:8080 using username 'admin' and the password above. Then, update the password as prompted."
read -p "Press enter once you have updated the ArgoCD password..."

# Agregar el repositorio a ArgoCD (este paso y los siguientes podrían requerir autenticación, dependiendo de tu configuración)
argocd repo add https://github.com/hanjelito/juan-gon-iot || exit_on_failure "Failed to add repository to ArgoCD"

# Crear la aplicación en ArgoCD
argocd app create mi-aplicacion \
  --repo https://github.com/hanjelito/juan-gon-iot \
  --path manifest \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev || exit_on_failure "Failed to create ArgoCD application"

# Sincronizar la aplicación
argocd app sync mi-aplicacion || exit_on_failure "Failed to sync ArgoCD application"

# Verificar los logs del servidor de ArgoCD
kubectl logs -n argocd $(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name) || exit_on_failure "Failed to get ArgoCD server logs"

# Obtener los pods en el namespace 'dev'
kubectl get pods -n dev || exit_on_failure "Failed to get pods in 'dev' namespace"

# La parte de kubectl port-forward se deja generalmente para ejecución manual, ya que crea un proceso de escucha
echo "To forward a pod port to your local machine, use:"
echo "kubectl port-forward <nombre-del-pod> 8888:8888 -n dev"
