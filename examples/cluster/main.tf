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
# All three share a VPC, so they peer over private addresses and the
# peer port stays closed to the internet (the module's default). The
# joiners seed with node 1's peer_endpoint, so they are created after
# it. Reserved IPs give clients stable public addresses.
# ----------------------------------------------------------------

locals {
  listen_port = 9000
  joiner_ids  = ["2", "3"]
}

resource "digitalocean_vpc" "cluster" {
  name   = "flo-prod-cluster"
  region = var.region
}

module "first" {
  source = "../.."

  environment = "prod"
  region      = var.region
  vpc_uuid    = digitalocean_vpc.cluster.id
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  flo_version  = "v0.1.0-dev.13"
  droplet_size = "s-4vcpu-8gb"
  listen_port  = local.listen_port
  shards       = 1

  cluster_enabled      = true
  cluster_node_id      = 1
  cluster_first_member = true
  cluster_secret       = var.cluster_secret

  # Clients and the dashboard are reachable only from the operator CIDRs.
  # The dashboard has no authentication yet, so keep that range narrow.
  api_allowed_cidrs       = var.operator_cidrs
  dashboard_bind_address  = "0.0.0.0"
  dashboard_allowed_cidrs = var.operator_cidrs
}

module "joiner" {
  for_each = toset(local.joiner_ids)
  source   = "../.."

  environment = "prod"
  region      = var.region
  vpc_uuid    = digitalocean_vpc.cluster.id
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  flo_version  = "v0.1.0-dev.13"
  droplet_size = "s-4vcpu-8gb"
  listen_port  = local.listen_port
  shards       = 1

  cluster_enabled = true
  cluster_node_id = tonumber(each.key)
  cluster_seeds   = [module.first.peer_endpoint]
  cluster_secret  = var.cluster_secret

  api_allowed_cidrs       = var.operator_cidrs
  dashboard_bind_address  = "0.0.0.0"
  dashboard_allowed_cidrs = var.operator_cidrs
}

locals {
  droplets = merge(
    { "1" = module.first.droplet_id },
    { for id, m in module.joiner : id => m.droplet_id },
  )
}

resource "digitalocean_reserved_ip" "node" {
  for_each = local.droplets
  region   = var.region
}

# Bind each reserved IP to its droplet.
resource "digitalocean_reserved_ip_assignment" "node" {
  for_each   = local.droplets
  ip_address = digitalocean_reserved_ip.node[each.key].ip_address
  droplet_id = each.value
}

output "endpoints" {
  value = {
    for id, _ in local.droplets :
    id => {
      ipv4      = digitalocean_reserved_ip.node[id].ip_address
      listen    = "${digitalocean_reserved_ip.node[id].ip_address}:${local.listen_port}"
      dashboard = "http://${digitalocean_reserved_ip.node[id].ip_address}:${local.listen_port + 2}"
    }
  }
}
