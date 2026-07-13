#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="${IMAGE_TAG:?Set IMAGE_TAG to the ACR image tag to deploy}"
MIGRATION_JOB="lago-migrate-${IMAGE_TAG}"
export API_IMAGE="${API_IMAGE:-lincanvas-registry.cn-hangzhou.cr.aliyuncs.com/lincanvas/lago-api:${IMAGE_TAG}}"
export FRONT_IMAGE="${FRONT_IMAGE:-lincanvas-registry.cn-hangzhou.cr.aliyuncs.com/lincanvas/lago-front:${IMAGE_TAG}}"

for secret in lago-runtime lago-connections; do
  kubectl get secret "$secret" --namespace lago >/dev/null
done

for config_map in lago-env lago-front-env; do
  kubectl get configmap "$config_map" --namespace lago >/dev/null
done

kubectl apply -f "$SCRIPT_DIR/base.yaml"

envsubst < "$SCRIPT_DIR/migrate.yaml" | kubectl apply -f -
kubectl wait --namespace lago --for=condition=complete "job/$MIGRATION_JOB" --timeout=20m

envsubst < "$SCRIPT_DIR/apps.yaml" | kubectl apply -f -
kubectl rollout status deployment/lago-api --namespace lago --timeout=15m
kubectl rollout status deployment/lago-worker --namespace lago --timeout=15m
kubectl rollout status deployment/lago-clock --namespace lago --timeout=15m
kubectl rollout status deployment/lago-front --namespace lago --timeout=15m
kubectl rollout status deployment/lago-pdf --namespace lago --timeout=15m
