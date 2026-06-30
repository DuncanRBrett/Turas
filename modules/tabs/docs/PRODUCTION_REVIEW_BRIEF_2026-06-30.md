# Production Review Brief — tabs v2 + tracker reporting (pre-merge)

**For a NEW, INDEPENDENT session. Use the `duncan-production-review` skill.**
**Goal: confirm quality has not drifted across a large body of work, then merge to `main`.**

---

## 1. What you are reviewing

Branch **`feature/tabs-qualitative-tab`** — **41 commits ahead of `main`** (base `0093d7b0`),
**NOT pushed**, ~5,400 insertions. The work was built across many sessions; Duncan wants a
production-readiness pass before it merges to `main`.

Scope = the v2 reporting work on this branch:

1. **The Qualitative tab (the bulk — new subsystem).** Ingests pre-coded comment workbooks →
   themes-as-quant + a verbatim island. R: `qual_workbook_reader.R`, `qual_workbook_io.R`,
   `qual_assemble.R`, `qual_island_builder.R`, `qual_quant_layer.R`, `qual_report.R` (+ wiring in
   `run_crosstabs.R`, `build_report_v2.R`, `template.html`). JS: `27q_qualitative.js` (917 lines).
   Features: ResponseID join into the main report, closed↔open 💬 jump, shortlist + Excel export,
   salience reframe, sentiment filter, select-to-highlight, diverging sentiment chart, and the
   theme×banner crosstab (latest).
2. **Composite audience filter as the single control.** The per-tab "Filter comments" facet row was
   retired — the global filter bar (which ANDs across conditions) drives the comments. Confirm the
   removal is clean (no dead code/CSS/state) and filtering still works.
3. **Disclosure control (re-identification protection) — SECURITY-SENSITIVE, scrutinise hardest.**
   `21d_disclosure.js` + config `min_reporting_base` (`crosstabs_config.R`, serialized in
   `data_layer_writer.R` only when >1 so existing reports are byte-identical). Below the threshold:
   comment demographic tags hidden, filter-bar warning, Excel export blanks tags, crosstab columns
   below k suppressed. Verify the guard actually protects (the SACS staff survey, n=167, ships with
   `min_reporting_base: 10`).
4. **Theme×banner crosstab** (in the Qualitative tab). Client-side from the joined records; column
   base = commenters; salience + net sentiment; Salience/Sentiment-skew + Counts toggles; vs-the-rest
   sig via `stats.propZ`; inline insight + pin-to-Story.
5. **Tracker reporting changes.** `27u_summary.js` / `27t_tracking.js` — the tracking Summary-card
   click now jumps to the clicked metric + cut (`d55336b0`). `tracking_nav_tests.mjs` (108 new lines).

---

## 2. Independence — read this first

Per Duncan's standing rule ([[feedback_independent_review]]): **you are independent of the sessions
that built this.** Do NOT take the build notes / commit messages / memory claims as evidence that
something works — **verify each claim yourself** (read the code, run the tests, trace the logic). Run
the **full** production-review process; do not skip phases because the work "looks done" (past reviews
have drifted by skipping required phases). The building sessions believed the work was correct — your
job is to find where that belief is wrong.

High-value places to be skeptical:
- **The disclosure control.** Is it genuinely safe, or does a path leak identity (a cut that slips
  under the threshold but still shows tags; the export; the crosstab; the jump; a Save-copy)? Is the
  threshold applied consistently everywhere identity can leak?
- **TRS compliance** in the 7 new R files — any `stop()` / silent failure / non-structured error?
  Console visibility for Shiny ([[feedback_launch_turas_verification]])?
- **The additive principle** — a qual failure must never touch the main Crosstabs/Excel outputs
  (the `run_crosstabs.R` hook is tryCatch-wrapped — confirm).
- **The crosstab math** — salience/net/sig and the column-base vs mentioner-base toggle. Hand-check
  against `qual_quant_layer.R` and a small fixture.
- **Dead code / drift** from the facet retirement and the many refine commits.

## 3. How to verify (the suites)

JS (node, from `modules/tabs/lib/html_report_v2/`): `node tests/qual_tests.mjs` (59),
`tests/disclosure_tests.mjs` (12), `tests/tracking_nav_tests.mjs`, plus `composite/portrait/takeout`.
R (from repo root): `Rscript -e 'testthat::test_file("modules/tabs/tests/testthat/<f>.R")'` for the
`test_qual_*` suite (reader 69 / io 17 / assemble 16 / island 35 / quant 16 / report 12 / join 44),
`test_report_v2_bundler.R` (25), `test_data_layer_writer.R` (186). A full bundle syntax check:
bundle via `bundle_report_v2_js()` and `node --check`.
**Generated HTML is verified by Duncan via `launch_turas` — never `preview_start` the tabs report,
never headless-run the pipeline on OneDrive data.** ([[feedback_tabs_v2_regen_via_launch_turas]])

## 4. Deliberate boundaries — do NOT re-flag these as defects

- Theme questions are **deliberately not merged** into the main client-facing Crosstabs list (would
  pollute it + fight the salience reframe). The crosstab lives in the Qualitative tab on purpose.
- Cell-level click-through (read one column×theme's comments) is a **noted follow-up**; v1 is
  row-level (theme in the current audience).
- **Complementary cell suppression** for the MAIN crosstab/dashboard/differences tables is the **next
  increment** — `disc.cellOk()` is built but not yet wired into those renderers. The qual identity
  side + the crosstab column suppression are done.
- Theme×banner sig is **vs-the-rest** (not pairwise letters) — intentional, robust for overlapping
  banners.
- Export-to-Excel for the crosstab is a noted follow-up.

## 5. Outcome

Report findings most-severe first. Fix what's real (with tests), confirm green, **then merge to
`main`** (Duncan's call on push). If the disclosure control has any hole, that is a blocker.
