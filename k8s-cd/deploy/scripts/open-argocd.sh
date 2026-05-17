#!/bin/bash
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-8080}"

echo ">>> Getting ArgoCD admin password..."
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "--------------------------------------------------------"
echo ">>> ArgoCD URL: http://localhost:$LOCAL_PORT"
echo ">>> Username  : admin"
echo ">>> Password  : $PASSWORD"
echo "--------------------------------------------------------"
echo ">>> Press Ctrl+C to stop port-forward."

kubectl port-forward svc/argocd-server -n argocd "$LOCAL_PORT:80"
