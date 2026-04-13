# syntax=docker/dockerfile:1
#
# Emulator runtime images for docker-emulationstation-de.
# Each target produces a long-running container that either:
#   1) Runs a game directly (standalone mode)
#   2) Stays alive for docker exec calls from the ES-DE frontend
#
# Build:  docker build --target retroarch -t blackoutsecure/esde-emulator-provider:retroarch .
# Override version: docker build --build-arg PPSSPP_VERSION=v1.20.3 --target ppsspp .

# Base image — LinuxServer.io Ubuntu with s6-overlay init system.
ARG BASE_IMAGE_REGISTRY=ghcr.io
ARG BASE_IMAGE_NAME=linuxserver/baseimage-ubuntu
ARG BASE_IMAGE_VARIANT=noble
ARG BASE_IMAGE=${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}:${BASE_IMAGE_VARIANT}

# Upstream-tracked versions — injected by CI or overridden via --build-arg.
ARG RETROARCH_VERSION=1.22.0
ARG PPSSPP_VERSION=v1.20.3
ARG DOLPHIN_VERSION=2509

# --- RetroArch (from ppa:libretro/stable) ------------------------------------
FROM ${BASE_IMAGE} AS retroarch

ARG RETROARCH_VERSION

RUN apt-get update && \
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
    apt-get clean && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.title="esde-emulator-provider:retroarch" \
      org.opencontainers.image.description="RetroArch + libretro cores runtime for ES-DE" \
      org.opencontainers.image.licenses="MIT AND GPL-3.0-or-later" \
      org.opencontainers.image.source="https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider"

ENV EMULATOR_NAME=retroarch \
    EMULATOR_BINARY=/usr/bin/retroarch \
    DISPLAY=:0

COPY --chmod=755 esde-provision /usr/local/bin/esde-provision
COPY --chmod=755 esde-emulator-run /usr/local/bin/esde-emulator-run
VOLUME /export
VOLUME /roms
VOLUME /bios
ENTRYPOINT ["/usr/local/bin/esde-emulator-run"]

# --- PPSSPP builder (from source) --------------------------------------------
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

# --- PPSSPP runtime -----------------------------------------------------------
ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS ppsspp

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libsdl2-2.0-0 libgl1 libegl1 libgles2 libvulkan1 \
      libzip4t64 libpng16-16t64 zlib1g && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=ppsspp-build /tmp/ppsspp/build/PPSSPPSDL /usr/bin/PPSSPPSDL
COPY --from=ppsspp-build /tmp/ppsspp/build/assets /usr/local/share/ppsspp/assets

LABEL org.opencontainers.image.title="esde-emulator-provider:ppsspp" \
      org.opencontainers.image.description="PPSSPP (PSP) runtime for ES-DE" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later" \
      org.opencontainers.image.source="https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider"

ENV EMULATOR_NAME=ppsspp \
    EMULATOR_BINARY=/usr/bin/PPSSPPSDL \
    DISPLAY=:0

COPY --chmod=755 esde-provision /usr/local/bin/esde-provision
COPY --chmod=755 esde-emulator-run /usr/local/bin/esde-emulator-run
VOLUME /export
VOLUME /roms
VOLUME /bios
ENTRYPOINT ["/usr/local/bin/esde-emulator-run"]

# --- Dolphin builder (from source) --------------------------------------------
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

# --- Dolphin runtime ----------------------------------------------------------
ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS dolphin-emu

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libsdl2-2.0-0 libevdev2 libxi6 libudev1 \
      libgl1 libegl1 libvulkan1 \
      libpulse0 libasound2t64 libavcodec60 libavformat60 libswscale7 \
      libusb-1.0-0 libhidapi-hidraw0 libbluetooth3 \
      libcurl4t64 libfmt9 libenet7 \
      libminiupnpc17 libpugixml1v5 liblzo2-2 liblz4-1 libzstd1 \
      libxrandr2 libspng0 libxxhash0 \
      libqt6widgets6t64 libqt6gui6t64 libqt6core6t64 libqt6svg6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=dolphin-build /tmp/dolphin/build/Binaries/dolphin-emu /usr/bin/dolphin-emu
COPY --from=dolphin-build /tmp/dolphin/build/Binaries/dolphin-emu-nogui /usr/bin/dolphin-emu-nogui

LABEL org.opencontainers.image.title="esde-emulator-provider:dolphin-emu" \
      org.opencontainers.image.description="Dolphin (GameCube/Wii) runtime for ES-DE" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later" \
      org.opencontainers.image.source="https://github.com/blackoutsecure/docker-emulationstation-de-emulator-provider"

ENV EMULATOR_NAME=dolphin-emu \
    EMULATOR_BINARY=/usr/bin/dolphin-emu \
    DISPLAY=:0

COPY --chmod=755 esde-provision /usr/local/bin/esde-provision
COPY --chmod=755 esde-emulator-run /usr/local/bin/esde-emulator-run
VOLUME /export
VOLUME /roms
VOLUME /bios
ENTRYPOINT ["/usr/local/bin/esde-emulator-run"]
