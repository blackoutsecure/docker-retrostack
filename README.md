# docker-emulationstation-de-emulator-provider

[![GitHub Stars](https://img.shields.io/github/stars/blackoutsecure/docker-emulationstation-de-emulator-provider?style=flat-square&logo=github)](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/stargazers)
[![Docker Pulls](https://img.shields.io/docker/pulls/blackoutsecure/esde-emulator-provider?style=flat-square&logo=docker)](https://hub.docker.com/r/blackoutsecure/esde-emulator-provider)
[![GitHub Release](https://img.shields.io/github/v/release/blackoutsecure/docker-emulationstation-de-emulator-provider?style=flat-square&logo=github)](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/releases)
[![Docker CI](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/actions/workflows/publish.yml/badge.svg)](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/actions/workflows/publish.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Emulator runtime images for [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de). Each image contains a fully installed emulator that runs games directly inside its own container — binaries are never exposed externally. ES-DE triggers game launches via a named pipe (FIFO) on a lightweight shared control volume.

Sponsored and maintained by [Blackout Secure](https://blackoutsecure.app/).

> [!IMPORTANT]
> This repository provides the **emulator sidecar** containers — not the ES-DE frontend itself.
> For the frontend, see [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de).

## Overview

Quick links:

- Docker Hub listing: [blackoutsecure/esde-emulator-provider](https://hub.docker.com/r/blackoutsecure/esde-emulator-provider)
- GitHub repository: [blackoutsecure/docker-emulationstation-de-emulator-provider](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider)
- ES-DE frontend container: [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de)
- Balena block metadata: [balena.yml](balena.yml)

## Table of Contents

- [docker-emulationstation-de-emulator-provider](#docker-emulationstation-de-emulator-provider)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Architecture](#architecture)
  - [Quick Start](#quick-start)
  - [Image Availability](#image-availability)
  - [Supported Architectures](#supported-architectures)
  - [Emulators](#emulators)
  - [Usage](#usage)
    - [Docker Compose (recommended)](#docker-compose-recommended)
    - [Docker CLI](#docker-cli)
    - [Balena Deployment](#balena-deployment)
  - [ES-DE Integration](#es-de-integration)
  - [Parameters](#parameters)
    - [Environment Variables](#environment-variables)
    - [Storage Mounts](#storage-mounts)
    - [Devices](#devices)
    - [Runtime Security Defaults](#runtime-security-defaults)
  - [Configuration](#configuration)
  - [Adding a New Emulator](#adding-a-new-emulator)
  - [Build Locally](#build-locally)
  - [Troubleshooting](#troubleshooting)
  - [Upstream Monitoring](#upstream-monitoring)
  - [Release & Versioning](#release--versioning)
  - [Support & Getting Help](#support--getting-help)
  - [References](#references)

## Architecture

```
┌──────────────────────────────┐                 ┌──────────────────────────┐
│  emulator-provider           │                 │  emulationstation-de     │
│  (this repo)                 │                 │  (separate repo)         │
│                              │                 │                          │
│  Emulator binary stays here  │  control pipe   │  User selects game       │
│  Listens on FIFO for launch  │◀────────────────│  esde-emulator-launch    │
│  commands, runs emulator on  │  /run/esde-emu/ │  writes command to FIFO  │
│  shared X11 display          │────────────────▶│  reads exit code back    │
│                              │  exit status    │                          │
└──────────────────────────────┘                 └──────────────────────────┘
        │                                                │
        ├── /dev/dri (GPU)                               ├── /dev/dri (GPU)
        ├── /dev/input (controllers)                     ├── /dev/input
        ├── /dev/snd (audio)                             ├── /dev/snd
        └── X11 socket                                   └── X11 socket
```

### Control Pipe Protocol

Both containers share a volume at `/run/esde-emulators/`. Each emulator creates:

| File | Direction | Purpose |
|------|-----------|---------|
| `<name>.cmd` | ES-DE → Emulator | FIFO — write emulator args (one line, shell-quoted) |
| `<name>.status` | Emulator → ES-DE | FIFO — read exit code after game finishes |

**No emulator binaries, libraries, or cores leave the emulator container.** Only the control pipes and shared display/GPU/input are exposed.

## Quick Start

Daemon mode — start emulator containers listening for ES-DE launch commands:

```bash
# Start RetroArch emulator container
docker compose --profile retroarch up -d

# Start all emulator containers
docker compose --profile all up -d
```

Standalone — run a game directly:

```bash
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  --device=/dev/input:/dev/input \
  --device=/dev/snd:/dev/snd \
  blackoutsecure/esde-emulator-provider:retroarch \
  --core gambatte /roms/gb/game.gb
```

## Image Availability

Docker Hub (Recommended):

- All images are published to [Docker Hub](https://hub.docker.com/r/blackoutsecure/esde-emulator-provider)
- Simple pull command: `docker pull blackoutsecure/esde-emulator-provider:retroarch`
- Multi-arch support: amd64, arm64
- No registry prefix needed when pulling from Docker Hub

```bash
# Pull RetroArch (default)
docker pull blackoutsecure/esde-emulator-provider:latest
docker pull blackoutsecure/esde-emulator-provider:retroarch

# Pull PPSSPP
docker pull blackoutsecure/esde-emulator-provider:ppsspp

# Pull Dolphin
docker pull blackoutsecure/esde-emulator-provider:dolphin-emu
```

## Supported Architectures

This image is published as a multi-arch manifest. Pulling `blackoutsecure/esde-emulator-provider:latest` retrieves the correct image for your host architecture.

The architectures supported by this image are:

| Architecture | Tags |
|-------------|------|
| x86-64 | `latest`, `retroarch`, `ppsspp`, `dolphin-emu` |
| arm64 | `latest`, `retroarch`, `ppsspp`, `dolphin-emu` |

## Emulators

| Tag | Emulator | Install Method | Upstream | License |
|-----|----------|---------------|----------|---------|
| `latest` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `retroarch` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `ppsspp` | PPSSPP (PSP) | Source build | [hrydgard/ppsspp](https://github.com/hrydgard/ppsspp) | GPL-2.0 |
| `dolphin-emu` | Dolphin (GC/Wii) | Source build | [dolphin-emu/dolphin](https://github.com/dolphin-emu/dolphin) | GPL-2.0 |

All images use `ghcr.io/linuxserver/baseimage-ubuntu:noble` as the runtime base (configurable via `BASE_IMAGE*` build args). Versions are tracked automatically by upstream monitor workflows and injected at build time via `--build-arg`.

## Usage

### Docker Compose (recommended)

Run a single emulator:

```yaml
---
services:
  retroarch:
    image: blackoutsecure/esde-emulator-provider:retroarch
    container_name: esde-retroarch
    environment:
      - DISPLAY=${DISPLAY:-:0}
      - PULSE_SERVER=${PULSE_SERVER:-unix:/run/pulse/native}
    volumes:
      - esde-emulator-control:/run/esde-emulators
      - /path/to/config:/config
      - /path/to/roms:/roms:ro
      - /path/to/bios:/bios:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
      - /dev/snd:/dev/snd
    tmpfs:
      - /var/tmp
      - /run:exec
    shm_size: 1gb
    restart: unless-stopped
```

Using profiles from the included [docker-compose.yml](docker-compose.yml):

```bash
# Start RetroArch only
docker compose --profile retroarch up -d

# Start all emulators
docker compose --profile all up -d
```

### Docker CLI

Standalone game launch (container exits when done):

```bash
# Game Boy game with RetroArch + gambatte core
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  --device=/dev/input:/dev/input \
  --device=/dev/snd:/dev/snd \
  blackoutsecure/esde-emulator-provider:retroarch \
  --core gambatte /roms/gb/game.gb

# PSP game with PPSSPP
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  blackoutsecure/esde-emulator-provider:ppsspp \
  /roms/psp/game.iso

# GameCube game with Dolphin
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  blackoutsecure/esde-emulator-provider:dolphin-emu \
  /roms/gc/game.iso
```

Daemon mode (container stays alive for ES-DE):

```bash
docker run -d \
  --name=esde-retroarch \
  --restart unless-stopped \
  -e DISPLAY=:0 \
  -v emu-ctl:/run/esde-emulators \
  -v /path/to/roms:/roms:ro \
  -v /path/to/bios:/bios:ro \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  --device=/dev/dri:/dev/dri \
  --device=/dev/input:/dev/input \
  --device=/dev/snd:/dev/snd \
  --shm-size=1gb \
  blackoutsecure/esde-emulator-provider:retroarch
```

### Balena Deployment

This image can be deployed to Balena-powered devices using the included [docker-compose.yml](docker-compose.yml) file (Balena labels are included and harmlessly ignored by standard Docker).

- Block metadata: [balena.yml](balena.yml)
- Compose file: [docker-compose.yml](docker-compose.yml)

```bash
balena push <your-app-slug>
```

See [Balena documentation](https://docs.balena.io/) for details.

## ES-DE Integration

When used with [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de), both containers share a control volume and the same X11 display. Emulator binaries never leave the emulator container:

1. **Startup**: Emulator container creates FIFO pipes at `/run/esde-emulators/<name>.cmd` and `.status`
2. **Discovery**: ES-DE installs `esde-emulator-launch` and symlinks each emulator name to it (e.g. `retroarch → esde-emulator-launch`)
3. **Game launch**: When the user selects a game, ES-DE calls the symlink. `esde-emulator-launch` writes the args to the `.cmd` pipe, the emulator container reads it and runs the game on the shared display
4. **Return**: When the game exits, the emulator container writes the exit code to the `.status` pipe. `esde-emulator-launch` reads it and returns, giving control back to ES-DE

### Combined docker-compose.yml

```yaml
volumes:
  esde-emulator-control:

services:
  emulationstation:
    image: blackoutsecure/emulationstation-de:latest
    container_name: emulationstation
    environment:
      - TZ=Etc/UTC
      - DISPLAY_NUM=0
      - XDG_RUNTIME_DIR=/run/esde
      - ESDE_USE_INTERNAL_X=1
      - UDEV=1
    volumes:
      - /path/to/config:/config
      - /path/to/roms:/roms:ro
      - /path/to/bios:/bios:ro
      - esde-emulator-control:/run/esde-emulators
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
      - /dev/snd:/dev/snd
    privileged: true
    shm_size: 1gb
    restart: unless-stopped

  retroarch:
    image: blackoutsecure/esde-emulator-provider:retroarch
    container_name: esde-retroarch
    environment:
      - DISPLAY=${DISPLAY:-:0}
    volumes:
      - esde-emulator-control:/run/esde-emulators
      - /path/to/roms:/roms:ro
      - /path/to/bios:/bios:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
      - /dev/snd:/dev/snd
    shm_size: 1gb
    restart: unless-stopped
```

### ES-DE Side Setup

Install `esde-emulator-launch` in the ES-DE container and create symlinks for each emulator:

```bash
# Copy the launch script from the emulator-provider image
docker cp esde-retroarch:/usr/local/bin/esde-emulator-launch /usr/local/bin/

# Create symlinks — ES-DE calls these by name
ln -sf /usr/local/bin/esde-emulator-launch /usr/local/bin/retroarch
ln -sf /usr/local/bin/esde-emulator-launch /usr/local/bin/PPSSPPSDL
ln -sf /usr/local/bin/esde-emulator-launch /usr/local/bin/dolphin-emu
```

### Startup Log Output

```
[esde-emulator:retroarch] Daemon mode — retroarch listening for game launch commands
[esde-emulator:retroarch] Version: RetroArch 1.22.2 (Git ...)
[esde-emulator:retroarch] Available libretro cores: 6
[esde-emulator:retroarch] Control pipe: /run/esde-emulators/retroarch.cmd
[esde-emulator:retroarch] Status pipe:  /run/esde-emulators/retroarch.status
```

## Parameters

### Environment Variables

| Parameter | Description | Required |
|-----------|-------------|----------|
| `-e EMULATOR_NAME` | Emulator identifier (set in image — `retroarch`, `ppsspp`, `dolphin-emu`) | Set per target |
| `-e EMULATOR_BINARY` | Path to emulator binary | Set per target |
| `-e EMULATOR_CORE` | Default libretro core for RetroArch | Optional |
| `-e DISPLAY=:0` | X11 display | Optional |
| `-e PULSE_SERVER` | PulseAudio server path | Optional |
| `-e ESDE_EMULATORS_CONTROL` | Control pipe directory (client-side) | Optional |

### Storage Mounts

| Mount | Description | Required |
|-------|-------------|----------|
| `-v /config` | Persistent emulator settings, saves, and states | Recommended |
| `-v /roms` | ROM library mount | Recommended |
| `-v /bios` | BIOS files for emulators that need them | Optional |
| `-v /run/esde-emulators` | FIFO control pipe volume (shared with ES-DE) | Required (daemon) |
| `-v /run/esde-shared` | Shared runtime — gamepad mappings, Xauthority | Optional |
| `-v /tmp/.X11-unix:/tmp/.X11-unix:ro` | X11 socket for display | Required |

### Devices

| Device | Description | Required |
|--------|-------------|----------|
| `--device=/dev/dri:/dev/dri` | GPU passthrough for Intel/AMD rendering | Optional |
| `--device=/dev/input:/dev/input` | Gamepad and input passthrough | Optional |
| `--device=/dev/snd:/dev/snd` | Audio device passthrough | Optional |

### Runtime Security Defaults

| Setting | Value | Purpose |
|---------|-------|---------|
| `read_only` | `false` | Keep root filesystem writable for LSIO init ownership setup |
| `tmpfs /var/tmp /run` | writable | Writable runtime scratch paths |
| `shm_size` | `1gb` | Shared memory for SDL and rendering stability |

## Configuration

The container stores persistent emulator data under `/config/<emulator-name>/`:

- **`/config`** — Persistent emulator settings, saves, and states. Recommended if you want data to survive restarts.
- **`/roms`** — Mount your ROM library read-only into the container.
- **`/bios`** — Supply BIOS files used by emulator backends.

### Best Practices

- Keep `/config` persistent so emulator saves and settings survive container recreation
- Mount `/roms` and `/bios` read-only unless you have a specific reason to allow writes
- Use the same ROM and BIOS volume mounts as your ES-DE container

## Adding a New Emulator

1. Add a `FROM ... AS <name>` stage to the `Dockerfile` (with a builder stage if compiling from source).
2. Set `ENV EMULATOR_NAME=<name>`, `ENV EMULATOR_BINARY=/path/to/binary`, and `ENV DISPLAY=:0`.
3. `COPY` scripts from `root/usr/local/bin/` and s6 services from `root/etc/s6-overlay/s6-rc.d`.
4. Add a service in `docker-compose.yml` with the control volume and GPU/input/display mounts.
5. Add a matrix entry in `publish.yml` (docker + manifest jobs) and `upstream-monitor.yml`.
6. On the ES-DE side, symlink `esde-emulator-launch` as the emulator name.

## Build Locally

```bash
# Build all emulators
docker compose --profile all build

# Build a single emulator
docker build --target retroarch -t blackoutsecure/esde-emulator-provider:retroarch .
docker build --target ppsspp -t blackoutsecure/esde-emulator-provider:ppsspp .
docker build --target dolphin-emu -t blackoutsecure/esde-emulator-provider:dolphin-emu .

# Override a tracked version
docker build --build-arg PPSSPP_VERSION=v1.20.3 --target ppsspp .
docker build --build-arg RETROARCH_VERSION=1.22.2 --target retroarch .
```

## Troubleshooting

### Emulator not launching

- Verify the emulator container is running: `docker ps | grep esde-`
- Check container logs: `docker logs esde-retroarch`
- Ensure `/dev/dri` is passed through for GPU access
- Verify `/tmp/.X11-unix` is mounted for X11 display

### Control pipe errors

- Ensure the `esde-emulator-control` volume is shared between ES-DE and the emulator container
- Check that the emulator container started successfully and created the FIFO pipes
- Look for `[esde-emulator-launch] ERROR: control pipe not found` in ES-DE logs
- Start the emulator container: `docker compose --profile retroarch up -d`

### Audio issues

- Ensure `/dev/snd` is passed through or `PULSE_SERVER` is set
- PulseAudio socket must be accessible at `/run/pulse/native`

### Input devices not detected

- Ensure the container has access to `/dev/input`
- Use `privileged: true` for full device access in kiosk/cabinet setups

### Gamepad Mapping

Each emulator image bundles the [SDL_GameControllerDB](https://github.com/gabomdq/SDL_GameControllerDB) community database (~3000 known gamepads). When running with ES-DE, the shared gamepad DB from the ES-DE container takes priority.

Mapping priority (highest first):

| Priority | Source | Description |
|----------|--------|-------------|
| 1 | `SDL_GAMECONTROLLERCONFIG` env var | User manual overrides |
| 2 | Shared DB from ES-DE (`/run/esde-shared/gamecontrollerdb.txt`) | ES-DE sidecar mappings |
| 3 | Bundled community `gamecontrollerdb.txt` | ~3000 known gamepads |
| 4 | SDL2 built-in DB | Major brand controllers (Xbox, PlayStation, Switch) |

If your gamepad isn't recognized:

1. Find your gamepad's SDL2 GUID — run `sdl2-jstest --list` inside the container
2. Generate a correct mapping at [SDL_GameControllerDB](https://github.com/gabomdq/SDL_GameControllerDB) or [General Arcade Gamepad Tool](https://generalarcade.com/gamepadtool/)
3. Set the mapping in your compose environment:

```yaml
environment:
  SDL_GAMECONTROLLERCONFIG: "03000000790000001100000000000000,DragonRise Generic USB Joystick,a:b2,b:b1,..."
```

## Upstream Monitoring

A [GitHub Actions workflow](.github/workflows/upstream-monitor.yml) monitors all three emulator upstreams every 6 hours:

| Emulator | Monitors | Rebuilds |
|----------|----------|----------|
| RetroArch | `libretro/RetroArch` releases + PPA version | `retroarch` target |
| PPSSPP | `hrydgard/ppsspp` releases | `ppsspp` target |
| Dolphin | `dolphin-emu/dolphin` releases/tags | `dolphin-emu` target |

Tracked versions are stored in `.github/upstream/*.json` and read by the publish/release workflows.

## Release & Versioning

- Stable Docker and Balena block publishing is handled by [.github/workflows/publish.yml](.github/workflows/publish.yml)
- GitHub release publishing is handled by [.github/workflows/release.yml](.github/workflows/release.yml)
- Upstream emulator release monitoring is handled by [.github/workflows/upstream-monitor.yml](.github/workflows/upstream-monitor.yml)

## Support & Getting Help

- GitHub repository: [blackoutsecure/docker-emulationstation-de-emulator-provider](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider)
- Docker Hub image: [blackoutsecure/esde-emulator-provider](https://hub.docker.com/r/blackoutsecure/esde-emulator-provider)
- ES-DE frontend container: [blackoutsecure/docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de)

## References

- [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de) — ES-DE frontend container
- [retroarch.com](https://retroarch.com/) · [ppa:libretro/stable](https://launchpad.net/~libretro/+archive/ubuntu/stable)
- [ppsspp.org](https://www.ppsspp.org/) · [dolphin-emu.org](https://dolphin-emu.org/)
- ES-DE: [https://es-de.org](https://es-de.org/)
- ES-DE source: [https://gitlab.com/es-de/emulationstation-de](https://gitlab.com/es-de/emulationstation-de)
- ES-DE user guide: [https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md](https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md)
- LSIO Ubuntu base image: [https://docs.linuxserver.io/images/docker-baseimage-ubuntu/](https://docs.linuxserver.io/images/docker-baseimage-ubuntu/)
- SDL_GameControllerDB (community gamepad mappings): [https://github.com/gabomdq/SDL_GameControllerDB](https://github.com/gabomdq/SDL_GameControllerDB)
