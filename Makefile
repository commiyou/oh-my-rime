ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
VENDOR := $(ROOT)/vendor/oh-my-rime
DIST := $(ROOT)/dist
DIST_TMP := $(ROOT)/dist.tmp
BACKUPS := $(ROOT)/backups
RIME_LINK := $(HOME)/Library/Rime
SQUIRREL_BIN := /Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel
SQUIRREL_FRAMEWORKS := /Library/Input Methods/Squirrel.app/Contents/Frameworks
STAMP := $(shell date +%Y%m%d-%H%M%S)
KEEP_BACKUPS ?= 10

BASE_OVERLAYS := $(ROOT)/overlays/base $(ROOT)/overlays/personal
AI_OVERLAY := $(ROOT)/overlays/ai
OVERLAYS := $(BASE_OVERLAYS) $(if $(wildcard $(ROOT)/.ai-enabled),$(AI_OVERLAY))
PRESERVE_FILES := installation.yaml english_learner.tsv
PRESERVE_DIR_GLOBS := *.userdb
PRESERVE_DIRS := sync

.PHONY: help status doctor backup sync update build validate deploy rollback diff ai-on ai-off clean clean-build clean-backups prune-backups

help:
	@printf '%s\n' \
		'Targets:' \
		'  make status    Show live link, upstream status, and AI overlay state' \
		'  make doctor    Check local prerequisites and managed paths' \
		'  make backup    Snapshot current ~/Library/Rime contents' \
		'  make sync      Fast-forward vendor/oh-my-rime from upstream main' \
		'  make update    sync + deploy in one command' \
		'  make build     Compose vendor + overlays into dist' \
		'  make validate  Parse YAML and check required files in dist' \
		'  make deploy    backup + build + validate, preserve user data, switch ~/Library/Rime to dist' \
		'  make rollback  Switch ~/Library/Rime to the latest backup snapshot' \
		'  make diff      Compare current live Rime config with dist' \
		'  make ai-on     Enable overlays/ai for subsequent builds' \
		'  make ai-off    Disable overlays/ai for subsequent builds' \
		'  make clean     Remove temporary build directory and compiled Rime build output' \
		'  make prune-backups  Keep newest KEEP_BACKUPS backup snapshots' \
		'  make clean-backups  Remove backup snapshots only'

status:
	@printf 'live: %s -> %s\n' "$(RIME_LINK)" "$$(readlink "$(RIME_LINK)" 2>/dev/null || printf 'not-a-symlink')"
	@printf 'vendor: '
	@git -C "$(VENDOR)" log --oneline -1 2>/dev/null || printf 'missing\n'
	@printf 'ai overlay: '
	@if [ -f "$(ROOT)/.ai-enabled" ]; then printf 'enabled\n'; else printf 'disabled\n'; fi
	@printf 'overlays:\n'
	@for d in $(OVERLAYS); do printf '  %s\n' "$$d"; done

doctor:
	@test -d "$(ROOT)/.git" || (printf 'not a git repo: %s\n' "$(ROOT)" >&2; exit 1)
	@test -d "$(VENDOR)/.git" || (printf 'missing vendor checkout; run make sync\n' >&2; exit 1)
	@test -x "$(SQUIRREL_BIN)" || (printf 'missing Squirrel binary: %s\n' "$(SQUIRREL_BIN)" >&2; exit 1)
	@test "$$(readlink "$(RIME_LINK)" 2>/dev/null)" = "$(DIST)" || printf 'warning: %s is not linked to %s\n' "$(RIME_LINK)" "$(DIST)" >&2
	@$(MAKE) validate
	@printf 'doctor: ok\n'

define preserve_runtime
	for f in $(PRESERVE_FILES); do \
		if [ -e "$(1)/$$f" ]; then rsync -a "$(1)/$$f" "$(2)/"; fi; \
	done; \
	for g in $(PRESERVE_DIR_GLOBS); do \
		find "$(1)/" -maxdepth 1 -name "$$g" -type d -exec rsync -a {} "$(2)/" \;; \
	done; \
	for d in $(PRESERVE_DIRS); do \
		if [ -d "$(1)/$$d" ]; then rsync -a "$(1)/$$d/" "$(2)/$$d/"; fi; \
	done
endef

backup:
	@mkdir -p "$(BACKUPS)"
	@test -e "$(RIME_LINK)" || (printf 'missing %s\n' "$(RIME_LINK)" >&2; exit 1)
	@rsync -a --delete "$(RIME_LINK)/" "$(BACKUPS)/rime-$(STAMP)/"
	@printf 'backup: %s\n' "$(BACKUPS)/rime-$(STAMP)"

sync:
	@if [ ! -d "$(VENDOR)/.git" ]; then \
		git clone https://github.com/Mintimate/oh-my-rime.git "$(VENDOR)"; \
	else \
		git -C "$(VENDOR)" fetch --all --prune; \
		git -C "$(VENDOR)" pull --ff-only origin main; \
	fi

update: sync deploy

build:
	@test -d "$(VENDOR)/.git" || (printf 'missing vendor checkout; run make sync\n' >&2; exit 1)
	@rm -rf "$(DIST_TMP)"
	@mkdir -p "$(DIST_TMP)"
	@rsync -a --delete \
		--exclude='.git' \
		--exclude='.github' \
		--exclude='.DS_Store' \
		--exclude='*.userdb' \
		--exclude='sync/' \
		--exclude='installation.yaml' \
		"$(VENDOR)/" "$(DIST_TMP)/"
	@for d in $(OVERLAYS); do \
		if [ -d "$$d" ]; then rsync -a "$$d/" "$(DIST_TMP)/"; fi; \
	done
	@if [ -d "$(DIST)" ]; then \
		$(call preserve_runtime,$(DIST),$(DIST_TMP)); \
	fi
	@rm -rf "$(DIST)"
	@mv "$(DIST_TMP)" "$(DIST)"
	@printf 'built: %s\n' "$(DIST)"

validate:
	@test -f "$(DIST)/default.yaml"
	@test -f "$(DIST)/default.custom.yaml"
	@test -f "$(DIST)/squirrel.custom.yaml"
	@test -f "$(DIST)/rime_mint.schema.yaml"
	@ruby -e 'require "yaml"; Dir["$(DIST)/**/*.yaml"].reject { |f| f.include?("/sync/") }.each { |f| YAML.load_file(f) }'
	@printf 'validated: %s\n' "$(DIST)"

deploy:
	@mkdir -p "$(BACKUPS)"
	@test -e "$(RIME_LINK)" || (printf 'missing %s\n' "$(RIME_LINK)" >&2; exit 1)
	@backup_dir="$(BACKUPS)/rime-$(STAMP)"; \
		rsync -a --delete "$(RIME_LINK)/" "$$backup_dir/"; \
		printf 'backup: %s\n' "$$backup_dir"; \
		$(MAKE) build; \
		$(MAKE) validate; \
		$(call preserve_runtime,$$backup_dir,$(DIST));
	@ln -sfn "$(DIST)" "$(RIME_LINK)"
	@if [ -x "$(SQUIRREL_BIN)" ]; then \
		cd "$(DIST)" && DYLD_LIBRARY_PATH="$(SQUIRREL_FRAMEWORKS)" "$(SQUIRREL_BIN)" --build; \
		"$(SQUIRREL_BIN)" --reload >/dev/null 2>&1 || true; \
	fi
	@printf 'deployed: %s -> %s\n' "$(RIME_LINK)" "$(DIST)"

rollback:
	@latest=$$(ls -dt "$(BACKUPS)"/rime-* 2>/dev/null | head -1); \
	test -n "$$latest" || (printf 'no backup found in %s\n' "$(BACKUPS)" >&2; exit 1); \
	ln -sfn "$$latest" "$(RIME_LINK)"; \
	if [ -x "$(SQUIRREL_BIN)" ]; then "$(SQUIRREL_BIN)" --reload >/dev/null 2>&1 || true; fi; \
	printf 'rolled back: %s -> %s\n' "$(RIME_LINK)" "$$latest"

diff:
	@test -d "$(DIST)" || (printf 'missing dist; run make build\n' >&2; exit 1)
	@diff -ruN "$(RIME_LINK)" "$(DIST)" || true

ai-on:
	@touch "$(ROOT)/.ai-enabled"
	@$(MAKE) build

ai-off:
	@rm -f "$(ROOT)/.ai-enabled"
	@$(MAKE) build

clean:
	@rm -rf "$(DIST_TMP)" "$(DIST)/build"
	@printf 'cleaned: %s and %s\n' "$(DIST_TMP)" "$(DIST)/build"

clean-build: clean

prune-backups:
	@mkdir -p "$(BACKUPS)"
	@ls -dt "$(BACKUPS)"/rime-* 2>/dev/null | tail -n +$$(($(KEEP_BACKUPS) + 1)) | xargs rm -rf
	@printf 'kept newest %s backups in %s\n' "$(KEEP_BACKUPS)" "$(BACKUPS)"

clean-backups:
	@rm -rf "$(BACKUPS)"
	@printf 'removed: %s\n' "$(BACKUPS)"
