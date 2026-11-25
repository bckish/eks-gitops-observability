mock_provider "aws" {
  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "random" {}
mock_provider "tls" {}

run "local_cluster_plan" {
  command = plan
}
