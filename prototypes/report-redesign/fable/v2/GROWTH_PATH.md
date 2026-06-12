# Growth Path: SACAP Report v2 (data-centric renderer)

**Date:** 2026-06-12
**Current state:** A 1.97 MB self-contained HTML recreation of the full SACAP
2025 crosstabs report on the data-centric architecture — 79 questions,
2018–2025 tracking workspace, live filtering/custom banners from synthetic
microdata, sampling-aware confidence layer, story/pins/present, native PPTX —
gated by 35 v2 + 21 v1 node tests, golden parity and a 15-case in-browser
selftest.
**Stack:** dependency-free vanilla JS (24 v2 files + 5 shared v1 engine
files), R build script (jsonlite only), Python pipeline + PPTX verifier.

## Architecture readiness

**Supported without significant rework:**

- **Production integration (the stated goal).** The whole engine renders from
  four JSON islands (`data-agg`, `data-micro`, `data-prev`, `user-state`)
  with a documented validate-on-boot contract (`20_data.js d2.validate`).
  Step 1 of the production path — a JSON writer in the tabs module alongside
  the existing Excel/HTML writers — needs zero renderer changes: emit the
  same shapes and the report builds. The golden-parity gate is the template
  for the R↔JS golden-file tests.
- **Any-project reuse.** Nothing SACAP-specific lives in the engine: banner
  groups, categories, index weights, thresholds, sampling method and tracking
  config all come from the data layer; explainer examples are computed from
  the report's own data (`21c_confidence.js workedExample`).
- **More waves / more segments.** The wave engine takes any number of waves
  and any segment coverage (sparse per-year segments already handled);
  match-rate floors are data, not code.
- **New exhibit kinds.** The story item contract (kind + flags + capture
  fields) and the `exhibit.slide` → packager chain (one native chart part per
  panel, rels rId2+k) extend cleanly; the round-5 → round-6 pin-shape
  back-compat shows the pattern.

**Requires significant rework:**

- **Real (non-synthetic) microdata.** The embedding mechanics exist, but
  production needs anonymisation + suppression-threshold decisions, a config
  flag in tabs, and possibly chunked islands if respondent counts are large
  (SACAP's 1,363 × 79 answers ≈ 0.5 MB; a 20k-respondent tracker would not
  fit the 2 MB budget — needs either a budget rethink or on-demand loading,
  which breaks "single file, works offline").
- **Confidence-module full parity.** t-based mean intervals, weighted
  effective-n (`03_study_level.R`) and bootstrap methods belong in R at
  data-layer-generation time, not ported to JS — i.e. tabs should emit
  precomputed interval bounds per cell for the published views, with the JS
  Wilson port kept only for live-filtered recomputes.
- **Signed chart axes.** Bar/column/dot/pie floor negatives at the axis
  (honest labels, review fix I5). Charts with negative domains (NPS
  composites for weak brands) need a zero-line axis model in `23z_charts.js`.

## Natural next steps

### 1. JSON data-layer writer in the tabs module
**What:** `99_output`-style writer emitting `data-agg` (+ optional microdata
behind a config flag) from a tabs run.
**Why now:** It is the only blocker between this prototype and a real report;
everything downstream is already gated.
**Effort:** Medium — the shapes are documented by example here; the work is
mapping tabs' internal structures and writing R-side tests against this
repo's JSON as golden files.
**Dependencies:** none (additive writer, old path untouched).
**Risk:** silent shape drift between R writer and JS expectations — mitigate
with a shared schema check (`d2.validate` mirrored in R) and R↔JS golden
tests from day one.

### 2. Ship the renderer behind a config switch
**What:** Bundle these JS files via the existing build.R inliner as the new
tabs HTML report; old per-cell generator stays default until trusted.
**Effort:** Medium (build integration, branding/config plumbing, pilot on a
real study).
**Dependencies:** step 1.
**Risk:** features the live report has that the prototype intentionally
stubbed (callout editor text, weighting display) — inventory before pilot.

### 3. Precomputed intervals + significance in the data layer
**What:** Tabs/confidence emit per-cell interval bounds and sig letters for
published views; JS computes only for live filters/custom banners.
**Why:** kills the three documented divergences (z-vs-t, rounded-pct
fallback, effective-n) without porting statistics to JS.
**Effort:** Small-Medium once step 1 exists.
**Risk:** double bookkeeping (published vs recomputed paths) — the
PUBLISHED/COMPUTED badge discipline already in place is the guard.

### 4. Advanced-module surfaces (handover §7 order)
**What:** segmentation → conjoint → maxdiff → keydriver → catdriver → brand
get this report look and feel.
**Effort:** Large (per module: data-layer shape + views; engine reuse high).
**Dependencies:** steps 1–2 prove the pattern on tabs first.

### 5. Real-microdata embedding policy
**What:** anonymisation + suppression threshold + size strategy for big
trackers.
**Effort:** Medium; mostly decisions, not code.
**Risk:** privacy — needs an explicit rule (e.g. suppress cells under n=5,
strip verbatims/IDs) signed off before any client data is embedded.

## Known limitations

| Limitation | When it matters | Mitigation |
|------------|-----------------|------------|
| Synthetic microdata approximates non-Campus crosses (mean abs err 1.8pp) | Only in this prototype's filtered views | Disappears at step 1 (real data); golden parity pins Campus exact |
| Sig letters ≈90% vs published on borderline cells | Filtered/custom views only (published views verbatim) | 85% floor gate; production consumes tabs-computed letters (step 3) |
| Mean intervals z not t; Welch on rounded published distributions | Means/Index/NPS sig + bands at small n | Step 3; divergence < 1.5% at n ≥ 70 today |
| Negative values floor at axis in SVG dist charts | Negative NPS composites | Labels show true value (review I5); signed axes are rework item |
| PPTX "Edit Data" full proof is manual | Every deck delivery | verify_pptx machine-checks the #REF! class; keep the manual open test in the release ritual |
| Insights/pins persist per-browser | Analyst switches machines | Export/import JSON sidecar + Save copy (both verified) |
| Single-file ≤ 2 MB budget | Large trackers with embedded microdata | Step 5 decision; trim waves precision first |

## Technical debt

| Debt | Why accepted | When to pay down |
|------|--------------|------------------|
| 11 of 24 files on SIZE-EXCEPTION | Coherent single-surface modules; prototype velocity | At productionisation, split the two 600+-line files (27v, 25_cards) along their internal section comments |
| URL hash carries a state subset (not hidden rows/cols/sorts) | Documented scope ("tab/question/banner/filter") | Only if "share exact view" becomes a requirement |
| Custom-banner sig letters wrap at 26 columns | Unreachable with current data | Guard when custom banners can exceed 26 categories |
| Chart workbook series letters cap at column Z | Max 18 chart columns today | Spreadsheet-style column names if ever needed |
| Visualise Y-override doesn't clip series lines | User-initiated, cosmetic | clipPath when touching 23za next |

## External dependencies to watch

None at runtime — the artifact is dependency-free by design (its main
defence against rot). Toolchain only: R + jsonlite (renv-pinned), node ≥ 18
for gates, python3 stdlib for pipeline/verifier. The single fragile external
contract is **PowerPoint's OOXML chart parser** (the Sheet1/#REF! class) —
covered by `verify_pptx.py` plus the manual open test.

## Summary

The prototype has done its job: the data-centric architecture demonstrably
carries the full report (at 28% of the size) plus filtering, tracking and
confidence features the render-centric design could not, behind real gates.
The clearest path is the three-step production sequence — tabs JSON writer,
renderer behind a config switch, precomputed statistics in the data layer —
in that order, each small enough for a session or two. The biggest constraint
is not code but policy: the real-microdata embedding rules (privacy +
size) need Duncan's sign-off before any client report ships on this path.
