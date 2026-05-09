# terraform-digitalocean-flo

Terraform module that provisions a [Flo](https://github.com/floruntime/flo)
node on DigitalOcean: droplet, firewall, cloud-init installation,
and optional cluster wiring.

> Published on the [Terraform Registry](https://registry.terraform.io/modules/floruntime/flo/digitalocean).

## Usage

```hcl
module "flo" {
  source  = "floruntime/flo/digitalocean"
  version = "~> 0.0.1"

  ssh_key_ids = [data.digitalocean_ssh_key.main.id]
  flo_version = "v0.1.0" # pin in production
}

output "endpoint"  { value = module.flo.listen_endpoint }
output "dashboard" { value = module.flo.dashboard_url }
```

```bash
terraform init
terraform apply

flo --server "$(terraform output -raw listen_endpoint)" kv set hello world
```

## Features

- **Single-droplet** provisioning with sensible defaults (Ubuntu
  24.04, `s-2vcpu-4gb`, `lon1`).
- **Cloud-init** runs the upstream `scripts/install.sh`, optionally
  pins to a specific `flo` version, drops a templated `flo.toml`
  into `/etc/flo/`, and runs Flo under a dedicated `flo` systemd
  unit.
- **Optional cluster mode** — set `cluster_enabled = true` and
  pass `cluster_node_id` + `cluster_seeds`; the firewall opens the
  derived raft and gossip ports between `cluster_allowed_cidrs`.
- **Project attachment**, **monitoring**, and **backups** toggles
  for production hygiene.

## Port layout

Flo derives all secondary ports from `listen_port` (default `9000`):

| Service   | Port               |
|-----------|--------------------|
| Wire      | `listen_port`      |
| Metrics   | `listen_port + 1`  |
| Dashboard | `listen_port + 2`  |
| Raft      | `listen_port + 500`|
| Gossip    | `listen_port + 600`|

## Examples

| Path | What it shows |
|---|---|
| [`examples/minimal`](./examples/minimal) | Single node, public defaults. |
| [`examples/cluster`](./examples/cluster) | Three-node cluster wired via reserved IPs. |

## After `terraform apply`

```bash
# Wire-protocol endpoint for the CLI / SDKs
flo --server "$(terraform output -raw listen_endpoint)" kv set hello world

# Dashboard
open "$(terraform output -raw dashboard_url)"

# Tail the install log
ssh root@$(terraform output -raw ipv4_address) 'tail -f /var/log/user-data.log'

# Service logs
ssh root@$(terraform output -raw ipv4_address) 'journalctl -u flo -f'
```

## Cloud-init is at-most-once

Cloud-init runs **only on first boot**. Changing `var.flo_version`
or any value rendered into `flo.toml` after the droplet exists
will NOT take effect on the running droplet. To roll a new config:

```bash
terraform apply -replace=module.flo.digitalocean_droplet.this
```

For in-place config rolls, SSH in and edit `/etc/flo/flo.toml`,
then `systemctl restart flo`.

## Operational notes

- Flo runs as the `flo` system user under systemd. Logs:
  `journalctl -u flo -f`.
- Data lives under `var.data_dir` (default `/var/lib/flo`),
  owned by `flo:flo`, mode `0750`.
- The dashboard listens on `listen_port + 2` and is gated by
  `var.dashboard_allowed_cidrs`. Tighten this in production —
  the dashboard exposes administrative APIs.
- The metrics port is **not** opened on the firewall by default.
  Set `expose_metrics = true` (and tighten `metrics_allowed_cidrs`)
  to scrape it from outside the droplet.

## Compatibility

- Terraform `>= 1.5.0`
- `digitalocean/digitalocean` provider `>= 2.40, < 3.0`
- Ubuntu 24.04 LTS

## Related modules

| Cloud | Module |
|---|---|
| DigitalOcean | This repo |
| AWS | `floruntime/flo/aws` *(planned)* |
| Hetzner Cloud | `floruntime/flo/hcloud` *(planned)* |
| GCP | `floruntime/flo/google` *(planned)* |

## Contributing

Run `terraform fmt -recursive` and `terraform validate` (in the
root and each `examples/*` directory) before opening a PR; CI
will block otherwise.

## License

Apache-2.0 — see [LICENSE](./LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_digitalocean"></a> [digitalocean](#requirement\_digitalocean) | >= 2.40, < 3.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_digitalocean"></a> [digitalocean](#provider\_digitalocean) | >= 2.40, < 3.0 |
## Resources

| Name | Type |
|------|------|
| [digitalocean_droplet.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/droplet) | resource |
| [digitalocean_firewall.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/firewall) | resource |
| [digitalocean_project_resources.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/project_resources) | resource |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_allowed_cidrs"></a> [api\_allowed\_cidrs](#input\_api\_allowed\_cidrs) | CIDR blocks allowed to reach the Flo wire-protocol port (var.listen\_port). | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_bind_address"></a> [bind\_address](#input\_bind\_address) | Address Flo binds the wire-protocol listener to. | `string` | `"0.0.0.0"` | no |
| <a name="input_cluster_allowed_cidrs"></a> [cluster\_allowed\_cidrs](#input\_cluster\_allowed\_cidrs) | CIDR blocks allowed to reach the cluster ports (raft = listen\_port + 500, gossip = listen\_port + 600). Only used when cluster\_enabled = true. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_cluster_enabled"></a> [cluster\_enabled](#input\_cluster\_enabled) | Join this droplet to a Flo cluster. Requires cluster\_node\_id and cluster\_seeds. | `bool` | `false` | no |
| <a name="input_cluster_node_id"></a> [cluster\_node\_id](#input\_cluster\_node\_id) | Unique node ID within the cluster (1, 2, 3, ...). Required when cluster\_enabled = true. | `number` | `0` | no |
| <a name="input_cluster_seeds"></a> [cluster\_seeds](#input\_cluster\_seeds) | Gossip seed addresses ('host:gossip\_port'). Each entry should target another node's listen\_port + 600. Required when cluster\_enabled = true. | `list(string)` | `[]` | no |
| <a name="input_create_firewall"></a> [create\_firewall](#input\_create\_firewall) | Create a DigitalOcean firewall in front of the droplet. Disable if you manage firewalls externally. | `bool` | `true` | no |
| <a name="input_dashboard_allowed_cidrs"></a> [dashboard\_allowed\_cidrs](#input\_dashboard\_allowed\_cidrs) | CIDR blocks allowed to reach the Flo dashboard / REST API (listen\_port + 2). Restrict in production. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_dashboard_bind_address"></a> [dashboard\_bind\_address](#input\_dashboard\_bind\_address) | Address Flo binds the dashboard listener to. | `string` | `"0.0.0.0"` | no |
| <a name="input_data_dir"></a> [data\_dir](#input\_data\_dir) | Directory Flo stores its data in. Created and chowned by cloud-init. | `string` | `"/var/lib/flo"` | no |
| <a name="input_droplet_size"></a> [droplet\_size](#input\_droplet\_size) | DigitalOcean droplet size slug. Flo benefits from multiple vCPUs (one shard per CPU). | `string` | `"s-2vcpu-4gb"` | no |
| <a name="input_durability"></a> [durability](#input\_durability) | Storage durability mode. One of 'async\_flush', 'sync\_flush', 'fsync'. | `string` | `"async_flush"` | no |
| <a name="input_enable_backups"></a> [enable\_backups](#input\_enable\_backups) | Enable weekly droplet backups. | `bool` | `false` | no |
| <a name="input_enable_dashboard"></a> [enable\_dashboard](#input\_enable\_dashboard) | Enable the dashboard HTTP API + web UI. | `bool` | `true` | no |
| <a name="input_enable_ipv6"></a> [enable\_ipv6](#input\_enable\_ipv6) | Enable IPv6 on the droplet. | `bool` | `true` | no |
| <a name="input_enable_metrics"></a> [enable\_metrics](#input\_enable\_metrics) | Enable the Prometheus metrics endpoint. | `bool` | `true` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enable DigitalOcean monitoring agent. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment label used in the droplet name and tags (e.g. 'dev', 'prod'). | `string` | `"dev"` | no |
| <a name="input_expose_metrics"></a> [expose\_metrics](#input\_expose\_metrics) | Open the metrics port (listen\_port + 1) on the firewall. Off by default; scrape via private network or DO monitoring instead. | `bool` | `false` | no |
| <a name="input_extra_inbound_tcp_ports"></a> [extra\_inbound\_tcp\_ports](#input\_extra\_inbound\_tcp\_ports) | Additional TCP ports to open inbound (gated by api\_allowed\_cidrs). | `list(number)` | `[]` | no |
| <a name="input_flo_version"></a> [flo\_version](#input\_flo\_version) | Flo release tag passed to install.sh (e.g. 'v0.1.0'). Empty means 'latest' — pin in production for reproducibility. | `string` | `""` | no |
| <a name="input_hot_buffer_capacity"></a> [hot\_buffer\_capacity](#input\_hot\_buffer\_capacity) | Size of the in-memory hot ring buffer in bytes. 0 uses the Flo default. | `number` | `0` | no |
| <a name="input_image"></a> [image](#input\_image) | Base image slug. Tested on Ubuntu 24.04 LTS; older Debian/Ubuntu releases may work but are unsupported. | `string` | `"ubuntu-24-04-x64"` | no |
| <a name="input_listen_port"></a> [listen\_port](#input\_listen\_port) | Port for the Flo wire protocol. Metrics auto-binds to listen\_port + 1, dashboard to listen\_port + 2. | `number` | `9000` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level (debug, info, warn, error). | `string` | `"info"` | no |
| <a name="input_metrics_allowed_cidrs"></a> [metrics\_allowed\_cidrs](#input\_metrics\_allowed\_cidrs) | CIDR blocks allowed to reach the Prometheus metrics endpoint (listen\_port + 1). Only used when expose\_metrics = true. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Optional DigitalOcean project ID to attach the droplet to. Empty disables attachment. | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | DigitalOcean region slug. | `string` | `"lon1"` | no |
| <a name="input_shards"></a> [shards](#input\_shards) | Number of shards (threads). 0 means auto-detect from CPU count. | `number` | `0` | no |
| <a name="input_ssh_allowed_cidrs"></a> [ssh\_allowed\_cidrs](#input\_ssh\_allowed\_cidrs) | CIDR blocks allowed to reach SSH (port 22). Tighten in production. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | DigitalOcean SSH key IDs (or fingerprints) to install on the droplet. At least one is required so cloud-init / operator access works. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra droplet tags. The module always adds 'flo' and 'flo-<environment>'. | `list(string)` | `[]` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | Dashboard / REST API URL. Empty when enable\_dashboard = false. |
| <a name="output_droplet_id"></a> [droplet\_id](#output\_droplet\_id) | DigitalOcean droplet ID. |
| <a name="output_droplet_name"></a> [droplet\_name](#output\_droplet\_name) | Droplet name. |
| <a name="output_firewall_id"></a> [firewall\_id](#output\_firewall\_id) | Firewall ID (empty when create\_firewall = false). |
| <a name="output_gossip_endpoint"></a> [gossip\_endpoint](#output\_gossip\_endpoint) | host:port other cluster nodes should list in their cluster\_seeds. Empty when cluster\_enabled = false. |
| <a name="output_gossip_port"></a> [gossip\_port](#output\_gossip\_port) | TCP/UDP port used for gossip (listen\_port + 600). |
| <a name="output_ipv4_address"></a> [ipv4\_address](#output\_ipv4\_address) | Public IPv4 address of the droplet. |
| <a name="output_ipv4_address_private"></a> [ipv4\_address\_private](#output\_ipv4\_address\_private) | Private IPv4 address (VPC), if assigned. |
| <a name="output_ipv6_address"></a> [ipv6\_address](#output\_ipv6\_address) | Public IPv6 address of the droplet (empty if disabled). |
| <a name="output_listen_endpoint"></a> [listen\_endpoint](#output\_listen\_endpoint) | host:port to point Flo clients (and the `flo` CLI) at. |
| <a name="output_metrics_endpoint"></a> [metrics\_endpoint](#output\_metrics\_endpoint) | Prometheus metrics endpoint. Empty when enable\_metrics = false. |
| <a name="output_raft_port"></a> [raft\_port](#output\_raft\_port) | TCP port used for Raft replication (listen\_port + 500). |
| <a name="output_urn"></a> [urn](#output\_urn) | Droplet URN, useful when wiring further DigitalOcean resources. |
<!-- END_TF_DOCS -->
