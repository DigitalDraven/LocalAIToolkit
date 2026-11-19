# v2.8.1 — Apple Silicon maintenance release

- Fix installer PATH detection so comments do not suppress the active `~/bin` export.
- Report macOS power mode as not applicable.
- Add available-memory and swap diagnostics to `ai-doctor`.
- Add a non-destructive memory preflight before vLLM-Metal installation/model download.
- Secure optional Open WebUI access with a generated vLLM API key.
- Reuse existing Open WebUI containers without changing their environment; only stop containers started by the current toolkit session.
- Preserve the existing Colima engine and unrelated containers.
- Refresh Apple model profile notes to distinguish upstream text support from experimental multimodal support and local hardware validation.
