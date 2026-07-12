# OPUS-0 Socket Consolidation — Handover for Opus Implementation Session

**Date:** 2026-07-12. Written by the Fable programme session for the Opus 4.8 session that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/V2_LIFT_PROGRAM.md` §3 (the OPUS-0 row + FAB-0 which is already DONE) and §1 (standing decisions D1-D6); (3) `modules/tabs/docs/V2_MIGRATION_PLAN.md` §5 (cross-cutting checklist) + §6 (Phase-0). Load the `fable-method` skill. Project CLAUDE.md rules apply (TRS refusals, console-visible errors, tests before "done").
**What this is:** the shared-plumbing consolidation that must land before the five gated v2 sessions. It is *socket work only* — no analytics, no new reports, no per-module v2 views. Every migrating module inherits correct behaviour from what you build here instead of re-duplicating it.
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the OPUS-0 row (§3) and append to §5 when you finish.

---

## 0. Decisions — locked defaults (Duncan may veto; session proceeds on these if no ruling)

Fable's recommendation stated for each; the session proceeds on the recommendation if Duncan gives no ruling. Duncan's vetoing message wins.

1. **`</script>` island hardening — pull into OPUS-0, or leave with catdriver B5?** The catdriver handover (§B5) scopes hardening `modules/shared/js/turas_pins.js` (`_save`/`_load`) and says split it to `fix/turas-pins-script-hardening` if the blast radius is too big for a per-module session. It touches **every** TurasPins module. **Recommendation: pull it into OPUS-0.** OPUS-0 already owns `modules/shared/js/turas_pins*` and already runs cross-module suites, so it is the natural home; leaving a shared-JS edit inside a single-module Session B is exactly the split catdriver flagged. If pulled in, catdriver B5 is struck (note it in that handover's row). The segment §5 log currently says "TurasPins fix stays with catdriver B5" — this doc supersedes that if Duncan agrees. Work package W3 below assumes pull-in.

2. **The fourth (divergent) Kish copy in maxdiff.** The OPUS-0 row named tabs (canonical), confidence (duplicate), tracker (dependency). Verified this session: a **fourth** copy exists at `modules/maxdiff/R/utils.R:585`, and it is **behaviourally different** — no rounding (returns a float, not an integer), no scale-safe normalisation, no all-weights-equal shortcut. **Recommendation: re-point it to the shared helper in OPUS-0 (W1) too**, so maxdiff's own sig/deff can't diverge — but this *changes maxdiff numbers* (float→rounded-int), so it must ship with a maxdiff-suite golden test and be called out for Duncan's eyeball. Alternative: leave it to maxdiff Session A/C and only note it. Default: re-point it, gated behind a passing maxdiff suite.

3. **Disclosure/min-base gate — helper shape.** There is no gate *function* today; `significance_min_base` (default 30) is compared inline at many sites. **Recommendation: extract a thin predicate** (`meets_min_base()`, W2) and re-point only the tabs reference-implementation callers that are trivial 1:1 swaps. Consuming analytical modules adopt it in their own Session Cs — OPUS-0 provides the socket, it does not chase every caller. If Duncan wants a richer suppress-and-flag object instead of a predicate, say so; default is the predicate.

---

## 1. Ground rules

- One branch: `feature/opus0-socket-consolidation`, off current main. **Do not merge** — Duncan merges after his eyeball and a Fable pre-merge review (required; §3 of the V2_LIFT_PROGRAM pipeline).
- Fix code + run suites only. Duncan verifies via `launch_turas()` himself — never headless-run against real project folders, never write into OneDrive.
- **Behaviour-identical is the whole point.** The Kish and gate consolidations must produce the *same numbers* before and after on a fixture. Ship each with a golden test that pins the pre-change output and passes on the re-pointed code.
- Every fix ships with a test that **fails on the old code** (a golden/regression test counts: it must fail if the helper diverges). TRS refusals only, console-visible. Log any deviation and surface it in the final summary.
- **Suites — run for EVERY module whose code you touch.** Command form (project convention, per the weighting handover): `Rscript -e 'testthat::test_dir("modules/{module}/tests/testthat", reporter = "summary")'`. Modules you *will* touch: **tabs, confidence, tracker** (Kish + gate), plus **every TurasPins module** for the island hardening — at minimum tabs, confidence, catdriver, brand, keydriver (all verified to have `tests/testthat/`). Add maxdiff if you take §0.2. Run each before your first change (record the baseline) and after every fix. **Do not quote counts you did not run.**
- Shared-code sourcing convention (match it exactly): modules resolve shared files via `file.path(dirname(<module script>), "shared", "lib", "<file>.R")` with a `getwd()/modules/shared/lib` fallback and `TURAS_ROOT`/`TURAS_HOME` env resolution (see `modules/tracker/lib/formatting_utils.R:17-28`, `modules/tabs/lib/weighting.R:39-54` `source_if_exists`, `modules/shared/lib/turas_pins_js.R:36+`). A new `modules/shared/lib/` file must be sourceable the same way.

## 2. Work packages (in this order)

### W1 — ONE shared Kish n_eff helper

**Proposed file:** `modules/shared/lib/effective_n.R`.
**Signature (must reproduce the canonical body verbatim):** `calculate_effective_n <- function(weights)` — copy the canonical implementation at `modules/tabs/lib/weighting.R:366-402` exactly: drop NA/±Inf/≤0 weights; return `0L` on empty; return `as.integer(length(weights))` when all weights == 1; else scale by `mean(weights)` for numeric stability and return `as.integer(round((sum(w)^2)/sum(w^2)))`. Also move `calculate_deff()` here if you re-point maxdiff (its deff calls the n_eff helper).

**Re-point (behaviour-identical):**
- `modules/tabs/lib/weighting.R:366-402` — becomes the shared source's home; keep tabs sourcing it so all tabs callers (`question_orchestrator.R:232`, `excel_writer.R:1105`, `cell_calculator.R:555`, `ranking/ranking_metrics.R:115,238`, `crosstabs/data_setup.R:182`, and the internal callers at `weighting.R:532,559,591,1060-1061,1462`) resolve the *same* function. The confidence copy is **verbatim identical** to this, so no number moves.
- `modules/confidence/R/03_study_level.R:86-122` — delete the duplicate body, source the shared helper. Confidence callers (`05_means.R`, `question_processor.R`, `04_proportions.R`, `00_main.R`) are unaffected in value.
- `modules/tracker/lib/trend_significance.R` — **NOTE: tracker does not compute n_eff.** It *consumes* a precomputed `eff_n` field (falls back to `n_unweighted`; see lines 64-66, 136-137, 228-229, 322-324). There is no duplicate to re-point here — the "dependency" is downstream consumption. Leave tracker's logic; run its suite as a platform-wide regression only.
- `modules/maxdiff/R/utils.R:585` — **only if §0.2 is adopted.** Divergent (float, no scale-safety). Re-point to the shared helper; ship a maxdiff golden test showing the new rounded-int values; call it out for Duncan.

**Acceptance:** shared helper exists and is sourced by tabs + confidence; a golden test in tabs and in confidence asserts identical n_eff on a fixed weight vector (e.g. `c(1,1,3)` → `n_eff = 25/11 → round = 2`; a mixed-weight vector) before and after; confidence's old inline copy is gone; tabs, confidence, tracker suites green.

### W2 — ONE shared disclosure / min-base gate (socket only)

Today `significance_min_base` (default 30) is compared inline: `numeric_processor.R:317`, `data_layer_writer.R:144` (`low_base_threshold`), `composite_processor.R:749-767`, `qual_quant_layer.R:159-164`, `standard_processor.R:252,340,595,858,1054`, and the weighting sig tests refuse when `n1 < min_base || n2 < min_base` (`weighting.R:865,1017`, default `min_base = 30`). The V2 socket must gate at **analysis, render, and export** (V2_MIGRATION_PLAN §5) — the *same predicate* at three points.

**Proposed file:** `modules/shared/lib/disclosure_gate.R`.
**Signature (grounded in the inline pattern read above):** `meets_min_base <- function(base, min_base = 30L)` returning a logical (vectorised over `base`); `TRUE` = base meets threshold (test-eligible / disclosable). This is exactly the `base >= min_base` predicate every site already computes; no new semantics. (If Duncan picks the richer object in §0.3, return `list(eligible=, base=, min_base=)` instead.)

**Scope discipline:** re-point only the **tabs reference-implementation** callers where the swap is a trivial 1:1 (`n < min_base` → `!meets_min_base(n, min_base)`). Do **not** rewrite the analytical modules' gating — they adopt the helper in their own Session Cs. OPUS-0 provides the socket + migrates the reference caller so there is a working example to copy.

**Acceptance:** shared predicate exists and is sourced by tabs; at least one real tabs gate site (recommend `data_layer_writer.R:144` or a `standard_processor.R` site) uses it with identical output; a unit test pins the boundary (`base = min_base` → TRUE, `base = min_base-1` → FALSE, vectorised, NA base → FALSE); tabs suite green.

### W3 — TurasPins island hardening + per-module `*_pins.js` inventory

**Reality check (verified this session):** the pin *consolidation* the 2026-07-05 migration plan envisioned is **already done**. Every module loads the shared library via `turas_pins_js()` (`modules/shared/lib/turas_pins_js.R`), and each per-module `*_pins.js` is a **thin content-capture wrapper** delegating to `TurasPins` (headers literally say "Thin Wrapper / Delegates to shared library" — e.g. `md_pins.js:1-14`, `cd_pins.js:1-11`). There is **no duplicate pin engine to retire.** The genuine shared-plumbing task that remains is the island hardening.

**W3a — `</script>` hardening (the real deliverable; §0.1 pull-in).** In `modules/shared/js/turas_pins.js`: `_save` (line ~257) writes `store.textContent = JSON.stringify(_pins)` and `_load` (line ~263) does `JSON.parse(store.textContent)`. When a saved report is serialised via `outerHTML`, a literal `</script` inside pinned insight text breaks out of the `<script>` island. Escape `</` on write and unescape on read, mirroring the R-side semantics at `modules/tabs/lib/build_report_v2.R:88-89` (`gsub("</", "<\\/", txt, fixed = TRUE)`). Grep for any other consumer of the island format before changing it.
**Tests:** extend the shared-pins / tabs report tests so a `</script>` payload in an insight round-trips through save→reload intact. Run tabs + confidence + catdriver + brand + keydriver suites (cross-module blast radius). If any breaks, this is the split catdriver warned about — do not paper over it.

**W3b — inventory, do not mass-retire.** Enumerate the wrappers (found this session): retire-vs-keep verdict below.

| `*_pins.js` file | Verdict |
|---|---|
| `modules/tabs/lib/html_report/js/tabs_pins.js` | **KEEP** — reference v2 wrapper. |
| `modules/tracker/lib/html_report/js/tk_pins.js` | **KEEP** — tracker is already v2. |
| `modules/report_hub/js/hub_pins.js` | **KEEP** — hub-level, out of programme scope. |
| `modules/{brand,catdriver,confidence,conjoint,keydriver,maxdiff,pricing,segment,weighting}/lib/html_report/js/*_pins.js` | **KEEP for now** — thin, already on shared lib. Each is replaced/retired by that module's own Session C (v2 view) or B report work, against the v2 DOM. **Not OPUS-0 work.** |
| `modules/maxdiff/lib/html_simulator/js/{sim,simulator}_pins.js` | **KEEP** — simulator is standalone (D2); out of socket scope. |

**Acceptance:** shared island hardened + round-trip test green across the cross-module suites; the inventory table above recorded in your summary; **no per-module wrapper deleted by OPUS-0.**

## 3. What NOT to do

- **No analytics, no new reports, no v2 views, no new `row.kind` arms, no exporters.** That is all per-module Session-C work.
- **Do not change any n_eff number** except the maxdiff float→int under §0.2 (and only with a golden test + call-out). Kish and gate consolidations are refactors that must be numerically inert on tabs/confidence.
- Do not touch tracker's `trend_significance.R` logic — it has no duplicate to consolidate.
- Do not mass-delete `*_pins.js` wrappers — pin consolidation is already complete; deleting a wrapper breaks that module's live pinning.
- Do not rename config fields, add dual-alpha/Bonferroni plumbing, or verify the audit stats bugs — FAB-0 already closed that (V2_LIFT_PROGRAM §3), and field renames belong to each module's migration.
- Do not add dependencies. Do not weaken any existing refusal to make a test pass.

---

## Gating — which sessions wait on OPUS-0

**GATED (the five Session Cs, the v2-report/plumbing sessions):**
`feature/maxdiff-v2-report` · `feature/conjoint-v2-report` · `feature/keydriver-v2-report` · `feature/catdriver-v2-report` · `feature/brand-v2-plumbing` (brand C adopts Kish + shared gate + retires `brand_pins.js` onto its v2 DOM).

**NOT gated (proceed independently of OPUS-0):** every Session A and Session B of every module; **segment Session C** (`feature/segment-tabs-export` — tabs exporter, explicitly not gated); **pricing entirely** (A + B, no Session C); **weighting entirely** (single session).

## Definition of done

- [ ] `modules/shared/lib/effective_n.R` exists; tabs + confidence source it; confidence's inline copy deleted; golden n_eff tests pass in tabs and confidence.
- [ ] `modules/shared/lib/disclosure_gate.R` exists; ≥1 tabs reference caller re-pointed; boundary unit test passes.
- [ ] `modules/shared/js/turas_pins.js` island `</script>`-hardened; save→reload round-trip test passes.
- [ ] Suites green (run and quote real results): **tabs, confidence, tracker** (Kish/gate) + **catdriver, brand, keydriver** (pins blast radius). Maxdiff too if §0.2 taken.
- [ ] `*_pins.js` inventory recorded; no wrapper deleted.
- [ ] V2_LIFT_PROGRAM §3 OPUS-0 row + §5 log updated.
- [ ] **Fable pre-merge review** requested (pipeline step 4). Duncan merges — not you.

---

## Open items (could NOT be fully verified this session — flag, don't invent)

- **Exact `_save`/`_load` line numbers in `turas_pins.js`** are approximate (`~257`/`~263` from grep) — confirm by reading before editing.
- **Full retire-vs-keep certainty per wrapper** rests on the "thin wrapper" headers + memory that pin consolidation is complete; two wrappers (`md_pins.js`, `cd_pins.js`) were read and confirmed thin, the rest inferred from consistent headers/line counts. Read a wrapper before touching it.
- **The disclosure gate at render/export** (V2_MIGRATION_PLAN §5 names `cell_calculator.R` for analysis and `excel_writer.R` for export) — the render-side site was not pinpointed to a line this session; locate it before claiming three-point coverage.
