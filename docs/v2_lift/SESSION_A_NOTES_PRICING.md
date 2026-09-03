# Pricing Session A: implementation notes

Branch: `feature/pricing-v2-lift`, off main at `3f85abb3`, in the worktree
`/Users/duncan/Dev/Turas-pricing-v2`. Spec: `HANDOVER_PRICING_V2_FOR_OPUS.md`
section 3, which keeps the July handover's A1 to A9 work orders. Findings in
`PRICING_PRODUCTION_REVIEW_2026-07-11.md`. Written 3 Sep 2026 by the Fable
session that also refreshed the handover. **Not merged, not pushed.**

Baseline reproduced before any change: pricing suite 0 fail / 0 skip /
63 warnings, the July figure. The shipped template, saved as a config, crashed
in validation with "argument is of length zero" (H1) on the first headless run
of the Karoo example.

## What landed, in order

| Item | State |
|---|---|
| A0 Karoo example | `examples/pricing/create_pricing_example.R`, data + four configs, README; `test_karoo_example.R` runs all four through `run_pricing_analysis()` and asserts the truth bands |
| Headless entry point | `00_main.R` now sources its siblings and remembers its own directory, so `source("modules/pricing/R/00_main.R")` is enough (it was GUI-only) |
| A1 H1 + H2 | Name maps on the VW and GG loaders; one `.pricing_parse_list()` for every list (commas or semicolons); template text aligned; template regenerated |
| A2 C1 | `fit_vw_psm()`: one routine that runs `psm_analysis_weighted()` on a `survey::svydesign` when a weight is configured, else `psm_analysis()`; refusal `MODEL_VW_WEIGHTED_FAILED`, never a fallback |
| A3 C3 + H3 | `validate` wired to the behaviour (`flag_only` keeps intransitives, default `drop`); bootstrap uses the same routine, flag and weights; `estimate` column is the headline point, bootstrap mean in its own column; `n_analysed` from psm's own count; strict ordering rule aligned with psm's |
| A4 C2 | Per-rung bases compared; `DATA_GG_UNEQUAL_BASES` refusal naming the counts; `GG_Stop_Early_Imputation = NO_AFTER_STOP` imputes No above the first No, stamped in diagnostics and the stats pack |
| A5 H4 + H5 + H6 | Monadic weights normalised to mean 1, grossing weights refuse, p-value caveat; declared-binary columns validated on both engines (`DATA_GG_NOT_BINARY`, `DATA_MONADIC_INTENT_NOT_BINARY`), `Binary_Coding = ONE_TWO` on the GaborGranger and Monadic sheets; `auto` refuses; weighted cell means with `weighted_n`. The monadic half was missed in the first commit and landed in the follow-up. |
| A6 H7 + H8 + M2 | Stats pack "Effective N (Kish)" from `modules/shared/lib/effective_n.R`, "Valid N" separate; `Generate_Stats_Pack` read from the flat config, GUI checkbox authoritative; `monotonicity_violations` returned so the Excel block renders |
| A7 M1 + M14 | PAVA (`smooth_isotonic`) wired to `Smoothing_Method`, default isotonic; raw curve kept as `purchase_intent_raw`; GG bootstrap vectorised, smooths inside each replicate, same resampling policy as VW (equal-probability resampling carrying weights) |
| A8 M4, M6 to M13 | Unknown-name warning, duplicate refusal, `PRICING_RETIRED_SETTINGS` (interpolation and outlier settings retired by name); divider regex; `Min_Sample` enforced; `PI_Scale` wired to psm; template example rows titled `[Example]` and filtered; dead Phase-3 output blocks deleted from `06_output.R`; GUI captures console output through a sink so a crash keeps its context; docs and sample config corrected |
| A9 tests | `test_config_honesty.R` (H1 round trip, separators, duplicates, retired, unknown, dividers, defaults, Min_Sample, M2), `test_engine_honesty.R` (weighted VW, two goldens, refusal-not-fallback, CI coherence, flag_only vs drop, unequal bases, imputation, coding, PAVA, band brackets curve, monadic weights), `test_karoo_example.R` (end to end, fails on any refusal or partial) |

## Findings not in the review

1. **Ties.** pricesensitivitymeter's `validate` treats a tie between adjacent
   answers as invalid; the module's own check allowed ties, so under `drop`
   twelve Karoo respondents passed the module and were then set aside by psm.
   `check_vw_monotonicity()` now uses the strict rule. Numbers under `drop`
   move slightly on any data with ties (they now match what psm analysed).
2. **`validate = FALSE` still counts.** psm reports `invalid_cases` either
   way and keeps them in the curves when validation is off. The analysed base
   for `flag_only` is therefore the whole complete-case sample.
3. **The monadic step re-sourced its file at run time** through a directory
   lookup that only works from the GUI; from a test or a script it refused
   `BUG_MONADIC_NOT_FOUND`. The module directory is now remembered at source
   time.
4. **Weighted glm noise.** Every weighted monadic fit printed "non-integer
   #successes" fifty times over. Muted for that message only.
5. **The stats pack declared a weighted run "unweighted".** The shared
   writer keys its Declaration on `data_used$weight_variable`, which pricing
   never passed. Now passed.
6. **Segment insights printed `$`** whatever the currency. Threaded through.
7. **The advisor review after the first commit caught four things**, fixed in
   the follow-up commit: the monadic engine still coded any positive number
   as a buy (H5 was only half done), three new export settings had no
   consumer (the retired-settings defect in a new coat, now a refusal until
   Session B), the GUI stats-pack checkbox defaulted to off once it became
   authoritative, and the monadic bootstrap counted the weights twice.
8. **A Python slip truncated the template generator mid-session** (a write
   that read the file after opening it for writing). Restored from git and
   re-patched; the file parses and regenerates the template. Noted so a
   reviewer diffing the generator sees why its history is two edits.

## Deviations from the work order

- **A4, long format.** `NO_AFTER_STOP` on long-format data is accepted when
  prices are numeric (ascending price is the derivable order) and refuses
  otherwise (`CFG_GG_IMPUTATION_ORDER`).
- **A5, grossing weights.** Refused when the mean raw weight exceeds 5;
  below that the weights are normalised to mean 1 and used. The handover
  said "refuse grossing-scale"; 5 is the line drawn.
- **A7, resampling policy.** One policy for all three bootstraps:
  respondents resampled with equal probability, each carrying its weight,
  estimated by the headline's routine. The old VW bootstrap resampled with
  weighted probabilities and an unweighted estimator; the old monadic
  bootstrap resampled with weighted probabilities and then fitted with the
  weights, counting them twice. Recorded as `attr(ci, "policy")` for VW and
  GG and in the stats pack.
- **A8, M9.** `PI_Scale` was wired rather than removed (psm has the
  parameter). `Interpolation_Method` retired.
- **A8, M13.** The 07/08/09 tier is untouched and still not wired; only the
  output blocks that read results the pipeline never produced were deleted.
  README marks the three files as direct API only.
- **Em dashes.** Every string this session touched is clean. The shared stats
  pack writer (`modules/shared/lib/stats_pack_writer.R`) still writes
  thirteen of its own into every module's Declaration and Warnings sheets.
  Shared code, every module's suite in the room: not changed here, logged for
  Duncan.
- **Handover ruling R1** (monotonicity default `drop`) was taken as
  recommended, since Duncan had not ruled at the start of the session.
- **Tabs export settings.** `Generate_Tabs_Export`, `Tabs_Question_Code` and
  `Export_WTP` are in the template for Session B. Until the exporter exists a
  `Y` refuses (`FEATURE_TABS_EXPORT_PENDING`) rather than passing in silence,
  which would be the outlier-settings defect again.
- **GUI stats pack checkbox** now defaults to on. With the H8 fix the
  checkbox is authoritative, and stats packs are contractual (`04c3c3c0`), so
  a default of off would have dropped them from every GUI run.

## What was executed

- The Karoo example built and run headless four ways (both methods weighted,
  monadic, stop-early refusing, stop-early imputed), plus an unweighted
  variant in the test, all through `run_pricing_analysis()`.
- `psm_analysis_weighted()` executed on the Karoo data and in the tests,
  including the weight-of-2-equals-duplication golden.
- The pricing suite from the repo root: **997 pass / 0 fail / 0 skip / 0 error / 14 warnings** (baseline 63 warnings; one of the 14 is psm's own note that flag_only kept inconsistent respondents, which is the point of that test).

## Not verified

- The GUI, per the standing rule (Duncan runs `launch_turas()`).
- The Excel deliverable and the classic HTML report were not opened as a
  reader would; the classic report is scheduled for retirement in Session B.
- The tabs suite was not run: nothing in `modules/tabs` or `modules/shared`
  changed.
