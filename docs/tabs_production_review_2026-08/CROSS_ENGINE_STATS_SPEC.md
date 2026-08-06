# Cross-engine statistics batch (I1/I2) — design & implementation spec

**Status:** Design locked 2026-08-05 (Fable design session). Awaiting implementation.
**Findings:** I1 + I2 in `PRODUCTION_REVIEW.md` (this folder) — the last correctness
residuals from the 2026-08 production review.
**Implementer brief:** Opus 4.8, high effort. Every stage ends with an executable
gate. Read the **Traps** section before touching anything.

---

## 1. The problem, as verified in code this session

Turas tabs has two statistics engines that can disagree on the same deliverable:

**Engine A — the R engine** (report of record: the Excel workbook, and the
letters carried into the v2 island):

- Proportions: `weighted_z_test_proportions()` (`lib/weighting.R:800`) —
  pooled two-sample z on weighted counts/bases, SE sized on the Kish effective
  base, normal-approximation guard (min expected 5), min_base gate.
- Means: `weighted_t_test_means()` (`lib/weighting.R:1002`) — Welch t on
  **population** variance (`weighted_variance()`, Σw denominator), SE and df
  sized on `calculate_effective_n()`.
- **`calculate_effective_n()` (`lib/weighting.R:~400`) returns
  `as.integer(round(n_effective))`** — integer-rounded. But
  `calculate_effective_base()` (`lib/cell_calculator.R:581`) returns
  **fractional** n_eff, and that is what rides in `banner_bases[[key]]$effective`
  into the proportion tests (`standard_processor.R:239` etc.). So within R:
  proportions test on fractional n_eff, means on integer-rounded n_eff.
  n_eff 29.6 fails min_base 30 for proportions, rounds to 30 and passes for means.
- Dual alpha: `add_significance_row()` (`lib/run_crosstabs.R:366`) emits a
  `Sig.` row (primary, e.g. 95%) and a `Sig.2` row (secondary, e.g. 80%,
  superset letters) from ONE p-value per pair. Net rows have their own parallel
  path (`lib/weighting.R:1339–1429`, direct `weighted_z_test_proportions` calls
  at :1389/:1403) which also emits `net*_2` secondary letters.
- **No FPC anywhere.** Confirmed: zero callers of any FPC function in
  `modules/tabs/lib`; population config is loaded
  (`crosstabs_config.R:1241` → `config_obj$population_frame`, plus
  `population_size` at :268) but only the data-layer writer reads it.

**Engine B — the v2 JS engine** (`modules/tabs/lib/html_report_v2/assets/js`,
recomputes under filters/custom banners, plus two overlays on the published view):

- `21_stats.js`: fractional Kish `effectiveBase()` everywhere (:96);
  `weightedMeanColumn` (:380–395) scales population variance by
  `effBase/(effBase-1)` (sample variance); `meanZ` (:458) is a **z**-test, not
  Welch t; `propZ` (:440) is formula-identical to R's z-test including the
  min-expected-5 guard; `sigLetters` (:481) mirrors R's Bonferroni divisor
  (comment says so, code confirmed: `choose(k,2)` over the group's non-Total
  columns).
- FPC: `21c_confidence.js` `fpcMul/fpcBase` (:186–213) with a 5% material-
  coverage floor; `22_model.js` `applyFpcSignificance` (:360+) **re-letters the
  published view** from published (display-rounded) %s and the FPC `ciBase`,
  for unweighted population reports only.
- Sig.2: the published view **recomputes** 80% letters from the published
  integer-rounded counts (`22_model.js:94–103` — `sigCell(r.n[ci], q.bases[ci])`
  where `r.n` is the `Frequency` row, which `format_output_value()` rounded to
  0dp: `run_crosstabs.R:535`, `"frequency" = round(x, 0)`). R tested the
  unrounded weighted counts. Marginal p≈0.20 calls can flip between the Excel
  Sig.2 row and the HTML lowercase letters. Mean rows get NO 80% letters in the
  published view at all (comment at `22_model.js:91`: no per-column SD in the
  model).
- Primary letters, by contrast, are **carried** from R: the data layer emits
  each row's `sig` array from the `Sig.` row (`data_layer_writer.R:631–642`) —
  the pattern this batch extends.

**The data layer** (`data_layer_writer.R`):

- `build_dl_question()` (:587) publishes `pct` / `n` (0dp-rounded Frequency) /
  `sig` (primary letters only) per row, and `bases[]` with `n` (unweighted),
  `nWeighted`, `nEff` (fractional) for weighted reports.
- `build_dl_columns()` resolves each column's population N via
  `.resolve_column_population()` (:312) — Total column gets `population_size`,
  banner columns match the Population frame, no match → no field.
- `proj$weighted` (:225) exists solely to gate the JS FPC re-lettering off for
  weighted designs ("design effect not in the published layer" — no longer
  true: `bases[].nEff` has carried it since the weighting work).

**The FPC source of truth already exists and is tested:**
`modules/confidence/R/03_study_level.R` — `calculate_fpc_factor()` (:169),
`apply_fpc()` (:218), `FPC_MIN_COVERAGE <- 0.05` (:134). `apply_fpc(n_eff,
n_actual, N)` returns `n_eff` untouched when N unusable or coverage ≤ 5%,
`Inf` at full census, else `n_eff·(N-1)/(N-n_actual)`. The JS is a port of it.

---

## 2. Decisions (locked this session)

**D1. The R engine is the single source of truth for every published
statistic.** Everything the reader sees by default — Excel Sig./Sig.2 rows, the
v2 published-view letters at both alphas — is computed once, in R, and
*carried*. The JS engine remains only for what R cannot precompute (live
filters, custom banners), where it is already badged as computed. Rationale:
the Excel workbook is the deliverable of record; carrying beats recomputing
(the rounding trap is exactly a recompute bug); the primary-letter carriage
pattern already exists and works.

**D2. FPC is applied inside the R tests, using the confidence module's helper
extracted to shared.** Move `calculate_fpc_factor()`, `apply_fpc()` and
`FPC_MIN_COVERAGE` into a new `modules/shared/lib/fpc.R`; the confidence
module sources it and re-exports unchanged (its API and tests must not move);
tabs sources it the same way it sources `modules/shared/lib/trs_refusal.R`
(`00_guard.R:45` pattern). Do NOT copy the functions into tabs (non-duplication
rule) and do NOT source the whole confidence module.

Mechanics in the R engine:

- At significance-test assembly time, each column's test entry gains an
  `fpc_mul` — computed per question × column as
  `apply_fpc(1, n_actual, N) ` where `n_actual` is that column's **unweighted**
  base for that question (`base_info$unweighted`) and `N` is the column's
  universe resolved with the **same resolver the writer uses**. Move
  `.resolve_column_population()` from `data_layer_writer.R` to
  `report_shared.R` (exported), call it from both places — one resolver, one
  behaviour. Total column N = `population_size`; unresolved column → mul 1.
  (Equivalently carry `(n_actual, N)` and let the test call `apply_fpc`
  directly — implementer's choice, but the multiplier must come from
  `apply_fpc`, not a re-derivation.)
- `weighted_z_test_proportions()` and `weighted_t_test_means()` gain
  `fpc_mul1 = 1, fpc_mul2 = 1` parameters, applied to the n each test actually
  uses (the eff_n branch AND the unweighted base branch for the z-test; the
  internally computed eff_n for the t-test). Default 1 ⇒ byte-identical for
  every existing caller — that is the no-population guardrail.
- **A full-census column (mul = Inf) is excluded from pairing** — contributes
  no letters and receives none — mirroring v2 (`22_model.js` `sizeAt`: "A full
  census has no sampling error to test"). Implement as: if either side's
  FPC-adjusted n is `Inf`, return the not-significant result.
- **min_base gates on the FPC-adjusted n** (FPC plan locked decision #3: the
  instability warning fires on the corrected base; the test gate must agree
  with the flag).
- The net-row path (`weighting.R:1389/:1403`) passes the same multipliers.
- Weighted studies get FPC'd letters too — R has the true per-column Kish
  n_eff, so the plan's out-of-scope gap ("weighted census keeps standard
  significance") closes here for the R engine and every carried surface.
- Stats pack Declaration (`stats_diagnostics.R`): add lines when a population
  is configured — universe size, coverage, "significance and intervals use
  finite-population-corrected effective bases". Read real config keys (I4's
  lesson).

**D3. n_eff is fractional everywhere in R.** `calculate_effective_n()`
(`weighting.R`) stops rounding: return `n_effective` as-is (keep the
scale-safe normalisation). Audit every caller before changing — display sites
must round at format time (`format_output_value`), never in the statistic.
This aligns means with proportions inside R, and R with JS. **This is a
deliberate behaviour change:** mean pairs whose rounded n_eff crossed min_base
(e.g. 29.6→30) stop testing; marginal Welch p-values move slightly. Regression
fixtures are updated deliberately and the change is release-noted. Any golden
fixture that changes must be re-derived by hand-check, not blindly re-blessed.

**D4. Sig.2 is carried into the island, not recomputed.**

- Writer: `build_dl_question()` emits, per row, `sig2` — the verbatim `Sig.2`
  row letters (same extraction as `sig_for()` but `RowType == "Sig.2"`), only
  when the run is dual-alpha (`detect_available_stats`' `has_sig2`). Mean rows
  included — R computes Sig.2 for means and nets already.
- Model (`22_model.js:94–103`): when the island carries `sig2`, the published
  view derives `low80` as **set-difference: letters in sig2 not in sig,
  lowercased** (Excel's Sig.2 is a superset that includes the 95% letters).
  The count-based recompute remains ONLY as fallback for islands without
  `sig2` (old fixtures), and mean rows now get their 80% letters in the
  published view for the first time — note this in the CHANGELOG as a fix,
  not a feature.
- Computed views (filters/custom banners) keep recomputing both alphas —
  unchanged.

**D5. The v2 published-view FPC re-lettering overlay is retired.** Once R
letters are FPC-corrected at source, `applyFpcSignificance` recomputing from
display-rounded %s is a second, worse computation of the same thing — exactly
the recompute pattern this batch removes. Delete the overlay call for the
default view (and the now-moot `proj$weighted` gate for it); **keep** FPC
intervals, `ciBase`, coverage-aware low-base flags, census framing, and the
PUBLISHED·FPC badge (rename the badge only if it now lies — it doesn't: the
view is still published + FPC intervals). Computed views keep their standard
(non-FPC) behaviour under filters, as the FPC plan locked (unknown
sub-population N).

**D6. Divergences that remain, documented and bounded — not silently.**
The JS computed engine keeps: `meanZ` as a z-test (R: Welch t; a t-inverse in
JS is not worth the code), sample-variance scaling `effBase/(effBase-1)` (R:
population variance), and pooling on effective bases for weighted proportions
(R: pools on weighted counts/bases). These surface only under live
filters/custom banners, where there is no R counterpart to disagree with, and
the view is badged computed. The parity harness (§3) pins exact parity where
exactness is claimed and documents the tolerance elsewhere. Aligning the mean
test is an optional follow-up, not this batch.

---

## 3. Parity harness spec

New fixture + two suites, grown stage by stage. Purpose: make cross-engine
agreement an executable gate, permanently.

**Fixture.** One small synthetic project (reuse the e2e demo-project harness
pattern from C6) with: a weighted variant, dual alpha (0.05/0.20), a
Population sheet + population_size (one column at full census, one above the
5% floor, one below it, one unresolved), at least one mean question, one
proportion question with nets, one routed question (smaller per-question
bases), and pairs engineered to sit near both alpha thresholds and near
min_base (n_eff ≈ 29.5–30.5). The R testthat run generates the island from it;
the island is committed as a golden fixture for the JS suite with a documented
regen command (same discipline as the existing goldens).

**R suite (testthat, `test_cross_engine_stats.R`):**

1. Known-answer FPC tests through the *tabs* path (the shared helper already
   has its own tests in confidence — these test the wiring, not the maths):
   census column excluded from pairing; below-floor column unchanged;
   corrected column flips a hand-computed marginal pair.
2. Carriage integrity: for every question in the generated island, `sig` ==
   the table's `Sig.` row and `sig2` == the `Sig.2` row, cell for cell.
3. No-population guardrail: the fixture minus its population config produces
   letters identical to a pre-FPC run (fpc_mul defaults are inert).
4. Fractional n_eff: a hand-built weights vector with n_eff 29.6 does NOT test
   at min_base 30 for means (regression on D3), and the same n_eff feeds
   means and proportions identically.

**JS suite (`parity_stats_tests.mjs` in
`modules/tabs/lib/html_report_v2/tests/`, registered like the other 25):**

1. Published view renders carried letters verbatim (both alphas) — no
   recompute drift on the default view, including mean rows' new low80.
2. Exact parity where claimed: for the fixture's **unweighted, unfiltered**
   first banner, JS-computed proportion letters == carried R letters, both
   alphas (`propZ` and the Bonferroni divisor are formula-identical — any
   failure is a real bug, not tolerance).
3. Documented divergence: for mean pairs, assert |z − Welch t decision| only
   outside a band |p − α| > ε (ε documented in the test header); pairs inside
   the band are logged, not failed. This is the executable form of D6.
4. `sig2`-absent fallback: an old-style island (fixture stripped of sig2)
   still renders 80% letters via the count recompute.

---

## 4. Implementation stages (each ends with a gate that can fail)

**Stage 1 — fractional n_eff (D3).** `calculate_effective_n()` + caller audit.
Gate: full R suite; every fixture delta hand-verified and listed in the commit
message; harness test R-4.

**Stage 2 — Sig.2 carriage (D4).** Writer emits `sig2`; model consumes with
fallback; CHANGELOG notes mean-row 80% letters. Gate: R writer tests + JS
suites incl. harness JS-1/JS-4; regenerate the golden island.

**Stage 3 — FPC into R + overlay retirement (D2, D5).** Shared helper
extraction first (confidence suite must stay green — its loader may be
whitelist-style, check how its R/ files are sourced before moving anything),
then resolver move, then test wiring, then Declaration lines, then delete the
JS overlay call. Gate: full R suite + confidence suite + all JS suites +
harness R-1/R-2/R-3, JS-2/JS-3; census fixture letters agree Excel↔island.

**Stage 4 — harness completion + docs.** Whatever assertions weren't landed
with their stage, plus: PRODUCTION_REVIEW.md residuals updated (I1/I2 →
fixed, with commit hashes), OPERATOR_GUIDE FPC section gains "applies to Excel
too", CHANGELOG. Gate: the pre-delivery checklist below.

Suite baseline before you start (verify, don't trust): R 3,327+/0/0/0 at the
classic-retirement tip (memory says 3,587 pre-deletion; run it yourself),
25 JS suites green, project-root suite has 3 known unrelated fails.

---

## 5. Traps (read before editing)

1. **The prototype is stale — do not sync from it.** Production JS source of
   truth is `modules/tabs/lib/html_report_v2/assets/js/` (last touched by many
   post-FPC commits). `prototypes/report-redesign/fable/v2/src/js/` stopped at
   the FPC commit (95e861f2) — verified `cmp` DIFFERS on all three stats
   files, 461 vs 687 lines on 22_model.js. A "sync" from the prototype would
   destroy months of work. Edit production directly; its tests live in
   `modules/tabs/lib/html_report_v2/tests/`.
2. **Concurrent sessions on main.** Another session's uncommitted
   composite-processor sig work may sit in the worktree. `git status` before
   starting; commit only files this batch touched; check mtimes on anything
   unexpected (see memory: concurrent-session collisions).
3. **`build_config_object` is a whitelist** — this batch needs NO new config
   keys (population_size + frame are registered). If you find yourself adding
   one, stop and re-read the design.
4. **Two `format_output_value` definitions exist** (M3, left deliberately):
   `run_crosstabs.R:535` wins over `excel_utils.R:118`. Don't "fix" that here.
5. **NULL-valued keys in build_config_object ARE present in `names()`** —
   `%in% names(config)` guards flip; use truthy checks.
6. **The e2e harness hand-copies constants from run_crosstabs.R** — if you
   touch row-type constants, grep the harness.
7. **openxlsx, never openpyxl, to verify generated workbooks** (drawing refs).
8. **Fixture re-blessing:** any golden that moves in stages 1/3 must be
   re-derived by hand-calculation in the test comment, not regenerated and
   accepted. That is the difference between a parity gate and a tautology.
9. **Duncan regenerates real projects via launch_turas** — never run the
   pipeline against OneDrive deliverables; verify on the committed fixture
   only.

---

## 6. Acceptance checklist

- [ ] No-population, single-alpha, unweighted report: byte-identical output
      (island + workbook) vs pre-batch main.
- [ ] Census fixture: Excel letters == island published letters at both
      alphas; census column blank in both; Declaration states FPC.
- [ ] Weighted census fixture: R letters FPC-corrected; v2 shows carried
      letters (no overlay).
- [ ] n_eff 29.6: means and proportions both refuse to test at min_base 30.
- [ ] Sig.2 flip case from the review (marginal p≈0.20, rounded count) now
      agrees Excel↔HTML because both show the R letters.
- [ ] Full R suite, confidence suite, all JS suites, harness suites: green,
      counts reported in the handover with before/after.
- [ ] CHANGELOG + review-doc residuals updated; every behaviour change listed.
