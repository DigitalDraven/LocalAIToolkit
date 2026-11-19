# Local AI Toolkit v2.8.2

## v2.8.2 — Apple Silicon runtime and documentation maintenance

- Fixes Apple native vLLM-Metal launch argument handling so every item in a profile's `VLLM_ARGS` Bash array is forwarded as a distinct argument with its quoting preserved.
- Updates the Apple Gemma 4 E2B profile with the M5-tested vLLM-Metal 0.33.0 recipe: Gemma 4 reasoning parser, thinking enabled by default, automatic tool choice, and Gemma 4 tool-call parser. Removes reliance on an unavailable external chat-template path.
- Raises the Gemma 4 E2B Apple profile GPU memory utilization setting to the M5-tested value of `0.55`; retains the 4K and 8K context choices.
- Adds the Gemma 4 family reasoning/tool-call arguments to the E4B profile, but explicitly marks E4B runtime and memory behavior as not yet independently validated.
- Preserves Qwen 3.5's model-specific configuration; it benefits from the launcher fix without inheriting Gemma-specific parsers.
- Updates platform interface documentation and Apple Silicon validation notes. NVIDIA and Jetson inference profiles are otherwise unchanged.

**Validation scope:** Gemma 4 E2B native text inference, 8K context startup, reasoning configuration, automatic tool-choice initialization, and multimodal sidecar loading were observed on an M5 MacBook Air with vLLM-Metal 0.33.0. Actual tool execution and image/audio/video generation are not claimed as validated. E4B is not runtime-validated by this release.

## Release path

- `v2.8.1`: Apple Silicon implementation, experimental.
- `v2.8.2`: Apple Silicon launcher argument fix, Gemma 4 recipe updates, and platform interface documentation.
- `v2.8.x`: on-device model validation, memory/performance tuning, and compatibility fixes.
- `v3.0.0`: intended public release after the supported hardware paths and model profiles have passed validation.

## Platforms

| Platform | Backend | Inference mode | UI |
|----------|---------|----------------|-----|
| Super Orin Nano | llama.cpp | NVIDIA/Jetson container | llama.cpp / OpenAI API on port 8080 |
| Jetson AGX Thor | vLLM | NVIDIA container | optional Open WebUI |
| DGX Spark | vLLM / vLLM-Omni | NVIDIA container | optional Open WebUI / Cosmos Media Studio |
| Apple Silicon M-series | vLLM-Metal / MLX | Native macOS | optional Open WebUI in Colima |

## Web interfaces and service URLs

Use these local URLs when the corresponding service is running:

| Platform | Interface | Local URL |
|----------|-----------|-----------|
| Super Orin Nano / Jetson Orin Nano | [llama.cpp server / web UI](http://127.0.0.1:8080) | `http://127.0.0.1:8080` |
| Jetson AGX Thor | [Open WebUI](http://127.0.0.1:8080) | `http://127.0.0.1:8080` |
| DGX Spark | [Open WebUI](http://127.0.0.1:8080) | `http://127.0.0.1:8080` |
| Apple Silicon M-series | [Open WebUI](http://127.0.0.1:8080) (Colima) | `http://127.0.0.1:8080` |
| DGX Spark with a Cosmos model and Media Studio enabled | [Cosmos Media Studio](http://127.0.0.1:7860) | `http://127.0.0.1:7860` |

The Jetson Orin Nano llama.cpp URL above reflects the toolkit deployment endpoint verified by the project owner. Open WebUI uses the toolkit's default host port `8080`; deployments that override `WEBUI_HOST_PORT` will use that configured port instead. Cosmos Media Studio is a separate optional service and is available at port `7860` when its container is running.

`127.0.0.1` means the machine on which the browser is running. To access an interface from another device on the same network, use the host machine's LAN IP address and the same service port, provided the service is bound/published for LAN access and the host firewall permits it. For API clients, the vLLM OpenAI-compatible API is normally exposed separately on port `8000` at `/v1`; it is not the Open WebUI page.

## v2.7.7 changes

- Updates `cosmos3-nano-vllm-omni.conf` for both DGX Spark and AGX Thor to use the requested common Cosmos 3 Nano vLLM-Omni profile: `GPU_MEMORY_UTILIZATION=0.85`, `MAX_MODEL_LEN=32768`, and `RECOMMENDED_MAX_MODEL_LEN=32768`.
- Replaces `--enable-layerwise-offload` with `--cache-backend sea_cache` and `--vae-use-tiling`, while retaining `--omni` and `--no-guardrails`. This aligns both platform profiles with the requested launch arguments and avoids silently keeping the older DGX Spark-specific argument set.
- Adds the previously absent AGX Thor Cosmos 3 Nano profile so both platforms expose the same model ID, startup interface, model repository, cache mount, context settings, token requirement, and plugin/environment defaults. The profile note retains the user's DGX Spark validation wording; it does not claim independent AGX Thor validation.
- Updates `prompt_open_webui()` in `lib/webui.sh` to check whether the Open WebUI container is already running before asking whether to start it. If it is running, the toolkit reports its UI/API addresses and reuses it without presenting a redundant yes/no prompt. If it is stopped or absent, the existing prompt and start/reuse behavior remain in place. This avoids asking users to start a service that is already available and prevents accidentally creating duplicate launch expectations.
- Raises the maximum Cosmos Media Studio inference-step slider value from 30 to 100 for both image and video generation. The default remains 15 and the step increment remains 1, so existing behavior is unchanged unless the user selects a higher value. This gives users room to experiment with higher inference-step counts without hard-coding a new default.
- Bumps the Cosmos Media Studio Docker image tag from `2.7.4` to `2.7.7`. The image contains a copy of `media-studio/app.py`; changing the tag forces the updated app to be rebuilt instead of silently reusing an older image with the 30-step slider limit.
- Updates toolkit version metadata in the shared library, installer, `ai-add-model`, and `ai-edit-model` to v2.7.7.
- No other model profiles, Hugging Face online/offline detection, existing Open WebUI data, or Cosmos Media Studio lifecycle behavior are intentionally changed. Open WebUI remains a separate container, and Cosmos Media Studio remains separate from the Cosmos inference server.

- Updates `prompt_open_webui()` in `lib/webui.sh` to check whether the Open WebUI container is already running before asking whether to start it. If it is running, the toolkit reports its UI/API addresses and reuses it without presenting a redundant yes/no prompt. If it is stopped or absent, the existing prompt and start/reuse behavior remain in place. This avoids asking users to start a service that is already available and prevents accidentally creating duplicate launch expectations.
- Raises the maximum Cosmos Media Studio inference-step slider value from 30 to 100 for both image and video generation. The default remains 15 and the step increment remains 1, so existing behavior is unchanged unless the user selects a higher value. This gives users room to experiment with higher inference-step counts without hard-coding a new default.
- Bumps the Cosmos Media Studio Docker image tag from `2.7.4` to `2.7.7`. The image contains a copy of `media-studio/app.py`; changing the tag forces the updated app to be rebuilt instead of silently reusing an older image with the 30-step slider limit.
- Updates toolkit version metadata in the shared library, installer, `ai-add-model`, and `ai-edit-model` to v2.7.7.
- No model profiles, vLLM launch arguments, Hugging Face online/offline detection, existing Open WebUI data, or Cosmos backend settings are intentionally changed. Open WebUI remains a separate container, and Cosmos Media Studio remains separate from the Cosmos inference server.


Configuration-driven launcher for local AI workloads on Super Orin Nano
(llama.cpp), Jetson AGX Thor / DGX Spark (vLLM), and experimental generation
frontends.

## v2.7.6 changes

- Adds a dedicated Hugging Face Hub connectivity check before launching vLLM. The existing `network_ok()` check remains responsible for general internet/Docker-registry availability; it is not treated as proof that `huggingface.co` is reachable.
- Retries the Hugging Face HTTPS check up to three times with short timeouts. This handles brief DNS/network startup delays like the one observed during Gemma 4 startup.
- Explicitly sets `HF_HUB_OFFLINE` and `TRANSFORMERS_OFFLINE` inside vLLM containers: both are `0` when the Hugging Face Hub is reachable and both are `1` when it is not. This prevents repeated Hub requests in a genuinely offline launch.
- Before allowing an offline launch, checks for a local Hugging Face model snapshot (or a directly supplied local model directory). If the model is not cached, launch is stopped with a clear instruction to connect and download it first rather than allowing vLLM to fail later with DNS errors.
- Applies the behavior centrally in `lib/docker.sh` for vLLM launches, so DGX Spark and AGX Thor profiles share the same implementation. It does not alter model-specific images, arguments, plugins, or specialized Cosmos/Muse configuration.
- Bumps shared, installer, and model-editor/add-model version labels to v2.7.6.

## v2.7.5 changes

- Sets the DGX Spark Cosmos 3 Nano model default and recommended maximum context length to 32,768 tokens.
- Sets Media Studio image and video inference-step defaults to 15.
- Prompts whether to stop Cosmos Media Studio when `start-ai` exits, without stopping the model backend.
- Updates DGX Spark and AGX Thor non-Cosmos vLLM profiles from `nvcr.io/nvidia/vllm:26.08-py3` to `nvcr.io/nvidia/vllm:26.09-py3`.
- Retains the Gradio `/outputs` access fix and existing v2.7.3 functionality.


- Keeps the Gradio `allowed_paths=["/outputs"]` fix in the shipped Media Studio app so generated files can be displayed by the interface.
- Corrects stale toolkit version metadata in `ai-edit-model` and `ai-add-model`.
- Aligns installer, shared version metadata, and the Media Studio image tag with v2.7.5.
- No model profiles or backend launch settings are intentionally changed in this maintenance release.

## v2.7.1 changes

- Adds Cosmos 3 Nano Media Studio, a dedicated Gradio image/video UI in its own Docker container.
- Adds `cosmos-media-studio` lifecycle commands: `start`, `stop`, `restart`, `status`, and `logs`.
- Persists generated images and videos under `~/cosmos3-nano-media` by default.
- Reuses the existing Cosmos 3 Nano vLLM-Omni API on port 8000; does not launch or modify the model backend.
- Keeps the app container CPU-only and uses host networking to reach the existing local API.

## v2.7.0 changes

- Adds a DGX Spark profile for `nvidia/Cosmos3-Nano` using `vllm/vllm-omni:cosmos3`.
- Uses the verified launch settings: `--omni`, `--gpu-memory-utilization 0.45`,
  `--max-model-len 2048`, `--enable-layerwise-offload`, and `--no-guardrails`.
- Uses Docker host networking and `--ipc=host`, matching the successful local
  test. It deliberately does not use `--privileged` because that broad host
  privilege was not shown to be necessary.
- Removes the experimental Cosmos 3 Super profiles and the Stage A/B Diffusers
  plugin from the shipped toolkit profiles. This does not delete Hugging Face
  model files, generated output, or existing containers from the user's host.
- Preserves existing LLM profiles and the vLLM launch path, including the
  separate Kolibri integration.

## Validated Cosmos Nano path

On DGX Spark with vLLM-Omni 0.25.0, the profile's launch settings successfully
initialized `nvidia/Cosmos3-Nano`, completed a warm-up generation, returned a
512x512 image request, and returned an H.264 MP4 from a short text-to-video
request. The tested video was 256x256 at 8 fps. These are smoke-test settings,
not recommended final-quality settings.

## Platforms

| Platform | Backend | UI |
|----------|---------|-----|
| Super Orin Nano | llama.cpp | llama.cpp / OpenAI API on port 8080 |
| Jetson AGX Thor | vLLM | optional Open WebUI (8080) to vLLM (8000) |
| DGX Spark | vLLM / vLLM-Omni | Cosmos Media Studio for Cosmos 3 Nano; optional Open WebUI for other models |

## Install

```bash
cd local-ai-toolkit-v2
chmod +x install.sh
./install.sh
source ~/.zshrc  # macOS default shell; use ~/.bashrc on Linux or if using Bash
```

## Commands

`start-ai`, `ai-status`, `ai-mode`, `ai-doctor`, `ai-add-model`, `ai-edit-model`,
`cosmos-media-studio` is installed to `~/bin`.

## Cosmos 3 Nano Media Studio

Select the Cosmos 3 Nano profile through `start-ai`. The model profile offers to start Cosmos Media Studio automatically; the interface becomes usable once the backend is ready on port 8000. You can also manage it manually:

```bash
cosmos-media-studio start
cosmos-media-studio status
```

Open `http://127.0.0.1:7860`. Generated media is retained in
`~/cosmos3-nano-media`. Use `cosmos-media-studio logs`
for diagnostics. The first start builds a small CPU-only Gradio image. The image
workflow uses the verified `/v1/images/generations` endpoint. Video uses the
verified synchronous `/v1/videos/sync` endpoint and conservative smoke-test
settings. Reference-image video conditioning is intentionally deferred until its request format
is verified against the installed vLLM-Omni API.

## Hugging Face token

Do not put `HF_TOKEN` values in `.conf` files, scripts, or commands shared in
logs. Export it in the shell (`export HF_TOKEN=...`) or use the standard token
file at `~/.cache/huggingface/token`. If a token has been pasted into a chat or
log, revoke it and create a replacement.
