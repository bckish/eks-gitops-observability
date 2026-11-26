#!/usr/bin/env bash
# Install the pinned charts on a disposable, patched Kind cluster only.
set -euo pipefail

if [[ $# != 1 ]]; then
  echo "Usage: bash scripts/local-chart-check.sh /path/to/local-kind.kubeconfig" >&2
  exit 2
fi
kubeconfig=$1
context=$(kubectl --kubeconfig "$kubeconfig" config current-context)
server=$(kubectl --kubeconfig "$kubeconfig" config view --minify -o jsonpath='{.clusters[0].cluster.server}')
if [[ $context != kind-* || $server != https://127.0.0.1:* ]] || ! kind get clusters | grep -Fxq "${context#kind-}"; then
  echo "Use a dedicated local Kind cluster, not a remote or Docker Desktop context." >&2
  exit 2
fi
versions=$(kubectl --kubeconfig "$kubeconfig" version -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["serverVersion"]["gitVersion"], d["clientVersion"]["major"], d["clientVersion"]["minor"])')
if [[ $versions != 'v1.34.3 1 34' ]]; then
  echo "Use Kubernetes and kubectl v1.34.3 for this check; recreate the disposable cluster with kindest/node:v1.34.3." >&2
  exit 2
fi

logs=$(mktemp -d)
trap 'rm -f "$logs/argocd.log" "$logs/monitoring.log"; rmdir "$logs"' EXIT
helm --kubeconfig "$kubeconfig" upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm --version 10.20.0 \
  --namespace argocd --create-namespace --set server.service.type=ClusterIP \
  --set server.ingress.enabled=false --wait --timeout 5m 2>&1 | tee "$logs/argocd.log"
helm --kubeconfig "$kubeconfig" upgrade --install monitoring kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts --version 65.0.0 \
  --namespace monitoring --create-namespace --set grafana.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP --wait --timeout 5m 2>&1 | tee "$logs/monitoring.log"

if grep -Ei 'Warning:|level=warn|coalesce.*warn' "$logs/argocd.log" "$logs/monitoring.log"; then
  echo "Chart installation emitted warnings; inspect the output above." >&2
  exit 1
fi
echo "PASS: both chart releases installed without Helm or Kubernetes warning output."
