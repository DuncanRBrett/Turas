---

editor_options: 
  markdown: 
    wrap: 72
---

# Finite Population Correction (FPC) — design & build plan

**Status:** Built 2026-06-26 — all phases A–G complete; awaiting Duncan's launch_turas regen + eyeball on a real population config (SACS). **Owner:** Duncan (decisions locked 2026-06-26) **Trigger:** Census / full-invite surveys (e.g. SACS, student surveys) where the universe is small and response is partial. Two recurring pains:

1.  A whole-population invite that gets \~30% response still shows intervals as wide as an infinite-population random sample, and small subgroups get flagged "unstable" even though they cover most of their (small) population.
2.  A small cohort (e.g. a Masters course, n≈20) that is a **75% response of a 27-person universe** is a near-complete count, not a fragile sample — but it is currently treated as a tiny, unstable sample.

## The statistics

For a base of `n` respondents drawn from a known finite population `N`, the standard error shrinks by the **finite population correction factor**

```         
FPC = sqrt( (N - n) / (N - 1) )        # ≈ sqrt(1 - n/N) for large N
```

Equivalently, expressed as an **effective base** that we can feed into the existing Wilson / mean-CI / z-/t-test machinery (which already runs on an effective base for weighting):

```         
n_eff_fpc = n_eff_kish * (N - 1) / (N - n_actual)
```

- Unweighted: `n_eff_kish = n_actual`, so `n_eff_fpc = n_actual·(N-1)/(N-n_actual)`.
- `n → N` (full census): `n_eff_fpc → ∞` ⇒ zero-width interval. Correct: if you measured everyone there is nothing left to be uncertain about.
- No population configured ⇒ factor 1 ⇒ **byte-identical to today** (guardrail: every existing report, incl. SACAP, must not move).

**What FPC does NOT fix:** the \~30% non-response is *non-response bias*, not sampling error. FPC narrows sampling uncertainty only. So wherever the design note appears we also surface the response/coverage rate and a one-line non-response caveat, so tighter intervals never imply false certainty.

## Decisions (locked)

1.  **Input model: per-subgroup population frame + total.** A study-level total universe plus optional per-column cohort sizes, so a small high-response column inside a low-response report is corrected on its *own* coverage.
2.  **FPC flows into significance too** (not just displayed intervals) — flags and intervals stay consistent. Opt-in: unconfigured ⇒ unchanged.
3.  **Coverage-aware small-base flag.** The "unstable" warning fires on the **FPC-adjusted effective base** vs the threshold, not raw `n`; where a base is suppressed-from-warning we annotate `n of N (xx%)`. Unconfigured ⇒ identical.

## Config surface

- `population_size` — Settings field: total universe (for the Total column FPC and the overall coverage/response rate). Optional.
- **`Population` sheet** (new, optional) — one row per banner subgroup: \| Banner \| Group \| Population \| \|---\|---\|---\| \| Study level \| Masters \| 27 \| \| Study level \| Honours \| 40 \|
  - `Banner` = banner question/label the column belongs to (optional; blank = match by `Group` value across any banner).
  - `Group` = the subgroup/column label as shown in the report.
  - `Population` = integer N for that subgroup.
- Absent sheet / blank values ⇒ no correction for that column.

## Build phases

- **A. R config** — read `population_size`; load optional `Population` sheet to `config_obj$population_frame`; register keys. *(crosstabs_config.R, data_loader.R)*

- **B. R writer** — `build_dl_project` emits `population_size` + total `coverage`; `build_dl_columns` resolves each column's `population` + `coverage` from the frame and emits them. *(data_layer_writer.R)* + testthat.

- **C. R confidence helper (source of truth)** — `calculate_fpc_factor(n, N)` and `apply_fpc(n_eff, n_actual, N)` in 03_study_level.R, with known-answer testthat. The JS ports these verbatim and the gate asserts agreement.

- **D. JS FPC (prototype src/js)** — implemented as an **overlay on the published default view** (the report of record), NOT a recompute, so the shown numbers never move:

  - `21c_confidence.js`: `conf.fpcMul/fpcBase/coverage/reportHasPopulation/ responseRate`; design sentence gains the coverage + non-response caveat.
  - `22_model.js`: `publishedModel` carries each column's `population`, `coverage` and `ciBase` (the FPC effective base); `attachIntervals` widths read `ciBase` (so intervals narrow — `Infinity` ⇒ zero width); a new `applyFpcSignificance` post-pass re-letters significance from the **published %s and `ciBase`** (never microdata) for **unweighted** population reports — weighted designs keep standard significance (their design effect isn't in the published layer) but still get FPC intervals. FPC is suppressed under a live filter / custom banner (`fpcDefault = !custom && !filtered && reportHasPopulation`).
  - `23_render.js`: base row shows `xx% of N` and sizes the worst-case margin on `ciBase`; low-base flag is coverage-aware (set from `ciBase < threshold`).
  - `25_cards.js`: a population default view is badged `PUBLISHED · FPC`.
  - writer emits `project.weighted` so the JS can gate the sig re-lettering.
  - new `tests/fpc.mjs` gate (kernel + intervals + significance flip + weighted fallback + reversibility); registered in `run_tests_v2.mjs`.

  **Why an overlay, not a recompute:** golden parity only guarantees published==computed for the FIRST banner; other banners' published bases can differ from a microdata recount, so routing the default view through compute would silently move the report-of-record numbers. The overlay reads only the published layer, so numbers are guaranteed verbatim.

- **E. Sync** prototype `src/js` → production `modules/tabs/lib/html_report_v2/assets/js` (byte-identical).

- **F. Template + docs** — `generate_config_templates.R` (population_size field + Population sheet w/ guidance); CHANGELOG.

- **G. Verify** — full tabs testthat + `run_tests_v2.mjs` green; confirm unconfigured reports are byte-identical.

## Out of scope (follow-up)

- The classic (opt-in) HTML/Excel crosstab significance engine is **not** wired to FPC in this pass — only the v2 interactive report (the default). The R helper in phase C gives that path a tested function to adopt later.
- FPC under arbitrary live filters / custom banners (unknown sub-population N): intentionally reverts to standard intervals.
- **Weighted** population reports get FPC intervals + coverage-aware low-base flags but keep standard significance (the published layer carries only the unweighted base, not the Kish effective base needed to combine the design effect with FPC). Census designs are unweighted in practice. To extend: emit a per-column effective base in the data layer and feed it as the pre-FPC base.

## Verification (2026-06-26)

- Confidence module: `test_study_level.R` +24 FPC assertions → 84/0; full module 1057/0.
- Tabs: `test_data_layer_writer.R` 177/0 (population emission, reversibility, resolver); `test_config_templates.R` 34/0 (Population sheet + loader round-trip); full module 2267/0 (9 pre-existing skips).
- v2 JS gate `run_tests_v2.mjs` 83/0 incl. new `fpc.mjs` 32/0; golden parity still green ⇒ no-population reports byte-identical.

## How to use (operator)

1.  Settings → `population_size` = total invited universe (e.g. all students).
2.  Optional `Population` sheet: one row per banner column — `Group` (label as shown), `Population` (cohort size), optional `Banner` (the banner question).
3.  Regenerate the v2 report. Intervals narrow with coverage; small high-response groups stop being flagged unstable; the design note states the response rate and the non-response caveat.
