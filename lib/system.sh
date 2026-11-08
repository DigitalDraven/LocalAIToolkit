#!/usr/bin/env bash

# System detection and host-state helpers.

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

gui_detected() {
    [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

power_mode() {
    if command_exists nvpmodel; then
        nvpmodel -q 2>/dev/null | head -1
    else
        echo "unknown"
    fi
}

system_mode() {
    if gui_detected; then
        echo "GUI"
    else
        echo "Headless"
    fi
}
