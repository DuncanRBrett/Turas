# ADR-001: Module Structure Standard

## Status
Accepted

## Context
Turas modules have evolved with inconsistent directory structures:
- Some use `R/` subdirectories (Conjoint, Confidence, Pricing, MaxDiff, AlchemerParser)
- Some use `lib/` subdirectories (Tabs, Segment)
- Some have flat structure (Tracker)

This creates navigation confusion and inconsistent patterns.

## Decision
Standardize on `lib/` pattern for new modules. Existing modules retain their structure but new development follows these conventions:

### Required Files
```
/modules/{module}/
├── README.md              # Module overview (required)
├── run_{module}.R         # Headless runner
└── lib/                   # (or R/ for existing modules)
    └── [feature files]
```

### File Naming
- Use descriptive names reflecting functionality
- Avoid generic names like `shared_functions.R`
- Keep files under 800 lines where practical

## Consequences
- New modules follow consistent pattern
- Existing modules not disrupted
- Navigation becomes predictable
