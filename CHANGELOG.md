# Changelog

All notable changes to this module are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

This module is pre-1.0 and tracks Flo's own pre-1.0 development.
Breaking changes can land on any minor bump (`0.x.0`) until
`v1.0.0`. Patch bumps (`0.x.y`) stay backwards-compatible.

## [Unreleased]

### Added
- `vpc_uuid`, to place members in one VPC, and the `peer_endpoint_public`
  output.

### Changed
- **Breaking.** The peer port accepts only the droplet's VPC by default
  (`cluster_allowed_cidrs = null`), and `peer_endpoint` is now the private
  address, so members in one VPC peer privately. To reach members outside the
  VPC, set `cluster_allowed_cidrs` to their addresses and seed with
  `peer_endpoint_public`. The peer link is authenticated by the cluster secret
  either way. `cluster_allowed_cidrs = []` is refused: it would open the port
  to nothing.
- Droplets install flo from the release's `.deb` (sha256 checked) instead of
  `scripts/install.sh` and a unit written by cloud-init: the binary, the `flo`
  user and the systemd unit come from the package, so the service is defined
  in one place and upgrades are package upgrades. The binary is now
  `/usr/bin/flo`. Needs a release that ships packages (v0.1.0-dev.13 or later).
  Droplets from earlier versions don't upgrade in place by installing the
  package: their own unit overrides it and keeps running
  `/usr/local/bin/flo`. Replace them, or remove that unit and binary first
  (README, "Cloud-init is at-most-once").
- With a volume, the service requires `/var/lib/flo` to be mounted, so a late
  or missing volume no longer starts flo on an empty root-disk directory.

### Removed
- **Breaking.** `data_dir`: Flo's data is always `/var/lib/flo`, the only path
  the packaged unit lets it write. A volume (`volume_size > 0`) mounts there.
- **Breaking.** `durability = "ephemeral"`: Flo now refuses it at startup,
  since nothing ever read it. Use `async_flush` or `sync`.

### Fixed
- Droplets install flo again. The installer came from flo's stale `master`
  branch, whose checksum step always failed, so no droplet got a binary. A
  pinned `flo_version` now takes the installer from that release's tag;
  empty takes dev's, which resolves the newest release, prereleases included.

### Changed
- **Breaking.** The firewall opens only SSH by default. `api_allowed_cidrs`
  now defaults to `[]`: name the ranges your clients connect from to open
  the wire port (and `extra_inbound_tcp_ports`).
- **Breaking.** The dashboard binds to `127.0.0.1` by default and
  `dashboard_allowed_cidrs` defaults to `[]`; it has no authentication yet.
  Reach it with the new `dashboard_ssh_tunnel` output, after which
  `dashboard_url` (now the tunnel's local end) opens it. To serve it on the
  network, set `dashboard_bind_address = "0.0.0.0"` and name the ranges.
- A crash-looping server no longer restarts forever: the systemd unit backs
  off from 5 s to 2 min between attempts and stops after 10 failed starts
  within an hour, leaving `flo` failed. Restore it with
  `systemctl reset-failed flo && systemctl start flo` once the cause is fixed.
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
- `durability` takes Flo's values: `sync`, `async_flush`
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
