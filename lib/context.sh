#!/usr/bin/env bash

# Context (llama.cpp) and max-model-len (vLLM) helpers.
# Interactive menus use fixed ladders. Profile VALIDATED_* arrays remain
# for documentation, helpers, and future resource estimation.

# Fixed set shown in every llama.cpp context menu (order matters for muscle memory).
COMMON_CONTEXTS=(4096 8192 16384 32768 49152)

# Fixed set shown in every vLLM max-len menu.
COMMON_MAX_LENS=(8192 16384 32768 65536)

recommended_context() {
    local mode rec
    mode="$(system_mode)"

    if [[ "$mode" == "GUI" && -n "${GUI_RECOMMENDED_CONTEXT:-}" ]]; then
        rec="$GUI_RECOMMENDED_CONTEXT"
    elif [[ "$mode" == "Headless" && -n "${HEADLESS_RECOMMENDED_CONTEXT:-}" ]]; then
        rec="$HEADLESS_RECOMMENDED_CONTEXT"
    else
        rec="${RECOMMENDED_CONTEXT:-}"
    fi

    # Must be a positive integer; never return empty.
    if [[ "$rec" =~ ^[1-9][0-9]*$ ]]; then
        echo "$rec"
    else
        echo "4096"
    fi
}

recommended_max_len() {
    local rec="${RECOMMENDED_MAX_MODEL_LEN:-${MAX_MODEL_LEN:-65536}}"
    if [[ "$rec" =~ ^[1-9][0-9]*$ ]]; then
        echo "$rec"
    else
        echo "65536"
    fi
}

context_is_validated() {
    local context="$1"
    local item
    for item in "${VALIDATED_CONTEXTS[@]:-}"; do
        [[ "$item" == "$context" ]] && return 0
    done
    return 1
}

context_is_experimental() {
    local context="$1"
    local item
    for item in "${EXPERIMENTAL_CONTEXTS[@]:-}"; do
        [[ "$item" == "$context" ]] && return 0
    done
    return 1
}
