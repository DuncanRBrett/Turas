# Turas Tabs - Report Colour Reference

> Reference for the colours the tabs report uses: what the config controls,
> what is fixed by design, and why.

---

## 1. Configurable Colours (via Config)

These colours are set per-project in the crosstab configuration and flow through the entire report.

### 1.1 Brand Colour

| Field | Default | Format |
|-------|---------|--------|
| `brand_colour` | `#323367` (deep navy) | Hex 6-digit |

**Used in:** the report's own accent throughout — sidebar and header
chrome, active tabs and chips, focus states, dashboard section headings
and gauge labels — and as the first series colour in charts, with
brand-derived shades filling later series.

### 1.2 Accent Colour

| Field | Default | Format |
|-------|---------|--------|
| `accent_colour` | `#CC9900` (gold) | Hex 6-digit |

**Used in:**

- CSS variable `--ct-accent` (available for future use)
- **Crosstab heatmap cell tint** (default source — see `heatmap_colour` below)
- Total column header text in crosstab tables

### 1.3 Heatmap Colour

| Field | Default | Format |
|-------|---------|--------|
| `heatmap_colour` | *(accent_colour)* | Hex 6-digit |

**What it does:** Controls the tint colour used for heatmap cell backgrounds in crosstab tables. RGB is extracted from this hex value and blended with white at varying alpha levels (0.08–0.43) proportional to the cell's value.

**Resolution order:**
1. `heatmap_colour` — explicit override per project
2. `accent_colour` — default source (warm cream for standard TRL configs with `#CC9900`)
3. Hard fallback `#CC9900`

**Why decoupled from brand_colour:** The previous behaviour (using `brand_colour` as the heatmap tint) produced cool-blue heatmaps for the standard deep-navy brand. Defaulting to `accent_colour` gives a warm cream tint that reads more neutrally and is easier to scan. Set `heatmap_colour` explicitly if you want a different tint without changing your brand or accent colours.

### 1.4 Dashboard Threshold Cutoffs

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

### 1.5 Chart Bar Colour

| Field | Default | Format |
|-------|---------|--------|
| `chart_bar_colour` | Falls back to `brand_colour` | Hex 6-digit |

**Used in:** the single-series default. With one banner column charted,
this colour replaces the brand colour at the front of the series palette.
It has no effect when `chart_series_colour_*` values are set — those take
the lead (see below).

### 1.6 Custom Series Colours (Banner Breaks)

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

**How they resolve:** configured colours lead the series palette in the
order given; any further columns fall back to the report's built-in
sequence (brand, accent, brand shades, then distinguishable defaults).
Blank and malformed values are dropped before the palette is built, so a
placeholder like "Optional" left in the template cannot reach a chart.

**Sentiment charts are never affected** — stacked bars for ordinal and
scale questions always colour from `chart_palette_preset`, whatever the
series colours say.

**Example 1 — Full corporate palette:**

| Setting | Value | Effect |
|---------|-------|--------|
| `chart_palette_preset` | `research` | Stacked bars: purple-green semantic |
| `chart_series_colour_1` | `#1B365D` | Total: navy |
| `chart_series_colour_2` | `#3A6EA5` | 2nd break: blue |
| `chart_series_colour_3` | `#E87722` | 3rd break: orange |
| `chart_series_colour_4` | `#5B9A7D` | 4th break: sage |
| `chart_series_colour_5` | `#8E4585` | 5th break: purple |

**Example 2 — Hybrid (custom Total, rest auto-generated):**

| Setting | Value | Effect |
|---------|-------|--------|
| `chart_palette_preset` | `warm` | Stacked bars: earth tones |
| `chart_series_colour_1` | `#DC2626` | Total: red (custom) |
| `chart_series_colour_2` | *(blank)* | Auto-generated, avoids red hues |
| `chart_series_colour_3` | *(blank)* | Auto-generated, distinct from above |

**Example 3 — No custom colours (auto-generation only):**

Leave all `chart_series_colour_*` fields blank. The system generates a visually distinct palette from `chart_bar_colour` for any number of banner series.

**Report Hub:** Custom series colours carry through automatically. They
are embedded in each report's data island, and the report hub passes them
through without modification.

---

## 2. Hardcoded Colours - Intentional

These are hardcoded by design because they carry universal meaning.

### 2.1 Semantic Chart Palette (Configurable Presets)

Used in stacked bar charts for ordinal/scale questions. The presets are
resolved by `get_palette_colours()` in `lib/report_shared.R` and carried
into the report's data layer, so the workbook and the report agree.
Selected via the `chart_palette_preset` config field.

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

## Note on scope

Sections describing the retired classic report's own CSS (UI chrome, slide
export, pinned-view and insight-export colours) were removed when that report
was deleted in August 2026. What remains is what the config still controls and
what the interactive report still reads.

---

## 3. Quick Config Reference

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
