# Executive Takeout — architecture & build plan

Status: v1 BUILT + review pass 1 · branch `feature/tabs-executive-takeout` · 2026-06-27
Engine + both views + curation + tests complete (node 20/20, bundler 25/25).
Review pass (Duncan, on real SACS data): apex now leads with overall
satisfaction (detected by title) + the composite indices, each with a wave
delta; satisfaction/composites are pulled OUT of the lanes. Lanes speak the
INDEX consistently (index standouts preferred over top-box); every card names
its question; levels use a single gauge bar (no scale-max bar). Protect/Act now
rank RELATIVE to the median (real scales sit mid-band, so absolute bands hid the
weakest items), and level scores are normalised to the same 0..1 effect footing
so subgroup standouts (e.g. Cape Town vs Durban satisfaction) compete with
touchpoint levels. Battery consistency is suppressed when category is blank
(SACS carries no categories) — tagging categories would re-enable the Decide
fork. Awaiting Duncan's launch_turas verification on the live report.

## The problem it solves

The v2 crosstabs report is excellent at "find anything" (dashboard gauges, the
80-finding Differences view, tracking) but it never *states the argument*. A
busy executive opening `SACS-2025_Crosstabs_report.html` confronts ~10,000
numbers across 22 questions x 24 banner cuts, organised by question and banner —
not by what matters. The two most summary-worthy numbers (the Engagement and
Values composite indices) are physically the *last* two items.

The Executive Takeout is the one surface that takes the view for them: a single,
beautiful, scannable page that answers the study's question whether or not
anyone scrolls — and it does so deterministically, with **no AI/LLM call**, for
consistency and privacy.

## Design principles

1. **Zero new statistics.** Every number is already computed. The Takeout is a
   selection + compression + presentation layer over `views._collectFindings`,
   `views.indexQuestions`, `TR.waves` deltas and `TR.conf` reliability.
2. **The cap is the product.** A fixed ceiling (1 answer + <=7 findings),
   immovable regardless of study size. A 90-question tracker yields the same
   calm page as a 12-question pulse. This is the structural cure for
   death-by-volume.
3. **Rank by effect size, gate by significance.** Findings arrive already
   significance- and base-gated; the Takeout re-ranks by Cohen's *h* (proportions)
   and standardized gap (means), never by p-value, plus a battery-consistency
   bonus — the signal a senior analyst reports.
4. **Human-in-the-loop is a feature.** The engine surfaces and ranks; the
   researcher edits every line into client language, promotes/vetoes, and writes
   the apex answer. Curation persists (localStorage + saved-copy island), exactly
   like analyst insights and story pins.
5. **Two shapes, one engine.** A "Read" view (pyramid + decision postures) and a
   "Present" view (Wrapped-style full-screen sequence) render the *same* takeout
   object. A toggle picks the view; it persists in the URL hash.

## Module layout (all under `assets/js/`, auto-bundled, no manifest edit)

| File | Responsibility | DOM? | Tested by |
|------|----------------|------|-----------|
| `27e_takeout_engine.js` | Pure: score, battery bonus, route, dedupe, cap, `buildTakeout` | no | node + #selftest |
| `27f_takeout_data.js` | Gather inputs from AGG/views/waves (I/O) + curation state (localStorage) | reads globals | #selftest |
| `27g_takeout_components.js` | Shared render atoms: card, two-bar, editable field, reliability ribbon, posture meta | yes | visual |
| `27h_takeout_read.js` | Read view — apex + four posture lanes | yes | visual |
| `27i_takeout_present.js` | Present view — Wrapped full-screen sequence | yes | visual |
| `27k_takeout.js` | Thin controller: gather -> build -> apply curation -> dispatch + wire toggle/edits | yes | visual |

Wiring (`24_shell.js`): add `['takeout','Executive takeout']` first in `tabList()`,
add a `route()` branch, hide the filter bar on this tab. Default `state.tab`
becomes `takeout`; `state.takeoutView` ('read'|'present') added to state + hash.

## The takeout object (the contract every module agrees on)

```
{
  answer:      { seed: string },                 // templated draft; state overrides
  reliability: { n, moePct, census, sampleNote },
  postures: [
    { id, label, verb, icon, items: [Finding] }  // protect | act | watch | decide
  ],
  candidateCount: int,                           // gated candidates considered
  promotedCount:  int                            // items shown after the cap
}
```

`Finding` (normalized across kinds):
```
{ id, code, title, category, column, kind('standout'|'level'),
  metric('pct'|'mean'), claimSeed, soWhatSeed,
  value, rest, overall, gap, soft, direction, band,
  delta{diff,sig,year}, base, batteryK, score, posture }
```

`id = code + '|' + column + '|' + metric` — stable across regenerations, so a
researcher's edit to a finding's text survives a re-run for unchanged questions.

## Routing rules (deterministic, disclosed to the reader)

Each candidate gets exactly one posture (no overlap):

- **level** (a rated touchpoint's Total figure, carries its wave delta):
  strong + significantly declining -> `decide`; strong -> `protect`;
  weak -> `act`; moderate + significant move -> `watch`; else dropped.
- **standout** (a subgroup vs the rest, from `_collectFindings`):
  battery consistency k >= `BATTERY_FORK_MIN` -> `decide`;
  gap >= 0 -> `protect`; gap < 0 -> `act`.

Per-posture caps: protect 2, act 2, watch 2, decide 1 (<=7 total). Within a
posture, keep top-N by score; dedupe exact `(code,column,metric)` collisions.

## Scoring (pure, known-answer tested)

- `cohenH(p1,p2) = 2·asin(√p1) − 2·asin(√p2)` (p in [0,1]).
- proportion effect = min(1, |h| / `COHEN_H_REFERENCE`); mean effect =
  min(1, |gap| / scaleRange).
- `score = effect × tierWeight × 100`, tierWeight = solid 1.0 / soft 0.5.
- battery bonus: ×(1 + `BATTERY_BONUS_PER_ITEM`·(k−1)), where k = items in the
  same category on which this column deviates the same direction with sig.

All thresholds live in one `CONST` block in the engine — no magic numbers.

## Human-in-the-loop / persistence

`27f` curation store mirrors `28_insights.js`: seeds from `TR.userState`, then
localStorage takes precedence; `set` writes back. Editable per finding:
`claim`, `soWhat`; plus the apex `answer`; plus `veto` (hide) and posture
override. All text is stored raw and **escaped on render** (`fmt.escapeHtml`) —
no XSS. A "Reset to engine" control reverts all curation.

## Accessibility (WCAG AA, non-negotiable)

- Posture is conveyed by icon + label + text, never colour alone.
- Every editable field is a real labelled control, keyboard-operable, with a
  visible focus ring; edits announced via `aria-live`.
- The view toggle is a `tablist`/`radiogroup` with arrow-key support.
- Present-view cards are reachable and readable linearly by screen readers.
- Contrast checked against the report's `--ink`/`--card` tokens.

## Verification gates

- `node modules/tabs/lib/html_report_v2/tests/takeout_tests.mjs` — known-answer
  suite for the pure engine (Cohen's h, scoring, routing, cap/dedupe, battery
  bonus) + a source structure check (<=300 active lines/file, <=50/function).
- `#selftest` in-browser cases: `buildTakeout` over live AGG yields a valid,
  capped takeout; graceful with no microdata / no waves.
- `Rscript -e "testthat::test_dir('modules/tabs/tests')"` — existing suite stays
  green (bundler picks up the new files; nothing in R changes).
