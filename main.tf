# ---------------------------------------------------------------
# terraform-digitalocean-flo
#
# Provisions a single DigitalOcean droplet running the Flo server.
# Cloud-init installs Flo via the upstream installer script and
# writes a flo.toml shaped by this module's inputs.
#
# Cluster mode (var.cluster_enabled = true) wires this node into a
# Flo cluster via gossip seeds. To stand up a multi-node cluster,
# instantiate this module N times with distinct cluster_node_id
# values and a shared cluster_seeds list.
# ---------------------------------------------------------------

locals {
  name = "flo-${var.environment}${var.cluster_enabled ? "-${var.cluster_node_id}" : ""}"

  # Derived ports (Flo convention):
  #   metrics   = listen_port + 1
  #   dashboard = listen_port + 2
  #   raft      = listen_port + 500
  #   gossip    = listen_port + 600
  metrics_port   = var.listen_port + 1
  dashboard_port = var.listen_port + 2
  raft_port      = var.listen_port + 500
  gossip_port    = var.listen_port + 600

  # Persistent volume wiring.
  volume_enabled = var.volume_size > 0
  volume_name    = var.volume_name != "" ? var.volume_name : "${local.name}-data"

  # DigitalOcean exposes attached volumes at this stable udev path.
  # The suffix is the volume name with non-alnum chars stripped to '_'.
  # See https://docs.digitalocean.com/products/volumes/how-to/mount/
  volume_device_path = local.volume_enabled ? "/dev/disk/by-id/scsi-0DO_Volume_${replace(local.volume_name, "-", "")}" : ""

  # The user_data script is rendered with module inputs. Cloud-init
  # is at-most-once: changing user_data does NOT re-run on existing
  # droplets, so changes here only take effect on a fresh apply.
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    flo_version            = var.flo_version
    flotoml                = local.flotoml
    data_dir               = var.data_dir
    volume_enabled         = local.volume_enabled
    volume_device_path     = local.volume_device_path
    volume_filesystem_type = var.volume_filesystem_type
  })

  flotoml = templatefile("${path.module}/templates/flo.toml.tftpl", {
    listen_port            = var.listen_port
    bind_address           = var.bind_address
    data_dir               = var.data_dir
    shards                 = var.shards
    durability             = var.durability
    hot_buffer_capacity    = var.hot_buffer_capacity
    log_level              = var.log_level
    enable_metrics         = var.enable_metrics
    enable_dashboard       = var.enable_dashboard
    dashboard_bind_address = var.dashboard_bind_address
    cluster_enabled        = var.cluster_enabled
    cluster_node_id        = var.cluster_node_id
    cluster_seeds          = var.cluster_seeds
    cluster_secret         = var.cluster_secret
  })
}

resource "digitalocean_volume" "this" {
  count = local.volume_enabled ? 1 : 0

  name                    = local.volume_name
  region                  = var.region
  size                    = var.volume_size
  initial_filesystem_type = var.volume_filesystem_type
  description             = "Persistent data volume for ${local.name}"

  # Stateful data: Terraform must refuse to destroy this resource.
  # Operators who genuinely want to delete a volume must remove it
  # from state (or set this to false locally) and apply explicitly.
  lifecycle {
    prevent_destroy = true
  }
}

resource "digitalocean_droplet" "this" {
  name     = local.name
  image    = var.image
  region   = var.region
  size     = var.droplet_size
  ssh_keys = var.ssh_key_ids

  monitoring = var.enable_monitoring
  backups    = var.enable_backups
  ipv6       = var.enable_ipv6

  # Attaching at create time guarantees the device is present when
  # cloud-init runs. The mount step in user_data still waits for the
  # udev symlink to settle as a belt-and-braces safety net.
  volume_ids = local.volume_enabled ? [digitalocean_volume.this[0].id] : []

  user_data = local.user_data

  tags = concat(["flo", "flo-${var.environment}"], var.tags)
}

resource "digitalocean_firewall" "this" {
  count = var.create_firewall ? 1 : 0

  name        = "${local.name}-fw"
  droplet_ids = [digitalocean_droplet.this.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_cidrs
  }

  # Flo wire protocol (clients + RESP)
  inbound_rule {
    protocol         = "tcp"
    port_range       = tostring(var.listen_port)
    source_addresses = var.api_allowed_cidrs
  }

  # Dashboard HTTP API + web UI
  dynamic "inbound_rule" {
    for_each = var.enable_dashboard ? [local.dashboard_port] : []
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.dashboard_allowed_cidrs
    }
  }

  # Prometheus metrics endpoint (only opened when explicitly enabled)
  dynamic "inbound_rule" {
    for_each = var.enable_metrics && var.expose_metrics ? [local.metrics_port] : []
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.metrics_allowed_cidrs
    }
  }

  # Cluster traffic (raft + gossip) — restricted to the cluster CIDRs.
  dynamic "inbound_rule" {
    for_each = var.cluster_enabled ? [local.raft_port, local.gossip_port] : []
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.cluster_allowed_cidrs
    }
  }

  dynamic "inbound_rule" {
    for_each = var.cluster_enabled ? [local.gossip_port] : []
    content {
      protocol         = "udp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.cluster_allowed_cidrs
    }
  }

  # Extra ports the operator wants reachable.
  dynamic "inbound_rule" {
    for_each = var.extra_inbound_tcp_ports
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.api_allowed_cidrs
    }
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_project_resources" "this" {
  count   = var.project_id != "" ? 1 : 0
  project = var.project_id
  resources = concat(
    [digitalocean_droplet.this.urn],
    local.volume_enabled ? [digitalocean_volume.this[0].urn] : [],
  )
}
