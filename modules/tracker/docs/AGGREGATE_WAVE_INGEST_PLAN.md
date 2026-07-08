# Aggregate-Wave Ingest — Design & Build Plan

**Status:** Design approved (direction), pre-build. Step 1 artifact.
**Date:** 2026-07-07
**Author:** Claude (Opus 4.8) with Duncan Brett
**Applies to:** tracker module — new capability, reused across CCPB CSAT, CCS, SACAP student, and any long-running tracker.

---

## 1. The problem this solves

Long-running trackers accumulate more history than we can economically load as
raw microdata. For CCPB CSAT we have run since 2011 (16 years by 2026) but only
hold respondent-level data in Turas for the recent waves. The earlier years
survive only as **published aggregates** in a spreadsheet — a percentage, a mean,
or an NPS net score per metric per year, with no respondent rows behind them.

The tracker today can only ingest a wave as a respondent-level data file. So there
is no way to show a continuous 2012→2026 trend that stitches historical aggregates
onto recent microdata. Duncan confirmed the same gap exists on CCS and SACAP
student — hence a reusable capability rather than a per-study hack.

## 2. Principles (non-negotiable)

- **No fabricated respondents, no fabricated significance.** We feed real
  published aggregates into the existing summary-statistic tests. Where the
  source lacks what a test needs (a mean's dispersion, an NPS split), the output
  says *no test* — it never manufactures an arrow.
- **Reuse the engine.** Historical aggregates flow into the *same* significance
  tests and the *same* outputs as microdata waves. No parallel stats path.
- **Faithful reshape.** The values table reproduces the source numbers exactly
  (verified by round-trip); cleaning actions are logged, never silent.
- **Total-column history.** Historical waves are the headline figure per metric.
  Demographic banner breakouts remain a microdata-only capability (2025 onward).

## 3. How the tracker runs today (verified seam)

`run_tracker()` (run_tracker.R) executes 8 steps. The relevant data path:

1. `load_tracking_config()` → config: **Waves**, Settings, Banner, TrackedQuestions.
2. `load_question_mapping()` + `build_question_map_index()` → question map (codes
   across waves + TrackingSpecs, e.g. `mean`, `top2_box`, `range:9-10`, `nps_score`).
3. `load_all_waves()` → `wave_data`: a **named list of respondent-level data
   frames**, one per wave.
4. `calculate_all_trends()` → `dispatch_single_trend()` routes each tracked
   question by type to a calculator:
   - `calculate_rating_trend_enhanced()` (mean / boxes)
   - `calculate_nps_trend()`
   - `calculate_single_choice_trend_enhanced()` (proportions)
   - `calculate_multi_mention_trend()`, `calculate_composite_trend_enhanced()`
   - Each **loops the waves**: `wave_df <- wave_data[[wave_id]]` →
     `q_data <- extract_question_data(...)` →
     `result <- calculate_proportions()/calculate_weighted_mean()/calculate_nps_score()`
     → stored as `wave_results[[wave_id]]`.
5. `calculate_enhanced_changes_and_significance()` compares those per-wave results
   using **summary-statistic tests** in statistical_core.R:
   - `z_test_for_proportions(p1, n1, p2, n2)` — needs only proportion + base.
   - `t_test_for_means(mean1, sd1, n1, mean2, sd2, n2)` — needs mean + SD + base.
6. Outputs (detailed / wave_history / dashboard / sig_matrix / tracking_crosstab /
   HTML) + optional stats pack all consume `trend_results`.

**The seam is `wave_results[[wave_id]]`** — the per-wave metric result object
(value, base/eff_n, dispersion). If we can produce that object for an aggregate
wave from a stored table instead of from microdata, everything downstream is
unchanged, because the sig tests are already summary-based.

## 4. Design

### 4.1 Config: Waves sheet gains a type

Today the Waves sheet requires `WaveID, WaveName, DataFile, FieldworkStart,
FieldworkEnd` for every wave (tracker_config_loader.R). Add:

- `WaveType` — `data` (default; behaves exactly as now) or `aggregate`.
- `AggregateFile` — path to the values table (used when `WaveType = aggregate`).
- For `aggregate` waves, `DataFile` is not required; fieldwork dates may be just
  the year (or left blank). The loader branches on `WaveType`.

Everything else (banner optional, ≥2 waves, Settings, TrackedQuestions) is
unchanged.

### 4.2 The values table (one row per number)

A single tidy table carries all historical aggregates. Canonical (long) schema:

| column | meaning |
|--------|---------|
| `metric_id` | stable key = the tracker **question code** used in the question mapping. Ties an aggregate value to the same metric computed from 2025/26 microdata. |
| `wave` (or `year`) | wave identifier, e.g. `2012` … `2024`. |
| `metric_type` | `mean` \| `proportion` \| `nps` (extensible: `top_box`, `range`, …). |
| `value` | the published figure, exactly as reported. `%` stored as the percentage number (e.g. `58` = 58%); `mean` on its native scale; `nps` net (−100..100). |
| `base` | effective base n for that metric that wave. Blank = unknown. |
| `sd` | dispersion for `mean` metrics. Blank = not recorded. |

Descriptive columns (`section`, `who_asked`, `question`) ride along for humans and
are ignored by the engine.

`metric_id` **is** the question code: during question mapping Duncan lines each
historical `metric_id` up with the 2025/26 data column + TrackingSpec, so the
engine treats them as one continuous metric.

### 4.3 Producing the per-wave result (the branch)

In each type calculator's wave loop, branch on wave type:

- `WaveType = data` → current behaviour (compute from `wave_df` columns).
- `WaveType = aggregate` → look up `(metric_id, wave)` in the values store and
  build the result object directly: `value`, `base`, `sd`.

Result object shape stays identical to the microdata path, so
`calculate_enhanced_changes_and_significance()` and all outputs are untouched.

### 4.4 Significance, per type — honest by construction

| metric_type | historical (aggregate) | recent (microdata, 2025+) |
|-------------|------------------------|---------------------------|
| `proportion` | `z_test_for_proportions` from `value%` + `base`. **Exact** if base supplied; **no test** if base blank. | full |
| `mean` | `t_test_for_means` needs SD. SD blank → **no test** (trend line only). SD present → exact. | full (SD from data) |
| `nps` | net-only lacks the promoter/detractor split that drives variance → **no test**; point estimate exact. | full |

The reconstruction-of-fake-respondents alternative was rejected precisely because
a synthetic rating column implies *some* SD, which would produce a significance
result that is an artifact of our construction. Storing `sd = blank` and returning
*no test* is the honest equivalent.

### 4.5 Integration surface (the one non-trivial bit)

Three places assume every wave has a real data frame and must learn to read an
aggregate wave's base from the values store instead of counting rows:

1. `get_wave_summary()` — per-wave n display.
2. `validate_wave_data()` — post-load validation.
3. Stats-pack diagnostics in `generate_tracker_stats_pack()` (run_tracker.R) —
   uses `nrow(wd)` and `wd$weight_var` for eff-n / weight CV.

These get an `aggregate`-wave path (base from store; weight diagnostics N/A).
This is where review attention concentrates.

## 5. Build stages (each ends in a fail-able check)

1. **Design + reshape (this artifact).** Values-table schema fixed; CCPB history
   reshaped into it; round-trip proves it reproduces the source exactly. ✅
2. **Config + values loader.** Parse `WaveType`/`AggregateFile`; load + validate
   the values table (types, duplicate keys, base/sd sanity). Unit tests. ✅
   *Done:* `resolve_wave_types()` in tracker_config_loader.R (back-compat: absent
   `WaveType` ⇒ all `data`); new `lib/aggregate_wave_loader.R`
   (`load_aggregate_values()` + `get_aggregate_metric()`); sourced in run_tracker.R;
   `tests/testthat/test_aggregate_wave_ingest.R` (41 assertions). Full tracker
   suite 1935/0. Real 464-row CCPB file loads to 60 metrics × 14 waves.
3. **Engine branch + honest sig.** Aggregate waves produce result objects; sig
   routes per §4.4. **Golden test:** aggregate-only run reproduces the published
   2012–2024 figures to the decimal, and unknown-SD/NPS metrics show *no test*.
4. **Integration fixes.** Teach the three spots in §4.5 about aggregate bases;
   full tracker regression suite stays green.
5. **Live CCPB wire-up.** 2025 as a real wave beside the history; question mapping
   aligns codes; run 2012→2025 on the total column; Duncan regenerates via
   `launch_turas` and eyeballs. 2026 slots in when fieldwork lands.

## 6. Known limits

- Historical **means and NPS** cannot carry significance — dispersion / the NPS
  split were never recorded. Trend lines only; full sig from 2025.
- History is **total column only** (no demographic banners for aggregate waves).
- The panel is **ragged** — most metrics exist for a subset of years. The question
  mapping handles this natively (a blank = the metric simply doesn't exist that
  wave); a metric's line starts in its first populated year.

## 7. CCPB specifics (from the step-1 reshape)

Source: `…/CCPB/CSAT/W2026/02 Data/CCPB Question History.xlsx` (Sheet1, 76×18).

- **14 historical waves, 2011→2024.** The sheet itself is 2012→2024; Duncan
  confirmed a 2011 study that held **only the overall rating (8.8)**, added as a
  single sourced point (2011 is otherwise empty).
- **60 trackable metrics, 464 data points:** 34 proportion, 25 mean, 1 NPS.
  Round-trip verified: the long table rebuilds every original *sheet* number
  exactly; the two non-sheet points (2011 overall; MyPenbev) are carried with a
  `source` note, not passed off as sheet data.
- **Ratings are a 1–10 scale** (confirmed). Proportions stored 0–100. NPS net.
- **"How would you rate MyPenbev" (8.42, 2024)** had a blank Type in the sheet;
  Duncan confirmed it is a rating → included as `mean` (`metric_id` `Q12b`; 2025
  value 7.6 will come from the live wave).
- **14 rows excluded** as non-trackable: 10 Distribution + 4 Text.
- **14 cells treated as missing (logged):** 12 × `TBD` (Fountain 2024 not yet
  entered → those metrics' latest point is 2023); 2 × an inline `"1 out of 3
  =33%"` note.
- **Per-wave aggregate→microdata swap is supported:** any aggregate wave can later
  be pointed at a real data file (flip `WaveType` to `data`) with no rework —
  Duncan flagged he may import an actual study for one wave in future.
- **Open items for Duncan** (step 5): per-metric **bases** for the frequencies
  wanted for sig (many are subgroup bases — "Requested signage", "Has cooler",
  "Spaza" — nowhere near the ~750 total, so a flat 750 would be wrong); the
  question **mapping** of each `metric_id` onto 2025/26 codes + TrackingSpec.
