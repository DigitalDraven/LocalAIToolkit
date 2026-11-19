#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TOOLKIT_DIR="$ROOT"

check_platform() {
    local platform="$1" expected="$2" profile
    LAT_PLATFORM="$platform" EXPECTED_BACKEND="$expected" bash -c '
        set -euo pipefail
        source "$TOOLKIT_DIR/lib/common.sh"
        detect_platform
        [[ "$BACKEND" == "$EXPECTED_BACKEND" ]]
        discover_profiles
        ((${#PROFILES[@]} > 0))
        for profile in "${PROFILES[@]}"; do
            load_profile "$profile"
            validate_profile
        done
        printf "PASS %s (%s): %s profiles\\n" "$PLATFORM" "$BACKEND" "${#PROFILES[@]}"
    ' _ "$expected"
}

check_platform apple-m vllm-metal
check_platform orin-nano llamacpp
check_platform agx-thor vllm
check_platform dgx-spark vllm
