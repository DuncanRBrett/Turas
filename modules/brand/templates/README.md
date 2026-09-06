# Brand Module Templates

## What is in this folder

Two of these workbooks are generator output. Three are older files that no
generator produces. Nothing here is hand curated, so never edit a workbook
in place: change the generator, regenerate, and commit the result.

### Generator output (use these)

| File | Written by |
|---|---|
| `Brand_Config_Template.xlsx` | `generate_brand_config_template()` |
| `Survey_Structure_Brand_Config_Template.xlsx` | `generate_brand_survey_structure_template()` |

Both live in `modules/brand/R/generate_config_templates.R`. Regenerate them
from the Turas project root:

```r
source("modules/brand/R/generate_config_templates.R")
generate_brand_templates("modules/brand/templates", overwrite = TRUE)
```

`generate_brand_templates()` writes exactly these two files and no others.
It saves through `turas_saveWorkbook()`, which reconciles the worksheet
relationships openxlsx leaves dangling. Never call
`openxlsx::saveWorkbook()` on a template: Excel then offers to repair the
file and the repair strips every dropdown.

`Brand_Config_Template.xlsx` carries `Settings` (element toggles, wave,
thresholds, colours, output), `Categories` (per-category Active flag, role,
timeframes) and `DBA_Assets`.

`Survey_Structure_Brand_Config_Template.xlsx` is one data dictionary for
both the brand module and the tabs module. It carries the tabs sheets
(`Project`, `Questions`, `Options`, `Composite_Metrics`) plus the brand
sheets (`Brands`, `CEPs`, `Attributes`, `QuestionMap`, `OptionMap`,
`Channels`, `PackSizes`, `MarketingReach`, `ReachMedia`, `AudienceLens`,
`DBA_Assets`) and two reference sheets. The brand sheets are inert to tabs
and tracker.

### Files with no generator

| File | Committed by | What it is |
|---|---|---|
| `Survey_Structure_Brand_Template.xlsx` | `1c6ce548`, 2026-04-30 | A structure workbook from the IPK rebuild. Eight sheets only: `Project`, `Questions`, `Options`, `Brands`, `CEPs`, `Attributes`, `Channels`, `PackSizes`. No `MarketingReach`, `QuestionMap`, `AudienceLens` or `DBA_Assets`, so Branded Reach, Audience Lens and DBA cannot be configured from it. |
| `Brand_Config.xlsx` | `bef06608`, 2026-04-16 | A config workbook from before the IPK rebuild. Three sheets: `Settings`, `Categories`, `DBA_Assets`. |
| `Survey_Structure.xlsx` | `bef06608`, 2026-04-16 | A structure workbook from before the IPK rebuild. Seven sheets: `Project`, `Questions`, `Options`, `Brands`, `CEPs`, `Attributes`, `DBA_Assets`. |

Do not start a new project from any of the three. They are kept only
because nothing has decided to remove them. Their removal is a call for
Duncan, not for a session.

## Starting a new brand project

1. Copy `Brand_Config_Template.xlsx` and
   `Survey_Structure_Brand_Config_Template.xlsx` into your project folder,
   alongside your AlchemerParser-cleaned data file. Rename them to
   `Brand_Config.xlsx` and `Survey_Structure.xlsx` if you prefer; the
   config points at the structure by path, so the names are free.
2. Edit the config workbook:
   - In `Settings`, set the file paths, `wave`, the focal brand, the
     element toggles and `wom_timeframe`. Leave `weight_variable` blank
     for an unweighted run. If you set it, every respondent needs a
     numeric weight: a blank cell refuses the run.
   - In `Categories`, replace the example categories with your own. Set
     `Active = N` for any category out of scope for this run.
   - In `DBA_Assets`, list the assets if `element_dba = Y`.
3. Edit the structure workbook:
   - In `Project`, set `data_file_path`, `output_dir` and `expected_n`.
   - In `Questions` and `Options`, register every question in your
     parsed data, using the tabs `Variable_Type` vocabulary
     (`Multi_Mention`, `Single_Response`, `Numeric`, `Open_End` and so
     on). Roles are inferred from `QuestionCode` where the naming follows
     the conventions below.
   - In `Brands`, list every brand and category combination.
   - In `CEPs` and `Attributes`, list the per-category statements.
   - In `Channels` and `PackSizes`, list the per-category options.
   - In `MarketingReach` and `ReachMedia`, define the assets if
     `element_branded_reach = Y`.
   - In `AudienceLens`, define the cuts if `element_audience_lens = Y`.
4. Run it: `result <- run_brand("path/to/Brand_Config.xlsx")`, or pick the
   config through the GUI.

## Convention-first naming

`modules/brand/R/00_role_inference.R` walks the `Questions` sheet and
assigns each question root a semantic role by its `QuestionCode` pattern.
Elements read roles, never client question codes, so a project that
follows these patterns needs no `QuestionMap` rows at all.

| Question root pattern | Inferred role |
|---|---|
| `BRANDAWARE_{CAT}` | Awareness for category {CAT} |
| `BRANDPEN1_{CAT}` | Long-window penetration |
| `BRANDPEN2_{CAT}` | Target-window penetration |
| `BRANDPEN3_{CAT}` | Purchase frequency |
| `BRANDATT1_{CAT}_{BRAND}` | Brand attitude, per-brand single response |
| `BRANDATT2_{CAT}_{BRAND}` | Rejection open-end |
| `BRANDATTR_{CAT}_CEP{NN}` | CEP by brand mention |
| `BRANDATTR_{CAT}_ATT{NN}` | Attribute by brand mention |
| `BRANDATTR_{CAT}{NN}` | Attribute by brand mention, glued-category form |
| `WOM_{POS\|NEG}_{REC\|SHARE}_{CAT}` | WOM mention sets |
| `WOM_{POS\|NEG}_COUNT_{CAT}_{BRAND}` | WOM count per brand |
| `CATBUY_{CAT}` or `CAT_FREQ_{CAT}` | Category buying frequency |
| `CATCOUNT_{CAT}` | Category purchase count, numeric |
| `CHANNEL_{CAT}` or `CAT_LOC_{CAT}` | Channels, Multi_Mention |
| `PACK_{CAT}` | Pack sizes, Multi_Mention |
| `DEMO_{KEY}` | Demographics |
| `ADHOC_{KEY}` or `ADHOC_{KEY}_{CAT}` | Ad hoc, sample-wide or per category |

`CAT_FREQ` and `CAT_LOC` are aliases of `CATBUY` and `CHANNEL`, so a
project that names one category the IPK way and the rest the other way
still resolves without manual mapping.

Two elements are wired by sheet, not by name. DBA reads
`FameQuestionCode` and `UniqueQuestionCode` from the `DBA_Assets` sheet.
Branded Reach reads `SeenQuestionCode`, `BrandQuestionCode` and
`MediaQuestionCode` from `MarketingReach`. Name those columns whatever the
export produced and point the sheet at them.

If a project deviates from the conventions anywhere else, add a
`QuestionMap` sheet row to override the role for that question.

## Further reading

- `../docs/BRAND_CONFIG_GUIDE.md` for every Settings key and what reads it.
- `../docs/ROLE_REGISTRY.md` for the role vocabulary itself.
- `../docs/archive/2026-05/PLANNING_IPK_REBUILD.md` for the rebuild that
  introduced this schema.
- `../tests/fixtures/ipk_wave1/` for a filled-in working example.
