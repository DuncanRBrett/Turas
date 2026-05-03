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

## Elements

All elements are config-togglable via `element_*` settings in Brand_Config.xlsx.

| Element | Type | Description |
|---------|------|-------------|
| Mental Availability | Core | MMS, MPen, NS, CEP x brand matrix, CEP TURF |
| Funnel | Derived | Awareness > disposition > bought > primary, attitude decomposition |
| Repertoire | Derived | Multi-brand buying, sole loyalty, share of requirements |
| Drivers & Barriers | Derived | Excel/CSV outputs (Importance x Performance, rejection themes). The HTML "drivers & barriers" view is rendered as a focal-brand drill-down on the Mental Advantage sub-tab — see `02c_ma_focal_view.R`. |
| WOM | Own battery | Received/shared x positive/negative balance |
| DBA | Own battery | Fame x Uniqueness grid for distinctive brand assets |

## Configuration

Two Excel files, both using relative paths (portable across machines):

- **Brand_Config.xlsx** -- Analysis settings, category definitions, element toggles
- **Survey_Structure.xlsx** -- Data dictionary: questions, brands, CEPs, attributes

All paths in config are relative to the config file's directory.

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
    01_config.R                  -- Config + structure loading
    02_mental_availability.R     -- MMS, MPen, NS, CEP TURF
    02c_ma_focal_view.R          -- MA + buyer-gap focal-brand view (Drivers & Barriers HTML lens)
    03_funnel.R                  -- Derived funnel + attitude
    04_repertoire.R              -- Multi-brand buying
    05_wom.R                     -- Word-of-mouth
    06_drivers_barriers.R        -- Derived importance (Excel/CSV outputs)
    07_dba.R                     -- Distinctive brand assets
    99_output.R                  -- Excel/CSV generators
    generate_config_templates.R  -- Config template generators
  lib/
    html_report/
      99_html_report_main.R      -- HTML report generator
  tests/
    testthat/                    -- 613+ tests
```

## Dependencies

Uses existing Turas modules: tabs (significance), confidence (CIs), catdriver (optional SHAP importance), tracker (wave 2+), weighting (upstream), report_hub + hub_app (HTML rendering), shared/TurasPins (pin system), shared/turf_engine (CEP TURF).

## References

- Romaniuk, J. (2022). *Better Brand Health*. Oxford University Press.
- Sharp, B. (2010). *How Brands Grow*. Oxford University Press.
- Romaniuk, J. (2018). *Building Distinctive Brand Assets*. Oxford University Press.
