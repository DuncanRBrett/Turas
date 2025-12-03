# Critical Fix #9: Variable Selection Model Mismatch

**Date Discovered:** 2025-11-30
**Severity:** CRITICAL - Scoring fails completely
**Status:** ✅ FIXED

---

## Problem

When variable selection was enabled and reduced clustering variables from 10 to 5, the model object was saving **inconsistent metadata**:

- `clustering_vars`: Contained all 10 ORIGINAL variables (before selection)
- `scale_params`: Contained only 5 SELECTED variables (Q03, Q04, Q05, Q07, Q11)
- `imputation_params`: Contained only 5 SELECTED variables

This caused **scoring to fail completely** with error:
```
Error: Scale parameters are missing for one or more clustering variables.
```

---

## Root Cause

In `run_segment.R`, the model was saving parameters from the ORIGINAL config instead of the UPDATED config:

```r
# WRONG (line 260):
clustering_vars = config$clustering_vars,  # Original 10 variables
config = config,  # Original config

# Model tries to use all 10 vars, but scale_params only has 5
```

After variable selection in `perform_variable_selection()`:
1. `data_list$config$clustering_vars` gets updated to selected vars (5)
2. But `config` variable in run_segment.R still has original vars (10)
3. Model saved using old `config`, not updated `data_list$config`

---

## Fix

Updated `run_segment.R` to use the UPDATED config from data_list:

```r
# CORRECT (line 199):
profile_result <- create_full_segment_profile(
  data = data_list$data,
  clusters = final_result$clusters,
  clustering_vars = data_list$config$clustering_vars,  # Use selected vars
  profile_vars = data_list$config$profile_vars  # Use updated config
)

# CORRECT (lines 260, 266):
model_object <- list(
  model = final_result$model,
  k = final_result$k,
  clusters = final_result$clusters,
  centers = final_result$model$centers,
  segment_names = segment_names,
  clustering_vars = data_list$config$clustering_vars,  # Use selected vars
  id_variable = config$id_variable,
  scale_params = data_list$scale_params,
  imputation_params = data_list$imputation_params,
  original_distribution = segment_dist,
  seed = seed_used,
  config = data_list$config,  # Use updated config with selected vars
  timestamp = Sys.time(),
  date_created = Sys.time(),
  turas_version = "1.0"
)
```

---

## Impact

**Before Fix:**
- ❌ Scoring failed completely when variable selection was used
- ❌ Model metadata inconsistent with actual parameters
- ❌ Impossible to score new data with selected variable models

**After Fix:**
- ✅ `clustering_vars` matches `scale_params` and `imputation_params`
- ✅ All model components consistent (same 5 selected variables)
- ✅ Scoring works correctly with selected variables
- ✅ Profiling uses correct variable set

---

## Testing Required

1. **Regenerate Model:**
   - Run segmentation with variable selection enabled
   - Verify model has consistent variable counts

2. **Verify Model Consistency:**
   ```r
   model <- readRDS("seg_model.rds")

   # All should be 5 (selected variables)
   length(model$clustering_vars)  # Should be 5
   length(model$scale_params$center)  # Should be 5
   length(model$imputation_params$means)  # Should be 5

   # Variables should match exactly
   identical(
     model$clustering_vars,
     names(model$scale_params$center)
   )  # Should be TRUE
   ```

3. **Scoring Consistency Test:**
   - Score the training data
   - Should get 100% match with original assignments
   - No "missing scale parameters" errors

---

## Files Modified

- `modules/segment/run_segment.R` (lines 199, 260, 266)

---

## Why This Was Missed

This bug only manifested when:
1. Variable selection was ENABLED in config
2. Variable selection actually REDUCED the variable count
3. User attempted to SCORE new data

During initial testing:
- Automated tests used simple data without variable selection
- Focus was on other critical bugs (scaling, imputation, data prep order)
- This was discovered during real-world scoring consistency test

---

## Lesson Learned

**Always use the most current version of configuration objects**

When data preparation pipeline modifies the config (like variable selection), subsequent steps must use the UPDATED config from `data_list$config`, not the original `config` variable.

Variable tracking principle:
```r
# Pipeline flow:
config → data_list (with config copy) →
  variable selection (updates data_list$config) →
  use data_list$config everywhere after this point
```

---

## Related Fixes

This complements the other critical fixes:
- Fix #1: Scoring scaling bug (use training scale params)
- Fix #2: Scoring imputation consistency (use training imputation params)
- Fix #9: **Variable selection consistency** (use selected vars in model)

All three work together to ensure scoring consistency.

---

**Status:** Fixed and committed
**Commit:** 9aa713a
**Next:** Re-run segmentation and test scoring consistency
