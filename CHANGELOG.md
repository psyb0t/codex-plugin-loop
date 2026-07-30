# Changelog

All notable changes per release. Versions follow [semver](https://semver.org)
pre-1.0 conventions: minor bumps may include breaking changes (called out
explicitly), patch bumps are docs / build / fixes only.

## v0.3.0 — 2026-07-30

Rebuilt on `clock.sleep`. A killed turn no longer kills the loop.

- **Breaking. Requires the `clock.sleep` tool, which Codex ships disabled.**
  Add this to `~/.codex/config.toml` and restart the CLI:

  ```toml
  [features.current_time_reminder]
  enabled = true
  sleep_tool = true
  ```

  Both keys are load-bearing. The shorthand `current_time_reminder = true`
  enables the clock but leaves `sleep_tool` at its default of `false`, which
  exposes no sleep tool at all. Without it the loop now refuses to start rather
  than faking a wait with a shell `sleep`.
- **Breaking. Goal mode and the background timer terminal are gone.** The loop
  used to write itself into a Codex Goal and poll a `sleep` running in a
  session-owned background terminal. It now holds a single turn open and waits
  on `clock.sleep` between iterations, so there is no goal to clear, no terminal
  to poll, and nothing to stop except the loop itself. Existing loops do not
  migrate — start a new one with `$loop:loop`.
- **Talking to a running loop wakes it immediately.** `clock.sleep` ends early
  when new input arrives, so a message no longer waits out the rest of the
  interval before being seen. The loop handles what you said and goes back to
  waiting.
- **A killed turn is no longer a stopped loop.** Every progress report carries a
  `Loop state: active | interval_ms=<n> | iteration=<n> | until=<rule>` line.
  On the next turn the loop reads the most recent one and resumes from there, so
  Esc, a tool error, or a dropped turn are recoverable instead of terminal. The
  line repeats every iteration so the newest copy survives context compaction.
- **`$loop:stop` writes `Loop state: stopped`.** That terminator is what stops a
  resume, which makes it the only reliable way to end a run. Esc now pauses a
  loop rather than ending it — nothing runs while the turn is dead, so the loop
  picks back up on your next message.
- Sleep-call failures no longer end a run: an out-of-range or rejected
  `duration_ms` is clamped into the accepted 1–43200000 ms range and retried.
  Intervals longer than the 12-hour per-call cap are chained instead of silently
  shortened.
- Plugin metadata and `make test-integration` assertions track the new
  mechanism. The suite now also asserts the retired Goal-mode strings are
  absent, so a stale skill fails instead of passing on old wording.

## v0.2.0 — 2026-07-29

The loop stopped itself. Now it can't.

- **The loop no longer asks for approval mid-run.** A real run hit a step that
  wanted a decision, reported `Loop paused as blocked: implementation requires
  approval`, stopped its own timer, and sat there. The instructions you give at
  the start *are* the approval — the skill now says so outright and treats an
  approval prompt inside an iteration as the failure it is. If you want a
  checkpoint, put it in the instructions and it will ask exactly that and
  nothing else.
- **The loop can no longer end itself.** Previously "if blocked on user input,
  preserve progress and pause" gave it a legitimate-looking exit. That rule is
  gone. An item it cannot do is now recorded as blocked, skipped, and the next
  item picked up, with the timer started as normal. If everything left is
  blocked it says so and re-checks next iteration, because circumstances change
  between iterations.
- **New `$loop:stop` skill** to end a run: clears the loop goal and stops the
  timer terminal it started, leaving other background work alone. Its own
  instructions tell the agent never to invoke it on its own initiative —
  uncertainty, a needed decision, or having no unblocked work are explicitly
  *not* reasons to stop.
- The scope limits are unchanged and unrelated: the loop still refuses to widen
  filesystem, network, account, or external-action authority beyond what the
  instructions granted, and still won't take destructive action without explicit
  authorization. Those bound *what it does*, not *whether it keeps going* —
  something out of scope is skipped and reported, never escalated mid-loop.
- Controls are now just the two skills. `/goal pause`, `/goal resume`,
  `/goal clear`, `/ps` and `/stop` are no longer advertised anywhere;
  `$loop:loop` and `$loop:stop` are the whole interface.

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
