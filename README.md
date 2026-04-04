# TURAS Analytics Platform

Enterprise-grade modular analytics for market research. Built in R with a Shiny GUI.

Turas provides production-ready tools for survey analysis, tracking studies, segmentation, MaxDiff, Conjoint, pricing research, and advanced driver analysis. Developed by [The Research LampPost (Pty) Ltd](https://theresearchlamppost.com).

## Quick Start

```r
# 1. Restore dependencies
renv::restore()

# 2. Launch the platform
source("launch_turas.R")
launch_turas()
```

The Shiny launcher opens in your browser with a grid of all 12 analytical modules.

## Modules

| Module | Purpose |
|--------|---------|
| **AlchemerParser** | Parse Alchemer exports, generate configs, detect routing |
| **Tabs** | Cross-tabulation with significance testing |
| **Tracker** | Wave-over-wave longitudinal trend analysis |
| **Weighting** | Rim, cell, and design weighting |
| **Confidence** | Confidence intervals for proportions, means, NPS |
| **Key Driver** | Correlation-based importance (Shapley, SHAP, Elastic Net) |
| **Cat Driver** | Categorical driver analysis (logistic regression, SHAP) |
| **Conjoint** | Choice-based conjoint (HB estimation, market simulator) |
| **MaxDiff** | Best-worst scaling (HB and aggregate) |
| **Pricing** | Van Westendorp, Gabor-Granger, monadic pricing |
| **Segment** | K-means, hierarchical, and GMM clustering |
| **Report Hub** | Combine HTML reports into a branded portal |

Every module uses an **Excel configuration file** as its primary input.

## Documentation

| Document | Description |
|----------|-------------|
| [Operator Guide](OPERATOR_GUIDE.md) | Running modules, config format, stats packs |
| [Contributing](CONTRIBUTING.md) | Development workflow and code conventions |
| [Changelog](CHANGELOG.md) | Release history |
| Module READMEs | `modules/{module}/README.md` for each module |

## Architecture

```
launch_turas.R              # Shiny launcher (entry point)
modules/
  shared/                   # Common utilities, TRS, design system, pins JS
  {module}/
    R/ or lib/              # Source files (00_guard.R, 00_main.R, ...)
    tests/testthat/         # Module tests
    docs/                   # Module documentation
examples/                   # Working examples with sample data
tools/                      # Test runner, inventory, utilities
```

All modules follow the TRS (Turas Refusal System) v1.0 pattern for structured error handling. See `modules/shared/lib/trs_refusal.R`.

## Requirements

- R 4.0+
- Package dependencies managed via `renv` (see `renv.lock`)

## Test Suite

```r
# Run all tests (11,800+ across 15 modules)
source("tools/run_all_tests.R")

# Run a single module
Rscript tools/run_all_tests.R --module=tabs
```

## License

Proprietary. Copyright The Research LampPost (Pty) Ltd.
