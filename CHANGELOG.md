# Changelog

All notable changes per release. Versions follow [semver](https://semver.org)
pre-1.0 conventions: minor bumps may include breaking changes (called out
explicitly), patch bumps are docs / build / fixes only.

## v0.1.1 — 2026-07-29

- Rewrote the README. The old one described the plugin the way a spec does —
  it never said what the thing is for, buried the fact that it is deliberately
  not a scheduler, and left the actual limits ("what it won't do") unstated.
  The new one leads with the use case, states the non-durability up front as a
  design choice rather than a caveat, documents the controls as a table, and
  spells out the refusals: no calendar schedules, no surviving a closed
  terminal, no widening its own permissions, no spinning on a blocker, never
  more than one timer.

## v0.1.0 — 2026-07-29

First release.

- `$loop:loop` skill that keeps an interactive Codex CLI session working at a
  fixed interval. It parses an interval, instructions and an optional completion
  rule, stores them in a Codex Goal, runs the first iteration immediately, then
  waits on a session-owned background timer before each subsequent iteration.
- Deliberately not durable: no Scheduled task, cron entry, daemon, or nested
  `codex` process. Closing the CLI or stopping its background terminals ends the
  loop. Calendar schedules and absolute times are out of scope.
- The loop keeps the session's existing sandbox and approval settings and does
  not grant itself additional permissions. The sleep command is built only from
  a validated integer, never from unparsed user text.
- Installed from the central catalog with `codex plugin add loop@psyb0t` after
  `codex plugin marketplace add psyb0t/agents`. The plugin lives at the
  repository root and is referenced with `source: "url"` and no `path`.
- Validation (`make test`) runs in a pinned, network-disabled container: the
  manifest must be valid JSON, the skill must be the only one under `skills/`,
  and it must still describe Goal mode, the `Loop mode: active` marker, the
  validated sleep command, and the no-nested-Codex constraint.
