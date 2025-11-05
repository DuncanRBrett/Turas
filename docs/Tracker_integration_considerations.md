Here's a development considerations document for **TURAS Tabs**, written
to mirror the clarity and format of your tracking module spec. It's
intended to guide your dev team on dependencies, future-proofing, and
integration implications across both modules.

**TURAS Tabs Module -- Development Considerations & Integration
Implications (v1.0)**

**Purpose:**\
Define the architecture, design principles, and integration
considerations for maintaining and extending the **TURAS Tabs**module.
This document ensures long-term compatibility with
the **Tracking** module and other analytical extensions.

**1. Overview**

**TURAS Tabs** is the **core analytical engine** for single-wave survey
analysis.\
Its outputs --- weighted crosstabs, means, top-box scores, sig tests,
and derived metrics --- form the foundation for:

-   All single-wave deliverables (Excel, CSV, JSON).

-   Baselines used in multi-wave tracking comparisons.

-   Testing and validation for Tracking module parity.

**Primary objective:**\
Keep Tabs *light, fast, and stable*, while abstracting statistical
functions into a shared **core** to support modular expansion (Tracking,
Dashboards, Text Analytics).

**2. Architectural Relationship to Tracking**

  ----------------------------------------------------------------------------
  **Aspect**     **Tabs**          **Tracking**          **Implication**
  -------------- ----------------- --------------------- ---------------------
  Data scope     One survey wave   Multiple waves        Shared core ensures
                                                         identical cell logic

  File inputs    questions.xlsx,   multiple data files + Harmonisation logic
                 data.xlsx         question mapping      exclusive to Tracking

  Output focus   Point-in-time     Trend and change      Tabs remains baseline
                 reporting         reporting             engine

  Significance   Row × Column      Wave × Wave + Row ×   Tests must be unified
  tests                            Column                

  Core           uses turas.core   uses turas.core +     Keep tests and nets
  dependency                       harmonisation         in core
  ----------------------------------------------------------------------------

**3. Development Principles**

1.  **Single source of truth** -- all calculations must
    use turas.core shared functions.

2.  **Minimal duplication** -- UI, tests, and configs identical to
    Tracking where possible.

3.  **Backward compatibility** -- maintain support for legacy files
    (V1--V2 project structures).

4.  **Isolation** -- Tabs must run standalone (no need for Tracking
    configs).

5.  **Plug-in readiness** -- easily extendable for segmentation, driver
    analysis, and dashboards.

6.  **Stable outputs** -- ensure reproducibility across R/Python
    environments.

**4. Core Dependencies**

**4.1 Shared Components**

-   **weights_effn.R** -- weighting, design effects, effective n.

-   **sig_test_dispatch.R** -- manages all p-value and test methods.

-   **nets.R** -- handles Top2/Bottom2, custom nets, and derived
    summaries.

-   **letters_or_flags.R** -- manages output annotation.

-   **excel_formats.R** -- ensures visual consistency.

-   **banner_build.R** -- defines hierarchical and multi-level banner
    structures.

**4.2 Key Config Files**

-   tabs_config.xlsx -- parallels tracking_config.xlsx with wave =
    current only.

-   questions.xlsx -- question metadata.

-   options.xlsx -- response options.

-   derived_metrics.xlsx -- reusable across modules.

**5. Analytical Capabilities (Core)**

  -----------------------------------------------------------------------
  **Function**     **Description**        **Implication**
  ---------------- ---------------------- -------------------------------
  Weighting & Deff Weighted stats using   Must exactly match Tracking's
                   base, eff-n            base engine

  Means &          Core outputs           Basis for change computations
  Proportions                             in Tracking

  Significance     t, z, chi-square       Must output identical flags as
  Testing                                 Tracking

  Multiple         Bonferroni, Holm, BH   Configured through stat_profile
  Comparisons                             

  Derived Metrics  Any custom metric      Used as continuity anchors in
                                          Tracking

  Banners          Multi-level            Must export schema readable by
                   cross-sections         Tracking

  Missing Data     DK/NA rules per        Must flag same cases as
                   question               Tracking
  -----------------------------------------------------------------------

**6. New Development Priorities**

**6.1 Refactor into Core + UI Layers**

Move statistical logic into turas.core to support reuse:

modules/

├─ core/

│ ├─ stats_engine.R

│ ├─ sig_tests.R

│ ├─ weights.R

│ └─ nets.R

└─ tabs/

├─ orchestrator_tabs.R

├─ excel_writer_tabs.R

└─ validation_tabs.R

**6.2 Config Harmonisation**

Ensure tabs_config.xlsx matches structure of tracking_config.xlsx to
simplify conversion.\
Example: a single-wave config should be a valid subset of multi-wave
config.

**6.3 Unified Testing Framework**

Adopt shared regression test suite (golden_master.R):

-   Confirm same p-values for common data.

-   Same net logic and formatting rules.

-   CI pipeline fails if drift \> tolerance.

**7. Integration Implications for Tracking & Future Modules**

**7.1 Shared Statistical Engine**

-   Any update to significance or weighting logic affects both modules.

-   Introduce **versioning**: core_version, tabs_version, tracking_version.

-   Add unit tests verifying parity for at least one common dataset per
    release.

**7.2 Harmonisation of Derived Metrics**

-   Derived metrics defined in Tabs become **tracking anchors**.

-   Must export canonical metric names (e.g., DRV_SAT_INDEX).

**7.3 Output Schema Consistency**

-   All outputs must use **identical field names**:\
    question_code, banner_code, metric, value, p_value, sig_flag, base_n, wave.

**7.4 Backward Compatibility**

-   Tabs must accept both legacy project folders and new harmonised
    configs.

-   Provide auto-conversion if older layouts are detected.

**8. Performance & Reliability Considerations**

-   Target runtime: \<2 minutes for 10,000 respondents × 250 variables.

-   Use data.table for all joins and reshapes.

-   Implement caching for repetitive banners.

-   Optimize Excel writing with openxlsx::writeDataTable() instead of
    cell loops.

-   Keep memory footprint \< 2GB during processing.

**9. Testing & Validation**

**Required Test Types**

  -----------------------------------------------------------------------
  **Test**                      **Purpose**
  ----------------------------- -----------------------------------------
  Golden-Master                 Detect deviations in p-values or flags

  Banner Integrity              Verify correct spanning and nesting

  Config Validation             Detect missing/duplicate variable IDs

  Derived Metric Continuity     Check formulas resolve correctly

  Performance Test              Ensure runtime within limits
  -----------------------------------------------------------------------

**Regression Test Workflow**

1.  Run Tabs and Tracking on the same wave.

2.  Compare outputs for shared measures.

3.  Report variance \> ±0.001 as warning.

4.  Log all discrepancies to /logs/test_results/.

**10. Future-Proofing & Expansion Hooks**

  -----------------------------------------------------------------------
  **Future Feature**      **Hook Required Now**
  ----------------------- -----------------------------------------------
  Visualisation           Export long-format JSON + metadata

  Dashboards              CSV schema parity with Tracking

  Text Analysis           Placeholder for open-ended linkage

  Segmentation            Tag segment variables in metadata

  Machine Learning        Export prepared model-ready dataset

  API Exposure            CLI + modular input/output design
  -----------------------------------------------------------------------

**11. Governance & Documentation**

-   All commits referencing shared code must update core_version.

-   Maintain full changelog of stats engine adjustments.

-   Document input/output examples for Tabs and Tracking parity.

-   Include inline Roxygen tags for every public function.

**12. Acceptance Criteria**

1.  Single-wave analysis executes end-to-end with no dependencies on
    Tracking.

2.  Outputs reproduce pre-existing results exactly.

3.  Core refactor allows Tracking to import all functions without
    redundancy.

4.  Parity validation passes across both modules.

5.  Full run time within performance thresholds.

**Prepared by:**\
*Duncan Brett*\
*The Research LampPost (Pty) Ltd*\
*November 2025*

Would you like me to generate a **diagram (system architecture
flow)** showing how Tabs and Tracking share the core engine --- suitable
for inclusion in your dev documentation deck or onboarding PDF?
