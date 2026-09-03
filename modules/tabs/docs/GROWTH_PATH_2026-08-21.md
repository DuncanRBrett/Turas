# Growth Path: Turas Tabs Module

**Date:** 2026-08-21
**Current state:** Production crosstab engine + interactive HTML report with integrated tracking,
qual layer, composites, callout/authored-text system; one real-project outing (CCPB) survived
cleanly; 5041 R + ~900 node test assertions green (one stale fixture red).
**Stack:** R (script-architecture engine, openxlsx/readxl/jsonlite), vanilla JS renderer, testthat + node vm suites.
Companion document: `PRODUCTION_REVIEW_2026-08-21.md` (findings referenced as C-/I-/M-/O-).

## Architecture readiness

What the current architecture supports without significant rework:
- **New question types**. The orchestrator dispatch + processor pattern is clean; Allocation
  proved the path end to end. Add the closed-vocabulary check (I-20) first so new types can't be
  silently mis-dispatched.
- **New report tabs / views**. The numbered-JS-module + data-island pattern absorbs new views
  cheaply (27x family shows the groove); the authored-text system means new UI copy is governed
  from day one.
- **More tracking wave sources**. The island/bridge separation (microdata, segment sidecars,
  aggregate bridge) is the right shape; it needs the eff_n/SD carriage fix (I-9/M-1) before more
  weighted trackers lean on it.
- **Per-study text/branding**. Override system delivered and tested; extending to more keys is
  incremental.

What would require significant rework:
- **Making the engine callable rather than sourced** (O-6). run_crosstabs.R as a script with
  global-env protocol is the root of five findings (I-1, I-2, M-10, M-9-GUI-globals, the text-grep
  test harness). Converting the body to a function is a focused 1-2 session refactor with the E2E
  suite as the net. The single highest-leverage structural change available.
- **Ending R↔JS statistical duplication**, not realistically removable; the mitigation is the
  parity fixture, which must be regenerated on ANY formula change on either side. Treat the
  fixture as a first-class artefact.
- **True multi-user / concurrent operation**. LocalStorage stores, whole-file callout saves
  (M-24), and per-folder checkpoints all assume one operator; fine for the business model, not
  worth changing.

## Natural next steps (ordered)

### 1. The pre-next-project hardening batch
**What:** C-1 (checkpoint stamping), I-6 (green the suite), and the silent-degradation cluster
(I-7, I-8, I-10, I-11, I-12, I-13, I-14, I-20, each a boxed-warning or refusal, none touches
maths).
**Why now:** every one is a first-project trap for VAS 2026 / ASSA / SACS; CCPB never hit them
because its inputs were clean.
**Effort:** Small-Medium. Mostly one-site fixes with a test each; the batch is one focused session.
**Risk:** low; all additive loudness.

### 2. Allocation + ranking statistical completion
**What:** I-5 (v2 sig letters), I-15/I-16 (sum validation + blank policy), I-17/I-18 (sentinel
exclusion; wire or disclaim ranking significance).
**Why now:** VAS 2026 wallet questions are allocations; the first ranking study after that inherits
the rest.
**Effort:** Medium. The blank policy and partial-ranking base need YOUR decision before code.
**Dependencies:** check one real VAS record for the blank-export convention first.
**Risk:** changes published numbers for affected types. Regenerate parity fixtures and eyeball
against a known study.

### 3. Weighted tracking sidecar rebuild (extends the open CCPB item)
**What:** carry eff_n + sample-form SD into segment sidecars (I-9/M-1); same rebuild closes the
CCPB 1dp item and documents the aggregate ≥1dp rule (M-23).
**Effort:** Medium; the rebuild tooling already exists and is tested.
**Risk:** wave-on-wave calls near thresholds may flip. That is the point; diff old vs new calls
and note flips in the deliverable.

### 4. Dead-code and dead-setting purge
**What:** I-24 (guard/validation dead layers + their tests), I-25 (inert settings), M-18 (dead
writers/duplicates), weighting preflight wiring (I-22/I-23).
**Why now:** for a solo-maintained repo, code that testifies falsely to being alive is the main
long-term hazard; this purge shrinks the surface a future session must read.
**Effort:** Medium (mostly deletion + a few wirings); zero behaviour change intended. The suites
are the net.

### 5. Documentation reset
**What:** I-27. Rewrite/trim 05, test-running section in README, dependency truth, docs/INDEX.md
with status buckets, plan-doc status corrections.
**Why now:** post-Jess, the repo IS the institutional memory; 11_DATA_CENTRIC_REPORT_V2.md proves
the standard is reachable.
**Effort:** Small-Medium, no code risk.

### 6. (When convenient) engine-as-function refactor
O-6 above. Do it after 1-4 so the suites are trustworthy first.

## Known limitations (accepted, documented)

| Limitation | When it matters | Mitigation |
|---|---|---|
| Microdata island carries raw numeric answers (C3 decision) | Confidential studies | microdata=N ship; boxed warning already fires (O-5); optional binning config |
| R↔JS twin stats engines | Any formula change | Parity fixture regeneration discipline |
| Render-time k-gate is a viewing convenience | Hostile recipient of an HTML file | Same as above. Microdata=N is the confidential ship |
| Wave tests use no cross-pair multiplicity control | Many-wave heatmaps | Deliberate tracker convention; document (O-2) |
| Overlapping BoxCategory columns tested as independent | Configs with nested nets | O-3; consider suppressing intersecting pairs |
| Design/cell weight paths never run on a real project | First design-weighted study | Supervised first outing after I-22/I-23 land |

## Technical debt register

| Debt | Why accepted | When to pay |
|---|---|---|
| Script-architecture engine + global-env protocol | Historical; works under launch_turas | Step 6 |
| 8 R files >1000 lines, 27q at 2648 | Coherent, comment-dense, SIZE-EXCEPTION discipline | On next major touch of each |
| Loader whitelists that skip missing files silently | Predates the trap being understood | Fold into step 4. Make every loader refuse (third instance of this class: brand, weighting, tabs) |
| Five parallel config registries per new setting | Contract test gates most pairs | Add the whitelist⊆consumed direction (I-25), then live with it |
| Text-grep test harness for run_crosstabs functions | Engine isn't sourceable in pieces | Dies naturally with step 6 |

## External dependencies to watch

| Dependency | Concern |
|---|---|
| openxlsx | The dangling-drawings class is patched by the reconciling saver; keep all saves routed through it (regression test M-24 suggests) |
| readxl | guess_max/type-guessing on late-route columns (adjacent observation in review); pin `col_types="text"` where alignment matters |
| jsonlite | Hard gate for the v2 report; document as required (I-27) |
| survey (weighting module) | calibrate error surfaces leak through as MODEL_* refusals (M-15); wrap messages when touched |

## Summary

The module is in the strongest shape it has ever been: the statistical core, the parity discipline,
the writer safety, and the callout system all pass adversarial review, and CCPB proved the happy
path. The clearest path forward is loudness, not features. A one-session hardening batch (step 1)
removes the CRITICAL and most first-project traps, and the allocation/ranking completion (step 2)
is the only work where statistics decisions are still open. The biggest structural constraint is
the script-architecture engine; convert it to a function when the schedule allows, not before the
hardening lands.
