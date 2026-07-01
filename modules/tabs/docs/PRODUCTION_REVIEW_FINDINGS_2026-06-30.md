# Production Review Findings — the integrated v2 reporting system (tabs + tracker)

**Source:** independent multi-agent audit (40 agents, 12 cold-reading area finders → adversarial
verify per finding → 3 completeness critics), read-only, against the brief
`PRODUCTION_REVIEW_BRIEF_2026-06-30.md`. Every finding below was CONFIRMED by a second agent whose
default stance was to refute it; 5 further candidate findings were refuted and dropped.

**Suite status at review time — all green.** JS: qual 59, disclosure 12, tracking_nav 10, composite 8,
portrait 8, takeout 25 (122/122). R: tabs testthat 2485 pass / 0 fail / 9 pre-existing env skips;
tracker testthat 1894 pass / 0 fail / 1 warn. The bugs below are all in territory the suites do not
cover — passing tests are necessary, not sufficient.

## Verdict — NOT ready to merge

The architecture is sound and the disclosure *primitives* are correct (the k-check uses an unweighted
respondent count; "off" is byte-identical; Save-copy re-renders from islands with no baked-HTML leak).
But two clusters block a merge that will make this the client-facing deliverable:

1. **The disclosure control is a client-side render gate over data that ships in full.** It does not
   deliver the re-identification protection it advertises. Per the brief's own rule ("any path that
   leaks sub-threshold identity blocks the merge"), this blocks.
2. **Weighted and finite-population statistics are wrong in several places in the v2 recompute.** On
   weighted/census studies the report shows incorrect — sometimes inverted — significance and
   intervals, and disagrees with the R-generated Excel. This blocks for any weighted/census deliverable.

Clusters 3–5 are real bugs to fix but are not, individually, merge blockers.

---

## Cluster 1 — Disclosure is a render gate, not anonymisation (BLOCKER)

Root cause: `min_reporting_base` is wired only into the HTML *render* paths (and the qual shortlist
export). The identifying data itself — every commenter's demographics, and in `text_mode:"full"` every
verbatim — is serialized into the page islands and the Excel workbook regardless of the threshold. The
render gate also has unguarded paths, and fails open in one configuration.

- **B1 (high, CONFIRMED).** `qual_island_builder.R:159` / `qual_report.R:25` — the DATA_QUAL island
  writes `record$demos` (full profile) and `record$text` as plaintext JSON gated only by
  `demographic_cuts` and `text_mode`; `min_reporting_base` is never consulted at serialization.
  View-Source (or Save-As) of a report built `full`/`allow`/`k=10` reconstructs any sub-k cut,
  cross-referenced against the equally-complete `data-micro` vectors. *Note: the interactive report
  inherently ships respondent-level microdata so it can re-filter live — this is partly a property of
  the design, but the disclosure dial is sold as protection it does not provide against the source.*
- **B2 (high, completeness).** `27q_qualitative.js` `prevalenceHtml`/`mainHtml` (~:491, :576) — the
  DEFAULT overview prevalence board is **not** gated by `disc.audienceTooSmall()`. On a sub-k audience
  it still renders per-theme `n / pos / neu / neg` and "n=1" badges, while the filter chips above name
  the ~3-person cut. Strongest on-screen leak. Fix: gate `prevalenceHtml` like `crosstabHtml`, or
  suppress any theme row with `1 ≤ n < k` via `disc.cellOk(n)`.
- **B3 (high, completeness).** `27q_qualitative.js` `quoteCard` (~:735) — under a sub-k cut the drawer
  hides demographic *tags* but still renders every verbatim *text* (text is withheld only when the
  independent `text_mode='hidden'`). With the cut named in the filter bar, tag suppression is largely
  cosmetic. Fix: when `audienceTooSmall()`, withhold the quote list (or force text hidden), not just tags.
- **B4 (high, completeness).** `excel_writer.R` `write_crosstab_workbook()` — the MAIN crosstab
  workbook, the file analysts actually distribute, has **no** disclosure awareness at all; every below-k
  sub-cut ships in full. Distinct from the §4 "complementary cell suppression follow-up" (that concerns
  HTML tables). Fix: gate the workbook (blank sub-k cells + cover-sheet note), withhold it when `k>1`,
  or at minimum warn loudly on the console that the threshold does not cover it.
- **B5 (high, completeness; = low A confirmed live).** `21d_disclosure.js:32` — `audienceBase()`
  returns `Infinity` when `TR.MICRO` is absent, so `audienceTooSmall()` is always false and tags render.
  `build_microdata()` degrades to NULL on any error (`run_crosstabs.R:728`), so `k=10` can silently do
  nothing. Fix: **fail closed** — treat missing MICRO as too-small; warn at build when `k>1` and micro is NULL.
- **B6 (high, completeness).** The three knobs (`min_reporting_base`, `qual_demographic_cuts`,
  `text_mode`) are independent with no cross-validation. Setting `k=10` alone (leaving `allow`/`full`)
  is near-useless. Fix: couple them (a non-trivial `k` forces demos out of the island / forces redacted
  text) or emit a build-time TRS warning.
- **C-leak (medium, completeness).** `27q_qualitative.js themeCrosstab` — column suppression guards the
  column base but not individual cells: a safe column (base 40) can print `net −100% / 1 raised` for a
  lone mentioner, and the island carries per-record banner membership + verbatim regardless. Fix:
  `disc.cellOk(cell.men)` on cells + sub-rows; coarsen sub-k detail server-side before serialization.
- **J-leak (low, completeness).** `28_insights.js:42` — legacy `TR.AGG.comments[code]` verbatims carry a
  banner tag, are not narrowed by the audience filter, and are not disclosure-gated. Decide if this
  channel is in scope.

**Recommended direction:** the only robust fix is a **server-side redaction pass** — coarsen or blank
sub-threshold detail in `qual_island_builder.R` / `qual_quant_layer.R` (and the workbook) *before* it
enters the islands, not only in the JS render. Alternatively, define two explicit modes: an internal
report (microdata in source, documented) vs a locked-down client report (redacted at source). Either
way, the current "set k and you're protected" promise needs to become true or be withdrawn.

---

## Cluster 2 — Weighted / finite-population stats are wrong in the recompute (BLOCKER for weighted/census)

Root cause: the JS recompute mixes a **weighted count** over an **unweighted base**, and uses the
**unweighted n** (not Kish `eff_n`) to size significance tests; FPC is applied to significance in JS but
not in R. Because the report recomputes on every filter, both engines must agree — they don't.

- **D1 (high, CONFIRMED).** `22_model.js:300` `attachIntervals` — 95% CI computed as
  `p = weightedCount / unweightedBase`, so the Wilson interval is centred on a different number than the
  % it annotates. Example: weighted base 150, weighted count 90 → displays 60% but intervals on 90%.
- **E1 (high, CONFIRMED).** `22_model.js:65` — published-view 80% dual-sig letters recompute from
  `weightedCount / unweightedBase` with the unweighted n; **inverts** the real relationship (30/100 vs
  42/100 instead of true weighted 0.50 vs 0.30) and contradicts the 95% letters in the same cells.
- **E2 (medium, CONFIRMED).** `22_model.js:64` — the low80 recompute is gated to `kind==='category'`, so
  NET and mean/index rows never get 80% letters in the default view, though R computed them (discarded
  `Sig.2` row). The same rows *do* get 80% letters once filtered — inconsistent within one table.
- **E3 (medium, CONFIRMED).** `21_stats.js:385` `meanZ` — JS uses sample-variance SD + fixed z=1.96;
  R uses population variance + Welch t. Three SD conventions coexist (JS sig, R sig, R displayed).
  Mean-significance letters diverge from R near the boundary.
- **FPC-sig (high, completeness).** `22_model.js:555` `applyFpcSignificance` re-letters the default view
  from an FPC-narrowed base; the R engine applies **no** FPC to significance. On census projects the
  HTML letters claim significance the Excel denies. Fix: pick one — port FPC into the R z-test, or gate
  the JS FPC-on-significance off.
- **eff_n rounding (medium, completeness).** `weighting.R:401` returns `as.integer(round(n_eff))`;
  `21_stats.js:37` uses the raw float. Flips the min-expected≥5 precondition and the low-base gate at
  boundary bases, desyncing HTML letters from Excel even after the above are fixed.
- **G1 (high, CONFIRMED).** `22w_waves.js:331` — weighted wave-on-wave significance computes a Kish
  eff-N-corrected SD but then feeds the test the **unweighted** base, understating SE and over-flagging.
  The classic tracker uses `eff_n` here (`trend_significance.R:65`). The v2 tracker reports more
  "significant" wave movements than the classic one on identical weighted data.

**Recommended direction:** serialize the weighted base **and** `eff_n` into the published columns so the
JS recompute uses weighted-count / weighted-base and `eff_n` for SE — or have R own the published 80%
letters (stop discarding `Sig.2`) and drop the JS low80 recompute. Align FPC handling, the `eff_n`
rounding, and the z-critical constants between the two engines. Add weighted fixtures that diff HTML
letters against the R-generated Excel.

---

## Cluster 3 — Patterns tab: correctness + lost curation

- **F1 (high, CONFIRMED).** `27e_takeout_engine.js:436` `oddOnePattern` — thresholds calibrated for 1–5
  scale points are applied to raw gaps, but `indexQuestions()` includes NPS/Score questions bucketed to
  ±100. A meaningless NPS wobble clears the floors and fabricates a spurious "odd one out" card (with a
  "survives correction" badge); the group's baseline `meanGap` is also polluted by mixing ±100 with
  ±0.1. Fix: normalise gaps to per-scale units (or exclude NPS/Score from the index-scale scan).
- **F3 (low, CONFIRMED).** `27f_takeout_data.js:319` `gatherBimodality` assumes 1..K; NPS/Score and
  0-based scales lose their bottom camps (every detractor/passive dropped), so a genuine 0–10
  detractor/promoter split is invisible while still counted in the "scanned N questions" provenance.
- **F2 (medium, CONFIRMED).** `27e_takeout_engine.js:472` — bimodality banding has no middle band on
  even-max scales, disabling the trough requirement (the `bMoment` gate still catches it in practice, so
  no concrete false positive was constructed — low real risk).
- **K1 (high, CONFIRMED).** `32_report.js:218` `saveCopy()` serializes a fixed key list that **omits
  `takeout`**. Rewritten takeaways, vetoed patterns, and the custom apex headline are written to
  localStorage but not into the saved `.html`; the recipient sees the raw engine defaults. The one tab
  most likely to be curated is the one that loses its curation in the hand-off file. Fix: add `takeout`
  to the serialized state (matching how `27f` hydrates `TR.userState.takeout`).

---

## Cluster 4 — Export & build robustness

- **L1 (high, CONFIRMED).** `build_report_v2.R:131` — tokens are replaced sequentially with
  `strsplit(fixed)`, replacing every occurrence in the whole document including inside already-inlined
  island JSON. A survey verbatim/label containing the literal `{{JS}}` gets the entire JS bundle spliced
  into the island string, breaking `JSON.parse` and blanking the report. Fix: single-pass replacement,
  or escape `{{` in island/title content before inlining.
- **I1 (high, CONFIRMED).** `24_shell.js:253` `snapshotLines()` harvests text from headings/paragraphs
  but not `<th>/<td>`, so a theme×banner crosstab pinned to the Story exports to PPTX/PNG as a slide with
  the title/caption but **none of the numbers**. Silent data loss in an export the user believes is
  faithful. Fix: harvest table cells, or render the deck matrix from the pinned item's data.
- **I2 (medium, CONFIRMED).** `23y_xlsx.js:37` `cell()` coerces any numeric-looking string to a native
  number for *every* cell, including verbatims/demographics: `50%`→50, `007`→7, `0821234567`→821234567.
  Verbatim text is altered in the exported workbook. Fix: don't coerce text columns.
- **H (medium, CONFIRMED).** `28c_composite.js:69` `nextToken()` reissues a freed `composite:N` id after
  a remove, so a new, differently-defined profile banner inherits the previous one's saved analyst
  insight/note. Fix: monotonic counter, or migrate/clear insights on remove.

---

## Cluster 5 — Tracker

- **G2 (high, CONFIRMED).** `23za_trend.js:17` — the current wave's plotted x-key comes from
  `currentYear()` re-parsing the first 4 digits of `project.wave` (so `2025.5`→2025), ignoring
  `wave_order`. On a twice-yearly tracker the latest point collides with the H1 same-year wave (overlaps
  in the chart, overwrites the byYear cell, and mislabels via `yLabel`). Annual trackers (SACAP, CCS)
  unaffected. Fix: use the current wave's `wave_order_key` for its x-key.

---

## Low / cosmetic (fix opportunistically)

- **C-round (low).** `27q_qualitative.js:96` — independently-rounded sentiment split need not sum to the
  rounded salience (≤1-point visual mismatch; no downstream number affected).
- **D-regex (low).** `microdata_writer.R:174` — `grep(paste0('^', code, '_\\d+$'))` interpolates the
  code raw; a metacharacter (e.g. `.`) over-matches unrelated columns and inflates recomputed answers
  under a filter. Fix: `fixed`/`Qescape` the code, matching the exact-string construction the processors use.
- **repel (low).** `23z_charts.js:43` — backward label sweep can push a callout below `minPos` with no
  re-clamp (cosmetic overlap on crowded small-slice charts).

---

## Recommended fix order

1. **Cluster 1 (disclosure)** — server-side redaction + fail-closed + workbook coverage + gate the
   prevalence board / quote text. This is the merge blocker and the highest-stakes for a staff-survey
   deliverable.
2. **Cluster 2 (weighted/FPC stats)** — align the JS recompute with the R engine (weighted base + eff_n;
   FPC; z-constants), with weighted fixtures diffing HTML vs Excel.
3. **K1 + L1** — cheap, high-value: don't lose analyst curation on Save-copy; don't let one odd verbatim
   corrupt the whole build.
4. **Cluster 3 (F1) + Cluster 4 + Cluster 5** — Patterns scale-mixing, export fidelity, tracker x-key.
5. **Lows** — opportunistic.

Each fix ships with a regression test that fails before and passes after; then Duncan regenerates the
affected reports via `launch_turas` to eyeball, before the branch merges to `main`.
