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
echo "${CYAN}==> Removing older versions...${NC}"
# Uninstall any older versions before attempting to install a new version
sudo apt-get -y remove docker docker-engine docker.io containerd runc || handle_error "Failed to remove older Docker versions"

echo "${CYAN}==> Updating apt to the newer versions...${NC}"
# Update apt to the newer versions, and install the required packages to allow apt to use a repository over HTTPS
sudo apt-get update || handle_error "Failed to update apt"
sudo apt-get install -y ca-certificates curl gnupg lsb-release || handle_error "Failed to install prerequisites"

echo "${CYAN}==> Adding Docker's official GPG key...${NC}"
# Add Docker's official GPG key
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || handle_error "Failed to add Docker GPG key"

echo "${CYAN}==> Setting up the repository...${NC}"
# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || handle_error "Failed to set up Docker repository"

echo "${CYAN}==> Granting read permission for the Docker public key...${NC}"
# Grant read permission for the Docker public key
sudo chmod a+r /etc/apt/keyrings/docker.gpg || handle_error "Failed to set permissions for Docker key"

echo "${CYAN}==> Updating the repo & installing Docker Engine...${NC}"
# Update the repo
sudo apt-get update || handle_error "Failed to update apt after adding Docker repository"
# Install Docker Engine, containerd, and Docker Compose
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "Failed to install Docker"
# Verify that the Docker Engine installation is successful by running the hello-world image
sudo docker run hello-world || handle_error "Docker test failed"

echo "----------------- ${GR}Installing Kubectl${NC} -------------------------------"
if [ -f /usr/local/bin/kubectl ]; then
    sudo rm /usr/local/bin/kubectl || handle_error "Failed to remove existing kubectl"
fi
curl -LO "https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl" || handle_error "Failed to download kubectl"
chmod +x ./kubectl || handle_error "Failed to make kubectl executable"
sudo mv ./kubectl /usr/local/bin/kubectl || handle_error "Failed to install kubectl"

echo "----------------- ${GR}Installing k3d${NC} -------------------------------"
if command -v k3d &> /dev/null; then
    sudo rm $(which k3d) || handle_error "Failed to remove existing k3d"
fi
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash || handle_error "Failed to install k3d"

echo -e "${GR}All tools installed successfully!${NC}"