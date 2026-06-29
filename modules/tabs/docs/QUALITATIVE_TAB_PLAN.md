# Qualitative Tab — Implementation Spec (tabs v2 report)

**Status:** Planned (ready to build) · **Date:** 2026-06-29 · **Owner:** Duncan Brett
**Module:** `tabs` (v2 HTML report) · **Type:** New report tab + new data island
**Companion:** `OPEN_END_CODING_PLAN.md` (the in-Turas AI coding engine) — **decoupled**;
this tab consumes a file contract, the coder later becomes one upstream producer of it.

> Output of a five-concept design fan-out + three-judge panel (taste / engineer /
> methodologist), synthesised and verified against the live v2 codebase. Coding
> happens **outside** Turas; this spec covers only how pre-coded comments are
> presented. Duncan's four steering decisions are locked in §12.

---

## 1. Summary

A new **Qualitative** tab that treats a coded theme as ordinary quant — a theme is
just a multi-mention variable where every mention also carries a 1/2/3 valence
(1=positive, 2=neutral, 3=negative). That one reframing lets theme-by-demographic
crosstabs, significance, dual-sig, custom banners, FPC and filters all come from the
engine the report already has, with **zero new statistics code**. On top of that
quant spine sits the one genuinely new thing: a gated `DATA_QUAL` island carrying the
**exact stored verbatims**, keyed to the same anonymous respondent index the microdata
already uses — so every number is **click-to-evidence**: tap a theme bar, a sentiment
band or a significant banner cell and the exact comments behind it slide in, rendered
by ID, never authored by a model.

The reader's path is **triage → question → verbatim**. A study-level grid ranks every
open-end question by volume / net sentiment / divisiveness (the answer to a 38-sheet
study); opening one shows an optional base-gated tension-led story header (the Patterns
idiom), a diverging prevalence-and-sentiment theme board, the theme×banner crosstab one
expand away, and a quote drawer underneath as the universal proof layer. Raw
(un-themed) questions are first-class: they collapse to a noteworthy spotlight plus a
searchable, faceted browser.

This wins because it is **the only open-end view native to a cross-tab report** — an
analyst trusts a theme finding for the same reasons they trust a closed-question
finding, a client reads it with the same mental model, and confidentiality is a
deliberate, configurable build dimension, not an afterthought.

---

## 2. Scope & relationship to the AI coder

- **In scope:** ingesting pre-coded comment workbooks; the Qualitative tab; the
  `DATA_QUAL` island; serialising theme rows into the existing aggregate/microdata
  layers; a report-level tab-visibility config; the verbatim confidentiality gate.
- **Out of scope (this spec):** AI theme generation/classification, frame
  harmonisation, the exception queue — all owned by `OPEN_END_CODING_PLAN.md`.
- **Contract, not coupling:** both meet at the `DATA_QUAL` schema (§9). Build this tab
  against the file contract now (coding external); the AI engine later emits the same
  island. *(Decision §12.4.)*

---

## 3. Input contract (the coded workbook)

Distilled from three real Duncan workbooks — SACS staff engagement, SACAP student,
CCPB trade. Universal model:

- **Unit = a QUESTION = one worksheet.** A question may be split across sheets by a
  closed cut (CCPB "NPS Promoter / Passive / Detractor").
- **Each respondent row:** respondent ID; 0..n demographic/banner columns (CCPB:
  Centre, Channel, Size, Sales method, Language, Distributor; Student: Campus, Course,
  Year, Intensity, NPS; SACS staff: none/anonymous); the **exact verbatim**; a
  **Noteworthy** flag (any non-blank = noteworthy; marker varies "Yes" / "x"); optional
  **Overall Sentiment** column (1/2/3); optional **Rating** (e.g. 1–5).
- **Theme columns:** each named theme is a column; cell value ∈ {1,2,3} or blank
  (blank = theme not mentioned). **A theme is therefore a multi-mention variable that
  also carries per-mention sentiment.**
- **Two question types, both first-class:** (1) **THEMED** (full theme matrix);
  (2) **RAW** quote list (demographics + verbatim + noteworthy, no theme matrix).
- The top-rows **summary block is derivable** — recompute from raw, ignore it.

**Real-world quirks the adapter must absorb (so the runtime sees a clean frame):**

| Quirk | Handling |
|---|---|
| Sentiment label drift ("Positive skew/Mixed/Negative skew" vs "Positive/Neutral/Negative") | Normalise to {1,2,3}; keep original label as tooltip |
| Noteworthy marker drift ("Yes" / "x") | Any non-blank = noteworthy |
| Header whitespace / theme-name drift | Trim + canonicalise; optional `theme_aliases` override (mirrors `BrandCodeAlias`) |
| Stray miscodes (a rogue "11") | Quarantine to a logged "uncoded" bucket; never coerce, never silently drop; count in rigor footer |
| Split-by-cut sheets (CCPB NPS bands) | Reassemble at build into ONE question; the split-cut becomes a banner dimension; config override for irregular splits |
| Contents index sheet (Student) | Drives rail grouping + triage order |
| Many questions (CCPB = 38) | Triage grid + searchable rail; only the open question renders heavy content |
| Base swings 48 → 1155 | Small-base honesty everywhere (§5) |

---

## 4. The reader's journey

**Level 0 — Study triage (the front door).** Opens on a **Triage Grid**: one row per
qual question — label, comment base *n*, a diverging net-sentiment bar (green right /
red left from a fixed centre), a divisiveness bar (share of mixed-valence mentions),
the top theme. RAW questions show a `RAW · browser-only` chip + base *n* + noteworthy
count (never a dead row). Sortable by **volume / net-sentiment / divisiveness**. A
1-question study auto-collapses straight to that question.

**Level 1 — One question.** Clicking a row drills in; the grid collapses to a thin
context strip (jump sibling-to-sibling) and a collapsible left **question rail**
(Crosstabs-sidebar idiom, searchable, grouped by Contents order, sentiment spark per
entry). Main column, top to bottom:

1. **Question header strip** — title, comment base ("*n* answered of *n* asked"),
   `THEMED`/`VERBATIM-ONLY` badge, net-sentiment chip, confidentiality shield icon.
2. **Story header (themed only, optional, base-gated)** — 1–3 auto-written tension-led
   claim lines (dominant theme / friction / divergence-vs-Total / surprising-absence),
   each with a "survives 95%/80%" chip and one ID-rendered pull-quote. Below ~n=80 it
   degrades to a "directional, low base" note and suppresses the dominant-theme and
   absence claims.
3. **Noteworthy spotlight reel** — compact horizontal band of analyst-flagged comments,
   sentiment-edged, pinnable to Story.
4. **Theme prevalence board** — ranked horizontal bars, %-of-commenters, each diverging
   pos/neutral/neg around a centre line with a per-row net figure and a small valence
   stack so a flat net never hides polarisation. Sig letters on rows under the active
   banner. Sortable by prevalence | net | base.
5. **Theme × banner crosstab (expand)** — the literal Crosstabs table renderer, theme
   rows × banner columns, dual-sig; honours active/custom/composite banner + filters.
6. **Differences-style standout strip** — "which groups over-mention which themes,"
   reusing the Differences finder on theme rows.

**Level 2 — Verbatims.** Underneath sits the **Quote Drawer**, the universal proof
layer: opens filtered to whatever was clicked (theme / sentiment band / sig cell),
showing the exact stored comments for that slice — banner tag chips, a sentiment spine,
a noteworthy star, a saturation indicator ("speaks for *N* comments"), a provenance ID.
For RAW questions this drawer **is** the main surface: a full quote browser with search,
demographic facets, sentiment chips, noteworthy pinned on top.

**Footer — rigor strip** on every panel: comment base, % noteworthy, themes-not-shown
count, coding mode, label-normalisation and stray-code notes, the no-fabrication +
confidentiality statement.

---

## 5. Components

| Component | What it shows | Rendered with | Reuses | New |
|---|---|---|---|---|
| Triage grid | Per-question: label, base, net-sentiment bar, divisiveness bar, top theme; sort | Sortable table + inline SVG bars | `23_render.js` bar/heat helpers; `27d_diffs.js` sort-control; net sentiment from engine mention counts | Grid layout + divisiveness metric |
| Question rail | Searchable grouped question list, sentiment spark + THEMED/RAW glyph + base | Crosstabs sidebar markup | `26_filter.js` picker+search; `d2.categories()` grouping; `d2.state` deep-link | Type chips/sparks |
| Story header | 1–3 auto claim lines + 95/80 chip + one pull-quote | Patterns claim/strain grammar | `27e_takeout_engine.js` storyScore; `27g_takeout_components.js`; sig via `model.forQuestion` | Theme-scoped templates + base-gating |
| Noteworthy reel | Flagged comments band, sentiment-edged, pinnable | Card band | Story pin path (`30_story.js`); `fmt.escapeHtml` | Reel layout |
| Theme prevalence board | Ranked diverging pos/neu/neg bars + net + divisiveness | SVG bars | `03_svg.js` primitives; `23z_charts.js` diverging geometry; `--green/--red/--muted` | Diverging-with-net row composite |
| Theme × banner crosstab | Theme rows × banner cols, pct/n/dual-sig | The Crosstabs table renderer | `cards2.renderTab`/`23_render.js`; `22_model.js forQuestion`; `21_stats.js tabulate+sigLetters` — **zero new stats** | Model adapter feeding theme rows |
| Standout strip | "Which groups over-mention which themes" | Differences card | `27d_diffs.js` finder + classification-exclusion guard, on theme rows | none |
| Quote drawer / browser | Exact verbatims by ID, tag chips, sentiment spine, noteworthy star, saturation, ID | Right drawer / virtualised list | `stats.mask` for the clicked cell's IDs; `MICRO.banner_vars` for tags; `d2.state.filters`; `fmt.escapeHtml` | `DATA_QUAL` reader + saturation |
| Confidentiality shield + rigor footer | Build mode badge, methodology note | Header icon + footer | island inlining in `build_report_v2.R`; `d2.storeKey`; Tracking null-island degradation | 3-mode gate |
| `DATA_QUAL` island + qual adapter | Per-question scrubbed verbatims + valences + noteworthy, keyed by anon index | Inlined JSON island | `parseIsland` in `shell.boot`; MICRO multi-mention shape; `DATA_VERIFY`-style ID check | The island + R writer + normalisation |

---

## 6. Themed vs raw questions

**Auto-detection at ingest, never at runtime.** A worksheet with one or more theme
columns (named columns whose cells ∈ {1,2,3} or blank) is `THEMED`; a worksheet with
only demographics + verbatim + noteworthy (± Overall Sentiment / Rating) is
`VERBATIM-ONLY`. The R writer stamps `type` on each question; the runtime never
re-infers.

**Themed** → ingested as an ordinary multi-mention question. Each named theme becomes a
category row (member = theme cell non-blank); the per-mention valence (1/2/3) is stored
as a parallel sentiment array on those member indices. Renders the full stack (story →
board → crosstab → standout → drawer). Banner / custom / composite banner / dual-sig /
filters all apply unchanged via `model.forQuestion`.

**Raw** → identical shell with the theme machinery off. Sections 2, 4, 5, 6 do **not**
render (the tab never invents codes). Badge reads `VERBATIM-ONLY`; the layout reclaims
the space and leads with the noteworthy spotlight then the full filterable browser
(search + demographic facets + sentiment chips if an Overall Sentiment column exists). A
raw question with a sentiment column still shows one honest net-sentiment figure in the
header. This is a deliberate first-class mode, not a degraded one.

---

## 7. Sentiment model

**Spine = per-mention valence 1=positive / 2=neutral / 3=negative**, normalised at
ingest (label drift → canonical {1,2,3}, original kept as tooltip; stray codes
quarantined, never coerced).

**Net sentiment** for a theme (or theme×cut) = (positive − negative) ÷ total mentions.
Surfaced four ways: story claims read it in words; every prevalence bar is a diverging
split; rail/triage sparks are mini versions of the same stack; a header net chip per
question.

**Honesty devices (non-negotiable).** A single net figure can mask polarisation, and
1/2/3 valence is coarse. Two guards ride everywhere: a **divisiveness bar** (share of
mixed-valence mentions) on the triage grid and theme rows; an **always-on valence
stack** showing the full pos/neu/neg composition with counts under any net figure. **Do
not render net as a clean −100..+100 precision score.** Where a question has no
sentiment column, the spine renders neutral and the facet hides.

**Small-base honesty.** Bases swing 48 → 1155. Thin theme×cut cells are greyed /
suppressed with a directional-read fallback, never asserted as precise. The story
header hard-gates below ~n=80.

---

## 8. Theme × banner + significance

Because themes serialise as ordinary multi-mention category rows in `DATA_AGG` (with
per-respondent theme-index arrays in `DATA_MICRO`), **theme×demographic cuts ARE the
existing crosstab.** `model.forQuestion(code, bannerId, filters, opts)` returns the
published AGG or live-recomputes from MICRO under a filter (`stats.mask → tabulate →
sigLetters`). Columns are the active banner (Total first, then cuts, plus
custom/composite). `stats.sigLetters` writes `row.sig[colIdx]` with full dual-sig
(95 UPPER / 80 lowercase), honouring `d2.state.sigMode`. FPC and weighting flow through
because they already live in the stats layer the themes ride on.

So "Detractors disproportionately mention Price" is both **felt** (red Price chips
cluster in the drawer) and **proven** (a sig letter on the Price cell) — one engine.
The Differences finder is reused verbatim on theme rows, including its
classification-exclusion guard (consistent with commit `0093d7b0`).

**Multiple-comparison caution (non-negotiable).** Many themes × many cuts is
comparison-heavy and qual bases swing wildly. Thin cells are suppressed/greyed; the
directional-read fallback replaces letters on low-base themes; the rigor footer states
the comparison count. Readers must not over-read a letter on a 48-comment theme.

---

## 9. The quote browser & no-fabrication

**No-fabrication is structural, not promised.** `DATA_QUAL` stores exact verbatim
strings keyed by the anonymous respondent index MICRO already uses; the renderer only
ever prints the stored string for an ID — the quote slot physically never carries
computed or paraphrased text. A deterministic **build-time ID-existence check**
(DATA_VERIFY-style) confirms every surfaceable ID resolves to a stored string before
the island inlines; a missing ID → the claim renders **without** its quote rather than
inventing one (TRS refusal echoed to console for Shiny).

**Drill-down, not a second selection.** The drawer reuses the **same `stats.mask` the
engine already computed** for the clicked cell — no separate quote-selection logic.
Click a prevalence bar → members of that theme; a sentiment band → intersect with
valence; a sig cell → intersect with that banner cut.

**Quote card** = sentiment-tinted left spine (`--green/--muted/--red`), the exact text
in reading type, a tag row beneath (demographic tags muted; theme chips tinted by **that
mention's own** valence — a card can carry a green "Service" chip and a red "Price" chip
at once), a saturation indicator ("speaks for *N* comments" — the antidote to
cherry-picking), the noteworthy star, the ID bottom-right, a pin-to-Story button.

**Search / filter / facets** — full-text search with match highlighting; facet chips
from `MICRO.banner_vars`; noteworthy-only toggle (marker-agnostic); sentiment chips. All
state persists in `d2.state` and serialises to the URL hash, so a "Detractor × negative
Price" view deep-links like everything else. The **noteworthy spotlight** pins flagged
comments atop both themed drawers and raw browsers — Duncan's "noteworthy comments
loaded with appropriate tags."

---

## 10. Confidentiality — two independent controls

There are two separate switches. Keep them separate.

### 10a. Tab visibility (coarse, report-composition) — *Duncan's config idea*

The report builds its tab row from a fixed list (`tabList()` in `24_shell.js`), and
Tracking already appears conditionally. Generalise this into a **config-driven
tab-visibility control** in the crosstab Settings sheet — a small set of include
switches: `show_patterns`, `show_differences`, `show_tracking`, `show_qualitative`,
`show_dashboard`, etc. (Crosstabs always on). The flags ride the data layer into
`TR.AGG.project`; `tabList()` filters against them. **Qualitative is one more switch**
in that list — whole-tab on/off: "does the Qualitative tab appear in this report at
all." (It also self-hides when `DATA_QUAL` is null, exactly like Tracking.)

> This is a small, generic enhancement worth doing alongside the tab — it gives Duncan
> per-report control over every tab, not just this one.

### 10b. Verbatim text level (fine, Qual-tab only)

Only matters once the Qual tab is in. The report is one forwardable HTML file, and the
comment text is its only re-identifiable content (theme numbers are anonymous). A
per-report **three-mode export gate**, persisted via `d2.storeKey` and honoured by
`build_report_v2.R` island inlining (the Tracking null-island pattern makes a no-text
build byte-graceful):

- **HIDDEN (numbers-only)** — the tab ships in full (prevalence, crosstab, sig, net
  sentiment, triage) but `DATA_QUAL` text is nulled; quote slots lock with "[quote
  hidden in this copy]". The aggregate analysis is non-identifying and always ships.
  **Default** — safe to forward by accident.
- **REDACTED** — rule-based PII-scrubbed verbatims (names → `[name]`), scrub logged with
  a reviewable diff. **Built from the start** (Duncan: "redacted sounds fine"); the mode
  analysts actually use for a client copy. Honest limit: rules catch *direct*
  identifiers, not *contextual* ones ("the only male diploma lecturer in Cape Town").
- **FULL** — exact verbatims, for internal / fully-consented studies.

**PII scrub runs at ingest, before any string enters the island** (the inlined HTML is
the deliverable, so scrubbing must precede the build). A header **shield icon** + the
rigor footer state which mode this build used. The save-copy path respects the current
mode, so an analyst hands a client a HIDDEN/REDACTED copy and keeps FULL internal.

**Recommended default: HIDDEN**, opt up deliberately to REDACTED/FULL.

---

## 11. Data & ingestion contract

**Read Duncan's Excel directly** (Decision §12.3): Turas opens the comment workbooks he
already produces (the three examples are the template), auto-detects columns, and
absorbs the §3 quirks. No change to how he/a coder works. The only cost is that a wildly
different future layout may need a small override. **Also document a simple normalised
template** as a fallback contract for any outside coding house — direct-read is the
primary path, the template is the safety net.

**Output: a new `DATA_QUAL` island**, inlined like the existing four (or `null` when no
open-ends, so the tab self-hides). Per qual question:

```
{
  code, title, type: "themed" | "raw",
  base: { answered, asked },
  themes: [ { id, label } ],                 // themed only
  records: [ {
    idx,                    // anonymous respondent index (== MICRO index)
    text,                   // exact verbatim, scrubbed (or null in HIDDEN build)
    noteworthy: bool,       // any non-blank source flag, marker-agnostic
    sentiment: 1|2|3|null,  // Overall Sentiment column, normalised (raw qs)
    themeVals: { themeId: 1|2|3 },           // themed only; absent = not mentioned
    rating: number|null
  } ],
  meta: { dropped_codes: n, label_variants: [...], pii_scrubbed: bool }
}
```

The theme matrix is **also** serialised into `DATA_AGG` (theme rows with pct/n/sig per
banner column) and `DATA_MICRO` (`answers[qcode]` = array of mentioned theme indices +
a parallel valence array), so the quant engine tabulates with zero new code.

**ID → microdata mapping.** The workbook respondent ID is the join key, resolved **at
build time** to the same anonymous index MICRO uses. The island carries **only the index
+ scrubbed text** — never a respondent ID or name — so banner cuts work while the file
stays anonymous.

---

## 12. Decisions (locked) & remaining open items

**Locked (Duncan, 2026-06-29):**

1. **Tab visibility** → build the generic config-driven tab-visibility control (§10a);
   Qualitative is one switch alongside Patterns / Differences / Tracking.
2. **Verbatim confidentiality** → all three modes built; **default HIDDEN**; **REDACTED
   available from the start** (not deferred); FULL for internal.
3. **Ingestion** → **read Duncan's Excel directly**, plus a documented fallback template
   for outside coders.
4. **AI coder sequencing** → **decoupled, tab first**; the engine later produces the
   same island.

**Still open (minor, can be settled in build):**

- **Net-sentiment presentation** → recommend never a single precise score; always the
  diverging stack + divisiveness bar. *(Confirm at build.)*
- **Split-by-cut reassembly** → recommend automatic-with-override; flag if a study's
  splits are irregular.

---

## 13. Integration into v2 (verified against the live codebase)

1. **`tabList()`** (`24_shell.js:13`) — push `["qualitative","Qualitative"]`, guarded on
   `DATA_QUAL` non-null **and** the `show_qualitative` config flag (mirrors the
   `tracking().enabled` guard).
2. **`shell.route()`** (`24_shell.js:~118`) — add
   `else if (d2.state.tab === "qualitative") TR.qual.render(host);`.
3. **New JS module** `27q_qualitative.js` defining `TR.qual.render(host)`. **No
   bundle-list edit** — `bundle_report_v2_js` does `sort(basename(list.files(...)))` at
   `build_report_v2.R:48`, so the file is auto-discovered by filename.
4. **New island** in `build_report_v2.R` — emit `DATA_QUAL` alongside the existing four,
   inlined as `<script type="application/json" id="data-qual">` (with `</` escaping per
   the existing guard), `null` when no open-ends or HIDDEN mode strips text. Parsed in
   `shell.boot` via the existing `parseIsland("data-qual")` path.
5. **R writer** (`tabs` `lib/` convention) — qual-workbook reader/normaliser producing
   §11's schema, plus serialisation of theme rows into `DATA_AGG`/`DATA_MICRO`.
6. **Config** — `show_*` tab-visibility flags + `qual_confidentiality_mode` ∈
   {hidden, redacted, full} (default `hidden`), read by the R inliner; runtime state in
   `d2.storeKey(base)`.

**Reused wholesale, no new copies:** banner (`columns[]`), `model.forQuestion`,
`stats.mask/tabulate/sigLetters` + dual-sig, `26_filter.js` value-picker, `27d_diffs.js`
finder + sort, `27e/27g` Patterns engine, `30_story.js` pin path, `d2.state` + URL hash,
the `--brand/--accent/--green/--red/--muted/--card/--line/--shadow` tokens.

---

## 14. Build order (risk-descending)

> Validate on the smaller-base SACS or Student workbook before CCPB's 38 sheets — the
> single biggest cross-concept risk is over-claiming on thin bases.

**Phase 1 — MVP (prove the brief on a real workbook):**
- R: qual-workbook adapter → `DATA_QUAL` island + theme rows into `DATA_AGG`/`DATA_MICRO`;
  label/marker normalisation, stray-code quarantine, ingest PII scrub.
- JS: register the tab; question rail; theme prevalence board (diverging + net + valence
  stack); theme×banner crosstab via `model.forQuestion` (banner + dual-sig + filters);
  quote drawer with the deterministic ID-existence check.
- Raw questions: noteworthy spotlight + filterable browser.
- Confidentiality: **HIDDEN + REDACTED + FULL** all in MVP (Duncan's call); default
  HIDDEN.
- Tab-visibility config switches (§10a).
- Rigor footer; hard base-gating.

This is the themes-as-quant spine with quotes as drill-down — the literal execution of
the brief.

**Phase 2 (straight after):**
- Triage grid front door (volume / net / divisiveness sort).
- Story header (Patterns-native auto-claims, base-gated below ~n=80, "surprising
  absence" lowest-priority confidence-gated).
- Differences standout strip on theme rows.
- Split-by-cut reassembly polish + Contents-driven grouping.

**Phase 3+ (defer):** saturation indicator everywhere; cross-question theme rollups;
wave-over-wave theme trends (rides the Tracking island once the frame is locked);
pin-to-Story + PPTX export; near-duplicate clustering (embeddings — approval-gated per
the OPEN_END plan); per-question lazy text / size budget for high-base studies.

---

## 15. Quality standards (project checklist)

- [ ] No `stop()`; failures are TRS refusals echoed to console for Shiny.
- [ ] Config-driven; no study-specific code paths.
- [ ] Every displayed quote is an exact stored verbatim; no model-authored quote text
      can ship; deterministic ID-existence check before render.
- [ ] Net sentiment never shown without its valence stack; low bases flagged, not
      asserted.
- [ ] Tests + synthetic fixtures: workbook ingest (themed + raw + split-by-cut), label/
      marker normalisation, stray-code quarantine, theme-row serialisation into
      AGG/MICRO, quote-ID verification, confidentiality-mode stripping, tab-visibility
      config.
- [ ] HIDDEN mode ships zero raw text; REDACTED scrub logged with reviewable diff.
- [ ] Verify via `launch_turas` regen + browser inspection (Duncan's job), not headless.

---

## 16. Build-effort note (model / level)

This is a multi-file, cross-language build (R adapter + island serialisation + a new JS
tab module) integrating with a sophisticated existing data layer, under Duncan's
quality mandate. Recommendation: **Opus.** Effort by phase:

- **Architecture-sensitive parts — high effort.** The R adapter and especially the
  serialisation of theme rows into `DATA_AGG`/`DATA_MICRO` (so `model.forQuestion`/
  significance "just work"), the island wiring, the ID→index join, and the
  confidentiality stripping. Subtle correctness; get it wrong and the sig is silently
  off. Plan/spec-driven.
- **JS rendering — medium effort** once the first component sets the pattern; most of it
  is reuse of documented helpers.
- **Verification/tests — high effort.** No-fabrication ID check and sentiment honesty
  are correctness-critical.

Net: Opus, high for Phase-1 R + tests, medium for the repetitive JS once a pattern is
established.
