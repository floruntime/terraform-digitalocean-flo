# ---------------------------------------------------------------
# Required
# ---------------------------------------------------------------

variable "ssh_key_ids" {
  type        = list(string)
  description = "DigitalOcean SSH key IDs (or fingerprints) to install on the droplet. At least one is required so cloud-init / operator access works."
  validation {
    condition     = length(var.ssh_key_ids) > 0
    error_message = "ssh_key_ids must contain at least one key."
  }
}

# ---------------------------------------------------------------
# Naming + placement
# ---------------------------------------------------------------

variable "environment" {
  type        = string
  description = "Environment label used in the droplet name and tags (e.g. 'dev', 'prod')."
  default     = "dev"
}

variable "region" {
  type        = string
  description = "DigitalOcean region slug."
  default     = "lon1"
}

variable "droplet_size" {
  type        = string
  description = "DigitalOcean droplet size slug. Flo benefits from multiple vCPUs (one shard per CPU)."
  default     = "s-2vcpu-4gb"
}

variable "image" {
  type        = string
  description = "Base image slug. Tested on Ubuntu 24.04 LTS; older Debian/Ubuntu releases may work but are unsupported."
  default     = "ubuntu-24-04-x64"
}

variable "tags" {
  type        = list(string)
  description = "Extra droplet tags. The module always adds 'flo' and 'flo-<environment>'."
  default     = []
}

variable "project_id" {
  type        = string
  description = "Optional DigitalOcean project ID to attach the droplet to. Empty disables attachment."
  default     = ""
}

# ---------------------------------------------------------------
# Droplet features
# ---------------------------------------------------------------

variable "enable_backups" {
  type        = bool
  description = "Enable weekly droplet backups."
  default     = false
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable DigitalOcean monitoring agent."
  default     = true
}

variable "enable_ipv6" {
  type        = bool
  description = "Enable IPv6 on the droplet."
  default     = true
}

# ---------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------

variable "create_firewall" {
  type        = bool
  description = "Create a DigitalOcean firewall in front of the droplet. Disable if you manage firewalls externally."
  default     = true
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach SSH (port 22). Tighten in production."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the Flo wire-protocol port (var.listen_port)."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "dashboard_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the Flo dashboard / REST API (listen_port + 2). Restrict in production."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "metrics_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the Prometheus metrics endpoint (listen_port + 1). Only used when expose_metrics = true."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "expose_metrics" {
  type        = bool
  description = "Open the metrics port (listen_port + 1) on the firewall. Off by default; scrape via private network or DO monitoring instead."
  default     = false
}

variable "cluster_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the cluster ports (raft = listen_port + 500, gossip = listen_port + 600). Only used when cluster_enabled = true."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "extra_inbound_tcp_ports" {
  type        = list(number)
  description = "Additional TCP ports to open inbound (gated by api_allowed_cidrs)."
  default     = []
}

# ---------------------------------------------------------------
# Flo installation
# ---------------------------------------------------------------

variable "flo_version" {
  type        = string
  description = "Flo release tag passed to install.sh (e.g. 'v0.1.0'). Empty means 'latest' — pin in production for reproducibility."
  default     = ""
}

# ---------------------------------------------------------------
# Flo runtime config (rendered into /etc/flo/flo.toml)
# ---------------------------------------------------------------

variable "listen_port" {
  type        = number
  description = "Port for the Flo wire protocol. Metrics auto-binds to listen_port + 1, dashboard to listen_port + 2."
  default     = 9000
}

variable "bind_address" {
  type        = string
  description = "Address Flo binds the wire-protocol listener to."
  default     = "0.0.0.0"
}

variable "data_dir" {
  type        = string
  description = "Directory Flo stores its data in. Created and chowned by cloud-init."
  default     = "/var/lib/flo"
}

variable "shards" {
  type        = number
  description = "Number of shards (threads). 0 means auto-detect from CPU count."
  default     = 0
  validation {
    condition     = var.shards >= 0
    error_message = "shards must be 0 (auto) or positive."
  }
}

variable "durability" {
  type        = string
  description = "Storage durability mode. One of 'async_flush', 'sync_flush', 'fsync'."
  default     = "async_flush"
  validation {
    condition     = contains(["async_flush", "sync_flush", "fsync"], var.durability)
    error_message = "durability must be one of: async_flush, sync_flush, fsync."
  }
}

variable "hot_buffer_capacity" {
  type        = number
  description = "Size of the in-memory hot ring buffer in bytes. 0 uses the Flo default."
  default     = 0
}

variable "log_level" {
  type        = string
  description = "Log level (debug, info, warn, error)."
  default     = "info"
}

variable "enable_metrics" {
  type        = bool
  description = "Enable the Prometheus metrics endpoint."
  default     = true
}

variable "enable_dashboard" {
  type        = bool
  description = "Enable the dashboard HTTP API + web UI."
  default     = true
}

variable "dashboard_bind_address" {
  type        = string
  description = "Address Flo binds the dashboard listener to."
  default     = "0.0.0.0"
}

# ---------------------------------------------------------------
# Cluster (optional)
# ---------------------------------------------------------------

variable "cluster_enabled" {
  type        = bool
  description = "Join this droplet to a Flo cluster. Requires cluster_node_id and cluster_seeds."
  default     = false
}

variable "cluster_node_id" {
  type        = number
  description = "Unique node ID within the cluster (1, 2, 3, ...). Required when cluster_enabled = true."
  default     = 0
  validation {
    condition     = var.cluster_node_id >= 0
    error_message = "cluster_node_id must be >= 0."
  }
}

variable "cluster_seeds" {
  type        = list(string)
  description = "Gossip seed addresses ('host:gossip_port'). Each entry should target another node's listen_port + 600. Required when cluster_enabled = true."
  default     = []
}

# ---------------------------------------------------------------
# Persistent storage (optional block-storage volume for data_dir)
# ---------------------------------------------------------------

variable "cluster_secret" {
  type        = string
  description = "Shared secret every node of the cluster proves at the peer handshake; the Raft port refuses to start without one. Use the same value on every node (e.g. `openssl rand -base64 32`). Required when cluster_enabled = true."
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.cluster_enabled || length(var.cluster_secret) > 0
    error_message = "cluster_secret is required when cluster_enabled = true."
  }
}

variable "volume_size" {
  type        = number
  description = "Size in GB of a DigitalOcean block-storage volume to provision and mount at var.data_dir. 0 (default) keeps Flo's data on the droplet's root disk; any positive value provisions a volume that survives droplet replacement."
  default     = 0
  validation {
    condition     = var.volume_size >= 0 && var.volume_size <= 16384
    error_message = "volume_size must be between 0 and 16384 GB (DigitalOcean's max volume size)."
  }
}

variable "volume_name" {
  type        = string
  description = "Name of the DigitalOcean volume. Must be lowercase alphanumeric or hyphen, 1-64 chars. Empty (default) auto-derives from the droplet name. Only used when volume_size > 0."
  default     = ""
  validation {
    condition     = var.volume_name == "" || can(regex("^[a-z0-9][a-z0-9-]{0,63}$", var.volume_name))
    error_message = "volume_name must be empty or 1-64 lowercase alphanumeric / hyphen chars starting with a letter or digit."
  }
}

variable "volume_filesystem_type" {
  type        = string
  description = "Filesystem to format a freshly-created volume with. One of 'ext4' or 'xfs'. Existing filesystems on a re-attached volume are detected and never reformatted."
  default     = "ext4"
  validation {
    condition     = contains(["ext4", "xfs"], var.volume_filesystem_type)
    error_message = "volume_filesystem_type must be one of: ext4, xfs."
  }
}
