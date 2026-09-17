# ==============================================================================
# KEYDRIVER - SHAP DUMMY COLLAPSE (review H6)
# ==============================================================================
# The map that collapses one-hot dummies back to their driver was built with
# the pattern "^Gender(?=$|[^[:alnum:]_])", which requires the character after
# the driver's name to be non-alphanumeric. model.matrix names its dummies
# GenderFemale and GenderMale, so the lookahead could never match. The map was
# always NULL and driver-level SHAP importance for a categorical driver did not
# exist. Nothing noticed, because a NULL map is also what a model with no
# factors legitimately returns.
# ==============================================================================

skip_if_not(file.exists(file.path(module_dir, "R", "kda_shap", "shap_calculate.R")),
            "shap_calculate.R not present")
suppressWarnings(try(source(file.path(module_dir, "R", "kda_shap", "shap_calculate.R")),
                     silent = TRUE))
skip_if(!exists("encode_features", mode = "function"), "encoder not loaded")
skip_if(!exists("create_feature_map", mode = "function"), "map builder not loaded")

test_that("the old pattern could not match a dummy name (H6)", {
  # Kept as the reason this file exists: the fix is not a preference.
  old_pattern <- paste0("^", "Gender", "(?=$|[^[:alnum:]_])")
  expect_equal(length(grep(old_pattern, c("GenderFemale", "GenderMale"),
                           perl = TRUE, value = TRUE)), 0)
})

test_that("a factor driver's dummies collapse back to the driver (H6)", {
  set.seed(9)
  n <- 120
  X <- data.frame(
    Age = rnorm(n),
    Gender = factor(sample(c("Female", "Male"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  enc <- encode_features(X)
  expect_true(all(c("GenderFemale", "GenderMale") %in% names(enc)))
  expect_false("Gender" %in% names(enc))

  fm <- create_feature_map(X, enc)
  expect_false(is.null(fm))
  expect_equal(fm[["GenderFemale"]], "Gender")
  expect_equal(fm[["GenderMale"]], "Gender")
  # The numeric driver is not in the map, because it needs no collapsing.
  expect_false("Age" %in% names(fm))
})

test_that("the map comes from the encoder, not from guessing the name back (H6)", {
  set.seed(11)
  n <- 80
  X <- data.frame(
    Q1 = factor(sample(c("Yes", "No"), n, TRUE)),
    Q10 = factor(sample(c("Yes", "No"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  enc <- encode_features(X)
  recorded <- attr(enc, "kd_feature_map")
  expect_false(is.null(recorded))
  # Q1 and Q10 both produce a "Yes" dummy. Prefix matching is exactly where
  # that goes wrong; the encoder's own record cannot.
  expect_equal(recorded[["Q1Yes"]], "Q1")
  expect_equal(recorded[["Q10Yes"]], "Q10")
  expect_equal(create_feature_map(X, enc), recorded)
})

test_that("the fallback path also maps Q1 and Q10 apart (H6)", {
  set.seed(13)
  n <- 60
  X <- data.frame(
    Q1 = factor(sample(c("Yes", "No"), n, TRUE)),
    Q10 = factor(sample(c("Yes", "No"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  enc <- encode_features(X)
  # Strip the encoder's record to force the reconstruction path.
  attr(enc, "kd_feature_map") <- NULL
  fm <- create_feature_map(X, enc)
  expect_false(is.null(fm))
  expect_equal(fm[["Q1Yes"]], "Q1")
  expect_equal(fm[["Q10No"]], "Q10")
  expect_equal(length(fm), 4)
})

test_that("a model with no factors still returns no map (H6)", {
  X <- data.frame(A = rnorm(30), B = rnorm(30))
  enc <- encode_features(X)
  expect_null(create_feature_map(X, enc))
})

test_that("an ordered factor is scored, not dummied, and stays out of the map (H6)", {
  set.seed(17)
  n <- 50
  X <- data.frame(
    Sat = factor(sample(c("Low", "Mid", "High"), n, TRUE),
                 levels = c("Low", "Mid", "High"), ordered = TRUE),
    Age = rnorm(n)
  )
  enc <- encode_features(X)
  expect_true("Sat" %in% names(enc))
  expect_true(is.numeric(enc$Sat))
  expect_null(create_feature_map(X, enc))
})
