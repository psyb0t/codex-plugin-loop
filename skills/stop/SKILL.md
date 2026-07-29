---
name: stop
description: Stop the active Loop in this Codex CLI session — clear the loop goal and stop the session-owned timer terminal. Use ONLY when the user explicitly asks to stop, end, kill, or cancel the loop. Never invoke this on your own initiative while a loop is running.
---

# Stop the loop

End the active Loop in this session: clear the loop goal so it stops reloading
the loop skill, and stop the session-owned background terminal running the
timer.

## Only the user calls this

**Do not invoke this skill on your own.** A running loop is meant to keep
running. Being uncertain, hitting something that needs a decision, running out
of unblocked work, or judging that the loop "should" end are NOT reasons to
stop it — the loop skill covers all of those by reporting and continuing.

Invoke this only when the user explicitly says to stop, end, kill, cancel, or
halt the loop, or when the loop's own goal instructions name a condition and
that condition is now demonstrably met.

If the loop already met its completion rule, it marks itself complete on its own
— that path does not need this skill.

## What to do

1. Read the active goal. If it does not carry the `Loop mode: active` marker,
   there is no loop to stop; say so and change nothing.
2. Clear the loop objective using the active goal capability equivalent to
   `/goal clear`. Do not try to type a slash command through the shell.
3. Stop the session-owned background terminal running the timer. Stop only the
   terminal this loop started — leave any other background work in the session
   alone.
4. Confirm in one line: the loop is stopped, and what it had completed.

Use this shape:

```text
Loop stopped.
Completed: <what the loop got done>
Left undone: <anything outstanding, or "nothing">
```

Stopping clears the goal outright — the instructions, interval, and completion
rule are gone. Starting again means giving them again with `$loop:loop`.
