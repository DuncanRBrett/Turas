# Growth Path: Tracker Module

**Date:** 2026-05-24
**Current state:** Production-grade longitudinal trend engine — loads
multi-wave survey data, normalises questions across waves, calculates
rating / single-choice / NPS / composite / multi-mention trends with
wave-on-wave significance, and emits Excel + HTML reports. Powers
client-facing tracker reports (e.g. Coca-Cola Peninsula Beverages).
**Stack:** R 4.5.3 + openxlsx + Shiny GUI; ~19,700 LOC across 33 R files in
`modules/tracker/lib/` plus a 20-file testthat suite (1855 tests).

---

## Architecture readiness

The v10.1 December 2025 refactor (extracting `metric_types`,
`trend_changes`, `trend_significance`, `output_formatting`) sets up
the module well for what's next. **What the current architecture
supports without significant rework:**

- **More custom metrics on rating questions.** The
  `calculate_metrics_from_specs` dispatcher (trend_calculator.R:530)
  is a clean switchboard — a new spec keyword plus a calculator in
  `statistical_core.R` plus a label in `metric_types.R` adds a metric
  end-to-end. Examples: weighted median, IQR, gain-loss ratio.
- **Welch's t-test as a config option.** `t_test_for_means` is one
  function. Add a `var_equal` parameter, branch the SE/df formulas,
  and surface it via `get_setting(config, "t_test_variant", default = "pooled")`.
- **Multiple alpha tiers (e.g. p<0.05 + p<0.10) in the same report.**
  The dual-significance pattern shipped in tabs (per memory) can lift
  directly into `perform_significance_tests_*` — add a second alpha
  parameter, return `significant_primary` + `significant_secondary`.
- **Per-question minimum_base.** `get_setting(config, "minimum_base")`
  is read once globally. The question_map already carries per-question
  metadata; threading a `MinBase` column through and falling back to
  the global is straightforward.
- **More output formats.** The output layer is already split across
  `tracker_output.R`, `tracker_output_banners.R`,
  `tracker_output_extended.R`, `tracker_dashboard_reports.R`, plus
  `html_report/` (12 files) and `tracking_crosstab_excel.R`. Adding a
  PowerPoint or PDF writer slots in alongside.
- **Banner significance heatmaps in HTML.** Banner trends already
  exist (`banner_trends.R`); `html_report/03f_heatmap_builder.R` shows
  the heatmap pattern is in-house. Connecting the two would not need
  new infrastructure.

**What would require significant rework:**

- **Multi-period (not wave-vs-wave) comparisons** — e.g. "this wave vs
  same wave last year" or "rolling 4-wave average." The significance
  layer is hard-wired to consecutive waves (the `for (i in 2:length(wave_ids))`
  loop in every `perform_significance_tests_*`). Generalising to arbitrary
  wave pairs needs both a comparison-spec config and a refactor of
  `calculate_changes_for_metric`.
- **Mixed-effects / longitudinal modelling** (treating respondents as
  repeated measures). Tracker treats each wave as an independent sample,
  which is correct for cross-sectional trackers but wrong for panel
  studies. Adding panel support means changing wave_loader to carry a
  respondent_id linkage and rewriting the trend engine.
- **Sample-mode parallelisation beyond `future.apply`.** Comments in
  `trend_calculator.R:17-20` mention parallel = TRUE as available, but
  it's question-level parallelism. For very large studies (e.g.
  100+ questions × 12+ waves × banner cuts), a stage-level pipeline
  (extract → calculate → format → write) with `targets`-style caching
  would be more efficient.

---

## Natural next steps

Ordered by impact and feasibility for Duncan's actual workflow.

### 1. `fix/tracker-sig-tests` — close the three statistical correctness items

**What:** Address I1 (eff_n loss for non-mean metrics), I2 (no min_base
on enhanced metrics), I3 (NPS conservative SE), plus M2/M3 (regression
tests for SD-sensitivity and the sig-test wrapper family).
**Why now:** The CCS review exposed that the test surface around
significance is thinner than it looks. The bugs are low-incidence but
silent — they don't crash, they just over- or under-flag. Locking the
behaviour in tests is the right insurance before the next client.
**Effort:** Small (1-2 days). All five items are local changes in
`statistical_core.R` + `trend_significance.R` + new test file.
**Dependencies:** None.
**Risk:** Fixing I3 (NPS true variance instead of conservative) will
change p-values on existing NPS reports. Compare before/after on a
known wave-pair to confirm direction is correct, not just looser.

### 2. `docs/tracker-cleanup` — collapse the doc pack to one source of truth

**What:** Address I4 (stale architecture diagram), I5 (duplicate
README + version drift across 8 docs), I6 (broken USER_MANUAL links).
Either symlink `docs/01_README.md` → top-level README, or delete it.
Bump every doc's footer to the current module version or strip per-doc
versions altogether.
**Why now:** This module is the one most likely to be picked up by a
non-Duncan analyst (CCPB analysts have asked about it; the IPK rebuild
plan touches it; Jess uses it). A confused doc pack makes that handoff
harder than the code itself.
**Effort:** Small (half a day).
**Dependencies:** None.
**Risk:** Low. Worst case is a brief period where docs reference a
file by old name during the rename.

### 3. Lint + style gate

**What:** I7. Install `lintr` + `styler`, drop a `.lintr` at project
root, add a `Rscript -e 'lintr::lint_dir(...)'` call to CI (or to a
`make check` target).
**Why now:** Adding the gate to a clean baseline is cheap. Adding it
later after style drift accumulates is expensive.
**Effort:** Small.
**Dependencies:** None.
**Risk:** None — gate starts as a warning, not a blocker, until the
existing code is brought into line.

### 4. Welch t-test option + dual alpha — tabs feature parity

**What:** Add `var.equal = FALSE` (Welch) as an optional config setting.
Add the dual-significance pattern (already in tabs per memory) so
trackers can display two thresholds (e.g. p<0.05 = filled asterisk,
p<0.10 = hollow asterisk).
**Why now:** Tracker reports are what clients see year-over-year. The
ability to flag "trending" changes at p<0.10 in addition to "confirmed"
changes at p<0.05 is something CCPB and similar clients would value —
the current binary "sig / not sig" hides marginal signals.
**Effort:** Medium. Welch is local to `t_test_for_means` + plumbing.
Dual alpha touches every `perform_significance_tests_*` and every
output writer that renders the asterisk.
**Dependencies:** #1 done first (don't pile new tests on a known-buggy
sig layer).
**Risk:** Output-format churn. Many existing reports' visual styling
assumes one asterisk per change.

### 5. Per-question minimum_base + display floor

**What:** Add a `MinBase` column to the question_map. When eff_n falls
below it for any wave, suppress the value (show "—") rather than
showing an unreliable number. Today the floor is a global 30.
**Why now:** Sub-segment banner cuts often dip below 30 effective N.
Today the report shows a number with a quiet "low base" footnote.
Per-question control would let analysts protect sensitive metrics
(e.g. NPS) more aggressively than non-sensitive ones (e.g. awareness).
**Effort:** Medium. Touches config loader, question_map index, every
wave_result formatter, plus tests.
**Dependencies:** Settled config schema (no other column changes
queued).
**Risk:** Backwards-compat — existing question_maps without MinBase
need to default to the global.

### 6. HTML report — banner significance heatmap

**What:** A summary heatmap showing, for each tracked question, which
banner segments moved significantly wave-on-wave. The data is already
calculated by `banner_trends.R`; the heatmap renderer exists at
`html_report/03f_heatmap_builder.R`.
**Why now:** This is the "headline" visualisation an exec wants in a
tracker readout — "who's moving and where" in one screen. It's an
analyst time-saver and a sales asset for the module itself.
**Effort:** Medium. The two halves exist; the work is plumbing,
hover-tooltips, and significance colouring.
**Dependencies:** None statistical. Could land alongside #4.
**Risk:** Performance — banner × question heatmaps can be large.
Pre-render to static SVG rather than runtime DOM.

### 7. Stats Pack maturation

**What:** The v10.2 Stats Pack (Generate_Stats_Pack = Y) exists but the
docs treat it as "for advanced partners." Mature it into a defensible
audit trail: method documentation per metric, formula citations, weight
diagnostics (effective N vs nominal N per question per wave), the
decisions made on missing data, and a per-test p-value table.
**Why now:** Compliance-aware clients (CCPB, anyone in pharma) increasingly
expect this. Today it exists as a workbook but lacks the explanatory
text to be standalone-defensible.
**Effort:** Medium-large. Mostly content + templating, not algorithm.
**Dependencies:** #1 (so the documented methods are correct).
**Risk:** Scope creep. Lock the structure first, fill it iteratively.

---

## Known limitations

| Limitation | When it matters | Mitigation |
|------------|-----------------|------------|
| Pooled t-test only | Unequal variances between waves (rare in stable trackers, common in new launches) | #4 — Welch option |
| Conservative NPS SE | NPS reports with real but moderate changes | #1.I3 |
| `eff_n` only set when `mean` in TrackingSpecs | Box/range-only configs with weighting | #1.I1 |
| No `min_base` check on enhanced-metric sig tests | Small-base banner cuts on top_box / range | #1.I2 |
| Wave pairs only — no roll-up, no skip-one comparison | Year-over-year reads, rolling-wave averaging | New work, not a quick fix |
| No respondent-level panel modelling | Panel studies (tracker assumes cross-sectional) | Out of scope for this module — would be a separate `panel` module |
| Single global `minimum_base` | Mixed-sensitivity trackers (e.g. NPS strict, awareness loose) | #5 |
| Documentation drift across 9 doc files | New developer onboarding, client handovers | #2 |

---

## Technical debt

| Debt | Why accepted | When to pay down |
|------|--------------|-----------------|
| 5 files > 1000 LOC | v10.1 already extracted the obvious seams; further splits would scatter readers | When a new feature needs to live in one of them — split during that change, not pre-emptively |
| Pooled t-test default | Convention + negligible difference at tracker N | Pay down via #4 (make it a config knob, keep pooled as default) |
| Conservative NPS SE | Documented in comments as "MVT — could be enhanced" | #1.I3 |
| `04_USER_MANUAL.md` ↔ `USER_MANUAL.md` link mismatch | Likely from a renaming that wasn't propagated | #2 |
| Hardcoded 1.96 for 95% CI | Trivial constant; only matters if alpha changes | M5 — half-hour fix |
| No `.lintr` gate | Project never had one | #3 |
| Two `stop()` calls remain in pre-TRS bootstrap | Bootstrapping correctness — TRS infra may not be loaded yet | Permanent — these are TRS *fallbacks*, not violations |

---

## External dependencies to watch

| Dependency | Version | Concern |
|------------|---------|---------|
| `openxlsx` | ≥ 4.2.5 | Active. Watch for the `openxlsx2` migration — Excel writes are the primary output path |
| `readxl` | ≥ 1.4.0 | Stable, but has slower performance than `openxlsx::read.xlsx` on big files |
| `haven` | optional, ≥ 2.5.0 | SPSS .sav support. SA market-research clients still ship .sav |
| `shiny` | optional, ≥ 1.7.0 | GUI only — module runs without it |
| `future` / `future.apply` | optional | Used by parallel = TRUE path. Mature, low concern |
| R | 4.5.3 (current env) | Tracker doesn't use R 4.5-specific features; should run on 4.2+ |

No critical version pins. The Excel I/O dependency is the most strategic
— if `openxlsx2` becomes mainstream, plan a migration spike.

---

## Summary

Tracker is the most-used analytical module in Turas and the most
visible to clients — every CCS / CCPB / IPK tracker report comes through
here. The codebase is healthy: 19,700 LOC, 1855 tests, clear v10.1
extraction discipline, no critical correctness bugs. The headline
"CCS handling vs Equipment Cleanliness" inconsistency that triggered
this review is, on inspection, correct statistical behaviour rather
than a bug.

The clearest path forward is the **one-week polish branch** that closes
the three statistical correctness items (I1–I3), locks them in tests,
and clears the doc-drift backlog (I4–I7). After that, the highest-
leverage feature investments are Welch + dual-alpha (#4) and the banner
heatmap (#6) — both lift the module from "competent" to "client-asset."

The biggest unaddressed constraint is **wave-pair-only comparisons**.
Every roll-up, year-over-year, or skip-one comparison a client will
eventually ask for is blocked on that. It's not urgent but it's the
ceiling of the current architecture.
