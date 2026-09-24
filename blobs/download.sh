#!/usr/bin/env bash
set -euo pipefail

# nginx oci layout + as tar
skopeo copy --format oci --all \
  docker://docker.io/library/nginx:1.14.0 \
  oci:blobs/nginx-oci-layout:1.14.0
tar -czf "blobs/nginx-1.14.0.tar" -C "blobs/nginx-oci-layout" .

# kubectl binary
curl -fsSL -o "blobs/kubectl-v1.20.0-linux-amd64" \
  https://dl.k8s.io/release/v1.20.0/bin/linux/amd64/kubectl
chmod +x "blobs/kubectl-v1.20.0-linux-amd64"

# vuln dir: with log4j
mkdir -p "blobs/vuln-dir"
curl -fsSL -o "blobs/vuln-dir/log4j-core-2.14.1.jar" \
  https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.14.1/log4j-core-2.14.1.jar
tar -czf "blobs/vuln-dir.tar.gz" -C "blobs" vuln-dir

echo "Downloads done"
