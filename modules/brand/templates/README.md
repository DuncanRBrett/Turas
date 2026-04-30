# Brand Module Templates

## Active templates (post-rebuild)

These reflect the new schema introduced in the IPK rebuild
(see [docs/PLANNING_IPK_REBUILD.md](../docs/PLANNING_IPK_REBUILD.md)).
They are exact copies of the IPK Wave 1 fixture configs.

- `Survey_Structure_Brand_Template.xlsx` — tabs-format `Project` /
  `Questions` / `Options` sheets plus brand-extension sheets
  (`Brands`, `CEPs`, `Attributes`, `Channels`, `PackSizes`).
  Same schema tabs and tracker modules use; brand sheets are inert
  to those modules.
- `Brand_Config_Template.xlsx` — `Settings` (element toggles, wave,
  thresholds), `Categories` (per-category Active flag, role,
  timeframes), `AdHoc`, `AudienceLens`.

## Starting a new brand project

1. Copy these two files into your project folder, alongside your
   AlchemerParser-cleaned data file.
2. Edit `Brand_Config_Template.xlsx`:
   - In `Settings`, set `wave`, element toggles, `wom_timeframe`.
   - In `Categories`, replace IPK categories with your project's
     categories. Set `Active = N` for any category not in scope for
     this report run; `Active = Y` only for those you want reported.
3. Edit `Survey_Structure_Brand_Template.xlsx`:
   - In `Project`, set `data_file_path`, `output_dir`, `expected_n`.
   - In `Brands`, list every brand × category combination.
   - In `CEPs` / `Attributes`, list per-category statements.
   - In `Channels` / `PackSizes`, list per-category options.
   - In `Questions` / `Options`, register each question your
     Alchemer-parsed data contains using tabs Variable_Type
     vocabulary (`Multi_Mention`, `Single_Response`, `Numeric`,
     `Open_End`, etc.) — convention-first roles will be inferred
     from `QuestionCode` patterns described in the planning doc.

## Convention-first naming (required for auto-role-inference)

| Question root pattern | Inferred role |
|---|---|
| `BRANDAWARE_{CAT}` | Awareness for category {CAT} |
| `BRANDPEN1_{CAT}` | 12-month penetration |
| `BRANDPEN2_{CAT}` | Target-window penetration |
| `BRANDPEN3_{CAT}` | Purchase frequency (continuous sum) |
| `BRANDATT1_{CAT}_{BRAND}` | Brand attitude (per-brand radio) |
| `BRANDATT2_{CAT}_{BRAND}` | Rejection open-end |
| `BRANDATTR_{CAT}_CEP{NN}` | CEP × brand mention |
| `BRANDATTR_{CAT}_ATT{NN}` | Attribute × brand mention |
| `WOM_POS_REC_{CAT}` / `WOM_POS_SHARE_{CAT}` / etc. | WOM mentions |
| `WOM_POS_COUNT_{CAT}_{BRAND}` | WOM count per brand |
| `CATBUY_{CAT}` | Category buying frequency |
| `CATCOUNT_{CAT}` | Category count (numeric) |
| `CHANNEL_{CAT}` | Channels Multi_Mention |
| `PACK_{CAT}` | Pack sizes Multi_Mention |
| `DBA_FAME_{ASSET}` / `DBA_UNIQUE_{ASSET}` | DBA |
| `REACH_{TYPE}_{ADCODE}` | Branded reach |
| `DEMO_{KEY}` | Demographics |
| `ADHOC_{KEY}` / `ADHOC_{KEY}_{CAT}` | Ad hoc |

If a project deviates from convention, add a `QuestionMap` sheet to
`Survey_Structure` to override per role.

## Working examples

- IPK Wave 1 fixture (full-content example):
  `../tests/fixtures/ipk_wave1/`

## Legacy templates (pre-rebuild)

`Brand_Config.xlsx` and `Survey_Structure.xlsx` are the old-format
templates. They will be deleted at the rebuild cutover. Do not use
them for new projects — they reference the column-per-brand format
that the new module no longer reads.
