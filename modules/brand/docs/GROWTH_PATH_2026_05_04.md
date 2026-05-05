# Growth Path: Brand Module

**Date:** 2026-05-04
**Current state:** A full-stack within-category brand health analytics module (13 analytical elements, 51 R source files, HTML report with 14+ panel types, 1651 passing tests) built on the Ehrenberg-Bass / Romaniuk CBM framework.
**Stack:** R, testthat, openxlsx, data.table, Shiny (via `launch_turas.R`), HTML/JS/CSS report output

---

## Architecture readiness

**What the current architecture supports without significant rework:**

- **Wave 2+ tracker integration:** The role-registry (`00_role_map.R`) and slot-indexed data access (`00_data_access.R`) are wave-agnostic. `run_brand()` accepts a single-wave data frame; feeding it wave-delta inputs from the tracker module is a thin wiring job.
- **New analytical elements:** The module-loader whitelist pattern and element toggle system (`element_*` in `01_config.R`) mean a new element (e.g. competitive pricing, salience) is just: new R files + whitelist entry + config key + panel renderer. No architectural change.
- **Multi-client / multi-study parallelism:** `run_brand()` is stateless — no global mutable state. Multiple studies can run in the same R session sequentially.
- **AI callouts:** The `turas_callout()` hook is already plumbed through the panel renderers. Adding callout logic to any panel is a drop-in; the infrastructure exists.

**What would require significant rework:**

- **True wave-to-wave comparison within the report:** The current HTML panels show single-wave data. Adding time-series sparklines or delta chips per brand/metric would require a new multi-wave data contract throughout the panel data builders (`02a_*`, `03c_*`, etc.) — moderate effort per panel, high effort overall.
- **Real-time/streaming data:** The pipeline is batch: load → validate → compute → render. Supporting live dashboards would require a different execution model.
- **Sub-group analysis beyond Audience Lens:** The Audience Lens recomputes 14 KPIs per audience subset, but it's a flat scorecard. A full cross-tab-style exploration across arbitrary breakdowns would need a different data model (closer to the tabs module).

---

## Natural next steps

Ordered by impact and feasibility from Duncan's position as solo technical founder.

### 1. User guide — document four missing subtabs (I3 from review)

**What:** Write Branded Reach, Demographics, Ad Hoc, and Audience Lens sections in `BRAND_REPORT_USER_GUIDE.md` following the existing Subtab pattern.
**Why now:** The module is production-ready; the gap is purely in client-facing documentation. First real-client use will expose this.
**Effort:** Small (1–2 hours writing).
**Dependencies:** None.
**Risk:** None.

---

### 2. Wave delta chips in the Summary panel

**What:** The Summary panel (`14_summary_panel.R`) already shows headline metrics per category. Add wave-on-wave delta indicators (+2.1pp ▲) to the headline strip, pulling from the tracker module when wave data is available.
**Why now:** This is the highest-value visible upgrade for tracking studies — clients see change at a glance without navigating to the tracker.
**Effort:** Medium. The tracker module already computes deltas; the work is (a) wiring tracker output into the brand run pipeline and (b) adding delta rendering to the summary panel HTML.
**Dependencies:** The brand run must have access to a prior-wave result, which means either a two-pass run or loading cached prior-wave output.
**Risk:** The summary panel is brand-new (added in the last round of work). Delta chips will interact with the existing chip layout — test carefully in browser.

---

### 3. Mental Advantage — bootstrap confidence intervals

**What:** The MA advantage matrix currently reports point estimates only. Add bias-corrected bootstrap CIs (BCa) for the advantage score so practitioners can distinguish real CEP strengths from noise.
**Why now:** Romaniuk's book explicitly recommends CIs for the advantage quadrant. This is the most obvious statistical upgrade and has already been flagged in the MA spec as a stretch goal.
**Effort:** Medium. The `.ma_count_matrix` infrastructure exists. The BCa bootstrap would be a new function in `02b_mental_advantage.R`, with CIs added to the quadrant data contract and rendered as whiskers in the JS chart.
**Dependencies:** None. The analytical foundation is already there.
**Risk:** Bootstrap CIs require ~1000 resamples; on large studies (n=500+) this adds computation time. Implement with a configurable `ma_bootstrap_reps` setting and a sensible default (500).

---

### 4. Lintr in renv

**What:** Add `lintr` to `renv.lock` and add a lint check to the test workflow (or CI gate).
**Why now:** The review could not run a lint gate — a routine quality check was unavailable. Lintr catches style issues, unused variables, and suspicious constructs before code review.
**Effort:** Small. `renv::install("lintr")` + `renv::snapshot()` + one-line lint call in a CI script or pre-commit hook.
**Dependencies:** None.
**Risk:** First run will likely surface formatting warnings (object naming conventions). Address as a cleanup pass, not a blocker.

---

### 5. SIZE-EXCEPTION comments on four large functions

**What:** Add `# SIZE-EXCEPTION: <reason>` above `run_repertoire()`, `load_brand_config()`, `.run_dba_core()`, `run_cat_buying_frequency()`.
**Why now:** Low effort, keeps the codebase self-documenting for the next reader.
**Effort:** Trivial (4 one-liners).
**Dependencies:** None.
**Risk:** None.

---

## Known limitations

| Limitation | When it matters | Mitigation |
|------------|-----------------|------------|
| Single-wave per run | Tracker integration is manual; no automatic delta | Tracker module provides wave-delta data; wiring is the next step |
| HTML report requires browser to render JS panels | PDF export is not native | TurasPins + PNG export provides static captures per panel |
| `element_audience_lens` off by default | New users won't discover it without reading the config guide | Now documented in `BRAND_CONFIG_GUIDE.md` (fixed in review) |
| Audience Lens limited to 6 audiences per category | Larger research designs with 10+ sub-groups will hit the ceiling | `audience_lens_max` is configurable; increase per project |
| Dirichlet norms require NBDdirichlet package | Optional dependency; skip path is clean but norms tab silently absent | Documented in module README; not a blocker |

---

## Technical debt

| Debt | Why accepted | When to pay down |
|------|-------------|-----------------|
| `%||%` defined in 4+ local files | Grew organically before shared-lib pattern was established | Next time any of these files are modified |
| Stale comment in `test_funnel.R` about "legacy tests" | Left over from the v2 migration transition | Low priority; remove when next touching test_funnel.R |
| `generate_config_templates.R` always loaded into memory | Convenience: templates available from Shiny GUI | Only if memory footprint becomes a reported issue |
| User guide missing 4 subtabs | Added post-initial-publication, guide not updated | Before first external client use — now I3 in the review |

---

## External dependencies to watch

| Dependency | Concern |
|------------|---------|
| `NBDdirichlet` | Small academic package; not on CRAN. Pinned via renv. Monitor for removal. |
| `ChoiceModelR` | Used by MaxDiff/Conjoint, not Brand, but same renv. CRAN-available. |
| R ≥ 4.0 | Module uses `\()` lambda syntax in a few files. Ensure client R version. |

---

## Summary

The brand module is in excellent shape: deep test coverage, clean analytical architecture, TRS-compliant error handling throughout, and 13 analytical elements fully shipped. The clearest path forward is completing the documentation layer (user guide subtabs, SIZE-EXCEPTION comments, lintr gate) — the code quality is there, the paper trail just needs to catch up. The highest-value analytical upgrade is wave delta chips in the Summary panel, which would make the module tracker-aware at a glance without requiring changes to the core analytical engines.
