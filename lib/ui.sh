#!/usr/bin/env bash

# User-interface helpers. Keep presentation separate from orchestration.

show_header() {
    echo "============================================================"
    printf "              Local AI Toolkit %s\n" "${TOOLKIT_VERSION:-v2.5}"
    echo "------------------------------------------------------------"
    printf "  Platform : %s\n" "$(platform_label)"
    printf "  Backend  : %s\n" "$(backend_label)"
    if [[ "${PLATFORM:-}" == "orin-nano" ]]; then
        printf "  Mode     : %s\n" "$(system_mode)"
    fi
    echo "============================================================"
}

show_dashboard() {
    echo
    printf "%-12s : %s\n" "Host" "$(hostname)"
    printf "%-12s : %s\n" "Platform" "$(platform_label)"
    printf "%-12s : %s\n" "Backend" "$(backend_label)"
    printf "%-12s : %s\n" "Mode" "$(system_mode)"
    printf "%-12s : %s\n" "Power" "$(power_mode)"
    printf "%-12s : %s\n" "RAM" "$(ram_summary)"
    printf "%-12s : %s\n" "Swap" "$(swap_summary)"
    printf "%-12s : %s\n" "Docker" "$(if docker_ok; then echo '✓'; else echo '✗'; fi)"
    printf "%-12s : %s\n" "Network" "$(if network_ok; then echo online; else echo offline; fi)"
    printf "%-12s : %s\n" "HF token" "$(hf_token_status)"
    if [[ "${BACKEND:-}" == "vllm" ]]; then
        if webui_running 2>/dev/null; then
            printf "%-12s : %s\n" "Open WebUI" "running (http://127.0.0.1:8080)"
        else
            printf "%-12s : %s\n" "Open WebUI" "not running"
        fi
    fi
    echo
}

show_model_menu() {
    local i p note
    echo "Select a model:"
    echo

    for i in "${!PROFILES[@]}"; do
        p="${PROFILES[$i]}"
        load_profile "$p" || continue

        if ! model_enabled; then
            printf "%d) %-28s %s\n" "$((i+1))" "$MODEL_NAME" "disabled"
            continue
        fi

        note="${MODEL_NOTE:-}"
        printf "%d) %-28s %s\n" "$((i+1))" "$MODEL_NAME" "$note"
    done

    echo "0) Exit"
    echo
}

show_runtime_menu() {
    echo
    echo "$MODEL_NAME"
    echo "------------------------------------------------------------"
    echo "Select llama.cpp runtime:"
    echo
    echo "1) Recommended (${RECOMMENDED_RUNTIME})"

    local i runtime
    for i in "${!RUNTIME_OPTIONS[@]}"; do
        runtime="${RUNTIME_OPTIONS[$i]}"
        case "$runtime" in
            nvidia-jetson) echo "$((i+2))) NVIDIA Jetson" ;;
            upstream) echo "$((i+2))) Upstream llama.cpp" ;;
            *) echo "$((i+2))) $runtime" ;;
        esac
    done

    echo "0) Cancel"
    echo
}

show_context_menu() {
    local rec i
    rec="$(recommended_context)"

    echo
    echo "$MODEL_NAME"
    echo "------------------------------------------------------------"
    echo "Mode: $(system_mode)"
    echo "Recommended context: $rec"
    echo
    echo "1) Auto / Recommended ($rec)"

    CONTEXT_ALTS=()
    for i in "${!COMMON_CONTEXTS[@]}"; do
        if [[ "${COMMON_CONTEXTS[$i]}" != "$rec" ]]; then
            CONTEXT_ALTS+=("${COMMON_CONTEXTS[$i]}")
        fi
    done

    for i in "${!CONTEXT_ALTS[@]}"; do
        echo "$((i+2))) ${CONTEXT_ALTS[$i]}"
    done

    local next=$(( ${#CONTEXT_ALTS[@]} + 2 ))
    echo "${next}) Custom"
    CONTEXT_CUSTOM_OPTION=$next

    echo "0) Cancel"
    echo
}

show_max_len_menu() {
    local rec i
    rec="$(recommended_max_len)"

    echo
    echo "$MODEL_NAME"
    echo "------------------------------------------------------------"
    echo "Recommended max model length: $rec"
    echo
    echo "1) Auto / Recommended ($rec)"

    CONTEXT_ALTS=()
    for i in "${!COMMON_MAX_LENS[@]}"; do
        if [[ "${COMMON_MAX_LENS[$i]}" != "$rec" ]]; then
            CONTEXT_ALTS+=("${COMMON_MAX_LENS[$i]}")
        fi
    done

    for i in "${!CONTEXT_ALTS[@]}"; do
        echo "$((i+2))) ${CONTEXT_ALTS[$i]}"
    done

    local next=$(( ${#CONTEXT_ALTS[@]} + 2 ))
    echo "${next}) Custom"
    CONTEXT_CUSTOM_OPTION=$next

    echo "0) Cancel"
    echo
}

show_diffusers_launch_summary() {
    echo
    echo "------------------------------------------------------------"
    echo "Model    : $MODEL_NAME"
    echo "Backend  : Diffusers"
    echo "Platform : $(platform_label)"
    echo "HF model : $HF_MODEL"
    echo "Mode     : ${DIFFUSERS_MODE:-stage_a}"
    echo "Pipeline : $DIFFUSERS_PIPELINE"
    echo "Image    : $IMAGE"
    echo "Output   : $HOME/${DIFFUSERS_OUTPUT_DIR:-local-ai-toolkit-output/${MODEL_ID}}"
    echo "HF token : $(hf_token_status)"
    echo "RAM      : $(free -h | awk '/^Mem:/ {print $7 " available"}')"
    echo "------------------------------------------------------------"
    echo
}

show_launch_summary() {
    echo
    echo "------------------------------------------------------------"
    echo "Model   : $MODEL_NAME"
    if [[ "${RUNTIME:-legacy}" == "nvidia-jetson" ]]; then
        echo "Runtime : NVIDIA Jetson ($RUNTIME_LABEL)"
    elif [[ "${RUNTIME:-legacy}" == "upstream" ]]; then
        echo "Runtime : Upstream llama.cpp ($RUNTIME_LABEL)"
    else
        echo "Runtime : ${RUNTIME:-legacy}"
    fi
    echo "Context : $CONTEXT ($CONTEXT_LABEL)"
    echo "Mode    : $(system_mode)"
    echo "RAM     : $(free -h | awk '/^Mem:/ {print $7 " available"}')"
    echo "------------------------------------------------------------"
    echo
}

show_vllm_launch_summary() {
    echo
    echo "------------------------------------------------------------"
    echo "Model    : $MODEL_NAME"
    echo "Backend  : vLLM"
    echo "Platform : $(platform_label)"
    echo "HF model : $HF_MODEL"
    echo "Max len  : $MAX_MODEL_LEN ($CONTEXT_LABEL)"
    echo "GPU util : ${GPU_MEMORY_UTILIZATION:-0.85}"
    echo "Port     : ${PORT:-8000}"
    echo "HF token : $(hf_token_status)"
    echo "RAM      : $(free -h | awk '/^Mem:/ {print $7 " available"}')"
    echo "------------------------------------------------------------"
    echo
}

show_launch_failure() {
    local rc="$1"
    echo
    echo "------------------------------------------------------------"
    echo "Model exited with status $rc."
    echo
    if [[ "${BACKEND:-llamacpp}" == "diffusers" ]]; then
        echo "If Stage A failed:"
        echo "  • check the Diffusers / bitsandbytes installation output"
        echo "  • confirm the Hugging Face token is present"
        echo "  • confirm the Cosmos3 model is cached or network access is available"
        echo "  • Stage B API integration is intentionally separate from Stage A"
    elif [[ "${BACKEND:-llamacpp}" == "vllm" ]]; then
        echo "If this was a memory / max-len failure:"
        echo "  • retry with a smaller max model length"
        echo "  • lower GPU_MEMORY_UTILIZATION in the profile"
        echo "  • confirm HF token is present for gated models"
        echo "  • NGC images may need: docker login nvcr.io"
    else
        echo "If this was a memory/context failure:"
        echo "  • retry with the recommended context"
        echo "  • use headless mode"
        echo "  • close memory-heavy applications"
    fi
    echo
    echo "No manual Docker cleanup is normally required."
    echo "------------------------------------------------------------"
}
