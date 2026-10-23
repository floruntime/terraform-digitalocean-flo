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
  flo_version = "v0.1.0-dev.13" # pin in production

  # The firewall opens only SSH unless you name who may connect.
  api_allowed_cidrs = ["203.0.113.0/24"]
}

output "endpoint"         { value = module.flo.listen_endpoint }
output "dashboard_tunnel" { value = module.flo.dashboard_ssh_tunnel }
```

```bash
terraform init
terraform apply

flo -e "$(terraform output -raw listen_endpoint)" kv set hello world
```

## Features

- **Single-droplet** provisioning with sensible defaults (Ubuntu
  24.04, `s-2vcpu-4gb`, `lon1`).
- **Cloud-init** installs the release's `.deb` (its sha256 checked),
  which brings the binary, the `flo` user and the `flo` systemd unit;
  writes a templated `flo.toml` into `/etc/flo/`; and starts the
  service. `flo_version` pins the release.
- **Optional cluster mode** — set `cluster_enabled = true` with a
  shared `cluster_secret`; one member sets `cluster_first_member`,
  the rest list its `peer_endpoint` in `cluster_seeds`. Members in
  one VPC (`vpc_uuid`) peer over private addresses, and the firewall
  opens the peer port (`listen_port + 500`) to that VPC only. Every
  peer proves the cluster secret at the handshake whichever network it
  comes from, so the private default is defence in depth, not the only
  guard. Members outside the VPC (another region, another provider)
  seed with `peer_endpoint_public` and need their addresses in
  `cluster_allowed_cidrs`.
- **Project attachment**, **monitoring**, and **backups** toggles
  for production hygiene.

## Port layout

Flo derives all secondary ports from `listen_port` (default `9000`):

| Service   | Port               |
|-----------|--------------------|
| Wire      | `listen_port`      |
| Metrics   | `listen_port + 1`  |
| Dashboard | `listen_port + 2`  |
| Peer port | `listen_port + 500`|

## Examples

| Path | What it shows |
|---|---|
| [`examples/minimal`](./examples/minimal) | Single node, module defaults: SSH only. |
| [`examples/cluster`](./examples/cluster) | Three-node cluster in one VPC: one first member, two joiners, reserved IPs. |

## After `terraform apply`

```bash
# Wire-protocol endpoint for the CLI / SDKs
flo -e "$(terraform output -raw listen_endpoint)" kv set hello world

# Dashboard: forward it over SSH, then open the URL
$(terraform output -raw dashboard_ssh_tunnel) &
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

To upgrade flo in place, install the newer release's `.deb`, keeping
the module's `flo.toml` (dpkg would otherwise ask, since it differs
from the package's default):

```bash
base=https://github.com/floruntime/flo/releases/download/<tag>
curl -fsSL -O "$base/flo_<version>_amd64.deb" -O "$base/flo_<version>_amd64.deb.sha256"
sha256sum -c flo_<version>_amd64.deb.sha256
apt-get install -y -o Dpkg::Options::=--force-confold ./flo_<version>_amd64.deb
```

The package restarts a running service on upgrade.

Droplets created by an older version of this module installed flo with
`install.sh` and their own unit at `/etc/systemd/system/flo.service`,
which overrides the package's: installing the `.deb` there "succeeds"
while the old `/usr/local/bin/flo` keeps running. Replace those
droplets, or first run
`rm /etc/systemd/system/flo.service /usr/local/bin/flo && systemctl daemon-reload`,
and move a custom `data_dir` to `/var/lib/flo`.

## Operational notes

- Flo runs as the `flo` system user under systemd. Logs:
  `journalctl -u flo -f`.
- Data lives in `/var/lib/flo`, owned by `flo:flo`, mode `0750`;
  the packaged unit lets Flo write nowhere else.
- The firewall opens only SSH by default. Name the ranges your
  clients connect from in `api_allowed_cidrs` to open the wire port.
- The dashboard listens on `listen_port + 2`, bound to `127.0.0.1`,
  and has no authentication yet. Reach it through an SSH tunnel:
  `ssh -N -L 9002:127.0.0.1:9002 root@<droplet>` (the
  `dashboard_ssh_tunnel` output prints this), then open
  `http://127.0.0.1:9002`. To open it on the network instead, set
  `dashboard_bind_address = "0.0.0.0"` and name the ranges in
  `dashboard_allowed_cidrs`; keep them narrow.
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
| [digitalocean_volume.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/volume) | resource |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_allowed_cidrs"></a> [api\_allowed\_cidrs](#input\_api\_allowed\_cidrs) | CIDR blocks allowed to reach the Flo wire-protocol port (var.listen\_port) and extra\_inbound\_tcp\_ports. Empty opens nothing: clients reach the node over SSH or the private network until you name them. | `list(string)` | `[]` | no |
| <a name="input_bind_address"></a> [bind\_address](#input\_bind\_address) | Address Flo binds the wire-protocol listener to. | `string` | `"0.0.0.0"` | no |
| <a name="input_cluster_allowed_cidrs"></a> [cluster\_allowed\_cidrs](#input\_cluster\_allowed\_cidrs) | CIDR blocks allowed to reach the peer port (listen\_port + 500). Only used when cluster\_enabled = true. null (the default) allows the droplet's VPC, which members seeded with peer\_endpoint reach each other over. List addresses to reach members outside it (seed those with peer\_endpoint\_public). | `list(string)` | `null` | no |
| <a name="input_cluster_enabled"></a> [cluster\_enabled](#input\_cluster\_enabled) | Make this droplet a cluster member. Requires cluster\_secret, and either cluster\_first\_member = true or cluster\_seeds. | `bool` | `false` | no |
| <a name="input_cluster_first_member"></a> [cluster\_first\_member](#input\_cluster\_first\_member) | This droplet starts the cluster: it leads a group of one until the others join it. Exactly one member of a new cluster sets this; it takes no cluster\_seeds. | `bool` | `false` | no |
| <a name="input_cluster_node_id"></a> [cluster\_node\_id](#input\_cluster\_node\_id) | This node's id within the cluster (1, 2, 3, ...). 0 derives one from hostname and port, which collides on cloned images; set it explicitly on members. | `number` | `0` | no |
| <a name="input_cluster_secret"></a> [cluster\_secret](#input\_cluster\_secret) | Shared secret every node of the cluster proves at the peer handshake; a node refuses to start its Raft listener without one. Make it once with `flo server secret` (Flo accepts no other form) and use the same value on every node. Required when cluster\_enabled = true. | `string` | `""` | no |
| <a name="input_cluster_seeds"></a> [cluster\_seeds](#input\_cluster\_seeds) | Peer endpoints of members to join ('host:port', the member's listen\_port + 500 — the module's peer\_endpoint output). Required when cluster\_enabled = true unless cluster\_first\_member = true. | `list(string)` | `[]` | no |
| <a name="input_create_firewall"></a> [create\_firewall](#input\_create\_firewall) | Create a DigitalOcean firewall in front of the droplet. Disable if you manage firewalls externally. | `bool` | `true` | no |
| <a name="input_dashboard_allowed_cidrs"></a> [dashboard\_allowed\_cidrs](#input\_dashboard\_allowed\_cidrs) | CIDR blocks allowed to reach the Flo dashboard / REST API (listen\_port + 2). Empty opens nothing. The dashboard has no authentication yet; naming CIDRs also needs dashboard\_bind\_address = "0.0.0.0". | `list(string)` | `[]` | no |
| <a name="input_dashboard_bind_address"></a> [dashboard\_bind\_address](#input\_dashboard\_bind\_address) | Address Flo binds the dashboard listener to. On loopback it is reached through an SSH tunnel (see the dashboard\_ssh\_tunnel output). | `string` | `"127.0.0.1"` | no |
| <a name="input_droplet_size"></a> [droplet\_size](#input\_droplet\_size) | DigitalOcean droplet size slug. Flo benefits from multiple vCPUs (one shard per CPU). | `string` | `"s-2vcpu-4gb"` | no |
| <a name="input_durability"></a> [durability](#input\_durability) | Storage durability mode. One of 'sync' (on disk before a write is acknowledged), 'async\_flush' (flushed within a second). | `string` | `"async_flush"` | no |
| <a name="input_enable_backups"></a> [enable\_backups](#input\_enable\_backups) | Enable weekly droplet backups. | `bool` | `false` | no |
| <a name="input_enable_dashboard"></a> [enable\_dashboard](#input\_enable\_dashboard) | Enable the dashboard HTTP API + web UI. | `bool` | `true` | no |
| <a name="input_enable_ipv6"></a> [enable\_ipv6](#input\_enable\_ipv6) | Enable IPv6 on the droplet. | `bool` | `true` | no |
| <a name="input_enable_metrics"></a> [enable\_metrics](#input\_enable\_metrics) | Enable the Prometheus metrics endpoint. | `bool` | `true` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enable DigitalOcean monitoring agent. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment label used in the droplet name and tags (e.g. 'dev', 'prod'). | `string` | `"dev"` | no |
| <a name="input_expose_metrics"></a> [expose\_metrics](#input\_expose\_metrics) | Open the metrics port (listen\_port + 1) on the firewall. Off by default; scrape via private network or DO monitoring instead. | `bool` | `false` | no |
| <a name="input_extra_inbound_tcp_ports"></a> [extra\_inbound\_tcp\_ports](#input\_extra\_inbound\_tcp\_ports) | Additional TCP ports to open inbound (gated by api\_allowed\_cidrs). | `list(number)` | `[]` | no |
| <a name="input_flo_version"></a> [flo\_version](#input\_flo\_version) | Flo release tag whose .deb to install (e.g. 'v0.1.0-dev.13'); its sha256 is checked. Empty means the newest release, prereleases included. Pin in production for reproducibility. | `string` | `""` | no |
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
| <a name="input_volume_filesystem_type"></a> [volume\_filesystem\_type](#input\_volume\_filesystem\_type) | Filesystem to format a freshly-created volume with. One of 'ext4' or 'xfs'. Existing filesystems on a re-attached volume are detected and never reformatted. | `string` | `"ext4"` | no |
| <a name="input_volume_name"></a> [volume\_name](#input\_volume\_name) | Name of the DigitalOcean volume. Must be lowercase alphanumeric or hyphen, 1-64 chars. Empty (default) auto-derives from the droplet name. Only used when volume\_size > 0. | `string` | `""` | no |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Size in GB of a DigitalOcean block-storage volume to provision and mount at /var/lib/flo, where Flo keeps its data. 0 (default) keeps Flo's data on the droplet's root disk; any positive value provisions a volume that survives droplet replacement. | `number` | `0` | no |
| <a name="input_vpc_uuid"></a> [vpc\_uuid](#input\_vpc\_uuid) | VPC to place the droplet in. Empty uses the region's default VPC. Cluster members in one VPC reach each other privately. | `string` | `""` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dashboard_ssh_tunnel"></a> [dashboard\_ssh\_tunnel](#output\_dashboard\_ssh\_tunnel) | SSH command that forwards the loopback-bound dashboard to the same port on your machine. Empty when the dashboard is disabled or not on loopback. |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | Dashboard / REST API URL. While the dashboard is bound to loopback this is the local end of the SSH tunnel (run dashboard\_ssh\_tunnel first). Empty when enable\_dashboard = false. |
| <a name="output_droplet_id"></a> [droplet\_id](#output\_droplet\_id) | DigitalOcean droplet ID. |
| <a name="output_droplet_name"></a> [droplet\_name](#output\_droplet\_name) | Droplet name. |
| <a name="output_firewall_id"></a> [firewall\_id](#output\_firewall\_id) | Firewall ID (empty when create\_firewall = false). |
| <a name="output_ipv4_address"></a> [ipv4\_address](#output\_ipv4\_address) | Public IPv4 address of the droplet. |
| <a name="output_ipv4_address_private"></a> [ipv4\_address\_private](#output\_ipv4\_address\_private) | Private IPv4 address (VPC), if assigned. |
| <a name="output_ipv6_address"></a> [ipv6\_address](#output\_ipv6\_address) | Public IPv6 address of the droplet (empty if disabled). |
| <a name="output_listen_endpoint"></a> [listen\_endpoint](#output\_listen\_endpoint) | host:port to point Flo clients (and the `flo` CLI) at. |
| <a name="output_metrics_endpoint"></a> [metrics\_endpoint](#output\_metrics\_endpoint) | Prometheus metrics endpoint. Empty when enable\_metrics = false. |
| <a name="output_peer_endpoint"></a> [peer\_endpoint](#output\_peer\_endpoint) | host:port, on the droplet's private (VPC) address, that joining members in the same VPC list in their cluster\_seeds (the peer port, listen\_port + 500). Empty when cluster\_enabled = false. |
| <a name="output_peer_endpoint_public"></a> [peer\_endpoint\_public](#output\_peer\_endpoint\_public) | host:port on the public address, for members outside this VPC; they also need their addresses in cluster\_allowed\_cidrs. Empty when cluster\_enabled = false. |
| <a name="output_raft_port"></a> [raft\_port](#output\_raft\_port) | The peer port members talk over (listen\_port + 500). |
| <a name="output_urn"></a> [urn](#output\_urn) | Droplet URN, useful when wiring further DigitalOcean resources. |
| <a name="output_volume_id"></a> [volume\_id](#output\_volume\_id) | DigitalOcean volume ID mounted at /var/lib/flo. Empty when volume\_size = 0. |
| <a name="output_volume_name"></a> [volume\_name](#output\_volume\_name) | DigitalOcean volume name. Empty when volume\_size = 0. |
| <a name="output_volume_urn"></a> [volume\_urn](#output\_volume\_urn) | DigitalOcean volume URN. Empty when volume\_size = 0. |
<!-- END_TF_DOCS -->
