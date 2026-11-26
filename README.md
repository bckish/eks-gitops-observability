# EKS GitOps and observability

Portfolio lab maintained in [bckish/eks-gitops-observability](https://github.com/bckish/eks-gitops-observability). The implementation is derived from upstream work; this repository's documentation and validation changes do not imply an independently verified cloud deployment.

Terraform lab for an AWS VPC and deployment host, a private EKS cluster, Argo CD, Prometheus/Grafana and AWS Load Balancer Controller.

![Upstream architecture illustration](assets/architecture-diagram.gif)

## Layout and local validation

The [vpc-ec2](vpc-ec2/) root prepares networking and the deployment host; the [eks](eks/) root configures the cluster and Helm releases. Both use [module](module/) and require Terraform 1.13.3 or later, below 2.0. Run `bash validate.sh` to initialize, validate and run a plan test with all providers explicitly mocked. These synthetic plan tests do not contact AWS or Kubernetes, load remote state or apply changes. The real EKS cluster is cloud infrastructure, not a local cluster.

```bash
git clone https://github.com/bckish/eks-gitops-observability.git
cd eks-gitops-observability
terraform -chdir=vpc-ec2 init -backend=false
terraform -chdir=vpc-ec2 validate
terraform -chdir=eks init -backend=false
terraform -chdir=eks validate
```

Provider downloads require internet access. Before planning, configure your own S3 state backend for each root, review [variables.tfvars](variables.tfvars), and use a suitable AWS identity and region. The private EKS endpoint needs a reachable deployment host. Plan the VPC/EC2 root first, then EKS; review both plans before any apply. Avoid automatic approval. EKS, NAT gateways, EC2 and load balancers can incur ongoing charges. No AWS cluster availability or cloud monitoring results are claimed here.

## Attribution and license

Original implementation by Aman Pathak. See [UPSTREAM.md](UPSTREAM.md) for the source repository and [LICENSE](LICENSE) (MIT). The upstream license and copyright notices are unchanged.

## Verified local Kubernetes and GitOps results

Test date: 25 November 2026. Environment: Docker Desktop on Apple Silicon, Kind v0.30.0, Kubernetes v1.34.3. Local images were imported into the isolated cluster; no images were pushed to a registry and no paid cloud resources were created.

Tested code: `901bdac` (merged main). The exact chart versions declared by the infrastructure were installed in a disposable Kind cluster with ClusterIP-only services:

- Argo CD Helm chart 5.46.0 (Argo CD v2.8.3): deployed, Application Synced and Healthy.
- kube-prometheus-stack chart 65.0.0: deployed, Prometheus, Grafana, Alertmanager, Prometheus Operator, kube-state-metrics and node-exporter running.
- Prometheus API query `up`: successful with 13 active targets, including kube-state-metrics. Grafana successfully queried Prometheus through its provisioned datasource.
- Argo CD reconciled both revisions of a disposable Git repository deploying the three-tier task app, scaled the API from one to two ready replicas, and repaired deliberate replica drift.

Reproduce the local chart installation in an isolated Kind cluster (use its specific kubeconfig):

```bash
helm --kubeconfig /path/to/local-kind.kubeconfig upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version 10.20.0 --namespace argocd --create-namespace --set server.service.type=ClusterIP --set server.ingress.enabled=false
helm --kubeconfig /path/to/local-kind.kubeconfig upgrade --install monitoring kube-prometheus-stack --repo https://prometheus-community.github.io/helm-charts --version 65.0.0 --namespace monitoring --create-namespace --set grafana.service.type=ClusterIP --set prometheus.service.type=ClusterIP
```

The EKS-specific Terraform roots were validated and tested with mock providers in the earlier pass. Actual AWS EKS, IAM, VPC, AWS Load Balancer Controller and remote state were **not deployed or verified**.

## Dependency maintenance (26 November 2026)

The Argo CD chart is now pinned to 10.20.0 (Argo CD 3.6.3), which renders without the old Helm values coalescing warning and starts all seven Argo CD components in local Kind. Removed obsolete top-level monitoring chart values for PodSecurityPolicy and persistent storage; storage must be explicitly configured using the supported `prometheus.prometheusSpec.storageSpec` if required. No paid AWS resources were created.

The new Argo CD chart reconciled local revisions `ba89310` and `08232e4` using the rebuilt task application, returned Synced/Healthy, and repaired replica drift back to two ready API replicas. Both Terraform roots validated and both mocked plans passed. This was a fresh local installation, not an in-place migration of a production Argo CD installation; existing users should review upstream upgrade instructions before applying.

## Warning-free local chart verification (26 November 2026)

Kubernetes 1.34.0 incorrectly warned about valid numeric CRD formats and default session affinity on headless services. Upstream fixed both server-side regressions ([numeric formats](https://github.com/kubernetes/kubernetes/pull/133896), [headless services](https://github.com/kubernetes/kubernetes/pull/134054)); the fixes were backported to 1.34. The same Argo CD 10.20.0 and kube-prometheus-stack 65.0.0 charts installed and upgraded without these warnings on Kubernetes v1.34.3. No CRD schema or chart warning was suppressed.

Use Kind and a matching kubectl v1.34.3 on a disposable cluster. The check rejects remote contexts and fails if Helm emits warnings:

```bash
kind create cluster --name observability-local --image kindest/node:v1.34.3 --kubeconfig ./observability-local.kubeconfig
bash scripts/local-chart-check.sh ./observability-local.kubeconfig
kind delete cluster --name observability-local --kubeconfig ./observability-local.kubeconfig
```

Both charts use ClusterIP-only services for this check. AWS-specific Terraform remains unchanged; this is not evidence of an EKS upgrade or cloud deployment.

The follow-up run confirmed all monitoring pods Ready and a successful Prometheus `up` query with 17 returned targets. Both Terraform roots and mocked plans passed again.
