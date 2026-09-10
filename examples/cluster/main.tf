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

# ----------------------------------------------------------------
# Three-node Flo cluster.
#
# We need stable IPs to populate cluster_seeds *before* the droplets
# exist, so we reserve floating IPs first and pass them in as the
# gossip seeds. Each node's gossip port is listen_port + 600.
# ----------------------------------------------------------------

locals {
  node_ids    = [1, 2, 3]
  listen_port = 9000
  gossip_port = local.listen_port + 600
}

resource "digitalocean_reserved_ip" "node" {
  for_each = toset([for id in local.node_ids : tostring(id)])
  region   = var.region
}

locals {
  seeds = [
    for id in local.node_ids :
    "${digitalocean_reserved_ip.node[tostring(id)].ip_address}:${local.gossip_port}"
  ]
}

module "flo" {
  for_each = toset([for id in local.node_ids : tostring(id)])
  source   = "../.."

  environment = "prod"
  region      = var.region
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  flo_version  = "v0.1.0"
  droplet_size = "s-4vcpu-8gb"
  listen_port  = local.listen_port

  cluster_enabled = true
  cluster_node_id = tonumber(each.key)
  cluster_seeds   = local.seeds
  cluster_secret  = var.cluster_secret

  # Lock the dashboard down to your operator IP in real deployments.
  dashboard_allowed_cidrs = var.operator_cidrs
}

# Bind each reserved IP to its droplet.
resource "digitalocean_reserved_ip_assignment" "node" {
  for_each   = module.flo
  ip_address = digitalocean_reserved_ip.node[each.key].ip_address
  droplet_id = each.value.droplet_id
}

output "endpoints" {
  value = {
    for id, m in module.flo :
    id => {
      ipv4      = digitalocean_reserved_ip.node[id].ip_address
      listen    = "${digitalocean_reserved_ip.node[id].ip_address}:${local.listen_port}"
      dashboard = "http://${digitalocean_reserved_ip.node[id].ip_address}:${local.listen_port + 2}"
    }
  }
}
