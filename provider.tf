terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.5.3"
    }
  }

  required_version = ">= 1.1"
}

provider "aws" {
  region = var.region
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory" # Untrusted certificates but unlimited to create
  server_url = "https://acme-v02.api.letsencrypt.org/directory" # Valid DNS record. Limited to 5 a week to create
}