# Turas Package Management with renv

This guide explains how Turas uses `renv` for reproducible R package management.

## Why renv?

Without dependency locking, R package updates can silently change:
- Statistical calculations (p-values, confidence intervals)
- Output formatting
- Function behavior

`renv` ensures everyone runs Turas with identical package versions, guaranteeing reproducible results across machines and time.

## Quick Start

### First Time Setup (After Cloning)

```r
# Open R in the Turas directory, then run:
renv::restore()
```

This installs all packages at the exact versions recorded in `renv.lock`.

### Daily Usage

No action needed! When you open R in the Turas directory, renv activates automatically.

## Common Commands

| Command | When to Use |
|---------|-------------|
| `renv::status()` | Check if packages are in sync with lockfile |
| `renv::restore()` | Install/update packages to match lockfile |
| `renv::snapshot()` | Update lockfile after adding packages |
| `renv::install("pkg")` | Install a new package |
| `renv::update()` | Update packages (then snapshot) |

## Workflows

### Installing a New Package

```r
# 1. Install the package
renv::install("newpackage")

# 2. Update the lockfile
renv::snapshot()

# 3. Commit renv.lock
# git add renv.lock && git commit -m "Add newpackage dependency"
```

### Updating Packages

```r
# Update all packages
renv::update()

# Or update specific package
renv::update("openxlsx")

# Save changes to lockfile
renv::snapshot()

# Test thoroughly before committing!
```

### Syncing After Git Pull

```r
# If renv.lock was updated by others
renv::restore()
```

## Maintenance Policy

Recommended schedule for Turas:

| Action | Frequency | Notes |
|--------|-----------|-------|
| `renv::status()` | Weekly | Check for drift |
| Package updates | Quarterly | Before major releases |
| Security patches | As needed | Critical vulnerabilities |

### Quarterly Update Process

1. Create a branch: `git checkout -b update-packages-2025Q1`
2. Update packages: `renv::update()`
3. Run all tests: `Rscript tests/regression/run_all_regression_tests.R`
4. Snapshot: `renv::snapshot()`
5. Review changes: `git diff renv.lock`
6. Commit and merge after testing

## Troubleshooting

### "Package not found" after clone

```r
renv::restore()
```

### Lockfile out of sync

```r
# Check what's different
renv::status()

# Option A: Update lockfile to match installed packages
renv::snapshot()

# Option B: Restore packages to match lockfile
renv::restore()
```

### renv not activating

Ensure `.Rprofile` exists and contains:
```r
source("renv/activate.R")
```

### Slow first restore

Normal! First `restore()` downloads all packages. Subsequent restores use the cache.

### Package installation fails

```r
# Try installing from source
renv::install("packagename", type = "source")

# Or check if dependencies are missing
renv::dependencies()
```

## Files Explained

| File | Purpose | Git Tracked? |
|------|---------|--------------|
| `renv.lock` | Package versions lockfile | Yes |
| `renv/activate.R` | Activation script | Yes |
| `renv/settings.json` | Project settings | Yes |
| `.Rprofile` | Auto-activates renv | Yes |
| `renv/library/` | Installed packages | No (local) |

## CI/CD Integration

For automated testing, add to your CI script:

```bash
# Install renv
Rscript -e "install.packages('renv')"

# Restore packages from lockfile
Rscript -e "renv::restore()"

# Run tests
Rscript tests/regression/run_all_regression_tests.R
```

## Initial Setup (One-Time, Maintainer Only)

To create the initial `renv.lock` (only needed once):

```r
# Initialize renv and create lockfile
renv::init()

# Or if renv structure exists but no lockfile:
renv::snapshot()
```

## Further Reading

- [renv Documentation](https://rstudio.github.io/renv/)
- [renv FAQ](https://rstudio.github.io/renv/articles/faq.html)
