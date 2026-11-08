#!/usr/bin/env bash

# Docker lifecycle, llama.cpp launch, and vLLM launch helpers.

docker_ok() {
    sudo -n docker info >/dev/null 2>&1 || sudo docker info >/dev/null 2>&1
}

cleanup_containers() {
    # Stop leftover llama.cpp servers only. Never touch Open WebUI.
    # Do not `docker container prune` — that would delete a stopped WebUI.
    echo "Cleaning stale llama.cpp containers..."
    local ids
    local id
    for id in $(sudo docker ps -aq --filter "ancestor=ghcr.io/nvidia-ai-iot/llama_cpp:latest-jetson-orin" 2>/dev/null); do
        sudo docker rm -f "$id" >/dev/null 2>&1 || true
    done
    for id in $(sudo docker ps -aq --filter "ancestor=ghcr.io/ggml-org/llama.cpp:server-cuda" 2>/dev/null); do
        sudo docker rm -f "$id" >/dev/null 2>&1 || true
    done
}


plugin_dir() {
    local plugin="$1"
    echo "$TOOLKIT_DIR/runtime/plugins/$plugin"
}

plugin_is_valid_name() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

validate_vllm_plugins() {
    local plugin dir
    [[ "${BACKEND:-}" == "vllm" ]] || return 0
    for plugin in "${VLLM_PLUGINS[@]:-}"; do
        [[ -n "$plugin" ]] || continue
        plugin_is_valid_name "$plugin" || {
            echo "ERROR: Invalid plugin name: $plugin"
            return 1
        }
        dir="$(plugin_dir "$plugin")"
        if [[ ! -d "$dir" ]]; then
            echo "ERROR: Model requires plugin '$plugin'"
            echo "       Plugin not found: $dir"
            return 1
        fi
        if [[ ! -f "$dir/PLUGIN" ]]; then
            echo "ERROR: Plugin '$plugin' is missing its PLUGIN manifest:"
            echo "       $dir/PLUGIN"
            return 1
        fi
    done
}

show_vllm_requirements() {
    local plugin envv
    echo "Runtime requirements"
    printf "  %-14s %s\n" "Image" "${IMAGE:-n/a}"
    if [[ ${VLLM_PLUGINS+x} && ${#VLLM_PLUGINS[@]} -gt 0 ]]; then
        for plugin in "${VLLM_PLUGINS[@]}"; do
            printf "  %-14s %s ✓\n" "Plugin" "$plugin"
        done
    else
        printf "  %-14s %s\n" "Plugins" "none"
    fi
    if [[ ${ENV_VARS+x} && ${#ENV_VARS[@]} -gt 0 ]]; then
        for envv in "${ENV_VARS[@]}"; do
            printf "  %-14s %s ✓\n" "Environment" "$envv"
        done
    fi
    echo
}

image_present() {
    sudo docker image inspect "$IMAGE" >/dev/null 2>&1
}

network_ok() {
    curl -fsS --max-time 3 --connect-timeout 2 https://ghcr.io >/dev/null 2>&1 && return 0
    curl -fsS --max-time 3 --connect-timeout 2 https://nvcr.io >/dev/null 2>&1 && return 0
    ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && return 0
    return 1
}

prepare_image() {
    local short_digest runtime_label
    short_digest="${IMAGE##*sha256:}"
    if [[ "$IMAGE" == *sha256:* ]]; then
        short_digest="${short_digest:0:12}"
    else
        short_digest=""
    fi

    if [[ "${BACKEND:-}" == "vllm" ]]; then
        runtime_label="${PLATFORM_LABEL:-vLLM}"
    else
        case "${RUNTIME:-}" in
            nvidia-jetson) runtime_label="NVIDIA Jetson" ;;
            upstream)      runtime_label="Upstream llama.cpp" ;;
            open-webui)    runtime_label="Open WebUI" ;;
            *)             runtime_label="${RUNTIME:-model profile}" ;;
        esac
    fi

    echo "Checking container image..."
    echo "  Runtime : $runtime_label"
    if [[ -n "$short_digest" ]]; then
        echo "  Image   : ${IMAGE%%@sha256:*}@sha256:${short_digest}…"
    else
        echo "  Image   : $IMAGE"
    fi
    echo

    if image_present; then
        echo "✓ Image found locally"
        if [[ -n "$short_digest" ]]; then
            echo "  Digest  : ${short_digest}…"
        fi
        if network_ok; then
            echo "Network   : online"
            if [[ -n "$short_digest" ]]; then
                echo "Update    : best-effort check (pinned digest — no newer tag expected)"
            else
                echo "Update    : best-effort pull (tag may move)"
            fi
            sudo docker pull "$IMAGE" >/dev/null 2>&1 || true
        else
            echo "Network   : offline"
            echo "Update    : skipped"
        fi
        echo
        echo "Using local image."
        return 0
    fi

    echo "✗ Image not found locally"
    if network_ok; then
        echo "Network   : online"
        echo
        echo "Pulling image (first use of this runtime)…"
        if sudo docker pull "$IMAGE"; then
            echo "✓ Pull complete"
            return 0
        fi
        echo
        echo "ERROR: Failed to pull container image."
        if [[ "$IMAGE" == nvcr.io/* ]]; then
            echo "       NGC images may require:  docker login nvcr.io"
        fi
        return 1
    fi

    echo "Network   : offline"
    echo
    echo "ERROR: Container image is not present and no network is available."
    echo "       Connect to the internet once so the image can be downloaded,"
    echo "       or load the image onto this machine from another host."
    echo "  $IMAGE"
    return 1
}

build_docker_args() {
    # No --pull here. prepare_image() already handled presence / optional refresh.
    DOCKER_ARGS=(
        run -it --rm
        --runtime=nvidia
        --network host
        -v "$VOLUME_PATH"
        "$IMAGE"
    )

    if [[ -n "${SERVER_COMMAND:-}" ]]; then
        DOCKER_ARGS+=("$SERVER_COMMAND")
    fi

    DOCKER_ARGS+=(
        -hf "$HF_MODEL"
        -c "$CONTEXT"
        -np 1
    )

    if [[ -n "${GPU_LAYERS:-}" ]]; then
        DOCKER_ARGS+=(-ngl "$GPU_LAYERS")
    fi

    if [[ -n "${FLASH_ATTN:-}" ]]; then
        # shellcheck disable=SC2206
        DOCKER_ARGS+=( $FLASH_ATTN )
    fi

    if [[ -n "${EXTRA_ARGS:-}" ]]; then
        # shellcheck disable=SC2206
        DOCKER_ARGS+=( $EXTRA_ARGS )
    fi
}

launch_model() {
    build_docker_args
    sudo docker "${DOCKER_ARGS[@]}"
}

build_vllm_args() {
    VLLM_DOCKER_ARGS=(
        run -it --rm
        --runtime=nvidia
        --network host
        -v "$VOLUME_PATH"
    )
    if [[ "${IPC_MODE:-}" == "host" ]]; then
        VLLM_DOCKER_ARGS+=(--ipc=host)
    else
        VLLM_DOCKER_ARGS+=(--shm-size="${SHM_SIZE:-16g}")
    fi

    # Pass HF_TOKEN from the environment if set. Never print it.
    if [[ -n "${HF_TOKEN:-}" ]]; then
        VLLM_DOCKER_ARGS+=(-e HF_TOKEN)
    fi
    if [[ -s "$HOME/.cache/huggingface/token" ]]; then
        VLLM_DOCKER_ARGS+=(-v "$HOME/.cache/huggingface/token:/root/.cache/huggingface/token:ro")
    fi

    # v2.5 plugins are mounted as an isolated site-packages tree and added to
    # PYTHONPATH. Each plugin may contain its own package and .dist-info entry
    # point metadata.
    local plugin plugin_root
    local plugin_path=""
    for plugin in "${VLLM_PLUGINS[@]:-}"; do
        [[ -n "$plugin" ]] || continue
        plugin_root="$(plugin_dir "$plugin")"
        VLLM_DOCKER_ARGS+=(-v "$plugin_root:/opt/local-ai-toolkit/plugins/$plugin:ro")
        if [[ -n "$plugin_path" ]]; then plugin_path="$plugin_path:"; fi
        plugin_path="${plugin_path}/opt/local-ai-toolkit/plugins/$plugin"
    done
    if [[ -n "$plugin_path" ]]; then
        VLLM_DOCKER_ARGS+=(-e "PYTHONPATH=$plugin_path${PYTHONPATH:+:$PYTHONPATH}")
    fi

    for envv in "${ENV_VARS[@]:-}"; do
        [[ -n "$envv" ]] || continue
        VLLM_DOCKER_ARGS+=(-e "$envv")
    done

    VLLM_DOCKER_ARGS+=("$IMAGE")

    if [[ "$IMAGE" == vllm/vllm-openai:* ]]; then
        VLLM_DOCKER_ARGS+=("$HF_MODEL")
    else
        VLLM_DOCKER_ARGS+=(vllm serve "$HF_MODEL")
    fi
    VLLM_DOCKER_ARGS+=(--gpu-memory-utilization "${GPU_MEMORY_UTILIZATION:-0.85}")
    VLLM_DOCKER_ARGS+=(--max-model-len "$MAX_MODEL_LEN")
    VLLM_DOCKER_ARGS+=(--host "${HOST:-0.0.0.0}")
    VLLM_DOCKER_ARGS+=(--port "${PORT:-8000}")

    if [[ "${TRUST_REMOTE_CODE:-0}" == "1" ]]; then
        VLLM_DOCKER_ARGS+=(--trust-remote-code)
    fi

    if ((${#VLLM_ARGS[@]})); then
        VLLM_DOCKER_ARGS+=("${VLLM_ARGS[@]}")
    fi

    if [[ -n "${CHAT_TEMPLATE_KWARGS:-}" ]]; then
        VLLM_DOCKER_ARGS+=(--default-chat-template-kwargs "$CHAT_TEMPLATE_KWARGS")
    fi
}

launch_vllm() {
    build_vllm_args
    sudo docker "${VLLM_DOCKER_ARGS[@]}"
}


validate_diffusers_plugins() {
    local plugin plugin_root
    for plugin in "${DIFFUSERS_PLUGINS[@]:-}"; do
        [[ -n "$plugin" ]] || continue
        plugin_root="$(plugin_dir "$plugin")"
        [[ -d "$plugin_root" && -f "$plugin_root/PLUGIN" ]] || {
            echo "ERROR: required Diffusers plugin '$plugin' is missing."
            echo "       Expected: $TOOLKIT_DIR/runtime/plugins/$plugin/PLUGIN"
            return 1
        }
    done
    return 0
}

build_diffusers_args() {
    local runtime_root="${HOME}/.cache/local-ai-toolkit/venvs/${MODEL_ID}"
    local output_root="${HOME}/${DIFFUSERS_OUTPUT_DIR:-local-ai-toolkit-output/${MODEL_ID}}"
    mkdir -p "$output_root"

    DIFFUSERS_DOCKER_ARGS=(
        run -it --rm
        --runtime=nvidia
        --network host
        --shm-size="${SHM_SIZE:-16g}"
        -v "$VOLUME_PATH"
        -v "${runtime_root}:/opt/local-ai-toolkit/runtime:rw"
        -v "${output_root}:/opt/local-ai-toolkit/output:rw"
    )

    if [[ -n "${HF_TOKEN:-}" ]]; then
        DIFFUSERS_DOCKER_ARGS+=(-e HF_TOKEN)
    fi
    if [[ -s "$HOME/.cache/huggingface/token" ]]; then
        DIFFUSERS_DOCKER_ARGS+=(-v "$HOME/.cache/huggingface/token:/root/.cache/huggingface/token:ro")
    fi

    local plugin plugin_root plugin_path=""
    for plugin in "${DIFFUSERS_PLUGINS[@]:-}"; do
        [[ -n "$plugin" ]] || continue
        plugin_root="$(plugin_dir "$plugin")"
        DIFFUSERS_DOCKER_ARGS+=(-v "$plugin_root:/opt/local-ai-toolkit/plugins/$plugin:ro")
        [[ -n "$plugin_path" ]] && plugin_path="$plugin_path:"
        plugin_path="${plugin_path}/opt/local-ai-toolkit/plugins/$plugin"
    done
    if [[ -n "$plugin_path" ]]; then
        DIFFUSERS_DOCKER_ARGS+=(-e "PYTHONPATH=$plugin_path${PYTHONPATH:+:$PYTHONPATH}")
    fi

    for envv in "${ENV_VARS[@]:-}"; do
        [[ -n "$envv" ]] || continue
        DIFFUSERS_DOCKER_ARGS+=(-e "$envv")
    done

    DIFFUSERS_DOCKER_ARGS+=("$IMAGE")

    local mode="${DIFFUSERS_MODE:-stage_a}"
    case "$mode" in
        stage_a)
            DIFFUSERS_DOCKER_ARGS+=(python3 "/opt/local-ai-toolkit/plugins/${DIFFUSERS_PLUGINS[0]}/stage_a.py")
            DIFFUSERS_DOCKER_ARGS+=(--model "$HF_MODEL" --pipeline "$DIFFUSERS_PIPELINE")
            DIFFUSERS_DOCKER_ARGS+=(--runtime-root /opt/local-ai-toolkit/runtime)
            DIFFUSERS_DOCKER_ARGS+=(--output-dir /opt/local-ai-toolkit/output)
            if [[ -n "${DIFFUSERS_PROMPT:-}" ]]; then
                DIFFUSERS_DOCKER_ARGS+=(--prompt "$DIFFUSERS_PROMPT")
            fi
            ;;
        api)
            DIFFUSERS_DOCKER_ARGS+=(python3 "/opt/local-ai-toolkit/plugins/${DIFFUSERS_PLUGINS[0]}/api.py")
            DIFFUSERS_DOCKER_ARGS+=(--model "$HF_MODEL" --pipeline "$DIFFUSERS_PIPELINE")
            DIFFUSERS_DOCKER_ARGS+=(--runtime-root /opt/local-ai-toolkit/runtime)
            DIFFUSERS_DOCKER_ARGS+=(--output-dir /opt/local-ai-toolkit/output)
            DIFFUSERS_DOCKER_ARGS+=(--host "${HOST:-0.0.0.0}" --port "${PORT:-8000}")
            ;;
        *)
            echo "ERROR: Unsupported Diffusers mode: $mode"
            return 1
            ;;
    esac
}

launch_diffusers() {
    build_diffusers_args
    sudo docker "${DIFFUSERS_DOCKER_ARGS[@]}"
}
