# Test Projects

This directory contains test projects, utilities, and validation scripts that are separate from the main TURAS codebase.

## Contents

### Test Directories
- **test_composite/** - Test data for composite scores module testing
- **test_data/** - Test configurations and data for conjoint and keydriver modules  
- **confidence_module_review/** - Complete confidence module review package (code, docs, examples, tests)

### Validation Scripts
- **test_bug_fixes.R** - Bug fix validation script (smoke tests)
- **compare_outputs.R** - Utility to compare baseline vs modular outputs
- **compare_functions.sh** - Function comparison utility
- **run_tracker_debug.R** - Debug launcher for tracker module

## Note
The formal test suite remains in `/tests/` directory (using testthat framework).
