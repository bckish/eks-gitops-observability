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
helm --kubeconfig /path/to/local-kind.kubeconfig upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version 5.46.0 --namespace argocd --create-namespace --set server.service.type=ClusterIP --set server.ingress.enabled=false
helm --kubeconfig /path/to/local-kind.kubeconfig upgrade --install monitoring kube-prometheus-stack --repo https://prometheus-community.github.io/helm-charts --version 65.0.0 --namespace monitoring --create-namespace --set grafana.service.type=ClusterIP --set prometheus.service.type=ClusterIP
```

The EKS-specific Terraform roots were validated and tested with mock providers in the earlier pass. Actual AWS EKS, IAM, VPC, AWS Load Balancer Controller and remote state were **not deployed or verified**.
