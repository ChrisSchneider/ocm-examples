#!/usr/bin/env bash
set -euo pipefail

GARAGE_CONTAINER=ocm-garage
AWS_ACCESS_KEY_ID=GK626462227e739523e7936f5f
AWS_SECRET_ACCESS_KEY=876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
AWS_DEFAULT_REGION=garage
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

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
oras login localhost:10500 --registry-config .dockerconfig.json \
  --username ocmuser --password ocmpassword \
  --ca-file "$(mkcert -CAROOT)/rootCA.pem"

log "local registries ready"
