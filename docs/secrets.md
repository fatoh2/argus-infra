# Secret Management

Argus uses **External Secrets Operator (ESO)** with **Doppler** as the backend for managing Kubernetes secrets.

## Architecture

```
Doppler (source of truth)
    │
    ▼
External Secrets Operator (syncs secrets into the cluster)
    │
    ▼
Kubernetes Secrets (consumed by pods)
```

- **Doppler** is the single source of truth for all secrets (API keys, database URLs, tokens).
- **External Secrets Operator** runs in the `external-secrets-operator` namespace and syncs secrets from Doppler into Kubernetes `Secret` objects.
- **SecretStore** resources define how ESO authenticates to Doppler.
- **ExternalSecret** resources define which Doppler secrets to sync and where to store them.

## Components

| Component | Namespace | Description |
|-----------|-----------|-------------|
| External Secrets Operator | `external-secrets-operator` | Helm chart deployed via Flux HelmRelease |
| Doppler Auth Secret | `external-secrets-operator` | Contains the Doppler service token |
| SecretStore (doppler-backend) | `default` | Configures ESO to use Doppler as provider |
| ExternalSecret (example) | `default` | Example showing how to sync secrets |

## Setup

### 1. Deploy External Secrets Operator

The operator is deployed via ArgoCD (app-of-apps pattern). The ArgoCD application at `k8s/argocd/apps/external-secrets.yaml` points to `k8s/external-secrets/`, which contains:

- `helm-repository.yaml` — Flux HelmRepository pointing to `https://charts.external-secrets.io`
- `helm-release.yaml` — Flux HelmRelease deploying ESO with CRDs
- `kustomization.yaml` — Kustomize resources list

ArgoCD syncs this automatically. To trigger a manual sync:

```bash
argocd app sync external-secrets
```

### 2. Configure Doppler Authentication

1. Create a Doppler service token:
   - Go to [Doppler Dashboard](https://dashboard.doppler.com) → your project → config → **Tokens**
   - Create a **Service Token** with read access

2. Update the Doppler auth secret:

```bash
kubectl create secret generic doppler-auth \
  --namespace external-secrets-operator \
  --from-literal=token='dp.st.your_token_here' \
  --dry-run=client -o yaml | kubectl apply -f -
```

> **Never** commit the actual token to the repository. The file `k8s/external-secrets/doppler-auth-secret.yaml` contains a placeholder only.

### 3. Verify the SecretStore

```bash
kubectl get secretstore -n default doppler-backend -o jsonpath='{.status.conditions[0].type}'
# Should output: Ready
```

### 4. Create ExternalSecrets

Define an `ExternalSecret` resource to sync secrets from Doppler:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secret
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: doppler-backend
    kind: SecretStore
  target:
    name: my-app-secret
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: DATABASE_URL
    - secretKey: API_KEY
      remoteRef:
        key: API_KEY
```

The resulting Kubernetes `Secret` will be named `my-app-secret` in the `my-app` namespace.

## Verification

To confirm the system is working:

```bash
# Check ESO pods are running
kubectl get pods -n external-secrets-operator

# Check SecretStore status
kubectl get secretstore -n default doppler-backend -o wide

# Check ExternalSecret status
kubectl get externalsecret -n default example-app-secret -o wide

# Verify the synced secret exists
kubectl get secret -n default example-app-secret
```

## Adding a New Secret

1. Add the secret to Doppler (via dashboard or CLI)
2. Create or update an `ExternalSecret` resource referencing the Doppler key
3. ArgoCD will sync the resource, and ESO will materialize the Kubernetes `Secret`

## Security Notes

- Doppler service tokens are stored as Kubernetes Secrets in `external-secrets-operator` namespace
- The `doppler-auth` secret is **never** committed to git with a real token
- ExternalSecrets use `creationPolicy: Owner` so ESO manages the lifecycle
- Secrets are refreshed every hour (`refreshInterval: 1h`)
- ESO RBAC is scoped to only manage secrets in namespaces where ExternalSecrets are defined

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| SecretStore not Ready | Invalid or missing Doppler token | Check `doppler-auth` secret in `external-secrets-operator` namespace |
| ExternalSecret not syncing | SecretStore not Ready | Check SecretStore status |
| Secret not created | Namespace mismatch | Ensure ExternalSecret and SecretStore are in the same namespace (or use a ClusterSecretStore) |
| ESO pod crash looping | Resource limits too low | Check pod logs: `kubectl logs -n external-secrets-operator deployment/external-secrets` |
