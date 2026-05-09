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
<!-- END_TF_DOCS -->
