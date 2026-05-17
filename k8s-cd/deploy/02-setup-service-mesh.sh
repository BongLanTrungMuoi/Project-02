#!/bin/bash
set -euo pipefail
set -x

MESH_NAMESPACES="${YAS_MESH_NAMESPACES:-yas-dev yas-staging}"

echo ">>> Creating mesh namespace(s) $MESH_NAMESPACES (if not exists)..."
for ns in $MESH_NAMESPACES; do
  kubectl create namespace "$ns" || true
done

echo ">>> Adding Istio Helm repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

echo ">>> Installing Istio Base..."
helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait

echo ">>> Installing Istiod..."
helm upgrade --install istiod istio/istiod -n istio-system --wait

echo ">>> Installing Kiali Server for Topology visualization..."
helm repo add kiali https://kiali.org/helm-charts
helm repo update
# Installing latest stable Kiali
helm upgrade --install kiali-server kiali/kiali-server \
  --namespace istio-system \
  --set auth.strategy="anonymous" \
  --set external_services.prometheus.url="http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090" \
  --wait

echo ">>> Enabling automatic sidecar injection for mesh namespace(s): $MESH_NAMESPACES..."
for ns in $MESH_NAMESPACES; do
  kubectl label namespace "$ns" istio-injection=enabled --overwrite
done

echo ">>> Injecting Istio sidecar into 'ingress-nginx' namespace (to support STRICT mTLS entry)..."
kubectl label namespace ingress-nginx istio-injection=enabled --overwrite
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

echo ">>> Applying Istio configurations (mTLS, Destination Rules, Auth Policies) via Loop..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read configuration value from cluster-config.yaml file to construct default hosts.
BASE_DOMAIN=$(yq -r '.domain' "$SCRIPT_DIR/cluster-config.yaml")

ISTIO_CONFIGS=("ingress-mtls.yaml" "mtls.yaml" "destination-rule.yaml" "keycloak-internal-dns.yaml" "telemetry-monitor.yaml" "virtual-service-retry-template.yaml" "auth-policy.yaml")

for ns in $MESH_NAMESPACES; do
  NS_DOMAIN="$BASE_DOMAIN"
  NS_ENV_TAG="${ENV_TAG:-}"

  if [ "$ns" = "yas-dev" ]; then
    NS_DOMAIN="${DEV_DOMAIN:-$BASE_DOMAIN}"
    NS_ENV_TAG="${DEV_ENV_TAG:-dev-13}"
  elif [ "$ns" = "yas-staging" ]; then
    NS_DOMAIN="${STAGING_DOMAIN:-yas.staging.local}"
    NS_ENV_TAG="${STAGING_ENV_TAG:-staging}"
  fi

  if [ -n "$NS_ENV_TAG" ]; then
    IDENTITY_HOST="identity-$NS_ENV_TAG.$NS_DOMAIN"
  else
    IDENTITY_HOST="identity.$NS_DOMAIN"
  fi

  DOMAIN="$NS_DOMAIN"
  export NAMESPACE="$ns" DOMAIN IDENTITY_HOST
  echo ">>> Applying Istio configurations for namespace '$NAMESPACE'..."
  for config in "${ISTIO_CONFIGS[@]}"; do
    if [ -s "$SCRIPT_DIR/istio/$config" ]; then
        echo ">>> Applying $config..."
        envsubst < "$SCRIPT_DIR/istio/$config" | kubectl apply -f -
    else
        echo ">>> Skipping $config (empty or not found)."
    fi
  done
done

echo ">>> Xong Giai đoạn 2: Cài đặt Service Mesh (Istio), Kiali và áp dụng Policies."
sleep 50
