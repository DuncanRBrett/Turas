**TURAS Tracking Module -- Developer Kick-Off Pack (v1.0)**

**Prepared by:** Duncan Brett / The Research LampPost\
**Target Audience:** Developers extending the existing **TURAS Survey
Analytics Toolkit**\
**Purpose:** Build the backend module that enables multi-wave
(longitudinal) analysis and reporting while sharing the same statistical
core as the single-wave Tabs engine.

**🧭 Project Overview**

**Goal:**\
Add a *Tracking* layer to TURAS that can:

-   Load, harmonise, and compare multiple survey waves.

-   Compute trends, change scores, and effect sizes.

-   Output results in Excel **and** machine-readable CSV/JSON for
    dashboards.

-   Flag continuity issues (wording, scale, base drift).

-   Remain 100 % compatible with existing Tabs output and significance
    logic.

**Key principle:**\
➡ **One Stats Core -- Two Applications.**\
Tabs = single-wave, Tracking = multi-wave assembler.

**📂 Directory Structure**

/modules

├─ core/ ← shared stats engine

│ ├─ weights_effn.R

│ ├─ nets.R

│ ├─ sig_test_dispatch.R

│ ├─ letters_or_flags.R

│ ├─ banner_build.R

│ └─ excel_formats.R

├─ tabs/ ← existing single-wave engine

└─ tracking/ ← new module

├─ tracking_orchestrator.R

├─ harmonisation.R

├─ trend_calculator.R

├─ excel_writer_tracking.R

├─ csv_json_exporter.R

├─ validation_tracking.R

└─ tests/

**⚙️ Input Configuration Files**

  -------------------------------------------------------------------------------
  **File**                    **Purpose**
  --------------------------- ---------------------------------------------------
  **tracking_config.xlsx**    Main run settings (waves, base wave, output
                              formats, thresholds, theme, locale).

  **question_mapping.xlsx**   Cross-wave mapping of questions/options.

  **derived_metrics.xlsx**    Definitions of computed metrics + continuity rules.

  **master_dictionary.csv**   Canonical variable registry (auto-updated).
  -------------------------------------------------------------------------------

**New required fields to parse:**

-   design_aware, stat_profile, render_style,

-   continuity_threshold, base_drift_threshold,

-   output_formats, theme_profile.

**📈 Core Processing Flow**

1.  **Load Configs** → validate using validation_tracking.R.

2.  **Load Waves** → read survey data files (xlsx/csv/sav).

3.  **Harmonise** → apply question_mapping.xlsx; build unified dataset
    keyed on TrackingCode.

4.  **Detect Changes** → flag new/retired questions, wording or scale
    changes.

5.  **Compute Metrics** → via shared turas.core:

    -   Weighted means, proportions.

    -   Change vs baseline.

    -   Effect sizes (effectsize pkg).

    -   Trend slope (lm).

    -   Significance tests (sig_test_dispatch()).

6.  **Generate Outputs** →

    -   Excel workbook (Summary, Trends, Continuity, Metadata).

    -   CSV/JSON long-format files + manifest.

7.  **Logging & QA** → write /logs/tracking_log.txt + Analyst Notes tab.

**🧩 Statistical Engine Integration**

All stats must come from **turas.core**, ensuring parity with Tabs.

**Supported test profiles:**

-   turas_standard -- internal defaults.

-   spss_like -- z/t tests, Bonferroni.

-   displayr_like -- adaptive tests + effect sizes.

**Optional R libraries:**

  -----------------------------------------------------------------------
  **Package**                            **Purpose**
  -------------------------------------- --------------------------------
  survey                                 design-aware SEs (optional).

  effectsize                             effect-size metrics.

  brolgar                                longitudinal trend helpers.

  lmtest, sandwich                       robust SEs for slopes.

  openxlsx, jsonlite, data.table         I/O + performance.
  -----------------------------------------------------------------------

Each library must be loaded conditionally; fallback to internal logic if
missing.

**🧪 Testing Protocol**

**Baseline Parity Test**

-   Run any wave as single-wave Tracking → output must equal Tabs output
    (identical cells, sig letters, p-values).

**Golden-Master Test**

-   Synthetic dataset with fixed p-values & effect sizes.

-   Use tests/golden_master.R for regression checking (fail CI if
    results drift).

**Continuity Test**

-   Mutate question text; hash mismatch must raise warning.

-   Simulate base drift \> threshold → expect ⚠ flag in metadata.

**🚀 Development Phases**

  --------------------------------------------------------------------------------
  **Phase**   **Weeks**   **Deliverables**
  ----------- ----------- --------------------------------------------------------
  0           2           Extract shared turas.core; parity tests pass.

  1           4           Wave loader, harmonisation, trend & change calculations.

  2           3           Continuity/base-drift reporting, effect sizes, manifest.

  3           2           CSV/JSON exporter, caching & incremental rebuilds.

  4           2           Optional design-aware mode (using survey pkg).
  --------------------------------------------------------------------------------

**📊 Output Expectations**

**Excel Workbook**

-   Sheets: *Summary*, *Trends*, *Continuity*, *Base Drift*, *Metadata*.

-   Formatting: identical to Tabs (use excel_formats.R).

**CSV/JSON**

-   Long-format (wave, banner, metric, value, p_value, sig_flag).

-   Manifest file: analysis_id, run_time, filters, waves.

**Metadata Tab**

-   Config snapshot, version hash, warnings, base drift %, continuity
    flags, runtime stats.

**🔒 Compliance & Quality**

-   Replace respondent IDs with hash before analysis.

-   No PII in outputs.

-   Locale-aware formatting (e.g., en_ZA).

-   Log everything (INFO, WARN, ERROR) → /logs/tracking_log.txt.

**🧠 Developer Tips**

-   Respect modularity: no stats logic inside writers.

-   Keep functions \<100 lines; use helpers with @keywords internal.

-   When adding a new metric:

    1.  Create helper in /modules/tracking/helpers/.

    2.  Register it in trend_calculator.R.

    3.  Add a line in derived_metrics.xlsx.

-   Test after every commit using test_runner_baseline.R.

**✅ Acceptance Criteria Summary**

1.  Single-wave parity with Tabs.

2.  All p-values and sig letters verified vs golden-master.

3.  Excel and CSV/JSON outputs identical in content.

4.  Warnings appear clearly in log & Metadata.

5.  10 000 × 10 waves runs \< 5 min.

6.  Visualisation team can consume CSV/JSON without re-schema.

**📅 Kick-Off Deliverables Checklist**

-    Core extraction complete.

-    tracking_config.xlsx template created.

-    Golden-master dataset built.

-    Validation + logger wired.

-    Dev branch set up with test harness.

Would you like me to generate the **tracking_config.xlsx
template** (with sample settings, annotated headers, and example
questions) as part of this pack next? It's a good developer-starter file
and ensures consistent testing.
