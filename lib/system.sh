#!/usr/bin/env bash

# System detection and host-state helpers.

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

gui_detected() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        return 0
    fi
    [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

power_mode() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        echo "Not applicable"
    elif command_exists nvpmodel; then
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
