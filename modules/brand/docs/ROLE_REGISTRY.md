# Brand Module — Role Registry

**Version:** 1.0 (draft) **Applies to:** `modules/brand/` and `modules/portfolio/` **Status:** Draft for review — nothing implemented against it yet.

------------------------------------------------------------------------

## 1. Purpose

Analytical elements read data by **semantic role**, not by client-specific question codes. This decouples the module from any particular survey's column naming and lets the same code run against IPK, tracker re-runs, and future studies without change.

Roles are **internal**. They never appear in the user-facing report. The report displays the client's `QuestionText` and `ClientLabel` from `Survey_Structure.xlsx`.

------------------------------------------------------------------------

## 2. Conventions

### 2.1 Naming

-   Namespaced dot-separated lower-case: `funnel.awareness`, `ma.cep_matrix`, `wom.received_positive`.
-   Sub-namespaces for category-type variants: `funnel.transactional.bought_long`, `funnel.durable.current_owner`.
-   Ordinal suffixes for repeated stimuli: `dba.asset.01`, `dba.asset.02`.

### 2.2 Required vs Optional

| Level | Meaning | On missing |
|----|----|----|
| **Required** | Element cannot run without this role | Guard refuses with `CFG_ROLE_MISSING` + actionable message + console box |
| **Optional** | Role extends functionality; element degrades gracefully without it | Affected view collapses, rest of element renders; About note lists what's unavailable and why |

### 2.3 Variable Types (catalogue)

The brand module reuses the `Variable_Type` vocabulary already defined in the tabs module (see `modules/tabs/lib/validation/structure_validators.R`). One shared catalogue across Turas — no parallel type system.

| Type | Description | Example |
|----|----|----|
| `Single_Response` | Single-select question. Integer or string codes. Ordinal vs nominal is expressed in OptionMap (via `OrderIndex`), **not** in the type. | QBRANDATT1 codes 1–5 per brand; BRANDPENDUR1 brand owned |
| `Multi_Mention` | Multi-select, one column per option, values 0/1/NA. Matrix / grid data is declared as Multi_Mention with a compound ColumnPattern until native grid support lands. | BRANDAWARENESS per brand; Q1BRANDATTRIBUTE CEP × brand |
| `Rating` | Numeric rating scale | Performance score |
| `Likert` | Ordered agreement/preference scale (ordering via OptionMap) | Agreement statement |
| `NPS` | 0–10 recommend scale | NPS question |
| `Ranking` | Forced rank across options | Preference ordering |
| `Numeric` | Free-entry number (counts, amounts) | BRANDPENTRANS3 frequency |
| `Open_End` | Free-text response | QBRANDATT2 rejection reason |

**Ordinal vs nominal:** tabs does not split `Single_Response` into ordinal and nominal. Ordering semantics live in the OptionMap's `OrderIndex` column and in the role's declared position sub-roles (see §4.2 for the attitude scale example). Same approach here — keeps the Variable_Type vocabulary tight and pushes semantics to the map where they belong.

**Grid types (`Grid_Single`, `Grid_Multi`):** present in the tabs validator whitelist but not yet processed. Brand does not consume them today. See [modules/tabs/docs/GRID_SUPPORT_SPEC.md](../../tabs/docs/GRID_SUPPORT_SPEC.md) for the deferred development spec. Until that lands, grid-shaped data (e.g. the CEP × brand matrix) is declared as `Multi_Mention` with a compound `ColumnPattern` (see §5).

### 2.4 Cardinality

| Cardinality | Meaning |
|----|----|
| `per_respondent` | One value per respondent row (e.g., weight, segment) |
| `per_brand` | One column per brand in the brand list |
| `per_category` | One column per category (multi-category studies) |
| `per_asset` | One column per stimulus asset (DBA) |
| `brand_matrix` | One column per (brand × attribute) cell |
| `reference` | Metadata declared in a `Survey_Structure.xlsx` sheet, not a data column |

### 2.5 Data-shape precondition

The brand module assumes the standard rectangular export shape produced by Alchemer, Qualtrics, and comparable platforms:

-   **One row per respondent.** No respondent appears on more than one row. Panel ID is unique per row (see guard rule 4).
-   **One column per question** for single-response / numeric / open-ended items.
-   **One column per option** for multi-response items. Values are 0/1/NA (or the declared equivalent). One column per option — not delimited strings.
-   **One column per cell** for grid / matrix items. A grid of *r* rows × *c* columns produces *r* × *c* columns in the data.

`ColumnPattern` in QuestionMap (§11.1) declares the naming template — for example `{code}_{brandcode}` for a per-brand multi-mention, `{code}_{row}_{col}` for a grid cell. The guard refuses loud (`CFG_PATTERN_MISMATCH`) if the data does not match the declared shape. Long-format or delimited-column data is not supported; reshape upstream before feeding the module.

------------------------------------------------------------------------

## 3. System namespace — shared across all elements

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `system.respondent.id` | per_respondent | Single_Response | Yes | Panel key. Stable across waves. |
| `system.respondent.weight` | per_respondent | Numeric | Optional | Post-stratification or rim weight. If absent, analysis is unweighted. |
| `system.respondent.segment` | per_respondent | Single_Response | Optional | Multiple segment roles permitted. |
| `system.respondent.demographics` | per_respondent | Single_Response | Optional | Standard demographic columns; role per variable. |
| `system.survey.wave` | per_respondent | Single_Response | Optional | Wave label (e.g., "W1-2025"). |
| `system.category.id` | per_respondent | Single_Response | Optional | Focal category assigned per respondent (multi-category studies). |
| `system.brand.list` | reference | — | Yes | BrandCode + BrandName + display order. Declared in `Survey_Structure.xlsx` Brands sheet. |
| `system.category.list` | reference | — | Conditional | Required when multi-category. CategoryCode + CategoryName + type. |

------------------------------------------------------------------------

## 4. Funnel element

Three category-type sub-namespaces. `category.type` setting in Brand_Config.xlsx selects which.

### 4.1 Shared (all category types)

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `funnel.awareness` | per_brand | Multi_Mention | Yes | BRANDAWARENESS equivalent. |
| `funnel.attitude` | per_brand | Single_Response | Yes | QBRANDATT1 equivalent. Codes mapped via OptionMap to the 5 attitude position sub-roles. |
| `funnel.rejection_oe` | per_brand | Open_End | Optional | QBRANDATT2 — rejection reason. Sparse: populated only when attitude = reject. |

### 4.2 Attitude position sub-roles (mapped via OptionMap)

| Role                  | Maps to                                | Default code |
|-----------------------|----------------------------------------|--------------|
| `attitude.love`       | Strong positive — "favourite"          | 1            |
| `attitude.prefer`     | Mild positive — "among those I prefer" | 2            |
| `attitude.ambivalent` | Would-buy-if-no-other-choice           | 3            |
| `attitude.reject`     | Active rejection                       | 4            |
| `attitude.no_opinion` | Neutral / no opinion                   | 5            |

OptionMap allows inverting codes, omitting positions (e.g., no Ambivalent → Consideration = Love + Prefer), and supplying client-specific labels for legend display.

### 4.3 Transactional (FMCG) — `category.type = transactional`

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `funnel.transactional.bought_long` | per_brand | Multi_Mention | Optional | BRANDPENTRANS1 — longer timeframe. |
| `funnel.transactional.bought_target` | per_brand | Multi_Mention | Optional | BRANDPENTRANS2 — target timeframe. |
| `funnel.transactional.frequency` | per_brand | Numeric | Optional | BRANDPENTRANS3. Required for Preferred stage. |

At least one of the three required to render any buying stage.

### 4.4 Durable — `category.type = durable`

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `funnel.durable.current_owner` | per_respondent | Single_Response | Yes | BRANDPENDUR1. One brand per respondent. |
| `funnel.durable.tenure` | per_respondent | Single_Response | Optional | BRANDPENDUR2. Required for loyalty stage. |

### 4.5 Service — `category.type = service`

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `funnel.service.current_customer` | per_respondent | Single_Response | Yes | BRANDPENSERV1. One brand per respondent. |
| `funnel.service.tenure` | per_respondent | Single_Response | Optional | BRANDPENSERV2. Required for loyalty stage. |
| `funnel.service.prior_brand` | per_respondent | Single_Response | Optional | BRANDPENSERV3. Not a stage; flagged in About as feeding Repertoire switching analysis. |

------------------------------------------------------------------------

## 5. Mental Availability element

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `ma.cep_matrix` | brand_matrix | Multi_Mention | Yes | Q1BRANDATTRIBUTE per CEP × brand. Binary. Declared with compound `ColumnPattern = {code}_{cep_code}_{brand_code}` — guard expands via CEPs × Brands lists. Will migrate to `Grid_Multi` when the grid stream ships (see [GRID_SUPPORT_SPEC](../../tabs/docs/GRID_SUPPORT_SPEC.md)). |
| `ma.cep_list` | reference | — | Yes | CepCode + CepText + CepType (cep / attribute). Declared in Survey_Structure CEPs sheet. |
| `ma.category_frequency` | per_respondent | Numeric | Optional | QCATEGORYBUYINGTRANS/DUR/SERV — for CEP importance weighting. |

Reuses `funnel.awareness` for MPen normalisation.

------------------------------------------------------------------------

## 6. Repertoire element

No new roles. Consumes:

-   Transactional: `funnel.transactional.bought_long`, `bought_target`, `frequency`.
-   Durable: `funnel.durable.current_owner`, optional tenure.
-   Service: `funnel.service.current_customer`, optional tenure, optional `prior_brand` (switching).

------------------------------------------------------------------------

## 7. Drivers & Barriers element

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `drivers.rejection_oe` | per_brand | Open_End | Optional | Same data source as `funnel.rejection_oe`; element declares the role to make its dependency explicit. Rejection themes rendered only when populated. |

Reuses `ma.cep_matrix` (performance) and `funnel.attitude` (preference outcome).

------------------------------------------------------------------------

## 8. DBA (Distinctive Brand Assets) element

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `dba.asset.{ordinal}.closed` | per_asset | Single_Response | Conditional | Closed attribution — one brand per asset. Required when `dba.mode = closed`. |
| `dba.asset.{ordinal}.open` | per_asset | Open_End | Conditional | Open attribution — free-text. Required when `dba.mode = open`. |
| `dba.asset_list` | reference | — | Yes | AssetCode + AssetLabel + AssetType + image ref. Declared in Survey_Structure Assets sheet. |

Exactly one of `closed` / `open` per asset per project (`dba.mode` setting).

------------------------------------------------------------------------

## 9. Portfolio (cross-category) element

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `portfolio.cross_category_awareness` | per_respondent × per_category | Multi_Mention | Yes | Lightweight awareness across all (category × brand) combinations. |

Reuses per-category funnel roles for penetration. Uses `system.category.id` for routing.

------------------------------------------------------------------------

## 10. WOM element

| Role | Cardinality | Type | Required | Notes |
|----|----|----|----|----|
| `wom.received_positive` | per_brand | Multi_Mention | Yes | QWOMBRAND1a |
| `wom.received_negative` | per_brand | Multi_Mention | Yes | QWOMBRAND1b |
| `wom.shared_positive_incidence` | per_brand | Multi_Mention | Yes | QWOMBRAND2a |
| `wom.shared_positive_count` | per_brand | Numeric | Optional | QWOMBRAND2b — upgrades incidence to volume |
| `wom.shared_negative_incidence` | per_brand | Multi_Mention | Yes | QWOMBRAND3a |
| `wom.shared_negative_count` | per_brand | Numeric | Optional | QWOMBRAND3b |

------------------------------------------------------------------------

## 11. `Survey_Structure.xlsx` schema

### 11.1 QuestionMap sheet — one row per role the project populates

| Column | Purpose |
|----|----|
| `Role` | Registry role name (e.g. `funnel.awareness`). |
| `ClientCode` | Client's question code in the data (e.g. `q1_aware`). |
| `QuestionText` | Full question wording. Used as chart/card label and in About. |
| `QuestionTextShort` | Optional shortened label for tight UI elements. |
| `Variable_Type` | One of the catalogue types (§2.3). Column name mirrors the tabs module's `Variable_Type` exactly — same value vocabulary, so a single Survey_Structure row satisfies both modules. |
| `ColumnPattern` | Declared naming template: `{code}_{brandcode}`, `{code}_{index}`, `{code}`. Guard refuses loud if data does not match. |
| `OptionMapScale` | Name of the OptionMap scale this row uses (blank for binary). |
| `Notes` | Operator notes (not shown in report). |

### 11.2 OptionMap sheet — one row per (code × scale)

| Column | Purpose |
|----|----|
| `Scale` | Scale name (e.g. `attitude_scale`). |
| `ClientCode` | Integer or string code in the data. |
| `Role` | Position role this code maps to (e.g. `attitude.love`). Blank if code is non-analytic (e.g. "Don't know"). |
| `ClientLabel` | Text the client used in the questionnaire — shown in report legend. |
| `OrderIndex` | Display order (integer). |

### 11.3 Existing sheets (unchanged)

`Brands`, `Categories`, `CEPs`, `Assets` remain as in the existing Survey_Structure template; they are the `reference`-cardinality role sources.

------------------------------------------------------------------------

## 12. Guard validation

Every module's `00_guard.R` validates before processing begins:

1.  Every **Required** role has a QuestionMap row with a matching data column.
2.  For each declared role, data columns match the declared `ColumnPattern` (no silent fallbacks).
3.  For any role referencing an OptionMap (`Single_Response`, `Likert`, `Rating`), the scale is fully populated — every expected position role is either present or explicitly null.
4.  `system.respondent.id` is unique per row.
5.  `system.respondent.weight` is numeric, non-negative, non-zero-sum.
6.  Brand list in `Brands` sheet is consistent with brand columns across roles (warn on orphan columns).

All refusals use typed codes:

-   `CFG_ROLE_MISSING` — required role absent.
-   `CFG_COLUMN_NOT_FOUND` — role declared but column not in data.
-   `CFG_PATTERN_MISMATCH` — ColumnPattern does not match actual columns.
-   `CFG_OPTIONMAP_INCOMPLETE` — scale referenced but not fully defined.
-   `CFG_BRAND_ORPHAN` — data columns exist for brands not in Brands sheet.

Refusals write to console per the Shiny error-box pattern and return a structured refusal to the caller.

------------------------------------------------------------------------

## 13. Review checklist

Before building against this registry:

-   [ ] System namespace covers everything shared (id, weight, segment, wave, category, brand list).
-   [ ] Funnel's three sub-namespaces cover transactional, durable, service accurately.
-   [ ] Mental Availability matrix role is well-defined (brand_matrix cardinality).
-   [ ] DBA closed/open split is correct and mutually exclusive per asset.
-   [ ] WOM separates incidence from count cleanly.
-   [ ] QuestionMap + OptionMap schema (§11) covers all mapping cases.
-   [ ] Guard error codes (§12) are the right granularity for operator feedback.

------------------------------------------------------------------------

**End of registry v1.0 draft.**
