#!/bin/bash
GR='\033[0;32m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
RED='\033[0;31m'

# Función para manejar errores
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

echo "----------------- ${GR}Installing Docker${NC} -------------------------------"
echo "${CYAN}==> Updating apt packages...${NC}"
sudo apt-get update || handle_error "Failed to update apt"
sudo apt-get install -y ca-certificates curl gnupg lsb-release || handle_error "Failed to install prerequisites"

echo "${CYAN}==> Installing Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh || handle_error "Failed to download Docker installation script"
sudo sh get-docker.sh || handle_error "Failed to install Docker"
sudo usermod -aG docker $USER || handle_error "Failed to add user to docker group"

echo "----------------- ${GR}Installing Kubectl${NC} -------------------------------"
if [ -f /usr/local/bin/kubectl ]; then
    sudo rm /usr/local/bin/kubectl
fi
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || handle_error "Failed to download kubectl"
chmod +x ./kubectl || handle_error "Failed to make kubectl executable"
sudo mv ./kubectl /usr/local/bin/kubectl || handle_error "Failed to install kubectl"

echo "----------------- ${GR}Installing k3d${NC} -------------------------------"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash || handle_error "Failed to install k3d"

echo -e "${GR}All tools installed successfully!${NC}"