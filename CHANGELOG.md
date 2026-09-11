# Changelog

All notable changes to this module are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

This module is pre-1.0 and tracks Flo's own pre-1.0 development.
Breaking changes can land on any minor bump (`0.x.0`) until
`v1.0.0`. Patch bumps (`0.x.y`) stay backwards-compatible.

## [Unreleased]

### Changed
- **Breaking.** A cluster is started by one member and joined by the
  rest: `cluster_first_member = true` on exactly one droplet (it takes
  no seeds), `cluster_seeds` on the others naming that droplet's
  `peer_endpoint` (`listen_port + 500`). A member list of every node's
  address on every node no longer starts (Flo refuses `enabled` and
  `seeds` together).
- `cluster_seeds` entries are peer endpoints (`listen_port + 500`), not
  gossip addresses; there is no gossip port any more. The firewall opens
  only the peer port; `gossip_endpoint` and `gossip_port` outputs are
  replaced by `peer_endpoint` and `raft_port`.
- `shards` must be `1` (or `0`) on a cluster member; a cluster
  replicates one shard for now.
- `expose_metrics = true` also binds the metrics listener to every
  interface; before, the firewall opened a port bound to loopback.
- `durability` takes Flo's values: `sync`, `async_flush`, `ephemeral`
  (`sync_flush` and `fsync` were never Flo's and were silently read as
  `async_flush`).

## [0.0.2] - 2026-05-09

### Added
- Optional persistent block-storage volume for `data_dir`. Set
  `volume_size > 0` to provision a `digitalocean_volume`, attach it
  to the droplet at boot, and mount it at `var.data_dir` via
  cloud-init (formats blank volumes with `var.volume_filesystem_type`,
  re-attached volumes keep their existing filesystem and data).
  The volume carries `prevent_destroy = true` so droplet replacement
  no longer wipes Flo state.
- New variables: `volume_size`, `volume_name`, `volume_filesystem_type`.
- New outputs: `volume_id`, `volume_name`, `volume_urn`.

### Changed
- Cloud-init now derives the systemd unit's `ReadWritePaths` and the
  `flo` user's home directory from `var.data_dir` (previously
  hard-coded to `/var/lib/flo`).

## [0.0.1] - 2026-05-09

### Added
- Initial public release.
- Single-droplet provisioning on DigitalOcean (droplet, firewall,
  optional project attachment).
- Cloud-init installs `flo` via the upstream `scripts/install.sh`,
  optionally pinned to `var.flo_version`.
- Templated `flo.toml` rendered from module inputs.
- Optional `cluster_enabled` mode: opens raft (`listen_port + 500`)
  and gossip (`listen_port + 600`) ports between cluster CIDRs and
  emits a `[cluster]` block with `node_id` + `seeds`.
- Examples: `minimal`, `cluster`.

[Unreleased]: https://github.com/floruntime/terraform-digitalocean-flo/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/floruntime/terraform-digitalocean-flo/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/floruntime/terraform-digitalocean-flo/releases/tag/v0.0.1
