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
