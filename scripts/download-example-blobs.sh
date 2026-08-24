#!/usr/bin/env bash
set -euo pipefail

BLOBS=examples/blobs

log() { echo "==> $*"; }
step() { echo "  -> $*"; }

mkdir -p "$BLOBS"

# ── nginx 1.14.0 (OCI layout tar for nginx-local input blob) ──────────────────
log "nginx 1.14.0"

step "copy to OCI layout dir (OCI format, all platforms)"
skopeo copy --format oci --all \
  docker://docker.io/library/nginx:1.14.0 \
  oci:$BLOBS/nginx-oci-layout:1.14.0

step "pack OCI layout dir as tar (nginx-local input blob)"
tar -czf "$BLOBS/nginx-1.14.0.tar" -C "$BLOBS/nginx-oci-layout" .

# ── kubectl v1.20.0 linux/amd64 ───────────────────────────────────────────────
log "kubectl v1.20.0"

if [[ ! -f "$BLOBS/kubectl-v1.20.0-linux-amd64" ]]; then
  step "download kubectl binary"
  curl -fsSL -o "$BLOBS/kubectl-v1.20.0-linux-amd64" \
    https://dl.k8s.io/release/v1.20.0/bin/linux/amd64/kubectl
else
  step "kubectl binary already downloaded, skipping"
fi

# ── vuln-dir: log4j-core 2.14.1 ──────────────────────────────────────────────
log "vuln-dir (log4j-core 2.14.1)"

if [[ ! -f "$BLOBS/log4j-core-2.14.1.jar" ]]; then
  step "download log4j-core-2.14.1.jar"
  curl -fsSL -o "$BLOBS/log4j-core-2.14.1.jar" \
    https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.14.1/log4j-core-2.14.1.jar
else
  step "log4j-core-2.14.1.jar already downloaded, skipping"
fi

step "pack into vuln-dir tarball"
mkdir -p "$BLOBS/vuln-dir"
cp "$BLOBS/log4j-core-2.14.1.jar" "$BLOBS/vuln-dir/"
tar -czf "$BLOBS/vuln-dir.tar.gz" -C "$BLOBS" vuln-dir

log "downloads done"
