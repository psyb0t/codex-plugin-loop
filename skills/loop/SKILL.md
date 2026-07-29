---
name: loop
description: Start or update an active recurring loop in the Codex CLI TUI by combining Goal mode with a background terminal timer. Use when the user invokes Loop, asks Codex to repeat or continue work at an interval while the terminal session stays open, or wants an active CLI loop changed, paused, resumed, or inspected.
---

# Loop

Keep the current interactive Codex CLI session working at a fixed interval.
Use Goal mode for continuity and a session-owned background terminal for timer
waits. Do not use Scheduled tasks, cron, a daemon, or a nested Codex process.

## Check the surface

Require an interactive Codex CLI session with Goal mode and unified background
terminals. If either capability is unavailable, explain that this active TUI
loop cannot run on the current surface. Do not claim that a loop started.

## Choose setup or execution

Inspect the active goal first. When it contains `Loop mode: active`, continue
that loop at **Run the loop** without parsing the goal text as a new user
request. Otherwise, treat the current request as setup or an update.

## Parse setup

Accept a fixed interval plus instructions. Supported forms include:

```text
$loop:loop 10m <instructions>
$loop:loop every hour: <instructions>
```

Extract:

- a positive fixed interval in seconds, minutes, hours, or days;
- instructions to execute on every iteration; and
- an optional completion or stop condition.

Ask one concise question only when the interval or instructions are missing.
Do not invent either. Reject calendar schedules and absolute times because this
loop is session-bound, not a durable scheduler.

Normalize the interval to a positive integer number of seconds. Never evaluate
the user's interval as code or interpolate unparsed user text into a shell
command.

## Set the goal

Treat explicit invocation of this skill as authorization to create or replace
the active Codex goal. Inspect the existing goal first. Reuse it when it already
represents the same loop; otherwise replace it after telling the user that the
current active goal will be superseded.

Store an objective no longer than the product's goal limit with this shape:

```text
Loop mode: active
Use $loop:loop to maintain this active TUI loop in the Codex CLI session.

Instructions:
<the user's instructions, preserved faithfully>

Interval seconds:
<normalized positive integer>

Completion rule:
<the user's rule, or "Continue until the user pauses or clears this goal.">

Start the first iteration immediately. Execute, verify, wait for the timer, and
repeat until the completion rule is met or the user pauses or clears the goal.
```

Preserve the user's intent, constraints, paths, and success criteria. Do not add
permissions or broaden the work. Use the active goal capability equivalent to
`/goal`; do not try to type a slash command through the shell.

## Start or update execution

After the goal is active, immediately continue at **Run the loop**. Do not
return after merely describing the loop. Keep the goal active across turn
boundaries until the completion rule is met, the user pauses or clears it, or
progress requires user input.

Give one concise startup update containing the normalized interval, completion
rule, and these controls:

- `/goal pause` pauses the loop objective;
- `/goal resume` resumes it;
- `/goal clear` removes it;
- `/ps` inspects the current timer process; and
- `/stop` stops session-owned background terminals.

The loop is intentionally not durable. Closing the CLI, ending the session, or
stopping its terminal processes ends active waiting.

## Run the loop

Read the active goal before every iteration. Require `Loop mode: active`,
preserved instructions, a positive integer `Interval seconds` value, and a
completion rule. Stop and report a malformed goal instead of guessing.

For each iteration:

1. Inspect current external or workspace state.
2. Identify completed work and avoid repeating it.
3. Select the next safe, meaningful increment.
4. Execute it within the user's granted scope and current sandbox.
5. Verify the result with the most relevant checks.
6. Give a concise progress update with the delta and verification result.

Continue within an iteration while useful work remains and the action is safe.
Do not stop after merely describing what should happen next.

Never broaden filesystem, network, account, or external-action authority beyond
the goal instructions. Do not perform destructive or irreversible actions
unless those instructions explicitly authorize the exact scope. Validate
untrusted input at every boundary and keep secrets out of logs and summaries.

Evaluate the completion rule after verification:

- If complete, mark the active goal complete and report `complete`.
- If the goal is paused or cleared, stop without starting another timer.
- If blocked on user input, do not spin. Preserve progress, report the minimum
  required action, and pause or leave the goal awaiting the user as supported.
- If useful work remains, report `continue`, then wait for the next iteration.

## Wait for the next iteration

Start exactly one timer with the unified execution tool using:

```text
sleep <Interval seconds>
```

Construct the command only from the validated decimal integer. Never place
instruction text or the original interval expression in the command.

When execution yields a background terminal identifier, retain it and poll
that same terminal with empty input until the timer exits successfully. A poll
that returns no output is not completion. Do not start another timer while one
is running. If the timer fails or is stopped, inspect the active goal before
deciding whether to retry or exit.

After the timer finishes, re-read the goal and current workspace state, then
run the next iteration. Across automatic Goal-mode turns, the goal's explicit
`$loop:loop` invocation reloads this skill; the `Loop mode: active` marker sends
execution directly back to **Run the loop**.

Use this compact progress shape:

```text
Loop status: continue | complete | blocked
Delta: <work performed this iteration>
Verification: <checks and outcome>
Next: <next checkpoint, timer wait, or blocker resolution>
```
