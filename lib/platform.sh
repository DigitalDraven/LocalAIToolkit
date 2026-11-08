#!/usr/bin/env bash
# Platform detection. Sets PLATFORM, BACKEND, MODELS_DIR, PLATFORM_LABEL, BACKEND_LABEL.

_read_file_trim() {
    local f="$1"
    [[ -r "$f" ]] || { echo ""; return; }
    tr -d '\0\n' < "$f" 2>/dev/null || true
}

_bind_platform() {
    case "$PLATFORM" in
        orin-nano)
            BACKEND="llamacpp"
            MODELS_DIR="$TOOLKIT_DIR/models/orin-nano"
            PLATFORM_LABEL="Super Orin Nano"
            BACKEND_LABEL="llama.cpp"
            ;;
        agx-thor)
            BACKEND="vllm"
            MODELS_DIR="$TOOLKIT_DIR/models/agx-thor"
            PLATFORM_LABEL="Jetson AGX Thor"
            BACKEND_LABEL="vLLM"
            ;;
        dgx-spark)
            BACKEND="vllm"
            MODELS_DIR="$TOOLKIT_DIR/models/dgx-spark"
            PLATFORM_LABEL="DGX Spark"
            BACKEND_LABEL="vLLM"
            ;;
        *)
            echo "Internal error: unknown PLATFORM='$PLATFORM'" >&2
            exit 1
            ;;
    esac
}

_print_unsupported() {
    echo "ERROR: Unsupported platform."
    echo "  Device tree : ${1:-n/a}"
    echo "  DMI product : ${2:-n/a}"
    echo "  DMI vendor  : ${3:-n/a}"
    echo "  DMI family  : ${4:-n/a}"
    echo "  Tegra       : ${5:-n/a}"
    echo "  Chip id     : ${6:-n/a}"
    echo
    echo "  Supported   : Super Orin Nano, Jetson AGX Thor, DGX Spark"
    echo
    echo "  Override    : LAT_PLATFORM=orin-nano|agx-thor|dgx-spark"
}

detect_platform() {
    if [[ -n "${LAT_PLATFORM:-}" ]]; then
        case "$LAT_PLATFORM" in
            orin-nano|agx-thor|dgx-spark)
                PLATFORM="$LAT_PLATFORM"
                _bind_platform
                return 0
                ;;
            *)
                echo "ERROR: LAT_PLATFORM='$LAT_PLATFORM' is not valid (orin-nano|agx-thor|dgx-spark)" >&2
                exit 1
                ;;
        esac
    fi

    local dt product vendor family tegra chip blob
    dt="$(_read_file_trim /proc/device-tree/model)"
    product="$(_read_file_trim /sys/class/dmi/id/product_name)"
    vendor="$(_read_file_trim /sys/class/dmi/id/sys_vendor)"
    family="$(_read_file_trim /sys/class/dmi/id/product_family)"
    tegra="$(_read_file_trim /etc/nv_tegra_release)"
    chip="$(_read_file_trim /sys/devices/soc0/soc_id)"
    if [[ -z "$chip" ]]; then
        chip="$(_read_file_trim /sys/module/tegra_fuse/parameters/tegra_chip_id)"
    fi

    blob="$(printf '%s %s %s %s %s %s' "$dt" "$product" "$vendor" "$family" "$tegra" "$chip" | tr '[:upper:]' '[:lower:]')"

    # Thor before generic Jetson.
    if [[ "$blob" == *thor* || "$blob" == *t5000* || "$chip" == "26" || "$chip" == "0x26" \
        || "$blob" == *tegra264* || "$blob" == *t264* ]]; then
        PLATFORM="agx-thor"
        _bind_platform
        return 0
    fi

    if [[ "$blob" == *orin*nano* || "$blob" == *jetson*orin*nano* ]]; then
        PLATFORM="orin-nano"
        _bind_platform
        return 0
    fi

    # DGX Spark class (NVIDIA reference + OEM boxes).
    if [[ "$blob" == *dgx*spark* || "$blob" == *gb10* || "$blob" == *gx10* \
        || "$blob" == *nvidia_dgx_spark* || "$family" == *"DGX Spark"* \
        || "$product" == *"DGX Spark"* ]]; then
        PLATFORM="dgx-spark"
        _bind_platform
        return 0
    fi

    if [[ "$product" == *Spark* && "$vendor" == *NVIDIA* ]]; then
        PLATFORM="dgx-spark"
        _bind_platform
        return 0
    fi

    _print_unsupported "$dt" "$product" "$vendor" "$family" "$tegra" "$chip"
    exit 1
}

platform_label() { echo "${PLATFORM_LABEL:-unknown}"; }
backend_label() { echo "${BACKEND_LABEL:-unknown}"; }

hf_token_present() {
    [[ -n "${HF_TOKEN:-}" ]] && return 0
    [[ -s "$HOME/.cache/huggingface/token" ]]
}

hf_token_status() {
    if hf_token_present; then
        echo "present"
    else
        echo "missing"
    fi
}

warn_legacy_command() {
    local old new
    old="$(basename -- "${0:-}")"
    case "$old" in
        super-orin-add-model) new="ai-add-model" ;;
        super-orin-edit-model) new="ai-edit-model" ;;
        orin-status)          new="ai-status" ;;
        orin-mode)            new="ai-mode" ;;
        *) return 0 ;;
    esac
    echo "Note: '$old' is now '$new' (compat shim; will be removed in a later release)."
    echo
}
