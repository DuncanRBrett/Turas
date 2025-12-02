Turas tracking development brief

Below is a **fully rewritten Development Specification** for
your **TURAS Tracking Module**, written in professional software-spec
language. It's designed to be handed directly to developers and reflects
everything we've discussed:

-   integration with your existing TURAS Tabs system,

-   all essential analytical & statistical features,

-   R-library integration options,

-   and placeholders for later visualisation and automation phases.

**TURAS Tracking Module -- Development Specification (Version 1.0)**

**Date:** November 2025\
**Prepared by:** Duncan Brett / The Research LampPost\
**Purpose:** Extend the existing **TURAS Survey Analytics Toolkit** to
support **longitudinal tracking and trend analysis**across multiple
survey waves, while remaining fully compatible with existing single-wave
(Tabs) functionality.

**1. Overview**

The **Tracking Module** will:

1.  Read and harmonise multiple survey waves (past and current).

2.  Identify and manage question/option changes across waves.

3.  Compute longitudinal metrics (change scores, trend slopes,
    continuity flags).

4.  Output both Excel and machine-readable (CSV/JSON) tables suitable
    for BI dashboards.

5.  Reuse the shared **TURAS Core Stats Engine** (weights, nets,
    significance testing, banner logic, Excel styling).

6.  Prepare data and metadata for a later **visualisation layer** (Phase
    2).

**2. Scope and Deliverables**

**2.1 In-scope (Phase 1)**

-   Backend logic and data model for longitudinal analysis.

-   Harmonisation and mapping workflows.

-   Statistical computations for wave-to-wave and baseline change.

-   Excel + CSV/JSON outputs.

-   Unit tests, regression tests, and configuration validation.

**2.2 Future scope (Phase 2+ placeholders)**

-   Interactive dashboards and chart generation.

-   Text/open-end analysis.

-   Complex survey design variance (design_aware = TRUE).

-   Attrition weighting (IPW / Heckman).

**3. Architecture**

**3.1 Integration**

-   Resides under /modules/tracking/.

-   Uses shared **turas.core** package containing:

    -   weights_effn.R

    -   nets.R (Top/Bottom/Net+)

    -   sig_test_dispatch.R

    -   letters_or_flags.R

    -   banner_build.R

    -   excel_formats.R

-   Imports same config and validation loaders used by Tabs.

**3.2 Data Flow**

tracking_config.xlsx ─→ validation.R ─→ tracking_orchestrator.R

↓ ↓ ↓

question_mapping.xlsx master_dictionary.csv derived_metrics.xlsx

↓ ↓ ↓

harmonisation.R → stats_core.R → excel_writer_tracking.R

↘→ csv_json_exporter.R

**4. Configuration Files**

**4.1 tracking_config.xlsx**

  ----------------------------------------------------------------------------------
  **Field**              **Type**   **Example**               **Notes**
  ---------------------- ---------- ------------------------- ----------------------
  project_name           text       CCPB_Tracker              

  waves                  list       2023, 2024, 2025          list of available
                                                              waves

  base_wave              text       2023                      baseline for
                                                              comparisons

  design_aware           bool       FALSE                     uses R "survey"
                                                              package if TRUE

  stat_profile           text       turas_standard \|         determines test
                                    spss_like \|              families
                                    displayr_like             

  render_style           text       letters \| flags \| both  affects sig annotation

  continuity_threshold   numeric    0.5                       tolerance for scale
                                                              shifts

  base_drift_threshold   numeric    10                        percent change flag
                                                              trigger

  auto_refresh           bool       TRUE                      auto-rebuild on new
                                                              wave

  theme_profile          text       default \| client_brand   chart/Excel theme

  locale                 text       en_ZA                     numeric/date
                                                              formatting

  output_formats         list       Excel, CSV, JSON          
  ----------------------------------------------------------------------------------

**4.2 question_mapping.xlsx**

Columns: TrackingCode, Wave, QuestionCode, OptionCode, MappingRule, ContinuityFlag, Comment.\
Purpose: align question/option differences across waves.

**4.3 derived_metrics.xlsx**

Columns: MetricName, Formula, ContinuityRule (Rescale \| Recompute \|
BreakSeries \| DualReport).

**4.4 master_dictionary.csv**

Persistent canonical list of variables (added automatically if absent).\
Columns: TrackingCode, CanonicalLabel, VariableType, ValueScale, FirstWave, LastWave, Hash.

**5. Functional Requirements**

**5.1 Wave Management**

-   Load multiple wave datasets (Excel/CSV/SPSS).

-   Validate structure against master dictionary.

-   Detect and log:

    -   New or retired questions/options.

    -   Option label or scale changes.

    -   Wording differences (via hash mismatch).

-   Auto-flag **continuity risk** where applicable.

**5.2 Harmonisation**

-   Apply mappings from question_mapping.xlsx.

-   Generate harmonised dataset keyed on TrackingCode.

-   Maintain per-wave effective base and weight totals.

-   Warn if total weighted base drifts \> base_drift_threshold.

**5.3 Analytical Computations**

  -----------------------------------------------------------------------
  **Metric**       **Description**           **R library / Function**
  ---------------- ------------------------- ----------------------------
  Mean/Index       Wave − Base difference    internal
  change                                     + effectsize::cohens_d

  Proportion       Wave − Base (%)           internal sig_test_dispatch
  change           difference                

  Trend slope      Linear regression across  stats::lm
                   waves                     

  Significance     z, t, paired t, McNemar   turas.core
  tests                                      

  Effect sizes     Cohen's d, r, η²          effectsize (easystats)

  Practical sig    p \< 0.05 AND Δ≥threshold internal
  flags                                      

  Segment          Jaccard/churn index       brolgar or internal
  stability                                  

  Attrition rates  Respondents retained /    placeholder (Phase 2)
                   lost                      
  -----------------------------------------------------------------------

**5.4 Outputs**

1.  **Excel workbook**

    -   Summary, Trend tables, Continuity report, Base drift report,
        Metadata.

    -   Same styling as Tabs via excel_formats.R.

2.  **CSV/JSON exports**

    -   Long-format data tables
        (wave, banner, metric, value, sig, flag).

    -   Manifest file listing analysis ids, filters, timestamps.

3.  **Metadata tab**

    -   Config snapshot, version hash, developer info, runtime,
        warnings.

**5.5 Logging & QA**

-   Centralised log (/logs/tracking_log.txt) with levels
    INFO/WARN/ERROR.

-   Auto-generate Analyst Notes summarising:

    -   base drift warnings

    -   continuity breaks

    -   small-base suppressions

**6. Statistical Engine Integration**

**6.1 Shared Core (turas.core)**

All tests, nets, weights, and banners must call the same underlying
functions as Tabs.\
Significance results identical for single-wave runs.

**6.2 R-library dependencies**

  ----------------------------------------------------------------------------
  **Library**                  **Purpose**
  ---------------------------- -----------------------------------------------
  **survey**                   complex sample variance (optional)

  **effectsize**               effect-size calculations

  **brolgar**                  trend and stability in longitudinal data

  **lmtest**, **sandwich**     robust SEs for trend slopes

  **data.table**               fast wave merging

  **openxlsx**, **jsonlite**   output formats
  ----------------------------------------------------------------------------

All libraries must be optional and checked at runtime; fallback to
internal methods if not installed.

**7. Performance & Scalability**

-   Must handle ≥ 10 waves × 10 000 respondents × 200 questions.

-   Caching: reuse per-wave processed objects to speed reruns.

-   Incremental rebuild: when new wave added, recompute only dependent
    analyses.

**8. Testing & Validation**

**8.1 Golden-master regression tests**

-   Use synthetic dataset with known p-values, sig letters, and effect
    sizes.

-   Ensure identical output across versions (± rounding tolerance).

**8.2 Baseline parity test**

-   Verify that single-wave run from Tracking equals Tabs output.

**8.3 Continuity validation**

-   Randomly mutate question text and confirm hash flag triggers.

-   Simulate option changes and confirm mapping behaves correctly.

**9. Security & Compliance**

-   Personally identifiable information (PII) confined to panel layer;
    replaced with hashed IDs before analysis.

-   All exports anonymised.

-   Configurable locale/date/number formats (e.g., en_ZA).

**10. Phase 2 Placeholders (to design for now)**

-   **Visualisation API:** produce long-format data + metadata ready for
    ggplot/Plotly or external BI.

-   **Theme registry:** JSON theme file with brand palettes, fonts, grid
    rules.

-   **Chart metadata:** per table, store chart_type suggestion
    ("trend_line", "bar_delta").

-   **Open-end text module stub:** table for verbatim classification
    rules.

**11. Acceptance Criteria**

1.  **Functional parity:** single-wave results identical to Tabs.

2.  **Accuracy:** p-values and effect sizes match golden-master
    benchmarks.

3.  **Usability:** analysts can run full tracker by
    updating tracking_config.xlsx only.

4.  **Performance:** 10 k × 10 waves completes ≤ 5 min.

5.  **Outputs:** Excel and CSV/JSON identical in content; metadata tab
    complete.

6.  **Logging:** all warnings/errors clearly written to log and
    Metadata.

7.  **Extensibility:** visualisation phase can consume CSV/JSON without
    schema change.

**12. Implementation Phasing (recommended)**

  --------------------------------------------------------------------------------
  **Phase**   **Duration**   **Deliverables**
  ----------- -------------- -----------------------------------------------------
  0           2 weeks        Extract shared core; parity test with Tabs

  1           4 weeks        Wave loader, harmonisation, trend engine, outputs

  2           3 weeks        Base-drift/continuity reporting, effect sizes,
                             manifest

  3           2 weeks        CSV/JSON exports, performance tuning

  4           2 weeks        Optional design-aware variance & attrition weighting
  --------------------------------------------------------------------------------

**End of Specification**

Would you like me to produce a concise **Developer Kick-off Pack** next
(a two-page handout summarising directory layout, key functions, and
test datasets) so your coders can start immediately?
