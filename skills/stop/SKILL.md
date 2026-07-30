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
halt the loop.

That is the whole list. A completion rule being met is **not** on it: the loop
closes itself out on that path and writes its own terminator, so a rule you
judge to be satisfied is never a reason to reach for this skill. Deciding that
some condition "counts as" the stop condition is the self-stop this plugin
exists to prevent.

## What to do

Invoking this while a loop is waiting counts as new input, so the pending
`clock.sleep` returns `Sleep interrupted by new input.` and hands control back
mid-turn. That is the moment this skill runs.

1. Find the most recent `Loop state:` line in the conversation. If it says
   `stopped`, or there is no such line at all, there is nothing to stop — say so
   and change nothing. Only a latest line reading `active` needs stopping, and
   it needs it whether or not a turn is still live.
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

Stopping retires the loop rather than pausing it. The old `Loop state: active`
lines stay in the conversation as history, but the terminator supersedes them,
so nothing resumes from them. Starting again means giving the interval,
instructions, and completion rule fresh with `$loop:loop`.
