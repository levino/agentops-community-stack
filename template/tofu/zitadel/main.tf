terraform {
  required_version = ">= 1.6.0"

  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State lives as a k8s Secret — same trust boundary as kubectl access.
  # NOTE: the state contains plaintext outputs (client secrets, initial
  # passwords). Anyone with cluster access can read it; that is the model.
  backend "kubernetes" {
    secret_suffix = "zitadel"
    namespace     = "terraform-state"
    config_path   = "~/.kube/config"
  }
}

provider "zitadel" {
  domain           = var.zitadel_domain
  insecure         = "false"
  port             = "443"
  jwt_profile_file = var.jwt_profile_file
}
