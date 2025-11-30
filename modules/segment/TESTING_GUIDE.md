# Critical Fixes Testing Guide

**Purpose:** Validate all 8 critical and high-priority fixes
**Time Required:** 15-20 minutes
**Prerequisites:** R installed, test data available

---

## Quick Test (Automated)

Run the automated test script:

```r
source("modules/segment/test_critical_fixes.R")
```

This will test:
- ✅ Seed reproducibility
- ✅ Data preparation order
- ✅ Mahalanobis guardrails
- ✅ nstart configuration
- ✅ Outlier flag NA handling

**Expected Output:** "🎉 ALL TESTS PASSED!"

---

## Manual Testing

If automated test isn't available, follow these manual tests:

### Test 1: Seed Reproducibility ⭐ CRITICAL

**Goal:** Verify same seed produces identical results

```r
# Set working directory
setwd("path/to/Turas")

# Source the main script
source("modules/segment/run_segment.R")

# Test with existing config
config_file <- "modules/segment/test_data/test_segment_config.xlsx"

# Run 1
result1 <- turas_segment_from_config(config_file)

# Run 2 (same seed in config)
result2 <- turas_segment_from_config(config_file)

# Verify
identical(result1$clusters, result2$clusters)  # Should be TRUE
```

**Expected:** Clusters identical across runs
**If Failed:** Check seed is being set in run_segment.R


---

### Test 2: Scoring Consistency ⭐⭐⭐ MOST CRITICAL

**Goal:** Verify scoring uses correct scale parameters

```r
# Run a segmentation
source("modules/segment/run_segment.R")
config_file <- "modules/segment/test_data/test_segment_config.xlsx"
result <- turas_segment_from_config(config_file)

# Score the SAME data that was used for training
source("modules/segment/lib/segment_scoring.R")

# Load the training data
training_data <- read.csv("modules/segment/test_data/test_survey_data.csv")

# Score it
model_file <- "output/segmentation/seg_model.rds"
scoring_result <- score_new_data(
  model_file = model_file,
  new_data = training_data,
  id_variable = "respondent_id",
  output_file = NULL
)

# Compare assignments
model <- readRDS(model_file)
original_assignments <- model$clusters
scored_assignments <- scoring_result$assignments$segment

# Calculate match rate
match_rate <- mean(original_assignments == scored_assignments)
cat(sprintf("Match rate: %.1f%%\n", match_rate * 100))

# CRITICAL: Should be 100% match
```

**Expected:** 100% match between original and scored assignments
**If Failed:** Scaling bug not fixed correctly


---

### Test 3: Data Preparation Order

**Goal:** Verify outliers removed before standardization

```r
# Create data with outliers
set.seed(123)
test_data <- data.frame(
  respondent_id = 1:50,
  var1 = c(rnorm(45, mean = 5, sd = 1), rep(100, 5)),  # 5 outliers
  var2 = c(rnorm(45, mean = 10, sd = 2), rep(200, 5))
)

# Save test data
write.csv(test_data, "test_outlier_data.csv", row.names = FALSE)

# Create config with outlier detection enabled
# outlier_detection = TRUE
# outlier_method = "zscore"
# outlier_threshold = 3.0
# outlier_handling = "remove"

# Run segmentation
result <- turas_segment_from_config("your_config.xlsx")

# Load model and check scale parameters
model <- readRDS("output/segmentation/seg_model.rds")
scale_means <- model$scale_params$center

# Check means are reasonable (outliers removed)
cat(sprintf("var1 mean: %.2f (expect ~5)\n", scale_means["var1"]))
cat(sprintf("var2 mean: %.2f (expect ~10)\n", scale_means["var2"]))
```

**Expected:** Scale means close to 5 and 10 (without outlier influence)
**If Failed:** Outliers being included in scale calculation


---

### Test 4: Imputation Consistency

**Goal:** Verify scoring uses training imputation parameters

```r
# Train a model with missing data
# (Use data with missing values and mean_imputation)

# Check model contains imputation params
model <- readRDS("output/segmentation/seg_model.rds")

if (!is.null(model$imputation_params)) {
  cat("✓ Imputation parameters saved in model\n")
  print(model$imputation_params$means)
} else {
  cat("✗ Imputation parameters NOT saved\n")
}

# Score new data with missing values
# Should use saved means, not batch means
```

**Expected:** Model contains imputation_params
**If Failed:** Check segment_data_prep.R saves imputation params


---

### Test 5: Mahalanobis Guardrails

**Goal:** Verify error when n < 3*p

```r
source("modules/segment/lib/segment_outliers.R")

# Create small dataset: n=10, p=5
small_data <- data.frame(
  var1 = rnorm(10),
  var2 = rnorm(10),
  var3 = rnorm(10),
  var4 = rnorm(10),
  var5 = rnorm(10)
)

# This should ERROR
tryCatch({
  detect_outliers_mahalanobis(
    data = small_data,
    clustering_vars = c("var1", "var2", "var3", "var4", "var5"),
    alpha = 0.001
  )
  cat("✗ FAIL: Should have errored!\n")
}, error = function(e) {
  cat("✓ PASS: Correctly errored with n < 3*p\n")
  cat("  Message:", conditionMessage(e), "\n")
})
```

**Expected:** Clear error message about n < 3*p
**If Failed:** Guardrails not working


---

## Integration Test with Real Data

**Recommended:** Test with your actual production data

```r
# 1. Run full segmentation
config_file <- "path/to/your/real_config.xlsx"
result <- turas_segment_from_config(config_file)

# 2. Check outputs
model <- readRDS("output/path/model.rds")

# Verify all critical elements present:
checks <- c(
  "scale_params" = !is.null(model$scale_params),
  "imputation_params" = !is.null(model$imputation_params),
  "seed" = !is.null(model$seed),
  "centers" = !is.null(model$centers)
)

print(checks)
# All should be TRUE

# 3. Score a subset of the training data
# Should get near-perfect match on segment assignments

# 4. Run twice with same seed
# Should get identical results
```

---

## Validation Checklist

After testing, verify:

- [ ] Seed management: Results reproducible with same seed
- [ ] Scoring consistency: 100% match when scoring training data
- [ ] Data prep order: Scale means reasonable after outlier removal
- [ ] Imputation params: Saved in model object
- [ ] Mahalanobis: Errors correctly with n < 3*p
- [ ] Outlier NA handling: No crashes with NA flags
- [ ] nstart: Default is 50
- [ ] P-value notes: Displayed in profiling output

---

## Common Issues

### Issue: Scoring doesn't match 100%

**Cause:** Old model without scale_params or imputation_params
**Solution:** Regenerate the model with the fixed code

### Issue: Different results each run

**Cause:** Seed not being set
**Solution:** Check run_segment.R calls set_segmentation_seed()

### Issue: Mahalanobis crashes

**Cause:** Too many variables for sample size
**Solution:** Use z-score method or reduce variables

---

## Performance Testing

For large datasets, also test:

```r
# Test with large data
# n = 10,000+, p = 50+

system.time({
  result <- turas_segment_from_config("large_data_config.xlsx")
})

# Should complete in reasonable time
# nstart=50 will be slower than nstart=25 but more stable
```

---

## Success Criteria

✅ **All tests pass**
✅ **Scoring matches training assignments 100%**
✅ **Results reproducible across runs**
✅ **No crashes or errors on edge cases**
✅ **Clear error messages when limits exceeded**

---

## Reporting Issues

If any tests fail:

1. Note which test failed
2. Copy error message
3. Check CRITICAL_FIXES_SUMMARY.md for expected behavior
4. Review the specific file mentioned in the fix documentation
5. Report issue with details

---

**Questions?** See CRITICAL_FIXES_SUMMARY.md for detailed fix documentation.
