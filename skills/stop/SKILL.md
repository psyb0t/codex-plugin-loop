---
name: stop
description: Stop the active Loop in this Codex CLI session — stop re-arming clock.sleep and close out the turn the loop was running in. Use ONLY when the user explicitly asks to stop, end, kill, or cancel the loop. Never invoke this on your own initiative while a loop is running.
---

# Stop the loop

End the active Loop in this session: stop re-arming `clock.sleep`, report what
the run got done, and let the turn close.

## Only the user calls this

**Do not invoke this skill on your own.** A running loop is meant to keep
running. Being uncertain, hitting something that needs a decision, running out
of unblocked work, or judging that the loop "should" end are NOT reasons to
stop it — the loop skill covers all of those by reporting and continuing.

Invoke this only when the user explicitly says to stop, end, kill, cancel, or
halt the loop, or when the loop's own instructions name a condition and that
condition is now demonstrably met.

If the loop already met its completion rule, it closes out on its own — that
path does not need this skill.

## What to do

Invoking this while a loop is waiting counts as new input, so the pending
`clock.sleep` returns `Sleep interrupted by new input.` and hands control back
mid-turn. That is the moment this skill runs.

1. If no loop is running and the most recent `Loop state:` line in the
   conversation says `stopped` — or there is no such line at all — there is
   nothing to stop; say so and change nothing.
2. Do **not** call `clock.sleep` again. Skipping the re-arm is what ends the
   loop — there is no timer to kill and no goal to clear.
3. Emit `Loop state: stopped`. This is the load-bearing step: the loop skill
   resumes any loop whose latest state line still says `active`, so without
   this terminator the next thing the user types brings the loop back.
4. Report what the run accomplished as a final message with no follow-up tool
   call, which closes the turn the loop was living in.

Use this shape:

```text
Loop state: stopped
Loop stopped.
Completed: <what the loop got done>
Left undone: <anything outstanding, or "nothing">
```

This is also how a loop that was killed mid-run gets put down for good. If the
user pressed Esc and then says to stop, there is no live turn to close, but the
latest state line still says `active` and would trigger a resume — write the
terminator anyway.

Stopping discards the loop's state outright — the instructions, interval, and
completion rule lived in that turn and go with it. Starting again means giving
them again with `$loop:loop`.
