# Runtime plugins

Backend-specific runtime plugins live here. v2.7.0 removes the experimental
Cosmos 3 Super Diffusers plugin because the validated DGX Spark path is now the
native `vllm/vllm-omni:cosmos3` server with `nvidia/Cosmos3-Nano`.

Do not place Hugging Face access tokens in profile files or plugins. The vLLM
launcher passes `HF_TOKEN` from the user's environment when set, or mounts the
standard `~/.cache/huggingface/token` file read-only.
