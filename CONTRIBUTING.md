# Contributing to Turas

## Code Standards

### Follow ADRs
All development must follow the Architectural Decision Records in `/docs/adr/`:
- ADR-001: Module structure standard (use `lib/` pattern)
- ADR-002: Shared utilities location (`/modules/shared/lib/`)
- ADR-003: File size guidelines (max 800 lines for feature files)
- ADR-004: No hardcoded paths (use `find_turas_root()`)
- ADR-005: Error handling patterns

### File Organization
```
/modules/{module}/
├── README.md              # Required: Module overview
├── run_{module}.R         # Headless runner
├── run_{module}_gui.R     # Shiny launcher (if applicable)
└── lib/
    └── [feature files]    # Max 800 lines each
```

### Shared Utilities
Use consolidated shared utilities from `/modules/shared/lib/`:

```r
# Recommended: Single import
source(file.path(find_turas_root(), "modules/shared/lib/import_all.R"))

# Or individual files (respect dependency order)
source(file.path(turas_root, "modules/shared/lib/validation_utils.R"))
source(file.path(turas_root, "modules/shared/lib/config_utils.R"))
```

### Path Handling
Never hardcode paths. Always use dynamic resolution:

```r
# Good
turas_root <- find_turas_root()
data_path <- file.path(project_root, config$data_file)

# Bad - never do this
source("/Users/someone/Turas/modules/shared/lib/utils.R")
```

## Pull Request Process

1. **Create feature branch** from main
2. **Make changes** following code standards
3. **Run tests**: `Rscript tests/testthat.R`
4. **Update documentation** if APIs changed
5. **Submit PR** with description of changes

## Code Review Checklist

- [ ] No hardcoded paths
- [ ] No duplicated utility functions (use shared)
- [ ] File size under 800 lines (or justified)
- [ ] Tests included for new functionality
- [ ] Documentation updated
- [ ] Error messages are actionable

## Testing

### Running Tests
```r
# All tests
Rscript tests/testthat.R

# Regression tests
Rscript tests/regression/run_all_regression_tests.R

# Specific module
Rscript tests/testthat/test_shared_weights.R
```

### Writing Tests
- Place unit tests in `/tests/testthat/`
- Place regression tests in `/tests/regression/`
- Use descriptive test names
- Test edge cases (NA, empty, invalid input)

## Reporting Issues

Use GitHub Issues with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- R version and OS

## Questions?

See `/docs/` for additional documentation or open a discussion.
