<p align="center">
  <img src="https://raw.githubusercontent.com/blackoutsecure/docker-retrostack/main/logo.png" alt="RetroStack logo" width="200">
</p>

# RetroStack

[![GitHub Stars](https://img.shields.io/github/stars/blackoutsecure/docker-retrostack?style=flat-square&color=E7931D&logo=github)](https://github.com/blackoutsecure/docker-retrostack/stargazers)
[![Docker Pulls](https://img.shields.io/docker/pulls/blackoutsecure/docker-retrostack?style=flat-square&color=E7931D&logo=docker&logoColor=FFFFFF)](https://hub.docker.com/r/blackoutsecure/docker-retrostack)
[![GitHub Release](https://img.shields.io/github/release/blackoutsecure/docker-retrostack.svg?style=flat-square&color=E7931D&logo=github&logoColor=FFFFFF)](https://github.com/blackoutsecure/docker-retrostack/releases)
[![Docker CI](https://img.shields.io/github/actions/workflow/status/blackoutsecure/docker-retrostack/publish.yml?style=flat-square&label=docker%20ci&color=E7931D)](https://github.com/blackoutsecure/docker-retrostack/actions/workflows/publish.yml)
[![License](https://img.shields.io/github/license/blackoutsecure/docker-retrostack?style=flat-square)](LICENSE)

RetroStack: a modular Docker platform providing scalable, multi‑emulator support for retro gaming. Run emulators standalone or as composable services. Features include multi-arch images (amd64/arm64), profile-based emulator selection, persistent config/saves, gamepad auto-detection, and optional integration with [EmulationStation-DE](https://github.com/blackoutsecure/docker-emulationstation-de) via FIFO control pipes.

Sponsored and maintained by [Blackout Secure](https://blackoutsecure.app/).

> [!TIP]
> RetroStack can run standalone — no frontend required. For an optional frontend, see
> [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de) (also by Blackout Secure).

## Overview

This project packages upstream emulators (RetroArch, PPSSPP, Dolphin) into
ready-to-run container images for cabinets, desktops, HTPCs, and handheld Linux
systems. Each image runs standalone or listens for launch commands via FIFO
control pipes — ideal for integration with frontends like EmulationStation-DE.

Quick links:

- Docker Hub listing: [blackoutsecure/docker-retrostack](https://hub.docker.com/r/blackoutsecure/docker-retrostack)
- GitHub repository: [blackoutsecure/docker-retrostack](https://github.com/blackoutsecure/docker-retrostack)
- ES-DE frontend container: [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de)
- Balena block metadata: [balena.yml](balena.yml)

---

## Table of Contents

- [RetroStack](#retrostack)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Quick Start](#quick-start)
  - [Image Availability](#image-availability)
  - [About The Emulators](#about-the-emulators)
  - [Supported Architectures](#supported-architectures)
  - [Usage](#usage)
    - [Docker Compose (recommended, click here for more info)](#docker-compose-recommended-click-here-for-more-info)
    - [Docker CLI (click here for more info)](#docker-cli-click-here-for-more-info)
    - [Balena Deployment](#balena-deployment)
  - [ES-DE Integration](#es-de-integration)
    - [Control Pipe Protocol](#control-pipe-protocol)
    - [How It Works](#how-it-works)
    - [Combined docker-compose.yml](#combined-docker-composeyml)
    - [ES-DE Side Setup](#es-de-side-setup)
    - [Startup Log Output](#startup-log-output)
  - [Parameters](#parameters)
    - [Environment Variables](#environment-variables)
    - [Storage Mounts](#storage-mounts)
    - [Devices](#devices)
    - [Runtime Security Defaults](#runtime-security-defaults)
  - [Configuration](#configuration)
    - [`/config` - Emulator Settings and Persistence](#config---emulator-settings-and-persistence)
    - [`/roms` - Content Library](#roms---content-library)
    - [`/bios` - Emulator Support Files](#bios---emulator-support-files)
    - [Best Practices](#best-practices)
  - [Adding a New Emulator](#adding-a-new-emulator)
  - [Build Locally](#build-locally)
  - [Troubleshooting](#troubleshooting)
    - [Emulator not launching](#emulator-not-launching)
    - [Control pipe errors](#control-pipe-errors)
    - [Audio issues](#audio-issues)
    - [Input devices not detected](#input-devices-not-detected)
    - [Gamepad Mapping](#gamepad-mapping)
  - [Upstream Monitoring](#upstream-monitoring)
  - [Release \& Versioning](#release--versioning)
    - [Platform Version](#platform-version)
    - [Emulator Versions](#emulator-versions)
    - [Tag Scheme](#tag-scheme)
    - [Image Labels](#image-labels)
    - [CI Workflows](#ci-workflows)
  - [Support \& Getting Help](#support--getting-help)
  - [References](#references)

---

## Quick Start

> [!NOTE]
> **Not sure which emulator to pick?** Use RetroArch — it covers the widest range of systems
> (NES, SNES, GB/GBA, Genesis, PS1, and hundreds more) via libretro cores. It's the default
> and recommended choice for most users.

**Standalone — run a game directly (container exits when done):**

```bash
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  --device=/dev/input:/dev/input \
  --device=/dev/snd:/dev/snd \
  blackoutsecure/docker-retrostack:retroarch \
  --core gambatte /roms/gb/game.gb
```

**Service mode — start emulator containers using profiles:**

```bash
# Start RetroArch emulator container
docker compose --profile retroarch up -d

# Start all emulator containers
docker compose --profile all up -d
```

For compose examples, device passthrough, Balena deployment, and local build options, see [Usage](#usage) below.

---

## Image Availability

**Docker Hub (Recommended):**

- All images are published to [Docker Hub](https://hub.docker.com/r/blackoutsecure/docker-retrostack)
- Simple pull command: `docker pull blackoutsecure/docker-retrostack:retroarch`
- Multi-arch support: amd64, arm64
- No registry prefix needed when pulling from Docker Hub

```bash
# Pull RetroArch (default)
docker pull blackoutsecure/docker-retrostack:latest
docker pull blackoutsecure/docker-retrostack:retroarch

# Pull PPSSPP
docker pull blackoutsecure/docker-retrostack:ppsspp

# Pull Dolphin
docker pull blackoutsecure/docker-retrostack:dolphin-emu
```

---

## About The Emulators

RetroStack packages three upstream emulator projects into containerised runtimes.
Each runs as an independent service — pick only the emulators you need.
**RetroArch is the recommended default** — it handles the widest range of systems
via libretro cores. Use PPSSPP or Dolphin only if you need dedicated PSP or
GameCube/Wii support beyond what RetroArch provides.

| Tag | Emulator | Install Method | Upstream | License |
| :----: | --- | --- | --- | :---: |
| `latest` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `retroarch` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `ppsspp` | PPSSPP (PSP) | Source build | [hrydgard/ppsspp](https://github.com/hrydgard/ppsspp) | GPL-2.0 |
| `dolphin-emu` | Dolphin (GC/Wii) | Source build | [dolphin-emu/dolphin](https://github.com/dolphin-emu/dolphin) | GPL-2.0 |

All images use `ghcr.io/linuxserver/baseimage-ubuntu:noble` as the runtime base
(configurable via `BASE_IMAGE*` build args). Versions are tracked automatically
by upstream monitor workflows and injected at build time via `--build-arg`.

Upstream project details:

- RetroArch: [retroarch.com](https://retroarch.com/) · [ppa:libretro/stable](https://launchpad.net/~libretro/+archive/ubuntu/stable)
- PPSSPP: [ppsspp.org](https://www.ppsspp.org/) · [hrydgard/ppsspp](https://github.com/hrydgard/ppsspp)
- Dolphin: [dolphin-emu.org](https://dolphin-emu.org/) · [dolphin-emu/dolphin](https://github.com/dolphin-emu/dolphin)

---

## Supported Architectures

This image is published as a multi-arch manifest. Pulling `blackoutsecure/docker-retrostack:latest` retrieves the correct image for your host architecture.

The architectures supported by this image are:

| Architecture | Available Tags |
| :----: | --- |
| x86-64 | `latest`, `retroarch`, `ppsspp`, `dolphin-emu` |
| arm64 | `latest`, `retroarch`, `ppsspp`, `dolphin-emu` |

**Tag scheme:**

| Variant | Rolling | Platform-Pinned | Emulator-Pinned | Commit-Pinned |
| --- | --- | --- | --- | --- |
| RetroArch | `latest`, `retroarch` | `1.0.0`, `1.0.0-retroarch` | `retroarch-v1.22.2` | `retroarch-sha-<commit>` |
| PPSSPP | `ppsspp` | `1.0.0-ppsspp` | `ppsspp-v1.20.3` | `ppsspp-sha-<commit>` |
| Dolphin | `dolphin-emu` | `1.0.0-dolphin-emu` | `dolphin-emu-2509` | `dolphin-emu-sha-<commit>` |

---

## Usage

### Docker Compose (recommended, [click here for more info](https://docs.linuxserver.io/general/docker-compose))

Run a single emulator:

```yaml
---
services:
  retroarch:
    image: blackoutsecure/docker-retrostack:retroarch
    container_name: retrostack-retroarch
    environment:
      - DISPLAY=${DISPLAY:-:0}
      - PULSE_SERVER=${PULSE_SERVER:-unix:/run/pulse/native}
    volumes:
      - retrostack-emulator-control:/run/retrostack-emulators
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

### Docker CLI ([click here for more info](https://docs.docker.com/engine/reference/commandline/cli/))

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
  blackoutsecure/docker-retrostack:retroarch \
  --core gambatte /roms/gb/game.gb

# PSP game with PPSSPP
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  blackoutsecure/docker-retrostack:ppsspp \
  /roms/psp/game.iso

# GameCube game with Dolphin
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  blackoutsecure/docker-retrostack:dolphin-emu \
  /roms/gc/game.iso
```

Daemon mode (container stays alive for ES-DE):

```bash
docker run -d \
  --name=retrostack-retroarch \
  --restart unless-stopped \
  -e DISPLAY=:0 \
  -v emu-ctl:/run/retrostack-emulators \
  -v /path/to/roms:/roms:ro \
  -v /path/to/bios:/bios:ro \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  --device=/dev/dri:/dev/dri \
  --device=/dev/input:/dev/input \
  --device=/dev/snd:/dev/snd \
  --shm-size=1gb \
  blackoutsecure/docker-retrostack:retroarch
```

### Balena Deployment

This image can be deployed to Balena-powered devices using the included [docker-compose.yml](docker-compose.yml) file (Balena labels are included and harmlessly ignored by standard Docker).

- Block metadata: [balena.yml](balena.yml)
- Compose file: [docker-compose.yml](docker-compose.yml)

```bash
balena push <your-app-slug>
```

See [Balena documentation](https://docs.balena.io/) for details.

---

## ES-DE Integration

When used with [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de), both containers share a control volume and the same X11 display:

```
┌──────────────────────────────┐                 ┌──────────────────────────┐
│  RetroStack                  │                 │  emulationstation-de     │
│  (this repo)                 │                 │  (separate repo)         │
│                              │                 │                          │
│  Emulator binary stays here  │  control pipe   │  User selects game       │
│  Listens on FIFO for launch  │◀────────────────│  retrostack-emulator-    │
│  commands, runs emulator on  │  /run/retro*/   │  launch writes to FIFO   │
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

Both containers share a volume at `/run/retrostack-emulators/`. Each emulator creates:

| File | Direction | Purpose |
| :----: | :----: | --- |
| `<name>.cmd` | ES-DE → Emulator | FIFO — write emulator args (one line, shell-quoted) |
| `<name>.status` | Emulator → ES-DE | FIFO — read exit code after game finishes |

### How It Works

1. **Startup**: Emulator container creates FIFO pipes at `/run/retrostack-emulators/<name>.cmd` and `.status`
2. **Discovery**: ES-DE installs `retrostack-emulator-launch` and symlinks each emulator name to it (e.g. `retroarch → retrostack-emulator-launch`)
3. **Game launch**: When the user selects a game, ES-DE calls the symlink. `retrostack-emulator-launch` writes the args to the `.cmd` pipe, the emulator container reads it and runs the game on the shared display
4. **Return**: When the game exits, the emulator container writes the exit code to the `.status` pipe. `retrostack-emulator-launch` reads it and returns, giving control back to ES-DE

### Combined docker-compose.yml

```yaml
volumes:
  retrostack-emulator-control:

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
      - retrostack-emulator-control:/run/retrostack-emulators
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
      - /dev/snd:/dev/snd
    privileged: true
    shm_size: 1gb
    restart: unless-stopped

  retroarch:
    image: blackoutsecure/docker-retrostack:retroarch
    container_name: retrostack-retroarch
    environment:
      - DISPLAY=${DISPLAY:-:0}
    volumes:
      - retrostack-emulator-control:/run/retrostack-emulators
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

Install `retrostack-emulator-launch` in the ES-DE container and create symlinks for each emulator:

```bash
# Copy the launch script from the RetroStack image
docker cp retrostack-retroarch:/usr/local/bin/retrostack-emulator-launch /usr/local/bin/

# Create symlinks — ES-DE calls these by name
ln -sf /usr/local/bin/retrostack-emulator-launch /usr/local/bin/retroarch
ln -sf /usr/local/bin/retrostack-emulator-launch /usr/local/bin/PPSSPPSDL
ln -sf /usr/local/bin/retrostack-emulator-launch /usr/local/bin/dolphin-emu
```

### Startup Log Output

```
[retrostack:retroarch] Daemon mode — listening for launch commands
[retrostack:retroarch] Version: RetroArch 1.22.2 (Git ...)
[retrostack:retroarch] Available cores: 6
[retrostack:retroarch] Control: /run/retrostack-emulators/retroarch.cmd
```

---

## Parameters

### Environment Variables

| Parameter | Description | Required |
| :----: | --- | :---: |
| `-e EMULATOR_NAME` | Emulator identifier (set in image — `retroarch`, `ppsspp`, `dolphin-emu`) | Set per target |
| `-e EMULATOR_BINARY` | Path to emulator binary | Set per target |
| `-e EMULATOR_CORE` | Default libretro core for RetroArch | Optional |
| `-e DISPLAY=:0` | X11 display | Optional |
| `-e PULSE_SERVER` | PulseAudio server path | Optional |
| `-e RETROSTACK_EMULATORS_CONTROL` | Control pipe directory (client-side) | Optional |

### Storage Mounts

| Mount | Description | Required |
| :----: | --- | :---: |
| `-v /config` | Persistent emulator settings, saves, and states | Recommended |
| `-v /roms` | ROM library mount | Recommended |
| `-v /bios` | BIOS files for emulators that need them | Optional |
| `-v /run/retrostack-emulators` | FIFO control pipe volume (shared with ES-DE) | Required (daemon) |
| `-v /run/retrostack-shared` | Shared runtime — gamepad mappings, Xauthority | Optional |
| `-v /tmp/.X11-unix:/tmp/.X11-unix:ro` | X11 socket for display | Required |

### Devices

| Device | Description | Required |
| :----: | --- | :---: |
| `--device=/dev/dri:/dev/dri` | GPU passthrough for Intel/AMD rendering | Optional |
| `--device=/dev/input:/dev/input` | Gamepad and input passthrough | Optional |
| `--device=/dev/snd:/dev/snd` | Audio device passthrough | Optional |

### Runtime Security Defaults

| Setting | Value | Purpose |
| :----: | --- | --- |
| `read_only` | `false` | Keep root filesystem writable for LSIO init ownership setup |
| `tmpfs /var/tmp /run` | writable | Writable runtime scratch paths |
| `shm_size` | `1gb` | Shared memory for SDL and rendering stability |

---

## Configuration

The container stores persistent emulator data under `/config/<emulator-name>/`.

### `/config` - Emulator Settings and Persistence

- Required: No, but recommended if you want settings and saves to survive restarts
- Purpose: Stores emulator configuration, save games, save states, and logs
- Example: `-v /path/to/config:/config` or a named volume mapped to `/config`

### `/roms` - Content Library

- Required: Recommended
- Purpose: Mount your ROM library read-only into the container
- Example: `-v /path/to/roms:/roms:ro`

### `/bios` - Emulator Support Files

- Required: Optional
- Purpose: Supply BIOS files used by emulator backends that need them
- Example: `-v /path/to/bios:/bios:ro`

### Best Practices

- Keep `/config` persistent so emulator saves and settings survive container recreation
- Mount `/roms` and `/bios` read-only unless you have a specific reason to allow writes
- Use the same ROM and BIOS volume mounts as your ES-DE container when using ES-DE integration

---

## Adding a New Emulator

1. Add a `FROM ... AS <name>` stage to the `Dockerfile` (with a builder stage if compiling from source).
2. Set `ENV EMULATOR_NAME=<name>`, `ENV EMULATOR_BINARY=/path/to/binary`, and `ENV DISPLAY=:0`.
3. Add a service in `docker-compose.yml` with the control volume and GPU/input/display mounts.
4. Add a matrix entry in `publish.yml` (docker + manifest jobs) and `upstream-monitor.yml`.
5. On the ES-DE side, symlink `retrostack-emulator-launch` as the emulator name.

**Project layout:**

| Path | Purpose |
| --- | --- |
| `root/usr/local/lib/retrostack-lib.sh` | Shared functions and constants (sourced by all scripts) |
| `root/usr/local/bin/retrostack-emulator-run` | Container entrypoint (daemon + standalone modes) |
| `root/usr/local/bin/retrostack-emulator-launch` | Client-side FIFO launcher (installed in ES-DE container) |
| `root/usr/local/bin/retrostack-provision` | Export emulator binary + libs to shared volume |
| `root/etc/s6-overlay/s6-rc.d/` | s6-overlay service definitions |
| `VERSION` | RetroStack platform version (semver) |
| `.github/upstream/*.json` | Tracked upstream emulator versions |

---

## Build Locally

```bash
# Build all emulators
docker compose --profile all build

# Build a single emulator
docker build --target retroarch -t blackoutsecure/docker-retrostack:retroarch .
docker build --target ppsspp -t blackoutsecure/docker-retrostack:ppsspp .
docker build --target dolphin-emu -t blackoutsecure/docker-retrostack:dolphin-emu .

# Override a tracked version
docker build --build-arg PPSSPP_VERSION=v1.20.3 --target ppsspp .
docker build --build-arg RETROARCH_VERSION=1.22.2 --target retroarch .
```

---

## Troubleshooting

### Emulator not launching

- Verify the emulator container is running: `docker ps | grep retrostack-`
- Check container logs: `docker logs retrostack-retroarch`
- Ensure `/dev/dri` is passed through for GPU access
- Verify `/tmp/.X11-unix` is mounted for X11 display

### Control pipe errors

- Ensure the `retrostack-emulator-control` volume is shared between ES-DE and the emulator container
- Check that the emulator container started successfully and created the FIFO pipes
- Look for `[retrostack] ERROR: pipe not found` in ES-DE logs
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
| 2 | Shared DB from ES-DE (`/run/retrostack-shared/gamecontrollerdb.txt`) | ES-DE sidecar mappings |
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

---

## Upstream Monitoring

A [GitHub Actions workflow](.github/workflows/upstream-monitor.yml) monitors all three emulator upstreams every 6 hours:

| Emulator | Monitors | Rebuilds |
|----------|----------|----------|
| RetroArch | `libretro/RetroArch` releases + PPA version | `retroarch` target |
| PPSSPP | `hrydgard/ppsspp` releases | `ppsspp` target |
| Dolphin | `dolphin-emu/dolphin` releases/tags | `dolphin-emu` target |

Tracked versions are stored in `.github/upstream/*.json` and read by the publish/release workflows.

---

## Release & Versioning

RetroStack uses a **dual-version scheme**: a platform version for the packaging/scripts and independent emulator versions tracked from upstream.

### Platform Version

The RetroStack platform version (packaging, scripts, s6 services, CI) is tracked in the [`VERSION`](VERSION) file at the repo root and follows [Semantic Versioning](https://semver.org/):

- **Major**: Breaking changes to the control pipe protocol, volume layout, or environment interface
- **Minor**: New emulator targets, new features, non-breaking config changes
- **Patch**: Bug fixes, dependency updates, documentation

Current version: **1.0.0**

### Emulator Versions

Each emulator tracks its own upstream release independently. Versions are stored in `.github/upstream/*.json` and resolved at build time:

| Emulator | Version Source | Tracked File |
| :----: | --- | --- |
| RetroArch | [libretro/RetroArch](https://github.com/libretro/RetroArch) releases + PPA | `.github/upstream/retroarch-release.json` |
| PPSSPP | [hrydgard/ppsspp](https://github.com/hrydgard/ppsspp) releases | `.github/upstream/ppsspp-release.json` |
| Dolphin | [dolphin-emu/dolphin](https://github.com/dolphin-emu/dolphin) releases | `.github/upstream/dolphin-release.json` |

### Tag Scheme

| Tag Pattern | Example | Description |
| --- | --- | --- |
| `:latest` | `:latest` | Rolling latest (RetroArch) |
| `:<target>` | `:retroarch` | Rolling latest for emulator |
| `:<target>-<emu-version>` | `:retroarch-v1.22.2` | Pinned to emulator version |
| `:<rs-version>-<target>` | `:1.0.0-retroarch` | Pinned to RetroStack platform version |
| `:<rs-version>` | `:1.0.0` | Platform-pinned (RetroArch default) |
| `:<target>-sha-<commit>` | `:retroarch-sha-abc123` | Commit-pinned |

### Image Labels

Each image includes OCI and RetroStack-specific labels:

| Label | Value |
| --- | --- |
| `org.opencontainers.image.version` | RetroStack platform version |
| `org.opencontainers.image.vendor` | `Blackout Secure` |
| `io.retrostack.version` | RetroStack platform version |
| `io.retrostack.emulator` | Emulator name (`retroarch`, `ppsspp`, `dolphin-emu`) |
| `io.retrostack.emulator.version` | Upstream emulator version |

### CI Workflows

- Stable Docker and Balena block publishing: [.github/workflows/publish.yml](.github/workflows/publish.yml)
- GitHub release publishing: [.github/workflows/release.yml](.github/workflows/release.yml)
- Upstream emulator release monitoring (every 6 hours): [.github/workflows/upstream-monitor.yml](.github/workflows/upstream-monitor.yml)
- Version resolution: [.github/actions/resolve-versions/action.yml](.github/actions/resolve-versions/action.yml)

---

## Support & Getting Help

- GitHub repository: [blackoutsecure/docker-retrostack](https://github.com/blackoutsecure/docker-retrostack)
- Docker Hub image: [blackoutsecure/docker-retrostack](https://hub.docker.com/r/blackoutsecure/docker-retrostack)
- ES-DE frontend container: [blackoutsecure/docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de)

---

## References

- [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de) — ES-DE frontend container
- [retroarch.com](https://retroarch.com/) · [ppa:libretro/stable](https://launchpad.net/~libretro/+archive/ubuntu/stable)
- [ppsspp.org](https://www.ppsspp.org/) · [dolphin-emu.org](https://dolphin-emu.org/)
- ES-DE: [https://es-de.org](https://es-de.org/)
- ES-DE source: [https://gitlab.com/es-de/emulationstation-de](https://gitlab.com/es-de/emulationstation-de)
- ES-DE user guide: [https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md](https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md)
- LSIO Ubuntu base image: [https://docs.linuxserver.io/images/docker-baseimage-ubuntu/](https://docs.linuxserver.io/images/docker-baseimage-ubuntu/)
- SDL_GameControllerDB (community gamepad mappings): [https://github.com/gabomdq/SDL_GameControllerDB](https://github.com/gabomdq/SDL_GameControllerDB)
