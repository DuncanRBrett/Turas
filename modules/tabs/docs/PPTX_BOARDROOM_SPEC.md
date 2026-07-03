# PPTX Boardroom Spec — tabs v2 Phase D (2026-07-03)

Rebuild of the native editable PPTX export (`29_export.js` + `14_pptx_parts.js`)
to Duncan's reporting bar: **every slide = insight title + chart + annotation +
metadata**, flat muted visuals, story flow, exec-summary cover, one consistent
template. Scope is the v2 in-report export only. The shared `turas_pins*`
system (modules/shared/js) is explicitly OUT of scope — reconciliation is its
own roadmap item (see project_next_pin_ppt_other_modules).

All geometry below is in inches (the exporter's `inch()` converts ×914400 to
EMU). Slide canvas: 13.333 × 7.5 (16:9, already `12192000×6858000`).

---

## 1. Gap analysis — current output vs the boardroom bar

| Area | Today (29_export.js) | Bar |
|---|---|---|
| Title | `Q003 — <question text>` 19pt **in brand colour**; pin insight title substitutes only when stored | Insight sentence in ink, question code demoted to metadata; brand colour reserved for rules/emphasis |
| Typography | Theme = Calibri Light/Calibri, but charts force Arial → mixed faces; sizes ad hoc (34/30/19/13/11.5/10.5/9/8.5) | One face, one 6-step scale, declared once |
| Layout | 0.55" margins, ad-hoc vertical stacking; no footer zone; content height juggled per slide | Fixed header/body/footer grid identical on every content slide |
| Metadata | One grey line: project · wave · published/computed · filter. **No question text, no n=, no weighted/effective base, no sig note, no source line** | Footer: question text · base (incl. weighted/effective) · sig note · wave · "Turas" |
| Chart colour | Every series full-saturation palette colour; data labels bold on ALL series | Muted greys + ONE emphasis series in brand; labels on emphasis only |
| Axes | Means/trends fixed (good); % bar charts auto-scale (`niceMax`) so small differences can inflate; `scale_min`/`scale_max` (now in source format) unused by `buildChart` | Honest fixed ranges from scale fields; min never truncated |
| Sig | Sig letters/flags computed in model, absent from every slide | Sig markers on emphasised deltas + plain-language footer note |
| Annotation | Gold "ANALYST INSIGHT" band (good bones), only when note exists | Keep band; add reference-line/callout support on charts |
| Cover | Brand-fill + "N exhibits · built natively…" (machine-y) | Exec summary: headline, client/wave, numbered leading findings (the HTML cover, `24a_reader.js coverHtml`, already has the spine) |
| Divider | Brand fill + gold tick — decent; no numbering | Numbered sections, consistent with cover |
| Verbatims | Qual pins (`pinSnapshot`) flatten to `lines[]` → **one-column table with a header row** — worst offender | Quote-first slide: large italic quotes, attribution chips, sentiment edge |
| Consistency | Editable deck, image deck and v1 turas_pins each look different | One template for the editable deck (image deck stays pixel-perfect fallback) |

## 2. Target design

### 2.1 Style constants — `TR.pptx.STYLE` (new block in 14_pptx_parts.js)

No new files: a new asset file would need loader-list changes; constants live
in 14 (parts/theme owner), consumed by 29.

```js
TR.pptx.STYLE = {
  FONT: "Arial",                       // one face everywhere (charts already Arial)
  INK: "1C2333", GREY: "6B7280", FAINT: "E7E9F2", PAPER: "FFFFFF",
  GOOD: "1B6E53", BAD: "B3372F", GOLD: "CC9900",
  CONTEXT: ["AEB4C2", "C6CBD6", "8F97A8", "D8DCE5"],  // muted series greys
  // brand/accent stay dynamic: TR.charts.brandOf()/accentOf() (project config)
  SIZE: { cover: 32, divider: 30, title: 20, subtitle: 11, body: 11,
          kicker: 10, footer: 8.5 },
  MARGIN: 0.6,
  HEADER: { rule: {x:0, y:0, w:13.333, h:0.06},          // brand rule
            kicker: {x:0.6, y:0.30, w:12.13, h:0.24},    // grey caps, e.g. "TRACKING · SERVICE"
            title:  {x:0.6, y:0.56, w:12.13, h:0.86},    // insight, ink, ≤2 lines
            subtitle:{x:0.6, y:1.44, w:12.13, h:0.28} }, // question code + text, grey
  BODY:   { x:0.6, y:1.86, w:12.13, h:4.62 },            // to y=6.48
  FOOTER: { rule: {x:0.6, y:6.72, w:12.13, h:0.012},     // FAINT hairline
            left:  {x:0.6,  y:6.80, w:6.4, h:0.44},      // question text (clipped 110)
            mid:   {x:7.1,  y:6.80, w:3.6, h:0.44},      // base + sig note
            right: {x:10.8, y:6.80, w:1.93, h:0.44} }    // "Turas · {wave}" + page no.
};
```

Footer content contract (every content slide, built by one `footer()` helper):
left = `Q003 · <question text>`; mid = `n=412 (weighted 398 · effective 371)`
when weighted else `n=412`, plus `▲▼ = 95% significance vs prior wave` when
sig marks are present; right = `Turas · {project.wave} · {slideNo}/{total}`.
Base figures come from the model's column base fields (unweighted / weighted /
Kish effective, per 22_model.js) for the charted column.

### 2.2 Slide archetypes (all share header/footer chrome above)

1. **Cover** — white background, brand rule full-height left edge (0.18" wide).
   Kicker "REPORT"; project name at 32; client · wave · date at 13 grey; then
   exec-summary paragraph (`TR.report.sectionText("exec")`, first ~2 paras) and
   **numbered leading findings**: `reader.coverFindings()` pin titles
   (`story2.pinTitle`) as an insight list, gold number chips. Mirrors the D1
   HTML cover exactly — same data sources, no re-derivation.
2. **Section divider** — keep brand fill; add big section ordinal ("02") at 60pt
   20%-alpha white top-right, title 30, subtitle 13, gold tick. Numbered from
   divider order in the story.
3. **Insight + chart** — chart fills BODY; when an analyst note exists it renders
   as the gold callout band pinned to the body's bottom (existing pattern,
   restyled to the grid). Kicker = question category; subtitle = `Q003 · <full
   question text>` (title no longer carries the code).
4. **Insight + matrix/table** — heatmaps, composites, crosstab-table pins.
   Same chrome; table styling unchanged in structure (brand header, zebra, gold
   stat edge, `fitMatrix` truncation note) but resized to BODY and STYLE fonts.
5. **Verbatim/quote slide** — NEW `exporter.quoteSlide(spec)`. Up to 4 quotes:
   36pt gold `“` glyph, quote at 14 italic ink on a 9.5" measure, attribution
   chip line at 9.5 grey (`Female · 25–34 · Detractor`), 0.05" sentiment edge
   rect (GOOD/BAD/GREY) left of each quote — never colour-only (chip names the
   sentiment). Overflow: "+N more in the report" footer-left suffix. Requires
   snapshot pins to carry structured `quotes:[{text, tags, sentiment}]`
   alongside today's `lines[]` (additive; old pins keep the table fallback).
6. **Tracking trend slide** — `buildTrendChart` output on the grid; wave-delta
   chip (`▲ +4pp •`) as a text box top-right of BODY; CI note in footer-mid
   when `item.ci`. Data-point annotations from pinned Visualise views render as
   small gold callout boxes at their wave position.
7. **Appendix data slide** — archetype 4 with kicker "APPENDIX", table font
   9–9.5, up to 18 rows. `slidesFor` emits an "Appendix" divider then appendix
   slides for pins flagged `appendix:true` (new optional pin flag; default
   deck order unchanged when unused).

## 3. Chart XML styling (buildChart / buildTrendChart / dotPlotShapes)

- **Emphasis model.** Multi-series: series 0 (the first charted column, i.e.
  Total or the analyst's chosen cut) = brand colour; remaining series =
  `STYLE.CONTEXT` greys in order. `dataLabels()` emitted **only on the emphasis
  series** (per-`c:ser` `<c:dLbls>`; others get none). Single-series bars: all
  bars `CONTEXT[0]` grey with the headline row (top NET / mean / max value) in
  brand — semantic red/green category colouring kept ONLY for sentiment/NPS
  row kinds where colour is meaning, and then flagged in the footer.
- **Gridlines.** None (already none — keep); category axis line 0.75pt FAINT
  via `<c:spPr>` on `c:catAx`; value axis deleted where labels carry values
  (stacked) as today.
- **Honest axes.** `chartAxes` gains min/max from the question's
  `scale_min`/`scale_max` when present (means: already fixed 0–max; now
  sourced from the fields, not inference). Percentages: min always 0; max =
  100 for shares/stacked, else `niceMax` **capped at 100** and floored at 25 so
  auto-scale can't inflate small differences. Trend axes keep the existing
  fixed-scale logic.
- **Sig markers.** Where the model marks the emphasis cell significant vs
  Total/prior wave, append `▲`/`▼` to that data label (numCache text is not
  touchable — use a small positioned text box beside the bar end, same
  technique as `dotPlotShapes` value labels); footer-mid carries the
  plain-language note (B2 wording).
- **Fonts.** Chart default text stays Arial 10 `3B4252`; slide `para()` gains
  `<a:latin typeface="Arial"/>` so text and charts finally match; theme
  major/minor fonts in 14 switch to Arial.

## 4. Implementation plan — ordered work packages

Each WP is single-agent sized, independently shippable, suites green per WP.
Test harness: `node modules/tabs/lib/html_report_v2/tests/exports_tests.mjs`
(vm-sandbox loads the js files and string-asserts slide/chart XML — extend it);
visual QA via `soffice --headless --convert-to pdf` (on PATH) rendering a
generated deck to images for eyeball checks.

- **WP0 — Style foundation.** `TR.pptx.STYLE` + Arial theme fonts + shared
  `header()/footer()/callout()` chrome helpers; `para()` typeface. Files:
  `14_pptx_parts.js`, `29_export.js`. Tests: XML asserts for STYLE colours,
  Arial latin runs, footer boxes present on `slideForModel`. **Safe now.**
- **WP1 — Metadata everywhere.** Wire footer content (question text, n=/
  weighted/effective from model bases, sig note, wave, Turas, page numbers)
  into `slideForModel`, `exhibitSlide`, `matrixSlide`; move question code out
  of titles into subtitle/footer. Files: `29_export.js` (+ `30_story.js`
  passing the model/base through for matrix-kind items). Tests: footer text
  asserts incl. weighted fixture. **Safe now.**
- **WP2 — Chart restyle.** Emphasis/context series, labels-on-emphasis-only,
  honest axes from `scale_min/scale_max`, capped % max, sig marker boxes.
  Files: `29_export.js` only. Tests: assert grey fills on series ≥1, exactly
  one `<c:dLbls>`, `<c:max val="100"/>` cases, marker text boxes. **Safe now.**
- **WP3 — Cover, dividers, deck order.** `exporter.coverSlide()` from
  `reader.coverFindings()`/`report.sectionText`; numbered dividers;
  `slidesFor` prepends cover (replaces `titleSlide` in the editable deck).
  Files: `29_export.js`, `30_story.js`. Tests: cover XML contains pin titles
  and exec text; divider numbering. **Safe now.**
- **WP4 — Quote slide.** `exporter.quoteSlide()`; structured `quotes` payload
  on qual snapshot pins (hub/collection add-to-story call sites in
  `27q_qualitative.js` / hubExhibit path), table fallback for old pins;
  disclosure k-gate respected (only already-gated rendered quotes are pinned).
  Files: `29_export.js`, `30_story.js`, `27q_qualitative.js`. Tests: quote XML
  asserts + qual_tests green. **Safe now** (v2-local; not turas_pins).
- **WP5 — Trend polish + appendix.** Delta chip, annotation callouts, CI note
  (`30x_exhibit.js` slide path + `29_export.js`); `appendix` pin flag +
  appendix section in `slidesFor`. Tests: exports + tracking fixtures.
  **Safe now.**
- **WP6 — Visual QA gate.** Node script builds a fixture deck (all archetypes)
  → `soffice` render → PNGs for eyeball; optional size/part-count goldens.
  New test file only. **Safe now.**
- **(Parked) WP-P — shared turas_pins reconciliation.** Restyling the OTHER
  pin/PPTX system (modules/shared/js/turas_pins_pptx.js et al., used by brand/
  hub/other modules) to this template. **Duncan's decision — separate roadmap
  item, not Phase D.**

## 5. Open decisions for Duncan (each with a recommendation)

1. **16:9 only?** Yes — keep the single 12192000×6858000 size; no 4:3 path.
2. **Slide titles in brand colour or ink?** Recommend **ink** (INK 1C2333);
   brand lives in the top rule, cover edge, emphasis series and table headers.
3. **Logo?** No logo asset exists in the payload. Recommend text wordmark
   ("Turas · The Research LampPost" footer-right on the cover only) now; add an
   optional config logo PNG later (the packager already handles media parts).
4. **One theme or per-client theming?** One template; colour already themes
   per client via `brand_colour`/`accent_colour` in project config. Recommend
   no further theming knobs in Phase D.
5. **Cover always?** Recommend always in the editable deck (analyst decks get
   project name + exec text; leading-findings block appears only when story
   pins exist — same rule as the HTML `coverAvailable`).
6. **Font.** Recommend Arial throughout (matches chart XML and the IPK topline
   deck precedent) over Calibri; avoids the current mixed-face look.
7. **Image deck.** Recommend leave as-is (pixel-perfect fallback); restyle or
   retire only after the editable deck proves itself on a real study.
8. **Sig markers on charts.** Recommend ▲▼ beside emphasised values + footer
   note, not per-bar letters (letters stay in tables) — boardroom, not analyst.
