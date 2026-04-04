# Inline Styles to CSS Classes — Refactor Plan

## Problem Statement

Turas HTML reports contain 600–1,200 inline `style=""` attributes, with 80% being repetitions of just 11 unique values. The primary offender is heatmap cell colouring: 608 cells in the demo fixture carry identical `background-color` + `color` + `font-weight` strings, consuming 40KB (65% of all inline style bytes). This hurts file size, makes styling changes harder, and exposes visual implementation detail in deliverables.

The good news: **`data-tier` attributes already exist** on dashboard heatmap cells. The infrastructure for CSS-based colouring is half-built.

---

## Quantitative Analysis (Demo Fixture: 1.8MB tabs report)

| Metric | Value |
|--------|-------|
| Total `style=""` attributes | 965 |
| Unique style values | 70 |
| Heatmap cells with inline styles | 608 (63%) |
| Unique heatmap background colours | **4** (fixed palette, not continuous) |
| Bytes consumed by all inline styles | 61,551 |
| Bytes consumed by heatmap styles alone | 40,328 (65.5%) |
| Styles appearing 21+ times | 11 unique values → 768 instances (80%) |

### The 4 heatmap styles (tabs dashboard)

| Tier | Count | Background | Text | Weight |
|------|-------|------------|------|--------|
| amber | 272 | `rgba(201,169,110,0.15)` | `#96783a` | normal |
| green (light) | 226 | `rgba(74,124,111,0.10)` | `#4a7c6f` | normal |
| green (bold) | 66 | `rgba(74,124,111,0.18)` | `#4a7c6f` | 700 |
| red | 44 | `rgba(184,84,80,0.12)` | `#b85450` | normal |

These are NOT continuous gradients — they are a fixed 4-value palette. Perfect for CSS classes.

---

## Current Architecture

```
R (06b_dashboard_styling.R):
  get_heatmap_bg_style(val, type, thresholds)
    → "background-color: rgba(74,124,111,0.10); color: #4a7c6f;"

  get_heatmap_tier(val, type, thresholds)
    → "green" | "amber" | "red"

R (06_dashboard_builder.R, line 905-908):
  sprintf('<td class="dash-hm-td" style="%s" data-tier="%s">%s</td>',
          bg_style, tier, value)

JS (06a_dashboard_js.R, line 65):
  var tier = cell.getAttribute("data-tier");  // for Excel export
```

**Key insight:** The `data-tier` attribute already exists specifically because inline styles get browser-normalised (rgba → rgb), making string matching unreliable for Excel export. The tier is the reliable source of truth.

---

## Proposed Architecture

### Phase 1: Dashboard heatmap cells (4 CSS rules replace 608 inline styles)

```css
/* In shared CSS (base_css.R or dashboard section) */
[data-tier="green"]       { background-color: rgba(74,124,111,0.10); color: #4a7c6f; }
[data-tier="green"].dash-hm-total { background-color: rgba(74,124,111,0.18);
                                     color: #4a7c6f; font-weight: 700; }
[data-tier="amber"]       { background-color: rgba(201,169,110,0.15); color: #96783a; }
[data-tier="red"]         { background-color: rgba(184,84,80,0.12); color: #b85450; }
```

```r
# R change (06_dashboard_builder.R, lines 901-908):
# BEFORE:
bg_style <- get_heatmap_bg_style(val, metric$metric_type, thresholds)
tier <- get_heatmap_tier(val, metric$metric_type, thresholds)
sprintf('<td class="dash-hm-td%s" style="%s" data-tier="%s">%s</td>',
        total_class, bg_style, tier, htmltools::htmlEscape(disp))

# AFTER:
tier <- get_heatmap_tier(val, metric$metric_type, thresholds)
sprintf('<td class="dash-hm-td%s" data-tier="%s">%s</td>',
        total_class, tier, htmltools::htmlEscape(disp))
```

**Files changed:**
- `modules/tabs/lib/html_report/06_dashboard_builder.R` — remove `bg_style` call, drop `style="%s"` from sprintf
- `modules/tabs/lib/html_report/06b_dashboard_styling.R` — `get_heatmap_bg_style()` can be deprecated (still available for other callers)
- CSS injection point (either `base_css.R` or a new `dashboard_heatmap.css` section) — add 4 CSS rules

**Impact:** -40,328 bytes inline styles, +~340 bytes CSS rules = **~40KB saving** (uncompressed), **~18-20KB saving** (gzipped)

**Risk:** Zero — `data-tier` already exists and is already used by Excel export JS. We're just adding CSS rules that target the same attribute.

### Phase 2: Static layout styles (20 CSS utility classes replace ~160 inline styles)

Replace repeated layout/text inline styles with utility classes:

```css
.u-hidden          { display: none; }
.u-flex-center      { display: flex; align-items: center; }
.u-flex-between     { display: flex; align-items: center; justify-content: space-between; }
.u-cursor-pointer   { cursor: pointer; }
.u-tabular-nums     { font-variant-numeric: tabular-nums; }
.u-text-secondary   { color: #64748b; font-size: 11px; }
.u-text-muted       { color: #94a3b8; }
.u-font-semibold    { font-weight: 600; }
.u-font-bold        { font-weight: 700; }
.u-inline           { display: inline; }
.u-relative         { position: relative; }
.u-flex-1           { flex: 1; }
.u-icon-inline      { vertical-align: -1px; margin-right: 5px; }
.u-ml-sm            { margin-left: 12px; }
.u-mr-xs            { margin-right: 6px; }
.u-mb-sm            { margin-bottom: 12px; }
/* ... etc. */
```

**Files changed:**
- `modules/tabs/lib/html_report/06_dashboard_builder.R` — replace ~70 inline styles
- `modules/tabs/lib/html_report/03b_page_components.R` — replace ~5 inline styles
- `modules/conjoint/lib/html_report/03_page_builder.R` — replace ~28 inline styles
- CSS injection point — add utility class definitions

**Impact:** ~5-8KB saving (uncompressed), ~2-3KB gzipped

### Phase 3: Tracker heatmap (add data-tier, move to CSS)

The tracker module's heatmap (`03f_heatmap_builder.R`) currently has NO `data-tier` attributes and uses a **continuous opacity gradient** within each tier — not a fixed palette like the dashboard. This needs a different approach:

**Option A: Discretise into tiers (simple, matches dashboard)**
- Map continuous opacity to 3-5 sub-tiers per colour: `data-tier="green-1"` through `data-tier="green-5"`
- 15 CSS rules replace 500-1000 inline styles
- Slight visual change (stepped vs smooth gradient) — needs Duncan's approval

**Option B: CSS custom properties per cell (preserves exact gradient)**
- Keep R calculating the opacity, but inject via `style="--hm-opacity: 0.26"` instead of full rgba
- CSS: `[data-tier="green"] { background: rgba(5,150,105, var(--hm-opacity)); color: var(--hm-text); }`
- Same number of `style=""` attributes but much shorter (16 chars vs 65 chars)
- ~60% reduction in inline style bytes with no visual change

**Option C: Leave as-is**
- Tracker heatmap is a niche view. The dashboard (Phase 1) is the volume driver.
- Revisit if tracker reports grow to problematic sizes.

---

## Implementation Order

| Phase | Effort | Saving (gzip) | Risk | Recommendation |
|-------|--------|---------------|------|----------------|
| 1: Dashboard heatmap | 2-3 hours | 18-20 KB | Near zero | Do first |
| 2: Static utilities | 4-6 hours | 2-3 KB | Low | Do second |
| 3: Tracker heatmap | 1-2 days | 5-10 KB | Medium | Decide later |

**Phase 1 alone delivers 80%+ of the achievable savings** with minimal effort and near-zero risk — the `data-tier` infrastructure already exists.

---

## Verification Strategy

1. Generate a tabs report WITHOUT the refactor → save as `baseline.html`
2. Generate the same tabs report WITH the refactor → save as `refactored.html`
3. **Visual diff:** Open both in browser, screenshot every page/tab, pixel-compare
4. **Functional diff:** Run automated verification checks (element counts, data attributes, handler functions)
5. **Size comparison:** Compare file sizes (uncompressed and gzipped)
6. **Excel export:** Export from both, compare Excel outputs cell-by-cell
7. **Print:** Print both to PDF, compare
8. **Hub integration:** Build a hub from refactored sub-reports, verify everything works

This must pass Duncan's non-negotiable: **nothing breaks between internal and client versions, not on a single screen or button.**

---

## Files Inventory

### Phase 1 (dashboard heatmap):
- `modules/tabs/lib/html_report/06_dashboard_builder.R` (line 905-908)
- `modules/tabs/lib/html_report/06b_dashboard_styling.R` (line 480-505)
- CSS injection point (TBD — likely `06b_dashboard_styling.R` or `base_css.R`)

### Phase 2 (static utilities):
- `modules/tabs/lib/html_report/06_dashboard_builder.R` (~15 instances)
- `modules/tabs/lib/html_report/03b_page_components.R` (~5 instances)
- `modules/conjoint/lib/html_report/03_page_builder.R` (~28 instances)
- CSS injection point

### Phase 3 (tracker heatmap):
- `modules/tracker/lib/html_report/03f_heatmap_builder.R` (lines 579-680)
- Tracker CSS section

---

## Decision Points for Duncan

1. **Phase 1:** Ready to proceed? (Near zero risk, high payoff)
2. **Phase 3 approach:** Discretise (stepped tiers, slight visual change) or CSS variables (exact gradient, smaller saving) or skip?
3. **Branch strategy:** New branch (`feature/inline-styles`) or continue on `feature/minification`?
