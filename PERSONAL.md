# Personal Rime Workflow

This repo keeps upstream oh-my-rime separate from local customizations.

## Daily Commands

```sh
make status
make update
make doctor
```

- `make sync`: update `vendor/oh-my-rime` from upstream.
- `make deploy`: build overlays into `dist`, preserve runtime data, and reload Squirrel.
- `make update`: run `sync` and `deploy`.
- `make rollback`: point `~/Library/Rime` at the latest backup.
- `make prune-backups`: keep the newest `KEEP_BACKUPS` snapshots, default 10.

## What To Commit

Commit only the management layer and personal overlays:

```sh
git add Makefile .gitignore PERSONAL.md overlays/
git commit -m "Manage personal Rime overlays"
git push origin main
```

Do not commit generated or runtime data:

- `vendor/`
- `dist/`
- `dist.tmp/`
- `backups/`
- `sync/`
- `*.userdb`
- `installation.yaml`
- `user.yaml`
- `english_learner.tsv`

## Layout

- `vendor/oh-my-rime`: upstream checkout.
- `overlays/base`: reusable local helpers.
- `overlays/personal`: personal schema patches and symbols.
- `overlays/ai`: optional AI-related extensions, enabled by `make ai-on`.
- `dist`: generated Rime config linked from `~/Library/Rime`.

