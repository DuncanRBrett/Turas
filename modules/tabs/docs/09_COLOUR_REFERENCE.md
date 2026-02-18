# Turas HTML Report - Colour Reference

> Complete reference for all colours used in the HTML report module.
> Covers what is configurable, what is hardcoded, and why.

---

## 1. Configurable Colours (via Config)

These colours are set per-project in the crosstab configuration and flow through the entire report.

### 1.1 Brand Colour

| Field | Default | Format |
|-------|---------|--------|
| `brand_colour` | `#323367` (deep navy) | Hex 6-digit |

**Used in (~40+ CSS rules via `gsub("BRAND", ...)` substitution):**

- Sidebar: active item indicator, active question code text
- Header: bottom border accent
- Search box: focus border
- Banner tabs: active tab background
- Toggle controls: checkbox accent colour
- Question title card: banner name label, stat label
- Column chips: hover border, active chip text
- Insight toggle: hover border and text colour
- Insight editor: left border accent
- Help overlay: heading colour, keyboard shortcut badges
- Footer: link colour
- Crosstab heatmap: cell background (RGB extracted, alpha varies by value)
- Charts: fallback bar colour (when no semantic match), brand-derived shades
- Dashboard: section headers, gauge labels, heatmap headers, significance cards

### 1.2 Accent Colour

| Field | Default | Format |
|-------|---------|--------|
| `accent_colour` | `#CC9900` (gold) | Hex 6-digit |

**Used in:**

- CSS variable `--ct-accent` (available for future use)
- Currently minimal direct usage beyond the CSS variable declaration

### 1.3 Dashboard Threshold Cutoffs

These control *when* the traffic light colours change, not the colours themselves.

| Field | Default | Controls |
|-------|---------|----------|
| `dashboard_green_net` | `30` | NET Positive green threshold |
| `dashboard_amber_net` | `0` | NET Positive amber threshold |
| `dashboard_green_mean` | `7` | Mean score green threshold |
| `dashboard_amber_mean` | `5` | Mean score amber threshold |
| `dashboard_green_index` | `7` | Index score green threshold |
| `dashboard_amber_index` | `5` | Index score amber threshold |
| `dashboard_green_custom` | `60` | Custom metric green threshold |
| `dashboard_amber_custom` | `40` | Custom metric amber threshold |

### 1.4 Chart Bar Colour

| Field | Default | Format |
|-------|---------|--------|
| `chart_bar_colour` | Falls back to `brand_colour` | Hex 6-digit |

**Used in:** Horizontal bar charts (nominal questions). Passed via `data.chart_bar_colour` in the chart JSON data, read by `chart_picker.js`.

---

## 2. Hardcoded Colours - Intentional

These are hardcoded by design because they carry universal meaning.

### 2.1 Semantic Chart Palette

Used in stacked bar charts for ordinal/scale questions. Colours map to survey response sentiment via `get_semantic_colour()` in `07_chart_builder.R`.

| Sentiment Tier | Colour | Hex | Labels Matched |
|---------------|--------|-----|----------------|
| Strong negative | Coral red | `#c0695c` | Negative, Poor, Detractor, Do not trust, Would switch, Strongly disagree, Very dissatisfied |
| Mild negative | Light coral | `#cf8a7c` | Below average, Dissatisfied, Disagree |
| Neutral | Amber gold | `#e8c170` | Neutral, Average, Passive, Undecided, Some trust, Neither agree nor disagree |
| Mild positive | Sage green | `#68a67d` | Satisfied, Above average, Agree, Good |
| Strong positive | Deep green | `#3d8b5e` | Positive, Excellent, Promoter, Fully trust, Would not switch, Strongly agree |
| DK / NA / Refused | Silver grey | `#d4d4d4` | DK, NA, DK/NA, Don't know, Not applicable, N/A, Refused, Prefer not to say |
| Other | Warm grey | `#c5c0b8` | Other |

**Why hardcoded:** Red-to-green sentiment mapping is a universal survey convention. Allowing per-project overrides would risk creating misleading visualisations (e.g., making "Detractor" green).

**Fallback behaviour:** When a row label does not match any semantic keyword, the chart uses brand-colour-derived shades. The brand colour is parsed to RGB and shades are generated from 30% to 100% intensity, lightest to darkest.

### 2.2 Dashboard Traffic Light Colours

Used for gauge arcs, heatmap cell tints, and significance cards.

| Tier | Colour | Hex | Meaning |
|------|--------|-----|---------|
| Green | Emerald | `#059669` | Value >= green threshold |
| Amber | Amber | `#d97706` | Value >= amber threshold but < green |
| Red | Red | `#dc2626` | Value < amber threshold |
| N/A | Cool grey | `#94a3b8` | Missing or unavailable value |

**Heatmap cell tints (rgba variants of the same colours):**

| Tier | Background | Text Colour | Font Weight |
|------|-----------|-------------|-------------|
| Strong green | `rgba(5,150,105,0.18)` | `#059669` | 700 (bold) |
| Green | `rgba(5,150,105,0.10)` | `#059669` | Normal |
| Amber | `rgba(217,119,6,0.10)` | `#b45309` | Normal |
| Red | `rgba(220,38,38,0.12)` | `#dc2626` | Normal |

**Why hardcoded:** Traffic light colours (green/amber/red) have universal meaning in business dashboards. The *threshold values* where colours change are fully configurable (see Section 1.3).

---

## 3. Hardcoded Colours - UI Chrome

These are structural/neutral colours used for backgrounds, borders, and text throughout the report. They form a consistent neutral palette that works with any brand colour.

### 3.1 Text Colours

| Colour | Hex | Usage |
|--------|-----|-------|
| Near-black | `#1a2744` | Slide titles, dark headings |
| Dark charcoal | `#1e293b` | Primary body text, question titles |
| Dark grey | `#374151` | Secondary text, chart labels, insight text |
| Medium grey | `#5c4a3a` | Chart value labels on light backgrounds |
| Steel grey | `#64748b` | Metadata text, axis labels, chart legends |
| Cool grey | `#94a3b8` | Tertiary text, timestamps, subtle labels |
| Coral red | `#e8614d` | Filter warnings, remove/delete actions |

### 3.2 Background Colours

| Colour | Hex | Usage |
|--------|-----|-------|
| White | `#ffffff` | Page background, card backgrounds, canvas fill |
| Off-white | `#fafbfc` | Alternating table rows (even) |
| Warm cream | `#fef9e7` | NET row background |
| Warm beige | `#f5f0e8` | Mean/summary row background |
| Light grey | `#f8f9fa` | Table header background, sidebar |
| Pale grey | `#f8f9fb` / `#f8fafa` | Insight editor background |
| Ice grey | `#f1f5f9` | Print layout table headers |
| Soft blue-grey | `#f9fafb` | Base row background |
| Light teal | `#f0fafa` | Priority metric pill background |

### 3.3 Border Colours

| Colour | Hex | Usage |
|--------|-----|-------|
| Light border | `#e2e8f0` | Card borders, divider lines, table cell borders, pin button default |
| Medium border | `#d0e8e8` | Priority metric pill stroke |
| Table border | `#ccc` | Print mode table wrapper |

### 3.4 Slide Export Colours

Used when rendering SVG slides for PNG export.

| Element | Colour | Source |
|---------|--------|--------|
| Slide background | `#ffffff` | Hardcoded |
| Title text | `#1a2744` | Hardcoded |
| Metadata text | `#94a3b8` | Hardcoded |
| Table header row | `#1a2744` (bg), `#ffffff` (text) | Hardcoded |
| Table even rows | `#fafbfc` | Hardcoded |
| Table borders | `#e2e8f0` | Hardcoded |
| Insight accent bar | `#323367` | Hardcoded (default brand) |
| Insight text | `#374151` | Hardcoded |

### 3.5 Pinned Views Colours

| Element | Colour | Source |
|---------|--------|--------|
| Pin button (active) | `#323367` text + border | Hardcoded (default brand) |
| Pin button (inactive) | `#94a3b8` text, `#e2e8f0` border | Hardcoded |
| Pinned card border | `#e2e8f0` | Hardcoded |
| Pinned card code | `#323367` | Hardcoded (default brand) |
| Pinned card title | `#1e293b` | Hardcoded |
| Pinned card meta | `#94a3b8` | Hardcoded |
| Insight accent border | `#323367` | Hardcoded (default brand) |
| Remove button text | `#e8614d` | Hardcoded |

### 3.6 Insights HTML Export Colours

| Element | Colour | Source |
|---------|--------|--------|
| Body text | `#1e293b` | Hardcoded |
| Metadata text | `#64748b` | Hardcoded |
| Question code | `#323367` | Hardcoded (default brand) |
| Insight left border | `#323367` | Hardcoded (default brand) |
| Insight background | `#f8f9fb` | Hardcoded |
| Banner label | `#94a3b8` | Hardcoded |

---

## 4. Known Colour Gap

### JS Files Do Not Receive Configured Brand Colour

The R-side CSS correctly substitutes the configured `brand_colour` via `gsub("BRAND", bc, ...)`. However, the 5 JavaScript files and their inline styles contain `#323367` (the *default* brand colour) hardcoded in approximately 15 locations.

**Impact:** If a client sets a brand colour other than `#323367`, the following elements will show the default navy instead of the client's colour:

| File | Element | Line(s) |
|------|---------|---------|
| `pinned_views.js` | Pin button active state | 40-41 |
| `pinned_views.js` | Insight accent border in pinned cards | 204 |
| `pinned_views.js` | Slide export insight accent bar | 359 |
| `pinned_views.js` | Print layout accent borders | 440, 450, 466 |
| `slide_export.js` | Slide insight accent bar | 343 |
| `slide_export.js` | Insights HTML export borders and code colour | 415-416 |

**Why it exists:** The JS files are loaded as standalone `.js` files and concatenated at build time. The `BANNER_GROUPS_JSON` placeholder substitution exists for banner data, but no equivalent `BRAND_COLOUR` substitution was implemented for colour.

**Workaround:** The main report display (sidebar, headers, tables, controls) correctly uses the configured brand colour. The mismatch only appears in exported slides, pinned view cards, and the insights HTML export.

---

## 5. Quick Config Reference

Minimum configuration for colour customisation:

```r
config_obj$brand_colour <- "#1B4F72"   # Your brand colour
config_obj$accent_colour <- "#D4AC0D"  # Your accent colour
```

Full dashboard threshold customisation:

```r
config_obj$dashboard_green_net    <- 30   # NET Positive: green if >= 30
config_obj$dashboard_amber_net    <- 0    # NET Positive: amber if >= 0
config_obj$dashboard_green_mean   <- 7    # Mean (out of 10): green if >= 7
config_obj$dashboard_amber_mean   <- 5    # Mean (out of 10): amber if >= 5
config_obj$dashboard_green_index  <- 7    # Index: green if >= 7
config_obj$dashboard_amber_index  <- 5    # Index: amber if >= 5
config_obj$dashboard_green_custom <- 60   # Custom %: green if >= 60
config_obj$dashboard_amber_custom <- 40   # Custom %: amber if >= 40
```
