# Model-based design change discipline

Rules for any AI agent that edits Simulink/Stateflow models which generate embedded C.
Vendor-neutral: nothing here depends on a particular assistant, IDE or MCP server.

**Read `SKILL.md` in full, and `references/stateflow-traps.md`, before your first chart edit in a
session.** This file is the short form.

## The gate — run before any model edit

1. **Analyse first.** Map every producer, consumer, router and namer of the thing you are
   changing, on *both* sides of the codegen boundary.
2. **Reuse?** If a component already does this, use it. Stop.
3. **Prior art?** If this *kind* of thing is already solved somewhere in the repo, copy that
   mechanism. Never introduce a second way.
4. **Which layer owns it?** Decide from the knowledge the code needs, not from where the symptom
   appeared.
5. **Geometry.** Can it be drawn cleanly in place? If not — **STOP**, name the obstacle before
   touching anything, and only work on a copy with explicit approval.
6. **Verify.** Layout check → scenario run → model check → codegen → compile with the real target
   toolchain. Every edit, not every feature.
7. **Build and run it yourself**, then confirm the artefact moved and the target restarted.

Any branch that says STOP means stop and say so. Do not proceed and explain afterwards.

## The seven rules

1. **Analyse every dependency first** — every producer, consumer, router and namer, on both sides
   of the codegen boundary.
2. **Reuse before you build** — search for the existing component first.
3. **Follow the mechanism that already exists** — never introduce a second way to do a solved
   problem.
4. **Geometry is part of the deliverable** — an unreadable chart is an unreviewable one.
5. **Verify every time** — layout, scenarios, model check, codegen, target compile.
6. **Build and run it yourself** — then confirm the artefact moved and the target restarted.
7. **Put the responsibility in the right layer** — decide from the knowledge the code needs.

## Hard constraints

- **Never run auto-layout on a hand-organised model.** Use explicit position vectors.
- **`scripts/check_chart_layout.m` must report `0`** after every chart edit.
- **A green simulation is not proof.** A harness cannot catch an assumption it shares with the
  model, and it cannot prove anything it stubbed.
- **Maximum 3 build-fix attempts**, then stop and flag rather than grinding.

## Reference files

| File | Use |
|---|---|
| `SKILL.md` | the seven rules in full, each with the defect class it prevents |
| `references/dependency-checklist.md` | the six pre-edit questions; hand-synced contracts; the port-reattach trap |
| `references/stateflow-traps.md` | eleven Stateflow traps, each with symptom → cause → fix |
| `references/allocation.md` | model vs hand-written C, and the constraints that force the split |
| `references/verification-loop.md` | scratch-harness construction, what to assert, what it cannot prove |
| `scripts/check_chart_layout.m` | the Rule 4 machine check |
