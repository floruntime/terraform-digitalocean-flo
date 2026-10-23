# The peer port's sources and the peer endpoints, planned against a mocked
# provider: no account or token needed.

mock_provider "digitalocean" {
  mock_resource "digitalocean_droplet" {
    defaults = {
      id                   = "1001"
      vpc_uuid             = "vpc-default"
      ipv4_address         = "203.0.113.10"
      ipv4_address_private = "10.110.0.5"
    }
  }
  mock_data "digitalocean_vpc" {
    defaults = {
      ip_range = "10.110.0.0/20"
    }
  }
}

variables {
  ssh_key_ids     = ["1"]
  cluster_enabled = true
  cluster_secret  = "flo-secret-0000000000000000000000000000000000000000000000000000000000000000"
  cluster_node_id = 1

  cluster_first_member = true
}

run "peer_port_defaults_to_the_vpc" {
  command = apply

  assert {
    condition = one([
      for r in digitalocean_firewall.this[0].inbound_rule : r.source_addresses if r.port_range == "9500"
    ]) == toset(["10.110.0.0/20"])
    error_message = "The peer port should accept only the droplet's VPC range by default."
  }
  assert {
    condition     = output.peer_endpoint == "10.110.0.5:9500"
    error_message = "peer_endpoint should be the private address."
  }
  assert {
    condition     = output.peer_endpoint_public == "203.0.113.10:9500"
    error_message = "peer_endpoint_public should be the public address."
  }
}

run "listed_cidrs_replace_the_vpc" {
  command = apply

  variables {
    cluster_allowed_cidrs = ["198.51.100.7/32"]
  }

  assert {
    condition = one([
      for r in digitalocean_firewall.this[0].inbound_rule : r.source_addresses if r.port_range == "9500"
    ]) == toset(["198.51.100.7/32"])
    error_message = "A listed range should replace the VPC default."
  }
}

run "an_empty_list_is_refused" {
  command = plan

  variables {
    cluster_allowed_cidrs = []
  }

  expect_failures = [var.cluster_allowed_cidrs]
}

run "no_peer_rule_or_endpoint_outside_a_cluster" {
  command = apply

  variables {
    cluster_enabled      = false
    cluster_first_member = false
  }

  assert {
    condition     = length([for r in digitalocean_firewall.this[0].inbound_rule : r if r.port_range == "9500"]) == 0
    error_message = "A single node should open no peer port."
  }
  assert {
    condition     = output.peer_endpoint == "" && output.peer_endpoint_public == ""
    error_message = "A single node has no peer endpoints."
  }
}
