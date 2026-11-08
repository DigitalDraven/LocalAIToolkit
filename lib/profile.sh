#!/usr/bin/env bash

# Model profile loading, discovery, and validation.

profile_defaults() {
    unset MODEL_ID MODEL_NAME ENABLED PROFILE_ORDER MODEL_NOTE IMAGE HF_MODEL VOLUME_PATH
    unset GPU_LAYERS FLASH_ATTN EXTRA_ARGS SERVER_COMMAND RECOMMENDED_CONTEXT
    unset VALIDATED_CONTEXTS EXPERIMENTAL_CONTEXTS
    unset GUI_RECOMMENDED_CONTEXT HEADLESS_RECOMMENDED_CONTEXT
    unset RECOMMENDED_RUNTIME RUNTIME_OPTIONS RUNTIME_NVIDIA_JETSON RUNTIME_UPSTREAM
    unset RUNTIME_IMAGE_NVIDIA_JETSON RUNTIME_VOLUME_NVIDIA_JETSON RUNTIME_SERVER_COMMAND_NVIDIA_JETSON
    unset RUNTIME_IMAGE_UPSTREAM RUNTIME_VOLUME_UPSTREAM RUNTIME_SERVER_COMMAND_UPSTREAM
    unset PORT HOST SHM_SIZE GPU_MEMORY_UTILIZATION MAX_MODEL_LEN
    unset RECOMMENDED_MAX_MODEL_LEN VALIDATED_MAX_MODEL_LENS
    unset TRUST_REMOTE_CODE NEEDS_HF_TOKEN VLLM_ARGS CHAT_TEMPLATE_KWARGS VLLM_PLUGINS ENV_VARS\n    unset DIFFUSERS_MODE DIFFUSERS_PLUGINS DIFFUSERS_PIP_PACKAGES DIFFUSERS_PIPELINE DIFFUSERS_ARGS DIFFUSERS_OUTPUT_DIR
    unset STARTUP_INTERFACE
}

load_profile() {
    local profile="$1"
    local file="$MODELS_DIR/$profile.conf"

    [[ -f "$file" ]] || return 1

    profile_defaults
    # shellcheck disable=SC1090
    source "$file"
}

model_enabled() {
    [[ "${ENABLED:-1}" == "1" ]]
}

discover_profiles() {
    local file profile order
    local -a entries=()

    for file in "$MODELS_DIR"/*.conf; do
        [[ -f "$file" ]] || continue

        profile="${file##*/}"
        profile="${profile%.conf}"
        load_profile "$profile" || continue
        [[ -n "${MODEL_ID:-}" && -n "${MODEL_NAME:-}" ]] || continue

        order="${PROFILE_ORDER:-9999}"
        [[ "$order" =~ ^[0-9]+$ ]] || order=9999
        entries+=("$(printf '%08d\t%s' "$order" "$profile")")
    done

    PROFILES=()
    if ((${#entries[@]})); then
        local tmp
        tmp="$(mktemp)"
        printf '%s\n' "${entries[@]}" | sort -n -k1,1 -k2,2 | cut -f2- > "$tmp"
        mapfile -t PROFILES < "$tmp"
        rm -f "$tmp"
    fi
}

validate_profile() {
    [[ -n "${MODEL_ID:-}" ]] || return 1
    [[ -n "${MODEL_NAME:-}" ]] || return 1

    if ! model_enabled; then
        return 0
    fi

    [[ -n "${IMAGE:-}" ]] || return 1
    [[ -n "${HF_MODEL:-}" ]] || return 1
    [[ -n "${VOLUME_PATH:-}" ]] || return 1

    # Optional v2.5 runtime extensions. Empty arrays are the normal default.
    [[ -n "${VLLM_PLUGINS+x}" ]] || VLLM_PLUGINS=()
    [[ -n "${ENV_VARS+x}" ]] || ENV_VARS=()

    if [[ "${BACKEND:-llamacpp}" == "vllm" ]]; then
        [[ -n "${RECOMMENDED_MAX_MODEL_LEN:-${MAX_MODEL_LEN:-}}" ]] || return 1
        return 0
    fi

    if [[ "${BACKEND:-llamacpp}" == "diffusers" ]]; then
        [[ -n "${DIFFUSERS_PIPELINE:-}" ]] || return 1
        [[ "${DIFFUSERS_MODE:-stage_a}" == "stage_a" || "${DIFFUSERS_MODE:-stage_a}" == "api" ]] || return 1
        [[ -n "${HF_MODEL:-}" ]] || return 1
        [[ -n "${VOLUME_PATH:-}" ]] || return 1
        [[ -n "${IMAGE:-}" ]] || return 1
        [[ -n "${DIFFUSERS_PIP_PACKAGES+x}" ]] || DIFFUSERS_PIP_PACKAGES=()
        [[ -n "${DIFFUSERS_PLUGINS+x}" ]] || DIFFUSERS_PLUGINS=()
        return 0
    fi

    [[ -n "${RECOMMENDED_CONTEXT:-}" ]] || return 1
    [[ "${RECOMMENDED_CONTEXT}" =~ ^[0-9]+$ ]] || return 1
}

apply_runtime() {
    local runtime="$1"

    case "$runtime" in
        nvidia-jetson)
            IMAGE="${RUNTIME_IMAGE_NVIDIA_JETSON:-${IMAGE:-}}"
            VOLUME_PATH="${RUNTIME_VOLUME_NVIDIA_JETSON:-${VOLUME_PATH:-}}"
            SERVER_COMMAND="${RUNTIME_SERVER_COMMAND_NVIDIA_JETSON-${SERVER_COMMAND:-}}"
            ;;
        upstream)
            IMAGE="${RUNTIME_IMAGE_UPSTREAM:-${IMAGE:-}}"
            VOLUME_PATH="${RUNTIME_VOLUME_UPSTREAM:-${VOLUME_PATH:-}}"
            SERVER_COMMAND="${RUNTIME_SERVER_COMMAND_UPSTREAM-${SERVER_COMMAND:-}}"
            ;;
        *)
            return 1
            ;;
    esac
    RUNTIME="$runtime"
}

runtime_is_available() {
    local runtime="$1"
    local item
    for item in "${RUNTIME_OPTIONS[@]:-}"; do
        [[ "$item" == "$runtime" ]] && return 0
    done
    return 1
}
