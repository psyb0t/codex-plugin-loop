DEV_IMAGE := loop-plugin-dev:local
CODEX_MANIFEST := .codex-plugin/plugin.json
SKILL_FILES := skills/loop/SKILL.md skills/stop/SKILL.md
MARKETPLACE := psyb0t/agents
DEV_RUN := docker run --rm --network none --cap-drop ALL \
	--security-opt no-new-privileges:true --read-only \
	--tmpfs /tmp:rw,noexec,nosuid,size=16m \
	--memory 256m --cpus 1 --pids-limit 64 \
	-v $(PWD):/work:ro -w /work $(DEV_IMAGE)

.PHONY: help dev-image shell lint lint-fix format test test-unit test-integration test-coverage build run clean generate dep marketplace-add install

help: ## Show supported commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev-image: ## Build the pinned validation container
	docker build --tag $(DEV_IMAGE) --file Dockerfile.dev .

shell: dev-image ## Open a Python REPL in the validation container
	$(DEV_RUN)

lint: dev-image ## Validate manifests and reject scaffold placeholders
	$(DEV_RUN) -m json.tool $(CODEX_MANIFEST) >/dev/null
	$(DEV_RUN) -c 'from pathlib import Path; files=[Path(p) for p in "$(SKILL_FILES)".split()]; bad=[str(p) for p in files if "[TODO:" in p.read_text()]; raise SystemExit("scaffold placeholders: "+", ".join(bad) if bad else 0)'

lint-fix: lint ## Run lint checks; no automatic rewrites are required

format: lint ## Verify canonical JSON and skill structure

test: lint test-integration ## Run the complete repository validation suite

test-unit: lint ## Run fast manifest and skill validation

test-integration: dev-image ## Validate the plugin layout and both bundled skills
	$(DEV_RUN) -c 'import json, pathlib; manifest=json.loads(pathlib.Path("$(CODEX_MANIFEST)").read_text()); loop=pathlib.Path("skills/loop/SKILL.md").read_text(); stop=pathlib.Path("skills/stop/SKILL.md").read_text(); assert sorted(str(p) for p in pathlib.Path("skills").glob("*/SKILL.md")) == ["skills/loop/SKILL.md", "skills/stop/SKILL.md"]; assert manifest["skills"] == "./skills/"; assert "clock.sleep" in loop and "duration_ms" in loop and "43200000" in loop; assert "[features.current_time_reminder]" in loop and "enabled = true" in loop and "sleep_tool = true" in loop; assert "Sleep completed." in loop and "Sleep interrupted by new input." in loop; assert "Keep the turn alive" in loop and "nested Codex process" in loop; assert "Resume a loop that died" in loop and "Loop state: active" in loop and "Loop state: stopped" in loop; assert "Never ask, never self-stop" in loop and "Do not end the loop yourself" in loop and "Do not ask the user for approval" in loop; assert "Goal mode" not in loop and "Loop mode: active" not in loop; assert "name: stop" in stop and "Only the user calls this" in stop and "Do not invoke this skill on your own" in stop and "clock.sleep" in stop and "Loop state: stopped" in stop'

test-coverage: test ## Run validation; executable coverage is not applicable

build: test ## Validate the distributable plugin bundle

run: ## Explain how to invoke the installed plugin
	@printf '%s\n' 'Start an interactive Codex CLI session and invoke $$loop:loop with an interval and instructions.'

clean: ## Remove the local development image
	docker image rm $(DEV_IMAGE) 2>/dev/null || true

generate: ## Confirm there is no generated source
	@printf '%s\n' 'No generated source.'

dep: dev-image ## Confirm the repository has no package dependencies
	@printf '%s\n' 'No package dependencies.'

marketplace-add: ## Register the central psyb0t marketplace with Codex
	codex plugin marketplace add $(MARKETPLACE)

install: ## Install Loop from the central Codex marketplace
	codex plugin add loop@psyb0t
