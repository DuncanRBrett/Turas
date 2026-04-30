# Brand Module Restructure — Development Note

**Date:** 2026-04-29
**Status:** Planning — do not start until Alchemer build is complete and real data is available

---

## Guiding principle

**Tabs and tracker modules are the established standards. Brand module adapts to them — not the other way around.**

The brand module will share the same `Survey_Structure.xlsx` format as tabs and tracker. It does not define its own question-mapping schema. Brand-specific metadata (CEPs, brand lists, attribute lists, category configuration) lives in `Brand_Config.xlsx` only.

---

## Flexibility requirements — critical

The brand module must be genuinely project-agnostic. Every structural assumption must be configurable, not hardcoded. Specifically:

### Categories
- Any number of categories (1 to N — not hardcoded to 4 or 9)
- Any category codes (not hardcoded to DSS/POS/PAS/BAK)
- Any mix of Core (full CBM) and Adjacent (awareness only) categories
- Some projects will have 1 Core + 2 Adjacent. Others will have 4 Core + 5 Adjacent. The module must handle both without code changes.

### Brands
- Any number of brands per category (not hardcoded to 10)
- Brand lists differ per category (even within the same project)
- Brand lists can change between waves (additions acceptable; removals flagged as trend-breaking)

### Questions
- Not all elements are always in scope (element toggles in Brand_Config)
- Ad hoc questions vary per project — module must handle any ADHOC_{KEY}_{CAT} or ADHOC_{KEY} columns
- CEP count varies per project (currently 10 slots but could be fewer or more)
- Attribute count varies per project (currently 10 slots but could be fewer or more)
- Channel options vary per project
- Pack size options vary per project
- WOM timeframe varies per project (configured in Brand_Config)

### Waves
- Wave tracking must follow the tracker module's conventions — not a separate brand-module implementation
- Wave column in the data (derived in prep_data.R, not a survey question)
- Wave-over-wave comparisons for all metrics where applicable
- CEPs must be stable across waves (any new CEP added in Wave 2 has no Wave 1 baseline)
- Adding brands between waves is acceptable but flagged (no Wave 1 comparison available)

---

## Config file structure (target)

### Survey_Structure.xlsx — tabs-compatible format (shared)
This file is the same format as tabs module. The brand module reads it using the tabs-compatible schema.

| Sheet | Contents | Who uses it |
|---|---|---|
| `Project` | Key-value project metadata | Tabs, brand |
| `Questions` | QuestionCode, QuestionText, Variable_Type, Columns | Tabs, brand |
| `Options` | QuestionCode, OptionText, DisplayText, ShowInOutput, DisplayOrder | Tabs, brand |

All brand questions (BRANDAWARE, BRANDATT1, BRANDATTR, BRANDPEN1/2/3, CATBUY, CATCOUNT, CHANNEL, PACKSIZE, WOM, REACH, DBA, DEMO, ADHOC) are registered here in tabs-compatible format. The brand module identifies which questions are brand-related via naming convention + Brand_Config — not via a separate schema.

### Brand_Config.xlsx — brand-module-only metadata
Everything that is genuinely brand-specific and not needed by tabs:

| Sheet | Contents |
|---|---|
| `Settings` | Element toggles, thresholds, wave number, WOM timeframe, colour palette, file paths |
| `Categories` | Category codes, roles (Core/Adjacent), Analysis_Depth, timeframes per category |
| `Brands` | Brand codes, labels, focal brand flag — per category |
| `CEPs` | CEP codes, statements — per category |
| `Attributes` | Attribute codes, statements — per category |
| `DBA_Assets` | Asset codes, labels, asset type |
| `Channels` | Channel codes, labels — per category |
| `PackSizes` | Pack size codes, labels — per category |
| `MarketingReach` | Ad/stimulus codes, labels |
| `AudienceLens` | Audience definitions (if element_audience_lens = Y) |
| `AdHoc` | Ad hoc question registration (Role, ClientCode, scope) |

---

## Key architectural changes required

### 1. WOM column naming — URGENT BLOCKER
Current: `WOM_POS_REC_{BRAND}` (no category suffix) — code uses legacy `get_questions_for_battery()` path
Required: `WOM_POS_REC_{CAT}_{BRAND}` — must migrate to role-registry / Survey_Structure.xlsx Questions approach
Fix: Register WOM questions in Survey_Structure with QuestionCode = `WOM_POS_REC_{CAT}` per category

### 2. Complete role-registry migration
Elements still on legacy `get_questions_for_battery()` path (MA, WOM, repertoire) must migrate to the tabs-compatible Questions sheet. Once complete, retire `get_questions_for_battery()` entirely.

### 3. Wave awareness
Add wave-aware comparison logic following tracker module conventions:
- Wave column in data (set in prep_data.R)
- All metrics computed per wave
- Trend functions for wave-over-wave change, significance testing
- Stable CEP/brand enforcement check (warn if CEPs or brands differ between waves)

### 4. Dynamic category/brand discovery
Remove any hardcoded category or brand assumptions from module code. All category codes, brand lists, and question patterns must be derived from Brand_Config.xlsx at runtime. The module should work correctly whether a project has 1 category or 10.

---

## Development sequence (when ready)

1. **Fix WOM column naming** (urgent — blocking first live run)
2. **Align Survey_Structure.xlsx to tabs format** — restructure Questions/Options sheets
3. **Update brand module config reader** — read from tabs-compatible schema
4. **Complete role-registry migration** — retire `get_questions_for_battery()`
5. **Add wave tracking** — follow tracker module conventions
6. **Validate against IPK real data** — use exported Alchemer data as the test case
7. **Write new synthetic data generator** — structurally identical to Alchemer export, tabs + brand compatible

---

## Reference
- Tabs module survey structure: `modules/tabs/` — do not modify, adapt brand to match
- Tracker module wave conventions: `modules/tracker/` — do not modify, adapt brand to match
- Alchemer column naming: `modules/brand/docs/ALCHEMER_PROGRAMMING_SPEC.md`
- IPK survey build: `modules/brand/docs/HANDOVER_IPK_ALCHEMER_SESSION4.md`
