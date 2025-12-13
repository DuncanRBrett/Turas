# ADR-004: No Hardcoded Paths

## Status
Accepted

## Context
Hardcoded paths break portability across machines and environments.

## Decision
All paths must be resolved dynamically:

### Allowed Patterns
```r
# Resolve from config file location
project_root <- dirname(config_path)
data_path <- file.path(project_root, config$data_file)

# Resolve from script location
script_dir <- dirname(sys.frame(1)$ofile)

# Use find_turas_root() for module imports
turas_root <- find_turas_root()
source(file.path(turas_root, "modules/shared/lib/utils.R"))
```

### Forbidden Patterns
```r
# Never do this
source("/Users/duncan/Turas/modules/shared/lib/utils.R")
data <- read.csv("C:\\Projects\\data.csv")
```

### Path Resolution
The `find_turas_root()` function walks up the directory tree looking for Turas markers (README.md, modules/ directory).

## Consequences
- Code portable across machines
- Works in different deployment contexts
- Config files control all external paths
