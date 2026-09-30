#!/usr/bin/env bash
set -euo pipefail

DIR=components/blobs

# nginx oci layout + as tar
skopeo copy --format oci --all \
  docker://docker.io/library/nginx:1.14.0 \
  oci:$DIR/nginx-oci-layout:1.14.0
tar -czf "$DIR/nginx-1.14.0.tar" -C "$DIR/nginx-oci-layout" .

# kubectl binary
curl -fsSL -o "$DIR/kubectl-v1.20.0-linux-amd64" \
  https://dl.k8s.io/release/v1.20.0/bin/linux/amd64/kubectl
chmod +x "$DIR/kubectl-v1.20.0-linux-amd64"

# vuln dir: with log4j
mkdir -p "$DIR/vuln-dir"
curl -fsSL -o "$DIR/vuln-dir/log4j-core-2.14.1.jar" \
  https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.14.1/log4j-core-2.14.1.jar
tar -czf "$DIR/vuln-dir.tar.gz" -C "$DIR" vuln-dir

echo "Downloads done"
