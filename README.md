# model-based-design-discipline

Rules that make an AI coding agent behave like a careful model-based-design engineer when it edits
**Simulink / Stateflow models that generate embedded C**.

Vendor-neutral. It is plain Markdown plus one MATLAB script — no plugin, no runtime, no
dependency on a particular assistant, IDE or MCP server. If your agent can read a file and run
MATLAB, it works.

It is not a modelling tutorial and it does not replace MathWorks' own model-building tooling. It
governs the *process around* an edit — what to check before, what to keep intact during, and what
to prove after.

## Why

Agents are good at making a Simulink edit and bad at the things that surround it: they delete a
constant from one chart and leave three other producers alive, they invent a second mechanism for
a problem the repo already solved, they hand back a diagram no human can review, and they report
success from a simulation that agreed with its own wrong assumption.

These seven rules were written down after each of those failures cost real debugging time on a
production vehicle-control model. Encoding them stopped them recurring.

### The seven rules, in one line each

1. **Analyse every dependency first** — every producer, consumer, router and namer, on both sides of the codegen boundary.
2. **Reuse before you build** — search for the existing component first.
3. **Follow the mechanism that already exists** — never introduce a second way to do a solved problem.
4. **Geometry is part of the deliverable** — an unreadable chart is an unreviewable one; if it cannot be done cleanly in place, stop and say so *before* editing.
5. **Verify every time** — layout, scenarios, model check, codegen, target compile. Every edit, not every feature.
6. **Build and run it yourself** — then confirm the artefact moved and the target restarted.
7. **Put the responsibility in the right layer** — decide from the knowledge the code needs, not from where the symptom appeared.

## Prerequisites

**To read and apply the rules:** nothing. They are prose, and a human or an agent can follow them
with no setup.

**To let an agent actually perform and verify the edits**, it needs to be connected to MATLAB.
MathWorks ships the official way to do that:

| Toolkit | What it gives you |
|---|---|
| [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit) | the one that matters here — model tooling (`model_edit`, `model_check`, `model_read`) plus MathWorks' own Simulink and Model-Based Design expertise |
| [MATLAB Agentic Toolkit](https://github.com/matlab/matlab-agentic-toolkit) | the MATLAB side, and it installs the [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server) for you |

Both can be installed together with MathWorks' Agentic Toolkit Installer. Agents configured
automatically include **Claude Code, GitHub Copilot, OpenAI Codex, Gemini CLI and Amp**; anything
else that speaks MCP can be pointed at the server by hand.

Also needed: **MATLAB R2021a or later** with Simulink and Stateflow, and Embedded Coder if you are
generating C.

> **How this fits.** The MathWorks toolkits give the agent the *tools and the MATLAB knowledge*.
> These rules govern the *process around an edit* — what to check before, what to keep intact
> during, what to prove after. They are complementary, and this repo does not duplicate or replace
> anything the toolkits provide.

## Install

Clone it once:

```bash
git clone https://github.com/Ahrazshamim/model-based-design-discipline.git
```

Then wire it into whatever you use. Every route below points the agent at the same two files —
`AGENTS.md` for the short contract, `SKILL.md` for the full reasoning.

<details>
<summary><b>Any agent, no setup</b> — paste or attach</summary>

Attach `AGENTS.md` to the conversation, or paste it, before asking for a model change. That alone
gets most of the value. Point the agent at `references/` when it starts a chart edit.
</details>

<details>
<summary><b>Claude Code</b> — as a skill</summary>

```bash
# personal, all projects
cp -r model-based-design-discipline ~/.claude/skills/

# or project-local, checked in with the repo
cp -r model-based-design-discipline .claude/skills/
```

Picked up on the next session; activates when a request involves editing a chart or model, adding
something that crosses the codegen boundary, or verifying a model change.
</details>

<details>
<summary><b>Cursor / Windsurf / Cline / Roo</b> — as a rule</summary>

Copy the folder into your model repo (e.g. `docs/mbd-discipline/`), then add a rule pointing at it:

```md
<!-- .cursor/rules/mbd-discipline.mdc  — or .windsurfrules, .clinerules -->
When editing any .slx, Stateflow chart, data dictionary, or generated C,
follow docs/mbd-discipline/AGENTS.md. Read docs/mbd-discipline/SKILL.md and
references/stateflow-traps.md before the first chart edit in a session.
```
</details>

<details>
<summary><b>GitHub Copilot</b> — as repository instructions</summary>

Copy the folder into your model repo, then append to `.github/copilot-instructions.md`:

```md
When editing Simulink/Stateflow models or the C generated from them, follow
docs/mbd-discipline/AGENTS.md.
```
</details>

<details>
<summary><b>Agents that read <code>AGENTS.md</code></b></summary>

Copy `AGENTS.md` to your model repo root, or reference it from the one you already have. The
relative links resolve if you copy the whole folder.
</details>

<details>
<summary><b>ChatGPT / Gemini / custom assistants</b></summary>

Upload `AGENTS.md` and `references/stateflow-traps.md` as knowledge files, or paste `AGENTS.md`
into the system prompt. The rules are prose — nothing needs to execute for them to apply.
</details>

## What it contains

| File | Contents |
|---|---|
| `AGENTS.md` | the short contract: the gate, the seven rules, the hard constraints |
| `SKILL.md` | the seven rules in full, each with the defect class it prevents, and the gate to run before any edit |
| `references/dependency-checklist.md` | the six questions to answer before an edit; the hand-synced contract table; the port-reattach trap; why bit-index conventions must be read, never inferred |
| `references/stateflow-traps.md` | eleven Stateflow traps — catch-all guards, junction-ladder ordering, silent re-parenting, junctions costing no time step, action-language limits — each with symptom, cause and fix |
| `references/allocation.md` | the model-vs-hand-written-C decision rule, and the two constraints that force the split |
| `references/verification-loop.md` | how to build a scratch harness that never touches the production model, what to assert, and what a harness cannot prove |
| `scripts/check_chart_layout.m` | a runnable MATLAB check for diagram tidiness: overlapping states, overlapping labels, children outside their parent, and chart-owned arcs. Must report `0`. |

## The layout check

The one executable part. Plain MATLAB, no toolbox beyond Simulink/Stateflow:

```matlab
check_chart_layout('my_model')   % must print 0
```

It discovers the charts in the model you pass, so it needs no adaptation.

## Adapting it to your project

The rules are generic; three things are worth making specific in a fork:

- **the verification commands** in Rule 5 — replace the generic loop with your actual script names
- **the hand-synced contract table** in `references/dependency-checklist.md` — list *your*
  boundary contracts and, honestly, what enforces each one
- **the layer table** in Rule 7 — rename the layers to whatever your architecture calls them

## Contributing

Traps and failure modes from real projects are the most useful thing you can add. A good addition
names the **symptom**, the **cause** and the **fix**, and comes from something that actually cost
you time — the value here is that every rule was paid for.

## License

MIT. See `LICENSE`.
