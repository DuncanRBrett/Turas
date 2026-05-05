---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Brand Module — Configuration Setup Guide

**Audience:** Jess (survey programmer / project operator)\
**Goal:** Set up a complete brand report from scratch, without asking
Duncan.\
**Applies to:** Brand Module v1.0

------------------------------------------------------------------------

## Overview

Every brand report requires two Excel files:

| File | What it controls |
|----|----|
| `Brand_Config.xlsx` | Which analyses to run, study settings, colours, output paths |
| `Survey_Structure.xlsx` | The data dictionary — what questions are in the data, which brands, CEPs, and how to map everything |

Both files use **relative paths** — all paths you enter are relative to
the folder the config file lives in. This means you can put the whole
project folder on OneDrive and it will work on any machine.

### Folder structure to use

```         
MyClient_Brand/
  Brand_Config.xlsx
  Survey_Structure.xlsx
  data/
    survey_data.csv
  output/
    brand/          ← report lands here
```

------------------------------------------------------------------------

## Step 0: Generate blank templates

Run this in R once to get the blank, pre-formatted Excel templates:

``` r
source("modules/brand/R/generate_config_templates.R")
generate_brand_config_template("MyClient_Brand/Brand_Config.xlsx")
generate_brand_survey_structure_template("MyClient_Brand/Survey_Structure.xlsx")
```

This creates both files with all sheets, column headers, colour coding,
dropdown validation, and example rows. **Delete the example rows** and
fill in yours.

------------------------------------------------------------------------

## File 1: Brand_Config.xlsx

This file has three sheets: **Settings**, **Categories**, and
**DBA_Assets**.

------------------------------------------------------------------------

### Sheet 1: Settings

The Settings sheet is a two-column vertical list. Column A = setting
name, Column B = your value. **Only edit column B.** Never edit column A
(the setting names must match exactly for the code to find them).

Below is every setting, in the order they appear in the sheet.

------------------------------------------------------------------------

#### STUDY IDENTIFICATION

| Setting | Required? | What it does | Allowed values |
|----|----|----|----|
| `project_name` | **Required** | Used in report titles and output file names | Free text |
| `client_name` | **Required** | Client organisation name, shown in report header | Free text |
| `study_type` | **Required** | Controls whether respondent IDs are expected for panel tracking | `cross-sectional` or `panel` |
| `wave` | **Required** | Wave number. Wave 1 = baseline. Wave 2+ enables tracker comparisons. | Integer ≥ 1 |
| `data_file` | **Required** | Path to survey data file, relative to this config file | e.g. `data/survey_data.csv` — supports `.csv` or `.xlsx` |
| `respondent_id_col` | Optional | Column name for respondent ID. Only required when `study_type = panel`. Default: `Respondent_ID` | Column name in data |
| `weight_variable` | Optional | Column name for the weight variable. Leave blank for unweighted analysis. | Column name in data, or blank |
| `focal_brand` | **Required** | The client's brand. Controls all colour highlighting, annotations, and comparisons. Must exactly match a `BrandCode` value in the Brands sheet. | Brand code from Brands sheet |

**Tip on `focal_brand`:** This is the `BrandCode` value (short code,
e.g. `IPK`), not the display label. It must match exactly —
case-sensitive.

------------------------------------------------------------------------

#### MULTI-CATEGORY ROUTING

These settings control how respondents are assigned to a focal category
when the study covers more than one category.

| Setting | Required? | What it does | Allowed values |
|----|----|----|----|
| `focal_assignment` | **Required** | How respondents are assigned to their focal category | `balanced` (equal random split), `quota` (minimum n per category), `priority` (weighted over-sampling) |
| `focal_category_col` | Optional | Column in the data containing the pre-assigned focal category code. If blank, the module derives it from config. | Column name in data, or blank |
| `cross_category_awareness` | Optional | Whether cross-category brand awareness is included in the survey (collected for all qualifying categories, not just the focal one). Set `Y` if the Portfolio element is enabled. | `Y` or `N` |
| `cross_category_pen_light` | Optional | Whether light brand penetration is collected for non-focal categories. | `Y` or `N` |

**On `focal_assignment`:** For most studies, use `balanced`. Use
`priority` only if you've deliberately over-sampled certain categories
and added a `Focal_Weight` column to the Categories sheet (see below).

------------------------------------------------------------------------

#### ANALYTICAL ELEMENTS

These are Y/N toggles. `Y` = run this element and include it in the
report. `N` = skip.

| Setting | Default | What it controls |
|----|----|----|
| `element_funnel` | Y | Brand funnel: awareness → disposition → bought → primary. Core CBM output. |
| `element_mental_avail` | Y | Mental Availability: MMS, MPen, NS, CEP × brand matrix. The centrepiece of the report. |
| `element_cep_turf` | Y | CEP TURF reach optimisation within Mental Availability. Which CEP combination maximises mental reach? Only runs if MA is enabled. |
| `element_repertoire` | Y | Repertoire analysis: multi-brand buying, share of requirements, switching patterns, buyer heaviness. |
| `element_drivers_barriers` | Y | Drivers & Barriers: CEP importance × performance quadrant. Derived from MA data — no extra survey questions needed. |
| `element_dba` | N | Distinctive Brand Assets: Fame × Uniqueness grid. Requires a DBA battery in the survey (\~2 extra minutes). |
| `element_portfolio` | Y | Portfolio analysis: cross-category brand presence, heatmap, competitive set. Requires 2+ categories and `cross_category_awareness = Y`. |
| `element_wom` | Y | Word-of-Mouth: received/shared × positive/negative. Requires WOM battery in survey (\~2 extra minutes). |
| `element_branded_reach` | N | Branded Reach: ad recognition, misattribution, media mix. Requires a Branded Reach battery in the survey. |
| `element_demographics` | Y | Demographics: focal-brand buyer profile vs category total. Derived from demographic columns in the data. |
| `element_adhoc` | Y | Ad Hoc: custom questions appended to the HTML report as additional subtabs. Requires an AdHoc battery in the survey. |
| `element_audience_lens` | N | Audience Lens: focal-brand KPI comparisons across defined sub-populations with GROW / FIX / DEFEND classification. Requires an AudienceLens sheet in Survey_Structure.xlsx. |

------------------------------------------------------------------------

#### DRIVERS & BARRIERS OPTIONS

| Setting | Default | What it does | Allowed values |
|----|----|----|----|
| `db_use_catdriver` | Y | Whether to use the catdriver module (SHAP values) for derived importance. More rigorous than the simple differential approach. | `Y` or `N` |
| `db_importance_method` | `differential` | Importance method when catdriver is not used. `differential` = buyer vs non-buyer gap. | `differential` |

------------------------------------------------------------------------

#### DBA OPTIONS (only relevant if `element_dba = Y`)

| Setting | Default | What it does | Allowed values |
|----|----|----|----|
| `dba_scope` | `brand` | Whether DBA is measured at brand level (across all categories) or per category (rare). | `brand` or `category` |
| `dba_fame_threshold` | 0.50 | Proportion threshold for classifying an asset as Famous. Above this → Famous. | 0.00 to 1.00 |
| `dba_uniqueness_threshold` | 0.50 | Proportion threshold for classifying an asset as Unique. | 0.00 to 1.00 |
| `dba_attribution_type` | `open` | How the DBA attribution question works in the survey. `open` = open-ended text (coded post-field, recommended). `closed_list` = forced-choice brand pick (inflates uniqueness scores). | `open` or `closed_list` |

------------------------------------------------------------------------

#### WOM OPTIONS (only relevant if `element_wom = Y`)

| Setting | Default | What it does | Allowed values |
|----|----|----|----|
| `wom_timeframe` | `3 months` | WOM recall period label shown in charts. Should match the target timeframe. | Free text (e.g. `3 months`, `6 months`) |

------------------------------------------------------------------------

#### SIGNIFICANCE TESTING

| Setting | Default | What it does | Allowed values |
|----|----|----|----|
| `alpha` | 0.05 | Primary significance level for cross-brand comparisons. | 0.01 to 0.20 |
| `alpha_secondary` | *(blank)* | Optional second significance level for dual-alpha reporting (e.g. 0.10). Leave blank to disable. | 0.01 to 0.20, or blank |
| `min_base_size` | 30 | Minimum base size for displaying a cell. Cells below this are suppressed with "–". | Integer ≥ 10 |
| `low_base_warning` | 75 | Base size below which a low-base flag is shown. Per Romaniuk, n \< 75 is unreliable for per-brand metrics. | Integer ≥ 30 |

------------------------------------------------------------------------

#### COLOUR PALETTE

These control brand colours in all charts and chips. The focal brand's
primary colour should be the brand's actual primary colour.

| Setting | Default | What it does | Allowed values |
|----|----|----|----|
| `colour_focal` | `#1A5276` | Primary colour for the focal brand. Saturated. | Hex colour (e.g. `#D62728`) |
| `colour_focal_accent` | `#2E86C1` | Secondary/accent colour for focal brand secondary elements. | Hex colour |
| `colour_competitor` | `#B0B0B0` | Colour for all competitor brands. Grey by default — this is intentional (Romaniuk design principle). | Hex colour |
| `colour_category_avg` | `#808080` | Colour for category average reference lines. | Hex colour |

------------------------------------------------------------------------

#### OUTPUT OPTIONS

| Setting | Required? | What it does | Allowed values |
|----|----|----|----|
| `output_dir` | **Required** | Directory where output files are saved. Relative to the config file. Created automatically if it does not exist. | e.g. `output/brand` |
| `output_html` | Optional | Generate the self-contained HTML report. | `Y` or `N` |
| `output_excel` | Optional | Generate an Excel workbook with all element data. | `Y` or `N` |
| `output_csv` | Optional | Generate CSV files in long format per element. | `Y` or `N` |
| `tracker_ids` | Optional | Include stable metric IDs for wave-over-wave tracking. Set `Y` if this study will be tracked (even if wave 1). | `Y` or `N` |

------------------------------------------------------------------------

#### REPORT OPTIONS

| Setting | Required? | What it does | Allowed values |
|----|----|----|----|
| `report_title` | Optional | Title shown in the HTML report header. | Free text |
| `report_subtitle` | Optional | Subtitle shown under the title (e.g. `Wave 1 Baseline` or `Q1 2026`). | Free text |
| `show_about_section` | Optional | Whether to include the About & Methodology section with academic references. | `Y` or `N` |
| `structure_file` | **Required** | Path to Survey_Structure.xlsx, relative to this config file. | e.g. `Survey_Structure.xlsx` |

------------------------------------------------------------------------

#### ADVANCED SETTINGS (rarely changed)

These are not in the template by default but can be added as extra rows
to the Settings sheet if needed.

| Setting | Default | What it does |
|----|----|----|
| `target_timeframe_months` | 3 | Target analytical window in months (e.g. last 3 months). Must be less than `longer_timeframe_months`. Used in Dirichlet norms. |
| `longer_timeframe_months` | 12 | Longer penetration window in months (e.g. last 12 months). Must be greater than `target_timeframe_months`. |
| `portfolio_timeframe` | `3m` | Which screener column to use as the portfolio denominator. `3m` uses `SQ2_{cat_code}` columns; `13m` uses `SQ1_{cat_code}` columns. |
| `focal_home_category` | *(blank)* | Category code for the focal brand's primary category (used in Portfolio Extension analysis). |
| `funnel_conversion_metric` | `ratio` | How funnel conversion rates are calculated. |
| `funnel_warn_base` | 75 | Funnel base-size warning threshold. |
| `funnel_suppress_base` | 0 | Funnel base-size suppression threshold (0 = never suppress). |
| `decimal_places` | 0 | Decimal places in report output. |

------------------------------------------------------------------------

### Sheet 2: Categories

One row per category in the study. The order here controls the order in
the report.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `Category` | **Required** | Category name as it appears in the data and report. Must match what's used in Survey_Structure.xlsx. | Free text (e.g. `Dry Seasonings & Spices`) |
| `Type` | **Required** | Category type. Controls question wording, funnel structure, and penetration data handling. | `transactional` (FMCG), `durable` (electronics, cars), `service` (banking, telecoms) |
| `Timeframe_Long` | **Required** | Longer penetration window label for reports (e.g. `12 months`). Matches `longer_timeframe_months` in Settings. | Free text |
| `Timeframe_Target` | **Required** | Target analytical period label (e.g. `3 months`). Matches `target_timeframe_months`. Shown on charts. | Free text |
| `Focal_Weight` | Optional | Required only when `focal_assignment = priority`. How much to over-sample this category. Must sum to 1.0 across all categories. | 0.00 to 1.00 |
| `Analysis_Depth` | Optional | Whether this category gets full CBM analysis or just cross-category awareness only. If the column is absent, all categories default to `full`. | `full` or `awareness_only` |

**On `Analysis_Depth`:** Use `awareness_only` for categories where you
want to show cross-category brand presence on the Portfolio tab, but
where you haven't run the full CBM battery (funnel, CEPs, attitude). For
example, if the client is in 5 categories but you only surveyed the full
battery for 3 of them — set the other 2 as `awareness_only`. The column
does not exist in the template by default; add it manually.

------------------------------------------------------------------------

### Sheet 3: DBA_Assets (only needed if `element_dba = Y`)

One row per distinctive brand asset you're testing.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `AssetCode` | **Required** | Unique short code for this asset. Used in data column names. | Short uppercase code (e.g. `LOGO`, `COLOUR`, `TAGLINE`) |
| `AssetLabel` | **Required** | Display label for charts and tables. | Free text (e.g. `Brand Logo`) |
| `AssetType` | **Required** | What type of stimulus was shown to respondents. | `image`, `text`, or `audio` |
| `FilePath` | Optional | Path to the asset file (image or audio). Relative to project root. Leave blank for text assets. | Relative path (e.g. `assets/logo.png`) |

------------------------------------------------------------------------

## File 2: Survey_Structure.xlsx

This is the data dictionary. It tells the module what questions are in
the survey, how they're named in the data, which brands and CEPs exist
per category, and how to interpret coded responses.

It has up to nine sheets. The most critical are **QuestionMap** and
**Brands**.

------------------------------------------------------------------------

### Sheet 1: Project

A short key–value settings sheet (same format as Brand_Config Settings).
Values must match Brand_Config.xlsx exactly.

| Setting        | Required?    | What it contains                           |
|----------------|--------------|--------------------------------------------|
| `project_name` | **Required** | Must match `project_name` in Brand_Config. |
| `data_file`    | **Required** | Must match `data_file` in Brand_Config.    |
| `client_name`  | **Required** | Must match `client_name` in Brand_Config.  |
| `focal_brand`  | **Required** | Must match `focal_brand` in Brand_Config.  |

------------------------------------------------------------------------

### Sheet 2: Questions

Maps every survey question to its CBM battery and category. This is the
**legacy question map** — still used for MA (mental availability) column
matching but not for the funnel element (which uses the QuestionMap
sheet instead).

One row per question or question block. If a question has one column per
brand (e.g. an awareness grid), one row here covers all brand columns.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `QuestionCode` | **Required** | The column name prefix in the data file. For per-brand questions, this is the prefix — columns in data will be `{QuestionCode}_{BrandCode}`. | e.g. `BRANDAWARE_DSS` |
| `QuestionText` | **Required** | Full question wording, for reference and report labelling. | Free text |
| `VariableType` | **Required** | Data type — how responses are coded. | `Multi_Mention`, `Single_Mention`, `Rating`, `Open_End`, `Numeric` |
| `Battery` | **Required** | Which CBM battery this question belongs to. | `awareness`, `cep_matrix`, `attribute`, `attitude`, `attitude_oe`, `cat_buying`, `penetration`, `wom`, `dba` |
| `Category` | **Required** | Which category this question applies to. For brand-level questions (WOM, DBA) that apply to all categories, use `ALL`. | Category name (must match Categories sheet), or `ALL` |

**Column naming convention in Alchemer:** For per-brand questions,
Alchemer exports one column per brand. The naming pattern is
`{QuestionCode}_{BrandCode}`. So if `QuestionCode` is `BRANDAWARE_DSS`
and brands are `IPK`, `ROB`, `KNO`, the data will have columns
`BRANDAWARE_DSS_IPK`, `BRANDAWARE_DSS_ROB`, `BRANDAWARE_DSS_KNO`.

**Example rows:**

| QuestionCode | QuestionText | VariableType | Battery | Category |
|----|----|----|----|----|
| `BRANDAWARE_DSS` | Which brands have you heard of in the dry seasonings category? | Multi_Mention | awareness | Dry Seasonings & Spices |
| `BRANDATTR_DSS_01` | Good for a quick weeknight meal | Multi_Mention | cep_matrix | Dry Seasonings & Spices |
| `BRANDATT1_DSS` | How would you describe your feelings towards this brand? | Single_Mention | attitude | Dry Seasonings & Spices |
| `BRANDPEN1_DSS` | Which have you bought in the last 12 months? | Multi_Mention | penetration | Dry Seasonings & Spices |
| `WOM_POS_REC` | Have you received positive recommendations about any of these brands? | Multi_Mention | wom | ALL |

------------------------------------------------------------------------

### Sheet 3: Options

Maps coded values to display labels for single-mention questions. You
need this for the attitude question at minimum.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `QuestionCode` | **Required** | Must match a `QuestionCode` in the Questions sheet. | Existing question code |
| `OptionText` | **Required** | The coded value in the data (what Alchemer exports — typically an integer). | e.g. `1`, `2`, `3` |
| `DisplayText` | **Required** | The human-readable label to show in output. | Free text |
| `DisplayOrder` | **Required** | Sort order for display (1 = first shown). | Integer |
| `ShowInOutput` | Optional | Whether to include this response in output. Use `N` for "Not applicable" or "Prefer not to say" options you want to exclude from analysis. Default `Y`. | `Y` or `N` |

**Example — Attitude question (BRANDATT1_DSS):**

| QuestionCode | OptionText | DisplayText | DisplayOrder | ShowInOutput |
|----|----|----|----|----|
| BRANDATT1_DSS | 1 | I love it / it's my favourite | 1 | Y |
| BRANDATT1_DSS | 2 | It's among the ones I prefer | 2 | Y |
| BRANDATT1_DSS | 3 | I wouldn't usually consider it, but I would if there's no other option | 3 | Y |
| BRANDATT1_DSS | 4 | I would refuse to buy this brand | 4 | Y |
| BRANDATT1_DSS | 5 | I have no opinion about this brand | 5 | Y |

------------------------------------------------------------------------

### Sheet 4: Brands

One row per brand per category. If the same brand appears in multiple
categories (common for the focal brand), it gets a row for each.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `Category` | **Required** | Category this brand appears in. Must exactly match the `Category` in Brand_Config Categories sheet. | Category name |
| `BrandCode` | **Required** | Short unique code for this brand. Must match the column suffix in the data (e.g. `IPK` → columns named `BRANDAWARE_DSS_IPK`). | Short uppercase code |
| `BrandLabel` | **Required** | Display name shown in charts, tables, and the report. | Free text (e.g. `Robertsons`) |
| `DisplayOrder` | **Required** | Sort order within the category in charts. Lower number = shown first. | Integer |
| `IsFocal` | **Required** | Whether this is the focal (client) brand for this category. Exactly one row per category must be `Y`. | `Y` or `N` |
| `Colour` | Optional | Hex colour for this brand in charts and chips. If blank, the focal brand uses `colour_focal` from Settings, competitors use `colour_competitor`. Set a custom colour here to override the default for specific brands. | Hex code (e.g. `#D62728`) or blank |

**Example:**

| Category                | BrandCode | BrandLabel   | DisplayOrder | IsFocal | Colour  |
|-------------------------|-----------|--------------|--------------|---------|---------|
| Dry Seasonings & Spices | IPK       | IPK          | 1            | Y       | #1A5276 |
| Dry Seasonings & Spices | ROB       | Robertsons   | 2            | N       |         |
| Dry Seasonings & Spices | KNO       | Knorr        | 3            | N       |         |
| Ready Meals             | IPK       | IPK          | 1            | Y       | #1A5276 |
| Ready Meals             | COMPA     | Competitor A | 2            | N       |         |

------------------------------------------------------------------------

### Sheet 5: CEPs

Category Entry Points — the situation-based cues used in the CEP × brand
matrix (Mental Availability). One row per CEP per category.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `Category` | **Required** | Category this CEP applies to. | Category name |
| `CEPCode` | **Required** | Short unique code within the category (e.g. `CEP01`). Must match how CEPs are referenced in the data column names. | Short code (e.g. `CEP01`, `CEP02`) |
| `CEPText` | **Required** | Full CEP statement text — what was shown to respondents. Should be simple, concrete, situation-based (Romaniuk). | Free text |
| `DisplayOrder` | **Required** | Sort order in MA outputs. | Integer |

**Example:**

| Category | CEPCode | CEPText | DisplayOrder |
|----|----|----|----|
| Dry Seasonings & Spices | CEP01 | Good for a quick weeknight meal | 1 |
| Dry Seasonings & Spices | CEP02 | Something the whole family enjoys | 2 |
| Dry Seasonings & Spices | CEP03 | When I want a healthy option | 3 |

**How many CEPs?** 10–15 per category is the Romaniuk recommendation.
Fewer than 8 makes TURF analysis meaningless.

------------------------------------------------------------------------

### Sheet 6: Attributes

Non-CEP brand image attributes — perception items measured with the same
grid structure as CEPs but used in the Drivers & Barriers analysis
rather than Mental Availability. Optional but recommended.

| Column | Required? | What it contains | Allowed values |
|----|----|----|----|
| `Category` | **Required** | Category this attribute applies to. | Category name |
| `AttrCode` | **Required** | Short unique code within the category (e.g. `ATTR01`). | Short code |
| `AttrText` | **Required** | Full attribute statement text. These are perception items, not entry points. | Free text |
| `DisplayOrder` | **Required** | Sort order in D&B output. | Integer |

**Example:**

| Category                | AttrCode | AttrText                 | DisplayOrder |
|-------------------------|----------|--------------------------|--------------|
| Dry Seasonings & Spices | ATTR01   | Good value for money     | 1            |
| Dry Seasonings & Spices | ATTR02   | High quality ingredients | 2            |
| Dry Seasonings & Spices | ATTR03   | A brand I trust          | 3            |

------------------------------------------------------------------------

### Sheet 7: DBA_Assets (only needed if `element_dba = Y`)

Maps asset codes to the question codes in the data. Unlike the
DBA_Assets sheet in Brand_Config.xlsx (which lists which assets exist),
this sheet tells the module which data columns contain the fame and
uniqueness scores for each asset.

| Column | Required? | What it contains |
|----|----|----|
| `AssetCode` | **Required** | Must match `AssetCode` in Brand_Config DBA_Assets sheet. |
| `AssetLabel` | **Required** | Display label for charts. |
| `AssetType` | **Required** | `image`, `text`, or `audio`. |
| `FameQuestionCode` | **Required** | Column name in data for the fame (recognition) question for this asset. |
| `UniqueQuestionCode` | **Required** | Column name in data for the uniqueness (attribution) question for this asset. |

------------------------------------------------------------------------

### Sheet 8: QuestionMap ⚠️ Critical

**This is the most important sheet to get right.** The QuestionMap tells
the module exactly which data columns contain each analytical role.
Without it, the funnel element and portfolio element cannot run.

**One row per role per category.** For multi-category studies, funnel
roles use a category suffix (e.g. `funnel.awareness.DSS`) so the module
knows which columns belong to which category.

| Column | Required? | What it contains |
|----|----|----|
| `Role` | **Required** | The internal role name from the role registry (see table below). |
| `ClientCode` | **Required** | The column name prefix in your data (what Alchemer exported). For per-brand questions, this is the prefix — the module appends `_{BrandCode}` to find each brand's column. |
| `QuestionText` | Optional | Full question wording. Used in charts and the About section. |
| `QuestionTextShort` | Optional | Shortened label for tight UI elements (chips, axis labels). |
| `Variable_Type` | **Required** | Data type for this question. |
| `ColumnPattern` | Optional | Column naming template (e.g. `{code}_{brandcode}`). Leave blank for the default pattern. |
| `OptionMapScale` | Optional | Name of the OptionMap scale to use for coded responses. Required for the attitude question. |
| `Notes` | Optional | Internal notes (not shown in report). |

#### Role names to use

The table below covers all roles you will typically need to fill in. Use
these exact role names in the `Role` column.

**For multi-category studies:** append `.{CAT_CODE}` to funnel roles
(e.g. `funnel.awareness.DSS`). For single-category studies, omit the
suffix (e.g. `funnel.awareness`). `CAT_CODE` is the short category code
— typically a 2–4 letter uppercase code that matches what you used in
Alchemer (e.g. `DSS` for Dry Seasonings & Spices).

------------------------------------------------------------------------

##### Funnel roles (one set per category)

| Role | Variable_Type | What data column it maps to |
|----|----|----|
| `funnel.awareness.{CAT}` | Multi_Mention | Awareness grid prefix (e.g. `BRANDAWARE_DSS`) → data has `BRANDAWARE_DSS_IPK`, `BRANDAWARE_DSS_ROB`, etc. |
| `funnel.attitude.{CAT}` | Single_Response | Brand attitude question prefix (e.g. `BRANDATT1_DSS`) → data has `BRANDATT1_DSS_IPK`, etc. Set `OptionMapScale = attitude_scale`. |
| `funnel.rejection_oe.{CAT}` | Open_End | Rejection open-end prefix (e.g. `BRANDATT2_DSS`). Optional. |
| `funnel.transactional.bought_long.{CAT}` | Multi_Mention | Long-window penetration prefix (e.g. `BRANDPEN1_DSS`). For `Type = transactional` only. |
| `funnel.transactional.bought_target.{CAT}` | Multi_Mention | Target-window penetration prefix (e.g. `BRANDPEN2_DSS`). For `Type = transactional` only. |
| `funnel.transactional.frequency.{CAT}` | Numeric | Purchase frequency prefix (e.g. `BRANDPEN3_DSS`). For `Type = transactional` only. Optional. |
| `funnel.durable.current_owner.{CAT}` | Single_Response | Current ownership question (e.g. `BRANDPENDUR1_DSS`). For `Type = durable`. One brand code per respondent. |
| `funnel.durable.tenure.{CAT}` | Single_Response | Ownership tenure (e.g. `BRANDPENDUR2_DSS`). For `Type = durable`. Optional. |
| `funnel.service.current_customer.{CAT}` | Single_Response | Current provider (e.g. `BRANDPENSERV1_DSS`). For `Type = service`. |
| `funnel.service.tenure.{CAT}` | Single_Response | Customer tenure (e.g. `BRANDPENSERV2_DSS`). For `Type = service`. Optional. |

##### Category buying role (one per category)

| Role | Variable_Type | What data column it maps to |
|----|----|----|
| `cat_buying.frequency.{CAT}` | Single_Response | Category-level buying frequency question (e.g. `CATBUY_DSS`). Maps to a scale in OptionMap — see OptionMap section below. |

##### Portfolio roles (one per category)

| Role | Variable_Type | What data column it maps to |
|----|----|----|
| `portfolio.screener.3m.{CAT}` | Single_Response | 3-month category buyer screener (e.g. `SQ2_DSS`). Used when `portfolio_timeframe = 3m`. |
| `portfolio.screener.13m.{CAT}` | Single_Response | 13-month category buyer screener (e.g. `SQ1_DSS`). Used when `portfolio_timeframe = 13m`. |
| `portfolio.cross_cat_awareness.{CAT}` | Multi_Mention | Cross-category awareness prefix (e.g. `BRANDAWARE_DSS`). Columns follow `BRANDAWARE_{CAT}_{BRAND}` pattern. |

##### WOM roles (brand-level, no category suffix)

| Role | Variable_Type | What data column it maps to |
|----|----|----|
| `wom.received_positive` | Multi_Mention | Received positive WOM prefix (e.g. `WOM_POS_REC`) |
| `wom.received_negative` | Multi_Mention | Received negative WOM prefix (e.g. `WOM_NEG_REC`) |
| `wom.shared_positive_incidence` | Multi_Mention | Shared positive WOM prefix (e.g. `WOM_POS_SHARE`) |
| `wom.shared_positive_count` | Numeric | Positive WOM frequency count prefix. Optional. |
| `wom.shared_negative_incidence` | Multi_Mention | Shared negative WOM prefix (e.g. `WOM_NEG_SHARE`) |
| `wom.shared_negative_count` | Numeric | Negative WOM frequency count prefix. Optional. |

#### Example QuestionMap rows (multi-category study, DSS + RM categories)

| Role | ClientCode | QuestionText | Variable_Type | OptionMapScale |
|----|----|----|----|----|
| `funnel.awareness.DSS` | `BRANDAWARE_DSS` | Which brands have you heard of in dry seasonings? | Multi_Mention |  |
| `funnel.attitude.DSS` | `BRANDATT1_DSS` | How would you describe your feelings towards each brand? | Single_Response | attitude_scale |
| `funnel.transactional.bought_long.DSS` | `BRANDPEN1_DSS` | Which have you bought in the last 12 months? | Multi_Mention |  |
| `funnel.transactional.bought_target.DSS` | `BRANDPEN2_DSS` | Which have you bought in the last 3 months? | Multi_Mention |  |
| `funnel.transactional.frequency.DSS` | `BRANDPEN3_DSS` | How often did you buy each brand in the last 3 months? | Numeric |  |
| `cat_buying.frequency.DSS` | `CATBUY_DSS` | How often do you buy dry seasonings in a typical month? | Single_Response | cat_buy_scale |
| `portfolio.screener.3m.DSS` | `SQ2_DSS` | Have you bought dry seasonings in the last 3 months? | Single_Response |  |
| `portfolio.cross_cat_awareness.DSS` | `BRANDAWARE_DSS` | Which dry seasonings brands are you aware of? | Multi_Mention |  |
| `funnel.awareness.RM` | `BRANDAWARE_RM` | Which brands have you heard of in ready meals? | Multi_Mention |  |
| `funnel.attitude.RM` | `BRANDATT1_RM` | How would you describe your feelings towards each brand? | Single_Response | attitude_scale |
| `wom.received_positive` | `WOM_POS_REC` | Have you heard anyone recommending any of these brands? | Multi_Mention |  |
| `wom.received_negative` | `WOM_NEG_REC` | Have you heard anyone saying negative things about these brands? | Multi_Mention |  |
| `wom.shared_positive_incidence` | `WOM_POS_SHARE` | Have you recommended any of these brands to others? | Multi_Mention |  |
| `wom.shared_negative_incidence` | `WOM_NEG_SHARE` | Have you said negative things about any of these brands? | Multi_Mention |  |

------------------------------------------------------------------------

### Sheet 9: OptionMap

Maps coded response values to analytical role positions for questions
that use codes (single-mention, rating, Likert). You need at minimum one
scale for the attitude question and one for each category buying
frequency question.

**One row per (scale × code) combination.**

| Column | Required? | What it contains |
|----|----|----|
| `Scale` | **Required** | Scale name. Must match the `OptionMapScale` value in QuestionMap. |
| `ClientCode` | **Required** | The numeric or string code as it appears in the data (e.g. `1`, `2`, `3`). |
| `Role` | **Required** | The attitude position sub-role this code maps to (see table below). Leave blank for non-analytic codes (e.g. "Don't know"). |
| `ClientLabel` | **Required** | The label from the questionnaire — shown in the report legend. |
| `OrderIndex` | **Required** | Display order (1 = shown first). |

#### Attitude scale (`attitude_scale`)

| Scale | ClientCode | Role | ClientLabel | OrderIndex |
|----|----|----|----|----|
| attitude_scale | 1 | attitude.love | I love it / it's my favourite | 1 |
| attitude_scale | 2 | attitude.prefer | It's among the ones I prefer | 2 |
| attitude_scale | 3 | attitude.ambivalent | I would buy it if no other option | 3 |
| attitude_scale | 4 | attitude.reject | I would refuse to buy this brand | 4 |
| attitude_scale | 5 | attitude.no_opinion | I have no opinion about this brand | 5 |

**Note:** The codes above (1–5) are defaults. If Alchemer exported
different codes for these positions, change the `ClientCode` values to
match. The `Role` values must remain exactly as shown.

#### Category buying frequency scale (`cat_buy_scale`)

Define a scale for each category buying frequency question. The `Role`
values for frequency responses don't map to named position roles — leave
`Role` blank and use the `OrderIndex` and `ClientLabel` to control
display order and labels.

| Scale         | ClientCode | Role | ClientLabel         | OrderIndex |
|---------------|------------|------|---------------------|------------|
| cat_buy_scale | 1          |      | Once a week or more | 1          |
| cat_buy_scale | 2          |      | 2–3 times a month   | 2          |
| cat_buy_scale | 3          |      | About once a month  | 3          |
| cat_buy_scale | 4          |      | Less often          | 4          |

------------------------------------------------------------------------

## Data file requirements

The data file (`.csv` or `.xlsx`) must follow these conventions:

-   **One row per respondent.** No multi-row formats.
-   **Per-brand columns:** naming convention is
    `{QuestionCode}_{BrandCode}`. Values are `1` (yes/mentioned), `0`
    (no), or `NA` (not shown). Examples:
    -   `BRANDAWARE_DSS_IPK` = 1 if respondent is aware of IPK in dry
        seasonings
    -   `BRANDPEN2_DSS_ROB` = 1 if respondent bought Robertsons in last
        3 months
-   **Per-category screener columns:** `SQ1_{CAT}` and `SQ2_{CAT}` are
    0/1 flags for whether the respondent qualifies for a category.
-   **Cross-category awareness:** `BRANDAWARE_{CAT}_{BRAND}` — same
    naming convention as funnel awareness.
-   **Focal category column:** if `focal_category_col` is set, this
    column contains the category code (e.g. `DSS`, `RM`) for each
    respondent's assigned focal category.
-   **Weight column:** if `weight_variable` is set, this column contains
    the post-stratification weight.

------------------------------------------------------------------------

## Step-by-step setup for a new project

### Step 1: Set up the project folder

Create a folder with the structure shown at the top. Copy or generate
the two template Excel files into it.

### Step 2: Fill in Brand_Config.xlsx — Settings sheet

Work through every required setting (marked **Required** in the tables
above): 1. `project_name`, `client_name`, `study_type`, `wave` 2.
`data_file` (relative path from the config folder to the data file) 3.
`structure_file` (usually just `Survey_Structure.xlsx` if it's in the
same folder) 4. `focal_brand` (the BrandCode of the client's brand —
you'll define this in Survey_Structure) 5. `output_dir` (e.g.
`output/brand`) 6. Element toggles: set any you don't need to `N` (e.g.
`element_dba = N` if no DBA battery) 7. Colour palette: set
`colour_focal` to the client's primary brand colour (hex code)

### Step 3: Fill in Brand_Config.xlsx — Categories sheet

Delete the example rows. Add one row per category: - `Category`: the
display name (this is what appears in the report tabs) - `Type`:
`transactional`, `durable`, or `service` - `Timeframe_Long` and
`Timeframe_Target`: the labels for the two penetration windows - If
needed: `Analysis_Depth` column — add it and set `awareness_only` for
any categories that only have cross-category awareness data

### Step 4: Fill in Survey_Structure.xlsx — Brands sheet

Delete the example rows. Add one row per brand per category: - Every
brand that appears in any question must be here - `BrandCode` must match
the column suffix Alchemer used in the export - Set `IsFocal = Y` for
the client's brand in each category (exactly one per category) -
`Colour`: set for the focal brand, leave blank for competitors

### Step 5: Fill in Survey_Structure.xlsx — CEPs sheet

Add one row per CEP per category. The `CEPCode` values must match how
CEPs are referenced in the data column names.

### Step 6: Fill in Survey_Structure.xlsx — Attributes sheet (optional but recommended)

Add brand image attributes — these feed the Drivers & Barriers analysis.

### Step 7: Fill in Survey_Structure.xlsx — QuestionMap sheet

This is the critical step. For each role you need: 1. Find the
corresponding data column prefix in the Alchemer export 2. Add a row:
`Role` = role name from the table above, `ClientCode` = your data prefix
3. For the attitude question, set `OptionMapScale = attitude_scale` 4.
For category buying frequency, set `OptionMapScale = cat_buy_scale` (or
whatever you name your scale)

Work through the role table systematically. For a typical transactional
multi-category study you'll have: - One `funnel.awareness.{CAT}` row per
category - One `funnel.attitude.{CAT}` row per category - One
`funnel.transactional.bought_long.{CAT}` row per category - One
`funnel.transactional.bought_target.{CAT}` row per category - One
`funnel.transactional.frequency.{CAT}` row per category (optional) - One
`cat_buying.frequency.{CAT}` row per category - One
`portfolio.screener.3m.{CAT}` row per category (if portfolio enabled) -
One `portfolio.cross_cat_awareness.{CAT}` row per category (if portfolio
enabled) - WOM roles once (no category suffix)

### Step 8: Fill in Survey_Structure.xlsx — OptionMap sheet

Add the attitude scale rows (see example above). Add a category buying
frequency scale if you have that question.

### Step 9: Fill in Survey_Structure.xlsx — Questions and Options sheets

These are used by the MA matrix column matching. Add rows for: - The CEP
× brand matrix question (Battery = `cep_matrix`) - The awareness
question (Battery = `awareness`) - The attitude question (Battery =
`attitude`) — and its options

### Step 10: Run the analysis

``` r
source("modules/brand/R/00_main.R")
result <- run_brand("MyClient_Brand/Brand_Config.xlsx")
```

Watch the console for step-by-step progress and any error messages. If
anything is misconfigured, the error message will tell you exactly which
setting or column is wrong.

------------------------------------------------------------------------

## Common errors and what they mean

| Error code | What it means | How to fix it |
|----|----|----|
| `CFG_MISSING_FIELD` | A required setting in Brand_Config Settings is blank | Fill in the setting named in the error message |
| `CFG_FOCAL_BRAND_NOT_FOUND` | `focal_brand` in Settings doesn't match any `BrandCode` in Brands sheet | Check capitalisation and spelling — these must match exactly |
| `CFG_QUESTIONMAP_MISSING` | The QuestionMap sheet is empty or missing from Survey_Structure.xlsx | Fill in the QuestionMap sheet (Step 7 above) |
| `CFG_ROLE_MISSING` | A required role (e.g. `funnel.awareness.DSS`) has no QuestionMap row | Add the missing role row to QuestionMap |
| `DATA_PORTFOLIO_NO_AWARENESS_COLS` | No `BRANDAWARE_*` columns found in data but portfolio is enabled | Check column naming in data matches `BRANDAWARE_{CAT}_{BRAND}` pattern |
| `DATA_PORTFOLIO_TIMEFRAME_MISSING` | No `SQ2_*` (or `SQ1_*`) columns found | Add screener columns to data, or change `portfolio_timeframe` setting |
| `IO_CONFIG_NOT_FOUND` | `Brand_Config.xlsx` not found at the path given to `run_brand()` | Check the file path argument |
| `IO_DATA_LOAD_FAILED` | Data file cannot be read | Check `data_file` path, and that the file is a valid `.csv` or `.xlsx` |
| `CFG_NO_CATEGORIES` | Categories sheet is empty | Add category rows to Brand_Config Categories sheet |
| `CFG_INVALID_CATEGORY_TYPE` | A Type value in Categories sheet is not valid | Change to `transactional`, `durable`, or `service` |
| `CFG_PORTFOLIO_MIN_CATS` | Portfolio is enabled but only 1 category is defined | Add more categories, or set `element_portfolio = N` |
| `CFG_TIMEFRAME_INVALID` | `target_timeframe_months` ≥ `longer_timeframe_months` | Ensure target (e.g. 3) is less than longer (e.g. 12) |

------------------------------------------------------------------------

## Checklist before handing off to Duncan

-   [ ] Both Excel files exist and are named correctly
-   [ ] `data_file` path is correct and file opens cleanly in Excel
-   [ ] All required Settings fields filled in
-   [ ] Categories sheet has all categories with correct Type and
    timeframe labels
-   [ ] Brands sheet has all brands for all categories; focal brand has
    `IsFocal = Y` (exactly one per category)
-   [ ] CEPs sheet has 10–15 CEPs per full-analysis category
-   [ ] QuestionMap sheet has a row for every role the study uses
-   [ ] OptionMap sheet has the attitude scale rows
-   [ ] `run_brand()` runs to completion without REFUSED errors in the
    console
-   [ ] Console shows "Brand analysis complete: PASS" or "PARTIAL"
    (PARTIAL is acceptable if some optional elements have warnings)
