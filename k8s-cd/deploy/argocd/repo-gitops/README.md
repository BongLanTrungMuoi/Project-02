# yas-gitops

This app-of-apps chart is the GitOps replacement for the old manual deploy phases:

- `save-03-setup-data-layer.sh`
- `save-04-deploy-apps.sh`

Bootstrap order:

```bash
cd k8s-cd/deploy
./01-setup-operators.sh
./02-setup-service-mesh.sh
./03-setup-argocd.sh
```

Argo CD then deploys the data layer and application layer from this chart.
