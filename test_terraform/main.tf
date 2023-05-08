terraform {
  cloud {
    hostname = "patrick-tfe22.tf-support.hashicorpdemo.com"
    organization = "test"

    workspaces {
      name = "test-workspace"
    }
  }
}

resource "null_resource" "test2" {}