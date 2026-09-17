# model-based-design-discipline

An [Agent Skill](https://code.claude.com/docs/en/skills) that makes a coding agent behave like a
careful model-based-design engineer when it edits **Simulink / Stateflow models that generate
embedded C**.

It is not a modelling tutorial and it does not replace MathWorks' own `building-simulink-models` /
`model_edit` tooling. It governs the *process around* an edit — what to check before, what to keep
intact during, and what to prove after.

## Why

Agents are good at making a Simulink edit and bad at the things that surround it: they delete a
constant from one chart and leave three other producers alive, they invent a second mechanism for a
problem the repo already solved, they hand back a diagram no human can review, and they report
success from a simulation that agreed with its own wrong assumption.

These seven rules were written down after each of those failures cost real debugging time on a
production vehicle-control model. Encoding them as a skill stopped them recurring.

## What it contains

| File | Contents |
|---|---|
| `SKILL.md` | the seven rules, each with the defect class it prevents, and the gate to run before any edit |
| `references/dependency-checklist.md` | the six questions to answer before an edit; the hand-synced contract table; the port-reattach trap; why bit-index conventions must be read, never inferred |
| `references/stateflow-traps.md` | eleven Stateflow traps — catch-all guards, junction-ladder ordering, silent re-parenting, junctions costing no time step, action-language limits — each with symptom, cause and fix |
| `references/allocation.md` | the model-vs-hand-written-C decision rule, and the two constraints that force the split |
| `references/verification-loop.md` | how to build a scratch harness that never touches the production model, what to assert, and what a harness cannot prove |
| `scripts/check_chart_layout.m` | a runnable MATLAB check for diagram tidiness: overlapping states, overlapping labels, children outside their parent, and chart-owned arcs. Must report `0`. |

### The seven rules, in one line each

1. **Analyse every dependency first** — every producer, consumer, router and namer, on both sides of the codegen boundary.
2. **Reuse before you build** — search for the existing component first.
3. **Follow the mechanism that already exists** — never introduce a second way to do a solved problem.
4. **Geometry is part of the deliverable** — an unreadable chart is an unreviewable one; if it cannot be done cleanly in place, stop and say so *before* editing.
5. **Verify every time** — layout, scenarios, model check, codegen, target compile. Every edit, not every feature.
6. **Build and run it yourself** — then confirm the artefact moved and the target restarted.
7. **Put the responsibility in the right layer** — decide from the knowledge the code needs, not from where the symptom appeared.

## Install

Copy the folder into a skills directory:

```bash
# personal, all projects
cp -r model-based-design-discipline ~/.claude/skills/

# or project-local, checked in with the repo
cp -r model-based-design-discipline .claude/skills/
```

Claude Code picks it up on the next session. It activates when a request involves editing a chart
or model, adding something that crosses the codegen boundary, or verifying a model change.

Works with any agent runtime that reads `SKILL.md` frontmatter; the references are plain Markdown
and the check script is plain MATLAB.

## Adapting it to your project

The rules are generic; three things are worth making specific in a fork:

- **the verification commands** in Rule 5 — replace the generic loop with your actual script names
- **the hand-synced contract table** in `references/dependency-checklist.md` — list *your*
  boundary contracts and, honestly, what enforces each one
- **the layer table** in Rule 7 — rename the layers to whatever your architecture calls them

`scripts/check_chart_layout.m` needs no adaptation: it discovers the charts in the model you pass.

## License

MIT. See `LICENSE`.
