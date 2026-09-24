#!/usr/bin/env bash
set -euo pipefail

GARAGE_CONTAINER=ocm-garage
AWS_ACCESS_KEY_ID=GK626462227e739523e7936f5f
AWS_SECRET_ACCESS_KEY=876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
AWS_DEFAULT_REGION=garage
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

# wait for garage to init
until docker exec "$GARAGE_CONTAINER" /garage status > /dev/null 2>&1; do sleep 1; done

# create garage layout, buckets and permissions
NODE_ID=$(docker exec "$GARAGE_CONTAINER" /garage status 2>/dev/null | awk '/NO ROLE|[0-9a-f]{16}/{print $1; exit}')
if [[ -n "$NODE_ID" ]]; then
  docker exec "$GARAGE_CONTAINER" /garage layout assign -z dc1 -c 1G "$NODE_ID" 2>/dev/null || true
  docker exec "$GARAGE_CONTAINER" /garage layout apply --version 1 2>/dev/null || true
fi
docker exec "$GARAGE_CONTAINER" /garage bucket create ocm-examples 2>/dev/null || true
if ! docker exec "$GARAGE_CONTAINER" /garage key info GK626462227e739523e7936f5f > /dev/null 2>&1; then
  docker exec "$GARAGE_CONTAINER" /garage key import --yes -n ocm-key GK626462227e739523e7936f5f 876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
fi
docker exec "$GARAGE_CONTAINER" /garage bucket allow --read --write --key GK626462227e739523e7936f5f ocm-examples 2>/dev/null || true
