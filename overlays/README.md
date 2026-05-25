# Rime Overlay Layout

This directory contains local, replaceable layers applied on top of
`vendor/oh-my-rime` by `make build`.

- `base/`: local helper scripts and machine-agnostic defaults.
- `personal/`: personal Rime patches, symbols, and user-level YAML.
- `ai/`: optional AI/LLM Rime extensions. Enable with `make ai-on`.

Files in later overlays overwrite files copied from upstream. Keep runtime data
such as `*.userdb`, `sync/`, and `installation.yaml` out of overlays; `make
deploy` preserves them from the currently active `~/Library/Rime`.
