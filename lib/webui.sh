#!/usr/bin/env bash
# Open WebUI companion service (Thor / Spark only).

WEBUI_IMAGE="${WEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
WEBUI_NAME="${WEBUI_NAME:-open-webui}"
WEBUI_HOST_PORT="${WEBUI_HOST_PORT:-8080}"

webui_running() {
    sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$WEBUI_NAME"
}

webui_exists() {
    sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$WEBUI_NAME"
}

ensure_open_webui() {
    local api_port="${1:-${PORT:-8000}}"
    mkdir -p "$HOME/open-webui"

    if webui_running; then
        echo "Open WebUI already running — reusing."
        echo "  UI       : http://127.0.0.1:${WEBUI_HOST_PORT}"
        echo "  API base : http://127.0.0.1:${api_port}/v1"
        echo "  (host networking; vLLM is expected on port ${api_port})"
        return 0
    fi

    if webui_exists; then
        echo "Starting existing Open WebUI container..."
        sudo docker start "$WEBUI_NAME" >/dev/null
        echo "Open WebUI: http://127.0.0.1:${WEBUI_HOST_PORT}"
        echo "  API base : http://127.0.0.1:${api_port}/v1"
        return 0
    fi

    echo "Preparing Open WebUI image..."
    local saved_image="${IMAGE:-}"
    local saved_runtime="${RUNTIME:-}"
    IMAGE="$WEBUI_IMAGE"
    RUNTIME="open-webui"
    if ! prepare_image; then
        IMAGE="$saved_image"
        RUNTIME="$saved_runtime"
        echo "ERROR: Could not prepare Open WebUI image."
        return 1
    fi
    IMAGE="$saved_image"
    RUNTIME="$saved_runtime"

    echo "Starting Open WebUI..."
    sudo docker run -d --network host \
        --name "$WEBUI_NAME" \
        -v "$HOME/open-webui:/app/backend/data" \
        -e "OPENAI_API_BASE_URL=http://127.0.0.1:${api_port}/v1" \
        "$WEBUI_IMAGE" >/dev/null

    echo "Open WebUI: http://127.0.0.1:${WEBUI_HOST_PORT}"
    echo "  API base : http://127.0.0.1:${api_port}/v1"
}

prompt_open_webui() {
    local api_port="${PORT:-8000}"
    local ans
    echo
    read -rp "Start Open WebUI against this server? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        ensure_open_webui "$api_port" || echo "Continuing without Open WebUI."
    else
        echo "Skipping Open WebUI."
    fi
}

prompt_leave_webui() {
    webui_running || return 0
    local ans
    echo
    read -rp "Leave Open WebUI running? [Y/n]: " ans
    if [[ "${ans:-Y}" =~ ^[Nn]$ ]]; then
        echo "Stopping Open WebUI..."
        sudo docker stop "$WEBUI_NAME" >/dev/null 2>&1 || true
        echo "Open WebUI stopped (container kept; start-ai can reuse it later)."
    else
        echo "Open WebUI left running at http://127.0.0.1:${WEBUI_HOST_PORT}"
    fi
}


prompt_leave_media_studio() {
    local ans
    command -v cosmos-media-studio >/dev/null 2>&1 || return 0
    docker container inspect cosmos-media-studio >/dev/null 2>&1 || return 0
    [[ "$(docker inspect -f '{{.State.Running}}' cosmos-media-studio 2>/dev/null)" == true ]] || return 0
    echo
    read -rp "Shut down Cosmos Media Studio? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "Stopping Cosmos Media Studio..."
        cosmos-media-studio stop
    else
        echo "Cosmos Media Studio left running at http://127.0.0.1:7860"
    fi
}
