# Apple Silicon (M-series) — v2.8.2 experimental support

## Scope and requirements

- Apple Silicon M-series only. Intel Macs are out of scope.
- macOS 15 or later.
- Homebrew for the supported vLLM-Metal stable installation path.
- Native ARM64 Python 3.12 and vLLM/MLX dependencies are managed by the official vLLM-Metal Homebrew formula.
- Ollama is not installed or used.
- Apple Container is intentionally deferred for this release; reconsider around November 2027.
- Model inference is native on macOS through vLLM-Metal, MLX, and Metal. It is not run inside Docker/Colima.

## Initial profiles

| Profile | Hugging Face checkpoint | Approximate download |
|---|---|---:|
| `qwen3.5-4b-mlx` | `mlx-community/Qwen3.5-4B-MLX-4bit` | 3.1 GB |
| `gemma-4-e2b-mlx` | `mlx-community/gemma-4-e2b-it-4bit` | 3.6 GB |
| `gemma-4-e4b-mlx` | `mlx-community/gemma-4-e4b-it-4bit` | 5.2 GB |

The Gemma 4 E2B profile uses an 8,192-token recommended context, offers 4,096 and 8,192-token choices, and uses `GPU_MEMORY_UTILIZATION=0.55`, matching the M5 launch that completed model and multimodal warmup. Gemma 4 E4B and Qwen retain their own profile memory settings; do not assume E2B memory results transfer to those models.

The v2.8.2 development validation observed Gemma 4 E2B loading and generating text on an M5 MacBook Air with vLLM-Metal 0.33.0. Its vision/audio sidecar loaded and multimodal warmup completed, but actual image/audio/video requests and tool execution have not yet been validated. Gemma 4 E4B and Qwen 3.5 remain unvalidated on this Mac.

## Install vLLM-Metal

The toolkit checks for Homebrew and the vLLM-Metal command. If missing, it offers the official stable Homebrew installation:

```bash
brew tap vllm-project/vllm-metal https://github.com/vllm-project/vllm-metal
brew install vllm-project/vllm-metal/vllm-metal
```

This is a native macOS package installation, not a Docker image pull. Homebrew manages Python 3.12 and the vLLM-Metal/MLX dependencies. The model weights are downloaded by vLLM on first launch and cached in `~/.cache/huggingface`.

## Optional Open WebUI

Open WebUI is optional and runs as a Docker container through Colima. The toolkit checks for and reuses existing Colima and Docker CLI installations. If either is missing, it offers to install only the missing components using Homebrew:

```bash
brew install colima docker
```

The toolkit does not install Docker Desktop or Docker Compose. Compose is unnecessary for the single Open WebUI container. A newly created Open WebUI container is configured with `OPENAI_API_BASE_URLS` to connect to vLLM-Metal without API-key authentication, and `ENABLE_OLLAMA_API=False` disables its Ollama integration. Colima is started only when the user chooses Open WebUI. Colima is started with `--activate=false`, and Docker commands explicitly use the `colima` Docker context. This reuses Colima without silently changing the user's active Docker context.

Open WebUI data persists under `~/open-webui`. Its container reaches the native inference API through Colima's `host.docker.internal` mapping. When Open WebUI is selected, the inference server binds to `0.0.0.0` without API-key authentication so the Colima-hosted Open WebUI container can connect directly. Without Open WebUI, the API binds to `127.0.0.1`.

An already-running Open WebUI instance is never reconfigured automatically; the user is asked whether to connect it, then receives the URL and secure key-file location for manual connection setup. An existing stopped container is started without recreation or environment changes and likewise requires manual connection setup. The toolkit only offers to stop an Open WebUI container that it started during the current session. Unrelated containers in the shared Colima engine are not modified.

## Diagnostics

- `start-ai`: Apple-specific dashboard, model selection, explicit launch confirmation, prerequisite checks, and native inference launch.
- `ai-status`: reports native vLLM-Metal API and optional Open WebUI status.
- `ai-doctor`: checks Apple Silicon/macOS, unified and available memory, swap usage, Metal availability, Homebrew, vLLM-Metal, Colima, Docker CLI, and network/cache state. Swap allocation is reported as context, not treated alone as proof of active memory pressure.

The Apple Silicon profile editor and guided profile-creation wizard are not included in v2.8.2. The initial three reviewed profiles are maintained directly as `.conf` files under `models/apple-m/`.

## Validation status

Validation evidence is model-specific: Gemma 4 E2B text inference, API responses, 8K startup, reasoning-parser initialization, automatic tool-choice initialization, sidecar loading, and multimodal warmup were observed on the target M5 MacBook Air. Tool execution and actual multimodal generation remain unverified. E4B and Qwen profile runtime behavior remains unverified. The shell/profile smoke tests in this release are separate from those hardware observations.

## Upstream references

- vLLM-Metal installation: https://docs.vllm.ai/projects/vllm-metal/en/stable/installation/
- vLLM-Metal supported models: https://docs.vllm.ai/projects/vllm-metal/en/latest/supported_models/
- vLLM-Metal memory budget and serving overview: https://vllm.ai/blog/2026-09-22-vllm-metal-v0-28-0
- Colima installation: https://colima.run/docs/installation/
- Colima Docker runtime and contexts: https://colima.run/docs/runtimes/
- Colima host networking: https://colima.run/docs/configuration/
- Open WebUI environment configuration: https://docs.openwebui.com/reference/env-configuration/


## v2.8.2 maintenance notes

- Installer PATH detection checks for an active `export PATH=...` statement instead of matching comments.
- macOS power mode reports `Not applicable`.
- Apple diagnostics include available RAM and swap; launch preflight asks before proceeding when available memory is low or swap allocation is high.
- Open WebUI connections do not require an API key; leave the API key field blank. Existing Open WebUI containers are not recreated or stopped unless this toolkit session started them.
- Project-specific containers in the shared Colima engine are not modified.
