# Weighting W1–W8 — Independent Review Findings

> **Status, added the same day:** Duncan asked for the recommendations to be
> implemented. All of them are, on branch `fix/weighting-review-followups` — see
> §7 at the foot of this document for what changed and how each was verified.
> The findings below are left as written, so the record of what was found stays
> separate from the record of what was done about it.

**Date:** 2026-08-09. Reviewing session; did not write the code under review.
**Scope:** the seven commits `684157ea`..`d2ce9699`, merged to local main at `82642f2b` (27 files, +2522/−137), judged against `WEIGHTING_PRODUCTION_REVIEW_2026-07-12.md` and `HANDOVER_WEIGHTING_FOR_OPUS.md`.
**Verification:** everything below marked "verified" was read or executed in this session. Anything I did not check myself is labelled unverified next to the claim. I did not run the pipeline against any project folder and wrote nothing into OneDrive.

---

## 1. Answers to the four questions

**Q1 — Are the new refusals calibrated correctly?** Mostly, with two miscalibrations. A cell target of exactly `0` now refuses (F4), which blocks a sparse census cell that rounds to 0.0%; and any one TRS refusal aborts an entire multi-weight config (F3), so one bad category in the fourth weight kills the other three. The empty-target-cell refusal itself is right. Its opt-out is the part that is broken (F2).

**Q2 — Does anything break a workflow that should work?** Nothing refuses that should pass, on the evidence I could gather. The design-weight normalisation (W5, locked decision §0.2) does change numbers on every existing design config, and F1 means the module's own report then contradicts the lookup file it just wrote. The weight-name collision refusal (W6) stops the "re-run weighting on a file that already carries last run's weight column" pattern; the message is clear and the fix is a rename, so I would leave it.

**Q3 — What should have been tested and was not?** Four gaps, all in §4 below. The largest is that there is still no golden-file regression against a known-good prior output, which is exactly the gap §5 of the July review named and W8 did not close — W8 added hand-checkable arithmetic, which is a different (and worthwhile) thing.

**Q4 — Do the weights still reach tabs correctly?** Yes, and W4's central assumption holds up better than the brief feared. I traced the failure path: a weight column named in a tabs config but absent from the data is logged as an `Error` by `check_weight_column_exists` (`modules/tabs/lib/validation/weight_validators.R:95`), and `modules/tabs/lib/validation.R:1531` refuses the run on any Error. So an omitted weight stops tabs rather than silently producing an unweighted report. There is a second-line silent fallback to `rep(1, nrow(data))` at `modules/tabs/lib/weighting.R:262` which would produce an unweighted report if validation were ever bypassed; it is not reachable on the normal path.

Against the live Electrum case (read-only inspection of `Weight_Config.xlsx` and `VAS_2024_weighting_data.csv`): rim only, `apply_trimming = N`, no Advanced_Settings, 1101 rows, `SbjNum` with 0 duplicates and 0 blanks, all four rim variables with 0 missing values and no category on either side that the other lacks, target sums 100.0001 / 100.0000 / 99.9999 / 100.0000. Nothing in W1–W8 fires on it, and none of W1–W8 touches rim weight *values*, so `VAS_2024_weighted.csv` should reproduce number for number. That regen is the confirmation step and it is yours to run.

---

## 2. Findings

### F1 — The design-weight summary table reports the un-normalised weights (MEDIUM)

`modules/weighting/lib/design_weights.R:277-307`.

W5 normalises the weight vector to sum = n at line 281, but `stratum_summary` is built afterwards at lines 288–307 from `population_sizes[cat] / sample_n` — the raw population-scale figure. The two never meet.

Verified by running the config path on the test fixture:

```
sum(weights) = 200   n = 200   weight_scale = sample
stratum_summary weight column:  329.6703   645.1613   638.2979
actual distinct weights:          0.659341   1.276596   1.290323
```

What breaks: `print_design_summary` (console), the Excel diagnostics (`lib/output.R:344`, `:605`) and the HTML report (`lib/html_report/02_table_builder.R:183`) all print a weight per stratum that is 500× the number actually written into the lookup file. An analyst reconciling the report against the lookup file will conclude one of them is wrong, and cannot tell which. The weights themselves are correct.

Fix cost: small. Either scale `stratum_summary$weight` by the same factor when `grossing` is FALSE, or carry both columns (`weight_population`, `weight_applied`) and label them. Add an assertion that the summary's weights match the distinct values in the vector.

### F2 — The `allow_unmatched` disclosure omits the number that matters, and nothing renormalises (MEDIUM-HIGH)

`modules/weighting/lib/cell_weights.R:271, 311-321`; same structure at `modules/weighting/lib/design_weights.R:125, 165-175`.

`n_unweighted` counts only respondents (`n_unmatched + n_na_rows`). Empty target cells are not respondents, so when the only problem is an empty cell the console block opens by saying nobody is affected — then lists the empty cell underneath it. Verified:

```
n = 75, one empty target cell (25% of the population)
console: "allow_unmatched = YES, so 0 of 75 respondents are being left with no weight"
sum(weights) = 56.25    (75% of n)
```

Every respondent has a weight; the weighted base is 56.25 against a sample of 75. Nothing renormalises the surviving cells, and there is no sum-vs-n check anywhere in `validate_calculated_weights` (`lib/validation.R:246-350`) or `diagnose_weights` — I grepped both. So the run reports GOOD quality on a weight that has quietly removed a quarter of the base, and the disclosure block that exists to prevent exactly this leads with "0".

This matters more than F1 because it is the *opt-in* path — the one an analyst reaches for after being refused, when they have decided to proceed anyway. It is also H2 from the July review reappearing on the other side of the new refusal: refusing by default was the fix, but the escape hatch still produces the original defect and now says less about it than the old warning did.

Note the test at `tests/testthat/test_cell_weights.R:154` asserts `expect_equal(result$n_unweighted, 0)` for precisely this fixture, with a comment explaining that the loss is on the population side. The author saw the distinction and encoded it, but did not follow it into the console text.

Fix cost: small-to-moderate. Three parts: (a) state the weighted base against n in the disclosure whenever empty cells exist; (b) add a weighted-sum-vs-n check to `validate_calculated_weights` that downgrades quality when they diverge by more than a threshold; (c) decide whether the opt-in should renormalise the surviving cells to restore sum = n — that is a policy call, see §3.

### F3 — One refusal aborts the whole multi-weight run, so W4 is nearly unreachable (MEDIUM — calibration decision)

`modules/weighting/run_weighting.R:528-532`.

The per-weight `tryCatch` re-throws anything inheriting `turas_refusal`, and only converts plain errors into a PARTIAL. W3 turned the design and cell NA-weight problems from warnings into refusals, so the most likely single-weight failure in a real config is now a refusal — which takes the other weights with it. W4's careful "omit the failed column" path therefore fires only for non-refusal errors. The W4 test at `tests/testthat/test_lookup_integrity.R:234` has to inject a bare `stop()` to reach it, and its comment says so.

This is defensible: a config error is a config error and stopping is honest. But it is a real change in how a four-weight config behaves, and it means the operator fixes one problem per run rather than seeing all four. Worth a decision rather than an accident.

Fix cost: moderate if you want per-weight isolation — catch `turas_refusal` per weight, record it on the run state, omit that weight, and continue; refuse outright only when every weight failed (the `CALC_NO_WEIGHTS_PRODUCED` guard at `run_weighting.R:600` already covers that case). Zero if the current behaviour is what you want.

### F4 — A cell target of exactly zero refuses, which the spec did not ask for (LOW-MEDIUM — calibration + scope deviation)

`modules/weighting/lib/cell_weights.R:99`.

Handover W7(f) asked the cell direct-API to refuse "negative/NA target_percent". The implementation refuses `<= 0`, which also catches a genuine zero. Verified: a four-cell target table with one cell at `0` refuses `CFG_INVALID_TARGET_VALUE`.

The reasoning in the comment is sound — a zero target silently zero-weights real respondents, which is an NA weight by another name. But in an interlocked design with a real census table, a sparse cell rounding to 0.0% is ordinary. The `how_to_fix` tells the analyst to remove the row and collapse the cell, which is the right advice and does not require the refusal to be this strict, since removing the row is what the analyst must do either way.

Fix cost: trivial either way. If you keep it, it is fine — just log it as a deliberate widening of the spec. If you soften it, refuse `< 0` and `NA` and route exact zeros into the same "no respondent can carry this share" disclosure as an empty cell.

### F5 — Smaller items

| | Where | What | Cost |
|---|---|---|---|
| a | `lib/validation/preflight_validators.R:430` | W7(a) asked for the category-mismatch preflight to go Warning→Error "for design/cell". Design was changed (`:185`, `:196`); the cell combinations check is still `"Warning"`. The cell engine now refuses downstream, so nothing corrupt ships — but the preflight, whose job is to catch it before the engine runs, still waves it through. | Trivial |
| b | `lib/00_guard.R:163` vs `lib/rim_weights.R:164` | The config guard allows rim targets summing to 100 ± 0.5 (`> 0.5` fails). The engine, working in proportions, uses `abs(sum − 1) > 0.005`. At exactly 100.5 the first passes and the second refuses on floating point. The engine refusal I executed — targets of 0.335 × 3 refuse with `CFG_TARGET_SUM_ERROR`; the preflight pass is read from the guard condition (`> 0.5`), not run. Loud, not corrupting, but confusing. | Trivial — express both from one constant |
| c | `lib/rim_weights.R:295-304` | `margin_tolerance` is validated in the config path (`:658`) but not in `validate_rim_inputs`, so the exported core accepts a negative tolerance and then reports every run as non-converged. Visible in the suite output as "tolerance −1.00 pp" with all diffs at 0.00. Direct-API only. | Trivial |
| d | `lib/rim_weights.R:458-469` | `CALC_NONPOSITIVE_WEIGHTS` is new and is not in any work package. It is a good guard (linear calibration can land weights at or below zero) and it is tested. Logging it as unrequested scope, not objecting to it. | n/a |
| e | `lib/validation.R:326` | With `grossing = Y` — now an explicitly supported mode — every weight is at population scale, so the "Maximum weight %.2f is very high (>10). Consider trimming." warning fires on every grossed run. Pre-existing, newly relevant. | Trivial — skip the check when the weight is grossed |
| f | brief §3 | The brief states 268 tests / 679 expectations and 1 expected warning. I measured 268 / **682** with **3** warnings: the deliberate 20% trim in `test_trimming.R:58`, the same in `test_config_templates.R:307`, and a `survey` non-convergence warning from `test_numeric_values.R:232`. That third one is benign — the test accepts either outcome — but a suite whose warning count is quoted as 1 should not be emitting 3. | Trivial |

---

## 3. What the code does *not* let an analyst do

Three of the findings above share a shape worth naming separately, because it is a design gap rather than a defect.

When cell or design weighting finds a target with no sample, the analyst has exactly two options: hand-edit the target table, or set `allow_unmatched = Y` and accept a deflated base with no renormalisation (F2). There is no supported way to say "I know that cell is empty, redistribute its share across the rest" — which is the statistically ordinary answer and what most analysts will actually want. And `allow_unmatched` currently carries two unrelated meanings (respondents with no weight; population shares with no respondent), so an analyst who wants to exclude three people with a missing age also silently switches off the empty-cell guard. The brief flagged this coupling as a suspicion; I think it is real.

My recommendation, for you to rule on: split the setting in two (`allow_unmatched` for respondents, `allow_empty_targets` for population shares), and make the empty-target opt-in renormalise the surviving targets to 100% with a console statement of what moved. That turns a disclosed error into a defensible method.

---

## 4. Test blindspots

1. **No golden-file regression.** Nothing in the suite compares a full run's output against a known-good prior result. Every numeric assertion is against arithmetic the author computed by hand, which catches wrong arithmetic but not a changed pipeline. The Electrum case is the obvious fixture: a small synthetic config with a committed expected lookup file, asserted to the last decimal, would have caught F1 immediately and would catch any future scale change.
2. **Nothing asserts that the design summary matches the written weights.** F1 exists because the two are tested separately and never against each other.
3. **The "0 unweighted" behaviour is enshrined rather than examined.** `test_cell_weights.R:177` asserts `n_unweighted == 0` on a fixture whose weighted base is half its sample size, and no test asserts anything about `sum(weights)` on that path.
4. **No sum-to-n assertion on any cell or design path.** `test_cell_weights.R:30` ("cell weights sum preserves sample size") covers the clean case only.
5. **`allow_unmatched` and `grossing` are tested through the engine and through `read_*_setting`, but not through `run_weighting()` end to end** — so nothing pins that a config file carrying those settings actually reaches the engine with them. The equivalent for `margin_tolerance` *is* tested end to end (`test_rim_weights.R:491`), which is the pattern the other two should follow.

---

## 5. Verification log

| Claim | How checked |
|---|---|
| Weighting suite green | Ran `testthat::test_dir("modules/weighting/tests/testthat")` this session: 268 tests, 682 expectations, 0 failed, 0 errors, 0 skipped, 3 warnings. |
| Platform suite | Ran `testthat::test_dir("tests/testthat")` this session: 574 expectations, 3 failed — `test_launcher.R` "module registry contains all 14 modules" and `test_module_smoke.R` "ADR directory exists with documents" (×2). Exactly the three the brief names as pre-existing and unrelated, and they are. The brief's wider figure of 15,892 passed spans the per-module suites as well; I ran the top-level suite and the weighting suite, not every module's. **The 15,892 figure is author-claimed and unverified here.** |
| F1 | Ran `calculate_design_weights_from_config` on the suite's own fixture and printed both the summary and the weight vector. |
| F2 | Ran `calculate_cell_weights(..., allow_unmatched = TRUE)` on a 4-cell design with one empty cell; captured the console block and `sum(weights)`. |
| F3 | Read `run_weighting.R:528-556`; corroborated by the W4 test's own use of a bare `stop()`. |
| F4 | Ran `calculate_cell_weights` with one target at 0. |
| F5b | Ran `calculate_rim_weights` with targets of 0.335 × 3. |
| Q4 tabs path | Read `weight_validators.R:95`, `:359`, `validation.R:1445`, `:1531`, `weighting.R:260`. |
| Electrum config | Read the workbook and the CSV directly with `readxl`/`read.csv`; no pipeline run, nothing written. |
| GUI load path | New functions all live in files already on the `lib_files` whitelist at `run_weighting.R:86-97`; no new source file was added. |
| `load_config_table_sheet` | Confirmed the shared change (`f31a23a4`, `7fa0ff33`) predates the W range via `git merge-base --is-ancestor`, so it is outside this review. Its help-row re-read assumes the help rows sit immediately below the header and is guarded by a row-count and name check — unverified against a config where they do not. |

---

## 6. On the locked §0 decisions

One paragraph, as instructed. I would have made the same four calls. The one I would revisit later, not now, is §0.2: normalising design weights to sum = n by default is right for consistency with rim, but it is a silent numeric change to every existing design config, and the module gives the analyst no signal that the scale moved — the diagnostics report `weight_scale`, but nothing compares this run's scale to the last one's. A one-line console statement of the scale and the un-normalised population total on every design run would cost nothing and remove the ambiguity entirely. F1 is the acute version of the same gap.

---

## 7. What was done — `fix/weighting-review-followups`, 2026-08-09

Every recommendation above was implemented on one branch off `main`. The two
findings where the review left a decision open were settled first, and the
reasoning is recorded here because the code alone does not carry it.

**F3 — refusals are isolated per weight.** The locked §0.4 decision, that a
failed weight is omitted from the lookup file, presupposes a failed weight can be
isolated. W3's refusals made that path nearly unreachable, so isolating them
implements the decision rather than re-litigating it. Config-level refusals —
duplicate IDs, weight-name collisions, an unreadable config, preflight — are
raised outside the weight loop and still stop the run, and a single-weight config
still refuses outright.

**F4 — a zero cell target is judged on occupancy, not on being zero.** `NA` and
negative targets always refuse. A zero target with respondents in it refuses as
unweighted respondents, which is what it is. A zero target nobody is standing in
passes, because a zero share lost is no loss.

| Finding | What changed | Where |
|---|---|---|
| F1 | The stratum summary is scaled to match the weights actually written, and keeps the population ÷ sample figure in its own `Pop/Sample` column. The HTML callout that asserted weight = population ÷ sample — true before W5, false after — was corrected. | `lib/design_weights.R`, `lib/output.R`, `lib/html_report/02_table_builder.R` |
| F2 | `allow_unmatched` split into a respondent-side and a population-side opt-in (`allow_empty_targets`); the population-side opt-in redistributes the orphaned share so the base is whole; the disclosure leads with respondents-carrying-a-weight and the weighted base; cell weights calibrate to the respondents carrying a weight rather than to `nrow(data)`; `validate_calculated_weights()` gained an expected-sum assertion and a `population_scale` flag that silences the >10 warning on grossed weights. | `lib/cell_weights.R`, `lib/design_weights.R`, `lib/config_loader.R`, `lib/validation.R`, `lib/rim_weights.R` |
| F3 | A refusal inside the weight loop is printed, recorded on the run state, and the weight is dropped; the rest are still calculated and the run is PARTIAL. | `run_weighting.R` |
| F4 | `target_percent < 0` and `NA` refuse; zero is routed by occupancy. New `CFG_NO_USABLE_TARGETS` for a config where every populated cell has a zero target. | `lib/cell_weights.R` |
| F5a | The empty cell-combination preflight check is an `Error`. | `lib/validation/preflight_validators.R` |
| F5b | Preflight and the rim engine express the target-sum tolerance from `RIM_TARGET_SUM_TOLERANCE`, with float slack so a config on exactly 100.5 cannot pass one and fail the other. | `lib/validation/preflight_validators.R`, `lib/rim_weights.R` |
| F5c | `margin_tolerance` is validated in the exported core as well as the config path. | `lib/rim_weights.R` |
| F5e | Grossed weights no longer trip the extreme-weight warning. | `lib/validation.R` |
| F5f | The one stray suite warning is declared where it arises; the two that remain are the module's own trimming-bias warning fired on purpose, and the runbook now says so. | `tests/testthat/test_numeric_values.R`, `docs/RUNBOOK.md` |
| §4.1 | Golden-file regression: a committed 200-row fixture run end to end through `run_weighting()` against an expected lookup file **derived from arithmetic, not from the module**, covering a design and a rim weight on one study. | `tests/fixtures/golden/`, `tests/testthat/test_review_followups.R` |
| §4.2–4.5 | Tests for the summary-matches-weights invariant, the two opt-ins separately, the sum check, and the settings through `run_weighting()`. | `tests/testthat/test_review_followups.R` |
| §6 | Every design run states its scale, the total the column sums to, and — under grossing — the stated population. | `lib/design_weights.R` |

Docs, template and changelog: `allow_empty_targets` added to the generated
template and to README / USER_MANUAL / TEMPLATE_REFERENCE / RUNBOOK, both checked-in
template workbooks regenerated, and the refusal index rewritten where the meaning
of a code changed.

### Verification

| Check | Result |
|---|---|
| Weighting suite | 742 expectations, 0 failures, 0 errors, 2 warnings — both the deliberate trimming-bias warning. Was 682/0/3 before this work. |
| Platform suite (`tests/testthat`) | 574 expectations, 3 failures — the same pre-existing `test_launcher.R` and `test_module_smoke.R` failures as before, unchanged. |
| Every new test fails on the old code | Each test in `test_review_followups.R` targets behaviour that did not exist at `82642f2b`; the two pre-existing tests that encoded the behaviour being changed (`allow_unmatched` on empty cells, the `<= 0` cell target) were rewritten to the new specification rather than deleted. |
| Live Electrum rim config, read-only | Config loaded and `calculate_rim_weights_from_config()` called on the data in memory — no pipeline run, nothing written. Passes the ID and weight-name guards, converges with a worst margin gap of 1e-4 pp, sums to 1101 on n = 1101, and reproduces `VAS_2024_weighted.csv` to a maximum absolute difference of **4.9e-15**. |
| GUI load path | No new source file: every new function is in `00_guard.R`, `config_loader.R`, `design_weights.R`, `cell_weights.R`, `rim_weights.R` or `validation.R`, all already on the `lib_files` list at `run_weighting.R:86-97`. |

**Not verified here.** The per-module suites outside weighting were not re-run;
no file outside `modules/weighting`, `docs/` and `CHANGELOG.md` was touched, so
nothing else should be affected, but that is reasoning rather than a test result.
Duncan's `launch_turas()` regeneration of the Electrum project remains the
confirming step — the 4.9e-15 figure above is the engine on the data, not the
full pipeline writing a file.
