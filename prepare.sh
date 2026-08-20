#!/usr/bin/env bash
set -euo pipefail

BLOBS=examples/blobs
ZOT=localhost:10500
GARAGE=localhost:10900
BUCKET=ocm-examples
AWS_ACCESS_KEY_ID=GK626462227e739523e7936f5f
AWS_SECRET_ACCESS_KEY=876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
AWS_DEFAULT_REGION=garage
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

ZOT_AUTH_CONFIG=.dockerconfig.json

log() { echo "==> $*"; }
step() { echo "  -> $*"; }

# detect container runtime
if command -v podman &>/dev/null; then
  CONTAINER_RUNTIME=podman
elif command -v docker &>/dev/null; then
  CONTAINER_RUNTIME=docker
else
  echo "ERROR: neither podman nor docker found" >&2; exit 1
fi

# ── garage init (idempotent) ──────────────────────────────────────────────────
log "initializing garage"
GARAGE_CONTAINER=ocm-garage

step "waiting for garage to be ready"
until $CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage status > /dev/null 2>&1; do sleep 1; done

NODE_ID=$($CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage status 2>/dev/null | awk '/NO ROLE|[0-9a-f]{16}/{print $1; exit}')
if [[ -n "$NODE_ID" ]]; then
  step "node ID: $NODE_ID — assigning layout"
  $CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage layout assign -z dc1 -c 1G "$NODE_ID" 2>/dev/null || true
  $CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage layout apply --version 1 2>/dev/null || true
else
  step "layout already applied"
fi
$CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage bucket create ocm-examples 2>/dev/null || true
if ! $CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage key info GK626462227e739523e7936f5f > /dev/null 2>&1; then
  $CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage key import --yes -n ocm-key GK626462227e739523e7936f5f 876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
fi
$CONTAINER_RUNTIME exec "$GARAGE_CONTAINER" /garage bucket allow --read --write --key GK626462227e739523e7936f5f ocm-examples 2>/dev/null || true
step "garage init done"

# ── authenticate to local zot ─────────────────────────────────────────────────
log "authenticating to zot"
mkdir -p .config
oras login "$ZOT" --registry-config "$ZOT_AUTH_CONFIG" \
  --username ocmuser --password ocmpassword --plain-http

# ── nginx 1.14.0 (OCI layout tar for nginx-local input blob) ──────────────────
# CVE-2019-9511, CVE-2019-9513 + dozens of Debian base CVEs
log "nginx 1.14.0"

step "copy to OCI layout dir (OCI format, all platforms)"
skopeo copy --format oci --all \
  docker://docker.io/library/nginx:1.14.0 \
  oci:$BLOBS/nginx-oci-layout:1.14.0

step "pack OCI layout dir as tar (nginx-local input blob)"
tar -czf "$BLOBS/nginx-1.14.0.tar" -C "$BLOBS/nginx-oci-layout" .

# ── kubectl v1.20.0 linux/amd64 ───────────────────────────────────────────────
# CVE-2021-25741 (symlink path traversal)
log "kubectl v1.20.0"

if [[ ! -f "$BLOBS/kubectl-v1.20.0-linux-amd64" ]]; then
  step "download kubectl binary"
  curl -fsSL -o "$BLOBS/kubectl-v1.20.0-linux-amd64" \
    https://dl.k8s.io/release/v1.20.0/bin/linux/amd64/kubectl
else
  step "kubectl binary already downloaded, skipping"
fi

step "upload to garage S3 (kubectl-s3)"
aws s3 cp "$BLOBS/kubectl-v1.20.0-linux-amd64" \
  "s3://$BUCKET/kubectl-v1.20.0-linux-amd64" \
  --endpoint-url "http://$GARAGE" \
  --checksum-algorithm CRC32

# ── vuln-dir: log4j-core 2.14.1 ──────────────────────────────────────────────
# CVE-2021-44228 (Log4Shell)
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

step "push to local zot (vuln-dir-oras)"
oras push --registry-config "$ZOT_AUTH_CONFIG" --plain-http \
  "$ZOT/ocm-examples/vuln-dir:1.0.0" \
  "$BLOBS/vuln-dir.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip"

step "upload to garage S3 (vuln-dir-s3)"
aws s3 cp "$BLOBS/vuln-dir.tar.gz" \
  "s3://$BUCKET/vuln-dir.tar.gz" \
  --endpoint-url "http://$GARAGE" \
  --checksum-algorithm CRC32

# ── SBOM (CycloneDX) ──────────────────────────────────────────────────────────
# log4j-core 2.14.1, lodash 4.17.15, express 4.17.1
# CVE-2021-44228, CVE-2021-23337, CVE-2022-24999
log "sbom-vulnerable.cdx.json"

step "push to local zot (sbom-oras)"
oras push --registry-config "$ZOT_AUTH_CONFIG" --plain-http \
  "$ZOT/ocm-examples/sbom-oras:1.0.0" \
  "$BLOBS/sbom-vulnerable.cdx.json:application/vnd.cyclonedx+json"

# ── OCM components → local zot ───────────────────────────────────────────────
log "pushing OCM components to local zot registry"

step "adding 1-zot-registry"
ocm add cv --repository "oci::http://$ZOT" --constructor examples/1-zot-registry.yml --config .ocmconfig

step "adding 2-known-vulnerabilities"
ocm add cv --skip-reference-digest-processing --repository "oci::http://$ZOT" --constructor examples/2-known-vulnerabilities.yml --config .ocmconfig

log "done — components in $ZOT:"
ocm get cv --repo "oci::http://$ZOT"
