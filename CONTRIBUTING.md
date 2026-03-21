# Contributing to TURAS

## Getting Started

1. Clone the repository
2. Run `renv::restore()` to install dependencies
3. Run `Rscript scripts/health_check.R` to verify the environment

## Development Workflow

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make changes following the conventions below
3. Run tests: `testthat::test_dir("tests/testthat")`
4. Run module-specific tests: `testthat::test_dir("modules/{module}/tests/testthat")`
5. Commit with descriptive message: `git commit -m "feat: description"`
6. Push and create a pull request

## Code Conventions

- **No `stop()` in module code** -- use TRS refusals (see `modules/shared/lib/trs_refusal.R`)
- **Functions under 100 lines** where feasible
- **All functions documented** with roxygen2 comments
- **No hardcoded paths** -- use `file.path()` and config files
- **Tests required** for new functionality

## Commit Message Format

```
<type>: <brief description>
```

Types: `feat`, `fix`, `test`, `docs`, `refactor`, `perf`, `chore`

## Module Structure

Every module follows the pattern:
```
modules/{module}/
  R/00_guard.R    -- Input validation
  R/00_main.R     -- Main orchestration
  R/01_*.R        -- Step files
  R/99_output.R   -- Output generation
  tests/          -- Tests
  README.md       -- Documentation
```

## Testing

- Use `testthat` framework
- Aim for 80%+ coverage
- Include edge case and error handling tests
- See `TESTING_GUIDE.md` for details

## Questions?

Contact Duncan Brett at The Research LampPost.
