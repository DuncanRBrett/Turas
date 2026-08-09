# Weighting W1–W8 — Independent Review Brief

**Written:** 2026-08-09, by the session that implemented W1–W8, for a session that did not.

**You are independent of the implementation.** The work under review was written by a
different session. Nothing in it has been checked by anyone but its author, including
its tests. Treat the code as a claim, not as a starting position, and treat this brief
as scoping only — where the author's reasoning appears below, it is there to be
falsified, not adopted.

---

## 0. What you are being asked

Four questions. Nothing else.

1. **Are the new refusals calibrated correctly for real market-research work?** Several
   changes convert a run that used to complete into one that stops. Each is defensible in
   principle. The question is whether any of them will block legitimate studies —
   an empty target cell that is genuinely empty, a stratum with no sample that the
   analyst already knows about, a respondent file that legitimately repeats an ID.
2. **Does anything in W1–W8 break a workflow that should work?** Including workflows that
   are not in the test suite because the author did not think of them.
3. **What should have been tested and was not?** The blindspot question. The suite grew
   from 209 tests / 454 expectations to 268 / 679, all written by the author of the code.
   Green tests written by the author are evidence that the code does what the author
   thought, not that what the author thought was right.
4. **Do the weights still reach tabs correctly, end to end?** The module's entire
   deliverable is a lookup file that tabs merges onto the survey data. Several changes
   touch what is written into it and under what conditions.

### Out of scope — do not re-open

- **The four §0 decisions** in `HANDOVER_WEIGHTING_FOR_OPUS.md` (post-hoc trimming
  semantics, design-weight scale, NA-row policy, PARTIAL output). These were locked by
  the July review. The implementation was instructed to follow them. If you think a
  decision was wrong, say so in one paragraph at the end and move on — do not rebuild the
  review around it.
- **The core engines.** `WEIGHTING_PRODUCTION_REVIEW_2026-07-12.md` §4 lists what was
  verified sound and marked do-not-re-litigate: the raking core, row alignment, the Kish
  formulas, no rounding on write, the percent-vs-proportion guards, preflight. Take those
  as given unless W1–W8 disturbed them, which is a different question and a fair one.
- **The HTML report layer.** Deliberately unreviewed in July and still out of scope.

---

## 1. The specification

Read these two, in this order. **They are the specification. The implementation is not.**

1. `docs/v2_lift/WEIGHTING_PRODUCTION_REVIEW_2026-07-12.md` — the findings, with IDs
   C1–C2, H1–H4, M1–M7 and a §5 assessment of the test suite's numeric weakness.
2. `docs/v2_lift/HANDOVER_WEIGHTING_FOR_OPUS.md` — §0 decisions, then work packages
   W1–W8, then §3 "What NOT to do".

Judge the implementation against those documents, not against the commit messages. The
commit messages are the author's account of the author's own work.

---

## 2. What to look at

Seven commits, `684157ea` to `d2ce9699`, merged to local main at `82642f2b`.
27 files, +2522 / −137.

| Package | Claim made | Where |
|---|---|---|
| W1 | Rim + `apply_trimming = Y` refuses (`CFG_TRIM_USE_CAP`); design/cell trim then rescale to the original sum, disclosed | `lib/trimming.R`, `lib/diagnostics.R` |
| W2 | Convergence decided from achieved margins via `judge_margin_convergence()`; new `margin_tolerance`; PARTIAL when missed | `lib/rim_weights.R`, `run_weighting.R` |
| W3 | Design/cell refuse `DATA_UNWEIGHTED_ROWS`; `allow_unmatched` opt-out; empty target cells refuse | `lib/design_weights.R`, `lib/cell_weights.R`, `lib/config_loader.R` |
| W4 | A failed weight is omitted from the lookup file, not written all-NA | `run_weighting.R` |
| W5 | Design weights normalise to sum = n; `grossing = Y` keeps population scale | `lib/design_weights.R`, `lib/config_loader.R` |
| W6 | Duplicate/blank IDs and weight-name collisions refuse | `lib/00_guard.R`, `run_weighting.R` |
| W7 | Unreadable targets refuse; labels trimmed both sides, case-sensitive; exported cores validate targets; DEFF from unrounded n_eff | `lib/config_loader.R`, `lib/rim_weights.R`, `lib/cell_weights.R`, `lib/validation.R`, `lib/validation/preflight_validators.R` |
| W7c | NA found before cell-key construction; keys joined with the ASCII unit separator | `lib/cell_weights.R` |
| W8 | Hand-checkable numeric assertions | `tests/testthat/test_numeric_values.R` |

New config keys, all in Advanced_Settings, all with generated-template columns and docs:
`margin_tolerance` (default 0.5pp), `allow_unmatched` (default N), `grossing` (default N).

New documentation: `modules/weighting/docs/RUNBOOK.md`, including an index of every
refusal code the module can raise.

---

## 3. What has and has not been verified

**Has been.** The weighting suite: 268 tests, 679 expectations, 0 failures, 1 expected
warning (`test_trimming.R` deliberately trims 20%). The full platform suite on merged
main: 15,892 passed, 3 failed, 25 skipped — the 3 are pre-existing and unrelated
(`tests/testthat/test_launcher.R` expects 14 launcher modules against a registry holding
16; `test_module_smoke.R` expects a `docs/adr` directory that does not exist). The GUI
load path was confirmed to resolve every new function with `TURAS_LAUNCHER_ACTIVE` set.

```bash
Rscript -e 'testthat::test_dir("modules/weighting/tests/testthat", reporter = "summary")'
```

**Has not been.** The module has not been run against a real weighting project since
W1–W8. Every claim above rests on tests written by the same session that wrote the code.
No weighted output has been compared against a known-good prior result.

**There is a live case available.** `Electrum/VAS 2024/Weighting/Weight_Config.xlsx` —
a single rim weight `pop_wt`, `apply_trimming = N`, no Advanced_Settings sheet — with
prior output beside it in `output/`. That config exercises the new defaults on a config
that never mentions them, plus W2's convergence judgement and W6's ID guard, and its
existing `VAS_2024_weighted.csv` gives a numeric before/after. **Duncan runs it, via
`launch_turas()`. Do not run the pipeline against project folders yourself and do not
write into OneDrive.**

---

## 4. Where the author expects to be wrong

Offered as leads, not conclusions. An empty list here would be more suspicious than a
long one.

- **Empty target cells refuse by default (W3, review H2).** A cell with a population
  share and no respondents now stops the run. Sparse interlocked designs may hit this
  routinely, and `allow_unmatched` is a blunt opt-out — it also switches off the NA-weight
  refusal, which is a different thing. One setting, two behaviours, possibly wrongly
  coupled.
- **Design-weight normalisation is a default that changes numbers (W5).** Every existing
  design-weight config now produces a differently-scaled column unless `grossing = Y` is
  added. Kish n_eff is scale-invariant so significance is untouched, but weighted Ns move.
  Is a silently-changed default the right migration for existing projects?
- **W2's PARTIAL may be unreachable in practice.** `survey::calibrate(force = FALSE)`
  refuses on non-convergence before the margin check runs; the author could not construct
  a fixture where calibration returns off-target, and tested the judgement function
  directly instead. Either the guard is a safety net for a case that cannot occur, or the
  case exists and neither the author nor the test suite found it.
- **Label trimming changed matching semantics (W7).** Surrounding whitespace is now
  ignored on both sides, case still respected. That is a behaviour change on live configs,
  chosen because whitespace is never meaningful. Is that true of every client's data?
- **Refusals abort the whole run.** With design and cell now refusing rather than warning,
  a single bad category in one weight stops a multi-weight config outright — the PARTIAL
  path only catches non-refusal errors. W4's careful handling of failed weights may
  therefore be much harder to reach than intended.
- **`load_config_table_sheet()` was changed underneath.** It is shared with catdriver and
  keydriver and now re-reads a sheet to recover column types when help rows are dropped.
  Weighting's own configs go through it.

---

## 5. Deliverable

A findings document in `docs/v2_lift/`, named for the review and dated. For each finding:
severity, the file and line, what breaks, and what it would take to fix. Verify load-bearing
claims yourself by reading the code or running something — mark anything you did not
verify as unverified, next to the claim.

If the answer to all four questions in §0 is "nothing found", say that plainly. A short
clean review is a useful result; a padded one is not.

Ground rules that still apply: TRS refusals rather than `stop()`, console-visible errors
because Turas runs inside Shiny, and no weakening of an existing refusal to make a test
pass.
