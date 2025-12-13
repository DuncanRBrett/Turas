# ADR-003: File Size Guidelines

## Status
Accepted

## Context
Several files exceed 1,500 lines, making them harder to navigate and maintain:
- `tracker/trend_calculator.R` (2,690 lines)
- `tracker/tracker_output.R` (2,178 lines)
- `tabs/lib/validation.R` (1,838 lines)
- `tabs/lib/shared_functions.R` (1,779 lines)

## Decision
Establish guidelines for file sizes:

| Category | Max Lines | Rationale |
|----------|-----------|-----------|
| Orchestration (main.R, run_*.R) | 500 | High-level only |
| Feature files | 800 | Single responsibility |
| Utility files | 400 | Small, focused |
| Test files | 600 | Keep tests readable |

### When to Split
- File exceeds guideline AND has multiple distinct responsibilities
- Natural seams exist between functionality
- Different parts have different change frequencies

### When NOT to Split
- File is cohesive despite size
- Splitting would create artificial boundaries
- No clear responsibility separation exists

## Consequences
- Guidelines, not hard rules
- Split during natural maintenance, not as emergency
- Prioritize cohesion over arbitrary line counts
