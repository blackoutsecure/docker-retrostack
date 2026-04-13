# syntax=docker/dockerfile:1.7
#
# RetroStack — modular emulator runtime images.
# Supports standalone mode and optional EmulationStation-DE integration.
#
# Build targets:
#   retroarch           — RetroArch + libretro cores (multi-system)
#   ppsspp              — PPSSPP (PlayStation Portable, source build)
#   dolphin-emu         — Dolphin (GameCube / Wii, source build)
#
# Build examples:
#   docker build --target retroarch   -t blackoutsecure/retrostack:retroarch .
#   docker build --target ppsspp      -t blackoutsecure/retrostack:ppsspp .
#   docker build --target dolphin-emu -t blackoutsecure/retrostack:dolphin-emu .
#
# Architecture:
#   runtime-base        — shared scripts, s6 services, gamepad DB, volumes
#     ├─ retroarch      — RetroArch packages on top of runtime-base
#     ├─ ppsspp         — PPSSPP binary (from ppsspp-build) on top of runtime-base
#     └─ dolphin-emu    — Dolphin binary (from dolphin-build) on top of runtime-base
#
# Each target produces a long-running container that either:
#   1) Runs a game directly (standalone mode)
#   2) Listens on a FIFO control pipe for game launch commands from ES-DE
#
# Standalone: run a game directly and exit.
# Service mode: listen on a FIFO control pipe (/run/retrostack-emulators/)
# for launch commands from ES-DE or any external caller.

# Base image — LinuxServer.io Ubuntu with s6-overlay init system.
ARG BASE_IMAGE_REGISTRY=ghcr.io
ARG BASE_IMAGE_NAME=linuxserver/baseimage-ubuntu
ARG BASE_IMAGE_VARIANT=noble
ARG BASE_IMAGE=${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}:${BASE_IMAGE_VARIANT}

# Upstream-tracked versions — injected by CI or overridden via --build-arg.
ARG RETROARCH_VERSION=1.22.0
ARG PPSSPP_VERSION=v1.20.3
ARG DOLPHIN_VERSION=2509
ARG VCS_URL=https://github.com/blackoutsecure/docker-retrostack

# ============================================================================
# Stage 0 — Shared runtime base
#
# Everything common to all emulator targets: scripts, s6-overlay service
# definitions, SDL2 gamepad mapping database, volumes, and entrypoint.
# Each emulator target inherits from this and only adds its own packages
# and binary.  BuildKit builds this in parallel with the builder stages.
# ============================================================================
FROM ${BASE_IMAGE} AS runtime-base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- Download SDL2 GameController community database ---
# Provides button mappings for ~3000 gamepads so SDL2 can recognise them.
# Without this, generic USB joysticks (e.g. DragonRise) are invisible to
# SDL2's GameController API and cannot be used by the emulator.
# Source: https://github.com/gabomdq/SDL_GameControllerDB  License: zlib
RUN curl -fsSL -o /usr/local/share/gamecontrollerdb.txt \
      https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt

COPY /root/usr/local/bin/retrostack-emulator-run   /usr/local/bin/retrostack-emulator-run
COPY /root/usr/local/bin/retrostack-emulator-launch /usr/local/bin/retrostack-emulator-launch
COPY /root/usr/local/bin/retrostack-provision       /usr/local/bin/retrostack-provision
COPY /root/etc/s6-overlay/s6-rc.d            /etc/s6-overlay/s6-rc.d

RUN set -eux; \
  echo "**** set permissions ****"; \
  chown -R root:root /etc/s6-overlay/s6-rc.d; \
  chmod 755 /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator \
            /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/dependencies.d; \
  chmod 755 /etc/s6-overlay/s6-rc.d/user/contents.d; \
  chmod 644 /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/type \
            /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/dependencies.d/init-services \
            /etc/s6-overlay/s6-rc.d/user/contents.d/svc-retrostack-emulator; \
  chmod 755 /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/run \
            /usr/local/bin/retrostack-emulator-run \
            /usr/local/bin/retrostack-emulator-launch \
            /usr/local/bin/retrostack-provision

VOLUME /run/retrostack-emulators
VOLUME /run/retrostack-shared
VOLUME /config
VOLUME /roms
VOLUME /bios

ENTRYPOINT ["/usr/local/bin/retrostack-emulator-run"]

# ============================================================================
# Stage 1a — PPSSPP builder (from source, runs in parallel with runtime-base)
# ============================================================================
FROM ubuntu:noble AS ppsspp-build
ARG PPSSPP_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates pkg-config \
      libsdl2-dev libgl1-mesa-dev libglu1-mesa-dev libgles-dev libegl-dev libvulkan-dev \
      libzip-dev libpng-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${PPSSPP_VERSION}" \
      --recurse-submodules --shallow-submodules \
      https://github.com/hrydgard/ppsspp.git /tmp/ppsspp && \
    cmake -S /tmp/ppsspp -B /tmp/ppsspp/build \
      -DUSING_QT_UI=OFF -DHEADLESS=OFF -DCMAKE_BUILD_TYPE=Release && \
    cmake --build /tmp/ppsspp/build -j"$(nproc)" --target PPSSPPSDL && \
    strip /tmp/ppsspp/build/PPSSPPSDL

# ============================================================================
# Stage 1b — Dolphin builder (from source, runs in parallel with runtime-base)
# ============================================================================
FROM ubuntu:noble AS dolphin-build
ARG DOLPHIN_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates pkg-config \
      libsdl2-dev libevdev-dev libxi-dev libudev-dev \
      libgl1-mesa-dev libegl-dev libvulkan-dev \
      libpulse-dev libasound2-dev libavcodec-dev libavformat-dev libswscale-dev \
      libusb-1.0-0-dev libhidapi-dev libbluetooth-dev \
      libcurl4-openssl-dev libfmt-dev libenet-dev \
      libminiupnpc-dev libpugixml-dev liblzo2-dev liblz4-dev libzstd-dev \
      libxrandr-dev libspng-dev libxxhash-dev \
      qt6-base-dev qt6-base-private-dev qt6-svg-dev && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${DOLPHIN_VERSION}" \
      --recurse-submodules --shallow-submodules \
      https://github.com/dolphin-emu/dolphin.git /tmp/dolphin && \
    cmake -S /tmp/dolphin -B /tmp/dolphin/build \
      -DCMAKE_BUILD_TYPE=Release -DENABLE_ANALYTICS=OFF -DENABLE_AUTOUPDATE=OFF && \
    cmake --build /tmp/dolphin/build -j"$(nproc)" && \
    strip /tmp/dolphin/build/Binaries/dolphin-emu \
          /tmp/dolphin/build/Binaries/dolphin-emu-nogui

# ============================================================================
# Stage 2a — RetroArch runtime (from ppa:libretro/stable)
#   docker build --target retroarch .
# ============================================================================
FROM runtime-base AS retroarch

ARG RETROARCH_VERSION
ARG VCS_URL

RUN echo "**** install RetroArch + libretro cores ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    gpg --keyserver hkp://keyserver.ubuntu.com:80 \
        --recv-keys 3B2BA0B6750986899B189AFF18DAAE7FECA3745F && \
    gpg --export 3B2BA0B6750986899B189AFF18DAAE7FECA3745F \
        > /etc/apt/keyrings/libretro.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/libretro.gpg] https://ppa.launchpadcontent.net/libretro/stable/ubuntu noble main" \
      > /etc/apt/sources.list.d/retroarch.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      retroarch libretro-core-info \
      libretro-gambatte libretro-mgba libretro-snes9x \
      libretro-nestopia libretro-genesisplusgx libretro-beetle-pce-fast && \
    echo "**** cleanup ****" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.title="retrostack:retroarch" \
      org.opencontainers.image.description="RetroArch + libretro cores runtime for RetroStack" \
      org.opencontainers.image.url="${VCS_URL}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.licenses="MIT AND GPL-3.0-or-later"

ENV EMULATOR_NAME=retroarch \
    EMULATOR_BINARY=/usr/bin/retroarch \
    DISPLAY=:0

# ============================================================================
# Stage 2b — PPSSPP runtime
#   docker build --target ppsspp .
# ============================================================================
FROM runtime-base AS ppsspp

ARG VCS_URL

RUN echo "**** install PPSSPP runtime dependencies ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libsdl2-2.0-0 libgl1 libegl1 libgles2 libvulkan1 \
      libzip4t64 libpng16-16t64 zlib1g && \
    echo "**** cleanup ****" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=ppsspp-build /tmp/ppsspp/build/PPSSPPSDL /usr/bin/PPSSPPSDL
COPY --from=ppsspp-build /tmp/ppsspp/build/assets /usr/local/share/ppsspp/assets

LABEL org.opencontainers.image.title="retrostack:ppsspp" \
      org.opencontainers.image.description="PPSSPP (PSP) runtime for RetroStack" \
      org.opencontainers.image.url="${VCS_URL}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later"

ENV EMULATOR_NAME=ppsspp \
    EMULATOR_BINARY=/usr/bin/PPSSPPSDL \
    DISPLAY=:0

# ============================================================================
# Stage 2c — Dolphin runtime
#   docker build --target dolphin-emu .
# ============================================================================
FROM runtime-base AS dolphin-emu

ARG VCS_URL

RUN echo "**** install Dolphin runtime dependencies ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libsdl2-2.0-0 libevdev2 libxi6 libudev1 \
      libgl1 libegl1 libvulkan1 \
      libpulse0 libasound2t64 libavcodec60 libavformat60 libswscale7 \
      libusb-1.0-0 libhidapi-hidraw0 libbluetooth3 \
      libcurl4t64 libfmt9 libenet7 \
      libminiupnpc17 libpugixml1v5 liblzo2-2 liblz4-1 libzstd1 \
      libxrandr2 libspng0 libxxhash0 \
      libqt6widgets6t64 libqt6gui6t64 libqt6core6t64 libqt6svg6 && \
    echo "**** cleanup ****" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=dolphin-build /tmp/dolphin/build/Binaries/dolphin-emu /usr/bin/dolphin-emu
COPY --from=dolphin-build /tmp/dolphin/build/Binaries/dolphin-emu-nogui /usr/bin/dolphin-emu-nogui

LABEL org.opencontainers.image.title="retrostack:dolphin-emu" \
      org.opencontainers.image.description="Dolphin (GameCube/Wii) runtime for RetroStack" \
      org.opencontainers.image.url="${VCS_URL}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later"

ENV EMULATOR_NAME=dolphin-emu \
    EMULATOR_BINARY=/usr/bin/dolphin-emu \
    DISPLAY=:0
