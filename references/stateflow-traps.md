# Stateflow traps

Eleven traps that produce wrong behaviour without producing an error. Each cost real debugging time
on a production chart. Read before the first chart edit of a session.

---

## T1 — a catch-all guard at execution order 1 makes every later arc dead code

**Symptom.** A newly added transition never fires. The chart looks right; simulation takes the old
path.

**Cause.** An existing arc leaving the same state has a broad guard — `queue[0].id ~= 0`,
`cmd > 0`, `~isempty(...)` — and sits at execution order 1. It matches the new case too, so it
fires first and the new arc is unreachable.

**Fix.** Narrow the broad guard rather than reordering:
`queue[0].id ~= 0 && queue[0].id ~= CMD_NEW`. This is a label edit only — no geometry moves, no
execution order shifts, no other arc is touched.

**Check for it:** before adding an arc to a state, list *all* existing outgoing arcs with their
execution orders and ask which of them could also match your new condition.

---

## T2 — in a junction ladder, the condition rung must be ExecutionOrder 1

**Symptom.** One rung of a decision ladder is never taken.

**Cause.** The ladder's "spine" (the fall-through arc to the next junction) is at a lower execution
order than the rung hanging off that junction. The spine wins and the rung is skipped.

**Fix.** At every junction, the **condition rung gets ExecutionOrder 1** and the spine gets 2.

---

## T3 — moving a state silently re-parents its transitions to the chart

**Symptom.** After a layout tidy-up, firing one transition resets *every* parallel region in the
chart — states that were not involved snap back to their default.

**Cause.** When a state is dragged or repositioned programmatically, Stateflow may re-assign an
attached transition's parent to the **chart** rather than the enclosing region. A chart-owned arc
is a chart-level transition: taking it exits and re-enters the whole chart.

**Fix.** After any move, check `t.getParent` for every transition; it must be the region, not the
chart. Re-parent by deleting and re-creating the transition inside the correct parent.
`scripts/check_chart_layout.m` reports these as `CHART-OWNED arc`.

---

## T4 — junctions cost no time step; only states hold across steps

**Symptom.** A designer inserts junctions expecting one decision per step, and the whole chain
executes in a single step — or, inversely, a timing assumption built on "each junction is a tick"
is wrong by many steps.

**Cause.** A complete path through connective junctions is evaluated within one chart execution.
Only entering a **state** ends the step.

**Fix.** If you need a step to pass, you need a state. If you need several decisions in one step,
junctions are correct and free.

---

## T5 — a wrapped guard needs a trailing `...`

**Symptom.** `Parse error` on a transition label that looks fine.

**Cause.** A guard expression wrapped across two lines. Guards require MATLAB line continuation
(`...`) at the break. **Actions do not** — which is why the mistake is easy to make: the same
wrapping works one line lower.

**Fix.** Add `...` at the end of each continued guard line, or keep the guard on one line.

---

## T6 — under the C action language, `if` inside a state action is rejected

**Symptom.** `Unexpected token 'if'` inside an `en:`/`du:` action.

**Cause.** The chart's action language is C, which does not accept statement-level branching in
state actions.

**Fix.** Branch with **transitions and junctions**, not with `if`. If the logic genuinely needs
expressions — string handling, array compare, arithmetic over a vector — move it into a **MATLAB
Function block** outside the chart. Note the trade: MATLAB action language accepts `if`, but then
custom C calls (a print/log function, a hand-written helper) are unavailable, so most production
charts keep C and push expression work outward. See `allocation.md`.

---

## T7 — every chart timer is a tick count

**Symptom.** After a step-size change, every timeout in the model is wrong by the same ratio, and
nothing warns.

**Cause.** Counters implemented as `cnt = cnt + 1` with a threshold are counting **executions**,
not seconds.

**Fix.** Derive thresholds from a single named step-size constant, or use Stateflow temporal logic
(`after(5, sec)`) where absolute time is what you actually mean. At minimum, put the conversion in
one place and comment the step size next to it.

---

## T8 — a Data Store Memory left on `Inherit: auto` fails at compile

**Symptom.** Compile error about an unresolved or ambiguous data store type, often far from the
store itself.

**Cause.** Data stores do not reliably infer a bus/enum type from their writers.

**Fix.** Set the **data type and the signal type explicitly** on the Data Store Memory block —
never leave inheritance to resolve it.

---

## T9 — a port count change re-attaches model-reference lines by position

**Symptom.** After adding or removing a port on a referenced model, signals are silently connected
to the wrong ports. Everything compiles; behaviour is scrambled.

**Cause.** Simulink re-attaches existing lines to the model-reference block **by port index**, not
by port name.

**Fix.** After any port count change, re-verify **every** connection to that block **by name**.
Script the verification if the block has more than a handful of ports.

---

## T10 — a field appended to a model-side bus that mirrors a hand-written struct

**Symptom.** Generated code and hand-written code disagree about a struct layout; fields read as
garbage.

**Cause.** A bus in the data dictionary mirrors a struct owned by the hand-written side. Adding to
the model-side copy changes the generated definition and breaks the mirror.

**Fix.** Append to the **hand-written struct** and re-mirror it into the dictionary; never add to
the model-side copy alone. If the two are supposed to be identical, generate one from the other.

---

## T11 — never run auto-layout on a hand-organised model

**Symptom.** A single small edit produces a 200-line diff and an unrecognisable diagram.

**Cause.** Auto-arrange repositions everything it can reach.

**Fix.** Use explicit `add_block` position vectors and explicit `add_line` routing. Script the
layout so it survives further edits, and check it with `scripts/check_chart_layout.m`.

---

## Quick pre-edit checklist

- [ ] listed every outgoing arc of the source state, with execution orders (T1)
- [ ] the new rung is ExecutionOrder 1 at its junction (T2)
- [ ] no state was moved; if one was, every `getParent` re-checked (T3)
- [ ] step-count vs state-count timing is what I think it is (T4)
- [ ] guards on one line, or continued with `...` (T5)
- [ ] no `if` in a state action under C action language (T6)
- [ ] timer thresholds derive from the named step size (T7)
- [ ] every new Data Store Memory has an explicit type (T8)
- [ ] port counts unchanged, or every line re-verified by name (T9)
- [ ] no field added to a model-side mirror of a hand-written struct (T10)
- [ ] no auto-layout run (T11)
