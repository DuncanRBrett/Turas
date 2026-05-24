# Production Review: Tracker Module

**Date:** 2026-05-24
**Branch/Version:** main (module v10.2)
**Reviewer:** Claude (production-review skill)
**Language/Stack:** R 4.5.3 / openxlsx / Shiny GUI
**Trigger:** Duncan flagged a possible significance-test inconsistency on the
Coca-Cola Peninsula Beverages W25 report — "Rate CCS in their handling..."
showed Δ -0.90 marked non-significant while "Equipment Cleanliness" showed
Δ -0.83 marked significant at the same sample size.

---

## Verification Gates

| Gate                 | Command                                              | Result |
|----------------------|------------------------------------------------------|--------|
| Test suite           | `testthat::test_dir("modules/tracker/tests/testthat")` | **PASS** — 1855 tests across 20 files, 0 failures, 1 acknowledged warning |
| TRS compliance       | `grep -E "^[^#]*stop\\(" modules/tracker/lib`        | **PASS** — 2 `stop()` calls, both intentional pre-TRS fallbacks (`00_guard.R:100`, `run_tracker_gui.R:46`), explicitly documented |
| Lint (`lintr`)       | not installed in this renv                           | **SKIPPED** — see I7 |
| Style (`styler`)     | not installed in this renv                           | **SKIPPED** |
| File size            | manual                                               | 5 files > 1000 LOC; documented and cohesive — see O1 |

Test run was clean apart from one warning at `test_statistical_core.R:400`
(intentional NaN-producing extreme-proportions edge case, documented in
the test itself).

---

## Headline finding — the CCS anomaly is **not a bug**

Reproduced with the module's own `t_test_for_means`:

```
CCS handling-style  mean1=7.0 sd1=3.2 n=100  →  mean2=6.1 sd2=3.3 n=100
   t = -1.958   p = 0.0516   sig = FALSE   (Δ = -0.90)

Equipment cleanliness-style  mean1=8.1 sd1=2.0 n=100  →  mean2=7.3 sd2=2.1 n=100
   t = -2.759   p = 0.00635  sig = TRUE    (Δ = -0.83)
```

The pooled two-sample t-test correctly accounts for variance:
- Retailers disagree strongly about how CCS handles a missing
  merchandiser (some furious, some calm) → wide SD (~3.2) → the larger
  raw delta sits just over p = 0.05.
- Retailers cluster their cleanliness ratings tightly (~SD 2.0) → the
  smaller delta clears the threshold easily.

This is **statistically correct behaviour**. The screenshot pattern is
mathematically consistent with the code as written. There is, however,
no regression test asserting this invariant, and the issue is not
explained anywhere in the docs — see I6 + M2.

---

## CRITICAL

*(none)*

The statistical core is correct. Test suite is green. Nothing here
blocks deployment, but the IMPORTANT items below should be addressed
on a polish branch before the next significant tracker release.

---

## IMPORTANT

### I1. `eff_n` is silently lost for non-mean rating metrics → inflated significance

**File:** [modules/tracker/lib/trend_calculator.R:712](../lib/trend_calculator.R) and
[modules/tracker/lib/trend_calculator.R:890](../lib/trend_calculator.R)

`calculate_rating_trend_enhanced` and `calculate_composite_trend_enhanced`
store `eff_n = metrics$eff_n` in each wave_result. But `metrics$eff_n`
is only populated by `calculate_weighted_mean` (statistical_core.R:263)
— i.e. only when the `mean` spec is in TrackingSpecs.

`calculate_top_box`, `calculate_bottom_box`, and `calculate_custom_range`
do **not** return `eff_n`. So if a user specifies e.g.
`TrackingSpecs = "top_box,range:9-10"` (no `mean`), then
`wave_results[[w]]$eff_n` is `NULL`. The downstream test in
[trend_significance.R:299-300](../lib/trend_significance.R) falls back
to `n_unweighted`, which **ignores the design effect** from weighting
and inflates the z-statistic.

Reproduction (with a wave where 40% weight efficiency reduces eff_n
from 100 to 60):

```
Using n_unweighted=100 each (what the bug produces): p = 0.0285  sig = TRUE
Using eff_n=60 each (correct):                       p = 0.0897  sig = FALSE
```

Bites any tracker config that uses top_box / bottom_box / range without
also requesting mean, AND that uses weighting with non-uniform weights.
Documented examples in `06_TEMPLATE_REFERENCE.md:389` (`mean,top_box,range:9-10`)
keep `mean` in the spec — so the most-common usage is unaffected. But
"box-only" configs are valid usage and would be misreported.

**Fix:** In `calculate_top_box`, `calculate_bottom_box`,
`calculate_custom_range` (statistical_core.R), also compute and return
`eff_n` using the same Kish formula already used in
`calculate_weighted_mean`. Then in `calculate_metrics_from_specs`
(trend_calculator.R:530-597), persist `metrics$eff_n` from whichever
spec ran first; or, simpler, compute `eff_n` once from
`wave_df$weight_var` independently of the specs loop and store it
directly on the wave_result. Add a test that runs `top_box`-only on
weighted data and asserts the resulting p-value matches the eff_n-based
calculation.

### I2. No `minimum_base` check for box / range / multi-mention significance tests

**File:** [modules/tracker/lib/trend_significance.R:268-318](../lib/trend_significance.R) (`perform_significance_tests_for_metric`) and
[modules/tracker/lib/trend_significance.R:332-372](../lib/trend_significance.R) (`perform_significance_tests_multi_mention`) and
[modules/tracker/lib/trend_significance.R:386-433](../lib/trend_significance.R) (`perform_significance_tests_multi_mention_metric`)

The three "means / proportions / NPS" tests all read `min_base <-
get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)`
and refuse to test below it (line 77, 140, 220). The four "enhanced
metric" tests don't. This means top_box, bottom_box, range, box, and
multi-mention proportions can be flagged as significant on samples of
n=5 — directly contradicting the policy stated for the other tests.

Demonstration: `z_test_for_proportions(p1 = 0.20, n1 = 5, p2 = 0.80,
n2 = 5)` returns `p = 0.058` (not flagged in this case, but only
because it's right on the boundary — e.g. 1/5 vs 5/5 would flag).

**Fix:** Add the same `min_base` guard (lines 77, 140, 220) to all
three enhanced-metric significance functions. Return
`list(significant = FALSE, reason = "insufficient_base_or_unavailable")`
below threshold, consistent with the other tests.

### I3. NPS test uses conservative SE — understates real significance

**File:** [modules/tracker/lib/trend_significance.R:228-229](../lib/trend_significance.R)

```r
# Approximate standard error for NPS difference (using effective N)
# Using conservative estimate: SE = sqrt((10000 / n1) + (10000 / n2))
# This assumes worst-case variance for NPS scale
se_nps <- sqrt((10000 / current_eff_n) + (10000 / previous_eff_n))
```

The comment acknowledges the conservatism. For a realistic NPS scenario
(p_p = 0.5, p_d = 0.2 → NPS = 30 in W1; p_p = 0.4, p_d = 0.3 → NPS = 10
in W2; n=100 each), the conservative SE is ~14.1 vs the true
multinomial SE of ~11.4 — a ~24% over-estimate. Real changes get
quietly missed.

Closed-form for NPS on the -100..+100 scale (where p_p, p_d are
the promoter and detractor proportions):

```
Var(NPS) = 10000 * [p_p*(1 - p_p) + p_d*(1 - p_d) + 2*p_p*p_d] / n
        = 10000 * [(p_p + p_d) - (p_p - p_d)^2] / n
```

Both `p_p` and `p_d` are already computed and stored in
`wave_result$promoters_pct` / `wave_result$detractors_pct`
(statistical_core.R:310-321), so the change is local.

**Fix:** Replace the worst-case SE with the multinomial form above,
substituting `eff_n` for `n`. Add a known-answer test (e.g. compare
to `prop.test` on a 3-category sample) to lock the formula.

### I4. README architecture diagram is significantly out of date

**File:** [modules/tracker/README.md:64-84](../README.md)

The diagram lists 14 files in `lib/`. The actual directory has 21 R
files plus two subdirectories (`html_report/`, `validation/`). Missing
from the diagram: `generate_config_templates.R`, `tracker_output_banners.R`,
`tracker_output_extended.R`, `tracking_crosstab_engine.R`,
`tracking_crosstab_excel.R`, `html_report/` (12 files), `validation/`
(1 file).

A new developer reading the README will assume the module is half its
real size and miss the HTML/preflight subsystems entirely.

**Fix:** Regenerate the diagram from a `tree` (or hand-write it) and
add one-line purposes for each of the new files. Consider grouping
under headings like "Output writers", "HTML report", "Preflight" so
the wall of files stays readable.

### I5. Duplicate, drifting README — single source of truth violated

**File:** [modules/tracker/README.md](../README.md) (v10.2, March 2026)
and [modules/tracker/docs/01_README.md](01_README.md) (v10.1, December 2025)

The two files have the same purpose and overlapping content but
differ — the docs/ copy is 14 weeks stale, missing the entire Stats
Pack section and the v10.2 entry. Pattern repeats across the doc pack:

| File | Version reported | Date |
|------|------------------|------|
| `README.md` | v10.2 | 21 March 2026 |
| `docs/01_README.md` | v10.1 | 28 December 2025 |
| `docs/02_TRACKER_OVERVIEW.md` | v10.0 | 22 December 2025 |
| `docs/03_REFERENCE_GUIDE.md` | v10.0 | 22 December 2025 |
| `docs/05_TECHNICAL_DOCS.md` | v10.1 | 28 December 2025 |
| `docs/06_TEMPLATE_REFERENCE.md` | v10.0 | 22 December 2025 |
| `docs/07_EXAMPLE_WORKFLOWS.md` | v10.0 | 22 December 2025 |
| `docs/USER_MANUAL.md` | v2.3 | February 2026 |
| `docs/CODE_INVENTORY.md` | v10.1 | 8 March 2026 |

Five of eight docs are pinned to v10.0/v10.1 while the module is on
v10.2. USER_MANUAL.md uses a completely separate version scheme,
making it unclear which is canonical.

**Fix:** Pick one of: (a) delete `docs/01_README.md` and have the
top-level `README.md` cross-link into `docs/`; or (b) make `docs/01_README.md`
a symlink. Then either bump every doc's footer to v10.2 with current
date, or drop per-doc versions in favour of a single VERSION constant
+ git history. USER_MANUAL.md should adopt the module version.

### I6. Broken `04_USER_MANUAL.md` links across 4 documents

**Files:** [README.md:109](../README.md), [docs/01_README.md:109](01_README.md),
[docs/02_TRACKER_OVERVIEW.md:145](02_TRACKER_OVERVIEW.md),
[docs/02_TRACKER_OVERVIEW.md:175](02_TRACKER_OVERVIEW.md),
[docs/07_EXAMPLE_WORKFLOWS.md:516](07_EXAMPLE_WORKFLOWS.md)

Five clickable links to `04_USER_MANUAL.md`. The file is `USER_MANUAL.md`
(no `04_` prefix). Every link 404s.

**Fix:** Either rename `USER_MANUAL.md` → `04_USER_MANUAL.md` to match
the numbered scheme, or update the five links to point to `USER_MANUAL.md`.
The numbered scheme is the convention elsewhere in `docs/`, so rename
is the lower-friction choice.

### I7. No `lintr` configuration — automated style gate cannot run

**File:** project root (no `.lintr` file)

`lintr` is not installed and there's no `.lintr` config to define
ruleset. The pre-commit checklist in CLAUDE.md mentions
`styler::style_file()` but there's no enforced gate. Style drift is
already visible in places (inconsistent comment headers, mixed
function-naming styles across older and newer files).

**Fix:** Add `lintr` and `styler` to `renv.lock`, create a project-level
`.lintr` with the team's preferred ruleset (line length, naming, no
`T`/`F`), and add a `make lint` (or equivalent) target. This is one-time
setup, not a per-finding fix.

---

## MINOR

### M1. README "Templates" section misdirects users

**File:** [modules/tracker/README.md:118-121](../README.md)

> Template files are located in the `templates/` subfolder

They're at `docs/templates/`. A user following the README will get
"No such directory."

**Fix:** Change "`templates/` subfolder" → "`docs/templates/` subfolder".

### M2. No regression test for the "same Δ, different SD → different significance" invariant

**File:** [modules/tracker/tests/testthat/test_statistical_core.R](../tests/testthat/test_statistical_core.R)

The CCS anomaly is the kind of "looks wrong but is right" thing that
will be flagged again. There's no test that locks in the invariant
("mean1=7.0 sd1=3.2 n=100, mean2=6.1 sd2=3.3 n=100 → NOT sig" vs
"mean1=8.1 sd1=2.0 n=100, mean2=7.3 sd2=2.1 n=100 → sig").

**Fix:** Add a `test_that("t_test_for_means is variance-sensitive: ...")`
block that pins both scenarios with `expect_false(...$significant)` and
`expect_true(...$significant)`. Cheap insurance.

### M3. No tests for `perform_significance_tests_*` wrapper family

**File:** [modules/tracker/tests/testthat/](../tests/testthat/) — no
test file targets `perform_significance_tests_means`,
`perform_significance_tests_proportions`, `perform_significance_tests_nps`,
or the four enhanced variants.

Coverage is on the inner `t_test_for_means` / `z_test_for_proportions`
only. The eff_n propagation, min_base gating, and fallback paths that
caused I1 + I2 are unguarded by tests.

**Fix:** Add `test_perform_significance_tests.R` exercising each
wrapper with synthetic `wave_results` — covering: eff_n properly
propagated, eff_n NULL falling back to n_unweighted, min_base gating,
unavailable wave handling.

### M4. `is_significant` minor fragility on empty lists (acknowledged in test)

**File:** [modules/tracker/lib/statistical_core.R:37-41](../lib/statistical_core.R),
[modules/tracker/tests/testthat/test_statistical_core.R:81-97](../tests/testthat/test_statistical_core.R)

Tests at lines 81-97 wrap the call in `tryCatch` and use
`expect_true(TRUE)` to "document" the case where `is_significant(list())`
errors. The fragility is real but harmless given current call sites
always populate `$significant`. The test pattern is vacuous though —
`expect_true(TRUE)` always passes.

**Fix (low priority):** Add a `!is.null(sig_test$significant)` short-
circuit to `is_significant`, and replace the documenting-pass test with
`expect_false(is_significant(list()))`.

### M5. `0.95` confidence interval critical value hardcoded

**File:** [modules/tracker/lib/statistical_core.R:253-254](../lib/statistical_core.R)

```r
ci_lower <- w_mean - 1.96 * se
ci_upper <- w_mean + 1.96 * se
```

`1.96` is hardcoded for 95% CI rather than `qnorm(1 - alpha/2)` from
config. If anyone ever switches `DEFAULT_ALPHA` to 0.10, the CIs become
inconsistent with the significance threshold.

**Fix:** `z_crit <- qnorm(1 - alpha / 2)` derived from `alpha`. Trivial.

---

## OBSERVATIONS

### O1. Five files over 1000 LOC — cohesive but at the limit

| File | Lines |
|------|-------|
| `trend_calculator.R` | 1525 |
| `tracker_dashboard_reports.R` | 1325 |
| `wave_loader.R` | 1310 |
| `validation/preflight_validators.R` | 1153 |
| `run_tracker.R` | 1110 |

Each is a single coherent concern. The v10.1 extraction (Dec 2025)
already pulled four sub-modules out — further splitting risks
ping-ponging readers across files. Note rather than action.

### O2. Pooled vs Welch t-test — pooled is fine here

`t_test_for_means` uses pooled (equal-variance) — a methodological
choice. Welch (`var.equal = FALSE`) is more robust under unequal
variances and is the default in `t.test()`. At n=100 per wave and the
SD ranges seen in real tracker reports the difference is <0.001 in
p-value (verified). Not changing — but worth noting that if anyone
asks "why pooled?", the answer is "convention + negligible difference
at tracker sample sizes", not "we considered Welch and rejected it."

### O3. Local-only deployment — security surface is minimal

No network calls, no `system()`/`shell()`, no secrets in code, no
SQL. File-path handling in `resolve_data_file_path` walks up 3
directories looking for a match — fine for trusted operators
(consultants running their own laptops), would be a path-traversal
vector if this ever became a web service. Document this implicit trust
model if the module ever heads that direction.

### O4. Pre-TRS `stop()` fallbacks are correctly justified

The two `stop()` calls (`00_guard.R:100`, `run_tracker_gui.R:46`) are
bootstrap-time fallbacks used only when the shared TRS infrastructure
fails to load. Both throw a `turas_refusal` condition object so handlers
that catch by class still work. Code comments explain the rationale
clearly. No change needed.

### O5. Dead code is cleanly marked

`trend_calculator.R` has five `[REMOVED]` blocks (lines 55, 247, 318,
503, 508) where v10.1 / Phase 4 extraction stripped out superseded
functions and left a comment pointing to the replacement. This is the
right pattern — keeps `git blame` honest without leaving the actual
dead code around.

---

## Verdict

**DEPLOY WITH CONDITIONS.**

The CCS-vs-Cleanliness pattern that triggered this review is correct
behaviour — the t-test is doing exactly what it should. No CRITICAL
issues exist. The 1855-test suite is green.

However, the module ships **three statistical correctness issues that
under-power or over-power significance tests in narrow but real
configurations**: I1 (eff_n lost for non-mean metrics → false
positives), I2 (no min_base check on enhanced-metric tests → tests run
on n=5), I3 (NPS conservative SE → false negatives). None of these are
showstoppers — the CCS report is unaffected because it uses mean — but
all three should land on a `fix/tracker-sig-tests` branch before the
next significant release, paired with M2 + M3 to lock the invariants
in tests.

Documentation issues (I4, I5, I6) and the lint gap (I7) are housekeeping
that would take an hour or two and dramatically improve the
new-developer experience.

I'd personally deploy this module as-is for the current CCS
engagement. I would *not* sign it off as "production-ready, hand it to
the next maintainer" until I1–I6 are addressed.
