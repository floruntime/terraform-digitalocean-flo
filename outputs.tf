output "droplet_id" {
  description = "DigitalOcean droplet ID."
  value       = digitalocean_droplet.this.id
}

output "droplet_name" {
  description = "Droplet name."
  value       = digitalocean_droplet.this.name
}

output "ipv4_address" {
  description = "Public IPv4 address of the droplet."
  value       = digitalocean_droplet.this.ipv4_address
}

output "ipv4_address_private" {
  description = "Private IPv4 address (VPC), if assigned."
  value       = digitalocean_droplet.this.ipv4_address_private
}

output "ipv6_address" {
  description = "Public IPv6 address of the droplet (empty if disabled)."
  value       = digitalocean_droplet.this.ipv6_address
}

output "urn" {
  description = "Droplet URN, useful when wiring further DigitalOcean resources."
  value       = digitalocean_droplet.this.urn
}

output "listen_endpoint" {
  description = "host:port to point Flo clients (and the `flo` CLI) at."
  value       = "${digitalocean_droplet.this.ipv4_address}:${var.listen_port}"
}

output "dashboard_url" {
  description = "Dashboard / REST API URL. Empty when enable_dashboard = false."
  value       = var.enable_dashboard ? "http://${digitalocean_droplet.this.ipv4_address}:${local.dashboard_port}" : ""
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint. Empty when enable_metrics = false."
  value       = var.enable_metrics ? "http://${digitalocean_droplet.this.ipv4_address}:${local.metrics_port}/metrics" : ""
}

output "gossip_endpoint" {
  description = "host:port other cluster nodes should list in their cluster_seeds. Empty when cluster_enabled = false."
  value       = var.cluster_enabled ? "${digitalocean_droplet.this.ipv4_address}:${local.gossip_port}" : ""
}

output "raft_port" {
  description = "TCP port used for Raft replication (listen_port + 500)."
  value       = local.raft_port
}

output "gossip_port" {
  description = "TCP/UDP port used for gossip (listen_port + 600)."
  value       = local.gossip_port
}

output "firewall_id" {
  description = "Firewall ID (empty when create_firewall = false)."
  value       = var.create_firewall ? digitalocean_firewall.this[0].id : ""
}
