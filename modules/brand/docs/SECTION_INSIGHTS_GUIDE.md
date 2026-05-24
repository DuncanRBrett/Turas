# Section_Insights — analyst-authored insights that survive re-runs

The brand HTML report has a "+ Add Insight" editor on every analytical
panel. Anything you type there lives only in that one rendered HTML file.
Re-run the report and it's gone.

The `Section_Insights` sheet in `Brand_Config.xlsx` fixes that. Type the
insight in the spreadsheet once, mark which section it belongs to, and the
text is pre-filled into the editor on every future re-run. Same pattern as
the tabs module's `Comments` sheet (`crosstabs_config.R::load_comments_sheet`).

This guide is the operator reference: sheet shape, anchor IDs, examples.
For the code, see `modules/brand/R/01b_section_insights.R`.

---

## Sheet shape

Add a sheet named **`Section_Insights`** to your brand config workbook.
Columns:

| Column   | Required | Description |
|----------|----------|-------------|
| Category | yes      | `CategoryCode` (e.g. `POS`, `DSS`, `BAK`, `PAS`), or the reserved code `_REPORT` for cross-cutting sections. |
| Section  | yes      | Friendly section label (e.g. `Brand Funnel`) **or** the raw HTML anchor ID (e.g. `funnel-pos`). Both work. |
| Insight  | yes      | The insight text. Supports markdown: `**bold**`, `*italic*`, `\`code\``, `- bullet`, blank lines. |
| Order    | no       | Integer; controls display order in any "all insights" tooling. Defaults to spreadsheet row order. |
| Author   | no       | Free text — currently not rendered, kept for traceability. |
| Date     | no       | YYYY-MM-DD — currently not rendered, kept for traceability. |

Rows where `Section` or `Insight` are blank are silently skipped. Rows where
`Section` starts with `[` (e.g. `[example anchor]`) are treated as template
help text and skipped. Duplicate anchors are tolerated; the last occurrence
wins, and the loader logs an `[INFO]` line listing the duplicated anchors.

---

## Anchor map — friendly Section labels

Use these in the `Section` column. Lookup is case-insensitive.

### Cross-cutting (Category = `_REPORT`)

| Section label                | Renders into anchor    | Where it appears |
|------------------------------|------------------------|------------------|
| `Executive Summary`          | `_EXECUTIVE_SUMMARY`   | Brand Summary panel, Analyst Commentary box |
| `Background`                 | `_BACKGROUND`          | About tab, "Project background" callout |
| `Portfolio Overview`         | `pf-overview`          | Portfolio tab → Overview sub-tab |
| `Portfolio Category Context` | `pf-clutter`           | Portfolio tab → Category Context sub-tab |
| `Portfolio Competitive Set`  | `pf-constellation`     | Portfolio tab → Competitive Set sub-tab |
| `Portfolio Footprint`        | `pf-footprint`         | Portfolio tab → Footprint sub-tab |

### Per-category (Category = `CategoryCode` from your Categories sheet)

| Section label      | Renders into anchor          | Where it appears |
|--------------------|------------------------------|------------------|
| `Brand Funnel`     | `funnel-{cat}`               | Category tab → Brand Funnel sub-tab |
| `Mental Advantage` | `ma-{cat}`                   | Category tab → Mental Advantage sub-tab |
| `Category Buying`  | `repertoire-{cat}`           | Category tab → Category Buying sub-tab, footer insight |
| `Word of Mouth`    | `wom-{cat}`                  | Category tab → Word of Mouth sub-tab |
| `Branded Reach`    | `branded_reach-{cat}`        | Category tab → Branded Reach sub-tab (when enabled) |
| `Demographics`     | `demographics-{cat}`         | Category tab → Demographics sub-tab |
| `Ad Hoc`           | `adhoc-{cat}`                | Category tab → Ad Hoc sub-tab |
| `Audience Lens`    | `audience_lens-{cat}`        | Category tab → Audience Lens sub-tab (when enabled) |

`{cat}` is the lower-cased `CategoryCode` with non-alphanumerics replaced by
hyphens — so `POS` → `pos`, `Baking Mixes` → `baking-mixes`,
`PASTA_SAUCES` → `pasta-sauces`. Match the rule in `build_br_category_panel()`.

### Pass-through (escape hatch)

Anything the resolver doesn't recognise as a friendly label is passed through
unchanged as the anchor ID. Useful when:

- You want to target an anchor that doesn't have a friendly label yet
- A new panel ships with a new anchor before this guide is updated
- You're debugging — type the raw anchor and the report shows you exactly
  what it found

To find the raw anchor for a section in a rendered report:

```bash
# Look at the source HTML — search for the section heading text, then look
# at the data-section attribute on the nearest element.
grep -oE 'data-section="[^"]+"' output/brand/{project}_Brand_Config_report.html | sort -u
```

---

## Example — IPK Wave 1 topline reel

| Category | Section                    | Insight | Order |
|----------|----------------------------|---------|------:|
| `_REPORT` | `Executive Summary`       | IPK reaches every category it plays in (38–49% awareness) but never leads. Mental neighbourhood is the value/private-label tier, not the megabrands. POS is the strongest position; BAK is the most exposed. | 0 |
| `_REPORT` | `Portfolio Overview`      | IPK plays across seven home categories at 38–49% awareness — credible mid-tier, well behind the 70%+ leaders. | 1 |
| `_REPORT` | `Portfolio Category Context` | **Dominant** in PES and ANT. **Crowded out** in DSS, PAS, COO. **Open space** in SLD, STO, BAK. | 2 |
| `_REPORT` | `Portfolio Competitive Set` | IPK's strongest mental neighbour is WWT (Jaccard 0.64). Lives in the private-label tier. | 3 |
| `_REPORT` | `Portfolio Footprint`     | Reference map for the four deep dives. Each category has its own 1–2 dominant brands; IPK is the consistent mid-tier player. | 4 |
| `POS`    | `Brand Funnel`             | Best funnel in the report: 50% aware → 25% primary. Every conversion ratio at or above category average. Once aware, IPK holds them. | 5 |
| `POS`    | `Mental Advantage`         | Closest gaps of any IPK category — leaders 10–18pp ahead, not 30pp. CEP06 contestable (gap to WWT only −10pp). | 6 |
| `PAS`    | `Brand Funnel`             | Aware-to-positive 86% (top-3 in cat); weak link is bought → primary (67%). Trial works; elevation doesn't. | 7 |
| `PAS`    | `Category Buying`          | IPK PAS buyers are heavier than category average (WBar 26.7 vs 15.6). Real engagement, not casual repertoire entry. | 8 |
| `DSS`    | `Brand Funnel`             | Most cluttered category — average aware set 7.1 brands. IPK rank 9 of 14 on mental penetration and volume share. | 9 |
| `DSS`    | `Mental Advantage`         | ROB owns every important CEP by 22–42pp. Narrowest gap is CEP12 (−22.6pp) — only candidate flag. | 10 |
| `BAK`    | `Brand Funnel`             | Lowest awareness (32%) of the four. Aware-to-positive only 65%. 17% of aware are price-driven + 17% no opinion. SNF shows 1%/0%. | 11 |
| `BAK`    | `Mental Advantage`         | Widest gaps in the report — SNF leads by 34–52pp on every CEP. Closest contestable CEP is 09 (gap −25pp). | 12 |

Drop these into a `Section_Insights` sheet in `8844718_Brand_Config.xlsx`,
re-run the brand module, and every insight is pre-filled into the matching
panel's editor.

---

## How it renders

When a section has a pre-filled insight:

- The insight container opens **by default** — analyst sees the text without
  needing to click anything.
- The rendered Markdown view is shown; the raw textarea is hidden.
- The toolbar button reads **"Edit Insight"** (instead of "+ Add Insight")
  and clicks straight into edit mode (toggles textarea ↔ rendered).
- The pinned-views workflow picks the insight up automatically — when
  exporting a pin, `brand_pins.js` reads `.br-insight-editor` value, which
  now contains the pre-filled text.

When a section has no insight:

- Container hidden as before.
- Button reads "+ Add Insight"; clicks open the empty editor.
- Existing UX exactly preserved.

If the analyst edits the box in the rendered HTML and saves the report
(Save Report button), those edits persist in the saved HTML but **do not**
automatically flow back into the spreadsheet. To make analyst HTML edits
permanent, copy the edited text from the rendered HTML into the
`Section_Insights` cell before the next re-run.

---

## What's not yet covered

- **No banner-equivalent.** The tabs Comments sheet supports per-banner
  insights via an optional `Banner` column. The brand module renders one
  focal brand at a time, so the equivalent (per-focal-brand or per-focal-
  category insights) hasn't been needed yet. If/when needed, follow the
  same pattern.
- **No automatic write-back.** Edits made in the rendered HTML do not flow
  back into the spreadsheet. The spreadsheet is the source of truth.
- **brsum-insight is per-category in JS.** The `_EXECUTIVE_SUMMARY` anchor
  pre-fills the Analyst Commentary box once on initial render. Switching
  focal category in the Brand Summary panel does **not** swap the text —
  this is a JS-side limitation that v1 keeps simple. If per-category
  executive insights become important, extend with anchors like
  `_EXECUTIVE_SUMMARY_POS`, `_EXECUTIVE_SUMMARY_DSS`, etc., and read them
  from the JSON payload on category switch.
