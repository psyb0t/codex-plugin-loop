# loop

[![version](https://raw.githubusercontent.com/psyb0t/codex-plugin-loop/badges/version.svg)](https://github.com/psyb0t/codex-plugin-loop/releases)
[![license](https://raw.githubusercontent.com/psyb0t/codex-plugin-loop/badges/license.svg)](LICENSE)

Codex sits there waiting for you to type the next thing. This makes it stop
waiting. Give it an interval and some instructions and it grinds — execute,
verify, report, sleep, repeat — in the session you already have open, with the
context you already built, until the job's done or you tell it to fuck off.

**This is not a scheduler.** No cron entry, no daemon, no Scheduled task, no
nested `codex` process spawning off into the dark. It's one turn that never
ends, parked on Codex's own `clock.sleep` between iterations. Close the CLI and
it dies, which is the entire point: nothing survives you, nothing runs behind
your back, nothing shows up at 4am to do something clever with your repo. If you
want something durable, go use cron like a normal person — that's a different
tool and this one isn't pretending to be it.

## Contents

- [Install](#install)
- [Turn the sleep tool on](#turn-the-sleep-tool-on)
- [Use](#use)
- [Controls](#controls)
- [How it actually works](#how-it-actually-works)
- [When it gets killed](#when-it-gets-killed)
- [What it won't do](#what-it-wont-do)
- [Development](#development)
- [License](#license)

## Install

```bash
codex plugin marketplace add psyb0t/agents
codex plugin add loop@psyb0t
```

The verb is `add`. There is no `codex plugin install` — that command does not
exist and will just tell you so. Start a fresh CLI session afterwards so the
skill loads.

## Turn the sleep tool on

The whole thing runs on `clock.sleep`, which Codex ships **off by default**. Put
this in `~/.codex/config.toml` and restart the CLI:

```toml
[features.current_time_reminder]
enabled = true
sleep_tool = true
```

Both keys. `current_time_reminder = true` on its own turns the clock on but
leaves `sleep_tool` at its default of `false`, and you get no sleep tool — the
table form above is the only shape that works. Without it the loop refuses to
start rather than faking a wait with a shell `sleep`.

## Use

```text
$loop:loop every 10 minutes: keep fixing the failing tests in ./api until they pass
```

Interval can be `30m`, `2h`, `every hour`, `45s` — anything that resolves to a
fixed number of seconds. Tack on a stop condition and it'll actually stop:

```text
$loop:loop 15m: work through the TODOs in internal/. Stop when there are none left.
```

No stop condition means it keeps going until you run `$loop:stop`.

First iteration runs **immediately** — no waiting around for the first tick.
After that it does the work, verifies it, tells you what changed, then sleeps.
Every iteration reads the same chat context you've been building, so it knows
what it already did and doesn't redo it.

## Controls

Everything happens in the TUI you're already looking at:

| Command | What it does |
|---|---|
| `$loop:loop <interval>: <instructions>` | Start a loop, or change the interval / instructions of the running one |
| `$loop:stop` | End it — the only reliable kill. Stops re-arming and writes the terminator so it can't resume |

Or just say "change it to every 5 minutes" and it'll update the running loop in
place. You don't have to wait for a tick to say it either — typing anything
wakes the sleep immediately, it deals with you, then goes back to waiting.

**It will not stop on its own and it will not ask you for anything.** That's the
whole point — you started it so you could walk away. If it hits something it
can't do, it writes that down, moves to the next thing, and keeps going. Ending
it is your call, and `$loop:stop` is how you make it.

If you *want* it to check in, say so in the instructions — "ask me before
touching prod" — and it'll do exactly that and nothing more.

## How it actually works

```text
$loop:loop
  -> parse interval + instructions + stop condition
  -> inspect state, do the next safe increment, verify it, report
  -> call clock.sleep(duration_ms) — exactly one, in the same breath as the report
  -> "Sleep completed."             -> next iteration
  -> "Sleep interrupted by new input." -> deal with you, then sleep again
  -> repeat until the completion rule hits, or you run $loop:stop
```

The trick is that it's all **one turn**. A plain assistant message with nothing
after it would end that turn and kill the loop, so every progress report ships
in the same step as the next sleep call. Nothing to poll, nothing to reload, no
process that outlives the session.

`clock.sleep` ends early the moment new input arrives, which is why talking to a
running loop works at all — your message *is* the interrupt. It takes
`duration_ms` and caps at 12 hours per call; anything longer gets chained.

The duration is built **only** from a validated integer. Your instruction text
never lands in a command, no matter how creatively you phrase it.

## When it gets killed

A turn can die without the loop being finished — you hit Esc, a tool blew up, or
it slipped and sent a bare message with no sleep after it. **None of those stop
the loop.** Only `$loop:stop` does, and that's deliberate: you asked for
something you can rely on until you explicitly kill it.

Every progress report carries a state line:

```text
Loop state: active | interval_ms=600000 | iteration=7 | until=tests pass
```

Next time you type anything, it reads the most recent one, sees a loop that was
never stopped, says so, and picks up at the next iteration. Repeating the line
every iteration is what makes it survive context compaction — the newest copy is
always near the end. `$loop:stop` writes `Loop state: stopped`, which is the
terminator that stops it coming back.

**The catch, and it's unavoidable:** while the turn is dead, nothing is running
— Codex only invokes the model when there's something to respond to. So a loop
killed by Esc resumes on your *next message*, not on a timer. Press Esc and walk
away and it stays dead until you're back.

**Esc is therefore not a reliable stop.** It pauses until you speak again.
`$loop:stop` is the kill switch.

## What it won't do

- **Calendar schedules.** "every Tuesday at 9" is a cron job, not this. Rejected on purpose.
- **Survive a closed terminal.** Kill the CLI, kill the loop. Not a bug — nothing is stored anywhere but the conversation.
- **Die quietly when the turn does.** Esc, a tool error, or a slipped message kills the turn, not the loop. See [When it gets killed](#when-it-gets-killed).
- **Give itself more rope.** It runs in whatever sandbox and approval mode your session is already in. It won't widen filesystem, network, or account access, and it won't do destructive shit unless your instructions explicitly authorized that exact thing.
- **Stop itself.** Not when it's unsure, not when something needs a decision, not when everything left is blocked. A blocked item is a line in the report, not a reason to quit. Only the completion rule, `$loop:stop`, or you saying so ends a run.
- **Ask you for approval mid-run.** The instructions you gave it *are* the approval. Anything outside that scope gets skipped and reported, not escalated. Want a checkpoint? Put it in the instructions.
- **Run two sleeps.** One in flight at a time, always. And it won't re-arm twice in a row without doing an iteration or handling your input in between — that's spinning, not waiting.

## Development

```bash
make help
make test
```

Validation runs in a pinned, network-disabled container with everything dropped
— no capabilities, read-only root, 256M, 64 pids. There are no dependencies to
install because there's no code — a manifest and two skills — and `make test`
checks they still say what they're supposed to say, including that the loop skill
still refuses to self-stop and the stop skill still refuses to fire on its own.

## License

WTFPL. See [LICENSE](LICENSE).
