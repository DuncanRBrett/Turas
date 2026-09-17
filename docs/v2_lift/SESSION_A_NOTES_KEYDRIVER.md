# KeyDriver Session A. Implementation notes

Built 2026-09-17 on `feature/keydriver-correctness`, sixteen commits, one per
work item from `HANDOVER_KEYDRIVER_FOR_OPUS.md` section 2. UNMERGED.

Suite from the repo root, quoted from the run: 26 files, 389 tests, 1,168
passing, 0 failed, 0 errors, 2 skipped, 2 warnings. Baseline at session start,
run before the first change: 18 files, 337 tests, 940 passing, 0 failed, 4
skipped, 2 warnings. The skip count fell because two of the four were tests
that guarded themselves with a function name that does not exist.

Every fix ships with a test that was run against the code as found. Where a
test passes both ways it is a deliberate control and says so in its own
comment.

## THE BRANCH IS CONTAMINATED, read this first

Three commits on this branch are not mine and belong to the session working on
`modules/steps`: `8a497e3a`, `c20a98fd`, `d3926287`. They are on this branch
and on no other, so that session committed while this branch was checked out in
the shared worktree.

Nothing was mixed INTO a commit: every `git add` here was scoped to
`modules/keydriver`, and no commit of mine touches `modules/steps` or
`scripts/`. But merging this branch would carry that session's work with it.
Resolve before merging: that session cherry-picks its three commits onto its
own branch, then this one is rebased to drop them.

## What was fixed

| ID | What was actually wrong |
|---|---|
| C1 | Johnson's relative weights orthogonalised with V sqrt(L), the PCA rotation, not the symmetric V sqrt(L) V'. Two drivers split 50/50 whatever the data said. Measured before the fix on r12=0.5, r1y=0.6, r2y=0.2: old 50.0/50.0, correct 92.9/7.1. Live in the main path, the mixed path and every bootstrap replicate. |
| C2 | Segment comparison: unweighted on weighted studies (no weight parameter existed); every categorical driver scored a silent zero because `coefs["Region"]` is NA when the term is `RegionNorth`; only `segment_variable[1]` was read and the `segment_values` column was never read anywhere in the module; failures returned NULL under a PASS. |
| H3 | `primary_method` stamped the constant "partial_r2", naming a v10.3 engine nothing called. Engine deleted, stamp derived. `AggregationMethod` refused runs over a value no code path read. Stats pack credited "shapr package"; the module uses xgboost + shapviz. |
| H4 | The mixed path substituted squared correlations for Johnson's weights on near-singularity and labelled them `Relative_Weight`. The non-mixed path refuses on the same condition, so the same data got a refusal or a different number depending on whether a categorical driver was present. |
| H5 | Weighted dominance multiplied by sqrt(w) and fitted unweighted, claiming algebraic equivalence. True for coefficients, false for R-squared, which is what dominance decomposes. Measured: 0.825110 against a true weighted R-squared of 0.825140. The 15-driver truncation was a console line only. |
| H6 | The SHAP dummy-collapse pattern `^Gender(?=$|[^[:alnum:]_])` cannot match `GenderFemale`. The map was always NULL, so driver-level SHAP for a categorical driver never existed. Indistinguishable from the legitimate no-factors case, which is why nothing caught it. |
| H7 | `nca_analysis(d[[drv]], d[[outcome]], ...)` against a signature of `(data, x, y, ...)`. Every call errored, every driver came back "Not Necessary" under a PASS. The return extraction and the bottleneck call were independently wrong too. |
| H8 | Fourteen pre-flight checks and 574 lines of tests; nothing ever called the orchestrator. Checks 12 to 14 also read `config$enable_shap` where a loaded config stores `config$settings$enable_shap`. The GUI never sourced `lib/validation/`. |
| H11, M2 | The template dropdown offered `shapley`, `relative`, `beta`; the engine handles `shap`, `relative_weights`, `regression`, `correlation`. Three of five choices fell through to auto. `shap` also took `Shapley_Value` before `SHAP_Importance`. |
| M1 | Standardised betas divided a weighted coefficient by an unweighted SD ratio. |
| M3 | Nothing seeded but a hard-coded 42 inside SHAP. Two runs of one config gave different intervals and a different SHAP model. |
| M4 | `Point_Estimate` is the bootstrap mean, not the headline figure, and a weighted run resamples PPS then fits unweighted. Neither was written anywhere. |
| M5 | The faceted segment chart drew every panel's quadrant lines from the first segment's thresholds. |
| M6 | An all-categorical mixed model died inside `cor()` with a bare R error. |
| M14 | `isTRUE(as.logical("Yes"))` is FALSE, so `enable_bootstrap = Yes` silently disabled the bootstrap. |
| A11 | Two tests guarded on `build_term_map`; the function is `build_term_mapping`, so both had never run. Recovery tests added against a known truth. |

## Deviations from the handover, and why

- **M14 went wider than asked.** The handover named five `enable_` gates. The
  same pattern was on six more settings, including `enable_html_report`,
  `normalize_axes` and `shade_quadrants`. All eleven are fixed. Leaving six
  known-broken settings because they were not on the list is not defensible.
- **M4's Shapley stamp is prose, not rows.** The handover says stamp "no
  interval available" for Shapley. Adding Shapley rows of NA to the interval
  table broke eighteen existing assertions and, more to the point, a row of NAs
  in a CI table reads as missing data rather than as a method without an
  interval. It is in the policy note instead.
- **M1 took the correct figure, not the disclosed hybrid.** The handover
  offered a hybrid with a note as the minimum.
- **C2 keeps `results$segment_comparison` pointing at the first variable.** The
  HTML report reads that slot and the report is Session B's. All variables are
  in `results$segment_comparisons` for Session B to widen onto.
- **H11 keeps the fallback when a requested source is absent.** An unrecognised
  VALUE refuses, because that is a config error. A missing COLUMN records what
  was used instead, because that is a data-availability problem and refusing
  would block a run over something the analyst cannot fix in the config.

## Two things found that the review did not have

- **H7 is worse than SUSPECTED.** The review could not execute it because it
  assumed the NCA package was absent. It is installed. Three independent faults,
  not one: the call signature, the return extraction, and `bottleneck.y` passed
  to `nca_output()`, which has no such parameter.
- **`segment_values` was never read anywhere in the module.** The review found
  that only the first Segments row was used. The deeper fault is that the
  column which groups levels into a named segment had no consumer at all: the
  sheet's schema was validated and its contents ignored.

## What was executed, and what was not

Executed: the full suite before and after every change; each new test against
the code as found; NCA, xgboost, shapviz, glmnet and domir end to end, all five
being installed in this renv contrary to the handover's assumption; domir's
source read directly to work out why a weight vector is invisible to `lm()`
inside it.

NOT executed: any end-to-end pipeline run against a real config, and the GUI.
Duncan regenerates through `launch_turas()`; a session does not. The GUI change
is a source-list line, verified by reading.

## Owed next

1. Resolve the branch contamination above.
2. Duncan's `launch_turas()` eyeball, then the merge.
3. The Fable independent pre-merge review. Do not share these notes with it
   until its own section 4 is written.
4. Sessions B and C.
