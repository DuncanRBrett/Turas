# ==============================================================================
# TESTS: LC ASSIGNMENT, CUSTOM SLIDES, OPTIMIZER CONFIG SURFACE
# ==============================================================================
# Review findings H10, H12, H3.
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT")
read_src <- function(...) paste(readLines(file.path(root, ...), warn = FALSE), collapse = "\n")

# ---------------------------------------------------------------------------
# H10 — latent class assignment
# ---------------------------------------------------------------------------

test_that("H10: the round-robin class assignment is gone", {
  src <- read_src("modules", "conjoint", "R", "13_latent_class.R")

  # rep(seq_len(k), length.out = n_respondents) dealt respondents to classes in
  # turn, with uniform probabilities and no message, and the run said PASS.
  expect_false(grepl("rep(seq_len(k), length.out = n_respondents)", src, fixed = TRUE))
  expect_true(grepl("CALC_LC_ASSIGNMENT_FAILED", src, fixed = TRUE))
})

test_that("H10: the k-means fallback announces itself", {
  src <- read_src("modules", "conjoint", "R", "13_latent_class.R")
  expect_true(grepl("CONJ_LC_KMEANS_ASSIGNMENT", src, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# H12 — the template's example slide
# ---------------------------------------------------------------------------

test_that("H12: as.logical no longer decides whether custom slides are included", {
  # as.logical("Y") is NA, which is why the gate never worked.
  expect_true(is.na(as.logical("Y")))
  expect_true(safe_logical("Y", default = FALSE))
  expect_false(safe_logical("N", default = TRUE))
  expect_false(safe_logical(NULL, default = FALSE))
})

test_that("H12: the config loader gates the Custom_Slides sheet on the setting", {
  src <- read_src("modules", "conjoint", "R", "01_config.R")
  expect_true(grepl('isTRUE(include_slides) && "Custom_Slides" %in% sheet_names',
                    src, fixed = TRUE))
  expect_false(grepl("as.logical(settings_list$include_custom_slides", src, fixed = TRUE))
})

test_that("H12: the template's example slide is recognised and skipped", {
  expect_true(.is_template_example_slide("Executive Summary — Key Findings", ""))
  expect_true(.is_template_example_slide("Executive Summary", "anything"))
  expect_true(.is_template_example_slide("A Real Title", "Replace this with your own text"))
  expect_true(.is_template_example_slide("A Real Title", "Example content goes here"))
})

test_that("H12: a genuine analyst slide is not mistaken for the example", {
  expect_false(.is_template_example_slide(
    "What the pricing test showed",
    "Households in the top income band traded down when the R20 tier appeared."
  ))
  expect_false(.is_template_example_slide(
    "Recommendation",
    "Launch the 6.7 inch model at R499 and hold the 5.5 inch at R299."
  ))
})

# ---------------------------------------------------------------------------
# H3 — the decorative optimizer config surface
# ---------------------------------------------------------------------------

test_that("H3: the optimizer settings are gone from the template, validator and config", {
  tpl <- read_src("modules", "conjoint", "R", "12_config_template.R")
  cfg <- read_src("modules", "conjoint", "R", "01_config.R")

  expect_false(grepl('add("OPTIMIZER"', tpl, fixed = TRUE))
  expect_false(grepl("optimizer_method = settings_list", cfg, fixed = TRUE))
  expect_false(grepl("must be 'exhaustive' or 'genetic'", cfg, fixed = TRUE))
})

test_that("H3: the optimizer functions themselves are still available", {
  # They are unwired from the config sheet, not deleted: both have tests in
  # test_optimizer.R, so removing them would remove working coverage.
  expect_true(exists("optimize_product_exhaustive", mode = "function"))
  expect_true(exists("optimize_product_greedy", mode = "function"))
})

test_that("H3: template and validator no longer disagree about any dropdown", {
  # The optimizer dropdown offered "greedy" while the validator accepted only
  # "exhaustive" or "genetic", so the template's own value refused the run.
  cfg <- read_src("modules", "conjoint", "R", "01_config.R")
  expect_false(grepl("genetic", cfg, fixed = TRUE))
})
