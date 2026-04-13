# docker-emulationstation-de-emulator-provider

[![CI](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/actions/workflows/publish.yml/badge.svg)](https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider/actions/workflows/publish.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/blackoutsecure/esde-emulator-provider)](https://hub.docker.com/r/blackoutsecure/esde-emulator-provider)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Emulator runtime images for [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de). Each image contains a fully installed emulator that can run games directly — either as a standalone container or alongside ES-DE, which auto-discovers the provisioned binaries and launches them when a game is selected with the default emulator.

## Architecture

```
┌──────────────────────────────┐       ┌──────────────────────────┐
│  emulator-provider           │       │  emulationstation-de     │
│  (this repo)                 │       │  (separate repo)         │
│                              │       │                          │
│  On startup, provisions      │       │  Mounts same volume at   │
│  binaries + libs to /export/ │──vol──│  /emulators/             │
│  then stays alive (daemon)   │       │  svc-esde scans for      │
│  or runs game (standalone)   │       │  /emulators/*/bin/*      │
│                              │       │  esde-emuwrap exec's the │
│  Also works standalone:      │       │  emulator with correct   │
│  docker run ... <rom-path>   │       │  LD_LIBRARY_PATH         │
└──────────────────────────────┘       └──────────────────────────┘
```

### Volume Layout (provisioned to shared volume)

```
/export/<emulator-name>/         ← ES-DE mounts at /emulators/<emulator-name>/
├── bin/<emulator-name>          # Emulator binary
├── lib/                         # Non-system shared libraries
├── cores/                       # Libretro cores (RetroArch only)
├── VERSION                      # Version stamp
└── retroarch.cfg                # Default config (RetroArch only)
```

### Usage Modes

| Mode | Description | Command |
|------|-------------|---------|
| **Standalone** | Run a game directly, container exits when done | `docker run --rm ... :retroarch --core gambatte /roms/gb/game.gb` |
| **Daemon** | Container provisions and stays alive; ES-DE uses the provisioned binaries, or use `docker exec` for direct access | `docker run -d ... :retroarch` |
| **ES-DE Integration** | ES-DE selects game/emulator, `esde-emuwrap` exec's the provisioned binary from the shared volume | Automatic — see [ES-DE integration](#es-de-integration) |
| **Provision-only** | Copy binaries to shared volume and exit | `docker run -e EMULATOR_MODE=provision ... :retroarch` |

## Emulators

| Tag | Emulator | Install Method | Upstream | License |
|-----|----------|---------------|----------|---------|
| `latest` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `retroarch` | RetroArch + cores | PPA (`ppa:libretro/stable`) | [libretro/RetroArch](https://github.com/libretro/RetroArch) | GPL-3.0 |
| `ppsspp` | PPSSPP (PSP) | Source build | [hrydgard/ppsspp](https://github.com/hrydgard/ppsspp) | GPL-2.0 |
| `dolphin-emu` | Dolphin (GC/Wii) | Source build | [dolphin-emu/dolphin](https://github.com/dolphin-emu/dolphin) | GPL-2.0 |

All images use `ghcr.io/linuxserver/baseimage-ubuntu:noble` as the runtime base (configurable via `BASE_IMAGE*` build args). Versions are tracked automatically by upstream monitor workflows and injected at build time via `--build-arg`.

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
- X11 display server (host or container-internal)
- GPU passthrough (`/dev/dri`) for hardware-accelerated rendering
- ~4 GB disk space per emulator target (build stage)

## Quick Start

### Standalone — run a game directly

```bash
# Run a Game Boy game with RetroArch + gambatte core
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  --device=/dev/input:/dev/input \
  --device=/dev/snd:/dev/snd \
  blackoutsecure/esde-emulator-provider:retroarch \
  --core gambatte /roms/gb/game.gb

# Run a PSP game with PPSSPP
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  blackoutsecure/esde-emulator-provider:ppsspp \
  /roms/psp/game.iso

# Run a GameCube game with Dolphin
docker run --rm \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v /path/to/roms:/roms:ro \
  --device=/dev/dri:/dev/dri \
  blackoutsecure/esde-emulator-provider:dolphin-emu \
  /roms/gc/game.iso
```

### Daemon mode — keep container alive for ES-DE

```bash
# Start emulator containers in daemon mode (auto-provisions to /export/)
docker compose up -d

# ES-DE integration: ES-DE mounts the same volume at /emulators/
# and auto-discovers the provisioned binaries via esde-emuwrap.

# Direct access via docker exec also works:
docker exec esde-retroarch retroarch -L /usr/lib/libretro/gambatte_libretro.so /roms/gb/game.gb
docker exec esde-ppsspp PPSSPPSDL /roms/psp/game.iso
docker exec esde-dolphin-emu dolphin-emu-nogui /roms/gc/game.iso
```

### Build from source

```bash
# Build all emulators
docker compose build

# Build a single emulator
docker build --target retroarch -t blackoutsecure/esde-emulator-provider:retroarch .

# Override a tracked version
docker build --build-arg PPSSPP_VERSION=v1.20.3 --target ppsspp .
```

## ES-DE Integration

When used with [docker-emulationstation-de](https://github.com/blackoutsecure/docker-emulationstation-de), this container provisions emulator binaries onto a shared Docker volume and stays alive. ES-DE discovers and launches the emulators automatically:

1. **Startup**: Emulator container provisions binaries + libs to `/export/<name>/` (shared volume)
2. **Discovery**: ES-DE's `svc-esde` scans `/emulators/*/` and symlinks each `bin/<name>` via `esde-emuwrap`
3. **Game launch**: When the user selects a game, ES-DE calls `%EMULATOR_RETROARCH%` (or the appropriate emulator) — `esde-emuwrap` resolves the symlink, sets `LD_LIBRARY_PATH` to the bundled libs, and `exec`s the real binary
4. **Return**: When the user exits the game, control returns to ES-DE

The emulator runs **inside the ES-DE container's process space** using the provisioned binaries from the shared volume — no `docker exec` is needed for this flow.

### Combined docker-compose.yml

```yaml
volumes:
  emulationstation-emulators:

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
      - emulationstation-emulators:/emulators
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
      - emulationstation-emulators:/export
      - /path/to/roms:/roms:ro
      - /path/to/bios:/bios:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
      - /dev/snd:/dev/snd
    shm_size: 1gb
    restart: unless-stopped

  ppsspp:
    image: blackoutsecure/esde-emulator-provider:ppsspp
    container_name: esde-ppsspp
    environment:
      - DISPLAY=${DISPLAY:-:0}
    volumes:
      - emulationstation-emulators:/export
      - /path/to/roms:/roms:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
    devices:
      - /dev/dri:/dev/dri
      - /dev/input:/dev/input
      - /dev/snd:/dev/snd
    shm_size: 1gb
    restart: unless-stopped
```

### Startup log output (ES-DE side)

```
[svc-esde] Sidecar retroarch detected; linked via esde-emuwrap as /usr/local/bin/retroarch
[svc-esde]   Version: RetroArch 1.22.2 (Git ...)
[svc-esde] Found 6 libretro core(s).
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EMULATOR_NAME` | Emulator identifier (set in image) | Per target |
| `EMULATOR_BINARY` | Path to emulator binary | Per target |
| `EMULATOR_MODE` | `run` (default) or `provision` (provision-only, exits) | `run` |
| `EMULATOR_CORE` | Default libretro core for RetroArch | _(none)_ |
| `DISPLAY` | X11 display | `:0` |
| `PULSE_SERVER` | PulseAudio server path | _(none)_ |

## Adding a New Emulator

1. Add a `FROM ... AS <name>` stage to the Dockerfile (with a builder stage if compiling from source).
2. Set `ENV EMULATOR_NAME=<name>`, `ENV EMULATOR_BINARY=/path/to/binary`, and `ENV DISPLAY=:0`.
3. `COPY esde-provision` and `esde-emulator-run`, set `esde-emulator-run` as `ENTRYPOINT`.
4. Add a service in `docker-compose.yml` with GPU/input/display mounts.
5. Add a matrix entry in `publish.yml` (docker + manifest jobs) and `upstream-monitor.yml`.

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build — one target per emulator |
| `esde-emulator-run` | Entrypoint script — auto-provisions to `/export/` if mounted, then standalone launch or daemon mode |
| `esde-provision` | Provision script — copies binaries + libs + cores to `/export/<name>/` for ES-DE discovery |
| `docker-compose.yml` | Local dev/testing with display, device passthrough, and shared emulators volume |

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
