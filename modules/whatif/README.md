# What if module

Status: engine only (session 1 of `docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md`).
There is no config workbook, no report tab and no client-safe output yet. The
module stands apart from the other modules for now: nothing else sources it.

## What it does

It links one outcome question (NPS, or any ordered categorical outcome) to the
experience questions around it, then answers "what would the outcome do for
this group if an area slipped, or were fixed for the people who need it?". It
also fits a second model on who the respondent is, for the "Build a student"
line.

The model is a cumulative logit (proportional odds) fitted by the module's own
penalised maximum likelihood (`optim`, analytic gradient). At zero penalty it
equals `ordinal::clm` (to 1e-4 in the tests; to 1e-9 on SACAP 2025).

It is association, not cause. Nothing built on this module may say that fixing
an area WILL add points.

## Files

| File | Purpose |
|---|---|
| `R/00_main.R` | `whatif_run_engine(spec)`: guard, design, fit, refits, moves, profile model |
| `R/00_guard.R` | Validates the study spec; every problem is a TRS refusal. The spec's fields are listed at the top of this file |
| `R/00_utils.R` | Refusal wrapper, seeded randomness that leaves the caller's stream alone |
| `R/01_design.R` | Design matrix: rating, nested and coverage levers, context baselines, profile dummies |
| `R/02_fit.R` | Penalised ordinal fit, probabilities, cross-validation, penalty choice |
| `R/03_bootstrap.R` | Bootstrap refits (respondents resampled, weights fixed) and the sign check |
| `R/04_moves.R` | Moves: slip2, slip1, up1, up2, floor (lift to the fix target), withdraw, extend |
| `R/05_groups.R` | `whatif_group_results()`: actual score and every move's change for a group, with 90% ranges |
| `R/06_profile.R` | Profile model; `whatif_profile_predict()` refuses a profile the Structure rules block |
| `R/07_calibration.R` | `whatif_calibration()`: held-out predicted against actual score by context group |
| `dev/verify_sacap_2025.R` | One-off check against the Python prototype on SACAP 2025. Reads client data; not part of the suite |

## Lever kinds

- **rating**: a score on the study scale; enters as value minus centre.
- **nested**: a rating only some respondents give (they have the service);
  enters as "has" plus "has times (value minus centre)". Moves touch only those
  who have it.
- **coverage**: has the service (1) or not (0). Moves extend or withdraw it.

## Context baselines

Context variables named in `spec$baselines` enter the lever model as dummies
(most common level as reference) with a ridge penalty on those columns only,
chosen by five-fold cross-validation from `c(1, 2, 5, 10, 20, 50, 100)`. This
fixes group calibration: on SACAP 2025 unweighted, groups whose held-out
prediction missed beyond sampling error fell from 6 of 36 to 0 of 36.

## Structure rules

`spec$profile$rules` is a table of blocked pairs (key1, level1, key2, level2),
for example course "Bachelor of Social Work" with year "Masters". Rules may name
structural traits only; a rule on a personal trait (age, gender) is refused.

## Tests

```bash
Rscript modules/whatif/tests/run_tests.R
```

Synthetic data only (`tests/fixtures/synthetic_data/generate_test_data.R`). A
git worktree has an empty renv library; run from one with
`RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and `R_LIBS_USER` pointing at the main
checkout's `renv/library/<platform>/<R version>/<arch>` folder.
