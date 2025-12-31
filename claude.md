# Claude Code Guide for TURAS Analytics Platform

This file provides context and guidelines for Claude Code when working with the Turas R package.

---

## Project Overview

**TURAS** is an enterprise-grade, modular R-based analytics platform for market research developed by The Research LampPost (Pty) Ltd. It provides production-ready tools for survey analysis, tracking studies, segmentation, MaxDiff, Conjoint, and advanced driver analysis.

**Core Philosophy:**
- **Quality Mandate:** No mistakes, no risk. Every change must be tested before proceeding.
- **Clarity over cleverness** - Code should be readable and maintainable
- **Zero tolerance for untested changes** - All code must have tests
- **TRS v1.0 Compliance** - Structured refusal system instead of silent failures
- **Configuration over hardcoding** - All parameters externalized

**Current Status:** Production-ready (85/100 quality score)

### Deployment Context

**IMPORTANT:** Turas runs through a **Shiny application interface** (`launch_turas.R`). This has critical implications for error handling:

- **All error messages MUST appear in the console** - Users debug through the R console/terminal where the Shiny app is running
- **Never suppress errors** - Shiny can silently swallow errors if not properly handled
- **Use explicit console output** - Combine TRS refusals with `cat()` or `message()` for visibility
- **Structured logging** - Error details must be written to console for troubleshooting

**Error Handling Pattern for Shiny:**
```r
# When a TRS refusal occurs, also output to console
result <- some_function(data)
if (result$status == "REFUSED") {
  # Console output for debugging
  cat("\n=== TURAS ERROR ===\n")
  cat("Code:", result$code, "\n")
  cat("Message:", result$message, "\n")
  cat("Fix:", result$how_to_fix, "\n")
  cat("==================\n\n")

  # Return structured refusal
  return(result)
}
```

This ensures that when users run the Shiny app and encounter errors, they can see detailed diagnostic information in their console to understand and resolve issues.

---

## Architecture & Module Structure

### Core Modules (11 Total)

| Module | Purpose | Status | Quality Score |
|--------|---------|--------|---------------|
| **AlchemerParser** | Parse Alchemer exports, generate configs | Production | 90/100 |
| **catdriver** | Categorical driver analysis (SHAP, regression) | Production | 92/100 |
| **confidence** | Confidence intervals (Wilson, bootstrap, weighted) | Production | 90/100 |
| **conjoint** | Choice-based conjoint analysis (HB, utilities) | Production | 91/100 |
| **keydriver** | Key driver correlation analysis | Production | 93/100 |
| **maxdiff** | MaxDiff estimation (HB & aggregate) | Production | 90/100 |
| **pricing** | Price sensitivity & optimization | Production | 90/100 |
| **segment** | Clustering & segmentation | Production | 85/100 |
| **tabs** | Cross-tabulation & significance testing | Production | 85/100 |
| **tracker** | Longitudinal tracking & trend analysis | Production | 85/100 |
| **weighting** | Sample weighting & rim weighting | Production | 85/100 |
| **shared** | Common utilities (not counted in 11) | Utility | - |

### Standard Module Pattern

Every analytical module follows this structure:

```
modules/{module_name}/
├── 00_main.R           # Main orchestration function
├── 00_guard.R          # TRS guard layer - validates inputs
├── 01_*.R              # Step 1 processing
├── 02_*.R              # Step 2 processing
├── ...
├── 99_output.R         # Output generation (Excel/CSV/JSON)
├── tests/              # Module-specific tests
│   ├── testthat/       # Unit & integration tests
│   └── fixtures/       # Synthetic test data
└── README.md           # Module documentation
```

---

## Critical Systems & Conventions

### 1. TRS (Turas Refusal System) v1.0

**NEVER use `stop()` or silent failures.** Always use TRS refusals:

```r
# ❌ WRONG
if (missing(data)) {
  stop("Data is missing!")
}

# ✅ CORRECT
if (missing(data)) {
  return(list(
    status = "REFUSED",
    code = "DATA_MISSING",
    message = "Required parameter 'data' is missing",
    how_to_fix = "Provide a valid data frame to the 'data' parameter",
    context = list(call = sys.call())
  ))
}
```

**TRS Error Code Prefixes:**
- `IO_*` - File/input-output errors
- `DATA_*` - Data validation failures
- `CFG_*` - Configuration issues
- `CALC_*` - Calculation/statistical failures
- `PKG_*` - Missing package dependencies

### 2. Status System

All functions return structured lists with:
- `status`: "PASS" | "PARTIAL" | "REFUSED"
- `result`: The actual computation result (if status != REFUSED)
- `warnings`: Array of warning messages (for PARTIAL)
- Additional context fields

### 3. Guard Layers

Every module has a `00_guard.R` file that validates:
- Required parameters exist
- Data types are correct
- File paths are valid
- Dependencies are loaded
- Configuration is well-formed

**Always call guards BEFORE processing:**

```r
main_function <- function(data, config) {
  # Step 1: Guard
  guard_result <- guard_validate_inputs(data, config)
  if (guard_result$status == "REFUSED") {
    return(guard_result)
  }

  # Step 2: Process
  # ... your code ...
}
```

---

## Code Quality Standards

### Style & Structure

1. **Use `styler::style_file()`** for consistent formatting
2. **Functions < 100 lines** where feasible (single responsibility)
3. **Roxygen2 documentation** for all exported functions
4. **No hardcoded paths** - use `file.path()` and config files
5. **Clear variable names** - `survey_data` not `sd`

### Documentation Requirements

Every function must have:

```r
#' Brief One-Line Description
#'
#' Longer description explaining what the function does,
#' when to use it, and any important caveats.
#'
#' @param data A data frame containing survey responses
#' @param config A list with configuration parameters
#'
#' @return A list with structure:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{result}{The computed result (if status != REFUSED)}
#'   \item{message}{Description of outcome}
#'
#' @examples
#' \dontrun{
#'   result <- my_function(survey_data, my_config)
#'   if (result$status == "PASS") {
#'     print(result$result)
#'   }
#' }
#'
#' @export
```

### Error Messages

Error messages must be:
- **Specific** - What went wrong?
- **Actionable** - How to fix it?
- **Contextual** - Where did it happen?
- **Console-visible** - Always output to console for Shiny debugging

```r
# ❌ BAD
"Invalid data"

# ✅ GOOD
sprintf(
  "Column '%s' contains %d missing values. Maximum allowed is %d. Remove rows with NA or impute missing values.",
  col_name, n_missing, max_allowed
)
```

### Shiny-Specific Error Handling

Since Turas runs in a Shiny app, error visibility is critical:

```r
# ✅ CORRECT - Console output + TRS refusal
handle_error <- function(result, context = "") {
  if (result$status == "REFUSED") {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Context:", context, "\n")
    cat("│ Code:", result$code, "\n")
    cat("│ Message:", result$message, "\n")
    cat("│ How to fix:", result$how_to_fix, "\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")

    # Also show in Shiny UI if available
    if (exists("showNotification", mode = "function")) {
      showNotification(
        paste(result$code, "-", result$message),
        type = "error",
        duration = NULL
      )
    }
  }
  return(result)
}

# Usage in module
result <- some_calculation(data)
result <- handle_error(result, context = "Tabs Module: Calculate crosstabs")
if (result$status == "REFUSED") return(result)
```

**Best Practices for Shiny:**
1. **Always write to console** - Use `cat()` or `message()` for all errors
2. **Use structured formatting** - Box formatting helps errors stand out in console
3. **Include context** - Which module, which step, what operation
4. **Show in UI too** - Use `showNotification()` for user feedback
5. **Never use silent returns** - Every error must be visible somewhere

---

## Testing Requirements

### Test Coverage Goals

- **Minimum:** 80% code coverage
- **Current:** ~60% (varies by module)
- **Target:** 90%+ for production modules

### Test Structure

Every module should have:

```
modules/{module}/tests/
├── testthat/
│   ├── test_core_functionality.R      # Happy path tests
│   ├── test_edge_cases.R              # Edge cases & boundaries
│   ├── test_error_handling.R          # TRS refusals
│   ├── test_integration.R             # Cross-function tests
│   └── test_performance.R             # Speed & memory benchmarks
└── fixtures/
    └── synthetic_data/
        ├── generate_test_data.R       # Data generator
        └── README.md                  # Data documentation
```

### Required Test Categories

1. **Unit Tests** - Individual functions in isolation
2. **Integration Tests** - Multiple functions working together
3. **Edge Case Tests** - Boundaries, NAs, empty data, large datasets
4. **Golden File Tests** - Compare outputs to known-good results
5. **Performance Tests** - Ensure reasonable speed/memory usage

### Writing Tests

Use `testthat` framework:

```r
test_that("confidence intervals handle weighted data correctly", {
  # Arrange
  data <- generate_weighted_sample(n = 100, weights = runif(100, 0.5, 2))

  # Act
  result <- calculate_confidence(data, method = "wilson")

  # Assert
  expect_equal(result$status, "PASS")
  expect_true(result$result$lower < result$result$upper)
  expect_true(result$result$estimate >= 0 && result$result$estimate <= 1)
})
```

**See:** `TESTING_GUIDE.md` for comprehensive testing documentation

---

## Dependencies & Package Management

### Core Dependencies

The project uses `renv` for reproducible package management.

**Key Packages:**
- `data.table` - Fast data manipulation
- `openxlsx` - Excel I/O without Java dependencies
- `survey` - Design-aware variance estimation
- `effectsize` - Standardized effect sizes
- `ChoiceModelR` - Conjoint/MaxDiff HB estimation
- `ordinal` - Ordinal regression (for MaxDiff)
- `shapr` - SHAP values for driver analysis
- `fastDummies` - Efficient dummy variable creation

### Adding New Dependencies

1. **Check if it exists:** Look in `renv.lock` first
2. **Justify the addition:** Document why it's needed
3. **Use `renv::install()`** to add
4. **Update `renv.lock`** with `renv::snapshot()`
5. **Test compatibility** across R versions (4.0+)
6. **Document in module README**

### Avoiding Dependency Bloat

- Prefer base R when performance difference is negligible
- Use `requireNamespace()` for optional features
- Consider vendoring small utility functions instead of adding packages

---

## File I/O Conventions

### Excel Files

**Always use `openxlsx`** (not `readxl` for writing, not `xlsx` which requires Java):

```r
# Reading
data <- openxlsx::read.xlsx("input.xlsx", sheet = 1)

# Writing with formatting
wb <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb, "Results")
openxlsx::writeData(wb, "Results", data)
openxlsx::addStyle(wb, "Results",
  style = openxlsx::createStyle(fontName = "Arial", fontSize = 11),
  rows = 1, cols = 1:10, gridExpand = TRUE
)
openxlsx::saveWorkbook(wb, "output.xlsx", overwrite = TRUE)
```

### CSV Files

Use `data.table::fwrite()` for fast, reliable CSV output:

```r
data.table::fwrite(results, "output.csv", row.names = FALSE)
```

### JSON Output

Use `jsonlite` with pretty printing for human-readable output:

```r
jsonlite::write_json(
  results,
  "output.json",
  pretty = TRUE,
  auto_unbox = TRUE,
  digits = 4
)
```

### File Paths

**NEVER hardcode paths.** Use:

```r
# ✅ GOOD - Relative to project root
input_path <- file.path("examples", "tabs", "basic", "survey_data.csv")

# ✅ GOOD - From config
output_path <- file.path(config$output_dir, config$output_filename)

# ❌ BAD - Hardcoded absolute path
"/Users/duncan/Documents/Turas/examples/data.csv"
```

---

## Git & Version Control

### Branch Strategy

- `main` - Production-ready code only
- `feature/<name>` - New features
- `fix/<name>` - Bug fixes
- `test/<name>` - Test infrastructure improvements
- `docs/<name>` - Documentation updates

### Commit Message Format

```
<type>: <brief description>

<optional longer description>

<optional context/rationale>
```

**Types:** `feat`, `fix`, `test`, `docs`, `refactor`, `perf`, `chore`

**Examples:**
```
feat: Add bootstrap confidence intervals to confidence module

Implements bias-corrected and accelerated (BCa) bootstrap method
for confidence intervals. Handles weighted data correctly.

Closes #42
```

```
fix: Handle NA values in weighting rim weight calculation

Previous version would fail silently when NA values present
in weighting variables. Now explicitly checks and returns
TRS refusal with actionable error message.
```

### Pre-Commit Checklist

Before committing:
- [ ] Run relevant tests: `testthat::test_dir("modules/{module}/tests")`
- [ ] Check code style: `styler::style_file("{file}.R")`
- [ ] Verify documentation: `roxygen2::roxygenise()`
- [ ] No hardcoded paths or credentials
- [ ] TRS compliance (no `stop()` calls)

### Pre-PR Checklist

Before creating a pull request:
- [ ] All tests pass (run regression suite)
- [ ] New tests added for new functionality
- [ ] Documentation updated (README, roxygen)
- [ ] No merge conflicts with main
- [ ] Code reviewed locally
- [ ] CHANGELOG.md updated (if applicable)

---

## Common Tasks & How-Tos

### Adding a New Module

1. **Create directory structure:**
   ```r
   dir.create("modules/new_module")
   dir.create("modules/new_module/tests/testthat")
   dir.create("modules/new_module/tests/fixtures/synthetic_data")
   ```

2. **Create core files:**
   - `00_guard.R` - Input validation
   - `00_main.R` - Main orchestration
   - `01_calculate.R` - Core logic
   - `99_output.R` - Output generation

3. **Add tests:**
   - Create test files following naming convention
   - Generate synthetic test data
   - Aim for 80%+ coverage

4. **Document:**
   - Add roxygen2 docs to all functions
   - Create module README.md
   - Add examples to `/examples/new_module/`

### Modifying Existing Modules

1. **Read the code first** - Understand current implementation
2. **Check for tests** - Look in `tests/` directory
3. **Run existing tests** - Ensure they pass before changes
4. **Make changes** - Follow TRS conventions
5. **Update tests** - Add new tests for new behavior
6. **Update docs** - Keep roxygen2 and README in sync

### Adding New Statistical Methods

1. **Research the method** - Ensure it's appropriate
2. **Check for R packages** - Don't reinvent the wheel
3. **Implement with TRS** - Handle all failure modes
4. **Validate against known results** - Use published examples
5. **Add comprehensive tests** - Edge cases matter
6. **Document assumptions** - Make limitations clear

### Debugging

1. **Check TRS messages** - Start with refusal messages
2. **Use `browser()`** - Set breakpoints for interactive debugging
3. **Print intermediate results** - Use `cat()` or `message()`
4. **Check data structure** - `str(data)` often reveals issues
5. **Simplify** - Test with minimal reproducible example

---

## Performance Considerations

### Data Manipulation

- **Prefer `data.table`** for large datasets (>10k rows)
- **Use vectorization** instead of loops where possible
- **Pre-allocate** vectors/lists when size is known
- **Avoid repeated column access** - assign to variable once

```r
# ❌ SLOW
for (i in 1:nrow(data)) {
  data$result[i] <- data$value[i] * 2
}

# ✅ FAST
data$result <- data$value * 2

# ✅ EVEN FASTER (data.table)
DT[, result := value * 2]
```

### Memory Management

- **Use `gc()`** after processing large objects
- **Remove intermediate objects** with `rm()`
- **Consider chunking** for very large datasets
- **Monitor memory** with `pryr::mem_used()`

### Benchmarking

Use `microbenchmark` for performance testing:

```r
microbenchmark::microbenchmark(
  base_r = sum(x^2),
  vectorized = crossprod(x)[1],
  times = 1000
)
```

---

## Troubleshooting Common Issues

### "Package X is not available"

1. Check `renv.lock` - is it listed?
2. Try `renv::restore()` to sync packages
3. If missing, install: `renv::install("package_name")`
4. Update lock file: `renv::snapshot()`

### "Error in openxlsx::read.xlsx"

- Check file path is correct (use `file.exists()`)
- Ensure file is valid Excel format (.xlsx not .xls)
- Check sheet name matches exactly (case-sensitive)

### "TRS refusal: DATA_INVALID"

- Read the `how_to_fix` field in the refusal message
- Check the `context` field for details
- Validate input data structure with `str()`

### Tests Failing After Changes

1. Read test output carefully
2. Check if expected behavior changed (update tests if intentional)
3. Use `testthat::test_file()` to run single test file
4. Add `browser()` in test to debug interactively

### "Error occurred but I can't see details in Shiny"

**This is why console output is mandatory!**

1. Check the R console where you launched the Shiny app
2. Look for boxed error messages (TURAS ERROR format)
3. If no console output visible, add explicit `cat()` statements
4. Never rely solely on Shiny's error display - it can suppress details
5. Use the error handling pattern shown in "Shiny-Specific Error Handling" section

---

## Resources & Documentation

### Key Documents

- `README.md` - Project overview and getting started
- `TURAS_COMPREHENSIVE_ANALYSIS.md` - Detailed module analysis
- `TESTING_GUIDE.md` - Testing framework and best practices
- `STATISTICAL_VALIDATION_AND_PACKAGE_REFERENCE.md` - Statistical methods
- `DEPENDENCY_RESOLUTION_GUIDE.md` - Package management
- `QUICK_LAUNCH.md` - Quick start guide

### Module Documentation

Each module has:
- `modules/{module}/README.md` - Module-specific guide
- Roxygen2 docs in code - Function-level documentation
- `examples/{module}/` - Working examples with sample data

### External References

- [data.table documentation](https://rdatatable.gitlab.io/data.table/)
- [openxlsx documentation](https://ycphs.github.io/openxlsx/)
- [testthat documentation](https://testthat.r-lib.org/)
- [ChoiceModelR vignette](https://CRAN.R-project.org/package=ChoiceModelR)

---

## When Working with Claude Code

### What Claude Should Do

✅ **Always:**
- Read existing code before making changes
- Run tests before and after modifications
- Use TRS refusal pattern (never `stop()`)
- **Add console output for all errors** - Remember: Turas runs in Shiny, errors must be visible in console
- Follow existing code style and patterns
- Add tests for new functionality
- Update documentation when changing behavior
- Ask clarifying questions if requirements are ambiguous

✅ **For new features:**
- Check if similar functionality exists
- Review relevant module's code structure
- Create tests alongside implementation
- Add examples to demonstrate usage
- Update module README

✅ **For bug fixes:**
- Create failing test that reproduces bug
- Fix the issue
- Verify test now passes
- Check for similar issues in related code

### What Claude Should NOT Do

❌ **Never:**
- Make changes without reading the code first
- Skip writing tests ("I'll add them later")
- Use `stop()` instead of TRS refusals
- Add dependencies without justification
- Hardcode file paths or credentials
- Disable tests to make them pass
- Make "improvements" beyond what was requested
- Add features not explicitly requested

❌ **Avoid:**
- Over-engineering simple solutions
- Premature optimization
- Breaking existing APIs without migration path
- Adding dependencies for trivial functionality

### Asking for Help

When you need clarification:
- Explain what you understand so far
- List the options you're considering
- Explain tradeoffs of each option
- Ask specific questions

**Example:**
"I see two approaches for adding bootstrap CIs:
1. Use the `boot` package (simpler, well-tested)
2. Implement from scratch (more control, no dependency)

The `boot` package would be faster to implement and more reliable. Is adding this dependency acceptable, or should I implement manually?"

---

## Project-Specific Preferences

### Duncan's Preferences (Project Owner)

1. **Quality over speed** - Correct, tested code is more important than fast delivery
2. **Explicit over implicit** - Clear, verbose code beats clever shortcuts
3. **Real-world ready** - All code should be production-ready, not prototypes
4. **Documentation matters** - Code without docs is incomplete
5. **No silent failures** - Always use TRS to communicate problems
6. **Test everything** - Untested code is broken code
7. **Reuse over reinvent** - Use existing R packages when suitable

### Decision-Making Authority

For decisions about:
- **Adding dependencies** - Ask first if non-standard package
- **Changing existing APIs** - Discuss breaking changes
- **Major architectural changes** - Definitely get approval
- **Bug fixes** - Proceed with tests and documentation
- **Minor improvements** - Use judgment, but stay focused

---

## Quick Reference Commands

### Testing
```r
# Run all tests for a module
testthat::test_dir("modules/confidence/tests")

# Run specific test file
testthat::test_file("modules/confidence/tests/testthat/test_proportion_ci.R")

# Run with coverage
covr::package_coverage(type = "tests", code = "testthat::test_dir('modules/confidence/tests')")
```

### Code Quality
```r
# Format code
styler::style_file("modules/confidence/01_calculate.R")

# Lint code
lintr::lint("modules/confidence/01_calculate.R")

# Generate documentation
roxygen2::roxygenise()
```

### Package Management
```r
# Restore packages from lockfile
renv::restore()

# Install new package
renv::install("package_name")

# Update lockfile
renv::snapshot()

# Check for updates
renv::status()
```

### Launch GUI
```r
# Main launcher
source("launch_turas.R")
launch_turas()

# Specific module
source("modules/tabs/00_main.R")
# ... use module functions
```

---

## Contact & Support

**Project Owner:** Duncan Brett (The Research LampPost Pty Ltd)

**For questions about:**
- Architecture decisions → Ask in context
- Statistical methods → Check module documentation first
- Testing approach → See TESTING_GUIDE.md
- Dependencies → See DEPENDENCY_RESOLUTION_GUIDE.md

---

**Remember:** If it's not tested, it doesn't ship. Quality over speed, always.
