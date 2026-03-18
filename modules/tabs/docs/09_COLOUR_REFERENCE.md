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

**Used in:** Horizontal bar charts (nominal questions). When only a single banner column is displayed, this colour is used directly. When multiple banner columns are selected and no custom series colours are defined, this colour is used as the seed for auto-generating a distinct palette via HSL rotation.

### 1.5 Custom Series Colours (Banner Breaks)

Optional per-series colour overrides for nominal bar charts with multiple banner columns (e.g., Total, Cape Town, Johannesburg). These allow clients to use their corporate colour scheme on bar charts.

| Field | Required | Description |
|-------|----------|-------------|
| `chart_series_colour_1` | Optional | Colour for 1st banner series (e.g., Total) |
| `chart_series_colour_2` | Optional | Colour for 2nd banner series |
| `chart_series_colour_3` | Optional | Colour for 3rd banner series |
| `chart_series_colour_4` | Optional | Colour for 4th banner series |
| `chart_series_colour_5` | Optional | Colour for 5th banner series |
| `chart_series_colour_6` | Optional | Colour for 6th banner series |
| `chart_series_colour_7` | Optional | Colour for 7th banner series |
| `chart_series_colour_8` | Optional | Colour for 8th banner series |

**Behaviour:**
- If **no series colours** are defined → `chart_bar_colour` is used with auto-generated HSL rotation (existing behaviour, unchanged).
- If **any series colours** are defined → they are used sequentially for each banner column. Colours are assigned in the order columns appear in the chart toggle chips.
- If there are **more series than colours defined** → colours cycle back to the start (with a console warning).
- **Stacked bar charts are not affected** — they always use `chart_palette_preset` and the semantic colour mapping.

**Interaction with other settings:**
- `chart_palette_preset` controls stacked bars only — completely independent of series colours.
- `chart_bar_colour` is still used as the single-column fallback and as the seed for auto-generation when no series colours are defined.

**Example configuration (client corporate colours):**

| Setting | Value |
|---------|-------|
| `chart_palette_preset` | `research` |
| `chart_series_colour_1` | `#1B365D` |
| `chart_series_colour_2` | `#3A6EA5` |
| `chart_series_colour_3` | `#E87722` |
| `chart_series_colour_4` | `#5B9A7D` |
| `chart_series_colour_5` | `#8E4585` |

In this example, stacked bars use the research preset (purple-green semantic palette) while nominal bar charts use the client's five corporate colours.

**Report Hub:** Custom series colours carry through automatically. The colours are embedded in each tab report's HTML/JS data, and the report hub parses them as-is without modification.

---

## 2. Hardcoded Colours - Intentional

These are hardcoded by design because they carry universal meaning.

### 2.1 Semantic Chart Palette (Configurable Presets)

Used in stacked bar charts for ordinal/scale questions. Colours map to survey response sentiment via `get_semantic_colour()` in `07_chart_builder.R`. Five presets are available, selected via the `chart_palette_preset` config field.

#### Warm Preset (default)

| Sentiment | Hex | Description |
|-----------|-----|-------------|
| Negative | `#b85450` | Dusty rose-red |
| Mod negative | `#d4918e` | Blush |
| Neutral | `#c9a96e` | Warm sand |
| Mod positive | `#7daa8c` | Sage |
| Positive | `#4a7c6f` | Deep teal-green |
| DK/NA | `#d1cdc7` | Warm grey |

#### Cool Preset

| Sentiment | Hex | Description |
|-----------|-----|-------------|
| Negative | `#a65461` | Muted burgundy |
| Mod negative | `#c78f93` | Dusty pink |
| Neutral | `#94a3b8` | Steel grey |
| Mod positive | `#6f9fa8` | Muted teal |
| Positive | `#3d7a8a` | Deep teal |
| DK/NA | `#d1cdc7` | Warm grey |

#### Research Preset

| Sentiment | Hex | Description |
|-----------|-----|-------------|
| Negative | `#8e4585` | Muted purple |
| Mod negative | `#b891b5` | Lavender |
| Neutral | `#b8b8b8` | True neutral grey |
| Mod positive | `#7daa8c` | Sage |
| Positive | `#3d7a5f` | Forest |
| DK/NA | `#d1cdc7` | Warm grey |

#### Teal Preset

| Sentiment | Hex | Description |
|-----------|-----|-------------|
| Negative | `#d4edea` | Pale teal |
| Mod negative | `#a3d5cf` | Light teal |
| Neutral | `#6dbfb8` | Medium teal |
| Mod positive | `#4a9e95` | Deep teal |
| Positive | `#2d7a72` | Dark teal |
| DK/NA | `#d1cdc7` | Warm grey |

#### Brand Preset

Dynamically generated from the `brand_colour` config setting. The brand colour's hue is extracted and used to produce a 5-stop monochromatic gradient from 88% lightness (lightest) to 30% lightness (darkest), desaturated to a maximum of 45% for a muted, professional look. DK/NA and Other remain warm grey.

**Configuration:** Set via `chart_palette_preset` in the Settings sheet. The semantic label-matching logic is unchanged -- only the hex values differ between presets.

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

### 2.3 Categorical Palette (Non-Ordinal)

10-colour qualitative palette for nominal data (regions, brands, etc.):

| Colour | Hex | Name |
|--------|-----|------|
| 1 | `#5b7e9a` | Steel blue |
| 2 | `#c47f5a` | Warm terracotta |
| 3 | `#6a9a7b` | Sage green |
| 4 | `#9b6b8a` | Dusty plum |
| 5 | `#b8a04c` | Muted gold |
| 6 | `#7a8e9e` | Grey-blue |
| 7 | `#c27878` | Dusty rose |
| 8 | `#5a8a8a` | Teal |
| 9 | `#a89060` | Warm khaki |
| 10 | `#8a7aaa` | Muted lavender |

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

Colours now use the global `BRAND_COLOUR` variable instead of hardcoded `#323367`.

| Element | Colour | Source |
|---------|--------|--------|
| Pin button (active) | `BRAND_COLOUR` text + border | Dynamic via JS variable |
| Pin button (inactive) | `#94a3b8` text, `#e2e8f0` border | Hardcoded |
| Pinned card border | `#e2e8f0` | Hardcoded |
| Pinned card code | `BRAND_COLOUR` | Dynamic via JS variable |
| Pinned card title | `#1e293b` | Hardcoded |
| Pinned card meta | `#94a3b8` | Hardcoded |
| Insight accent border | `BRAND_COLOUR` | Dynamic via JS variable |
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

### JS Brand Colour - RESOLVED

**RESOLVED in v10.8.0**: All JS files now use the global `BRAND_COLOUR` variable injected from R via `<script>var BRAND_COLOUR = "...";</script>`. The hardcoded `#323367` references in `pinned_views.js`, `slide_export.js`, `chart_picker.js`, and `core_navigation.js` have been replaced.

---

## 5. Quick Config Reference

Minimum configuration for colour customisation:

```r
config_obj$brand_colour <- "#1B4F72"   # Your brand colour
config_obj$accent_colour <- "#D4AC0D"  # Your accent colour
config_obj$chart_palette_preset <- "warm"  # Options: "warm", "cool", "research", "teal", "red", "brand"
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
