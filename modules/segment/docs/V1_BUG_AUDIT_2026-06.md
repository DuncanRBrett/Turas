# Production Bug Audit: Segment Module — Classic (v1) Report

**Date:** 2026-06-16
**Branch:** `fix/segment-v1-hardening` (off `main`, building on `fix/segment-rules-subscript`)
**Reviewer:** Claude (production-review skill)
**Stack:** R / Shiny analytics module
**Goal:** Identify ALL bugs in the classic (v1) segmentation report so it is 100%
solid. Focus class: a report section/chart that **silently drops** because an
error is swallowed (`tryCatch → NULL`) or a data key/shape mismatch.

## Verification gates

| Gate | Command | Result |
|------|---------|--------|
| Test suite | `testthat::test_dir(modules/segment/tests/testthat)` | PASS — 1026 pass / 0 fail / 1 warn / 1 skip |
| Reproduce-then-fix | each fix reproduced as a crash, then re-run clean | PASS |

The 1 remaining warning is pre-existing test hygiene (see M2). Baseline before
this audit was 1016 pass; +10 are the new regression tests in
`tests/testthat/test_html_robustness.R`.

---

## The silent-drop mechanism (why these hide)

The final-mode orchestrator (`R/00_main.R`) wraps each enhanced analytic in
`tryCatch(..., error = function(e) NULL)` (rules, cards, stability,
vulnerability, golden questions, exec summary — lines 316–435) and the HTML
build in another (line 544). So **any crash in a feeder function makes its whole
section vanish with no user-visible error.** Separately, the page builder gates
sections on data keys; a wrong key hides a section even when its data exists.
Every finding below is one of those two mechanisms.

---

## CRITICAL
None outstanding. (The two original crashers — the rules `yval2` subscript bug
and the cards wrong-key/shape bug — were fixed earlier on this branch lineage:
commits `41da3d07`, `09967db9`.)

## IMPORTANT (all fixed in this audit)

### I1. Charts crash on a partial `question_labels` vector → silently drop
**File:** `lib/html_report/05_chart_builder.R:268, 409, 1064`
`question_labels` is a *named character vector*. `ql[[v]]` on a variable whose
name isn't present throws `subscript out of bounds`. Any config whose
`question_labels` doesn't cover **every** clustering variable crashes the
Variable Importance, Profile Heatmap and Golden Questions charts — each then
silently drops (chart `tryCatch → NULL`). Reproduced: crash confirmed with
labels for 2 of 3 variables.
**Fix (applied):** `lbl <- if (v %in% names(ql)) ql[[v]] else NULL` at all three
sites. Re-verified: renders, no crash.

### I2. `generate_headline()` crashes on an all-NA variable → Cards section drops
**File:** `R/07_cards.R:162`
`avg_mean <- mean(stats$means)` (no `na.rm`); if a segment has an all-NA
clustering variable, `avg_mean` is `NA`, and `if (avg_mean > overall_avg + 1)`
throws `missing value where TRUE/FALSE needed`. The Segment Action Cards section
then silently drops (cards `tryCatch → NULL`). Reproduced.
**Fix (applied):** `na.rm = TRUE` on both means + a `finite_pair` guard on the
sentiment branches + `isTRUE()` on the trait-direction comparison.

### I3. About panel always prints "Average silhouette: 0.000"
**File:** `lib/html_report/03c_section_builders.R:1915`
Read `html_data$diagnostics$silhouette_avg`, but the transformer
(`01_data_transformer.R:70`) sets `avg_silhouette`. The wrong key resolves to
`NULL %||% 0` → always `0.000`. (Same wrong-key class as the rules/cards bugs.)
Grep confirms every other diagnostics read uses the correct key; no other
final-mode siblings.
**Fix (applied):** `diagnostics$avg_silhouette`.

### I4. Assignments file can carry NA segment names (the tabs-banner join table)
**File:** `R/09_output.R:78`
`segment_name = segment_names[clusters]` yields `NA` for any NA cluster id
(flagged outlier) or out-of-range id, silently corrupting the very file used to
cross-tab survey questions by segment in the tabs module. (Defensive — not
confirmed reachable on the default path where k-means assigns every row, but the
output is Duncan-critical and the guard is zero-risk.)
**Fix (applied):** map NA names to `"Unassigned"`; raw id preserved in
`segment_id`.

## MINOR

### M1. Heatmap shows `NA` axis labels if `segment_names` is shorter than k (fixed)
**File:** `lib/html_report/05_chart_builder.R:403` — the `%||%` fallback only
fires when `segment_names` is NULL, not when it's short, so `seg_names[k]` is
`NA` (R returns `NA`, it does **not** crash — an audit over-claim corrected).
**Fix (applied):** explicit `length(...) >= k` check at both heatmap sites.

### M2. `validate_input_data` leaks a base-R coercion warning on non-numeric input
**File:** `tests/testthat/test_utilities.R:146` exercises non-numeric columns;
the validator emits an uncontrolled R warning (the non-numeric *is* detected).
Test hygiene / TRS-cleanliness. Not fixed (outside the report pipeline; pre-existing).
**Fix (suggested):** detect non-numeric explicitly and refuse before any numeric
op, or `expect_warning()` in the test.

## OBSERVATIONS (investigated — NOT bugs)

- **`variable_importance$variable %||% character(0)` (03c:1914)** — flagged by the
  audit as a NULL-crash; it is **not**. In R, `NULL$variable` returns `NULL`
  (the "`$` on atomic" error only fires on real atomic vectors), so `%||%`
  protects it. Verified.
- **k = 1 / k = 0 crashes** (silhouette, vulnerability, exec-summary) — flagged
  CRITICAL by the audit but **unreachable**: `R/00a_guards_hard.R:270` enforces
  `k_fixed >= 2` and `k_min < k_max`. No fix needed.
- **Golden-questions cumulative `0/0`** (`06_rules.R:687`) — `sum(sub_conf)` is
  the RF OOB count, always > 0 for a fitted model; not reachable in practice.

## SUSPECTED — needs a focused verification pass (NOT yet traced/fixed)

These were surfaced by the audit but **not reproduced**, and several initial
CRITICAL claims proved false above — so treat as leads, not confirmed bugs.
They are in the secondary report modes (the standard final-mode report is now
solid):

- **Exploration mode** (`06_exploration_report.R`): NULL `metrics_df` / failed-k
  handling — some `is.null` return-guards already exist; needs a trace.
- **Combined / multi-method** (`07a_combined_builders.R`): agreement-matrix
  silently skips a method with missing clusters; possible `diag$ch_index`
  wrong-key in the combined diagnostics (combined mode uses a different
  diagnostics shape than final mode — verify before trusting).
- **Silent content loss (not crashes):** profiling drops constant variables
  (`05a_profiling_stats.R`) and `.extract_variable_importance` returns `NULL`
  (`01_data_transformer.R`) without logging — content vanishes with no warning.

## Verdict

**DEPLOY (final-mode report) — with a follow-up pass on exploration/combined.**

The standard final-mode classic report is now hardened against the silent-drop
class: every section that can be generated will render, and the four confirmed
defects (chart crash on partial labels, cards crash on NA variable, the 0.000
silhouette, the banner-file NA names) are fixed with regression tests. The
exploration and combined modes carry audit-flagged suspects that need a focused
verify-and-fix pass before they meet the same bar.
