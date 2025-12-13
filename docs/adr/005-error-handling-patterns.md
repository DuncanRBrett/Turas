# ADR-005: Error Handling Patterns

## Status
Accepted

## Context
Consistent error handling improves debugging and user experience.

## Decision
Standardize error handling across modules:

### Error Messages
Use informative, actionable error messages:
```r
stop(sprintf(
  "Required column '%s' not found in data\n\nAvailable columns:\n  %s",
  column_name,
  paste(head(names(data), 10), collapse = "\n  ")
), call. = FALSE)
```

### Validation at Boundaries
Validate inputs at function entry points:
```r
function(data, config) {
  # Validate immediately
  if (!is.data.frame(data)) {
    stop("data must be a data frame", call. = FALSE)
  }
  # ... proceed with validated inputs
}
```

### Use Shared Validators
Prefer shared validation functions:
```r
validate_data_frame(data, required_cols = c("id", "value"))
validate_file_path(path, must_exist = TRUE)
validate_numeric_param(threshold, "threshold", min = 0, max = 1)
```

### Graceful Degradation
Where appropriate, warn instead of stop:
```r
if (nrow(subset) == 0) {
  warning("No data matches filter criteria")
  return(empty_result())
}
```

## Consequences
- Consistent user experience
- Easier debugging with actionable messages
- Validation catches issues early
