#!/usr/bin/env bash
set -euo pipefail

REGISTRY=zot.test:3443
S3_ENDPOINT=http://garage.test:3900
AWS_ACCESS_KEY_ID=GK626462227e739523e7936f5f
AWS_SECRET_ACCESS_KEY=876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
AWS_DEFAULT_REGION=garage
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

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

# Upload kubectl to S3
aws s3 cp "blobs/kubectl-v1.20.0-linux-amd64" \
  "s3://ocm-examples/kubectl-v1.20.0-linux-amd64" \
  --endpoint-url "$S3_ENDPOINT" \
  --checksum-algorithm CRC32

# Upload vuln dir to S3
aws s3 cp "blobs/vuln-dir.tar.gz" \
  "s3://ocm-examples/vuln-dir.tar.gz" \
  --endpoint-url "$S3_ENDPOINT" \
  --checksum-algorithm CRC32

# Push vuln-dir to registry
oras push --registry-config .dockerconfig.json \
  "$REGISTRY/ocm-examples/vuln-dir:1.0.0" \
  "blobs/vuln-dir.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip"

# Push SBOM to registry
oras push --registry-config .dockerconfig.json \
  "$REGISTRY/ocm-examples/sbom-oras:1.0.0" \
  "blobs/sbom-vulnerable.cdx.json:application/vnd.cyclonedx+json"

# Push ocm components
ocm_add_cv --repository "$REGISTRY" --constructor components/1-zot-registry.yml
ocm_add_cv --repository "$REGISTRY" --constructor components/2-known-vulnerabilities.yml
ocm_add_cv --repository "$REGISTRY" --constructor components/3-scan-control.yml
ocm_add_cv --repository "$REGISTRY" --constructor components/9-all.yml
