# Brand Module — Report Upgrade Review

**Question asked:** *"To what extent can we upgrade the brand module to the same standard as the recently-upgraded tabs/tracker v2 report?"*
**Reference deliverable reviewed:** `IPK_Brand_report_Provisional.html` (6.9 MB, generated 25 May 2026).
**Stated problem:** *"The report is good, but there is so much detail — the feedback is that it is quite confusing to the user."* PPTX export *"will be highly valued."*
**Branch:** `review/brand-report-v2-upgrade-2026-06`
**Date:** 2026-06-17 · Author: Claude (review only — no production code changed)

---

## 1. Bottom line up front

The "tabs v2 standard" is not one thing. It is **three separable upgrades**, and they are not equally worth doing for brand:

| Strand | What it is | Worth it for brand? | Why |
|---|---|---|---|
| **A. Clarity / information design** | Dashboard-first landing, progressive disclosure, search, a stable IA, less on-screen chrome | **YES — this is the actual problem** | The IPK feedback ("too much detail, confusing") is an information-design problem, not an engineering one. High value, medium effort, low risk. |
| **B. Native branded PPTX export** | Editable text + tables on a brand-themed master, not screenshots | **YES — Duncan flagged it as high value** | The engine already exists (tabs v2). Brand is on the *weakest* of three export paths today. Medium effort, contained risk. |
| **C. Data-layer + microdata recompute** | One JSON source of truth; live audience filtering that recomputes stats in the browser | **MOSTLY NO (partial only)** | Brand's analytics (Dirichlet, TURF, MA networks, funnel) do not recompute cheaply client-side, and audience-slicing is *not* the pain point. A *lightweight* serialization boundary is worth borrowing; full microdata recompute is not. |

**Recommendation:** Do **A then B**. Treat **C** as a thin internal refactor only (clean per-panel payloads), and explicitly **do not** attempt a microdata/live-recompute rewrite of brand. A wave-tracking view (D) is a sensible later phase once there is a second IPK wave.

The single most important sentence in this review: **the brand report does not need to become the tabs report — it needs the tabs report's restraint.** The win is subtraction, not addition.

---

## 2. The problem, quantified

I parsed the actual IPK deliverable rather than relying on impressions. The surface area a single user faces:

| Cognitive-load proxy | Count in IPK report |
|---|---|
| Top-level tabs | 8 (Summary · BAK · DSS · PAS · POS · Portfolio · Pinned · About) |
| Category tabs, each fanning out to ~9 sub-destinations | 4 |
| Sub-destinations *per category* | Funnel, Brand Attitude/Relationship, MA Metrics, MA CEPs, MA Attributes, Mental Advantage, Category Buying (Headline / Buyer Heaviness / Purchase Distribution / Duplication of Purchase / Loyalty Segmentation), WOM, Demographics |
| Inline SVG charts | 58 |
| HTML tables | 105 |
| Sub-headings (h3 + h4) | 95 |
| Pin buttons (📌) | ~40 |
| PNG buttons (🖼) | 32 |
| Excel buttons (📥) | 16 |
| Per-section insight textareas | 69 |
| Occurrences of the word "significant" | 2,324 |

**Read that as one journey.** A user opens the report, lands on Summary, then must choose among 4 categories; inside each category there are ~9 places to go; almost every one carries its own chart, table, three export buttons, an insight box, and significance markers on most cells. To confirm whether a given element (say, Demographics or Ad Hoc) even *exists* for a category, the user has to click into it. There is **no search, no progressive disclosure beyond tabs, and no stable map** of "what is in this report and where."

This is a textbook *information-overload* failure, not a content-quality failure. The analysis is good (the feedback says so). The report shows **all of it, all the time, at the same visual weight.**

### Why it got this way (not a criticism — context)
The module grew element-by-element over ~15 feature branches (MA → funnel → cat buying → portfolio → branded reach → demographics → audience lens → ad hoc → exec summary). Each element was built to be *complete and pinnable in its own right*. That is exactly how you get 14 first-class, always-on, equally-weighted elements. The Executive Summary panel (`14_summary_panel.R`, **2,150 lines**) was itself added as a response to this — an attempt to put a landing in front of the sprawl — but it sits *alongside* the sprawl rather than *gating* it.

---

## 3. What the tabs v2 report actually does differently (the borrowable principles)

From `modules/tabs/docs/11_DATA_CENTRIC_REPORT_V2.md` and the shell/views JS, the principles that make v2 approachable:

1. **Dashboard-first landing.** Opens on headline gauges/heatmap (traffic-light KPIs), *not* tables. Detail is one click away, never the first thing you see.
2. **A stable, small tab set.** Always the same shape — Dashboard · Crosstabs · Differences · Tracking · Story — regardless of how many questions the study has. The IA does not change shape with content.
3. **Progressive disclosure.** Tables, confidence intervals and significance detail live *behind* the headline (tooltips, a second tab, a toggle) — present but not shouting.
4. **Search instead of browse.** A question search box means you never scroll a 50-item menu.
5. **One dataset, many lenses** (the data-centric idea). Rather than pre-render every cut, v2 carries the data and re-renders views on demand — which is *why* it can stay small.
6. **A narrative/"Story" tab** for curation — exploration (reading data) is separated from synthesis (building the story you'll present).
7. **Significance as a mode, not a default.** Dual-significance is a toggle; the clean 95% view is the default. The user opts into more rigour, rather than drowning in it.

**Brand can adopt 1, 2, 3, 4, 6, 7 without the data-centric engine (5).** Principle 5 is the expensive one and the one brand needs least (see §6).

---

## 4. Gap analysis: brand vs. tabs v2

| Dimension | Tabs v2 | Brand today | Gap severity |
|---|---|---|---|
| Landing | Headline KPI dashboard; detail on click | Lands on Summary (good), but Summary is per-category cards that still front a 4×9 maze | **Medium** — right instinct, wrong depth |
| IA stability | Fixed 5-tab shape | Nav shape changes with which of 14 elements are toggled on | **High** |
| Progressive disclosure | Strong (tabs, tooltips, toggles) | Weak — everything always visible at equal weight | **High** |
| Search / quick-nav | Yes | No | **Medium** |
| On-screen chrome | Minimal, consolidated toolbar | ~40 pin + 32 PNG + 16 Excel + 69 insight boxes | **High** |
| Significance | Toggle (clean default) | Markers everywhere (2,324 hits) | **Medium** |
| Serialization | One JSON data layer (`TR.AGG`/`TR.MICRO`/`TR.PREV`) | Hybrid: pre-rendered SVG/HTML + per-panel payloads, no single source | **Low for the user; Medium for maintainers** |
| Live audience filter | Yes (microdata recompute) | No | **Low** (not the pain point) |
| PPTX export | **Native** editable text+tables+shapes | **Image screenshots** via PptxGenJS+html2canvas; not branded | **High** (and high-value) |
| Wave tracking in-report | Yes (tracking island) | No (brand metrics are tracker-friendly by design, but no in-report view) | **Low now** (IPK is wave 1) |
| Code footprint | ~5 R files + 33 small JS modules | ~52k R lines + ~15.6k JS lines; panels of 1,200–2,150 lines each | Maintainability risk, not a user-facing gap |

---

## 5. Recommendation A — the clarity redesign (the core ask)

This is where the actual feedback lives, and it can be delivered **without touching the analytics engine** — it is a report-layer (`lib/html_report/`) and JS exercise.

### 5.1 Establish a stable, three-level information architecture

Replace "8 tabs, one of which explodes into a 4×9 maze" with a **predictable hierarchy that does not change shape**:

```
LEVEL 1 — Executive (always the landing)
   • One verdict line + 3–4 anchor numbers per category
   • A single "category health" strip; click a category → Level 2

LEVEL 2 — Category story (the 80% that gets presented)
   • Funnel (the spine)               ← primary
   • Mental Availability headline      ← primary (one view, not 4 sub-tabs)
   • Category position / WOM headline  ← primary
   • [ Show full detail ▸ ]            ← reveals Level 3

LEVEL 3 — Appendix / full detail (the 20%, on demand)
   • MA: CEPs, Attributes, Advantage (the 3 deep sub-tabs)
   • Category Buying deep cuts (Buyer Heaviness, Duplication of Purchase, Loyalty Segmentation)
   • Demographics, Branded Reach, Ad Hoc, Audience Lens
```

The rule: **Level 2 is what you would actually walk a client through. Level 3 is what you open when someone asks "why?"** Today everything is Level 2.

### 5.2 Specific, concrete moves (in priority order)

1. **Collapse Mental Availability's four sub-tabs into one headline + a "deep dive".** MA Metrics is the headline; CEPs / Attributes / Advantage are Level 3. This alone removes 3 always-present destinations × 4 categories = **12 screens** from the default path.
2. **Demote secondary elements to an Appendix section** behind a single disclosure, instead of being peer sub-tabs: Demographics, Branded Reach, Ad Hoc, Audience Lens, and the Category-Buying deep cuts (Buyer Heaviness, Duplication of Purchase, Loyalty Segmentation).
3. **Consolidate the export chrome.** One toolbar per *major section* (pin / PNG / Excel), not per sub-table. Target: cut ~40 pin + 32 PNG + 16 Excel buttons to roughly one set per Level-2 section (~12–15 toolbars total).
4. **Make significance a toggle (borrow `d2.state.sigMode`).** Default to a clean view; "Show significance" reveals the letters/markers. The 2,324 markers should be opt-in.
5. **Cut the insight boxes from 69 to "where analysts actually write".** One editable insight per Level-2 section, not one per table. Keep the callouts.json persistence; reduce the slots.
6. **Add a persistent "jump to" / search** (borrow v2's question search) so 4×(Level-2 sections) is navigable without scrolling.
7. **Stabilise the nav.** Whatever elements are toggled, the user always sees the same top-level shape: **Executive · Categories · Portfolio · Appendix · Pinned · About.** Toggled-off elements simply don't populate; they never restructure the menu.

### 5.3 What this costs / risks
- **Effort:** Medium. It is mostly `lib/html_report/03_page_builder.R` + the panel renderers + the JS tab/disclosure logic. No engine changes.
- **Risk:** Low–medium. The risk is *regression in what's shown*, not wrong numbers. Mitigation: the move is "relocate to Level 3", never "delete" — every current element remains reachable.
- **Verification:** Per the standing rule, **Duncan regenerates via `launch_turas()` and eyeballs** — I fix code + run test suites; I do not headless-run the pipeline or overwrite OneDrive deliverables.

---

## 6. Recommendation C — be honest about the data layer (do the cheap part, skip the expensive part)

The tabs v2 data layer is genuinely elegant, and it is tempting to "do the same for brand." Here is the honest assessment.

### Skip: microdata + live recompute
v2's killer feature is `TR.MICRO` — anonymised per-respondent rows that let the browser **recompute** percentages/means/significance under an arbitrary audience filter. This works for crosstabs because the maths is trivial (counts, proportions, z-tests). **It does not transfer to brand:**
- Dirichlet norms, CEP TURF, mental-availability network effects, funnel stage derivation, buyer-heaviness segmentation — these are **not closed-form recomputations** you can do in JS per filter. Re-deriving them client-side would mean porting a large chunk of the R engine to JavaScript.
- More importantly, **audience-slicing is not the reported pain.** Nobody said "I can't cut the brand report by sub-audience" — the Audience Lens element already exists for the curated cuts. The pain is *overload*. Microdata recompute would *add* capability and *add* surface area — the opposite of what's needed.

### Do: a clean per-panel serialization boundary (lightweight)
Brand already half-does this (`01_data_transformer.R` → `charts`, `02_table_builder.R` → `tables`). The worthwhile borrow from v2 is to make each panel emit a **small, documented JSON payload** (its display data) that the JS renders, rather than R pre-baking giant SVG/HTML strings. Benefits:
- **Lighter HTML** (6.9 MB is heavy; payload + client render is smaller).
- **A single, testable contract** per panel (easier handoff — the module is ~52k R lines).
- **It is the prerequisite for native PPTX** (§7) and for any future wave-tracking view (§8).

This is an internal refactor with **no user-visible change** if done well — so it should be sequenced *underneath* the clarity work, not as a separate user-facing project.

---

## 7. Recommendation B — native, branded PPTX export (high value)

### The current state is the weakest of three paths
- **Brand today:** `modules/shared/js/turas_pins_pptx.js` (363 lines) → PptxGenJS embedding **html2canvas screenshots**. Output slides are **flat images**: not editable, text not selectable, tables not real tables, fuzzy when scaled, and **not brand-themed**. The buttons the user sees are only 📌 / 🖼 PNG / 📥 Excel — PPTX is reached indirectly via the Pinned tab.
- **Tabs v2:** `14_pptx_parts.js` + `29_export.js` → **hand-rolled OOXML** producing **native editable text, native tables, and shapes**. No screenshot. This is the good one, and it's already in the repo.
- **Hub app:** `export_pptx.R` → R `officer` + branded `turas_template.pptx`. Fully branded master, but **only runs from the Shiny app** (there's no R behind a static HTML file opened from disk).

### Recommended approach: adopt the tabs v2 native engine, add a brand master
1. **Reuse the v2 OOXML engine** (`14_pptx_parts.js` / `29_export.js` / `13_zip.js`) in the brand report, replacing the image-screenshot exporter. Pins with a `tableHtml` become **real PowerPoint tables**; insight text becomes **real text boxes**; titles and "Base: n=" become **real text**. This is literally "upgrade brand to the tabs standard."
2. **Add a brand-themed slide master** — colours from `brand_colours.js` / config, a title bar, footer with source + base, and the project logo. (The v2 engine already lays down a master/layout/theme; brand-theming it is a contained change.)
3. **Handle complex bespoke charts pragmatically.** Funnel waterfalls, MA strategic quadrants and the constellation are intricate SVGs; re-emitting them as native OOXML shapes is disproportionate effort. Export those as **high-DPI images** *within* otherwise-native slides. So a slide = native title + native table + native insight text + (where needed) one crisp chart image. That is a large step up from "the entire slide is one screenshot."
4. **Surface the action.** Add a visible "Export to PowerPoint" affordance (not buried in Pinned), and a "pin → build deck" flow consistent with v2's Story tab. This pairs naturally with the §5 clarity work (the Pinned/Story tab becomes the deck-builder).
5. **Secondary path (optional):** when export is triggered *inside* `launch_turas()`, offer the R `officer` route (like hub_app) for a fully-branded master deck. Keep the JS native exporter as the default for the standalone file.

### Cost / risk
- **Effort:** Medium. The engine exists; the work is wiring brand pins into it + the brand master + the chart-image fallback.
- **Risk:** Contained and well-bounded — it's an export feature, fully covered by the existing pin schema. Failure mode is "slide looks wrong", caught immediately on inspection.
- **Dependency note:** `officer` and `base64enc` are already in `renv.lock`; the JS path needs no new R deps.

---

## 8. Recommendation D — wave tracking view (later phase)

Brand metrics were deliberately built to be **tracker-friendly** (per-respondent columns / simple ratios). Once there is an IPK wave 2, a v2-style in-report wave view (funnel deltas, MA share trend, awareness/penetration over time) is a natural, high-value addition that reuses the tracker's `Question_Mapping` and the tabs `tracking_island` pattern. **Not now** — IPK is wave 1, so there is nothing to trend. Flag it so the §6 serialization boundary is designed to make it cheap later.

---

## 9. Suggested phasing

| Phase | Scope | Value | Effort | Risk | Sequencing |
|---|---|---|---|---|---|
| **1. Clarity redesign** (§5) | Stable IA, dashboard-first, collapse MA sub-tabs, demote secondary elements to an Appendix, significance toggle, consolidate chrome, search | **Highest** (this is the stated problem) | Medium | Low–Med | Do first |
| **2. Native branded PPTX** (§7) | Adopt v2 OOXML engine + brand master + chart-image fallback; surface the export action | **High** (explicitly requested) | Medium | Low–Med | Do second; pairs with Phase 1's Pinned/Story tab |
| **3. Serialization tidy-up** (§6) | Per-panel JSON payload contract; lighten HTML | Medium (maintainability + enables 2 & 4) | Medium | Low | Underneath 1–2, not standalone |
| **4. Wave tracking view** (§8) | In-report trend views | High *when wave 2 exists* | Med–High | Med | Defer to wave 2 |

Phases 1 and 2 together address 100% of the explicit ask ("confusing / too much detail" + "PPTX highly valued"). Phases 3–4 are the "to the same standard" tail.

---

## 10. What NOT to do (explicit guardrails)

- **Do not** port the microdata/live-recompute engine to brand. Wrong tool, wrong problem, enormous effort (§6).
- **Do not** delete any element to "simplify." The move is **relocate to Level 3 / Appendix**, always reachable. Simplification = hierarchy, not loss.
- **Do not** rewrite the brand report from scratch to mirror tabs v2's file structure. The analytics engine (~52k lines, well-tested) is fine; this is a *report-layer* and *export* upgrade.
- **Do not** headless-run the brand pipeline or overwrite the OneDrive client deliverable. Fix code + run test suites; **Duncan regenerates via `launch_turas()` and verifies in the GUI.**
- **Do not** treat this as one big-bang branch. Phase 1 and Phase 2 are independently shippable and independently verifiable.

---

## 11. Evidence base (so this review is auditable)

- **IPK report metrics** — parsed directly from `IPK_Brand_report_Provisional.html` (counts in §2).
- **Tabs v2 architecture** — `modules/tabs/lib/data_layer_writer.R`, `microdata_writer.R`, `tracking_island.R`, `lib/html_report_v2/build_report_v2.R`, `assets/js/*` (33 modules), `docs/11_DATA_CENTRIC_REPORT_V2.md`.
- **Brand report architecture** — `modules/brand/lib/html_report/99_html_report_main.R` (orchestrator), `01_data_transformer.R`, `02_table_builder.R`, `03_page_builder.R`, `04_chart_builder.R`, `panels/*` (14 panels), `js/*` (17 files, ~15.6k lines), loader whitelist at `R/00_main.R:51–138`.
- **PPTX paths** — brand: `modules/shared/js/turas_pins_pptx.js`; tabs v2: `modules/tabs/lib/html_report_v2/assets/js/14_pptx_parts.js` + `29_export.js`; hub app: `modules/hub_app/lib/export_pptx.R` + `assets/turas_template.pptx`. `officer` v0.7.0 + `base64enc` present in `renv.lock`.
- **Elements** — `modules/brand/README.md` (14 toggleable elements); user journey — `modules/brand/docs/BRAND_REPORT_USER_GUIDE.md`.

---

## 12. One-paragraph summary for the exec check-in

The brand analysis is strong; the *report* overwhelms because all 14 elements are shown always, at equal weight, across a 4-category × ~9-sub-tab maze with ~40 pin buttons, 105 tables and significance markers on nearly every cell. The tabs v2 report is calmer not because of its data engine but because of its **restraint** — it lands on a headline, keeps a stable small menu, and reveals detail on demand. We should borrow that restraint (a three-level IA: Executive → Category story → Appendix), make significance and deep cuts opt-in, and **upgrade PPTX export from today's fuzzy screenshots to the native, editable, brand-themed slides the tabs v2 engine already produces.** We should *not* try to give brand the live-recompute microdata engine — that solves a problem brand doesn't have and would add surface area, not remove it. Phase 1 (clarity) and Phase 2 (PPTX) cover the entire ask and are independently shippable.
