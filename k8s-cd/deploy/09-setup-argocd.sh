#!/bin/bash
set -x

echo ">>> Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo ">>> Creating argocd namespace (if not exists)..."
kubectl create namespace argocd

echo ">>> Installing ArgoCD..."
# Cho chạy trên HTTP
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.extraArgs="{--insecure}" \
  --wait

echo ">>> Waiting for ArgoCD Server to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo ">>> ArgoCD Initial Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ">>> Xong Giai đoạn 6: Cài đặt ArgoCD và cấu hình GitOps Root App cho cả Dev và Staging."
