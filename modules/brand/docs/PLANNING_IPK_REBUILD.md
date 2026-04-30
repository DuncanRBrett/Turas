# Brand Module Rebuild — IPK as Canonical Template

**Date:** 2026-04-30
**Status:** Planning complete — ready to begin execution on a new feature branch
**Project type:** Software product / module rebuild
**Branch (to create):** `feature/brand-ipk-rebuild`

This is the governing reference for the rebuild. Build sequence, file inventory, schema specs, and verification gates all live here. Update in place as decisions evolve.

---

## 1. Problem Statement

The brand module was built against a synthetic 9-category fixture whose column shape (one column per brand, e.g. `BRANDAWARE_DSS_IPK = 1`) does not match the shape that real Alchemer exports — once parsed by AlchemerParser — actually produce. The IPK Wave 1 survey is now the canonical real-world template. Its data uses tabs-compatible *slot-indexed* columns (`BRANDAWARE_DSS_1...16` with brand codes as cell values) and a per-brand single-response shape for radio questions (`BRANDATT1_DSS_IPK`, `WOM_POS_COUNT_DSS_IPK`).

The rebuild aligns the brand module with the standards already set by the tabs and tracker modules: a single shared `Survey_Structure.xlsx` schema, a single AlchemerParser feeding both modules, and consistent wave conventions. The HTML report layout, pin/PNG export contract, and analytical methods (Romaniuk MA, Ehrenberg-Bass funnel logic, NBD-Dirichlet thinking) are not changing — only the data-access layer and the configuration surface.

The rebuild also delivers the flexibility the dev note demands: any number of categories, any brand list per category, any CEP/attribute count, any ad hoc questions, with conventions that make typical projects trivial to set up and explicit overrides available when projects deviate.

---

## 2. Landscape & Approach

### What already exists and stays
- **Analytical engines** for every element (funnel, MA, MA Advantage, WOM, Cat Buying, Shopper Behaviour, Portfolio, Branded Reach, DBA, Demographics, Ad Hoc, Audience Lens). All operate on per-respondent × per-brand logical matrices and stay as-is.
- **HTML report shell** — sub-tab structure, panel JSON contract, dark-navy styling, focal picker, pin/PNG export, TurasPins library, hub integration. All stay.
- **Role-registry skeleton** in [00_role_map.R](../R/00_role_map.R) — the resolver concept is right; only the consumer helpers and the canonical patterns change.
- **TRS v1.0 refusal contract** — every refusal in the new code uses [00_guard.R](../R/00_guard.R) helpers as today.

### What changes
- **Data-access layer**: a single shared helper resolves a Multi_Mention root + brand code to a logical respondent vector by searching across slot columns. Replaces every `data[[paste0(Q,"_",B)]] == 1` site.
- **Survey_Structure.xlsx schema**: tabs format becomes the foundation. Brand-specific sheets are layered on top in a brand-only template. One file, two template variants.
- **Brand_Config.xlsx**: slimmed to settings + element toggles + category roles + thresholds + audience definitions. Brands / CEPs / Attributes / DBA assets move to Survey_Structure.
- **Role registry**: convention-first inference from the Questions sheet, with an optional `QuestionMap` override sheet for projects that deviate from convention.
- **Wave handling**: one file per wave, separate report run per wave, exactly as tracker does it. Multi-wave comparison is a downstream concern (existing tracker plumbing handles it).
- **Partial-data resilience**: Brand_Config Categories sheet has an `Active` column. The module reports only on Active categories. For Active categories where data is missing or incomplete, the report renders what's available and clearly notes what's not.
- **Synthetic fixture**: the legacy 9cat generator is retired. A new generator produces output structurally identical to AlchemerParser-cleaned IPK exports.

### Approach: Path A — in-place refactor on a new branch
- Branch `feature/brand-ipk-rebuild` cut from `main`.
- Element-by-element migration with verification gates after each step.
- `main` and the live polished work remain untouched until cutover.
- Old fixture deleted only after the new fixture passes equivalent regression checks for every salvageable test.

---

## 3. Objectives

These are measurable. The build is not done until every objective passes.

1. **Brand module ingests AlchemerParser-cleaned IPK Wave 1 data** and produces a complete HTML report for the DSS deep dive without manual data manipulation.
2. **Survey_Structure.xlsx is shared** between tabs and brand modules. A single file feeds both modules; tabs ignores brand sheets; brand reads tabs sheets + brand sheets.
3. **Adding a new category** to a brand project requires only Brand_Config edits (Categories sheet + Brands sheet entries) — no module code changes.
4. **Adding a new brand** to an existing category requires only adding a row to Brands in Survey_Structure — no code changes.
5. **CEP and attribute counts are project-driven** — DSS with 15 CEPs + 15 attributes works; a future project with 8 CEPs + 5 attributes works without code changes.
6. **Partial data renders gracefully** — running the brand module against IPK Wave 1 (DSS-only, no DBA, no Branded Reach) produces a complete report for what is present and a clear "not yet collected" placeholder card for what isn't. Active categories with no data show the placeholder; Inactive categories never appear.
7. **Test coverage** — every analytical element has a unit test that runs against the new IPK fixture and verifies a known-answer output. All 1500+ existing brand tests pass on the new fixture (those that don't are explicitly retired with reason recorded).
8. **The new synthetic fixture is structurally indistinguishable** from a parsed Alchemer export — same column names, same slot-indexed shape, same value coding, same `Wave` derivation. AlchemerParser run on the IPK survey produces files the module accepts identically.
9. **The role registry is convention-first** — a typical project's Survey_Structure has no QuestionMap sheet; the module infers roles from `BRANDPEN1_{CAT}`, `BRANDATTR_{CAT}_CEP{NN}`, etc. Operator can supply a QuestionMap to override.
10. **Performance**: full IPK 4-category × 1200-respondent report generation completes in under 90 seconds on the 9cat reference machine (current baseline: ~80s).

---

## 4. Requirements

### Capabilities
- Read tabs-format `Survey_Structure.xlsx` (Project / Questions / Options sheets).
- Read brand-extension sheets (Brands / CEPs / Attributes / DBA_Assets / optional QuestionMap) when present.
- Read `Brand_Config.xlsx` (Settings / Categories / AdHoc / AudienceLens).
- Resolve every analytical role to concrete data columns via convention-first inference + optional override.
- Produce per-respondent × per-brand logical matrices for any Multi_Mention question regardless of slot count.
- Produce per-respondent × per-brand value matrices for per-brand Single_Response questions.
- Auto-detect available categories from data + Active flag + report only on Active+available.
- Render HTML report with the same sub-tab structure, focal picker, pin/PNG export, dark-navy styling, TurasPins library, and hub integration as today.
- Wave column derived in `prep_data.R`, set per project, downstream tracker comparisons handled by tracker module.

### Quality standards
- TRS v1.0 — no `stop()`, no silent failures. Every refusal is structured + console-visible.
- Coding standards per [duncan-coding-standards](../../../.claude/skills/anthropic-skills/duncan-coding-standards) — file ≤ 300 active lines, function ≤ 50 active lines, no magic numbers, typed errors, deterministic tests, named-constant config.
- Every public function has roxygen docs with @param, @return, @examples.
- 100% of new public functions have known-answer tests.
- All tests deterministic — no unseeded randomness, no time-dependent behaviour.
- Console-visible error reporting for Shiny — every refusal renders the boxed `=== TURAS ERROR ===` format from CLAUDE.md.

### Constraints
- Cannot touch `modules/tabs/` or `modules/tracker/` — they are upstream standards. Brand adapts.
- Cannot break the existing pin/PNG export pipeline — `panel_data` JSON contract per element must be backward-compatible (or migration documented).
- Cannot regress on currently working categories of analysis — every metric the production module produces today must produce the same value (within float tolerance) on equivalent input data.
- AlchemerParser is the only data-shaping point. The brand module never re-shapes; if data is wrong, parser is fixed.
- No new R package dependencies unless justified. Existing stack: data.table, openxlsx, jsonlite, base R.

### Dependencies
- AlchemerParser must produce IPK-shape output for the live data. If the parser doesn't yet, that work blocks brand module verification.
- Tabs module's `Survey_Structure.xlsx` schema is the foundation. If tabs changes its schema, brand inherits the change.
- IPK Alchemer survey must complete enough categories to validate multi-category logic. DSS alone is enough for single-category testing; POS/PAS/BAK at minimum once for multi-category Portfolio + Cross-Category Awareness verification.

### Scenarios
- **As a market researcher (Duncan)**, I run AlchemerParser on the IPK export, then run the brand module pointing at the parser output and Brand_Config — and get the standard HTML report covering DSS today, plus auto-extending to POS/PAS/BAK as those waves come in.
- **As a project lead spinning up a new brand project (Jess or Duncan)**, I copy the brand template folder, edit Brand_Config (categories, brand list, CEPs, settings), program the survey in Alchemer using the spec naming convention, run AlchemerParser, run the brand module — and the report renders correctly without code changes.
- **As an operator with a one-off non-standard column name**, I add a single QuestionMap row to override the convention inference for that role only, leave the rest auto-inferred.
- **As a tracker operator**, I have wave 1 done, wave 2 collected — I run AlchemerParser on each wave separately, run the brand module separately on each, then run the tracker module on the combined output. Brand module never sees more than one wave at a time.
- **Unhappy path — partial data**: a category is Active in Brand_Config but the data has no respondents in that category. Report renders with a "Data not yet collected for [Category Name]" panel; the rest of the report is unaffected.
- **Unhappy path — config drift**: Brand_Config lists 12 brands for DSS but only 10 appear in the data. Report uses the 12 declared brands; missing brands show 0% for all metrics with a clear note "no respondents picked this brand".

---

## 5. Design & Experience

### 5.1 Configuration files

#### `Survey_Structure.xlsx` — tabs-foundation, brand-extended

**Two template variants:**
- `modules/tabs/templates/Survey_Structure_Template.xlsx` — tabs-only (existing, unchanged).
- `modules/brand/templates/Survey_Structure_Brand_Template.xlsx` — extends tabs with brand sheets.

**Sheets in the brand template:**

| Sheet | Source | Required for | Notes |
|---|---|---|---|
| `Project` | Tabs | All | Existing tabs schema. Brand reads `data_file_path`, `output_dir`, `wave`. |
| `Questions` | Tabs | All | Existing tabs schema. Brand registers every brand question here using tabs Variable_Type vocabulary. |
| `Options` | Tabs | Most | Existing tabs schema. Brand option codes go here (e.g. one row per attitude code with DisplayText). |
| `Brands` | Brand-only | Brand projects | Per category × brand: `Category`, `BrandCode`, `BrandLabel`, `DisplayOrder`, `IsFocal`. |
| `CEPs` | Brand-only | If `element_mental_avail = Y` | Per category × CEP: `Category`, `CEPCode` (e.g. `CEP01`), `CEPText`, `DisplayOrder`. |
| `Attributes` | Brand-only | If `element_mental_avail = Y` | Per category × attribute: `Category`, `AttrCode` (e.g. `ATT01`), `AttrText`, `DisplayOrder`. |
| `DBA_Assets` | Brand-only | If `element_dba = Y` | Per asset: `AssetCode`, `AssetLabel`, `AssetType`, `FilePath`, `FameQuestionCode`, `UniqueQuestionCode`. |
| `Channels` | Brand-only | Channels questions | Per category × channel: `Category`, `ChannelCode`, `ChannelLabel`, `DisplayOrder`. |
| `PackSizes` | Brand-only | Pack questions | Per category × pack: `Category`, `PackCode`, `PackLabel`, `DisplayOrder`. |
| `MarketingReach` | Brand-only | If `element_branded_reach = Y` | Per ad code: `AdCode`, `AdLabel`, `Description`. |
| `QuestionMap` | Brand-only | Optional override | One row per role to override convention inference. Schema: `Role`, `ColumnPattern`, `Variable_Type`, `OptionMapScale`. Empty in typical projects. |

**Naming conventions** (the convention-first defaults, per the IPK Alchemer spec and live data):

| Role family | Pattern | Example |
|---|---|---|
| Cross-cat awareness | `BRANDAWARE_{CAT}` (Multi_Mention, brand codes as values) | `BRANDAWARE_DSS_1...16` |
| CEP × brand matrix | `BRANDATTR_{CAT}_CEP{NN}` (Multi_Mention) | `BRANDATTR_DSS_CEP01_1...16` |
| Attribute × brand matrix | `BRANDATTR_{CAT}_ATT{NN}` (Multi_Mention) | `BRANDATTR_DSS_ATT01_1...16` |
| Brand attitude | `BRANDATT1_{CAT}_{BRAND}` (Single_Response, numeric code) | `BRANDATT1_DSS_IPK` |
| Rejection OE | `BRANDATT2_{CAT}_{BRAND}` (Open_End) | `BRANDATT2_DSS_IPK` |
| Penetration long | `BRANDPEN1_{CAT}` (Multi_Mention) | `BRANDPEN1_DSS_1...16` |
| Penetration target | `BRANDPEN2_{CAT}` (Multi_Mention) | `BRANDPEN2_DSS_1...16` |
| Purchase frequency | `BRANDPEN3_{CAT}` (Multi_Mention or per-brand single — TBC by parser output) | `BRANDPEN3_DSS_*` |
| Category buying freq | `CATBUY_{CAT}` (Single_Response, numeric code) | `CATBUY_DSS` |
| Category count | `CATCOUNT_{CAT}` (Numeric) | `CATCOUNT_DSS` |
| Channels | `CHANNEL_{CAT}` (Multi_Mention) | `CHANNEL_DSS_1..6` |
| Pack sizes | `PACK_{CAT}` (Multi_Mention) | `PACK_DSS_1..4` (note: `PACK_`, not `PACKSIZE_`) |
| WOM received pos / shared pos / received neg / shared neg | `WOM_{TYPE}_{CAT}` (Multi_Mention) | `WOM_POS_REC_DSS_1..16` |
| WOM count | `WOM_{TYPE}_COUNT_{CAT}_{BRAND}` (Single_Response, numeric code) | `WOM_POS_COUNT_DSS_IPK` |
| DBA fame | `DBA_FAME_{ASSET}` (Single_Response) | `DBA_FAME_LOGO` |
| DBA unique | `DBA_UNIQUE_{ASSET}` (Open_End coded post-field) | `DBA_UNIQUE_LOGO` |
| Branded reach seen / brand / media | `REACH_{TYPE}_{ADCODE}` | `REACH_SEEN_ADTV01` |
| Demographics | `DEMO_{KEY}` (any type) | `DEMO_AGE` |
| Ad hoc sample-wide | `ADHOC_{KEY}` | `ADHOC_NPS` |
| Ad hoc category-specific | `ADHOC_{KEY}_{CAT}` | `ADHOC_FUTURE_DSS` |
| Screener long window | `SQ1` (Multi_Mention with category codes as values) | `SQ1_1..N` |
| Screener target window | `SQ2` (Multi_Mention) | `SQ2_1..N` |
| Focal category assignment | `Focal_Category` (Single_Response with category code value) | `Focal_Category` |

#### `Brand_Config.xlsx` — slimmed to brand-module-only metadata

| Sheet | Purpose |
|---|---|
| `Settings` | Element toggles (`element_funnel`, `element_mental_avail`, `element_wom`, `element_dba`, `element_branded_reach`, `element_portfolio`, `element_audience_lens`), thresholds, wave number, `wom_timeframe`, colour palette, file paths, `focal_assignment` strategy |
| `Categories` | Per category: `Category` (label), `CategoryCode` (matches data), `Active` (Y/N), `Type` (transactional/durable/service), `Analysis_Depth` (full / awareness_only / screener_only), `Timeframe_Long`, `Timeframe_Target`, `Focal_Weight` |
| `AdHoc` | Per ad-hoc question: `Role`, `ClientCode`, `QuestionTextShort`, `Variable_Type`, `OptionMapScale`, `Scope` (sample / category) |
| `AudienceLens` | If element on: per audience: `AudienceCode`, `AudienceLabel`, `Definition` (R expression or column ref) |

### 5.2 Data-access layer (the heart of the rewrite)

A single small module — `modules/brand/R/00_data_access.R` — exposes the helpers every analytical element calls. This file replaces every site that does `data[[paste0(Q,"_",B)]]`.

```r
#' Did each respondent select a given option for a Multi_Mention question?
#'
#' Searches across all slot columns matching `^{root}_[0-9]+$` for the option
#' code. Returns a logical vector of length nrow(data).
#'
#' @param data Data frame.
#' @param root Question root code (e.g. "BRANDAWARE_DSS").
#' @param option_code Option code to test for (e.g. "IPK", "NONE").
#' @return Logical vector, length nrow(data). NA-safe.
respondent_picked <- function(data, root, option_code) { ... }

#' Build a per-respondent × per-brand logical matrix from a Multi_Mention root.
#'
#' Wraps respondent_picked() across a brand list. Columns are brand codes,
#' rows are respondents. NA entries are FALSE.
#'
#' @param data Data frame.
#' @param root Question root code.
#' @param brand_codes Character vector of brand codes.
#' @return Logical matrix [n_resp × n_brands] with brand_codes as colnames.
multi_mention_brand_matrix <- function(data, root, brand_codes) { ... }

#' Read a per-brand Single_Response column directly.
#'
#' For the BRANDATT1_{CAT}_{BRAND} family — one column per brand. Returns
#' the numeric vector unchanged.
single_response_brand_column <- function(data, root, cat_code, brand_code) { ... }

#' Build a per-respondent × per-brand value matrix from per-brand columns.
single_response_brand_matrix <- function(data, root, cat_code, brand_codes) { ... }
```

These four helpers cover every brand × respondent question pattern in the canonical naming. The role-registry resolver returns `entry$root` and `entry$variable_type`; consumers call the right helper based on `variable_type`.

### 5.3 Role resolution flow

```
Brand_Config.Categories (Active=Y) + Survey_Structure.Brands
                        │
                        ▼
        load_brand_role_map(structure, config)
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
  Convention inference        QuestionMap override
  (from question codes        (if sheet present —
   in Survey_Structure.        per-row override of
   Questions sheet)            inferred entries)
        │                               │
        └───────────────┬───────────────┘
                        ▼
           role_map: list keyed by role name
           (e.g. "funnel.penetration_long.DSS"),
           each with: root, variable_type,
           option_scale, applicable_brands
                        │
                        ▼
        Every analytical element calls
        role_map[["funnel.penetration_long.DSS"]]
        and dispatches to data-access helpers
        based on variable_type
```

Convention inference rules — codified in `modules/brand/R/00_role_inference.R`:

| Question code shape | Inferred role(s) |
|---|---|
| `BRANDAWARE_{CAT}` | `funnel.awareness.{CAT}`, `portfolio.awareness.{CAT}` |
| `BRANDPEN1_{CAT}` | `funnel.penetration_long.{CAT}` |
| `BRANDPEN2_{CAT}` | `funnel.penetration_target.{CAT}` |
| `BRANDPEN3_{CAT}` | `funnel.frequency.{CAT}` (TBC: per-brand or multi-mention?) |
| `BRANDATT1_{CAT}_{BRAND}` | `funnel.attitude.{CAT}.{BRAND}` (collapsed by element to per-brand matrix) |
| `BRANDATTR_{CAT}_CEP{NN}` | `mental_avail.cep.{CAT}.CEP{NN}` |
| `BRANDATTR_{CAT}_ATT{NN}` | `mental_avail.attr.{CAT}.ATT{NN}` |
| `WOM_POS_REC_{CAT}` | `wom.received_positive.{CAT}` |
| ... etc per the table in 5.1 ||

QuestionMap override: a row with `Role = "funnel.awareness.DSS"`, `ColumnPattern = "MyCustomAware_{brandcode}"`, `Variable_Type = "Multi_Mention"` replaces the convention.

### 5.4 Partial-data behaviour

Per Active=Y category in Brand_Config:
1. Module checks if expected root columns exist in the data file.
2. If all expected roots present → render the full sub-tab as today.
3. If some expected roots missing → render a placeholder card "Data not yet collected — expected questions: [list]" within the relevant sub-tab. Other elements for the same category that have data still render.
4. If category has no respondents (column exists but no rows match Focal_Category=CAT) → render "No respondents in this category yet (n=0)" placeholder.
5. Categories with `Active=N` are silently skipped — no panel, no placeholder.

The category list shown in the focal picker reflects only Active=Y categories that have ≥1 element with data. Categories with all elements missing render a single top-level "Awaiting data" card and nothing else.

### 5.5 Error handling — Shiny-visible

Every refusal goes through `brand_refuse(code, title, problem, why_it_matters, how_to_fix, ...)` which:
- Returns the structured TRS list.
- Writes the boxed `┌─── TURAS ERROR ───` block to console via `cat()`.
- Calls `showNotification()` if Shiny session is active.

This is unchanged from current contract. New error codes added for the migration:
- `DATA_SLOT_COLUMNS_MISSING` — expected `Q_root_1...N` slots not in data
- `CFG_CATEGORY_INACTIVE_BUT_REQUESTED` — caller asked for inactive category
- `CFG_ROLE_NOT_INFERABLE` — convention failed and no QuestionMap entry exists
- `DATA_NO_ALCHEMER_PARSER_OUTPUT` — data file shape suggests raw export, not parser output

### 5.6 HTML report — unchanged

Sub-tab structure, focal picker behaviour, panel JSON contract, dark-navy styling, TurasPins library, hub integration: all stay exactly as today. The output assembly code in `99_output.R` and the panel-data builders (`*_panel_data.R`) are the LAST things to change — they consume the analytical engines, which consume the role map, which consumes the data-access helpers. Earlier layers change; the report layer should ideally not need any changes beyond input wiring.

---

## 6. Growth Roadmap

### Immediate (this rebuild — Wave 1 IPK)
- Single wave (`Wave = 1` derived in prep_data.R).
- DSS deep dive only (POS/PAS/BAK Active=N until Jess finishes Alchemer build).
- Cross-category awareness for whichever Adjacent categories have data.
- All polished sub-tabs render: Funnel, Mental Availability, Mental Advantage, Cat Buying / Shopper Behaviour, Portfolio (DSS-only at first), Branded Reach (placeholder), DBA (placeholder), Demographics, Ad Hoc (placeholder), Audience Lens.

### Near-term (3–6 months)
- POS/PAS/BAK deep dives added as Jess completes them in Alchemer.
- DBA data collected and assets coded.
- Branded Reach added with stimuli.
- Wave 2 collected — tracker module wired up for wave-over-wave.
- Second non-IPK brand project run end-to-end as a flexibility validation.

### Long-term (6–18 months)
- Additional question types (Likert batteries beyond CEP, Rating-scale brand image batteries, MaxDiff brand priorities) — adding via the same convention/QuestionMap pattern.
- White-label deployment at a partner agency — proves the parser-feeds-both-modules architecture in someone else's hands.
- Audience Lens v2 — multi-audience comparison rather than single-pair.
- Multi-wave consolidated reporting once tracker has 3+ waves.

### Foundational decisions taken now to support growth
- Role registry survives because new question types only need a convention + handler + (optionally) a QuestionMap row.
- Single Survey_Structure schema means tabs-side improvements (composite scores, ranking, NPS) become available to brand projects automatically.
- AlchemerParser as the only data-shaping point means new export quirks are fixed in one place.
- Slot-indexed format is the natural Alchemer output — no more divergence between fixture and reality.

---

## 7. Risks & Mitigations

### Execution risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| AlchemerParser doesn't produce the assumed shape for some question type | Medium | High — blocks verification | Run parser on IPK data first, confirm shape for every question type before brand module work begins. If gaps, fix parser first. |
| Per-brand Single_Response (BRANDATT1) format doesn't match expectations after parser run | Low | Medium | Verify with parsed IPK output before locking the data-access helper API. |
| Partial-data rendering reveals layout bugs in HTML report (panels assume sibling panels exist) | Medium | Medium | Test partial-data scenarios explicitly. Ensure each panel renders standalone. |
| Existing 1500+ tests fail wholesale because they presume Format A column shape | High | Medium | Migrate tests in waves with the production code; retire format-A-specific tests with reasoning recorded. New IPK-shape fixture replaces 9cat fixture. |
| Pin/PNG round-trip breaks due to panel JSON contract drift | Medium | High — direct user-facing | Lock contract version + browser-test pin/PNG capture for every sub-tab post-migration. Per memory: launch_turas() Shiny app is the verification path. |
| Performance regression — slot-indexed reads slower than direct-column reads | Low | Medium | Benchmark with full IPK fixture before/after. Cache the slot-search result if needed. |
| Convention inference produces ambiguous roles (BRANDPEN3 — per-brand or multi-mention?) | Medium | Low | Verify against parsed IPK output; document explicitly in role_inference.R; QuestionMap override is the escape hatch. |
| Brand_Config schema migration confuses existing examples | Low | Low | Generate fresh templates as part of the rebuild; no support for legacy Brand_Config v1. |

### Strategic risks

| Risk | Mitigation |
|---|---|
| Time sink — rebuild takes longer than expected and delays IPK Wave 1 reporting | Build in element order from least-entangled to most. Each element ships verified; if calendar pressure hits, partial brand module is still useful. |
| The convention-first inference is too clever and fails on a non-IPK project | QuestionMap override sheet is the safety valve. Document the inference rules clearly. Run a non-IPK test project early. |
| Tabs schema changes during the rebuild | Coordinate with tabs work — no concurrent tabs schema changes during this rebuild. |
| Memory: "Don't touch synthetic data generator" | Per Duncan's confirmation, the old generator IS being deprecated as part of this rebuild. Update the memory entry once rebuild is merged. |

---

## 8. Quality Standards

### Per-element verification gate
Before any element is marked complete:
1. **Unit tests** — at least one known-answer test per public function. Inputs literal, expected outputs hand-calculated.
2. **Integration test** — element runs end-to-end on the new IPK fixture, output is structurally valid (panel JSON parses, columns exist, types correct).
3. **Regression test** — for any element that currently exists, run the old test against the new code with the new fixture; outputs match (within float tolerance) for equivalent metrics.
4. **TRS coverage** — every refusal path in the element has a test that triggers it and asserts the structured refusal shape.
5. **Shiny console output** — boxed `=== TURAS ERROR ===` rendered for at least one refusal path, confirmed by manual inspection.
6. **Style** — `styler::style_file()` clean, `lintr::lint()` clean.
7. **Doc** — every public function has roxygen with @param, @return, @examples.
8. **Coverage** — `covr::package_coverage()` ≥ 80% for new files, ≥ 90% for the data-access layer specifically.

### Final cutover gate (before merge to main)
- Full test suite passes on `feature/brand-ipk-rebuild` (target: 1500+ tests, exact count TBC after migration).
- Browser verification per memory: `launch_turas()` → pick IPK Brand_Config in GUI → render report → pin every panel → export PNG of every panel → all succeed.
- Pin / PNG round-trip works for every sub-tab.
- HTML report renders cleanly in Chrome + Safari + Firefox.
- Performance: full report < 90s on reference machine.
- Documentation updated: README, CLAUDE.md if needed, this planning doc marked Status = Complete.
- Old fixture deleted; old generator deleted.
- Memory entries updated.

---

## 9. Build Order & File Inventory

### Build sequence — strict order
Each step ships verified before next begins. Can compress if confident, but the verification gates do not move.

| Step | Element | Files | Verification |
|---|---|---|---|
| **0. Foundations** ||||
| 0a | New branch + scaffolding | `git checkout -b feature/brand-ipk-rebuild` | branch created, builds |
| 0b | New synthetic IPK fixture generator | `modules/brand/tests/fixtures/generate_ipk_wave1.R` (new) — produces parser-shape data with ~1200 rows, 4 Core + 5 Adjacent, 10-15 brands per cat, 15 CEPs + 15 ATT for DSS | running it produces a file shape-identical to a parsed Alchemer export; tabs module can read it without error |
| 0c | New Brand_Config + Survey_Structure templates | `modules/brand/templates/Brand_Config.xlsx`, `modules/brand/templates/Survey_Structure_Brand_Template.xlsx` | template files validate against schema; example IPK config copies cleanly |
| **1. Data-access layer** ||||
| 1a | `respondent_picked()`, `multi_mention_brand_matrix()`, `single_response_brand_column()`, `single_response_brand_matrix()` | `modules/brand/R/00_data_access.R` (new) | known-answer tests on hand-coded slot-indexed input |
| 1b | Updated role registry — convention-first inference + QuestionMap override | `modules/brand/R/00_role_map.R` (rewrite), `modules/brand/R/00_role_inference.R` (new) | role map for IPK Survey_Structure resolves all expected roles correctly |
| 1c | Updated guards — slot-column existence, active category checks | `modules/brand/R/00_guard.R` (refactor relevant sections) | refusal shape verified for each new error code |
| **2. Config readers** ||||
| 2a | `load_brand_survey_structure()` reads tabs format + brand sheets | `modules/brand/R/01_config.R` (rewrite) | reads IPK template; ignores tabs-only sheets gracefully |
| 2b | `load_brand_config()` reads slimmed Brand_Config | same file | reads new schema; refuses on missing required fields with clear messages |
| 2c | Active-category resolver + partial-data detector | new helper in `01_config.R` | given Brand_Config + data file, returns the actual category list to report on |
| **3. Per-element migration** ||||
| 3a | Funnel | `03_funnel.R`, `03a_funnel_derive.R`, `03b_funnel_metrics.R`, `03c_funnel_panel_data.R`, `03d_funnel_output.R` | renders DSS funnel against new fixture; matches expected Romaniuk maths |
| 3b | Cat Buying + Shopper Behaviour | `08_cat_buying.R`, `08b_brand_volume.R`, `08c_dirichlet_norms.R`, `08d_buyer_heaviness.R`, `08e_shopper_behaviour.R` | 6-tab cat-buying panel renders correctly |
| 3c | Mental Availability | `02_mental_availability.R`, `02a_ma_panel_data.R` | CEP × brand matrix renders for DSS with 15 CEPs |
| 3d | Mental Advantage | `02b_mental_advantage.R`, `02b_ma_advantage_data.R` | quadrant + action list renders with WOM input working |
| 3e | WOM | `05_wom.R`, `05a_wom_panel_data.R` | 4 multi-mention checkboxes + per-brand counts produce correct net balance |
| 3f | Repertoire | `04_repertoire.R` | renders with new BRANDPEN2 access |
| 3g | Drivers / Barriers | `06_drivers_barriers.R` | renders with new attitude data |
| 3h | DBA | `07_dba.R` | renders or shows partial-data placeholder |
| 3i | Portfolio | `09*_portfolio*.R` (10 files) | cross-cat awareness portfolio renders for DSS-Adjacent only initially |
| 3j | Branded Reach | `10*_br*.R` | placeholder for IPK Wave 1; full render once data added |
| 3k | Demographics | `11*_demographics*.R` | renders DEMO_* questions |
| 3l | Ad Hoc | `12*_adhoc*.R` | renders ADHOC_* questions per Brand_Config AdHoc sheet |
| 3m | Audience Lens | `13*_al*.R` (4 files) | renders for DSS focal brand pair |
| **4. Output assembly** ||||
| 4a | Output writer + report shell | `99_output.R`, `00_main.R` | full report renders end-to-end against IPK fixture |
| 4b | Run from launch_turas GUI | `run_brand_gui.R` if needed | manual browser verification — every panel pins + exports |
| **5. Cutover** ||||
| 5a | Delete old fixture + old generator | remove `tests/fixtures/generate_ipk_9cat_wave1.R` and related | tests still pass with only new fixture |
| 5b | Update memory entries | update `~/.claude/projects/-Users-duncan-Dev-Turas/memory/` notes | memory reflects new reality |
| 5c | Merge to main | PR + merge | main has rebuilt brand module, IPK pipeline live |

### File inventory — what changes vs stays

**Heavy rewrite (data-access layer in every consumer):**
- `00_role_map.R`, `00_data_access.R` (new), `00_role_inference.R` (new)
- `00_guard.R` (partial — error codes + slot-column checks)
- `01_config.R` (rewrite reader for new schema)
- `02_mental_availability.R`, `02a_ma_panel_data.R`
- `02b_mental_advantage.R`, `02b_ma_advantage_data.R`
- `03_funnel.R`, `03a_funnel_derive.R`, `03b_funnel_metrics.R`
- `04_repertoire.R`
- `05_wom.R`, `05a_wom_panel_data.R`
- `06_drivers_barriers.R`
- `07_dba.R`
- `08_cat_buying.R`, `08b_brand_volume.R`, `08c_dirichlet_norms.R`, `08d_buyer_heaviness.R`, `08e_shopper_behaviour.R`
- `09a_portfolio_footprint.R` through `09h_portfolio_overview_data.R`
- `10a_br_panel_data.R` through `10d_br_output.R`
- `11_demographics.R`, `11a_demographics_panel_data.R`
- `12_adhoc.R`, `12a_adhoc_panel_data.R`
- `13_audience_lens.R`, `13a_al_audiences.R`, `13b_al_metrics.R`, `13c_al_classify.R`, `13d_al_panel_data.R`

**Minor change (input wiring + paths):**
- `00_main.R` (orchestration — rewires to new role map, partial-data check)
- `99_output.R` (panel inputs change minimally; output structure unchanged)
- `generate_config_templates.R` (regenerates new templates)

**No change (or only style):**
- `03c_funnel_panel_data.R`, `03d_funnel_output.R`, `03e_funnel_legacy_adapter.R` (delete `03e_*` after migration)
- HTML report shell + JS (`templates/`, `lib/`)
- TurasPins library (`shared/`)
- Tests get migrated alongside their source files.

**Delete after cutover:**
- `tests/fixtures/generate_ipk_9cat_wave1.R`
- Any `_legacy_adapter.R` files
- `00_guard_role_map.R` if superseded
- Any `get_questions_for_battery()` callers (per dev note)

---

## 10. Next Steps

Immediately actionable, in order. **The fixture is the contract** — parser verification is a final validation gate, not an upfront blocker. The shape we are building against is the one in `IPK_Data_Structure v2.xlsx`, confirmed against tabs module's native handling.

1. **Cut the branch** — `git checkout -b feature/brand-ipk-rebuild` from `main`.
2. **Build new fixture generator (step 0b)** — synthetic IPK Wave 1 data, parser-shape, ≥1200 respondents, 4 Core + 5 Adjacent, full DSS deep dive, partial POS/PAS/BAK, no DBA/Branded Reach. Doubles as the test fixture for every element. **This is the contract** — every later step is verified against this fixture.
3. **Build new Survey_Structure_Brand_Template + Brand_Config templates** with example IPK content.
4. **Build the data-access layer (step 1a)** with full known-answer test coverage. Every subsequent element depends on this.
5. **Migrate the role registry (steps 1b, 1c)** — convention inference, QuestionMap override, slot-column-aware guards.
6. **Element-by-element migration (steps 3a–3m)** in order. Each shipped verified before the next.
7. **Output assembly + manual browser verification** against the fixture.
8. **Final validation gate — AlchemerParser run on real IPK data**. Compare the parser output against the fixture shape. If they match (which they should — the fixture was built from `IPK_Data_Structure v2.xlsx` which is parser-target-shape), proceed to cutover. If they diverge, fix the parser, not the brand module.
9. **Final cutover gates** — full suite green, browser verification, performance check, memory updated, merge.

### Risk if parser output diverges from the fixture shape
Low — the IPK reconfigured data file is already parser-target-shape, and tabs module reads it natively. But if a divergence is found at step 8, the contract is clear: AlchemerParser is the single data-shaping point per the architectural decisions in §2. Brand module never reshapes. Any divergence is a parser issue.

---

## Appendix — Reference

- [Brand module restructure dev note](DEV_NOTE_brand_module_restructure.md) — the baseline plan this document supersedes.
- [Alchemer programming spec](ALCHEMER_PROGRAMMING_SPEC.md) — survey-side spec (note: now updated by Duncan's confirmations — `PACK_` not `PACKSIZE_`, slot-indexed format is canonical, WOM has `_{CAT}_` in column names).
- [Session 4 IPK handover](HANDOVER_IPK_ALCHEMER_SESSION4.md) — current Alchemer build state.
- [Tabs Survey_Structure template](../../tabs/templates/Survey_Structure_Template.xlsx) — the foundation schema this rebuild adopts.
- [Tabs standard processor](../../tabs/lib/standard_processor.R) — the reference implementation for slot-indexed Multi_Mention reading (lines 82–115 specifically).
- IPK questionnaire: `~/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/IPK_Brand_Health_Wave_1.doc`
- IPK reconfigured data: `~/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/IPK_Data_Structure v2.xlsx`
- IPK raw Alchemer export: `~/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/export-16767014-2.xlsx`

---

*End of plan. Maintained by The Research LampPost. Update Status header as phases complete.*
