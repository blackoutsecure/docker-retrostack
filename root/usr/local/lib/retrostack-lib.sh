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
  chmod 700 "${XDG_RUNTIME_DIR}"
  if [[ -f "${RETROSTACK_SHARED_DIR}/.Xauthority" ]]; then
    export XAUTHORITY="${RETROSTACK_SHARED_DIR}/.Xauthority"
  fi
}

rs_setup_audio() {
  if [[ -S /run/pulse/native ]]; then
    export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"
  fi
}

# --- Raspberry Pi detection ---
rs_is_rpi() {
  if [[ -e /proc/device-tree/model ]]; then
    local model
    model="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)" || true
    [[ "${model}" == *"Raspberry"* ]] && return 0
  elif grep -qi 'raspberry\|bcm27\|bcm28' /proc/cpuinfo 2>/dev/null; then
    return 0
  fi
  return 1
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
  for d in /config/retroarch/retroarch/cores /usr/lib/libretro /usr/lib/*/libretro; do
    [[ -d "$d" ]] || continue
    [[ -f "$d/${core}_libretro.so" ]] && echo "$d/${core}_libretro.so" && return
    [[ -f "$d/${core}.so" ]] && echo "$d/${core}.so" && return
  done
  return 1
}

rs_count_cores() {
  local count=0 d f
  for d in /config/retroarch/retroarch/cores /usr/lib/libretro /usr/lib/*/libretro; do
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
  # Match host /dev/snd GID
  if [[ -e /dev/snd/controlC0 ]]; then
    local snd_gid
    snd_gid="$(stat -c '%g' /dev/snd/controlC0 2>/dev/null)" || true
    if [[ -n "${snd_gid}" && "${snd_gid}" != "0" ]]; then
      if ! id -G "${user}" 2>/dev/null | grep -qw "${snd_gid}"; then
        local snd_grp
        snd_grp="$(getent group "${snd_gid}" 2>/dev/null | cut -d: -f1)" || true
        if [[ -z "${snd_grp}" ]]; then
          groupadd -g "${snd_gid}" hostaudio 2>/dev/null || true
          snd_grp="hostaudio"
        fi
        usermod -aG "${snd_grp}" "${user}" 2>/dev/null || true
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

  local _audio_output="${RETROSTACK_AUDIO_OUTPUT:-auto}"

  # --- Load audio kernel modules ---
  # RPi 3.5mm analog output needs snd_bcm2835 (not loaded by default with vc4 driver)
  local _bcm2835_loaded=false
  if rs_is_rpi; then
    if modprobe snd_bcm2835 2>/dev/null; then
      local _bcm_wait
      for _bcm_wait in $(seq 1 10); do
        if grep -qi 'bcm2835\|Headphones' /proc/asound/cards 2>/dev/null; then
          _bcm2835_loaded=true
          break
        fi
        udevadm trigger --action=add --subsystem-match=sound 2>/dev/null || true
        sleep 0.5
      done
    fi
    if ! ${_bcm2835_loaded}; then
      rs_log "Warning: RPi 3.5mm analog audio NOT available."
      rs_log "  The snd_bcm2835 module did not create an ALSA card."
      rs_log "  To enable 3.5mm audio, set Balena device variable:"
      rs_log "    BALENA_HOST_CONFIG_dtparam = \"audio=on\""
      rs_log "  Then reboot the device."
    fi
  else
    modprobe snd_bcm2835 2>/dev/null || true
  fi

  # Load USB audio kernel module
  if [[ -d /dev/bus/usb ]]; then
    modprobe snd-usb-audio 2>/dev/null || true
    udevadm trigger --action=add --subsystem-match=sound 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true
  fi

  # Log ALSA cards
  if [[ -r /proc/asound/cards ]]; then
    local _alsa_cards
    _alsa_cards="$(grep -E '^\s*[0-9]' /proc/asound/cards | sed 's/.*\]: //' | tr '\n' ', ' | sed 's/, $//')" || true
    rs_log "ALSA cards: ${_alsa_cards:-none}"
  fi

  # Start our own PulseAudio
  if ! pulseaudio --check 2>/dev/null; then
    pulseaudio --start --exit-idle-time=-1 --daemonize=yes 2>/dev/null || {
      rs_log "Warning: PulseAudio failed to start"
      return
    }
  fi

  # Locate the PulseAudio socket.
  # docker-compose sets PULSE_SERVER=unix:/run/pulse/native for daemon mode
  # (ES-DE provides the socket), but in standalone mode the volume is empty
  # and PA creates its socket elsewhere depending on the user context.
  # Search common locations to find where PA is actually listening.
  local _pa_socket=""
  local _search_paths=(
    "${XDG_RUNTIME_DIR}/pulse/native"
    "/run/pulse/native"
    "/run/user/0/pulse/native"
    "/run/user/$(id -u)/pulse/native"
    "${HOME}/.config/pulse/native"
  )
  local _sp
  for _sp in "${_search_paths[@]}"; do
    if [[ -S "${_sp}" ]]; then
      _pa_socket="${_sp}"
      break
    fi
  done

  # If not found in known paths, ask PulseAudio directly
  if [[ -z "${_pa_socket}" ]]; then
    local _pa_info
    _pa_info="$(PULSE_SERVER= pactl info 2>/dev/null | grep -oP 'Server String: \K.*')" || true
    if [[ "${_pa_info}" == /* && -S "${_pa_info}" ]]; then
      _pa_socket="${_pa_info}"
    elif [[ "${_pa_info}" == unix:* ]]; then
      local _pa_path="${_pa_info#unix:}"
      [[ -S "${_pa_path}" ]] && _pa_socket="${_pa_path}"
    fi
  fi

  if [[ -n "${_pa_socket}" ]]; then
    export PULSE_SERVER="unix:${_pa_socket}"
  else
    # Last resort: let libpulse auto-discover
    unset PULSE_SERVER 2>/dev/null || true
  fi
  rs_log "PulseAudio running (PULSE_SERVER=${PULSE_SERVER:-<auto>})"

  # Fix PulseAudio card profiles for bcm2835
  if ${_bcm2835_loaded}; then
    local _bcm_card_index
    _bcm_card_index="$(pactl list short cards 2>/dev/null \
      | grep -i 'bcm2835\|Headphones' | head -1 | awk '{print $1}')" || true
    if [[ -n "${_bcm_card_index}" ]]; then
      pactl set-card-profile "${_bcm_card_index}" output:analog-stereo 2>/dev/null || \
        pactl set-card-profile "${_bcm_card_index}" analog-stereo 2>/dev/null || true
      sleep 1
    fi
  fi

  # Wait for USB audio devices to enumerate (up to 15s)
  if [[ -d /dev/bus/usb ]]; then
    local _usb_audio_found=false _usb_wait
    for _usb_wait in $(seq 1 15); do
      if grep -qi 'usb' /proc/asound/cards 2>/dev/null; then
        _usb_audio_found=true; break
      fi
      local _scard
      for _scard in /sys/class/sound/card*/device; do
        [[ -L "${_scard}" ]] || continue
        if [[ "$(basename "$(readlink -f "${_scard}/subsystem" 2>/dev/null)" 2>/dev/null)" == "usb" ]]; then
          _usb_audio_found=true; break 2
        fi
      done
      if (( _usb_wait % 5 == 0 )); then
        udevadm trigger --action=add --subsystem-match=sound 2>/dev/null || true
        udevadm settle --timeout=3 2>/dev/null || true
      fi
      sleep 1
    done
    if ${_usb_audio_found}; then
      rs_log "USB audio card(s) detected"
    elif [[ "${_audio_output}" == "usb" ]]; then
      rs_log "Warning: RETROSTACK_AUDIO_OUTPUT=usb but no USB audio cards found"
    fi
  fi

  # Ensure PulseAudio detection modules are loaded.
  # In containers, module-udev-detect may not auto-load or may fail silently.
  # Retry loading it, then fall back to module-alsa-detect, and finally
  # try creating sinks manually from /proc/asound/cards.
  local _initial_sinks
  _initial_sinks="$(pactl list short sinks 2>/dev/null)" || true
  if [[ -z "${_initial_sinks}" ]]; then
    # Re-trigger udev sound subsystem so PA's module-udev-detect picks up cards
    udevadm trigger --action=change --subsystem-match=sound 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true
    sleep 2

    _initial_sinks="$(pactl list short sinks 2>/dev/null)" || true
    if [[ -z "${_initial_sinks}" ]]; then
      # Try loading detection modules explicitly
      pactl load-module module-udev-detect 2>/dev/null || true
      pactl load-module module-alsa-detect 2>/dev/null || true
      sleep 2

      _initial_sinks="$(pactl list short sinks 2>/dev/null)" || true
      if [[ -z "${_initial_sinks}" ]] && [[ -r /proc/asound/cards ]]; then
        # Last resort: manually create ALSA sinks for each card
        rs_log "Auto-detect found no sinks — creating ALSA sinks manually"
        local _cnum
        while read -r _cnum; do
          [[ "${_cnum}" =~ ^[0-9]+$ ]] || continue
          pactl load-module module-alsa-sink "device=hw:${_cnum}" 2>/dev/null || true
        done < <(grep -oP '^\s*\K[0-9]+' /proc/asound/cards 2>/dev/null)
        sleep 1
      fi
    fi
  fi

  # Wait for a hardware ALSA sink (up to 30s) with priority selection
  # PulseAudio's module-udev-detect can take time to create sinks from ALSA cards.
  local _hw_sink="" _wait sink_list
  for _wait in $(seq 1 30); do
    sink_list="$(pactl list short sinks 2>/dev/null)" || true

    # Sink selection respects RETROSTACK_AUDIO_OUTPUT preference
    case "${_audio_output}" in
      analog)
        _hw_sink="$(echo "${sink_list}" | grep -i 'alsa_output.*\(analog\|stereo-fallback\)' | grep -iv 'hdmi' | head -1 | awk '{print $2}')" || true
        ;;
      hdmi)
        _hw_sink="$(echo "${sink_list}" | grep -i 'alsa_output.*hdmi' | head -1 | awk '{print $2}')" || true
        ;;
      usb)
        _hw_sink="$(echo "${sink_list}" | grep -i 'alsa_output.*usb' | head -1 | awk '{print $2}')" || true
        ;;
      *)
        # auto: Priority: 1) USB audio  2) 3.5mm analog  3) any ALSA (usually HDMI)
        _hw_sink="$(echo "${sink_list}" | grep -i 'alsa_output.*usb' | head -1 | awk '{print $2}')" || true
        if [[ -z "${_hw_sink}" ]]; then
          _hw_sink="$(echo "${sink_list}" | grep -i 'alsa_output.*\(analog\|stereo-fallback\)' | grep -iv 'hdmi' | head -1 | awk '{print $2}')" || true
        fi
        if [[ -z "${_hw_sink}" ]]; then
          _hw_sink="$(echo "${sink_list}" | grep -i 'alsa_output' | head -1 | awk '{print $2}')" || true
        fi
        ;;
    esac
    [[ -n "${_hw_sink}" ]] && break
    sleep 1
  done

  # Allow manual sink override
  if [[ -n "${RETROSTACK_AUDIO_SINK:-}" ]]; then
    _hw_sink="${RETROSTACK_AUDIO_SINK}"
  fi

  if [[ -n "${_hw_sink}" ]]; then
    pactl set-default-sink "${_hw_sink}" 2>/dev/null || true
    pactl set-sink-mute "${_hw_sink}" 0 2>/dev/null || true
    pactl set-sink-volume "${_hw_sink}" 100% 2>/dev/null || true
    rs_log "Audio sink: ${_hw_sink} (output=${_audio_output})"
  else
    # ALSA cards exist but PulseAudio couldn't create a usable sink
    local _all_sinks
    _all_sinks="$(pactl list short sinks 2>/dev/null)" || true
    rs_log "Warning: no usable PulseAudio sink found (output=${_audio_output})"
    if [[ -n "${_all_sinks}" ]]; then
      rs_log "  Available sinks (none matched '${_audio_output}'):"
      while IFS= read -r _s; do
        rs_log "    ${_s}"
      done <<< "${_all_sinks}"
    else
      rs_log "  PulseAudio found no sinks at all."
      rs_log "  ALSA cards were detected but PulseAudio could not use them."
    fi
    rs_log "  Ensure /dev/snd is passed through and speakers/HDMI display are connected."
    if rs_is_rpi; then
      rs_log "  RPi 3.5mm: set BALENA_HOST_CONFIG_dtparam=\"audio=on\" and reboot."
      rs_log "  RPi HDMI: set BALENA_HOST_CONFIG_hdmi_drive=2 if no sound over HDMI."
    fi
    return
  fi

  # Unmute ALSA mixer controls for all sound cards
  if command -v amixer >/dev/null 2>&1 && [[ -r /proc/asound/cards ]]; then
    local _cnum
    while read -r _cnum; do
      [[ "${_cnum}" =~ ^[0-9]+$ ]] || continue
      amixer -c "${_cnum}" sset 'PCM' 100% unmute 2>/dev/null || true
      amixer -c "${_cnum}" sset 'Master' 100% unmute 2>/dev/null || true
    done < <(grep -oP '^\s*\K[0-9]+' /proc/asound/cards 2>/dev/null)
  fi

  # Audio device wake — send a brief silence burst to force the ALSA device open.
  # HDMI: triggers ELD/EDID audio handshake.
  # bcm2835 analog: forces the PWM audio driver to initialize.
  if [[ -n "${_hw_sink}" && "${_hw_sink}" == alsa_output* ]]; then
    local _alsa_card
    _alsa_card="$(echo "${_hw_sink}" | grep -oP 'alsa_output\.\K[0-9]+')" || true
    if [[ -n "${_alsa_card}" ]] && command -v speaker-test >/dev/null 2>&1; then
      timeout 2 speaker-test -D "plughw:${_alsa_card},0" -t sine -f 0 -l 1 >/dev/null 2>&1 || true
    elif [[ -n "${_alsa_card}" ]] && command -v aplay >/dev/null 2>&1; then
      dd if=/dev/zero bs=1 count=8000 2>/dev/null | \
        aplay -D "plughw:${_alsa_card},0" -r 8000 -f S16_LE -c 2 -q 2>/dev/null || true
    fi
  fi
}
