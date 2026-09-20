# The Thornhill Grocers worked example (examples/segment/).
#
# Segment had no example of any kind until September 2026, which is how
# mini-batch k-means came to be dead for every study over 10,000 rows with
# passing tests around it. These assertions are the example's own gate: the
# constructed answer must come back out, and the two config workbooks must
# load and validate.
#
# The full pipeline is NOT run here. That is Duncan's launch_turas() pass. What
# is checked is the part with a known right answer.

.segment_example_dir <- function() {
  file.path(Sys.getenv("TURAS_ROOT"), "examples", "segment")
}

.skip_without_example <- function() {
  skip_if_not(nzchar(Sys.getenv("TURAS_ROOT")), "TURAS_ROOT not set")
  skip_if_not(file.exists(file.path(.segment_example_dir(), "create_segment_example.R")),
              "segment example not present")
}

test_that("the example's three files are present", {
  .skip_without_example()
  d <- .segment_example_dir()

  expect_true(file.exists(file.path(d, "Thornhill_Segment_Data.xlsx")))
  expect_true(file.exists(file.path(d, "Thornhill_Segment_Config.xlsx")))
  expect_true(file.exists(file.path(d, "Thornhill_Segment_Config_Explore.xlsx")))
})

test_that("the shipped data file is the one the generator makes", {
  .skip_without_example()
  options(turas.example.no_run = TRUE)
  source(file.path(.segment_example_dir(), "create_segment_example.R"), local = TRUE)

  shipped <- openxlsx::read.xlsx(
    file.path(.segment_example_dir(), "Thornhill_Segment_Data.xlsx"),
    sheet = "Data", skipEmptyRows = FALSE)
  rebuilt <- build_segment_data()

  expect_equal(nrow(shipped), nrow(rebuilt))
  expect_equal(sort(names(shipped)), sort(names(rebuilt)))
  expect_equal(shipped$att_price_first, rebuilt$att_price_first)
  expect_equal(shipped$true_segment, rebuilt$true_segment)
})

test_that("k-means recovers the constructed segments", {
  .skip_without_example()
  options(turas.example.no_run = TRUE)
  source(file.path(.segment_example_dir(), "create_segment_example.R"), local = TRUE)

  d <- build_segment_data()
  vars <- paste0("att_", SEGMENT_EXAMPLE_VARS)
  set.seed(2026)
  km <- kmeans(scale(d[, vars]), centers = 3, nstart = 50)

  tb <- table(km$cluster, d$true_segment)
  perms <- list(1:3, c(1, 3, 2), c(2, 1, 3), c(2, 3, 1), c(3, 1, 2), c(3, 2, 1))
  best <- max(vapply(perms, function(p) sum(diag(tb[, p, drop = FALSE])) / sum(tb),
                     numeric(1)))

  expect_gt(best, 0.95)
})

test_that("the constructed segment shares are unequal, as intended", {
  .skip_without_example()
  options(turas.example.no_run = TRUE)
  source(file.path(.segment_example_dir(), "create_segment_example.R"), local = TRUE)

  d <- build_segment_data()
  shares <- prop.table(table(d$true_segment))

  # A solution that comes back 33/33/33 has found the k-means grid, not these
  # shoppers, so the example must not hand it that shape to begin with.
  expect_gt(max(shares), 0.40)
  expect_lt(min(shares), 0.27)
})

test_that("both config workbooks load and validate", {
  .skip_without_example()
  d <- .segment_example_dir()

  for (f in c("Thornhill_Segment_Config.xlsx", "Thornhill_Segment_Config_Explore.xlsx")) {
    raw <- read_segment_config(file.path(d, f))
    capture.output(cfg <- validate_segment_config(raw))

    expect_equal(cfg$method, "kmeans")
    expect_equal(length(cfg$clustering_vars), 6)
    expect_equal(cfg$id_variable, "respondent_id")
  }
})

test_that("the final config is final mode and the explore config is not", {
  .skip_without_example()
  d <- .segment_example_dir()

  capture.output(final <- validate_segment_config(
    read_segment_config(file.path(d, "Thornhill_Segment_Config.xlsx"))))
  capture.output(explore <- validate_segment_config(
    read_segment_config(file.path(d, "Thornhill_Segment_Config_Explore.xlsx"))))

  expect_equal(final$mode, "final")
  expect_equal(final$k_fixed, 3)
  expect_equal(explore$mode, "exploration")
})

test_that("neither config trips the unused-settings warning", {
  # Every setting in these workbooks must be one the module really reads. If
  # this fails, either the example invented a setting or the template and the
  # parser have drifted apart again (H3).
  .skip_without_example()
  d <- .segment_example_dir()

  out <- capture.output(
    validate_segment_config(read_segment_config(
      file.path(d, "Thornhill_Segment_Config.xlsx"))))

  expect_false(grepl("did not survive validation", paste(out, collapse = " ")))
})
