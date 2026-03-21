# TURAS Examples Directory

This directory contains **example projects, validation scripts, and test data** that are separate from the formal test suite.

**Purpose:** Demonstrate TURAS usage, provide validation tools, and offer reference implementations.

---

## Directory Structure

### 📊 validation_scripts/
**Purpose:** Validation and debugging utilities for TURAS development

**Contents:**
- `compare_outputs.R` - Compare baseline vs modular output for validation
- `compare_functions.sh` - Compare function implementations across versions
- `test_bug_fixes.R` - Smoke tests for bug fix validation
- `run_tracker_debug.R` - Debug launcher for tracker module

**When to use:** During development to validate changes don't break existing functionality

### 📁 test_data/
**Purpose:** Example datasets and configurations for testing modules

**Contents:**
- `test_composite/` - Test data for composite scores module
- `conjoint_test_config.xlsx` - Conjoint module test configuration
- `conjoint_test_data.csv` - Conjoint test dataset
- `keydriver_test_config.xlsx` - Key driver module test configuration
- `keydriver_test_data.csv` - Key driver test dataset
- `generate_conjoint_test_data.R` - Script to generate test data
- `TEST_NEW_MODULES.md` - Guide for testing new modules

**When to use:** When learning a module or testing configurations before production use

### 📚 module_reviews/
**Purpose:** Complete module review packages with code, docs, and tests

**Contents:**
- `confidence_module_review/` - Complete confidence module review package
  - Core code implementations
  - Comprehensive documentation
  - UI and test scripts
  - Review checklist and technical summary

**When to use:** Reference implementation for understanding module architecture

---

## vs. /tests/ Directory

**examples/** (this directory):
- 🎯 Example projects and reference implementations
- 🛠️ Validation and debugging utilities
- 📊 Sample data for learning and testing
- 📚 Module review packages
- **Not run in CI/CD**

**tests/** (formal test suite):
- ✅ Formal unit tests using testthat framework
- 🔄 Run automatically in CI/CD
- 🎯 Test core functionality and edge cases
- **Production quality assurance**

---

## Quick Start

### Using Test Data

```r
# Example: Test conjoint module
setwd("/path/to/Turas")
source("modules/conjoint/run_conjoint.R")

# Use example test configuration
config_file <- "examples/test_data/conjoint_test_config.xlsx"
data_file <- "examples/test_data/conjoint_test_data.csv"
```

### Running Validation Scripts

```bash
# Compare outputs after making changes
cd examples/validation_scripts
Rscript compare_outputs.R

# Run smoke tests
Rscript test_bug_fixes.R
```

### Reviewing Module Architecture

```bash
# Study confidence module implementation
cd examples/module_reviews/confidence_module_review
cat README.md  # Read overview
cat TECHNICAL_SUMMARY.md  # Study architecture
```

---

## Adding New Examples

When adding new example projects or test data:

1. **Choose the right subdirectory:**
   - `validation_scripts/` for utilities
   - `test_data/` for datasets and configs
   - `module_reviews/` for complete review packages

2. **Include documentation:**
   - README.md explaining purpose
   - Comments in code
   - Example usage

3. **Keep it clean:**
   - No sensitive data
   - Use synthetic/example data
   - Follow TURAS coding standards

---

## Note

**These are examples and references** - not production code. For the formal test suite, see `/tests/` directory.

**Last Updated:** December 2, 2025
**TURAS Version:** 10.0
