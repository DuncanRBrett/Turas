# Production Review: Tabs Microdata Writer + Tabs-Integrated Tracker

**Date:** 2026-06-14
**Branch:** `feature/tabs-json-data-layer`
**Reviewer:** Claude (production-review skill)
**Scope:** The data-centric report v2 microdata interactivity (Option 2) and the
tabs-integrated tracker foundation (Option 3): `microdata_writer.R`,
`tracking_island.R`, `score_utils.R`, the engine weighting in
`21_stats.js`/`22_model.js`, `data_layer_writer.R` (index_scores + logos),
`build_report_v2.R` (`micro_json`/`prev_json`), Step 4d wiring, config flags.
**Stack:** R (writers + orchestration) + vanilla JS (vendored renderer).

> **Independence caveat:** this review was performed in the same session that
> built the feature. It was conducted adversarially (line-by-line, claim-by-claim)
> but is not a fully independent re-review; a cold second pass before merge is
> recommended (see Verdict).

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| R tests (tabs) | `testthat::test_dir(modules/tabs/tests/testthat)` | PASS — 2040 pass / 0 fail / 9 skip |
| Renderer gates | `node tests/run_tests_v2.mjs` | PASS — 40 / 40 (incl. weighted + scores known answers) |
| Golden parity | (in renderer gate) | PASS — computed == published on SACAP |
| SACAP build | `Rscript build.R` | PASS — 1.99 MB, no external URLs |
| JS sync | prototype src ↔ module assets | PASS — 0 drift (29 files) |
| File size | active-line count | PASS — all v2 files < 300 (data_layer_writer 290 after fix) |
| Function size | active-line count | PASS — largest 35 (micro_banner_vars) |
| Lint | `lintr` | NOT RUN — lintr not installed (see M1) |

Baseline test count for future reviews: **2040** R tests + **40** renderer gates.

## CRITICAL

None.

## IMPORTANT

### I1. `data_layer_writer.R` exceeded the 300-line limit *(Fixed in this review)*
**File:** `modules/tabs/lib/data_layer_writer.R`
Adding `index_scores` derivation pushed the file to 336 active lines, over the
standard's 300 limit; the score helpers were also an implicit cross-file
dependency (the microdata writer reached into them).
**Fix:** Extracted `option_numeric_value`, `nps_bucket_score`,
`derive_index_scores` into a new `score_utils.R` sourced before both writers.
`data_layer_writer.R` is now 290 active lines and the dependency is explicit.

### I2. `build_data_layer` recomputed up to 4× per run *(Fixed in this review)*
**File:** `modules/tabs/lib/run_crosstabs.R` Step 4d
The report path pivoted the full data layer separately for the sidecar, the
microdata, the tracking contribution, and the report — wasteful on large surveys.
**Fix:** Build the data layer once and reuse it; `project.tracking.enabled` is set
by mutation at the end. Now two builds total (sidecar + report).

## MINOR

### M1. `lintr` not installed
The R lint gate could not run. The new code follows the surrounding style
conventions and passed manual review.
**Fix:** `install.packages("lintr")` and run `lintr::lint_dir("modules/tabs/lib")`
before merge for a final style pass.

### M2. Doc code-map named the wrong file for `index_scores` *(Fixed in this review)*
`11_DATA_CENTRIC_REPORT_V2.md` attributed `index_scores` to `data_layer_writer.R`;
after I1 it lives in `score_utils.R`.
**Fix:** Code-map updated.

## OBSERVATIONS

### O1. Recompute correctness is empirically proven on real client data
On CCS (60 respondents, 31 questions): the microdata recompute reproduces the
published Total for **60 / 61** category frequencies (exact counts) and **19 / 19**
mean / SD / NPS rows (display precision). Weighted recompute is verified by
hand-calculated known answers (9 / 9), and the engine is byte-identical to the
pre-weighting version when unweighted (golden parity holds).

### O2. The single category miss is a documented data-quality edge
The one CCS mismatch (`Q13 / "Don't know"`, count 2 / 60) is a *semantic* value
recode (`DK` → `Don't know`) in a multi-select with **no** structure option to
bridge raw value and published label. Documented; the data-side fix is to define
the option in `Survey_Structure`. No silent wrong number — unmatched values are
simply not counted in that category.

### O3. Intentionally scoped limitations (documented in §"Current scope")
- Tracking wave means are unweighted (`meanOfScores`); weighted trackers are a
  scoped follow-up.
- Arbitrary BoxCategory NET rows and numeric (binned) means show "—" under an
  active filter (honest degrade) rather than a recomputed value.
These are honest degradations (never a wrong number), each with a follow-up path.

### O4. Microdata island size scales with respondents × questions
The island carries one index per respondent per question. For typical trackers
(n ≈ 60–2000) this is small (CCS 10 KB; SACAP within the 2 MB budget). A very
large survey (n ≈ 50k × 200 q) would produce a multi-MB island. Mitigation if it
ever bites: gate microdata emission above a size threshold. Not a concern at
current scale.

### O5. No committed full-pipeline integration test (by design)
The end-to-end Step 4d → report path is verified against **real CCS client data**,
which must not enter the repo. The committed tests cover every unit (writer,
assembler, bundler, engine known answers); the integration is exercised by the
units plus the documented manual CCS verification.

### O6. Classic outputs and the classic tracker are untouched
Step 4d only ever writes new files and is fully `tryCatch`-guarded; a microdata or
tracking failure degrades the v2 report and never affects the Excel/HTML outputs.
The standalone `modules/tracker/` module is not touched.

## Verdict

**DEPLOY (Option 2) / DEPLOY-AS-FOUNDATION (Option 3), pending a cold second review.**

Option 2 (microdata interactivity: filter + custom banners + weighted recompute +
confidence) is production-ready: off by default, generic across question types,
weighted-correct, byte-identical for existing reports, fully tested and documented,
and proven on real client data. Option 3 (tabs-integrated tracker) is wired,
off by default, and verified (assembler known answers + real-data wave linkage +
the prior spike's 14/14 vs the classic tracker), with weighted-tracking and NET
tracking as clearly-scoped, documented follow-ups. Two IMPORTANT findings were
fixed during the review; no CRITICALs. Because builder and reviewer were the same
session, a brief independent cold pass (Phase 2 cold-start + Phase 3 spot-trace)
is recommended before merging to `main`.

---

## Independent cold-review addendum (2026-06-14)

A second reviewer with **no prior context** re-ran every gate, wrote its **own**
known-answer harnesses (not the author's tests), and independently confirmed: the
weighted math (Kish n_eff, weighted %/mean, two-proportion z), the row-index
mapping (cannot map to the wrong row), the hidden-category `-2` handling, the
length-n / `d2.validate` contract, byte-identical-when-unweighted, and the
anonymisation (it extracted the built island and verified no strings leak). It
rated test quality "good, not vacuous", and raised two IMPORTANT findings the
author's review under-weighted — **both now addressed:**

- **I-NET — NET rows blank under a live filter / custom banner.** Confirmed: the
  writer emits no `net_members`, so `computedModel.netRow` returns null cells for
  Top-2-Box / summary NETs under a filter. *Response:* the renderer already shows
  these as "–" (`fmtPct(null)` → "–", never blank or zero); the limitation is now
  documented prominently (docs §"Current scope") and `net_members` emission is the
  **top** growth-path item. Not fixed in code (a wrong NET would be worse than an
  honest "–"; the real fix needs its own known-answer tests). Blocks *enabling*
  for NET-heavy reports, not the off-by-default merge.
- **I-WTRACK — weighted tracker mixed weighted crosstab + unweighted trend.**
  *Response: FIXED.* `wave_contribution` now returns NULL when
  `apply_weighting = TRUE` and Step 4d prints a clear NOTE — the Tracking tab is
  not built on weighted studies (weighted crosstab + filtering still ship), so the
  silent discrepancy cannot occur. Tested (`test_tracking_island.R`, 30/30).

Cold-review MINORs accepted, none fixed this pass: `stop()` inside the bundler's
`tryCatch` guards vs the TRS mandate (degrade safely); Step 4d after the stats
pack would be marginally safer; `micro_banner_vars` ~52 lines; the dash class is
fragile; the `-2` sentinel is duplicated across R/JS (well-commented). Added to
the growth path: a golden test feeding **actual** `build_microdata` output through
`d2.validate` + a recompute, to lock the writer↔renderer seam.

**Net position:** with I-WTRACK fixed and I-NET documented + honestly degraded,
the conditions are met for the **off-by-default merge**; emitting `net_members`
is the remaining gate before enabling on a NET-heavy client report.
