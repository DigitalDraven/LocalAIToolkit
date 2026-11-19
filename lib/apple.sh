#!/usr/bin/env bash

# Apple Silicon native vLLM-Metal runtime and optional Colima/Open WebUI.

APPLE_VLLM_METAL_TAP="vllm-project/vllm-metal https://github.com/vllm-project/vllm-metal"
APPLE_VLLM_METAL_FORMULA="vllm-project/vllm-metal/vllm-metal"
APPLE_WEBUI_IMAGE="${WEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
APPLE_WEBUI_NAME="${WEBUI_NAME:-open-webui}"
APPLE_WEBUI_PORT="${WEBUI_HOST_PORT:-8080}"
APPLE_DOCKER_CONTEXT="colima"
APPLE_WEBUI_STARTED_BY_TOOLKIT=0

apple_brew_available() { command -v brew >/dev/null 2>&1; }
apple_network_ok() {
    curl -fLsS --connect-timeout 3 --max-time 6 -o /dev/null https://github.com/ 2>/dev/null \
        || curl -fLsS --connect-timeout 3 --max-time 6 -o /dev/null https://huggingface.co/ 2>/dev/null
}
apple_colima_available() { command -v colima >/dev/null 2>&1; }
apple_docker_available() { command -v docker >/dev/null 2>&1; }
apple_vllm_metal_available() {
    command -v vllm >/dev/null 2>&1 && { ! apple_brew_available || brew list --versions vllm-metal >/dev/null 2>&1; }
}
apple_colima_running() { apple_colima_available && colima status >/dev/null 2>&1; }
apple_metal_available() {
    command -v system_profiler >/dev/null 2>&1 && system_profiler SPDisplaysDataType 2>/dev/null | grep -qi 'Metal'
}
apple_docker_info() { apple_docker_available && docker --context "$APPLE_DOCKER_CONTEXT" info >/dev/null 2>&1; }
apple_webui_running() {
    apple_docker_info && docker --context "$APPLE_DOCKER_CONTEXT" ps --format '{{.Names}}' 2>/dev/null | grep -qx "$APPLE_WEBUI_NAME"
}
apple_webui_exists() {
    apple_docker_info && docker --context "$APPLE_DOCKER_CONTEXT" ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$APPLE_WEBUI_NAME"
}

apple_dashboard() {
    local osver model mem avail_mb total_mb swap_used swap_total
    osver="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
    model="$(sysctl -n hw.model 2>/dev/null || echo unknown)"
    mem="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GiB", $1/1073741824}')"
    printf "%-16s : %s (%s)\n" "macOS" "$osver" "$model"
    printf "%-16s : %s / %s\n" "Architecture" "$(uname -m)" "${mem:-unknown} unified memory"
    printf "%-16s : %s\n" "Homebrew" "$(if apple_brew_available; then brew --version | head -1; else echo 'not installed'; fi)"
    printf "%-16s : %s\n" "vLLM-Metal" "$(if apple_vllm_metal_available; then vllm --version 2>&1 | head -1; else echo 'not installed'; fi)"
    printf "%-16s : %s\n" "Metal GPU" "$(if apple_metal_available; then echo available; else echo 'not verified'; fi)"
    printf "%-16s : %s\n" "MLX" "$(if apple_vllm_metal_available; then echo 'bundled with vLLM-Metal; runtime verification on launch'; else echo 'provided by vLLM-Metal installation'; fi)"
    printf "%-16s : %s\n" "Colima" "$(if apple_colima_running; then echo 'running'; elif apple_colima_available; then echo 'installed, stopped'; else echo 'not installed'; fi)"
    printf "%-16s : %s\n" "Docker CLI" "$(if apple_docker_available; then docker --version 2>/dev/null; else echo 'not installed'; fi)"
    printf "%-16s : %s\n" "Docker engine" "$(if apple_docker_info; then echo 'Colima context reachable'; else echo 'not reachable'; fi)"
    printf "%-16s : %s\n" "Open WebUI" "$(if apple_webui_running; then echo "running (http://127.0.0.1:${APPLE_WEBUI_PORT})"; else echo 'not running'; fi)"
    printf "%-16s : %s\n" "Network" "$(if apple_network_ok; then echo online; else echo offline; fi)"
    printf "%-16s : %s\n" "HF cache" "$(if [[ -d "$HOME/.cache/huggingface/hub" ]]; then echo present; else echo 'not found'; fi)"
}

apple_doctor() {
    local osver model mem
    osver="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
    model="$(sysctl -n hw.model 2>/dev/null || echo unknown)"
    mem="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GiB", $1/1073741824}')"
    pass "Apple Silicon" "$(uname -m) / $model"
    local os_major
    os_major="$(printf '%s' "$osver" | cut -d. -f1)"
    if [[ "$os_major" =~ ^[0-9]+$ ]] && (( os_major >= 15 )); then pass "macOS" "$osver"; else fail "macOS" "$osver (vLLM-Metal requires 15+)"; fi
    pass "Unified memory" "${mem:-unknown}"
    avail_mb="$(ram_available_mb)"
    total_mb="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1048576}')"
    if [[ "$avail_mb" =~ ^[0-9]+$ ]]; then
        if (( avail_mb < 2048 )); then
            fail "Available memory" "$(_human_mb "$avail_mb") / $(_human_mb "${total_mb:-0}")"
        elif (( avail_mb < 4096 )); then
            warn "Available memory" "$(_human_mb "$avail_mb") / $(_human_mb "${total_mb:-0}")"
        else
            pass "Available memory" "$(_human_mb "$avail_mb") / $(_human_mb "${total_mb:-0}")"
        fi
    else
        warn "Available memory" "could not determine"
    fi
    swap_used="$(swap_used_mb)"
    swap_total="$(swap_total_mb)"
    if [[ "$swap_used" =~ ^[0-9]+$ ]]; then
        if (( swap_used >= 4096 )); then
            warn "Swap usage" "$(_human_mb "$swap_used") used / $(_human_mb "${swap_total:-0}") total; allocated swap alone does not prove active pressure"
        else
            pass "Swap usage" "$(_human_mb "$swap_used") used / $(_human_mb "${swap_total:-0}") total"
        fi
    else
        warn "Swap usage" "could not determine"
    fi
    pass "Disk" "$(df -h "$HOME" | awk 'NR==2 {print $4 " free"}')"
    if apple_brew_available; then pass "Homebrew" "$(brew --version | head -1)"; else warn "Homebrew" "not installed; required to install vLLM-Metal"; fi
    if apple_metal_available; then pass "Metal GPU" "available"; else warn "Metal GPU" "could not verify through system_profiler"; fi
    if apple_vllm_metal_available; then pass "vLLM-Metal" "$(vllm --version 2>&1 | head -1)"; pass "MLX" "bundled; full GPU check occurs at model startup"; else warn "vLLM-Metal / MLX" "not installed"; fi
    if command -v colima >/dev/null 2>&1; then
        if apple_colima_running; then pass "Colima" "running"; else warn "Colima" "installed but stopped"; fi
    else warn "Colima" "not installed (optional; required for Open WebUI)"; fi
    if apple_docker_available; then pass "Docker CLI" "$(docker --version 2>/dev/null)"; else warn "Docker CLI" "not installed (optional; required for Open WebUI)"; fi
    if apple_docker_info; then pass "Docker engine" "Colima context reachable"; else warn "Docker engine" "Colima Docker context unavailable"; fi
    if apple_webui_running; then pass "Open WebUI" "running on port ${APPLE_WEBUI_PORT}"; else warn "Open WebUI" "not running"; fi
    if apple_network_ok; then pass "Network" "online"; else warn "Network" "offline"; fi
    if [[ -d "$HOME/.cache/huggingface/hub" ]]; then pass "Hugging Face cache" "present"; else warn "Hugging Face cache" "not found"; fi
}

apple_install_vllm_metal() {
    if apple_vllm_metal_available; then
        echo "vLLM-Metal is already installed; reusing it."
        return 0
    fi
    if ! apple_brew_available; then
        echo "ERROR: Homebrew is required to install vLLM-Metal."
        echo "Install Homebrew from https://brew.sh, then rerun start-ai."
        return 1
    fi
    echo
    echo "vLLM-Metal is not installed. The official Homebrew formula installs the native Apple Silicon inference runtime, including its Python and MLX dependencies."
    echo "No Docker image is used for model inference."
    read -rp "Install vLLM-Metal now? [Y/n]: " ans
    [[ "${ans:-Y}" =~ ^[Nn]$ ]] && { echo "Installation cancelled."; return 1; }
    echo "Adding the official vLLM-Metal Homebrew tap..."
    brew tap $APPLE_VLLM_METAL_TAP || return 1
    echo "Installing vLLM-Metal..."
    brew install "$APPLE_VLLM_METAL_FORMULA" || return 1
    command -v vllm >/dev/null 2>&1 || {
        echo "ERROR: Installation completed but 'vllm' is not on PATH. Check: brew --prefix vllm-metal"
        return 1
    }
    echo "vLLM-Metal installed: $(vllm --version 2>&1 | head -1)"
}

apple_prepare_vllm_metal() {
    echo "Checking Apple Silicon inference prerequisites..."
    [[ "$(uname -m)" == "arm64" ]] || { echo "ERROR: Apple M-series arm64 hardware is required."; return 1; }
    local os_major free_gb min_disk_gb available_mb swap_mb memory_ans
    os_major="$(sw_vers -productVersion | cut -d. -f1)"
    (( os_major >= 15 )) || { echo "ERROR: vLLM-Metal requires macOS 15 or later."; return 1; }
    if ! huggingface_hub_ok && ! hf_model_cached "${HF_MODEL:-}"; then
        echo "ERROR: Hugging Face is unreachable and the selected model is not cached."
        echo "Connect to the internet or cache the model before launching."
        return 1
    fi

    available_mb="$(ram_available_mb)"
    swap_mb="$(swap_used_mb)"
    if [[ "$available_mb" =~ ^[0-9]+$ ]] && { (( available_mb < 6144 )) || { [[ "$swap_mb" =~ ^[0-9]+$ ]] && (( swap_mb >= 4096 )); }; }; then
        echo
        echo "MEMORY CAUTION"
        echo "Available memory: $(_human_mb "$available_mb")"
        if [[ "$swap_mb" =~ ^[0-9]+$ ]]; then
            echo "Swap currently allocated: $(_human_mb "$swap_mb")"
            echo "Allocated swap is not, by itself, proof of active memory pressure."
        fi
        echo "The model runtime needs additional memory for weights, context, and overhead."
        read -rp "Continue with installation/model startup despite this memory warning? [y/N]: " memory_ans
        [[ "$memory_ans" =~ ^[Yy]([Ee][Ss])?$ ]] || {
            echo "Cancelled before installing dependencies or downloading model weights."
            return 1
        }
    fi

    if ! hf_model_cached "${HF_MODEL:-}"; then
        free_gb="$(df -Pk "$HOME" | awk 'NR==2 {print int($4/1048576)}')"
        min_disk_gb="${MODEL_MIN_DISK_GB:-5}"
        if [[ "$free_gb" =~ ^[0-9]+$ ]] && (( free_gb < min_disk_gb )); then
            echo "ERROR: Only ${free_gb} GB is free; this profile recommends at least ${min_disk_gb} GB free for model download and cache overhead."
            return 1
        fi
        echo "Disk space: ${free_gb:-unknown} GB free; profile target ${min_disk_gb} GB."
    else
        echo "Selected model is already present in the Hugging Face cache; skipping the download-space check."
    fi
    apple_install_vllm_metal || return 1
    echo "Verifying vLLM-Metal CLI..."
    vllm --version || return 1
    if ! hf_model_cached "${HF_MODEL:-}"; then
        echo "Model weights are not cached. vLLM-Metal will download the selected MLX checkpoint from Hugging Face on first launch."
    else
        echo "Selected model is already present in the Hugging Face cache."
    fi
    return 0
}

apple_docker_install_if_needed() {
    local missing=() missing_count=0
    if ! apple_colima_available; then missing+=(colima); missing_count=$((missing_count + 1)); fi
    if ! apple_docker_available; then missing+=(docker); missing_count=$((missing_count + 1)); fi
    if (( missing_count > 0 )); then
        apple_brew_available || { echo "Homebrew is required to install missing Colima/Docker components. Install it from https://brew.sh."; return 1; }
        echo "The optional Open WebUI container requires Colima and the Docker CLI."
        echo "The toolkit will install only missing components: ${missing[*]}"
        echo "Docker Desktop and Docker Compose will NOT be installed."
        read -rp "Install missing components with Homebrew? [Y/n]: " ans
        [[ "${ans:-Y}" =~ ^[Nn]$ ]] && return 1
        brew install "${missing[@]}" || return 1
    fi
    return 0
}

apple_ensure_colima() {
    apple_docker_install_if_needed || return 1
    if ! apple_colima_running; then
        echo "Colima is installed but not running. Starting the existing Colima profile..."
        colima start --activate=false || return 1
    fi
    if ! apple_docker_info; then
        echo "ERROR: Docker CLI cannot reach the Docker Engine through the Colima context."
        echo "Check with: docker --context colima info"
        return 1
    fi
    echo "Colima is running and Docker CLI is connected through context '$APPLE_DOCKER_CONTEXT'."
}

apple_print_manual_webui_connection() {
    echo "Configure this connection in Open WebUI > Admin Settings > Connections:"
    echo "  URL     : http://host.docker.internal:${PORT:-8000}/v1"
    echo "  API key : leave blank (no API key is required)"
}

apple_ensure_open_webui() {
    mkdir -p "$HOME/open-webui"
    apple_ensure_colima || return 1
    if apple_webui_running; then
        echo "Open WebUI is already running — reusing it without changing its container."
        apple_print_manual_webui_connection
        return 0
    fi
    if apple_webui_exists; then
        echo "Starting the existing Open WebUI container (persistent data and settings are retained)..."
        docker --context "$APPLE_DOCKER_CONTEXT" start "$APPLE_WEBUI_NAME" >/dev/null || return 1
        APPLE_WEBUI_STARTED_BY_TOOLKIT=1
        echo "Existing container settings are unchanged; add the inference connection manually:"
        apple_print_manual_webui_connection
    else
        if ! docker --context "$APPLE_DOCKER_CONTEXT" image inspect "$APPLE_WEBUI_IMAGE" >/dev/null 2>&1; then
            echo "Pulling Open WebUI image: $APPLE_WEBUI_IMAGE"
            docker --context "$APPLE_DOCKER_CONTEXT" pull "$APPLE_WEBUI_IMAGE" || return 1
        else
            echo "Open WebUI image is already present; no pull needed."
        fi
        echo "Creating Open WebUI container with persistent data at $HOME/open-webui..."
        docker --context "$APPLE_DOCKER_CONTEXT" run -d \
            --name "$APPLE_WEBUI_NAME" \
            -p "${APPLE_WEBUI_PORT}:8080" \
            -v "$HOME/open-webui:/app/backend/data" \
            -e "OPENAI_API_BASE_URLS=http://host.docker.internal:${PORT:-8000}/v1" \
            -e "ENABLE_OLLAMA_API=False" \
            "$APPLE_WEBUI_IMAGE" >/dev/null || return 1
        APPLE_WEBUI_STARTED_BY_TOOLKIT=1
    fi
    echo "Open WebUI: http://127.0.0.1:${APPLE_WEBUI_PORT}"
    echo "Inference API: http://127.0.0.1:${PORT:-8000}/v1"
}

apple_prompt_open_webui() {
    local ans
    if apple_webui_running; then
        echo
        read -rp "Connect the already-running Open WebUI to this inference server? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        HOST="0.0.0.0"
            echo "The inference API will listen on 0.0.0.0:${PORT:-8000} without API-key authentication."
            apple_print_manual_webui_connection
        else
            echo "Leaving the existing Open WebUI and inference network settings unchanged."
        fi
        return 0
    fi
    echo
    read -rp "Start Open WebUI in Colima for this model? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        HOST="0.0.0.0"
        echo "The native inference API will listen on 0.0.0.0:${PORT:-8000} without API-key authentication."
        apple_ensure_open_webui || {
            echo "WARNING: Open WebUI could not be started. Inference can still continue on localhost."
            HOST="127.0.0.1"
        }
    else
        echo "Skipping Open WebUI."
    fi
}

apple_prompt_leave_webui() {
    [[ "$APPLE_WEBUI_STARTED_BY_TOOLKIT" == "1" ]] || return 0
    apple_webui_running || return 0
    local ans
    echo
    read -rp "Stop the Open WebUI container started by this toolkit session? [y/N]: " ans
    if [[ "${ans:-N}" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "Stopping Open WebUI (container and persistent data are retained)..."
        docker --context "$APPLE_DOCKER_CONTEXT" stop "$APPLE_WEBUI_NAME" >/dev/null 2>&1 || true
    else
        echo "Open WebUI left running at http://127.0.0.1:${APPLE_WEBUI_PORT}"
    fi
}

apple_launch_vllm_metal() {
    local -a args=(serve "$HF_MODEL" --host "${HOST:-0.0.0.0}" --port "${PORT:-8000}" --max-model-len "$MAX_MODEL_LEN" --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION:-0.70}")
    if ((${#VLLM_ARGS[@]})); then
        args+=("${VLLM_ARGS[@]}")
    fi
    echo "Starting native vLLM-Metal. Model downloads are handled by vLLM and cached in ~/.cache/huggingface."
    vllm "${args[@]}"
}
