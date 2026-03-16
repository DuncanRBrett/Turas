# Turas Tracker HTML Report — Design Specification

**Status:** Planning / Architecture  
**Purpose:** Specification for Claude Code implementation. This builds on existing Turas tracker infrastructure — it is NOT a from-scratch build.  
**Date:** 15 March 2026

---

## 1. Context

Turas already has:
- A **summary page** that shows key metrics and highlights significant changes over the last wave
- An **insights text editor** with localStorage persistence for analyst commentary
- An **annotation/callout system** for marking special events (e.g. "Campaign launched", "Price increase")
- Existing HTML report infrastructure (tabs module, key driver module, etc.)
- A `turas-sampling-method` meta tag system driving confidence/precision reporting

This spec covers the **tracker exploration views** — the deeper interactive report that sits alongside the summary page.

---

## 2. Data Type Taxonomy

All questions in the tracker must be classified into one of four data types. This classification is the foundational organising principle of the report — it determines what metrics are available, what the heatmap shows, and how comparisons work.

### 2.1 The Four Types

| Data Type | Headline Metric | Distribution View | Available Metrics |
|-----------|----------------|-------------------|-------------------|
| **NPS** | NPS score (−100 to +100) | Three categories (Promoter/Passive/Detractor) | NPS score, % Promoter, % Passive, % Detractor |
| **Ratings** | Mean rating | Scale points or top-box/bottom-box | Mean, Top-2-box %, Bottom-2-box % |
| **Likert scales** | Index or Top-2-box % | Full scale distribution | Index, Top-2-box %, individual scale point %s |
| **% Mentions** | % mention | N/A (the % *is* the distribution) | % mention |

### 2.2 Metric Mode

Rather than "primary" and "secondary" metrics, use the concept of **metric mode**. For any question, the data type determines what metrics are *available*. The user selects which metric they are viewing. The heatmap/line chart then shows that one metric consistently across all questions in the view.

- The metric selector should list only the metrics valid for the current data type
- When switching between question groups that have different data types, the metric selector must update accordingly
- Default metric mode per type: NPS → NPS score; Ratings → Mean; Likert → Top-2-box %; Mentions → % mention

### 2.3 Rule: Do Not Mix Data Types in the Same Visual

An NPS score of +35 next to a rating mean of 3.8 next to a mention rate of 42% — the eye cannot compare them, and the heatmap loses its power. Each heatmap/line chart view must be homogeneous by data type.

Exception: the Question Deep-Dive view (see §4.2) shows all metrics for a single question in one place — but with clear visual hierarchy, not side-by-side comparison.

---

## 3. Dimensions

### 3.1 Core Dimensions

Every data point in the tracker lives at the intersection of:
- **Question** (with data type classification and group membership)
- **Wave** (with metadata: dates, sample size, methodology notes, annotation callouts)
- **Banner** (Total + subgroup breakdowns)
- **Metric** (determined by question data type — see §2.1)

### 3.2 Question Grouping

Questions must be assigned to groups (e.g. "Brand Health", "Attitudes", "Usage", "Satisfaction"). This is metadata from the questionnaire design, defined in the data layer — not hard-coded in the report.

Groups serve as:
- Section headers with visual separation in heatmap views
- Filter/selector options in line chart views
- Optional summary/composite rows in the heatmap

### 3.3 Wave Metadata

Each wave must carry:
- Wave label/name
- Fieldwork dates (start and end)
- Sample sizes (total and per banner)
- Methodology notes (if methodology changed between waves)
- Annotation callouts for events
- Structural break markers (see §6.3 — questionnaire changes)

### 3.4 Value Display Modes

Three modes, toggled by the user:

1. **Absolute** — the metric value itself
2. **Change from previous wave** — with significance flag
3. **Change from baseline (wave 1)** — with significance flag

The heatmap colour scale must adapt per mode:
- **Absolute mode:** sequential scale (light to dark in a single hue)
- **Change modes:** diverging scale centred on zero (red through neutral through green)

Avoid traffic-light palettes — they create false precision. A single-hue ramp with highlight for outliers reads more cleanly.

---

## 4. View Modes

Three view modes, each answering a different question. The user should always know which mode they are in and be able to move between them fluidly.

### 4.1 View 1: Overview Heatmap

**Purpose:** "What's moving?" — high density scanning view  
**Axes:** Questions (rows, grouped by section) × Waves (columns), for a single selected banner  
**Shows:** One metric consistently across all questions

#### Visual Components

- **Heatmap grid** — each cell shows the number, coloured by intensity according to the active value display mode (absolute or change)
- **Row-end sparklines** — a tiny line chart at the right edge of each row showing the trend trajectory. The heatmap says "where are we now"; the sparkline says "what's the trajectory"
- **Row-end delta chip** — a small pill/badge showing change from baseline or previous wave (per active mode), colour-coded green/red/grey with significance marker (e.g. ↑* for significant increase)
- **Section summary rows** — optional subtly styled row at top of each group showing group average/composite. Lighter background, different typography
- **Column headers** — wave labels + sample size + annotation callout flags above relevant columns

#### Sort Options

Default is questionnaire order within groups. Additional sort options:
- Current value (highest to lowest)
- Magnitude of change (largest movement first)
- Significance (significant changes first)

#### Navigation

Clicking a question row opens View 2 (Question Deep-Dive) for that question.

### 4.2 View 2: Question Deep-Dive

**Purpose:** "What's happening with this question?" — medium density understanding view  
**Shows:** Everything about one question across all waves and banners

#### Visual Components

- **Hero card** — headline metric in large type with sparkline beside it. Below: change from baseline and previous wave with significance flags. This is the dominant visual element.
- **Distribution strip** — horizontal stacked bar per wave showing category breakdown (e.g. Promoter/Passive/Detractor, or scale point distribution). Waves stacked vertically to show distribution shifting over time. More informative than a line chart for understanding *how* a number moved.
- **Banner comparison panel** — small multiples: one mini line chart per banner, all on the same y-axis scale. Alternatively, a single overlaid line chart for ≤5 banners (beyond 5, use small multiples to avoid spaghetti). Annotation callouts appear as vertical marker lines with labels.
- **Secondary metrics row** — smaller cards for non-headline metrics, visually greyed back. Each with its own sparkline. Clickable to swap into the hero position.

#### Navigation

Clicking a banner in the comparison panel opens View 3 (Subgroup Comparison) for the current question filtered to that banner.

### 4.3 View 3: Subgroup Comparison

**Purpose:** "Where's the movement coming from?" — medium density diagnostic view  
**Axes:** Banners (rows or lines) × Waves (columns/x-axis), for a single selected question  
**Shows:** One metric across all subgroups over time

#### Visual Components — offer toggle between:

- **Small multiple line charts** — one panel per banner, same scales, same y-axis range. Clean, no legend needed. Best for ≥6 banners.
- **Overlaid line chart** — all banners on one chart, colour-coded. Works for ≤5 banners. Hover/tooltip shows exact values and significance vs. total.
- **Heatmap variant** — banners as rows, waves as columns. Same grammar as View 1 but pivoted. Good for spotting "which subgroup is the outlier this wave."

#### Additional Visual Options

- **Dot plots with confidence intervals** — horizontal dot plot with error bars, one row per banner. Answers "how do subgroups compare *right now*?" — a snapshot complement to the trend views.

### 4.4 Line Charts (Cross-cutting)

Line charts are an alternative rendering of Views 1 and 3, not a separate mode — toggled between heatmap and line chart within the same view. In View 1, a line chart shows selected questions over waves. In View 3, a line chart shows banners over waves.

### 4.5 Slope Charts (Optional/Future)

For two-wave comparisons. Left dot = baseline, right dot = current wave, connected by a line. Ranks questions by magnitude of change. Useful as an alternative rendering in View 1 when focusing on a specific pair of waves.

---

## 5. Visual Design Rules

### 5.1 Visual Hierarchy

| View | Density | Mode | Decoration |
|------|---------|------|------------|
| Overview Heatmap | High — many questions | Scanning | Minimal decoration, maximum data |
| Question Deep-Dive | Medium — one question | Understanding | Cards, charts, space to breathe |
| Subgroup Comparison | Medium — one question | Diagnostic | Comparative charts, aligned scales |

### 5.2 Card Design

Cards are used in View 2 (Question Deep-Dive):
- Hero card: large metric, sparkline, delta with significance
- Secondary cards: smaller, greyed-back, with sparklines
- All cards should have consistent padding, typography hierarchy, and subtle borders

### 5.3 Sparklines

- Appear in: heatmap row-ends, hero cards, secondary metric cards
- Should be simple, no axes, no labels — just the shape of the trend
- Consistent height and width across all instances
- Final point highlighted (dot or colour change)

### 5.4 Annotation Callouts

Already decided: the system supports callout annotations for special events. In the report:
- **Heatmap:** small flags or markers above relevant wave columns
- **Line charts:** vertical marker lines with labels
- **Distinct from structural break markers** (see §6.3)

### 5.5 What to Avoid

- Gauges or dials — waste space, a number + sparkline conveys more
- Radar/spider charts — hard to read over time
- 3D anything
- Stacked area charts — look dramatic but individual series are unreadable

### 5.6 Colour Accessibility

- Must work for colour-blind users (~8% of men)
- Do not rely on red/green alone
- Use a palette distinguishable under deuteranopia (blues-oranges-purples family)
- Consider offering a high-contrast mode
- Heatmap includes numbers in each cell — colour reinforces, it is not the only signal

---

## 6. Data Edge Cases

### 6.1 Missing Data

Trackers are messy — questions added in wave 3, dropped in wave 5, reworded in wave 7. Banners change when clients restructure segments.

**Rules:**
- Empty heatmap cell: subtle marker (e.g. dash or light hatching), not blank
- Sparklines: break the line at gaps, never interpolate
- Line charts: break the line, do not connect across missing waves
- Consistency: whatever the rule, apply it identically in all views

**Rationale:** Interpolation is dishonest — it implies data that doesn't exist.

### 6.2 Small Base Warnings

Some banner × wave combinations fall below reportable thresholds.

**Rules:**
- Flag clearly: greyed-out cells, hatched patterns, or warning icon
- The threshold must be configurable in the data layer (typical: n=30, some clients require n=50)
- This is separate from significance testing — it governs whether the number should be shown at all
- Flagged cells should still show the number but with clear visual dampening

### 6.3 Questionnaire Change Log

When wording changes or a question is added/removed, the discontinuity must be marked.

- **Event annotations** (§5.4) handle one-off events like "campaign launched"
- **Structural breaks** are different — they mean "do not compare across this line"
- Visual: a dashed vertical rule in the heatmap column, distinct from event annotation markers
- The break marker should appear in all views where the affected question is shown

### 6.4 Benchmark / Norm Lines

Clients often have category norms or targets (e.g. "NPS target = +40", "Category average satisfaction = 7.2").

- Line charts: optional horizontal reference line, labelled
- Heatmaps: optional reference colour band
- Data structure must accommodate benchmarks even if V1 doesn't render them — avoids painful retrofit

---

## 7. Interaction & Navigation

### 7.1 Cross-View Navigation

- Clicking a question in View 1 (Heatmap) → opens View 2 (Question Deep-Dive) for that question
- Clicking a banner in View 2 (Deep-Dive) → opens View 3 (Subgroup Comparison) for that question
- Breadcrumb or back navigation to return to previous view
- User should always know which view they are in

### 7.2 Controls / Selectors

- **Banner selector** (View 1, View 2)
- **Question selector** (View 2, View 3)
- **Metric mode selector** — available metrics determined by data type of selected question(s)
- **Value display mode** — Absolute / Change from previous / Change from baseline
- **Sort options** (View 1) — questionnaire order, current value, magnitude of change, significance
- **Chart type toggle** — heatmap vs. line chart (Views 1 and 3)
- **Question group filter** — filter to show only questions in a specific group

### 7.3 URL State Persistence

Encode current view configuration in the URL hash so that:
- A shared link opens the report in exactly the right view/configuration
- Browser back/forward navigates between view states
- This is much easier to build from the start than to retrofit

**State to encode:** active view, selected banner, selected question, metric mode, value display mode, sort order, chart type, group filter.

### 7.4 Export Per View

- "Copy to clipboard as image" or "Download PNG" button per chart panel
- Not required for V1, but the rendering approach (SVG vs Canvas) should be chosen with this in mind
- **Recommendation:** SVG for heatmaps and sparklines (crisp at any size, easy to export), Canvas only if performance demands it for large datasets

---

## 8. Performance Considerations

### 8.1 Scale Targets

The report must handle without sluggishness:
- **Upper bound:** 100 questions × 10 banners × 20 waves = 20,000 cells (before multiple metrics per question)
- **Typical:** 40-60 questions × 5-8 banners × 6-12 waves

### 8.2 Rendering Strategy

- Charts should render on demand (when the view is activated), not all on initial load
- Heatmap cells are lightweight (coloured divs with text) — these can render eagerly
- Line charts and sparklines should use a consistent library (likely the same one used elsewhere in Turas)
- Lazy-render views that aren't currently visible

---

## 9. Data Layer Requirements

### 9.1 Question Metadata

Each question needs:
- Unique ID
- Label / short name
- Data type (NPS / Rating / Likert / Mention)
- Group membership (e.g. "Brand Health", "Attitudes")
- Scale definition (for Ratings and Likert — what are the scale points)
- Available metrics (derived from data type — see §2.1)
- Wave availability (which waves include this question)
- Structural break markers (which waves have a discontinuity)

### 9.2 Wave Metadata

Each wave needs:
- Wave ID / label
- Fieldwork dates
- Sample sizes (total + per banner)
- Methodology notes
- Event annotations (text + type: event vs. structural break)

### 9.3 Banner Metadata

Each banner needs:
- Banner ID / label
- Sample sizes per wave
- Small base threshold (configurable, default n=30)

### 9.4 Data Values

Each data point (question × wave × banner × metric):
- Value
- Base size (n)
- Significance vs. previous wave (flag + direction)
- Significance vs. baseline (flag + direction)
- Small base flag (derived from base size vs. threshold)

### 9.5 Benchmarks (Future-Proof)

Optional per question:
- Benchmark value
- Benchmark label (e.g. "Category norm", "Target")

---

## 10. Analyst Commentary / Insights

The existing insights text editor supports annotation. For the tracker report, consider:
- Commentary may need to attach to a **question × wave** intersection (e.g. "NPS dropped here because of X")
- Or to a **view configuration** (e.g. analyst note on the 25-34 subgroup comparison)
- Or to a **wave as a whole** (likely handled by the summary page)
- Determine whether the insights editor needs a tracker-specific mode, or whether wave-level commentary on the summary page is sufficient

---

## 11. Open Questions for Implementation

1. What is the existing data structure for tracker data in Turas? This spec assumes certain fields — the implementation needs to map to or extend the actual structure.
2. Which charting library is currently used in Turas HTML reports? Consistency is preferable.
3. How does the summary page currently relate to the exploration views? Shared container or separate HTML files?
4. What is the current state of wave metadata handling? The spec in §9.2 may require extension.
5. Is there an existing pattern for cross-view navigation in Turas, or is this the first multi-view report?

---

## 12. Implementation Priority (Suggested)

**Phase 1 — Core:**
- Data type taxonomy and metric mode system
- View 1: Overview heatmap with sparklines and delta chips
- View 2: Question deep-dive with hero card and distribution strip
- Banner and metric selectors
- Value display mode toggle (absolute / change)
- Missing data handling
- Small base warnings

**Phase 2 — Extended:**
- View 3: Subgroup comparison (heatmap + line chart variants)
- Question grouping with section headers
- Sort options
- URL state persistence
- Cross-view navigation

**Phase 3 — Polish:**
- Slope charts
- Dot plots with confidence intervals
- Benchmark/norm lines
- Export per view (PNG/clipboard)
- High-contrast / accessibility mode
- Structural break markers
- Analyst commentary integration

---

*This spec is a planning document for Claude Code implementation. It consolidates architectural decisions from a design conversation on 15 March 2026. It should be read alongside existing Turas tracker module documentation and the CONFIDENCE_CALLOUT_SPEC.md.*
