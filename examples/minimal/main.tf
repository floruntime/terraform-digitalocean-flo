terraform {
  required_version = ">= 1.5.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.40, < 3.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

module "flo" {
  source = "../.."

  environment = "dev"
  region      = "lon1"
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  flo_version = "v0.1.0"
}

output "ipv4_address" { value = module.flo.ipv4_address }
output "listen_endpoint" { value = module.flo.listen_endpoint }
output "dashboard_url" { value = module.flo.dashboard_url }
