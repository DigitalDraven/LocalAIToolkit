# Local AI Toolkit v2.7.5

Configuration-driven launcher for local AI workloads on Super Orin Nano
(llama.cpp), Jetson AGX Thor / DGX Spark (vLLM), and experimental generation
frontends.

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
source ~/.bashrc
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
