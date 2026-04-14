# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE_REGISTRY=ghcr.io
ARG BASE_IMAGE_NAME=linuxserver/baseimage-ubuntu
ARG BASE_IMAGE_VARIANT=noble
ARG BASE_IMAGE=${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}:${BASE_IMAGE_VARIANT}
ARG RETROSTACK_VERSION=1.0.0
ARG RETROARCH_VERSION=1.22.0
ARG PPSSPP_VERSION=v1.20.3
ARG DOLPHIN_VERSION=2509
ARG VCS_URL=https://github.com/blackoutsecure/docker-retrostack

# --- runtime-base ---
FROM ${BASE_IMAGE} AS runtime-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL -o /usr/local/share/gamecontrollerdb.txt \
      https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt
RUN mkdir -p /defaults/roms/gb \
  && curl -fsSL -o "/defaults/roms/gb/Libbet and the Magic Floor.gb" \
       https://github.com/pinobatch/libbet/releases/download/v0.08/libbet.gb
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       xserver-xorg-core xserver-xorg-input-libinput \
       xserver-xorg-video-dummy xinit x11-xserver-utils \
       pulseaudio udev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY root/ /tmp/retrostack-root/
COPY VERSION /etc/retrostack-version
RUN set -eux \
  && cp /tmp/retrostack-root/usr/local/lib/retrostack-lib.sh /usr/local/lib/retrostack-lib.sh \
  && cp /tmp/retrostack-root/usr/local/bin/retrostack-emulator-run /usr/local/bin/retrostack-emulator-run \
  && cp /tmp/retrostack-root/usr/local/bin/retrostack-emulator-launch /usr/local/bin/retrostack-emulator-launch \
  && cp /tmp/retrostack-root/usr/local/bin/retrostack-provision /usr/local/bin/retrostack-provision \
  && cp -rT /tmp/retrostack-root/etc/s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d \
  && rm -rf /tmp/retrostack-root \
  && chown -R root:root /etc/s6-overlay/s6-rc.d \
  && chmod 755 \
       /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator \
       /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/dependencies.d \
       /etc/s6-overlay/s6-rc.d/user/contents.d \
       /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/run \
       /usr/local/lib/retrostack-lib.sh \
       /usr/local/bin/retrostack-emulator-run \
       /usr/local/bin/retrostack-emulator-launch \
       /usr/local/bin/retrostack-provision \
  && chmod 644 \
       /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/type \
       /etc/s6-overlay/s6-rc.d/svc-retrostack-emulator/dependencies.d/init-services \
       /etc/s6-overlay/s6-rc.d/user/contents.d/svc-retrostack-emulator
VOLUME /run/retrostack-emulators /run/retrostack-shared /config /roms /bios
ENTRYPOINT ["/init"]

# --- ppsspp-build ---
FROM ubuntu:noble AS ppsspp-build
ARG PPSSPP_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates pkg-config \
      libsdl2-dev libgl1-mesa-dev libglu1-mesa-dev libgles-dev libegl-dev libvulkan-dev \
      libzip-dev libpng-dev zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${PPSSPP_VERSION}" \
      --recurse-submodules --shallow-submodules \
      https://github.com/hrydgard/ppsspp.git /tmp/ppsspp \
  && cmake -S /tmp/ppsspp -B /tmp/ppsspp/build \
       -DUSING_QT_UI=OFF -DHEADLESS=OFF -DCMAKE_BUILD_TYPE=Release \
  && cmake --build /tmp/ppsspp/build -j"$(nproc)" --target PPSSPPSDL \
  && strip /tmp/ppsspp/build/PPSSPPSDL

# --- dolphin-build ---
FROM ubuntu:noble AS dolphin-build
ARG DOLPHIN_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates pkg-config \
      libsdl2-dev libevdev-dev libxi-dev libudev-dev \
      libgl1-mesa-dev libegl-dev libvulkan-dev \
      libpulse-dev libasound2-dev libavcodec-dev libavformat-dev libswscale-dev \
      libusb-1.0-0-dev libhidapi-dev libbluetooth-dev \
      libcurl4-openssl-dev libfmt-dev libenet-dev \
      libminiupnpc-dev libpugixml-dev liblzo2-dev liblz4-dev libzstd-dev \
      libxrandr-dev libspng-dev libxxhash-dev \
      qt6-base-dev qt6-base-private-dev qt6-svg-dev \
  && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${DOLPHIN_VERSION}" \
      --recurse-submodules --shallow-submodules \
      https://github.com/dolphin-emu/dolphin.git /tmp/dolphin \
  && cmake -S /tmp/dolphin -B /tmp/dolphin/build \
       -DCMAKE_BUILD_TYPE=Release -DENABLE_ANALYTICS=OFF -DENABLE_AUTOUPDATE=OFF \
  && cmake --build /tmp/dolphin/build -j"$(nproc)" \
  && strip /tmp/dolphin/build/Binaries/dolphin-emu \
           /tmp/dolphin/build/Binaries/dolphin-emu-nogui

# --- retroarch ---
FROM runtime-base AS retroarch
ARG RETROSTACK_VERSION
ARG RETROARCH_VERSION
ARG VCS_URL
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates gnupg \
  && install -m 0755 -d /etc/apt/keyrings \
  && gpg --keyserver hkp://keyserver.ubuntu.com:80 \
         --recv-keys 3B2BA0B6750986899B189AFF18DAAE7FECA3745F \
  && gpg --export 3B2BA0B6750986899B189AFF18DAAE7FECA3745F \
         > /etc/apt/keyrings/libretro.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/libretro.gpg] https://ppa.launchpadcontent.net/libretro/stable/ubuntu noble main" \
       > /etc/apt/sources.list.d/retroarch.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       retroarch libretro-core-info \
       libretro-gambatte libretro-mgba libretro-snes9x \
       libretro-nestopia libretro-genesisplusgx libretro-beetle-pce-fast \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
LABEL org.opencontainers.image.title="retrostack:retroarch" \
      org.opencontainers.image.description="RetroArch + libretro cores runtime for RetroStack" \
      org.opencontainers.image.url="${VCS_URL}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.version="${RETROSTACK_VERSION}" \
      org.opencontainers.image.vendor="Blackout Secure" \
      io.retrostack.version="${RETROSTACK_VERSION}" \
      io.retrostack.emulator="retroarch" \
      io.retrostack.emulator.version="${RETROARCH_VERSION}" \
      org.opencontainers.image.licenses="MIT AND GPL-3.0-or-later"
ENV EMULATOR_NAME=retroarch EMULATOR_BINARY=/usr/bin/retroarch DISPLAY=:0

# --- ppsspp ---
FROM runtime-base AS ppsspp
ARG RETROSTACK_VERSION
ARG PPSSPP_VERSION
ARG VCS_URL
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       libsdl2-2.0-0 libgl1 libegl1 libgles2 libvulkan1 \
       libzip4t64 libpng16-16t64 zlib1g \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=ppsspp-build /tmp/ppsspp/build/PPSSPPSDL /usr/bin/PPSSPPSDL
COPY --from=ppsspp-build /tmp/ppsspp/build/assets /usr/local/share/ppsspp/assets
LABEL org.opencontainers.image.title="retrostack:ppsspp" \
      org.opencontainers.image.description="PPSSPP (PSP) runtime for RetroStack" \
      org.opencontainers.image.url="${VCS_URL}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.version="${RETROSTACK_VERSION}" \
      org.opencontainers.image.vendor="Blackout Secure" \
      io.retrostack.version="${RETROSTACK_VERSION}" \
      io.retrostack.emulator="ppsspp" \
      io.retrostack.emulator.version="${PPSSPP_VERSION}" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later"
ENV EMULATOR_NAME=ppsspp EMULATOR_BINARY=/usr/bin/PPSSPPSDL DISPLAY=:0

# --- dolphin-emu ---
FROM runtime-base AS dolphin-emu
ARG RETROSTACK_VERSION
ARG DOLPHIN_VERSION
ARG VCS_URL
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       libsdl2-2.0-0 libevdev2 libxi6 libudev1 \
       libgl1 libegl1 libvulkan1 \
       libpulse0 libasound2t64 libavcodec60 libavformat60 libswscale7 \
       libusb-1.0-0 libhidapi-hidraw0 libbluetooth3 \
       libcurl4t64 libfmt9 libenet7 \
       libminiupnpc17 libpugixml1v5 liblzo2-2 liblz4-1 libzstd1 \
       libxrandr2 libspng0 libxxhash0 \
       libqt6widgets6t64 libqt6gui6t64 libqt6core6t64 libqt6svg6 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=dolphin-build /tmp/dolphin/build/Binaries/dolphin-emu /usr/bin/dolphin-emu
COPY --from=dolphin-build /tmp/dolphin/build/Binaries/dolphin-emu-nogui /usr/bin/dolphin-emu-nogui
LABEL org.opencontainers.image.title="retrostack:dolphin-emu" \
      org.opencontainers.image.description="Dolphin (GameCube/Wii) runtime for RetroStack" \
      org.opencontainers.image.url="${VCS_URL}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.version="${RETROSTACK_VERSION}" \
      org.opencontainers.image.vendor="Blackout Secure" \
      io.retrostack.version="${RETROSTACK_VERSION}" \
      io.retrostack.emulator="dolphin-emu" \
      io.retrostack.emulator.version="${DOLPHIN_VERSION}" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later"
ENV EMULATOR_NAME=dolphin-emu EMULATOR_BINARY=/usr/bin/dolphin-emu DISPLAY=:0
