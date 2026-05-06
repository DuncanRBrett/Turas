# Brand Selector Dropdown — Project Plan

**Author:** Duncan Brett (planning) + Claude (drafting)
**Date:** 2026-05-06
**Branch:** `feature/brand-selector-dropdown`
**Status:** EXECUTING

---

## 1. Problem Statement

The brand module's HTML report uses chip-strip selectors to control which
brands appear in tables and charts. With 13+ brands per category (Dry
Seasonings & Spices, future CCPB / SACAP categories), the chip strip wraps
onto multiple rows, dominates the toolbar, and looks cluttered. A small,
discoverable dropdown — modelled on the existing Pin dropdown — keeps the
toolbar clean regardless of brand count and scales gracefully to any size
of brand list.

## 2. Landscape & Approach

The Pin button (`TurasPins.showCheckboxPopover`) is the visual donor pattern
but is a one-shot confirm-action popover, unsuitable for live filtering.
We build a lightweight live-filter equivalent in the brand module:

- New shared JS component `BrandSelector` exposing `create({...})` API
- Brand-namespaced CSS (`.bs-*`) so it does not collide with `.tp-*`
  (TurasPins) or per-panel chip styles
- R helpers `build_brand_selector_trigger()` and
  `build_brand_selector_legend_strip()` for use inside panel files
- Each panel keeps its existing visibility-state logic
  (`panel.__state.hiddenBrands` Set + `applyBrandVisibility()` function);
  the dropdown is a UI substitute that drives the same Set

**Donor pattern reused:** Pin popover positioning, click-outside-closes,
checkbox-row layout. Live updates on each toggle — no Apply / Cancel.

## 3. Objectives

1. Replace per-brand chip strip with a "Filter brands ▾" dropdown across
   the 8 brand panels with brand-chip selectors (Funnel, MA × 3 sub-tabs,
   MA Attitude Advantage, Word of Mouth, Cat Buying main, Demographics,
   Ad Hoc).
2. Cat avg stays as a separate chip next to the dropdown.
3. Show all / Hide all (and any panel-specific quick actions) move
   inside the dropdown header as buttons.
4. Brand colour legibility preserved by the swatches inside the dropdown
   itself. The static colour-legend strip below charts was tried during
   the Demographics migration and dropped per Duncan's review feedback
   ("not necessary to show the brand names" — dropdown swatches suffice).
   **Per-chart legend (different concern):** every panel that renders a
   multi-brand chart (Funnel, MA, WoM, Cat Buying, etc.) must keep its
   in-chart legend intact during migration. The chip strip currently
   doubles as the chart's colour key in some panels — when that strip
   goes, the chart's own legend (SVG text labels or a legend block
   inside the chart container) becomes the only colour reference while
   the dropdown is closed. Audit each chart during its panel migration:
   if the chart relies on the chip strip for its legend, add a proper
   in-chart legend before removing the strip.
5. Funnel + MA panels (which have separate table-row vs chart-series
   selection) get a "Sync table + chart" toggle inside the dropdown,
   defaulting ON; turning it OFF reveals a second checkbox column.
6. No regression in: pin capture, PNG export, Excel export, focal-brand
   sync, % total / % aware base toggles, heatmap toggles.
7. All existing brand tests pass; new tests added for the shared helper.

**Out of scope:**
- Portfolio category-chip selectors (different concern — categories not
  brands)
- Cat Buying secondary segment / comparison chips (contextual filters,
  not brand selectors)
- Ad Hoc per-question brand picker — discovered during migration to be a
  single-select radio (pick ONE brand to show its heatmap) rather than a
  multi-select filter, hidden behind a "By brand" toggle. The
  BrandSelector checkbox pattern doesn't fit. If this picker grows
  cluttered with many brands, a separate refactor to a native
  \code{<select>} dropdown is the right move — not this branch.
- Tabs / Tracker / Conjoint / MaxDiff modules (separate refactor if useful)

## 4. Design

```
Toolbar:
┌───────────────────────────────────────────────────────────────┐
│ FOCAL BRAND  [Ina Paarman's Kitchen ▾]                         │
│                                                                │
│ [📊 Filter brands (10/13) ▾]  [Cat avg ✓]                      │
│ [% total | % aware]   [☐ Heatmap]    [Pin▾][PNG][Excel]        │
└───────────────────────────────────────────────────────────────┘

Below chart:
⬤ Ina Paarman's Kitchen   ⬤ Cape Herb & Spice   ⬤ Cartwright's …
(static legend strip — non-interactive)
```

Dropdown popover:

```
┌──────────────────────────────────┐
│ Filter brands       [All] [None] │  ← header buttons
│ ──────────────────────────────── │
│ ☑ ⬤ Ina Paarman's Kitchen FOCAL │
│ ☑ ⬤ Cape Herb & Spice           │
│ ☑ ⬤ Cartwright's                │
│ ...                              │
│ ──────────────────────────────── │
│ ☑ Sync table + chart             │  ← only on split panels (Funnel, MA)
└──────────────────────────────────┘
```

When the Sync toggle is OFF (split panels only), a second checkbox column
appears beside the first, with headers "Table | Chart".

## 5. Growth Roadmap

The shared `BrandSelector` becomes a candidate for:
- Tabs module attribute pickers (long-list filtering)
- Tracker module wave / period filtering
- Conjoint / MaxDiff attribute selection
- Cross-module category filtering (future)

This refactor unblocks similar UI cleanups platform-wide without rebuilding
the popover machinery each time.

## 6. Risks & Mitigations

| # | Risk | Mitigation |
|---|------|------------|
| 1 | Pin / PNG export expects DOM-visible state | Keep `display:none` on hidden table rows + chart series, same as today. Capture code unchanged. |
| 2 | z-index collision with TurasPins popover | `.bs-popover` z-index 900 (below TP 1000); only one popover open at a time per panel. |
| 3 | Brand colour legibility loss | Static legend strip below charts retains colour↔brand mapping. |
| 4 | Discoverability — users may miss the dropdown | Trigger button shows live count badge "(8/13)" so the active state is obvious. |
| 5 | Excel export reads `.col-chip-off` row class | Dropdown sets the same class on hidden rows; export code unchanged. |
| 6 | IPK regression (panels visually change) | This branch INTENTIONALLY changes the chip strip. Functional regression is the gate, not visual identity. |
| 7 | Test fixtures break on chip → dropdown markup change | Update R tests as each panel migrates. |

## 7. Quality Standards

Per Duncan's coding standards:
- `brand_selector_dropdown.js` ≤ 300 active lines, each function ≤ 50
- `BrandSelector.create({...})` documented with full API
- Tests for the R helpers (trigger HTML, legend strip HTML)
- Tests for each migrated panel updated
- Atomic commits per panel migration
- IPK regen + browser-verify after each panel migration

## 8. Phasing

| # | Commit | Scope |
|---|--------|-------|
| 1 | Planning doc | This file |
| 2 | Shared component | JS + CSS + R helpers + tests, not yet wired |
| 3 | Demographics migration | Simplest unified-list case (proof of concept) |
| — | **Pause for browser verification** | Confirm dropdown works end-to-end |
| 4 | Ad Hoc migration | Mirror of Demographics |
| 5 | Word of Mouth migration | Single chip set with brand swatches |
| 6 | MA Attitude Advantage migration | Single chip set with focal-only toggle |
| 7 | Funnel migration | First split (table + chart) — tests Sync model |
| 8 | MA migration | 3 sub-tabs × split — biggest single panel |
| 9 | Cat Buying migration | Main brand chips only; segment chips stay |
| 10 | Test + docs | Final coverage pass + README update |

## 9. Verification

After each panel migration:

- [ ] Brand test suite green (`Rscript -e "testthat::test_dir('modules/brand/tests/testthat')"`)
- [ ] IPK report regenerates without error
- [ ] Browser-verify in `launch_turas()` against IPK config
  - [ ] Dropdown opens / closes
  - [ ] Brand toggles hide / show in table AND chart
  - [ ] All / None buttons work
  - [ ] Cat avg chip still works
  - [ ] Sync toggle works (split panels only)
  - [ ] Pin + PNG export captures correct visible state
  - [ ] Excel export respects selection
  - [ ] Focal-brand sync still works cross-panel

---

## Execution Log

| Step | Commit | Outcome |
|------|--------|---------|
| Pre-flight baseline | — | 1739 pass / 0 fail / 2 skip on main |
| Branch + plan | b74d1ee | `feature/brand-selector-dropdown` created + planning doc |
| Shared component | fc3a2b6 | JS + CSS + R helpers + 32 tests; 1771 / 0 / 2 |
| Demographics migration | d77903a | Proof-of-concept panel; 1771 / 0 / 2 |
| Inline trigger + drop legend | ff9b7dc | Per Duncan's review feedback; 1760 / 0 / 2 |
| Per-chart legend audit note | deb714a | Doc reminder for upcoming migrations |
| Word of Mouth migration | 6128421 | Per-category dropdown wired to wom-focus-bar |
| MA Attitude Advantage migration | e6e335a | Inline trigger in adv-controls-bar |
| Brand Funnel migration | a823d68 | First split-mode panel + Sync footer toggle |
| Mental Availability migration | 579939b | 3 sub-tabs (attributes / ceps split, metrics unified) |
| Category Buying migration | 4c0099f | Per-category dropdown wired to cb-focus-bar |

**Final test count:** 1760 pass / 0 fail / 2 skip (was 1739 pre-branch — net
+21 from the new selector-widget tests, no regressions).

**Panels migrated:**
- Demographics (unified)
- Ad Hoc (out of scope — single-select per-question picker, kept as chips)
- Word of Mouth (unified, per-category)
- MA Attitude Advantage (unified, brand-level)
- Brand Funnel (split mode + Sync footer)
- Mental Availability ×3 sub-tabs (attributes split, ceps split, metrics unified)
- Category Buying (unified, per-category)

**Skipped panels:**
- Portfolio (category chips not brand chips — different concern, out of scope)
- Ad Hoc per-question picker (single-select radio behaviour, not multi-select)
- Cat Buying secondary segment / comparison chips (contextual filters, not
  brand selectors)

**What still needs verification (browser, in `launch_turas`):**
- Click-through every migrated panel to confirm the dropdown opens, brand
  toggles correctly hide rows / chart series, All / None / Sync work, focal
  changes keep the FOCAL pill on the right brand and don't lose the new
  focal's visibility.
- Confirm Pin / PNG / Excel exports still capture the right state.
- Per-chart legends are intact on Funnel, MA, WoM, Cat Buying multi-brand
  charts (audit gate documented above).

