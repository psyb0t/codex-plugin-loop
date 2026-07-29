# loop

[![version](https://raw.githubusercontent.com/psyb0t/codex-plugin-loop/badges/version.svg)](https://github.com/psyb0t/codex-plugin-loop/releases)
[![license](https://raw.githubusercontent.com/psyb0t/codex-plugin-loop/badges/license.svg)](LICENSE)

Codex sits there waiting for you to type the next thing. This makes it stop
waiting. Give it an interval and some instructions and it grinds — execute,
verify, report, sleep, repeat — in the session you already have open, with the
context you already built, until the job's done or you tell it to fuck off.

**This is not a scheduler.** No cron entry, no daemon, no Scheduled task, no
nested `codex` process spawning off into the dark. It's a Goal plus a `sleep`
running in a background terminal your session owns. Close the CLI and it dies,
which is the entire point: nothing survives you, nothing runs behind your back,
nothing shows up at 4am to do something clever with your repo. If you want
something durable, go use cron like a normal person — that's a different tool
and this one isn't pretending to be it.

## Contents

- [Install](#install)
- [Use](#use)
- [Controls](#controls)
- [How it actually works](#how-it-actually-works)
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

## Use

```text
$loop:loop every 10 minutes: keep fixing the failing tests in ./api until they pass
```

Interval can be `30m`, `2h`, `every hour`, `45s` — anything that resolves to a
fixed number of seconds. Tack on a stop condition and it'll actually stop:

```text
$loop:loop 15m: work through the TODOs in internal/. Stop when there are none left.
```

No stop condition means it keeps going until you pause or clear the goal.

First iteration runs **immediately** — no waiting around for the first tick.
After that it does the work, verifies it, tells you what changed, then sleeps.
Every iteration reads the same chat context you've been building, so it knows
what it already did and doesn't redo it.

## Controls

Everything happens in the TUI you're already looking at:

| Command | What it does |
|---|---|
| `$loop:loop <interval>: <instructions>` | Start a loop, or change the interval / instructions of the running one |
| `$loop:stop` | End it — clears the goal, stops the timer |

Or just say "change it to every 5 minutes" and it'll update the running loop in
place.

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
  -> write it all into a Codex Goal
  -> inspect state, do the next safe increment, verify it, report
  -> start exactly ONE `sleep <n>` in a background terminal
  -> poll that terminal until it exits
  -> goal reloads the skill, marker sends it straight back to work
  -> repeat until the completion rule hits, or you run $loop:stop
```

The goal carries a `Loop mode: active` marker. On re-entry the skill sees it and
jumps straight to execution instead of re-parsing the goal text as if it were a
fresh request from you. That's the whole trick — Goal mode gives continuity
across turns, the background terminal gives the wait, and neither one needs a
process that outlives your session.

The sleep command is built **only** from a validated integer. Your instruction
text never lands in a shell command, no matter how creatively you phrase it.

## What it won't do

- **Calendar schedules.** "every Tuesday at 9" is a cron job, not this. Rejected on purpose.
- **Survive a closed terminal.** Kill the CLI, kill the loop. Not a bug.
- **Give itself more rope.** It runs in whatever sandbox and approval mode your session is already in. It won't widen filesystem, network, or account access, and it won't do destructive shit unless your instructions explicitly authorized that exact thing.
- **Stop itself.** Not when it's unsure, not when something needs a decision, not when everything left is blocked. A blocked item is a line in the report, not a reason to quit. Only the completion rule, `$loop:stop`, or clearing/pausing the goal ends a run.
- **Ask you for approval mid-run.** The instructions you gave it *are* the approval. Anything outside that scope gets skipped and reported, not escalated. Want a checkpoint? Put it in the instructions.
- **Run two timers.** One sleep at a time, always. A poll returning nothing is not "done".

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
