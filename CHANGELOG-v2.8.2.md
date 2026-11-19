# v2.8.2 — Apple Silicon runtime and documentation maintenance

- Removes the unnecessary Apple Silicon vLLM API-key requirement. vLLM-Metal starts without `--api-key`, Open WebUI is no longer configured with `OPENAI_API_KEYS`, and manual Open WebUI connections leave the API key blank. The API remains bound to localhost without Open WebUI and uses `0.0.0.0` only when Colima-hosted Open WebUI needs access.

- Fixes `lib/apple.sh` to append the `VLLM_ARGS` Bash array with `"${VLLM_ARGS[@]}"`, preserving each argument and embedded JSON value. This fixes the previously observed behavior where array arguments were not reliably forwarded as separate CLI arguments.
- Updates the Apple Gemma 4 E2B profile with the M5-tested vLLM-Metal 0.33.0 recipe:
  - `--reasoning-parser gemma4`
  - `--default-chat-template-kwargs '{"enable_thinking": true}'`
  - `--enable-auto-tool-choice`
  - `--tool-call-parser gemma4`
- Does not specify `examples/tool_chat_template_gemma4.jinja`; that path was not present in the installed vLLM-Metal package. The model's bundled tokenizer chat template is used.
- Sets Gemma 4 E2B Apple `GPU_MEMORY_UTILIZATION=0.55`, retaining 4096 and 8192 context choices. The 8192 startup was observed on an M5 MacBook Air with 16 GiB unified memory.
- Adds the Gemma 4 family reasoning/tool-call arguments to the E4B Apple profile, while explicitly noting that E4B has not been independently validated on the target Mac.
- Preserves the Qwen 3.5 Apple profile's model-specific settings; it uses the corrected launcher without Gemma-specific parser arguments.
- Updates README platform interface references for llama.cpp, Open WebUI, and Cosmos Media Studio, including local-versus-LAN guidance.
- Updates shared toolkit version metadata, installer output, model helper version labels, and Apple Silicon documentation to v2.8.2.

## Validation notes

- M5 MacBook Air / vLLM-Metal 0.33.0: Gemma 4 E2B model load, 8192 max context, reasoning parser configuration, automatic tool-choice initialization, Gemma 4 tool-call parser configuration, sidecar load, model warmup, multimodal warmup, and API startup observed.
- Direct OpenAI-compatible API text-generation requests succeeded with thinking enabled and disabled.
- Actual tool invocation/execution and image/audio/video generation are not claimed as validated.
- Gemma 4 E4B is configuration-updated but not runtime-validated.
