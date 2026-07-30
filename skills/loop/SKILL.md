---
name: loop
description: Keep an interactive Codex CLI session working at a fixed interval by holding one active turn open and waiting on the input-interruptible clock.sleep tool between iterations. Use when the user invokes Loop, asks Codex to repeat or continue work at an interval while the terminal session stays open, or wants a running loop's interval, instructions, or completion rule changed.
---

# Loop

Keep the current interactive Codex CLI session working at a fixed interval.
One turn stays open for the whole run: execute, verify, report, wait on
`clock.sleep`, repeat. Do not use Scheduled tasks, cron, a daemon, a background
terminal timer, or a nested Codex process.

## Require the clock.sleep tool

This loop is built on `clock.sleep`, which is behind a feature flag that is off
by default. Before claiming a loop started, confirm the `clock.sleep` tool is
actually available in this session.

If it is not, do not start a loop and do not fake one with a shell `sleep`. Tell
the user to add this to `~/.codex/config.toml` and restart the CLI:

```toml
[features.current_time_reminder]
enabled = true
sleep_tool = true
```

Both keys are required. The shorthand `current_time_reminder = true` enables the
clock but leaves `sleep_tool` at its default of `false`, which exposes no sleep
tool. The table form above is the only shape that turns it on.

## Resume a loop that died

A loop lives in one turn, and a turn can die without the loop being over:
the user pressed Esc, a tool error killed the turn, or you slipped and sent a
plain message with no sleep after it. None of those are a stop.

**At the start of every turn, before anything else, scan back through the
conversation for the most recent `Loop state:` line.**

- `Loop state: active ...` — a loop ran and never stopped. **Resume it.**
- `Loop state: stopped` — the last loop ended properly. Do nothing.
- No such line — no loop has run in this session. Do nothing.

That line carries everything needed to pick the loop back up: the interval, the
completion rule, and the iteration number. Recover them from the most recent one
and keep going from the next iteration.

Codex may also have recorded a marker saying the previous turn was interrupted
on purpose. Treat it as confirmation of *how* the loop died, never as a reason
not to resume — only `$loop:stop` ends a loop. Say in one line that the loop was
interrupted and is resuming, then immediately run an iteration and sleep. Do not
ask whether to resume.

Resuming can only happen while you are running, and after the turn dies you are
not running until the user's next message. So a loop killed by Esc stays dead
until the user says anything at all — then it picks itself straight back up.

If a state line says `active` but the conversation no longer carries the rest of
these instructions — deep context compaction can drop them while the repeated
state line survives — reload this skill with `$loop:loop` and resume from the
recovered interval and completion rule rather than guessing at the procedure.

## Parse the request

Accept a fixed interval plus instructions. Supported forms include:

```text
$loop:loop 10m <instructions>
$loop:loop every hour: <instructions>
```

Extract:

- a positive fixed interval in seconds, minutes, hours, or days;
- instructions to execute on every iteration; and
- an optional completion or stop condition.

Ask one concise question only when the interval or instructions are missing. Do
not invent either. Reject calendar schedules and absolute times — this loop is
bound to one live turn, not a durable scheduler.

Normalize the interval to a positive integer number of **milliseconds** for
`clock.sleep`. Never evaluate the user's interval as code.

Hold the normalized interval, the instructions as the user wrote them, and the
completion rule (defaulting to "continue until the user stops the loop") for the
rest of the run. There is no goal and no external store: the open turn carries
them, and the `Loop state:` line in every report is the written record that
survives the turn dying.

## Start

Give one concise startup update naming the interval, the completion rule, and
one line saying `$loop:stop` ends the loop. Do not advertise slash commands —
`$loop:loop` and `$loop:stop` are the interface.

Run the first iteration **immediately**. Do not sleep before the first one and
do not return after merely describing the loop.

The loop is intentionally not durable across sessions. It survives a killed turn
by resuming on the next one, but closing the CLI or ending the session ends it —
there is no state anywhere except this conversation.

## Run an iteration

1. Inspect current external or workspace state.
2. Identify completed work and avoid repeating it.
3. Select the next safe, meaningful increment.
4. Execute it within the user's granted scope and current sandbox.
5. Verify the result with the most relevant checks.
6. Report the delta and the verification result.

Continue within an iteration while useful work remains and the action is safe.
Do not stop after merely describing what should happen next. Apply the change
you prepared — a prepared plan the user never sees applied is a wasted
iteration.

Never broaden filesystem, network, account, or external-action authority beyond
the instructions the loop started with. Do not perform destructive or
irreversible actions unless those instructions explicitly authorize the exact
scope. Validate untrusted input at every boundary and keep secrets out of logs
and summaries.

Those limits are about SCOPE, not about pausing. Something outside the granted
scope is skipped and reported, never escalated to the user mid-loop and never
used as a reason to stop.

Evaluate the completion rule after verification. If it is met, report `complete`
with `Loop state: stopped` and end the turn — a completed run that signs off
still saying `active` gets resurrected by the next thing the user types.
Otherwise report `continue` and wait.

## Keep the turn alive

The whole loop is one turn. **A standalone assistant message with no tool call
ends that turn and kills the loop.** So every progress report is emitted in the
same step as the next `clock.sleep` call, never as a final answer on its own.

Report, wait, repeat — in one unbroken chain. The only deliberate end is a final
message with no follow-up sleep, and that happens only when the loop is
genuinely over.

## Wait for the next iteration

Call `clock.sleep` exactly once with `duration_ms` set to the normalized
interval. One sleep in flight, always.

`duration_ms` accepts 1 to 43200000 (12 hours). For an interval longer than 12
hours, chain consecutive sleeps and track the elapsed total until the interval
is covered — do not silently shorten the interval the user asked for.

The result text tells you which of two things happened:

- **`Sleep completed.`** — the interval elapsed. Run the next iteration.
- **`Sleep interrupted by new input.`** — the user typed something. Handle it
  first, then re-arm.

On an interruption: read what the user said and act on it. If it changes the
loop — a new interval, different instructions, a new completion rule — apply the
change and keep going under the new terms. If it is a question or an unrelated
request, answer or do it. Then call `clock.sleep` again in the same step as the
reply, exactly as in **Keep the turn alive**. An interruption is not a stop.

If the call itself fails — an out-of-range `duration_ms`, a rejected argument, a
tool error — that is not a stop either. Fix the argument (clamp into the 1 to
43200000 range) and call it again. Only give up on sleeping if the tool is
missing entirely, which means the feature was turned off mid-session; report
that and say what to re-enable.

Two things to know about the interrupt path:

- If input is already queued when `clock.sleep` is called, it returns
  `Sleep interrupted by new input.` **immediately, without sleeping**. That is
  correct behavior, not a failure. Handle the input and re-arm.
- Because of that, never call `clock.sleep` twice in a row without either
  running an iteration or handling input in between. Two immediate returns
  back-to-back mean you are spinning — drain the input and do the work.

## Never ask, never self-stop

The user started this loop so it would run without them. Two hard rules follow.

**Do not ask the user for approval, confirmation, or a decision inside an
iteration.** Not for a plan, not for a next step, not for permission to apply
something already prepared. Treat the loop's instructions as the approval — they
are what the user authorized when they started it. The only exception is when
those instructions explicitly say to check in; then ask exactly what they say to
ask, and keep the loop running while waiting rather than halting it.

**Do not end the loop yourself.** Only three things end it: the completion rule
being met, the user invoking `$loop:stop`, or the user saying so in the session.
Never stop sleeping because you are uncertain, because something needs a
decision, or because progress feels stuck.

A turn dying is not one of those three. If the turn is killed — Esc, a tool
error, an accidental plain message — the loop is not over; it is interrupted,
and the next turn resumes it per **Resume a loop that died**.

When an item cannot be done — it needs authority the loop never granted, an
external dependency is unavailable, a decision is genuinely the user's — do NOT
halt. Record it in the progress report as blocked with the reason, pick the next
item that CAN move, and sleep as normal. A blocked item is a line in a report,
not a reason to stop working.

If every remaining item is blocked, say so plainly in the report, then still
sleep and re-check on the following iteration; circumstances change between
iterations and something may have unblocked.

## Progress shape

Use this compact shape, always paired with the next `clock.sleep` call:

```text
Loop state: active | interval_ms=<n> | iteration=<n> | until=<completion rule>
Loop status: continue | complete | blocked
Delta: <work performed this iteration>
Verification: <checks and outcome>
Next: <next checkpoint, wait duration, or blocker resolution>
```

The `Loop state:` line is what makes a dead loop recoverable, so it goes in
**every** report, not just the first. Repeating it means the newest copy is
always near the end of the conversation, where it survives context compaction —
and a resume only ever needs the most recent one.

Write it verbatim in that shape. It is parsed by you on the next turn, so
paraphrasing it or dropping a field is what breaks recovery.

When the loop genuinely ends — completion rule met — emit `Loop state: stopped`
so a later turn does not resurrect it.
