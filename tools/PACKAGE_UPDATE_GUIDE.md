# Turas Package Update Guide

## Why This Matters

Turas uses `renv` to lock R package versions so the platform behaves identically
across machines and over time. **Updating a package without testing can break
production code** — even minor version bumps can change function signatures.

**Real example (March 2026):** The `domir` package changed its `domin()` API
between versions — a required argument (`fitstat`) was added. The KeyDriver
dominance analysis silently failed (returned PARTIAL instead of PASS) because
the old function call no longer worked. This went undetected until the full
test suite was run.

---

## Quick Reference

| Task | Command |
|------|---------|
| Check current state | `renv::status()` |
| Lock current packages | `renv::snapshot()` |
| Restore from lock file | `renv::restore()` |
| Update one package | `Rscript tools/safe_package_update.R <package>` |
| Update all packages | `Rscript tools/safe_package_update.R --all` |

---

## Golden Rules

1. **Never run `renv::update()` directly** — use the safe update script
2. **Always run tests after any package change** — `Rscript tools/run_all_tests.R`
3. **Snapshot after confirmed success** — `renv::snapshot()` locks the working state
4. **Commit `renv.lock` to git** — it's your safety net for rollback

---

## Step-by-Step: Updating a Single Package

```r
# 1. Check what you have now
renv::status()

# 2. Use the safe update script (runs tests automatically)
# From terminal:
Rscript tools/safe_package_update.R domir

# 3. If all tests pass, the script snapshots automatically
# If tests fail, it rolls back automatically

# 4. Commit the updated renv.lock
git add renv.lock
git commit -m "chore: update domir to vX.Y.Z"
```

## Step-by-Step: Fresh Setup / Restore

When setting up on a new machine or after a git pull:

```r
# Restore exact package versions from renv.lock
renv::restore()

# Verify everything works
source("tools/run_all_tests.R")
```

---

## Fixing "Out of Sync" State

If `renv::status()` shows inconsistencies:

```r
# Option 1: Snapshot current working state (if tests pass)
renv::snapshot()

# Option 2: Restore to last known good state (if things are broken)
renv::restore()
```

**Before snapshotting:**
1. Run the full test suite: `Rscript tools/run_all_tests.R`
2. Confirm 0 failures
3. Then snapshot: `renv::snapshot()`
4. Commit `renv.lock`

---

## Troubleshooting

### "Package X is not available"
```r
renv::install("X")       # Install it
renv::snapshot()         # Lock it
```

### "Function Y not found after update"
The package API changed. Options:
1. Roll back: `renv::restore()` (restores from renv.lock)
2. Fix code to match new API, then `renv::snapshot()`

### "Tests pass locally but fail on another machine"
The other machine has different package versions.
```r
# On the other machine:
renv::restore()   # Sync to renv.lock
```

### renv::status() is very slow
Add a `.renvignore` file to skip scanning irrelevant directories:
```
# Already handled in .renvignore
examples/
docs/
*.html
*.css
*.js
```

---

## Schedule

**Recommended cadence:**
- **Monthly:** Run `Rscript tools/safe_package_update.R --check` to see available updates
- **Quarterly:** Update packages one at a time using the safe update script
- **Before any release:** Run full test suite and confirm renv.lock is committed

---

## Files

| File | Purpose |
|------|---------|
| `renv.lock` | The lock file — commit this to git |
| `renv/` | Local package library (gitignored) |
| `.Rprofile` | Auto-activates renv on project load |
| `tools/safe_package_update.R` | Safe update script with auto-rollback |
| `tools/PACKAGE_UPDATE_GUIDE.md` | This document |
