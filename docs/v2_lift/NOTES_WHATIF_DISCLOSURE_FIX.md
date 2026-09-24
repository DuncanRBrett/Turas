# Notes: What if client-safe disclosure fix, 24 Sep 2026

Branch `fix/whatif-disclosure` from local main 374ae172. Committed on the branch only: not merged, not pushed. Spec: `BRIEF_WHATIF_DISCLOSURE_FIX.md`; findings: `REVIEW_WHATIF_DISCLOSURE_2026_09_24.md`, both in this folder.

Every number below was produced by a command or a test run in this session. Nothing here is estimated.

## What changed

One exact recoverability engine, used three times.

`disclosure_small_recoverable(atom_n, A, k)` in `modules/shared/lib/disclosure_groups.R`. Atoms with identical rows of A are merged into classes first, since any set in the column space of A is constant across such atoms. With N a basis of the left null space of A (from a complete QR), a union of small classes is recoverable when its rows of N sum to zero: singles are zero rows, pairs cancel, larger unions are found by meeting in the middle on hashed partial sums (projected to four random directions, every hit verified against the full rows). Only minimal sets are returned, each with its coefficient vector over the published columns so the caller can hide the smallest group involved. The search is counted by dynamic programming before it runs; past `max_work` (500,000 subsets a side) it refuses with `CALC_DISCLOSURE_RECOVERABLE`. `disclosure_atoms()` and `disclosure_atom_sets()` build the inputs; `disclosure_candidates()` and `disclosure_recoverable()` are gone.

1. Membership. `disclosure_publish_groups()` runs the engine each round on the published groups and hides the smallest group in each recovering combination. `audit$recoverable_failures` is the engine's count at exit (0 unless it refused); `audit$exact` is TRUE; `candidates_checked` became `small_atoms`. `disclosure_audit_groups()` runs the same engine and describes each recoverable set by its atoms.

2. Need counts and 3. effects. `whatif_safe_suppression()` in `modules/whatif/R/11_island.R`, computed once in `run_whatif_impl` from the unweighted model's need masks and deltas, applied to both weighting versions. Need: atoms refined by the need mask; columns are every group's membership plus the shown groups' members who need the fix; the per-group rule (count or complement under k) is the starting point; then the smallest group in each recovering combination loses its count until nothing under k is recoverable. Effects: atoms refined by "changed by this move" and restricted to the changed respondents; columns are the shown groups' movers only (membership counts are a different quantity and are not columns here); a group with 1 to k-1 movers is hidden first, then the same loop. Bundles use the union of their moves. Identical mover masks share one decision (floor equals need, up1 equals up2, slip1 equals slip2). `whatif_safe_block()` writes null for est, lo, hi and the bundle triple where an effect is withheld.

4. Whole-sample counts. The safe block now carries `safe$meta` with `n_by_outcome` (null unless every category clears k) and `warnings` rebuilt without counts by `whatif_safe_warnings()` (the outcome warning becomes "Few students are Detractor. ...", the don't-know warning "More than a tenth of the answers on Admin were ...", the refit warning "Some bootstrap refits did not converge."). `whatif_safe_model()` drops `levers[].missing` and takes `notes_safe`, which omits the don't-know sentence. `.read_whatif_contribution` in `modules/tabs/lib/run_crosstabs.R` replaces those two meta fields from `safe$meta` in the client-safe cut and refuses a file without `safe$meta` as incomplete.

5. Release audit, `release_audit_whatif()`. Check 4 needs `recoverable_failures` 0, `differencing_failures` 0, `exact`, `need_checked` and `effects_checked`. New: a shipped audit that counts small cells is a violation; need counts across definition-nested pairs (count and complement) that differ by 1 to k-1; `n_by_outcome` under k; any `levers[].missing`; any whole number 1 to k-1 in warnings or notes (percentages and decimals stripped first). The length check excludes `model$fits`, `model$ctx_offset`, `profile$fits`, `safe$profile$fits`, `safe$groups` and any unnamed list exactly as long as the fits.

6. Build a ... `whatif_safe_profile()` keeps only Structure rules whose two levels are still offered after pooling. The shipped `safe$audit` is `k, line_failures, differencing_failures, recoverable_failures, exact, need_checked, effects_checked`; the counts of what was hidden stay in the run (`res$publish$audit`, `res$suppress`) for the analyst.

Report tab, `27w_whatif.js`: a withheld effect renders "not shown" in the effort table (per 100 reached becomes n/a rather than 0, which `isNaN(null)` used to allow), a scenario with a withheld part says so instead of silently dropping it, a bundle with a withheld part shows "not shown" for the exact figure and for the sum of parts, and the Privacy paragraph needs `exact`, `need_checked` and `effects_checked` as well as the two failure counts.

## Tests

Each counterexample was written as a failing test first and its failure kept:

- Counterexample A (seed 1035): brute force found 1 recoverable set; B (gen2 seed 5020): 9. The old audit passed both group sets. `test_disclosure_groups.R`.
- Need (review proj1, n = 300, seed 11, one DK, two detractors): 35 need counts hidden by the per-group rule, 27 rebuilt exactly from published ones, 7 shown nested pairs leaking. Effects: 1,064 shown, 45 resting on 1 to 4 movers, 9 nested pairs differing by that few. `test_run_whatif.R`.
- Whole-sample counts: `n_by_outcome` 2, `missing` 1, the outcome warning and the don't-know note all reached the safe cut.
- Small study (n = 100, seed 7, 100 refits, Masters cut to 3): the release audit failed on the refit lists.

After the fix, all of those are 0 or absent, and:

- Property test: 250 review studies (150 gen, 100 gen2), no set of 1 to 4 recoverable. The independent brute force (least squares over explicit candidates: every atom, every three-way cell, every union of two small atoms, unions of three and four when there are at most 150,000 of them) covered unions of up to four small atoms in 203 of 250 studies and up to three or two in the rest, because the largest studies have up to 116 small atoms. The test prints the coverage. Before the fix this brute force found 98 of 250 studies leaking (160 sets); the review's weaker one found 23 of 150 and 22 of 100.
- Engine refusal past the cap, and a leaking island failing the release audit, both tested.

Suite counts, all from runs in this session (before the fix, then after):

| Suite | Before | After |
|---|---|---|
| whatif (`modules/whatif/tests/testthat`) | 304 pass | 1093 pass |
| disclosure (`test_disclosure_groups.R`) | 305 pass | 1324 pass |
| release audit (`test_release_audit.R`) | 71 pass | 87 pass |
| tabs whatif (`test_whatif_island.R`) | 72 pass | 91 pass |
| node What if gate (`whatif_view_tests.mjs`) | 15 pass | 17 pass |
| shared, full (`modules/shared/tests/testthat`) | 2424 pass + 1 known failure (per the memory note) | 2669 pass, 1 failure, 4 skips |
| tabs, full (`modules/tabs/tests/testthat`) | 6445 pass (per the memory note) | 6463 pass, 0 failures, 1 skip |

The shared failure is the known one: "the writers of committed workbooks do not call openxlsx::saveWorkbook directly", naming `examples/segment/create_segment_example.R:145`. Run alone, that test file fails on that expectation only. The disclosure and release audit counts above are 1325 and 88 after the two late fixes below.

The disclosure test file now takes about 40 s (was 2 s). Measured by test: 21.0 s for the 250-study property test, 9.8 s for the pre-existing "a chain of subtractions across a crossing" test (60 studies at k = 10) and 8.2 s for the pre-existing 150-study fuzz at k = 10, which now run the exact engine. The engine alone on the 250 k = 5 studies took 7.2 s.

## What the suppression costs on the synthetic projects

Groups: none. The exact engine hides no group the old check did not on any of the four projects (38, 38, 27 and 21 groups, unchanged). Need counts and effects, per project (`hidden of shown-able`, then the split between the starting rule and the recoverability loop):

| Project | Need counts | Effects (incl. bundles) |
|---|---|---|
| default test project, n = 500, seed 11 | 48 of 228 (15 + 33) | 47 of 1,064 (14 + 33) |
| review proj1, n = 300, seed 11, DK 1, detractors 2 | 75 of 228 (35 + 40) | 118 of 1,064 (45 + 73) |
| tabs fixture, n = 160, seed 21 | 60 of 162 (42 + 18) | 103 of 756 (71 + 32) |
| review proj2, n = 100, seed 7, Masters 3 | 59 of 126 (44 + 15) | 85 of 588 (59 + 26) |

Script: the session scratchpad's `cost_counts.R`, not kept in the repo. The counts are also printed by `run_whatif` ("client-safe: N need counts and M effects hidden ...") and returned in `res$suppress`.

## For Duncan

- Pooling in Build a ... is unchanged, as instructed. A level pooled because it has fewer than k respondents is absent from the shipped level lists, so a reader who knows the population learns that level had under k. That is a bound, not a count. Whether the bound is acceptable, or pooling should follow declared merges in the config only, is your decision. Nothing in this branch decides it.
- The SACAP 2025 What if config is not on this machine (searched `~/Library/CloudStorage/OneDrive-Personal/DB Files`, including TurasProjects/SACAP, for any WhatIf workbook). No real-data run, so the "282 groups before" figure has no after.
- This needs an independent re-review before anything client-safe goes to SACAP. The brute force in the property test shares the atom idea with the engine, even though it tests explicit candidates by least squares rather than searching a null space.

## Two late fixes from the advisor pass

- The audit's "count from 1 to k-1" check matched every digit run, so a lever labelled "Q3 Admin" or an outcome level "0-6" would have refused a clean build. It now matches a whole number standing on its own (start or a space before it; a space, full stop, comma, semicolon, colon or bracket after it). Tested both ways.
- The engine drew its four hashing directions from the global random stream, advancing it for every caller. It now draws from a fixed seed and puts the caller's stream back, so it is a pure function; a test checks the stream is untouched.

## What Duncan must do himself

- Every What if contribution file written before this fix, including the SACAP one sent on 24 Sep, lacks `safe$meta`, so the tabs reader will now refuse it as incomplete and build the report without the tab. Run the What if module again on each study before regenerating a report.
- Regenerate a client-safe report through `launch_turas()` and eyeball the What if tab: "not shown" cells in the effort table, a scenario with a withheld part, the bundle rows, and the Privacy paragraph.

## Deviations and things not done

- The brief's brute force ("every union of up to k-1 small atoms") is infeasible at the review's study sizes (up to 116 small atoms), so it is budgeted and reports its coverage.
- The reader replaces exactly two meta fields (`n_by_outcome`, `warnings`) from `safe$meta` rather than looping over whatever keys are present, so an absent key means null.
- The shipped audit keeps `line_failures` (a zero is not disclosive) and adds `exact`, `need_checked`, `effects_checked`. The whatif test that checked `line_failures == 0` still passes.
- The Excel Privacy sheet is unchanged; the hidden need and effect counts are printed and returned instead.
- styler is not installed here and was not run. No browser eyeball of the tab: the node gate renders the fixture headlessly.
- Weighted variant: the suppression is decided on counts and applied to both versions, so the weighted est for a withheld cell is null too. Not tested against a weighted attack beyond the identity check between versions.
