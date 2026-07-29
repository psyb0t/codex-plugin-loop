# Loop

[![version](https://raw.githubusercontent.com/psyb0t/codex-plugin-loop/badges/version.svg)](https://github.com/psyb0t/codex-plugin-loop/releases)
[![license](https://raw.githubusercontent.com/psyb0t/codex-plugin-loop/badges/license.svg)](LICENSE)

Codex plugin that repeatedly executes instructions while the CLI TUI stays open.

**Status:** early development. Requires an interactive Codex CLI session with
Goal mode and unified background terminals.

## Quick start

```bash
codex plugin marketplace add psyb0t/agents
codex plugin add loop@psyb0t
```

Or via the Makefile: `make marketplace-add && make install`.

The install verb is `plugin add` — there is no `codex plugin install`. Start a
new Codex CLI session afterwards so the bundled skill loads.

## Use

Start a recurring loop from an interactive Codex CLI session:

```text
$loop:loop every 10 minutes: <instructions to execute on every run>
```

Other accepted forms include a fixed interval such as `30m` or a natural form
such as `every hour`. Include a completion rule when the loop should stop
automatically. Calendar schedules and absolute times are intentionally outside
the plugin's scope.

Loop starts a Codex Goal in the current TUI, executes the first iteration
immediately, then waits on a session-owned background timer before continuing.
Each iteration uses the existing chat context, avoids repeating completed work,
executes the next meaningful increment, verifies it, and reports what changed.

Keep the Codex CLI process and its TUI session open. This is an active loop, not
a durable scheduler: closing the CLI or ending its background processes stops
the wait.

## How it works

```text
$loop:loop
  -> parse interval + instructions + completion rule
  -> create or update the active Codex Goal
  -> inspect current state
  -> execute the next safe increment
  -> verify and report
  -> launch one validated sleep timer
  -> wait on the timer's background terminal
  -> process completion resumes Codex
  -> repeat, complete, or block
```

The single `$loop:loop` skill handles setup, execution, and timer waiting. It
uses Codex's Goal mode and unified background-terminal mechanism and does not
create a Scheduled task, cron entry, daemon, or nested `codex` process.

Control the active loop from the TUI:

- `/goal pause` pauses the objective.
- `/goal resume` resumes it.
- `/goal clear` removes it.
- `/ps` shows the current timer process.
- `/stop` stops session-owned background terminals.

The loop retains the current sandbox and approval settings. It does not grant
itself additional permissions.

## Repository layout

This repository root is the plugin source. The central marketplace references it
with `source: "url"` and no `path` field, which makes the whole repository the
plugin. `git-subdir` is not usable here: it requires a `path`, and Codex rejects
root-equivalent values like `"."` or `"./"` outright, so the plugin would never
be found.

```text
.codex-plugin/plugin.json   Codex manifest
skills/loop/SKILL.md        Setup, execution, controls, and timer handling
```

## Development

```bash
make help
make test
```

Validation runs in a pinned, network-disabled development container. The
repository has no package dependencies.

## License

WTFPL. See [LICENSE](LICENSE).
