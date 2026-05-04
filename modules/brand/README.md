# Brand Module

Within-category brand strength analysis using the Ehrenberg-Bass / Romaniuk Category Buyer Mindset (CBM) framework.

## Quick Start

```r
# Generate config templates
source("modules/brand/R/generate_config_templates.R")
generate_brand_config_template("config/Brand_Config.xlsx")
generate_brand_survey_structure_template("config/Survey_Structure.xlsx")

# Fill in both Excel files, then run
source("modules/brand/R/00_main.R")
result <- run_brand("config/Brand_Config.xlsx")
```

> **Note:** The test fixture `.xlsx` files are generated (not committed). Run
> `source("modules/brand/tests/fixtures/ipk_wave1/00_generate.R"); ipk_generate_fixture()`
> before running the full test suite on a fresh clone.

## Elements

All elements are config-togglable via `element_*` settings in Brand_Config.xlsx.

| Element | Config key | Type | Description |
|---------|-----------|------|-------------|
| Mental Availability | `element_mental_avail` | Core | MMS, MPen, NS, CEP × brand matrix, CEP TURF |
| Mental Advantage | _(part of MA)_ | Core | Romaniuk CEP/attribute advantage matrix, strategic quadrant |
| Funnel | `element_funnel` | Derived | Awareness → disposition → bought → primary, attitude decomposition |
| Repertoire | `element_repertoire` | Derived | Multi-brand buying, sole loyalty, share of requirements |
| WOM | `element_wom` | Own battery | Received/shared × positive/negative balance |
| Drivers & Barriers | `element_drivers_barriers` | Derived | Excel/CSV outputs (Importance × Performance, rejection themes) |
| DBA | `element_dba` | Own battery | Fame × Uniqueness grid for distinctive brand assets |
| Category Buying | `element_cat_buying` (always on) | Derived | Purchase frequency, brand volume, Dirichlet norms, buyer heaviness, shopper behaviour |
| Portfolio | `element_portfolio` | Brand-level | Cross-category footprint, constellation, clutter, strength, extension |
| Branded Reach | `element_branded_reach` | Own battery | Ad recognition, misattribution, media mix |
| Demographics | `element_demographics` | Derived | Focal-brand profile vs category total |
| Ad Hoc | `element_adhoc` | Own battery | Custom questions appended to the HTML report |
| Audience Lens | `element_audience_lens` | Derived | Per-audience KPI comparisons (GROW / FIX / DEFEND classification) |
| Executive Summary | _(always on)_ | Derived | Per-category dashboard: headline sentence, focal strip, diagnostic chips |

## Configuration

Two Excel files, both using relative paths (portable across machines):

- **Brand_Config.xlsx** — Analysis settings, category definitions, element toggles
- **Survey_Structure.xlsx** — Data dictionary: questions, brands, CEPs, attributes

Valid `Type` values for the Categories sheet: `transactional`, `durable`, `service`.

See `docs/BRAND_CONFIG_GUIDE.md` for the full configuration reference.

## Output

- **HTML report** via report_hub (self-contained, TurasPins enabled)
- **Excel workbook** with one sheet per element per category
- **CSV files** in long format per element

## File Layout

```
modules/brand/
  R/
    00_main.R                    -- Main orchestration (run_brand)
    00_guard.R                   -- TRS guard layer
    00_data_access.R             -- Slot-indexed data access helpers
    00_role_inference.R          -- Auto-infer role map from column names
    00_role_map.R                -- Build brand role map from Survey_Structure
    00_guard_role_map.R          -- Guard layer for role map validation
    01_config.R                  -- Config + structure loading
    02_mental_availability.R     -- MMS, MPen, NS, CEP TURF
    02b_mental_advantage.R       -- Romaniuk CEP/attribute advantage calculation
    02c_ma_focal_view.R          -- MA focal-brand view (Drivers & Barriers HTML lens)
    02a_ma_panel_data.R          -- MA panel data builder
    02b_ma_advantage_data.R      -- MA advantage panel data builder
    03_funnel.R                  -- Derived funnel + attitude
    03a_funnel_derive.R          -- Stage matrix derivation
    03b_funnel_metrics.R         -- Stage percentages, conversions, significance
    03c_funnel_panel_data.R      -- Funnel HTML panel data contract
    03d_funnel_output.R          -- Funnel Excel/CSV writers
    03e_funnel_legacy_adapter.R  -- Legacy QuestionMap adapter
    04_repertoire.R              -- Multi-brand buying
    05_wom.R                     -- Word-of-mouth
    05a_wom_panel_data.R         -- WOM panel data builder
    06_drivers_barriers.R        -- Derived importance (Excel/CSV outputs)
    07_dba.R                     -- Distinctive brand assets
    08_cat_buying.R              -- Category buying frequency
    08b_brand_volume.R           -- Brand volume matrix
    08c_dirichlet_norms.R        -- Dirichlet benchmark norms
    08d_buyer_heaviness.R        -- Buyer heaviness analysis
    08e_shopper_behaviour.R      -- Purchase channel + pack size
    09_portfolio.R               -- Portfolio orchestrator
    09a–09h_portfolio_*.R        -- Portfolio sub-analyses (footprint, constellation, etc.)
    10_branded_reach.R           -- Branded reach orchestrator
    10a–10d_br_*.R               -- Branded reach sub-analyses
    11_demographics.R            -- Demographics analysis
    11a_demographics_panel_data.R
    12_adhoc.R                   -- Ad hoc questions
    12a_adhoc_panel_data.R
    13_audience_lens.R           -- Audience lens orchestrator
    13a–13d_al_*.R               -- Audience lens sub-analyses
    99_output.R                  -- Excel/CSV generators
    generate_config_templates.R  -- Config template generators
  lib/
    html_report/
      99_html_report_main.R      -- HTML report orchestrator
      01_data_transformer.R      -- Transform results to chart/table data
      02_table_builder.R         -- Styled HTML tables
      03_page_builder.R          -- Full HTML page assembly
      04_chart_builder.R         -- Inline SVG charts
      panels/                    -- Per-element panel renderers (auto-loaded)
  tests/
    testthat/                    -- 431 test blocks / 1621+ assertions
    fixtures/
      ipk_wave1/                 -- IPK 9-category synthetic fixture
        00_generate.R            -- Run ipk_generate_fixture() to build .xlsx files
  docs/
    BRAND_CONFIG_GUIDE.md        -- Full configuration reference
    BRAND_REPORT_USER_GUIDE.md   -- End-user report guide
    CAT_BUYING_SPEC_v3.md        -- Category buying specification
```

## Dependencies

Uses existing Turas modules: tabs (significance), confidence (CIs), catdriver (optional SHAP importance), tracker (wave 2+), weighting (upstream), report_hub + hub_app (HTML rendering), shared/TurasPins (pin system), shared/turf_engine (CEP TURF).

## References

- Romaniuk, J. (2022). *Better Brand Health*. Oxford University Press.
- Sharp, B. (2010). *How Brands Grow*. Oxford University Press.
- Romaniuk, J. (2018). *Building Distinctive Brand Assets*. Oxford University Press.
