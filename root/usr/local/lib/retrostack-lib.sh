#!/usr/bin/env bash
# retrostack-lib — Shared functions and constants for RetroStack scripts.
# Copyright (c) 2026 Blackout Secure (https://blackoutsecure.app). MIT License. See LICENSE.
set -euo pipefail

readonly RETROSTACK_CONTROL_DIR="${RETROSTACK_EMULATORS_CONTROL:-/run/retrostack-emulators}"
readonly RETROSTACK_SHARED_DIR="/run/retrostack-shared"
readonly RETROSTACK_GAMEPAD_DB="/usr/local/share/gamecontrollerdb.txt"

EMULATOR_NAME="${EMULATOR_NAME:-}"
EMULATOR_BINARY="${EMULATOR_BINARY:-}"

rs_log() { echo "[retrostack:${EMULATOR_NAME:-unknown}] $*"; }

rs_die() {
  rs_log "ERROR: $*" >&2
  exit 1
}

rs_require_emulator_name() {
  [[ -n "${EMULATOR_NAME}" ]] || rs_die "EMULATOR_NAME must be set"
  EMULATOR_BINARY="${EMULATOR_BINARY:-/usr/bin/${EMULATOR_NAME}}"
}

rs_validate_binary() {
  [[ -x "${EMULATOR_BINARY}" ]] || rs_die "binary not found: ${EMULATOR_BINARY}"
}

rs_setup_display() {
  export DISPLAY="${DISPLAY:-:0}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/retrostack}"
  mkdir -p "${XDG_RUNTIME_DIR}"
  if [[ -f "${RETROSTACK_SHARED_DIR}/.Xauthority" ]]; then
    export XAUTHORITY="${RETROSTACK_SHARED_DIR}/.Xauthority"
  fi
}

rs_setup_audio() {
  if [[ -S /run/pulse/native ]]; then
    export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"
  fi
}

rs_setup_gamepad() {
  if [[ -f "${RETROSTACK_SHARED_DIR}/gamecontrollerdb.txt" ]]; then
    export SDL_GAMECONTROLLERCONFIG_FILE="${RETROSTACK_SHARED_DIR}/gamecontrollerdb.txt"
    rs_log "Using shared gamepad DB"
  elif [[ -f "${RETROSTACK_GAMEPAD_DB}" ]]; then
    export SDL_GAMECONTROLLERCONFIG_FILE="${RETROSTACK_GAMEPAD_DB}"
  fi
}

rs_find_libretro_dir() {
  local d
  for d in /usr/lib/libretro /usr/lib/*/libretro; do
    [[ -d "$d" ]] && echo "$d" && return
  done
}

rs_resolve_core() {
  local core="$1"
  [[ "${core}" == /* ]] && echo "${core}" && return
  local d
  for d in /usr/lib/libretro /usr/lib/*/libretro; do
    [[ -d "$d" ]] || continue
    [[ -f "$d/${core}_libretro.so" ]] && echo "$d/${core}_libretro.so" && return
    [[ -f "$d/${core}.so" ]] && echo "$d/${core}.so" && return
  done
  return 1
}

rs_count_cores() {
  local count=0 d f
  for d in /usr/lib/libretro /usr/lib/*/libretro; do
    [[ -d "$d" ]] || continue
    for f in "$d"/*.so; do
      [[ -f "$f" ]] && count=$((count + 1))
    done
  done
  echo "$count"
}

rs_emulator_version() {
  timeout 5 "${EMULATOR_BINARY}" --version 2>&1 | head -n 1 || true
}

rs_retrostack_version() {
  if [[ -f /etc/retrostack-version ]]; then
    cat /etc/retrostack-version
  elif [[ -f /VERSION ]]; then
    cat /VERSION
  else
    echo "unknown"
  fi
}

rs_start_internal_x() {
  local display_num="${DISPLAY#:}"
  display_num="${display_num%%.*}"

  rm -f "/tmp/.X${display_num}-lock" 2>/dev/null || true
  rm -f "/tmp/.X11-unix/X${display_num}" 2>/dev/null || true
  mkdir -p /tmp/.X11-unix

  if [[ -f /etc/X11/Xwrapper.config ]]; then
    sed -i -e 's/console/anybody/g' /etc/X11/Xwrapper.config 2>/dev/null || true
    if ! grep -q '^needs_root_rights=yes$' /etc/X11/Xwrapper.config 2>/dev/null; then
      echo 'needs_root_rights=yes' >> /etc/X11/Xwrapper.config
    fi
  fi

  export XAUTHORITY="${XDG_RUNTIME_DIR}/.Xauthority"
  touch "${XAUTHORITY}"
  chmod 600 "${XAUTHORITY}"
  if command -v mcookie >/dev/null 2>&1 && command -v xauth >/dev/null 2>&1; then
    local cookie
    cookie="$(mcookie)"
    xauth -f "${XAUTHORITY}" remove "${DISPLAY}" >/dev/null 2>&1 || true
    xauth -f "${XAUTHORITY}" add "${DISPLAY}" . "${cookie}" >/dev/null 2>&1 || true
  fi

  rs_log "Starting internal Xorg on ${DISPLAY}"
  Xorg "${DISPLAY}" -nolisten tcp -novtswitch -keeptty -nocursor -auth "${XAUTHORITY}" \
    >/dev/null 2>&1 &
  _RS_XORG_PID=$!

  local i
  for i in $(seq 1 50); do
    [[ -S "/tmp/.X11-unix/X${display_num}" ]] && break
    sleep 0.1
  done

  if [[ ! -S "/tmp/.X11-unix/X${display_num}" ]]; then
    rs_log "ERROR: Xorg failed to start — check /dev/dri is mounted and container has access"
    wait "${_RS_XORG_PID}" 2>/dev/null || true
    return 1
  fi

  rs_log "Xorg started (PID ${_RS_XORG_PID})"
  return 0
}

rs_stop_internal_x() {
  if [[ -n "${_RS_XORG_PID:-}" ]]; then
    kill "${_RS_XORG_PID}" 2>/dev/null || true
    wait "${_RS_XORG_PID}" 2>/dev/null || true
    rs_log "Xorg stopped"
  fi
}

rs_setup_device_groups() {
  local user="${APP_USER:-abc}"
  local grp
  for grp in video render audio input; do
    if getent group "${grp}" >/dev/null 2>&1; then
      if ! id -nG "${user}" 2>/dev/null | grep -qw "${grp}"; then
        usermod -aG "${grp}" "${user}" 2>/dev/null || true
      fi
    fi
  done
  # Match host /dev/dri GID
  if [[ -e /dev/dri/card0 ]]; then
    local dri_gid
    dri_gid="$(stat -c '%g' /dev/dri/card0 2>/dev/null)" || true
    if [[ -n "${dri_gid}" && "${dri_gid}" != "0" ]]; then
      if ! id -G "${user}" 2>/dev/null | grep -qw "${dri_gid}"; then
        local dri_grp
        dri_grp="$(getent group "${dri_gid}" 2>/dev/null | cut -d: -f1)" || true
        if [[ -z "${dri_grp}" ]]; then
          groupadd -g "${dri_gid}" hostdri 2>/dev/null || true
          dri_grp="hostdri"
        fi
        usermod -aG "${dri_grp}" "${user}" 2>/dev/null || true
      fi
    fi
  fi
}

rs_setup_udev() {
  if pidof systemd-udevd >/dev/null 2>&1 || pidof udevd >/dev/null 2>&1; then
    return
  fi
  if [[ -x /usr/lib/systemd/systemd-udevd ]]; then
    /usr/lib/systemd/systemd-udevd --daemon 2>/dev/null || true
  elif command -v udevd >/dev/null 2>&1; then
    udevd --daemon 2>/dev/null || true
  else
    return
  fi
  udevadm trigger --action=add 2>/dev/null || true
  udevadm settle --timeout=5 2>/dev/null || true
  rs_log "udevd started"
}

rs_setup_pulse() {
  command -v pulseaudio >/dev/null 2>&1 || return
  # If an external PA socket is available, use it
  if [[ -S /run/pulse/native ]]; then
    export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"
    return
  fi
  # Start our own PulseAudio
  if ! pulseaudio --check 2>/dev/null; then
    pulseaudio --start --exit-idle-time=-1 --daemonize=yes 2>/dev/null || {
      rs_log "Warning: PulseAudio failed to start"
      return
    }
  fi
  # Wait for a hardware sink (up to 5s)
  local sink="" i
  for i in $(seq 1 10); do
    sink="$(pactl list short sinks 2>/dev/null | grep -i 'alsa_output' | head -1 | awk '{print $2}')" || true
    [[ -n "${sink}" ]] && break
    sleep 0.5
  done
  if [[ -n "${sink}" ]]; then
    pactl set-default-sink "${sink}" 2>/dev/null || true
    pactl set-sink-mute "${sink}" 0 2>/dev/null || true
    pactl set-sink-volume "${sink}" 100% 2>/dev/null || true
    rs_log "Audio sink: ${sink}"
  else
    rs_log "Warning: no ALSA audio sink detected"
  fi
}
