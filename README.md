# TURAS Analytics Platform

**Author:** The Research LampPost (Pty) Ltd  
**Language:** R  
**Status:** Active Development  
**Core Modules:** Parser · Tabs · Tracking · Segmentation · MaxDiff · Conjoint · Driver Analysis

> **Quality Mandate — No Mistakes, No Risk.**  
> **Every change MUST be thoroughly tested _before_ it proceeds.** Do not merge or release without green tests, code review approval, and checklist sign‑off.

---

## 🌍 Overview
**TURAS** is a modular R-based analytics platform for market research. It supports single-survey tabulations and scales to longitudinal tracking, segmentation, MaxDiff, Conjoint, and driver analysis — with a future visualization layer.

The system is:
- **Generic & reusable** (works across projects/clients)
- **Clear & well documented** (roxygen docs, comments, examples)
- **Modular & lean** (single responsibility per file)
- **Maintainable & scalable** (config-driven, minimal coupling)
- **High standard** (code reviews, CI, regression tests)

---

## 🧠 Core Philosophy
- Clarity over cleverness.
- Shared core functions, no duplication.
- Configuration over hardcoding.
- Deterministic outputs, reproducible pipelines.
- **Zero‑tolerance for untested changes.**

---

## 🧩 Current Architecture

| Module | Purpose |
|---|---|
| **Parser** | Input validation; reads survey structure and sets up metadata. |
| **Tabs** | Single-wave analysis (weighted crosstabs, nets, sig tests, Excel/CSV). |
| **Tracking** *(in dev)* | Multi-wave harmonisation, continuity checks, trend/change. |
| **Segmentation** *(planned)* | Clustering/latent class; profiles. |
| **MaxDiff** *(planned)* | HB & aggregate estimation. |
| **Conjoint** *(planned)* | CBC/ACA estimation & simulators. |
| **Driver Analysis** *(planned)* | Key driver modelling (regression/correlation). |
| **Visualization/Dashboards** *(future)* | ggplot/Plotly + BI connectors. |

**Shared Core (`turas.core`):** weights/effective‑n, nets (Top/Bottom/NET+), significance dispatch, banner builder, Excel formats.

---

## 🏗️ Directory Layout
```
/turas/
 ├─ core/                   # Shared functions (weights, sig tests, nets, formatting)
 ├─ parser/                 # Input validation and metadata setup
 ├─ tabs/                   # Single-wave module
 ├─ tracking/               # Multi-wave tracking module
 ├─ segmentation/           # (Future) clustering & profiles
 ├─ maxdiff/                # (Future) MaxDiff estimation
 ├─ conjoint/               # (Future) Conjoint estimation
 ├─ driver_analysis/        # (Future) Importance modelling
 ├─ viz/                    # (Future) Visualisation layer
 ├─ tests/
 │   └─ regression/         # Regression test harness (8 modules, 67 checks)
 │       ├─ run_all_regression_tests.R
 │       ├─ test_tabs.R
 │       ├─ test_confidence.R
 │       ├─ test_keydriver.R
 │       ├─ test_alchemer_parser.R
 │       ├─ test_segment.R
 │       ├─ test_conjoint.R
 │       ├─ test_pricing.R
 │       ├─ test_tracker.R
 │       ├─ helpers/        # Path resolution, assertions, extractors
 │       ├─ mocks/          # Mock implementations for testing
 │       └─ golden/         # Known-good outputs (JSON)
 ├─ examples/               # Test data and configs for all modules
 ├─ templates/              # Config templates (working + annotated)
 └─ docs/                   # Specs, templates, manuals
```

---

## 🚀 Getting Started
1. **Install dependencies:**
   ```r
   install.packages(c("data.table","openxlsx","jsonlite","effectsize","survey","brolgar","ggplot2"))
   ```
2. **Run Parser:**
   ```r
   source("parser/run_parser.R")
   ```
3. **Run Tabs or Tracking:**
   ```r
   source("tabs/run_tabs.R")
   source("tracking/run_tracking.R")
   ```
4. **Outputs:** `/output/` (Excel, CSV/JSON).

---

## 🧮 Reuse Existing R Libraries
Use proven libraries — do not reinvent:
- **survey** (design-aware variance; optional)
- **data.table** (fast manipulation)
- **effectsize** (effect sizes)
- **brolgar** (longitudinal helpers)
- **lmtest**, **sandwich** (robust SEs)
- **openxlsx** (Excel)
- **jsonlite** (JSON)
- **ggplot2** (future viz)

---

## 🧾 Code Quality Expectations
- Consistent style (`styler::style_file()`)
- Roxygen docs for every exported function
- Functions < 100 lines where feasible; single-responsibility
- No hardcoded paths; config-driven
- Clear error messages; no silent failures
- Logging with levels: `INFO`, `WARN`, `ERROR`

---

## 🧪 Regression Testing

**Run all regression tests with one command:**
```r
source("tests/regression/run_all_regression_tests.R")
```

**Test Coverage (67 assertions across 8 modules):**
- ✅ **Tabs** (10 checks) — crosstabs, weights, significance
- ✅ **Confidence** (12 checks) — intervals, methods, coverage
- ✅ **KeyDriver** (5 checks) — correlation, importance scores
- ✅ **AlchemerParser** (6 checks) — survey structure, metadata
- ✅ **Segment** (7 checks) — clustering, profiles
- ✅ **Conjoint** (9 checks) — utilities, simulations
- ✅ **Pricing** (7 checks) — elasticity, optimization
- ✅ **Tracker** (11 checks) — continuity, trends, base drift

**Golden-master pattern:** Each module has example data and known-good outputs (JSON). Tests verify outputs match within tolerance.

**Configuration:** All modules include working config templates (`examples/{module}/basic/`) for realistic testing scenarios.

**Documentation:** See `tests/regression/REGRESSION_TEST_SYSTEM_COMPLETE.md` for full implementation details.

---

## ✅ Testing & Release Policy (MANDATORY)

> **No code merges or releases without all checks green.**

**Pre‑commit (local):**
- Run regression tests: `source("tests/regression/run_all_regression_tests.R")`
- Run `lintr`/style checks.
- Verify all 67 assertions pass before committing.

**CI (required to merge):**
- Build succeeds across supported R versions.
- **All regression tests pass** (67/67 checks green).
- Performance check: large sample (≥10k×200 vars) completes under agreed time budget.
- Artifacts saved: logs, metadata sheets, outputs for diffing.

**Pre‑release checklist (maintainer):**
- Version bumped (`core_version`, module version).
- CHANGELOG updated.
- Config templates validated.
- Any new feature toggled by config (safe default OFF).

**Release gate:**
- Code review approval by a senior reviewer.
- All CI checks green.
- Manual smoke test on a real (non‑sensitive) project.

**Rollback policy:**
- Releases must be reversible (tag + previous artifacts stored).
- If regression detected, revert immediately and open a hotfix branch.

---

## 🧭 Roadmap
- **Now:** Tracking (continuity, base drift, trend diagnostics)
- **Next:** Segmentation
- **Later:** MaxDiff → Conjoint → Driver Analysis
- **Future:** Visualization & dashboards (CSV/JSON long-format is already supported)

---

## 📚 Documentation
- Specs and templates in `/docs/`
- Config examples: `tracking_config.xlsx`, `question_mapping.xlsx`, `derived_metrics.xlsx`, `master_dictionary.csv`
- Developer guides: Tabs/Tracking briefs, Kick‑off Pack

---

## 🤝 Contributing (optional template)
- Branch from `feature/<name>`
- Add tests & docs with each change
- Open PR with a clear description and screenshots/samples
- Do **not** disable tests to merge

---

## 📣 Contact
For architecture or release approvals, contact **Duncan Brett** (The Research LampPost).

---

**Reminder:** _If it’s not tested, it does not ship._
