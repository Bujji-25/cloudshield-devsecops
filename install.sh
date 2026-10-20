
#!/bin/bash
set -euo pipefail

# CloudShield DevSecOps - Ubuntu EC2 setup
# Run with: sudo bash install.sh

if [ "$EUID" -ne 0 ]; then
  echo "Run this script using sudo."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "=== Updating packages ==="
apt-get update
apt-get install -y ca-certificates curl gnupg unzip wget git jq

echo "=== Installing Java 11 and Maven ==="
apt-get install -y openjdk-11-jdk maven

echo "=== Installing Docker ==="
apt-get install -y docker.io
systemctl enable --now docker

echo "=== Installing AWS CLI v2 ==="
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64) AWS_ARCH="x86_64" ;;
  arm64) AWS_ARCH="aarch64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TMP_DIR=$(mktemp -d)
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
  -o "$TMP_DIR/awscliv2.zip"
unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"

if command -v aws >/dev/null 2>&1; then
  "$TMP_DIR/aws/install" --update
else
  "$TMP_DIR/aws/install"
fi
rm -rf "$TMP_DIR"

echo "=== Installing kubectl ==="
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64) K8S_ARCH="amd64" ;;
  arm64) K8S_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl" \
  -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

echo "=== Installing Helm ==="
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== Installing Terraform ==="
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
chmod 0644 /etc/apt/keyrings/hashicorp-archive-keyring.gpg

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install -y terraform

echo "=== Installing Trivy ==="
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor --yes -o /etc/apt/keyrings/trivy.gpg
chmod 0644 /etc/apt/keyrings/trivy.gpg

echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  > /etc/apt/sources.list.d/trivy.list

apt-get update
apt-get install -y trivy

echo "=== Installing SonarQube Community using Docker ==="
# Keep SonarQube data in persistent Docker volumes.
docker volume create sonarqube_data
docker volume create sonarqube_extensions
docker volume create sonarqube_logs

# Reuse the existing container if this script is run again.
if ! docker ps -a --format '{{.Names}}' | grep -qx sonarqube; then
  docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    -p 9000:9000 \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    -v sonarqube_logs:/opt/sonarqube/logs \
    sonarqube:community
else
  docker start sonarqube
fi

echo "=== Adding Ubuntu user to Docker group ==="
if id ubuntu >/dev/null 2>&1; then
  usermod -aG docker ubuntu
fi

echo "=== Checking installed tools ==="
java -version
mvn -version
git --version
docker --version
aws --version
kubectl version --client
helm version
terraform -version
trivy --version

echo
echo "Installation completed."
echo "SonarQube container: sonarqube"
echo "SonarQube default port: 9000"
echo "Configure AWS access with an EC2 IAM role; do not hardcode access keys."
echo "Prometheus and Grafana will be installed separately into EKS using Helm."
echo "Ensure SonarQube port 9000 is not publicly open to everyone."
