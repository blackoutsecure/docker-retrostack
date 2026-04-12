# docker-emulationstation-de-emulator-provider

[![CI](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/actions/workflows/publish.yml/badge.svg)](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/actions/workflows/publish.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/blackoutsecure/esde-emulator-provider)](https://hub.docker.com/r/blackoutsecure/esde-emulator-provider)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Emulator sidecar images for [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de). Each image is an init-container that provisions an emulator binary, shared libraries, and (for RetroArch) libretro cores onto a shared Docker volume, then exits.

## Architecture

```
┌──────────────────────┐       ┌──────────────────────────┐
│  emulator-provider   │       │  emulationstation-de     │
│  (this repo)         │       │  (separate repo)         │
│                      │       │                          │
│  Provisions binaries │──────▶│  Mounts /emulators/      │
│  + libs to /export/  │  vol  │  esde-emuwrap exec's     │
│  then exits          │       │  emulator with correct   │
│                      │       │  LD_LIBRARY_PATH         │
└──────────────────────┘       └──────────────────────────┘
```

### Volume Layout

```
/export/<emulator-name>/
├── bin/<emulator-name>    # Emulator binary
├── lib/                   # Non-system shared libraries
├── cores/                 # Libretro cores (RetroArch only)
├── VERSION                # Version stamp
└── retroarch.cfg          # Default config (RetroArch only)
```

## Emulators

| Tag | Emulator | Install Method | Upstream | License |
|-----|----------|---------------|----------|---------|
| `latest` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `retroarch` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `ppsspp` | PPSSPP (PSP) | Source build | [hrydgard/ppsspp](https://github.com/hrydgard/ppsspp) | GPL-2.0 |
| `dolphin-emu` | Dolphin (GC/Wii) | Source build | [dolphin-emu/dolphin](https://github.com/dolphin-emu/dolphin) | GPL-2.0 |

All images use `ubuntu:noble` as the base. Versions are tracked automatically by upstream monitor workflows and injected at build time via `--build-arg`.

## Upstream Monitoring

A single [GitHub Actions workflow](.github/workflows/upstream-monitor.yml) monitors all three emulator upstreams every 6 hours:

| Emulator | Monitors | Rebuilds |
|----------|----------|----------|
| RetroArch | `libretro/RetroArch` releases + PPA version | `retroarch` target |
| PPSSPP | `hrydgard/ppsspp` releases | `ppsspp` target |
| Dolphin | `dolphin-emu/dolphin` releases/tags | `dolphin-emu` target |

Tracked versions are stored in `.github/upstream/*.json` and read by the publish/release workflows.

## Prerequisites

- Docker 24+ with BuildKit enabled
- Docker Compose v2 (for local dev)
- ~4 GB disk space per emulator target (build stage)

## Quick Start

```bash
# Pull the default emulator (RetroArch)
docker pull blackoutsecure/esde-emulator-provider:latest

# Build and run all sidecars
docker compose up --build

# Build a single emulator
docker build --target retroarch -t blackoutsecure/esde-emulator-provider:retroarch .

# Override a tracked version
docker build --build-arg PPSSPP_VERSION=v1.20.3 --target ppsspp .
```

## Adding a New Emulator

1. Add a `FROM ... AS <name>` stage to the Dockerfile (with a builder stage if compiling from source).
2. Set `ENV EMULATOR_NAME=<name>` and `ENV EMULATOR_BINARY=/path/to/binary`.
3. `COPY esde-provision` and set it as `ENTRYPOINT`.
4. Add a service in `docker-compose.yml`.
5. Add a matrix entry in `publish.yml` (docker + manifest jobs) and `upstream-monitor.yml`.

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build — one target per emulator |
| `esde-provision` | Entrypoint script — copies binaries + libs to `/export/` |
| `docker-compose.yml` | Local dev/testing |

## CI/CD

| Workflow | Purpose |
|----------|---------|
| [publish.yml](.github/workflows/publish.yml) | Build + push to Docker Hub on push/dispatch (matrix: target × arch) |
| [release.yml](.github/workflows/release.yml) | Versioned release tags on GitHub release |
| [upstream-monitor.yml](.github/workflows/upstream-monitor.yml) | Auto-rebuild on upstream changes (every 6h) |

## Licenses

This repo's packaging code is MIT licensed. Emulators retain their original licenses — see [LICENSE](LICENSE) for third-party notices.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

To report a vulnerability, please see [SECURITY.md](SECURITY.md).

## References

- [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de) — ES-DE frontend container
- [retroarch.com](https://retroarch.com/) · [ppa:libretro/stable](https://launchpad.net/~libretro/+archive/ubuntu/stable)
- [ppsspp.org](https://www.ppsspp.org/) · [dolphin-emu.org](https://dolphin-emu.org/)
