# HANDOVER — Confidence Module Integration into the v2 Report

> **STATUS: COMPLETE (2026-06-12).** Shipped in 5 commits on
> `feature/report-data-layer` (confidence core → crosstabs/dashboard →
> tracking → pins/exports → docs). All 7 required-functionality items
> delivered; gates 30/30 v2 + 21/21 v1 + 15/15 in-browser; artifact
> 1.96 MB; browser-verified with cache-busting + computed styles.
> See README "Round 7 — confidence integration" for what shipped and the
> documented divergences (z-vs-t mean CIs, rounded-pct fallback, no
> effective-n hook). Also fixed in passing: the story exhibit card's
> unclosed `</div>` (later story cards nested inside pinned exhibits).
> **Next phase:** full production review via `duncan-production-review`
> (section 7), then the advanced modules in order. The original brief is
> preserved below for context.

**For:** a fresh session. Read this cold; it is self-contained.
**Mission:** give every number in the v2 report an honest, plainly-worded
statement of its reliability — the confidence module's Wilson intervals,
sampling-method-aware language and sample-size explanations, woven into
the existing views. **Confidence is a property of every number, not a
destination tab.** This phase runs BEFORE the full production review
(`duncan-production-review`) so the statistical layer is reviewed once,
complete. After the review, the remaining modules (segmentation, conjoint,
maxdiff, keydriver, catdriver, brand) get this look and feel.
**Touch nothing in live Turas modules.** Build inside
`prototypes/report-redesign/fable/v2/` only.

## 0. The two principles Duncan set (non-negotiable)

1. **Confidence is a function of THE SAMPLE.** Whether an interval may be
   called a "confidence interval" at all depends on the sampling design.
   Mirror `modules/confidence/R/sampling_labels.R` exactly: probability
   designs (Random/Stratified/Cluster/Census) speak standard statistics
   ("Confidence Interval", "CI", "Margin of Error", "MOE"); non-probability
   designs (Quota/Online_Panel/Self_Selected/Not_Specified) get honest
   softened language ("Stability Interval", "SI", "Precision Estimate",
   "PE"). SACAP is a student-census-attempt online survey — pick the
   defensible default (`Not_Specified` → SI/PE) and make it a config:
   `project.sampling_method`.
2. **Report readers are NOT statisticians.** Every interval ships with a
   plain-language explanation via the existing callout pattern (the
   collapsible explainers in `25_cards.js` `explainersHtml()` — extend
   that, and reference the production callout editor concept from the
   tabs module for editable text). Target sentence quality: "Based on
   519 answers, this 84% would likely land between 81% and 87% if we
   ran the survey again. Smaller groups — Durban has only 49 students —
   swing much more, so treat their numbers as indicative." Concrete,
   short, zero jargon.

---

## 1. What exists (all committed on `feature/report-data-layer`)

`sacap_report_v2.html` (1.93 MB — **the test budget is 2 MB, watch it**;
if needed, trim `data/sacap_waves.json` float precision to claw back room).
Commits to date: `2888dca9` multi-wave data layer → `064c7c73` tracking tab
→ `a5d1932f` wave strip → `52a3cdfd` exhibits/composites → `4ef055bf` gates
→ `e51f6001` per-segment workspace → `26c1ac18` explorer UX + key metrics
→ `e5ab2687` multi-select/annotations/pin popover → `d46a2017` CI bands all
types → `19b2a48d` means significance + production-review items.

- **Data islands:** `data-agg` (published 2025), `data-micro` (synthetic
  respondents), `data-prev` (7 waves 2018–2024 incl. per-segment values,
  `data/sacap_waves.json` schema 3), `data-verify`, `user-state`.
- **Engine:** `20_data` state/hash · `21_stats` masks/tabulate/pooled-z/
  Welch (`propZ`, `meanZ`, `sigLetters`) · `22_model` view models ·
  `22w_waves` wave history + per-segment series + **distribution-derived
  SDs** (`scoreMap`, `sdAtWave`, `sdFromPairs`, Welch mean-sig) ·
  `23_render`/`23y`/`23z`/`23za` renderers incl. `trendChart(model, opts)`
  with `opts.ci` band callback · `24_shell` (+ shared `shell.pinMenu`) ·
  `25_cards` crosstabs (Rows & columns panel, wave strip + toggles) ·
  `26_filter` · `27_views` dashboard/differences · `27s_notes` annotations
  · `27t/27u/27v` tracking workspace (Summary | Explorer | Visualise) ·
  `28_insights` · `29_export` PNG/PPTX (native charts) · `30_story` ·
  `30x_exhibit` · `31_selftest` · `32_report` save-copy.
- **Current CI/sig methodology (what this phase formalises):**
  - Proportions: CI = 1.96·√(p(1−p)/n) (normal approx — **replace with
    Wilson**); sig = pooled z mirroring `modules/tabs/lib/weighting.R`,
    expected counts ≥5, bases <30 excluded + ⚠.
  - Means/Index/NPS: SD derived from published category distributions
    (`TR.trk.sdAt`, single source); CI = 1.96·SD/√n; sig = Welch
    (`stats.meanZ`) — keep, it is sound; confidence-module parity check
    against `R/05_means.R` wanted.
  - CI bands live in tracking Visualise only; **crosstabs and dashboard
    have no interval display yet** — that is the main build.

### Build + gates (run before AND after every change)

```bash
cd prototypes/report-redesign/fable/v2
Rscript build.R                    # → sacap_report_v2.html
node tests/run_tests_v2.mjs        # 23 tests: golden parity, known answers, pptx
node ../tests/run_tests.mjs        # v1 gate (21) — shared 14_pptx_parts stays green
```

Browser: `preview_start` name `report-prototype-fable` (port 8775), open
`/v2/sacap_report_v2.html?v=<random>` — **always cache-bust**; Duncan's own
server (e.g. :4182) serves stale artifacts after rebuilds, which has already
masqueraded as "feature broken" once. Verify by `getComputedStyle`, never
properties. In-browser selftest: append `#selftest` (11/11 today).

---

## 2. Source intel

- **`modules/confidence/R/`** (production, 93/100): `ci_dispatcher.R`
  (per-question orchestration; Wilson/bootstrap flags), `04_proportions.R`
  (`calculate_proportion_ci_wilson(p, n, conf_level)` — port THIS formula
  verbatim to JS; bootstrap BCa = production-path only, do NOT fake it on
  synthetic microdata), `05_means.R` (t-based mean CIs — parity-check the
  existing distribution-SD approach), `03_study_level.R` (effective n for
  weighted data — document the hook, the prototype's published bases are
  unweighted), `sampling_labels.R` (**port `get_sampling_labels()` to JS
  near-verbatim** — field names interval_name/interval_abbrev/moe_name/
  moe_abbrev/precision_term/interval_term/is_probability; also reuse the
  `CLUSTER_WARNING_HTML` honest-warning pattern for low-base and
  non-probability caveats), `sampling_labels.R:143` prose style ("Differences
  near the margin of error should be interpreted with particular caution.").
- **Callout pattern in v2:** `25_cards.js` `explainersHtml()` + `.callout`
  CSS — collapsible footer explainers ("Reading this table", "Understanding
  the significance testing"). Extend with a third: "How sure can I be of
  these numbers?" The tabs module's callout editor (`modules/tabs/lib/`,
  callout files) is the editable-text concept to imitate for analyst-
  customisable wording later; for the prototype, well-written defaults
  + the per-question insight editor suffice.
- **Reference report:** run the confidence module's own HTML output if an
  example exists under `examples/confidence/` to see its interval tables,
  badges and warning callouts.

## 3. Required functionality

1. **Sampling-aware vocabulary everywhere.** `project.sampling_method` in
   the agg config (pipeline `extract_2025_html.py` writes it; default
   `Not_Specified`). JS port of `get_sampling_labels()` (suggest
   `21c_confidence.js` or fold into `21_stats`). Every user-facing string
   that says CI/MOE flows through it — tracking CI bands note, new
   crosstab/dashboard surfaces, explainers, pinned-exhibit context lines,
   PPTX meta lines.
2. **Wilson intervals for proportions** replacing the normal approximation
   in `ciHalfWidth` (27v) and powering the new surfaces. Known-answer test
   against the R module (e.g. p=0.05, n=200 — run R once to capture the
   expected bounds, or lift from module tests/docs). Wilson is asymmetric:
   surfaces must show [lo, hi], not ±.
3. **Crosstabs interval display:** a "Show intervals" control (lives in the
   existing controls bar; consider inside Rows & columns panel if crowded).
   Per-cell display: small "81–87" range under the Total value (and per
   banner column), or on hover + a ± summary on the base row — design for
   non-statisticians, avoid table clutter; the Total column treatment
   matters most. Respect low-base ⚠ (intervals on n<30 are wide — show
   them, with the warning, rather than hiding).
4. **Dashboard context:** each gauge/heatmap cell already shows the index;
   add the interval to the gauge tooltip + a MOE/PE chip on the dashboard
   intro card ("At n=1,363 overall results are stable to about ±2.7pp;
   campus cuts vary — Durban ±14pp").
5. **Tracking:** CI bands already exist — relabel via sampling vocabulary
   ("95% SI bands" when non-probability), and the Visualise method note
   updates. The Summary scorecard cards gain interval text in tooltips.
6. **The explainer callout** (principle 2): one new collapsible footer
   callout used on Crosstabs AND inside Tracking, written for lay readers:
   what the interval means in one sentence, why small bases swing (use a
   real example from the data: Durban n=49 vs Total n=1,363), what
   "significant" means in one sentence, and the honest one-liner about the
   sampling design (from the labels port). Keep each bullet under ~25 words.
7. **Pins/exports carry it:** pinned exhibits + PPTX slide meta lines say
   "95% CI (Wilson)" / "95% SI" appropriately; Excel exports of interval
   views include lo/hi columns.

## 4. Definition of done

- All gates green; NEW known-answer tests: Wilson bounds vs the R module
  (≥3 cases incl. small-p and small-n), label switch (Random → CI/MOE,
  Online_Panel → SI/PE, Not_Specified → SI/PE), explainer presence in the
  built artifact, crosstab interval golden spot-check.
- Golden parity for published 2025 tables stays EXACT (intervals are
  additive display — published values must not change).
- Artifact under 2 MB (1.93 MB today — trim waves float precision if the
  Wilson/labels code pushes it over).
- Browser-verified after tab-bouncing with cache-busting + computed styles;
  in-browser selftest extended and green.
- README + this handover updated; atomic commits with the trailer
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## 5. Hard-won guardrails (every one cost a real bug)

1. **Fresh wrapper per tab render** (`host.replaceChildren(wrap)`);
   document-level listeners need singleton guards; internal re-renders
   target `tabhost`/`trkhost`, never a stale wrapper.
2. **`[hidden]` vs CSS:** `[hidden]{display:none!important}` must survive;
   verify visibility by `getComputedStyle`, never by property.
3. **One CSS definition per selector** — two competing `.colmenu` rules
   (overflow auto vs hidden) made the Rows panel invisible for a round.
4. **Panel lists build from the FULL underlying set**, never the filtered
   model — a row hidden via the panel must stay listed (un-hideable).
5. **Cache-busting always**; Duncan's own server serves stale builds.
6. **Sig methodology is settled** — pooled z (α=.05, expected counts ≥5,
   bases<30 excluded+⚠) for proportions; Welch on distribution-derived SDs
   for means/Index/NPS (`TR.trk.sdAt` is the single SD source — Wilson work
   must NOT fork it). Published letters verbatim in published views.
7. **Tracking shows PUBLISHED figures only**; report filters deliberately
   do not apply there (noted in UI). History never filtered by microdata.
8. **Key metrics = evaluative questions only** (mean row + top-box NET,
   one per question); profile questions live in "all tracked rows".
9. **Charts carry question TEXT, codes only in tables**; series names in
   the bottom legend, end labels value-only.
10. **Pin-time element choice** (shared `shell.pinMenu`); story cards show
    exactly the pin, no toggles. Exhibit items: `item.series`
    [{code, ri, label, seg}] (round-5 `item.segments` shape still renders).
11. **Structure rule:** ≤300 active lines per v2 file or a justified
    SIZE-EXCEPTION comment (test-enforced).
12. **jsonlite/renv:** run R from repo root or `v2/`; worktrees need
    `RENV_PATHS_LIBRARY=/Users/duncan/Dev/Turas/renv/library`.
13. **`.gitignore` re-includes `*.html`** under prototypes — built
    artifacts ARE committed deliberately.

## 6. Open items inherited (do not lose)

- Duncan's manual PowerPoint check still outstanding: `tests/tmp/v2_exhibit.pptx`
  and `tests/tmp/v2_segpin.pptx` — "Edit Data" must open Excel on BOTH
  charts of slide 2.
- Sig-letter agreement vs published ≈90% (engine slightly less conservative
  on borderline cells) — documented; production review item.
- Two analyst judgment calls in `pipeline/wave_title_aliases.json`
  (`_judgment_calls`) — review before presenting long trends on those.
- Annotations render in HTML/present/pins but not inside native PPTX
  chart objects (PPTX gets them via the insight band only).
- Welch-on-published-distributions treats rounded published percentages as
  the distribution; the production pipeline computes from raw respondent
  scores per `modules/tracker/lib/trend_significance.R`.

## 7. After this phase

Full production review via `duncan-production-review` (statistical layer
is then complete and stable), then the advanced modules in order:
segmentation → conjoint → maxdiff → keydriver → catdriver → brand.
Production path unchanged: tabs emits the JSON data layer + this renderer
behind a config switch.
