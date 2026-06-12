# Production Review: SACAP Report v2 (data-centric renderer prototype)

**Date:** 2026-06-12
**Branch/Version:** `review/report-v2-production-2026-06` (off `feature/report-data-layer`)
**Reviewer:** Claude (duncan-production-review skill, independent session)
**Language/Stack:** Vanilla JS (no-dependency browser engine) + R build script + Python pipeline/verifier
**Scope:** `prototypes/report-redesign/fable/v2/` plus the shared v1 engine files it
bundles (`00_namespace`, `01_format`, `03_svg`, `13_zip`, `14_pptx_parts`) and
`tests/verify_pptx.py`. No live Turas module touched.

## Verification Gates

| Gate | Command | Before review | After review |
|------|---------|---------------|--------------|
| Build | `Rscript build.R` | PASS — 1.97 MB (< 2 MB budget) | PASS — 1.97 MB |
| v2 suite | `node tests/run_tests_v2.mjs` | PASS — 32 tests | PASS — **35 tests** |
| v1 shared gate | `node ../tests/run_tests.mjs` | PASS — 21 tests | PASS — 21 tests |
| Golden parity | `node tests/golden_parity.mjs` | PASS (2,562 cells exact; sig agreement printed only) | PASS (**85% sig floor now enforced**; measured 89.6%) |
| In-browser selftest | `#selftest` | PASS — 15/15, console clean | PASS — 15/15, console clean |
| Structure | within v2 suite | PASS — ≤300 active lines / SIZE-EXCEPTION | PASS |

Standards sweep: zero TODO/FIXME/HACK markers; `console.error` appears only in
error paths (the project's mandated console visibility); no hardcoded paths;
`stop()`-equivalents absent (boot refusals use the TRS-style fatal panel with
codes).

## CRITICAL

None found. Golden parity for the published 2025 tables is exact (2,562
category cells, 0 mismatches, 0 base mismatches), published views show
published numbers and sig letters verbatim, and the settled sig methodology
(pooled z with expected-count ≥ 5 precondition, low-base exclusion; Welch on
the single distribution-derived SD source) is implemented as documented —
verified line-by-line in `21_stats.js`, `21c_confidence.js`, `22_model.js`,
`22w_waves.js` and `27t_tracking.js`. The Wilson port matches
`modules/confidence/R/04_proportions.R` verbatim; `TR.trk.sdAt` delegates to
`TR.waves.scoreMap`/`sdFromPairs` everywhere (the SD source is not forked).

## IMPORTANT (all fixed in this review)

### I1. Interval method notes claimed "(Wilson)" on z·SD/√n surfaces — *(Fixed, `e614c76e`)*
**File:** `src/js/21c_confidence.js:87` + call sites `30x_exhibit.js:322`,
`25_cards.js:639`, `29_export.js:521`, `30_story.js:265`
`TR.conf.methodNote()` returned "95% SI (Wilson)" unconditionally. A pinned
NPS/Index/mean Visualise view draws its bands from z·SD/√n on the
distribution-derived SD — its story card, present view and PPTX context line
mislabelled the method on exported artifacts. Crosstab interval views mix
Wilson (proportion rows) with z·SD (Index rows) under a pure-Wilson footnote.
The gate test at `run_tests_v2.mjs` even asserted the wrong label, locking the
bug in. **Fix:** `methodNote(kind)` (props/means/mixed); crosstab surfaces
derive the kind from the model, series exhibits from their metrics; tests
updated to require the honest label and forbid "Wilson" on mean-only pins.

### I2. PPTX tables truncated silently to fit the slide — *(Fixed, `ee926de4`)*
**File:** `src/js/29_export.js` (`slideForModel`, `exhibitSlide`, `matrixSlide`)
All three sliced `matrix.body` to the slide's row budget with no indication —
a 30-row index heatmap exported as a 15-row table that read as complete.
**Fix:** shared `fitMatrix()` replaces the last visible row with
"… +N more rows — see the full report" whenever anything is dropped; gate test
covers truncated and untouched cases.

### I3. Pinned crosstab cards did not reproduce the on-screen table — *(Fixed, `0d3d9bc6`)*
**File:** `src/js/30_story.js:57-72` (capture), `:201-209` (render)
`pinCurrent` captured chart state (type/kind/cols/hiddenChartRows/intervals)
but dropped `rowScope`, `sort`, `hiddenRows`, `hiddenCols` and the dual-sig
setting — a user who hid noise rows/columns or sorted the table got the full
default table back on the story card, in present mode and in the PPTX,
contradicting "story cards show exactly the pin" (guardrail 10). **Fix:** the
pin now carries all five; story `modelFor` passes them through
`model.forQuestion` (which already supported every one). Older pins lack the
fields and keep their historic full-table render (tested).

### I4. Sig-letter agreement was reported but never asserted — *(Fixed, `f5d62867`)*
**File:** `tests/golden_parity.mjs:90`
The README documents ~90% agreement with the published ▲ letters; the gate
printed the rate (89.6% today) but `hardFail` ignored it — an engine
regression to 60% would pass. **Fix:** agreement below 85% now fails the gate.

### I5. Negative values produced invalid/missing bars in SVG dist charts — *(Fixed, `f5d62867`; verifies known item 4)*
**File:** `src/js/23z_charts.js` (`columnChart:74`, `dotChart:264`, `pieChart:183`)
A negative NPS headline in a composite/series exhibit reached `columnChart`
as a negative rect height — invalid SVG that browsers silently drop, leaving
a floating label below the axis. Dots drew off-plot; a pie would arc
backwards. (`barChart` already clamped; diff rows never chart in crosstabs —
`chartRows` excludes them — so the exposure is exhibits only; native PPTX
charts pass raw values and were always correct.) **Fix:** column/dot/pie now
floor at the axis exactly like `barChart`; value labels keep the true negative
number. Documented in README known limitations; proper signed axes are a
production item. Gate test added.

## MINOR

### M1. Present mode crashed on a stale pin — *(Fixed, `0d3d9bc6`)*
`renderPresent` (`30_story.js:550`) called `model.code` without the null guard
that `itemHtml` and the PPTX path both have. A saved story referencing a
question absent from the current report (real in wave-on-wave production)
threw mid-presentation. Now renders an "Unavailable exhibit" slide.

### M2. Crafted/typo'd hash filters silently zeroed every base — *(Fixed, `9202ddfb`)*
`decodeHash` (`20_data.js`) accepted `#filter=Q999:1` or out-of-range row
indexes; `stats.mask` then matched nothing and every table showed base 0 with
no explanation. Filters now validate against the parsed data (question must
exist, rows must be its category rows).

### M3. One unguarded document-level listener — *(Fixed, `0d3d9bc6`)*
`wireTopLevel` (`24_shell.js:135`) registered document/window listeners with
no singleton guard (safe only because boot runs once). Guard added per
guardrail 1. All other document-level listeners were verified guarded
(colmenu closer flag; present-mode add/remove pair).

### M4. Added-slide `<img src>` not escaped — *(Fixed, `9202ddfb`)*
`32_report.js:90` interpolated `slide.image` raw into the attribute. The only
writer is `FileReader.readAsDataURL` (safe format) and the sidecar import does
not touch report state, so this was not exploitable — escaped anyway because
stored state outlives the code that wrote it.

### M5. Custom banner sig letters repeat after 26 columns — *(Documented, not fixed)*
`21_stats.js:110` assigns letters modulo 26. Unreachable with SACAP data
(largest banner: 17 columns + Total) and the live-report convention also uses
single letters. Production item if a custom banner can ever exceed 26
categories.

### M6. Visualise Y-axis overrides do not clip the data line — *(Documented, not fixed)*
`23za_trend.js`: user-set `yMin`/`yMax` clamp the CI band but not the series
line/points; values outside the override range draw outside the plot region
(clipped at the SVG edge). User-initiated, cosmetic; clipping the line would
itself misrepresent values. A `clipPath` is the clean production fix.

### M7/M8. Documentation drift — *(Fixed, docs commit)*
README test count (30 → 35), artifact size (1.96 → 1.97 MB), no statement
that `data/*.json` is committed (a cold-start reader thinks they need the
source workbooks to build), PPTX meta-line wording, handover STATUS block.
Round 8 section added.

## OBSERVATIONS

### O1. Sig-letter agreement 89.6% — assessed acceptable
Published views show published letters verbatim, so engine letters surface
only on filtered/custom views, where no published letters exist to disagree
with. The divergence is concentrated in borderline cells (engine slightly
less conservative; the published report's exact engine settings are not
recoverable from its HTML). With the new 85% floor (I4) a regression cannot
slip through. Revisit only if production comparisons against
`modules/tabs/lib/weighting.R` outputs (which the data layer will carry)
show systematic bias.

### O2. Documented statistical divergences verified as documented
z-based mean intervals vs `05_means.R` t (< 1.5% at n ≥ 70); Welch on rounded
published distributions (production uses raw scores via
`modules/tracker/lib/trend_significance.R`); weighted effective-n not wired
(published bases are unweighted). All stated in README/handover; none
misrepresented in the UI.

### O3. The two alias-map judgment calls check out
`pipeline/wave_title_aliases.json` `_judgment_calls`: the Student Support &
Development Team renames (wellness/counselling wording 2025; Student Services
→ SSDT). Both are same-battery-slot/same-metric calls, clearly annotated.
**Duncan should still eyeball these two before presenting long trends on
those metrics** — analyst sign-off, not a code property.

### O4. Security posture is sound
Full adversarial escaping audit: `escapeHtml` covers all five metacharacters;
every user-content render path (insights, notes, annotations, report fields,
imported sidecar JSON, prompt input) escapes at render time; save-copy embeds
state via `textContent` plus `</` hardening, so a crafted insight cannot break
out of the saved file's state island; URL-hash values are never rendered.
localStorage reads/writes are all try/catch-guarded with island-only
fallbacks; report-state quota failure surfaces a toast.

### O5. Scope decisions verified as intentional (not bugs)
Tracking shows published figures only (filters deliberately don't apply;
noted in UI). The URL hash carries tab/question/banner/filters/toggles —
per-question hidden-row/sort maps are deliberately session-local; the
saved-copy carries insights/story/report sections, not live workspace tweaks.
Differences and Dashboard recompute under the active report filter (the
documented "filter the whole report" behaviour).

### O6. Smaller notes
NPS history has no distribution-recompute fallback (Index does); no wave
needed one — now in README. PPTX workbook series letters cap at column Z
(unreachable: max 18 chart columns). `verify_pptx.py` `has_table` has a
redundant always-truthy clause (works correctly). Story import dedup is
JSON.stringify-keyed (key-order sensitive; duplicate-tolerant, harmless).
11 of 24 v2 files carry SIZE-EXCEPTION — the 300-line rule is now more
exception than rule; acceptable for a prototype, revisit at productionisation.

## What Duncan should manually check

1. **PowerPoint open test** (the one thing no gate can prove): open
   `tests/tmp/v2_story.pptx`, `v2_exhibit.pptx`, `v2_segpin.pptx` (all
   regenerated by this review's gates) — "Edit Data" must open Excel on BOTH
   charts of the exhibit slides; charts must survive the workbook closing.
2. **The two alias judgment calls** (O3) before presenting long trends on
   those metrics.
3. A quick `launch`-style browser pass over the new wording: pin an NPS
   Visualise view with bands and confirm the story card / PPTX meta now says
   "95% SI (z·SD/√n) bands"; pin a sorted, column-hidden crosstab and confirm
   the story card mirrors the screen.

## Verdict

**DEPLOY (as the prototype gate for the production path).**
No correctness defect survives: published numbers are exact, the statistical
layer matches its documentation, and the five IMPORTANT findings — all
honesty/robustness issues in exports and pins, not computation errors — are
fixed with tests. The remaining open items are the documented prototype/
production divergences (synthetic microdata, z-vs-t, rounded-distribution
Welch) that disappear by design when tabs emits the real data layer, plus the
manual PowerPoint open test. The codebase is disciplined (consistent escaping,
guarded persistence, pure renderers, honest UI copy) and a newcomer can build
and verify it from the README in under five minutes.
