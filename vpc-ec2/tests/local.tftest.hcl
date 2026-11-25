mock_provider "aws" {}
mock_provider "kubernetes" {}

run "local_network_plan" {
  command = plan
}
