#!/usr/bin/env bash
set -euo pipefail

BLOBS=examples/blobs
REGISTRY=${REGISTRY:-registry.internal:10500}
S3_URL=${S3_URL:-http://registry.internal:10900}
BUCKET=${BUCKET:-ocm-examples}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-GK626462227e739523e7936f5f}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-garage}
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
REGISTRY_AUTH_CONFIG=.dockerconfig.json

log() { echo "==> $*"; }
step() { echo "  -> $*"; }

ocm_add_cv() {
  local out
  if ! out=$(ocm add cv "$@" 2>&1); then
    if echo "$out" | grep -q "already exists in target repository"; then
      echo "$out"
    else
      echo "$out" >&2
      return 1
    fi
  else
    echo "$out"
  fi
}

# ── kubectl → S3 ──────────────────────────────────────────────────────────────
#log "kubectl v1.20.0"

#step "upload to S3 (kubectl-s3)"
#aws s3 cp "$BLOBS/kubectl-v1.20.0-linux-amd64" \
#  "s3://$BUCKET/kubectl-v1.20.0-linux-amd64" \
#  --endpoint-url "$S3_URL" \
#  --checksum-algorithm CRC32

# ── vuln-dir → registry + S3 ─────────────────────────────────────────────────
log "vuln-dir"

step "push to registry (vuln-dir-oras)"
oras push --registry-config "$REGISTRY_AUTH_CONFIG" \
  "$REGISTRY/ocm-examples/vuln-dir:1.0.0" \
  "$BLOBS/vuln-dir.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip"

#step "upload to S3 (vuln-dir-s3)"
#aws s3 cp "$BLOBS/vuln-dir.tar.gz" \
#  "s3://$BUCKET/vuln-dir.tar.gz" \
#  --endpoint-url "$S3_URL" \
#  --checksum-algorithm CRC32

# ── SBOM → registry ───────────────────────────────────────────────────────────
log "sbom-vulnerable.cdx.json"

step "push to registry (sbom-oras)"
oras push --registry-config "$REGISTRY_AUTH_CONFIG" \
  "$REGISTRY/ocm-examples/sbom-oras:1.0.0" \
  "$BLOBS/sbom-vulnerable.cdx.json:application/vnd.cyclonedx+json"

# ── OCM components → registry ─────────────────────────────────────────────────
log "pushing OCM components to $REGISTRY"

step "adding 1-zot-registry"
ocm_add_cv --repository "$REGISTRY" --constructor examples/1-zot-registry.yml

step "adding 2-known-vulnerabilities"
ocm_add_cv --skip-reference-digest-processing --repository "$REGISTRY" --constructor examples/2-known-vulnerabilities.yml --config .ocmconfig

step "adding 3-scan-control-labels"
ocm_add_cv --repository "$REGISTRY" --constructor examples/3-scan-control-labels.yml

step "adding 9-all"
ocm_add_cv --repository "$REGISTRY" --constructor examples/9-all.yml

log "done — components in $REGISTRY:"
ocm get cv --repository "$REGISTRY"
