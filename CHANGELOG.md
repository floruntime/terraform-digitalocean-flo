# Changelog

All notable changes to this module are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

This module is pre-1.0 and tracks Flo's own pre-1.0 development.
Breaking changes can land on any minor bump (`0.x.0`) until
`v1.0.0`. Patch bumps (`0.x.y`) stay backwards-compatible.

## [Unreleased]

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

[Unreleased]: https://github.com/floruntime/terraform-digitalocean-flo/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/floruntime/terraform-digitalocean-flo/releases/tag/v0.0.1
