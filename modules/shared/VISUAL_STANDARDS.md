# Turas Visual Standards

Reference guide for consistent visual treatment across all Turas report modules.

---

## Color Palette Presets

Three configurable sentiment palettes for ordinal (Likert/Rating/NPS) charts. Set via `chart_palette_preset` config field. Default: `warm`.

### Warm (Earth Tones)

| Role | Hex | Description |
|------|-----|-------------|
| Negative | `#b85450` | Dusty rose-red |
| Mod negative | `#d4918e` | Blush |
| Neutral | `#c9a96e` | Warm sand |
| Mod positive | `#7daa8c` | Sage |
| Positive | `#4a7c6f` | Deep teal-green |
| DK/NA | `#d1cdc7` | Warm grey |

### Cool (Blue-Anchored)

| Role | Hex | Description |
|------|-----|-------------|
| Negative | `#a65461` | Muted burgundy |
| Mod negative | `#c78f93` | Dusty pink |
| Neutral | `#94a3b8` | Steel grey |
| Mod positive | `#6f9fa8` | Muted teal |
| Positive | `#3d7a8a` | Deep teal |
| DK/NA | `#d1cdc7` | Warm grey |

### Research (Purple-Green Diverging)

| Role | Hex | Description |
|------|-----|-------------|
| Negative | `#8e4585` | Muted purple |
| Mod negative | `#b891b5` | Lavender |
| Neutral | `#b8b8b8` | True neutral grey |
| Mod positive | `#7daa8c` | Sage |
| Positive | `#3d7a5f` | Forest |
| DK/NA | `#d1cdc7` | Warm grey |

### RAG (Dashboard Gauges & Heatmaps)

| Tier | Hex | Usage |
|------|-----|-------|
| Green | `#4a7c6f` | Above green threshold |
| Amber | `#c9a96e` | Between amber and green |
| Red | `#b85450` | Below amber threshold |

### Categorical Palette (Non-Ordinal)

10-colour qualitative palette for nominal data (regions, brands, etc.):

```
#5b7e9a  steel blue
#c47f5a  warm terracotta
#6a9a7b  sage green
#9b6b8a  dusty plum
#b8a04c  muted gold
#7a8e9e  grey-blue
#c27878  dusty rose
#5a8a8a  teal
#a89060  warm khaki
#8a7aaa  muted lavender
```

---

## Typography Scale

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Report title (header) | 26px | 700 | `#ffffff` |
| Product name (header) | 13px | 600 | `rgba(255,255,255,0.7)` |
| Section title | 14px | 700 | `#1a2744` |
| Question text | 16px | 600 | `#1a2744` |
| Question code | 11px | 500 | `#94a3b8` |
| Body text / insight | 14px | 400 | `#1e293b` |
| Table body | 13px | 400 | `#1e293b` |
| Table header | 12px | 600 | inherited |
| Metadata / captions | 11px | 400-600 | `#64748b` |
| Badge text | 9-10px | 700 | varies |

---

## Card Styling

| Property | Value |
|----------|-------|
| Background | `#ffffff` |
| Border | `1px solid #e8e5e0` |
| Border radius | `8px` |
| Padding | `20px 24px` (cards), `14px 20px` (insight callouts) |

---

## Insight Callout Pattern

```css
border-left: 3px solid BRAND;
background: #f8fafa;
border-radius: 0 6px 6px 0;
padding: 14px 20px;
```

Includes a `::before` pseudo-element with "KEY INSIGHT" small-caps label (9px, `#94a3b8`).

---

## Chart Conventions

- **Stacked bars:** Labels inside segment only when segment > 20% of bar. Percentage only for 8-20%. Nothing for < 8%.
- **Label font:** 12px, weight 500, `font-variant-numeric: tabular-nums`
- **Legend:** Includes percentage values alongside colour swatches
- **Bar corners:** `rx="3"` or `rx="4"` for rounded appearance
- **Horizontal bars:** Single brand colour, `opacity: 0.85`

---

## Table Styling

| Property | Value |
|----------|-------|
| Cell padding | `8px 12px` |
| Header background | `#f8f9fa` |
| Row separator | `1px solid #f0f0f0` |
| Category row hover | `background: #f8f9fb` |
| Net row background | `#f5f3ef` |
| Net row text | `#1e293b` (dark, weight 700) |
| Mean row background | `#faf8f4` |
| Mean row text | `#475569` (dark grey, italic) |

---

## Print Stylesheet Requirements

- `page-break-after: always` per question / pinned card
- `page-break-inside: avoid` for chart wrappers and cards
- `-webkit-print-color-adjust: exact; print-color-adjust: exact` for chart and heatmap colours
- Hide all interactive controls (sidebar, toggles, buttons, editors)
- Header converts to compact black text on white

---

## Brand Colour

- Set via `brand_colour` config field
- Flows to CSS via `--ct-brand` / `--brand-colour` variables
- Flows to JS via global `BRAND_COLOUR` variable
- No hardcoded hex values in JS files; all reference `BRAND_COLOUR`

---

## Cross-Module Consistency

All Turas reports must share:
1. Same font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
2. Same text colour hierarchy: `#1e293b` primary, `#64748b` secondary, `#94a3b8` muted
3. Same border colour: `#e2e8f0` structural, `#f0f0f0` light separators
4. Same card pattern: white bg, 1px border, 8px radius
5. Same chart bar styling: rounded corners, muted palette
6. Coordinate RAG colours across dashboard and chart modules
