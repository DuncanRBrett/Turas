---
editor_options: 
  markdown: 
    wrap: 72
---

# Visual Polish Plan — 6 Module Parallel Sessions

**Date:** 2026-03-24 (tomorrow) **Branch:** `feature/visual-polish`
**Reference implementation:**
`modules/confidence/lib/html_report/03_page_builder.R`

------------------------------------------------------------------------

## Pre-Session: Shared Work (do FIRST, before parallel sessions)

The confidence session is currently adding callout structures. Once
done, these shared files should be stable:

-   `modules/shared/lib/design_system/design_tokens.R` — tokens API
-   `modules/shared/lib/design_system/base_css.R` — shared CSS generator
-   `modules/shared/lib/design_system/font_embed.R` — Inter font
    embedding
-   `modules/shared/lib/callouts/callout_registry.R` — `turas_callout()`
    function
-   `modules/shared/lib/callouts/callouts.json` — all callout text
    (already populated for all 6 modules)

**IMPORTANT: Shared files are READ-ONLY during parallel sessions.** No
session should modify them. If a module needs a new design token or
callout entry, note it and we'll batch those changes.

------------------------------------------------------------------------

## Common Pattern for ALL Modules

Every session follows the same 5-step process. The confidence module is
the reference implementation.

### Step 1: Wire up callout registry

``` r
# In 03_page_builder.R, add to the local({ ... }) block that sources design system:
callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
  source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
}
```

Then replace hardcoded callout HTML with:

``` r
turas_callout("module_name", "callout_key", collapsed = TRUE)
```

### Step 2: Replace hardcoded colours with CSS variables

-   SVG charts: use design token constants (`.xx_label_colour`,
    `.xx_grid_colour`, etc.)
-   CSS: use `var(--prefix-text-primary)`, `var(--prefix-border)`, etc.
-   Tables: zebra striping, hover, borders → CSS vars

### Step 3: Standardise table padding

-   Headers: `12px 16px` (was various)
-   Cells: `10px 16px` (was various)
-   Use `font-variant-numeric: tabular-nums` on all numeric cells

### Step 4: Fix chart typography

-   All SVGs must use Inter font stack
-   Font sizes aligned to design token scale (xs=10, sm=11, base=13,
    md=14)

### Step 5: Refactor & de-bloat

-   Remove any CSS that duplicates what `turas_base_css()` already
    provides
-   Consolidate repeated colour values into module-level constants
-   Remove dead CSS rules

------------------------------------------------------------------------

## Session 1: KEYDRIVER

**Files to modify:** -
`modules/keydriver/lib/html_report/03_page_builder.R` -
`modules/keydriver/lib/html_report/02_table_builder.R` -
`modules/keydriver/lib/html_report/05_chart_builder.R` -
`modules/keydriver/lib/html_report/06_quadrant_section.R`

**Module-specific issues:**

1.  **Callouts not using registry** — 5 callouts defined in
    `callouts.json` (shapley_importance, method_comparison,
    effect_sizes, correlation_matrix, priority_quadrant). Currently
    built as manual HTML divs.

2.  **40+ hardcoded colour values** across all files:

    -   Table builder: bar colours `#2563EB/#3B82F6/#93C5FD/#DBEAFE`,
        status badges, delta colours, heatmap gradients
    -   Page builder: header gradient, verdict badges
    -   Chart builder: already has module constants (`.kd_label_colour`
        etc.) — good pattern, just needs token alignment

3.  **Quadrant chart uses wrong font** — `06_quadrant_section.R:100`
    hardcodes system font stack instead of Inter. Fix to use
    `.kd_font_family`.

4.  **Table styling** — no zebra striping, hardcoded `#f0f0f0` borders,
    padding at `2px 10px` for badges.

5.  **Help system inline** — `07_v104_sections.R` may have additional
    hardcoded values to check.

**Estimated complexity:** Medium (4 files, well-structured constants
pattern in chart builder)

------------------------------------------------------------------------

## Session 2: CATDRIVER

**Files to modify:** -
`modules/catdriver/lib/html_report/03_page_builder.R` -
`modules/catdriver/lib/html_report/02_table_builder.R` -
`modules/catdriver/lib/html_report/05_chart_builder.R`

**Module-specific issues:**

1.  **Callouts not using registry** — 5 callouts defined in
    `callouts.json` (driver_importance, odds_ratios, factor_patterns,
    probability_lifts, diagnostics). Help system uses inline JSON (lines
    99-120) instead.

2.  **Wrong CSS variable prefix** — Table header uses
    `var(--ct-bg-muted)` (crosstabs prefix) instead of
    `var(--cd-bg-muted)`. One-line fix but critical.

3.  **Hardcoded colours** — Fewer than keydriver, but scattered:

    -   SVG charts: `#e2e8f0`, `#94a3b8`, `#334155`, `#64748b`
    -   Table: `#f0f0f0` borders, `#f9fafb` zebra, `#f0fdf4` reference
        row
    -   Probability lift: `#EF4444` red hardcoded

4.  **Table padding non-standard** — Headers `10px 14px`, cells
    `8px 14px`. Should be `12px 16px` / `10px 16px`.

5.  **Help modal not integrated with callout registry** — Lines 99-120
    build inline help JSON.

**Estimated complexity:** Low-Medium (fewest issues, best-aligned
module)

------------------------------------------------------------------------

## Session 3: CONJOINT (Report + Simulator)

**Files to modify:** -
`modules/conjoint/lib/html_report/03_page_builder.R` (1,600+ lines) -
`modules/conjoint/lib/html_report/05_chart_builder.R` -
`modules/conjoint/lib/html_report/02_table_builder.R` -
`modules/conjoint/lib/html_simulator/02_simulator_page_builder.R` -
`modules/conjoint/lib/html_simulator/js/simulator_ui.js` (brand
fallback)

**Module-specific issues:**

1.  **Callouts hardcoded** — 3 callouts in `callouts.json`
    (reading_utilities, convergence_pass, convergence_fail). Currently
    built inline in page builder.

2.  **Simulator CSS is standalone** — `02_simulator_page_builder.R`
    lines 114-157 hardcode ALL styles with `gsub("BRAND", brand)`
    replacement instead of properly using `turas_base_css()`. It does
    call `turas_base_css()` on line 30 but then layers massive inline
    CSS on top.

3.  **Pin button SVG colour** — `#8B2332` hardcoded 8+ times for pin
    icon stroke. Not in design tokens. Should use brand or accent
    colour.

4.  **Simulator annotation colours** — `#d4a843`, `#92700c`, `#fbbf24`,
    `#fffbeb` hardcoded for annotation borders/backgrounds.

5.  **Mixed CSS prefixes** — Report uses `--cj-*`, simulator uses
    `--sim-*`. Should unify under `--cj-*`.

6.  **Print CSS hardcoded** — Lines 589-598 use hardcoded colours
    instead of CSS vars.

7.  **390+ lines of module CSS after `turas_base_css()`** — Much of this
    duplicates shared styles. Needs careful trimming.

**Estimated complexity:** High (two systems, lots of CSS duplication)

------------------------------------------------------------------------

## Session 4: MAXDIFF (Report + Simulator)

**Files to modify:** -
`modules/maxdiff/lib/html_report/03_page_builder.R` (\~2,000 lines) -
`modules/maxdiff/lib/html_report/04_chart_builder.R` -
`modules/maxdiff/lib/html_report/02_table_builder.R` -
`modules/maxdiff/lib/html_simulator/02_simulator_page_builder.R` -
`modules/maxdiff/lib/html_simulator/js/simulator_export.js` (font fix)

**Module-specific issues:**

1.  **Callouts not using registry** — 2 callouts in `callouts.json`
    (how_to_read, item_analysis). Built inline with hardcoded styles.

2.  **Simulator export JS uses wrong font** — `simulator_export.js`
    lines 97, 183, 185, 207-217 use `font-family="system-ui,sans-serif"`
    instead of Inter. Exported PNGs look generic.

3.  **Three parallel CSS token systems** — `--md-*` (report), `--sim-*`
    (simulator), `--t-*` (shared base). Should consolidate.

4.  **Chart palette not brand-aware** — `generate_md_palette()` only
    uses brand colour for first item, remaining 7 are hardcoded.

5.  **Callout inline styles mix approaches** — Background hardcoded
    (`#f8fafc`), border uses CSS var. Inconsistent.

6.  **Header gradient fixed** —
    `linear-gradient(135deg, #1a2744, #2a3f5f)` regardless of brand.

**Estimated complexity:** High (two systems, font fix in JS, triple
token system)

------------------------------------------------------------------------

## Session 5: SEGMENT

**Files to modify:** -
`modules/segment/lib/html_report/03_page_builder.R` (3,920 lines —
largest!) - `modules/segment/lib/html_report/02_table_builder.R` -
`modules/segment/lib/html_report/05_chart_builder.R`

**Module-specific issues:**

1.  **Callouts not using registry** — 2 callouts in `callouts.json`
    (interpretation_guide, how_it_works). Guide section at line 3333+ is
    hardcoded.

2.  **Checkbox accent-color hardcoded** — Line 2918:
    `accent-color:#323367` should be `accent-color: var(--seg-brand)`.

3.  **Modal shadow hardcoded** — Lines 1774-1790: `rgba(0,0,0,0.2)`
    instead of CSS var.

4.  **Accuracy indicator colours hardcoded** — Lines 2833, 3084:
    `#22c55e`, `#f59e0b`, `#ef4444`.

5.  **Table cell status colours** — Lines 646-667: `.seg-td-high` etc.
    use hardcoded backgrounds. These are semantic so may be acceptable,
    but should align with design tokens.

6.  **Best-integrated module** — Already uses CSS custom properties
    extensively, proper prefixing, good token alignment. Mostly minor
    fixes.

**Estimated complexity:** Low (best integrated, mostly minor fixes
despite large file)

------------------------------------------------------------------------

## Session 6: PRICING (Report + Simulator)

**Files to modify:** -
`modules/pricing/lib/html_report/03_page_builder.R` (massive CSS
section) - `modules/pricing/lib/html_report/04_chart_builder.R` -
`modules/pricing/lib/html_report/02_table_builder.R` -
`modules/pricing/lib/html_report/01_data_transformer.R` (callouts
hardcoded here) -
`modules/pricing/lib/simulator/css/simulator_styles.css` (341 lines,
standalone) - `modules/pricing/lib/simulator/simulator_builder.R`

**Module-specific issues:**

1.  **Wrong default brand colour** — Uses `#1e3a5f` instead of platform
    standard `#323367`. This is the ONLY module with a different
    default.

2.  **1000+ lines of hardcoded CSS** — Page builder lines 188-727
    duplicate rules already in `turas_base_css()`. Massive de-bloat
    opportunity.

3.  **Simulator CSS completely standalone** — `simulator_styles.css`
    (341 lines) hardcodes `--sim-brand: #1e3a5f`, duplicates entire
    design system. Not configurable.

4.  **Callouts hardcoded in data transformer** — Not even in page
    builder. Must move to use `turas_callout()`.

5.  **VW curve colours hardcoded** — `#e74c3c`, `#f39c12`, `#3498db`,
    `#2ecc71` for too_cheap/cheap/expensive/too_expensive. These are
    semantic so acceptable, but should be documented as intentional.

6.  **Chart palette** — Same issue as MaxDiff: only first colour is
    brand-aware, rest are fixed.

7.  **Massive colour duplication** — `#1e3a5f` appears \~8 times,
    `#64748b` appears 50+ times across files.

**Estimated complexity:** Highest (worst integration, most de-bloating
needed, wrong defaults)

------------------------------------------------------------------------

## Parallel Session Assignment Strategy

Sessions can run simultaneously since each touches different module
directories. The shared design system files are read-only.

**Pair sessions by complexity to balance workload:**

| Session | Module    | Complexity | Est. Changes           |
|---------|-----------|------------|------------------------|
| 1       | Keydriver | Medium     | \~4 files, \~80 edits  |
| 2       | Catdriver | Low-Medium | \~3 files, \~40 edits  |
| 3       | Conjoint  | High       | \~5 files, \~120 edits |
| 4       | MaxDiff   | High       | \~5 files, \~100 edits |
| 5       | Segment   | Low        | \~3 files, \~30 edits  |
| 6       | Pricing   | Highest    | \~6 files, \~150 edits |

**Recommended groupings if running fewer than 6 sessions:** - **3
sessions:** (Keydriver + Catdriver) \| (Conjoint + MaxDiff) \|
(Segment + Pricing) - **4 sessions:** Keydriver \| Catdriver + Segment
\| Conjoint \| MaxDiff + Pricing

------------------------------------------------------------------------

## Post-Session: Refactor & Verify

After all parallel sessions complete:

1.  **Merge all changes** onto `feature/visual-polish`
2.  **Regenerate showreel reports** for all 6 modules
3.  **Visual diff** — Compare before/after screenshots
4.  **Check Report Hub** — Ensure no CSS prefix collisions when reports
    are embedded
5.  **CSS audit** — grep for remaining hardcoded hex values that should
    be tokens
6.  **File size check** — Ensure no significant bloat (target: net
    reduction from de-duplication)

------------------------------------------------------------------------

## Session Prompt Template

Use this prompt structure to kick off each session:

```         
We are doing visual polish on the {MODULE} module's HTML report.
Branch: feature/visual-polish

Reference implementation: modules/confidence/lib/html_report/03_page_builder.R

The shared design system is at modules/shared/lib/design_system/ and provides:
- turas_design_tokens(brand, accent) — returns named list of ~60 tokens
- turas_base_css(brand, accent, prefix) — returns complete shared CSS
- turas_font_face_css() — returns Inter font @font-face CSS
- turas_callout(module, key, collapsed) — returns callout HTML from registry

Callouts for {MODULE} are already defined in modules/shared/lib/callouts/callouts.json.

DO NOT modify any shared files (design_system/, callouts/).

Tasks:
1. Wire up callout registry — source callout_registry.R, replace hardcoded callout HTML with turas_callout() calls
2. Replace hardcoded colours with CSS variables/design tokens
3. Standardise table padding (headers 12px 16px, cells 10px 16px)
4. Fix chart typography (Inter font, token-aligned sizes)
5. De-bloat: remove CSS that duplicates turas_base_css() output
{MODULE-SPECIFIC TASKS}

After changes, the report should look identical or better — no visual regressions.
Keep changes lean. No new features. No over-engineering.
```

------------------------------------------------------------------------

## Key Rules

1.  **DO NOT modify shared files** — design_system/ and callouts/ are
    frozen during parallel work
2.  **Preserve visual output** — changes should improve consistency, not
    break layouts
3.  **Lean changes** — remove bloat, don't add it
4.  **Test by regenerating** — each session should produce a test report
    to verify
5.  **Note any needed shared changes** — if a new token or callout is
    needed, log it for a follow-up batch
