terraform {
  cloud {
    hostname = "patrick-tfe2.bg.hashicorp-success.com"
    organization = "test"

    workspaces {
      name = "test-workspace"
    }
  }
}

resource "null_resource" "test2" {}