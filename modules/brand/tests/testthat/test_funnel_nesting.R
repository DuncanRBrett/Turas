# ==============================================================================
# BRAND MODULE TESTS — FUNNEL NESTING INVARIANT (§3.4) — v2 port
# ==============================================================================
# Validates that:
# 1. Stage counts decrease monotonically by construction (nested derivation).
# 2. Fabricating a nesting violation triggers CALC_NESTING_VIOLATED.
# ==============================================================================
library(testthat)

.find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root()

shared_lib <- file.path(ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(ROOT, "modules", "brand", "R", "03_funnel.R"))


# ==============================================================================
# Helpers
# ==============================================================================

.pack_mm <- function(picks, root) {
  n_slots <- max(vapply(picks, length, integer(1)), 1L)
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_,
          character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

.mm_entry <- function(role, cat, client, column_root, n_slots) {
  list(role = role, category = cat, client_code = client,
       variable_type = "Multi_Mention",
       column_root = column_root, per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL,
       question_text = "", option_scale = NA,
       option_map = NULL, notes = "")
}

.att_entry <- function(cat, brands) {
  colroot <- paste0("BRANDATT1_", cat)
  named_cols <- setNames(paste0(colroot, "_", brands), brands)
  list(role = "funnel.attitude", category = cat, client_code = "BRANDATT1",
       variable_type = "Single_Response_Brand",
       column_root = colroot, per_brand = TRUE,
       columns = named_cols,
       applicable_brands = brands,
       question_text = "", option_scale = NA,
       option_map = NULL, notes = "")
}


# ==============================================================================
# Tests
# ==============================================================================

test_that("derived stages nest in aggregate when raw data is coherent", {
  # v3 aggregate funnel: stages don't AND into each other in code, but
  # they SHOULD still nest when raw data is coherent (every penetration_target
  # respondent is also flagged as aware in the underlying data). This
  # fixture constructs bt as a subset of aware so nesting holds.
  set.seed(42)
  n <- 100
  brands <- c("IPK","ROB","CART")

  # Build slot-indexed awareness + penetration_target using random picks
  aware_list <- lapply(seq_len(n), function(i) {
    brands[as.logical(sample(0:1, 3, replace = TRUE))]
  })
  bt_list <- lapply(seq_len(n), function(i) {
    intersect(aware_list[[i]], brands[as.logical(sample(0:1, 3, replace = TRUE))])
  })

  data <- cbind(
    data.frame(RID = seq_len(n), W = runif(n, 0.5, 1.5),
               stringsAsFactors = FALSE),
    .pack_mm(aware_list, "BRANDAWARE_NTX"),
    .pack_mm(bt_list,   "BRANDPEN2_NTX"))
  for (b in brands) {
    data[[paste0("BRANDATT1_NTX_", b)]] <- sample(1:5, n, replace = TRUE)
  }

  n_aw <- sum(grepl("^BRANDAWARE_NTX_", names(data)))
  n_pt <- sum(grepl("^BRANDPEN2_NTX_",  names(data)))
  rm <- list(
    "funnel.awareness"          = .mm_entry("funnel.awareness",
                                             "NTX", "BRANDAWARE",
                                             "BRANDAWARE_NTX", n_aw),
    "funnel.attitude"           = .att_entry("NTX", brands),
    "funnel.penetration_target" = .mm_entry("funnel.penetration_target",
                                             "NTX", "BRANDPEN2",
                                             "BRANDPEN2_NTX", n_pt)
  )

  res <- run_funnel(data, rm, data.frame(BrandCode = brands, BrandLabel = brands,
                                          stringsAsFactors = FALSE),
                    list(`category.type` = "transactional",
                         focal_brand = "IPK",
                         `funnel.conversion_metric` = "ratio",
                         `funnel.warn_base` = 0, `funnel.suppress_base` = 0))

  stage_keys <- unique(res$stages$stage_key)
  for (b in brands) {
    b_rows <- res$stages[res$stages$brand_code == b, , drop = FALSE]
    b_rows <- b_rows[match(stage_keys, b_rows$stage_key), , drop = FALSE]
    b_rows <- b_rows[!is.na(b_rows$stage_key), , drop = FALSE]
    expect_true(
      all(diff(b_rows$base_unweighted) <= 0),
      info = sprintf("Stage counts for %s should be monotonically non-increasing", b)
    )
  }
})


test_that("validate_nesting returns warnings on a fabricated violation (no refusal)", {
  # v3 aggregate funnel: validate_nesting no longer refuses. Non-monotonic
  # brands surface as warnings attached to the funnel result so the
  # operator can investigate, but the engine reports the data as recorded.
  m1 <- matrix(c(1,1,0,  0,0,0), nrow = 2, ncol = 3, byrow = TRUE,
               dimnames = list(NULL, c("IPK","ROB","CART")))
  m2 <- matrix(c(1,1,1,  1,1,1), nrow = 2, ncol = 3, byrow = TRUE,
               dimnames = list(NULL, c("IPK","ROB","CART")))
  stages <- list(
    aware         = list(key = "aware", label = "Aware",
                         matrix = m1 == 1),
    consideration = list(key = "consideration", label = "Consideration",
                         matrix = m2 == 1)
  )
  res <- validate_nesting(stages)
  expect_false(res$ok)
  expect_true(length(res$warnings) >= 1)
  # All three brands violate (consideration > aware for each)
  expect_match(paste(res$warnings, collapse = " | "), "IPK")
  expect_match(paste(res$warnings, collapse = " | "), "ROB")
  expect_match(paste(res$warnings, collapse = " | "), "CART")
})


test_that("validate_nesting reports ok when stage counts equal the previous", {
  m <- matrix(c(1,1,0,  1,1,0), nrow = 2, ncol = 3, byrow = TRUE,
              dimnames = list(NULL, c("IPK","ROB","CART")))
  stages <- list(
    a = list(key="a", label="A", matrix = m == 1),
    b = list(key="b", label="B", matrix = m == 1)
  )
  res <- validate_nesting(stages)
  expect_true(res$ok)
  expect_equal(length(res$warnings), 0)
})


test_that("validate_nesting is a no-op with fewer than 2 stages", {
  res_empty <- validate_nesting(list())
  expect_true(res_empty$ok)
  expect_equal(length(res_empty$warnings), 0)
  res_one <- validate_nesting(list(
    only = list(key="only", label="Only",
                matrix = matrix(TRUE, nrow = 3, ncol = 2,
                                dimnames = list(NULL, c("A","B"))))
  ))
  expect_true(res_one$ok)
  expect_equal(length(res_one$warnings), 0)
})
