#!/usr/bin/env bash

# Compatibility loader for the Local AI Toolkit modular library.

TOOLKIT_VERSION="v2.7.5"
TOOLKIT_NAME="Local AI Toolkit"

# Callers should set TOOLKIT_DIR to the directory containing this toolkit
# (install dir or the extracted source tree). Fall back to the new home.
TOOLKIT_DIR="${TOOLKIT_DIR:-$HOME/.local-ai-toolkit}"
LEGACY_TOOLKIT_DIR="${LEGACY_TOOLKIT_DIR:-$HOME/.super-orin-ai}"

# MODELS_DIR is rebound by detect_platform(). Keep a safe default.
MODELS_DIR="${MODELS_DIR:-$TOOLKIT_DIR/models}"

PLATFORM="${PLATFORM:-}"
BACKEND="${BACKEND:-}"
PLATFORM_LABEL="${PLATFORM_LABEL:-unknown}"
BACKEND_LABEL="${BACKEND_LABEL:-unknown}"

# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/platform.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/system.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/memory.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/profile.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/context.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/docker.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/webui.sh"
# shellcheck disable=SC1091
source "$TOOLKIT_DIR/lib/ui.sh"
