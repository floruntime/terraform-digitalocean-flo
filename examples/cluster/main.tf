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
# Three-node Flo cluster: node 1 starts it, nodes 2 and 3 join it.
#
# The joiners need node 1's address before any droplet exists, so a
# reserved IP is created first and node 1's peer endpoint (that IP at
# listen_port + 500) is their seed.
# ----------------------------------------------------------------

locals {
  node_ids    = [1, 2, 3]
  listen_port = 9000
  peer_port   = local.listen_port + 500
}

resource "digitalocean_reserved_ip" "node" {
  for_each = toset([for id in local.node_ids : tostring(id)])
  region   = var.region
}

locals {
  first_member_seed = "${digitalocean_reserved_ip.node["1"].ip_address}:${local.peer_port}"
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
  shards       = 1

  cluster_enabled      = true
  cluster_node_id      = tonumber(each.key)
  cluster_first_member = each.key == "1"
  cluster_seeds        = each.key == "1" ? [] : [local.first_member_seed]
  cluster_secret       = var.cluster_secret

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
