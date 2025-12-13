# ADR-002: Shared Utilities Location

## Status
Accepted

## Context
Shared utilities exist in two locations:
- `/shared/` (root level) - 3 files
- `/modules/shared/lib/` - 4 files

This creates confusion about which to use and import.

## Decision
Consolidate to `/modules/shared/lib/` as the single source of truth.

### Consolidated Structure
```
/modules/shared/lib/
├── config_utils.R      # Config loading and settings
├── data_utils.R        # Data loading, type conversion
├── validation_utils.R  # Input validation
├── logging_utils.R     # Logging and progress
├── formatting_utils.R  # Number/Excel formatting
└── weights_utils.R     # Weight calculations
```

### Migration
- Root `/shared/` content merged into `/modules/shared/lib/`
- Root `/shared/` deprecated (kept temporarily for compatibility)
- Modules updated to import from single location

### Import Pattern
Modules should use relative path resolution:
```r
# At module entry point
turas_root <- find_turas_root()
source(file.path(turas_root, "modules/shared/lib/config_utils.R"))
```

## Consequences
- Single import location eliminates confusion
- Easier maintenance - one place to fix bugs
- Clear dependency chain
