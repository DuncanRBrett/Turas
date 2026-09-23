# What if simulator, session 1: the engine in R

Session run 24 Sep 2026, on branch `feature/whatif-engine-r` (built in a git
worktree, not merged). Brief: `docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md`,
section 6, session 1.

## What was built

A new module, `modules/whatif/`, with no link to any other module yet:

- `R/00_main.R`: `whatif_run_engine(spec)` fits the lever model, the bootstrap
  refits, the sign check, every lever's moves and the profile model.
- `R/00_guard.R`: validates the in-memory study spec. Every problem is a TRS
  refusal, printed to the console. The spec's fields are listed in the file
  header; session 2 builds this spec from the config workbook.
- `R/01_design.R` to `R/07_calibration.R`: design matrix (rating, nested,
  coverage, context baselines), penalised ordinal fit, bootstrap and sign
  check, moves, group results, profile model with Structure rules, calibration.
- `tests/`: 159 expectations on a synthetic study with every lever kind, a
  known Honours offset and Structure rules.
- `dev/verify_sacap_2025.R`: the one-off check on SACAP 2025. It reads the
  OneDrive file, takes its path as an argument and writes nothing.

## Verification (quoted from the runs, 24 Sep 2026)

Suite: `Rscript modules/whatif/tests/run_tests.R` gives
`Total: 159 | Passed: 159 | Failed: 0 | Skipped: 0`.

Brief bar, item by item:

1. Unpenalised fit against `ordinal::clm`. Synthetic fixture, in the suite:
   within 1e-4 for three categories unweighted and weighted, binary, five
   categories, and the fixture's own design matrix. SACAP 2025 unweighted:
   largest difference 7.61e-10 on coefficients, 3.23e-10 on thresholds.
   Weighted: 5.93e-09 and 8.28e-09.
2. SACAP 2025 unweighted, no baselines, against `study_sacap.py`:

   | | R engine | Prototype |
   |---|---|---|
   | Respondents, actual NPS | 1,361, 45.6 | 1,361, 45.6 |
   | Main fit coefficients | largest difference 4.48e-06 | |
   | Thresholds | 0.42593, 2.16351 | 0.42593, 2.16351 |
   | Value for money, slip one notch | -26.3 [-29.9, -22.3] | -26.3 [-31.0, -22.0] |
   | Value for money, lift to Good | +14.1 [11.9, 16.0] | +14.1 [11.7, 16.5] |
   | Slip / lift, other seven levers | identical to one decimal | |
   | Need counts | 173, 373, 148, 471, 207, 188, 392, 481 | the same |
   | Bundles, Teaching and Service | 16.4 and 8.1 | 16.4 and 8.1 |
   | Sign check, Q026 / Q064 / Q065 | 0.29 / 0.06 / 0.25 | 0.29 / 0.06 / 0.31 |
   | Held-out pseudo R2 | 0.207 | 0.204 |
   | Profile model penalty, spread 5/50/95 | 5; 19.6 / 48.8 / 64.2 | 5; 19.6 / 48.8 / 64.2 |

   Point estimates match exactly. Ranges, the sign check and held-out fit
   differ within noise: R draws different bootstrap samples and folds from
   numpy.
3. Calibration with baselines on, re-measured UNWEIGHTED (the brief asked for
   this; the 23 Sep figures were weighted). Groups of 30 or more, held-out:

   | | Ratings only | With context baselines |
   |---|---|---|
   | Held-out pseudo R2 | 0.207 | 0.220 |
   | Groups outside their 95% band | 6 of 36 | 0 of 36 |
   | Median error in group NPS | 5.2 points | 1.7 points |
   | BSocSci Honours (actual 23.5) | predicted 42.3, z 3.3 | predicted 26.1, z 0.5 |
   | Honours year (actual 28.2) | 43.8, z 3.1 | 30.0, z 0.4 |
   | Age 18 to 20 (actual 56.5) | 44.7, z -2.7 | 53.9, z -0.6 |
   | Higher Certificate (actual 65.3) | 48.4, z -2.2 | 59.5, z -0.8 |

   Chosen baseline penalty 5; the cross-validation curve is flat from 2 to 20
   (held-out 0.2189 to 0.2204). With baselines, all students, value for money
   reads slip -25.6 and lift +13.6. The other levers' lifts move by 0.4 points
   or less.

   Weighted, same run: ratings only 0.203, 6 of 36, median 4.7; with
   baselines (penalty 10) 0.215, 0 of 36, median 2.0. PLAN.md's weighted
   figures were 0.201 to 0.213 and 6 to 0. The weighted value for money,
   -26.6 and +14.3, equals PLAN.md's weighted figure.
4. Impossible profiles. Suite: two blocked profiles refused with
   `CFG_PROFILE_IMPOSSIBLE`, and an unseen personal combination (male Masters,
   after removing every male Masters student) still answered. SACAP: a Bachelor
   of Social Work Masters student is refused. A male third-year BSW student in
   Cape Town is answered: NPS 32.9 [15.3, 48.3].

## Decisions taken in this session (conservative option, logged)

1. **How the baselines are coded.** The 23 Sep calibration code was not kept
   (not in `robustness.py`, not in the scratchpad), so it was rebuilt. Each
   baseline variable is dummy coded with its most common level as the
   reference. A ridge penalty applies to those columns only; the levers keep
   the prototype's tiny 1e-4. The penalty is chosen by five-fold
   cross-validation from 1, 2, 5, 10, 20, 50 and 100.
2. **Held-out figures after choosing the penalty on the same folds** are
   slightly optimistic. The curve is flat, so the effect is small, but it is
   not nested cross-validation.
3. **The outcome takes any number of ordered categories** plus a score per
   category (NPS is -100, 0, 100; a top-two-box share would be 0, 0, 0, 100,
   100). Binary is the same code with one threshold. The multinomial model for
   a genuinely unordered outcome is NOT built. Neither SACAP nor CCPB needs it.
4. **Structure rules are a table of blocked pairs** (key1, level1, key2,
   level2). The guard refuses a rule on a trait not marked structural, a level
   nobody has, or a trait paired with itself. Deriving proposed rules from the
   data is left to the session 2 preflight.
5. **Move names follow the prototype** (slip2, slip1, up1, up2, floor,
   withdraw, extend). "floor" means lift everyone below the fix target up to
   it. Each lever can carry its own fix target; the scale's "good" point is the
   default.
6. **Public functions return a structured refusal**: `whatif_run_engine`,
   `whatif_group_results` and `whatif_profile_predict` use
   `with_refusal_handler`, so a refusal prints the boxed message and comes back
   as a `turas_refusal_result`.
7. **A lever counts as unclear when more than 10% of refits point the wrong
   way**, the mockup's threshold. An unclear lever makes the run PARTIAL with a
   warning. So does a baseline penalty at the edge of the grid.

## Bug found and fixed during the session

`spec$profile` partially matched the setting `profile_penalties` when a study
had no profile, and the engine crashed. A test had passed anyway, because it
only checked a field that the error result also lacked. Fixes: the settings are
now `penalty_grid_profile`, `penalty_grid_baselines` and `penalty_levers`. The
profile is read with `[[ ]]`. The test helpers fail on an unexpected error, and
a regression test covers a spec with no profile.

## Not done, and why

- **Symptoms** (fitted only to show why they are not levers) are not ported.
  They belong with the session 2 preflight and the session 5 stats pack.
- **Client-safe groups** (secondary suppression, the nesting check, the audit)
  are session 4, as the brief says. Session 1 takes groups as given.
- **The brief's "56 of 90 course by year cells empty"** was not reproduced.
  With the prototype's collapsed courses (10) and year bands (6) the count is
  30 of 60. The 90 probably used a different course grouping. Unverified.
- **styler** is not installed in the renv library, so it was not run. lintr
  reports only object-name notes on upper-case constants and matrix names such
  as `X`, which match the house style elsewhere.
- **No em dashes** in the module (grep checked).

## For session 2

- The config should switch baselines on by default. The brief makes the
  calibration fix part of version 1. The obvious set is the context variables
  the study already declares for filters and the profile.
- The spec in `R/00_guard.R` is the target the config reader builds. Lever
  items averaged into one lever (CCPB's rep and delivery) should be averaged by
  the config reader before they reach the engine. Don't-know handling belongs
  there too: the engine refuses a missing rating.
- The CCPB 2026 reproduction is session 2's bar. It will be the first real run
  of nested and coverage levers; the synthetic suite covers both.

## Still open for Duncan

Whether the SACAP deliverable is the open or the client-safe version (brief
section 3). Nothing in session 1 depends on it.
