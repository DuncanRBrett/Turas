# Classic → V2 Migration Plan

**Status:** v0.1 — Discover complete, three decisions open (see §1). Not yet ready to execute.
**Date:** 2026-07-05
**Scope:** Bringing the analytical modules (segment, keydriver, pricing, conjoint, maxdiff) into the V2 interactive report (currently Tabs + Tracker).
**How this doc was built:** grounded blindspot pass — three parallel code readers mapped (a) what each module produces, (b) how the V2 report socket works and how Tracker was integrated, (c) where the cross-cutting plumbing lives and diverges. Findings below are traced to files, not reasoned from first principles.

> Leads with the decisions most likely to change (per "A Field Guide to Fable" — put the forks first, bury the mechanical parts). Execution model: this doc is the Fable/Opus **Freeze** artifact — an Opus session should be able to migrate one module by reading this and nothing else.

---

## 1. Open decisions (Duncan) — these set the spine

1. **Parity or curated?** For each module, is the bar *everything the classic deliverable produced*, or a *deliberate best-of* reframed for the interactive report? The capability drop-list (§5) only bites under parity.
   - *Recommendation:* curated. Migrate the decision-grade content; leave exhaustive diagnostic sheets in the classic Excel deliverable, linked not embedded.

2. **The simulators — in, linked, or out?** Pricing, conjoint and maxdiff each ship a core interactive simulator (§3). Embed live in V2 / keep standalone and link / drop.
   - *Recommendation:* standalone. They are tools, not report content; the microdata weight ceiling (§6) makes embedding costly; they already work as self-contained HTML.

3. **Order.** Proposed: segment → key driver → (pricing / conjoint / maxdiff static parts). Anything pulling rank (a live project needing one sooner)?

---

## 2. Mental model — two corrections up front

- **The unit of migration is the *part*, not the module.** segment and keydriver are report content. pricing / conjoint / maxdiff each split into a static report part **and** a standalone simulator. Plan per part.
- **"Migrate a module" = make it emit V2 data islands, NOT port its HTML report.** The classic per-module HTML reports are throwaway. The input the socket wants is the module's *results*, serialised into the island schema (§4). Porting the old HTML is the wrong layer and will waste weeks.

---

## 3. Per-module landing zones

| Module | Character | Static report part (→ V2) | Interactive tool (→ standalone?) |
|---|---|---|---|
| **segment** | report content | segment profiles, validation metrics, exec summary, assignment rows | assignment/scoring = a bridge feed to other modules, not a UI |
| **keydriver** | report content | importance rankings (Shapley/rel-weight/beta), VIF, model fit, IPA quadrant | — |
| **pricing** | mixed | VW/GG price points, demand & revenue curves, elasticity, WTP | **Price Simulator** (`modules/pricing/lib/simulator/`) |
| **conjoint** | mixed | part-worth utilities, importance, model fit, HB diagnostics | **Market Simulator** (`modules/conjoint/lib/html_simulator/`) |
| **maxdiff** | mixed | item scores, best-worst, TURF, HB diagnostics | **Preference Simulator** (`modules/maxdiff/lib/html_simulator/`) |

Closest to the proven Tracker template: **segment** (per-segment summary rows mirror the tracking island). **keydriver** reuses the existing `index_scores` row pattern.

---

## 4. The socket — what a module must produce

The report bundles a data contract; Tracker was integrated through exactly it.

- **Aggregate island** — `modules/tabs/lib/data_layer_writer.R` (`build_data_layer`, `build_dl_question`). Per-question rows with `pct[]` / `n[]` / `sig[]` arrays indexed by column, plus `bases[]` carrying `n` / `nWeighted` / `nEff`.
- **Microdata island** (optional, enables live filtering) — `modules/tabs/lib/microdata_writer.R`. Per-respondent answers/scores; row-index match uses the `safe_equal()` pattern — get this wrong and data silently drops.
- **Tracking island** (optional, wave history) — `modules/tabs/lib/tracking_island.R`.
- **Orchestration** — `modules/tabs/lib/run_crosstabs.R` (~L750–847) wires the islands and bundles the HTML.
- **JS render/recompute** — `assets/js/20_data.js` (`d2.validate`), `21_stats.js` (recompute engine), `22_model.js` (`forQuestion`), `25_cards.js` (card renderer), `24_shell.js` (tab router). A new module adds a `27*_*.js` view and new `row.kind` arms.

**New row kinds each module introduces:** segment breakdown rows; keydriver importance/correlation; pricing elasticity/optimal-price; conjoint utilities; maxdiff position scores. Each must be added to `classify_row_labels()` (R) **and** given a matching arm in `forQuestion()` (JS), or it won't render.

---

## 5. Cross-cutting checklist — every migration must pass this

This is where numbers silently go wrong. The plumbing is duplicated/divergent today.

- [ ] **Weighting / Kish n_eff** — use ONLY `modules/tabs/lib/weighting.R::calculate_effective_n`. Formula is currently duplicated in `modules/confidence/R/03_study_level.R` and depended-on in `modules/tracker/lib/trend_significance.R`. **Risk: HIGH.** A migrated module computing n_eff its own way = divergent bases.
- [ ] **Disclosure / min base** — classic modules have **no** min-base gate. V2 gates on analysis (`cell_calculator.R`), render, AND export (`excel_writer.R`). A migrated module must apply `significance_min_base` in all three, or low-base cells leak. **Risk: HIGH.**
- [ ] **Pins / PPTX / PNG export** — adopt shared `modules/shared/lib/turas_pins_js.R` + `modules/shared/js/turas_pins*.js`. Classic modules each ship their own `*_pins.js` bound to module-specific DOM/CSS — these break against the V2 layout. Remove them. **Risk: HIGH.**
- [ ] **Config field names** — V2 uses `significance_min_base`, `alpha`, `alpha_secondary`, `bonferroni_correction`, `sampling_method`. Classic diverges (`minimum_base` in tracker; `Confidence_Level` in confidence). Rename to V2 on migration. **Risk: MEDIUM.**
- [ ] **Significance** — dual-alpha (95% + 80%) and Bonferroni live only in Tabs. A migrated module inherits the Tabs engine; make sure it reads `project.alpha` / `alpha_secondary` / `bonferroni_correction` rather than any local single-alpha path. **Risk: MEDIUM-HIGH.**
- [x] **TRS refusals & stats pack** — already shared and consistent (`modules/shared/lib/trs_refusal.R`, `stats_pack_writer.R`). **Risk: LOW.** Just add a module code prefix.

---

## 6. Socket-hardening prerequisites (Phase 0)

Before *any* module goes in:

1. **VERIFY the audit stats bugs are actually closed.** The architecture reader surfaced, from `modules/tabs/docs/PRODUCTION_AUDIT_2026-07-02.md`, that the JS sig engine may hard-code z-values / ignore Bonferroni, weighted mean CIs may use raw base not `baseEff`, and FPC may leak past disclosure. These *may* already be fixed by the 63-finding pass — **check the JS directly** (`21_stats.js`, `22_model.js`), don't trust the doc or memory. If open, every migrated module inherits them.
2. **Consolidate the shared plumbing** (recommended): extract one Kish formula into `shared/`, one disclosure gate, retire per-module pins onto TurasPins. Do this once, up front, and every later migration inherits correct behaviour instead of re-duplicating it. This is arguably the real "first upgrade."

**File-size ceiling:** the microdata island grows with respondents × questions (~15–20 MB HTML at n=5000 × 100 questions; segment scores multiply it). The heavy modules must pre-aggregate (freeze) some output rather than ship every respondent live. Constrains how much of pricing/conjoint/maxdiff can be live-filterable.

---

## 7. Capability drop-list — do NOT lose these

If migration collapses to "port the summary tables," these fall out (regression disguised as upgrade):

individual-level HB utilities · confidence intervals · MCMC convergence diagnostics (Rhat/ESS/Geweke) · VIF · model-fit stats (McFadden R²/AIC/BIC/hit-rate) · TURF reach/frequency · design effect / weighting · probability-based assignments (GMM/latent-class membership) · respondent-quality (RLH) scoring.

Under a *curated* bar (Decision 1) some of these legitimately stay in the classic Excel deliverable — but that must be a **choice**, logged, not an accident.

---

## 8. Per-module execution checklist (once decisions locked)

For each module, in order:
- [ ] Emit results into the aggregate island schema; extend `build_dl_question()` for new row kinds.
- [ ] (If live filtering wanted) emit microdata; verify `safe_equal()` row-index mapping.
- [ ] Add `27*_*.js` view + `forQuestion()` arms; extend `d2.validate()`.
- [ ] Pass the §5 cross-cutting checklist.
- [ ] Decide freeze vs live per §6 ceiling.
- [ ] Tests: R (type mapping, serialisation) + JS (model build, recompute under a custom banner).
- [ ] Update `modules/tabs/docs/11_DATA_CENTRIC_REPORT_V2.md` with the new island schema.
- [ ] Regen via launch_turas (Duncan) + eyeball before merge.
