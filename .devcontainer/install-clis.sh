set -euo pipefail

ARCH="$(dpkg --print-architecture)"  # amd64 or arm64

# skopeo, mkcert & podman
sudo apt-get update -qq
sudo apt-get install -y -qq --no-install-recommends skopeo mkcert

# oras
ORAS_VERSION="1.3.4"
ORAS_ARCH="${ARCH}"
curl -sSfL "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_${ORAS_ARCH}.tar.gz" \
  | sudo tar -xz -C /usr/local/bin oras

# AWS CLI v2
AWS_ARCH="$([ "$ARCH" = arm64 ] && echo aarch64 || echo x86_64)"
curl -sSfL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/awscliv2
sudo /tmp/awscliv2/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli
rm -rf /tmp/awscliv2.zip /tmp/awscliv2

# OCM CLI
wget -qO- https://ocm.software/install-cli.sh | OCM_VERSION=0.16 bash

# Claude Code
npm install -g @anthropic-ai/claude-code

# Update CA trust
sudo update-ca-certificates
