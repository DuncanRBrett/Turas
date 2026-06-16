# ==============================================================================
# SEGMENT MODULE - CLASSIFICATION RULES TESTS
# ==============================================================================
# Regression coverage for generate_segment_rules() (R/06_rules.R).
#
# Regression: on a standard 10-variable / 3-cluster solution the rule
# extractor indexed rpart's yval2 matrix by column names ("nodeprob.N") that
# rpart never assigns, throwing "subscript out of bounds". The orchestrator
# swallowed that error (tryCatch -> NULL), so the Classification Rules section
# silently vanished from the report. These tests pin the fixed behaviour.
# ==============================================================================

# Helper: a realistic 10-var / 3-cluster solution with NA-cluster outliers
# (mirroring the synthetic fixture used across the module).
.make_rules_inputs <- function() {
  td <- generate_segment_test_data(n = 300, k_true = 3, n_vars = 10, seed = 42)
  num <- td$data[, td$clustering_vars, drop = FALSE]
  for (col in td$clustering_vars) {
    num[[col]][is.na(num[[col]])] <- median(num[[col]], na.rm = TRUE)
  }
  set.seed(42)
  clusters <- as.integer(stats::kmeans(scale(num), centers = 3, nstart = 10)$cluster)
  clusters[298:300] <- NA_integer_  # outliers carry NA cluster ids
  list(data = td$data, clusters = clusters, clustering_vars = td$clustering_vars,
       question_labels = td$question_labels)
}


test_that("generate_segment_rules builds rules on a 10-var/3-cluster fixture", {
  skip_if_not_installed("rpart")
  skip_if_not(exists("generate_segment_rules", mode = "function"),
              "rules module not loaded")

  inp <- .make_rules_inputs()

  res <- generate_segment_rules(
    data = inp$data, clusters = inp$clusters,
    clustering_vars = inp$clustering_vars,
    question_labels = inp$question_labels, max_depth = 3,
    segment_names = c("Segment 1", "Segment 2", "Segment 3"))

  # Previously this returned NULL (the call errored). It must now succeed.
  expect_false(is.null(res))
  expect_s3_class(res$tree, "rpart")
  expect_true(is.character(res$rules_text) && length(res$rules_text) > 0)
  expect_true(is.data.frame(res$rules_df) && nrow(res$rules_df) == 3)
})


test_that("leaf purities are valid probabilities (no -Inf from name-keyed yval2)", {
  skip_if_not_installed("rpart")
  skip_if_not(exists("generate_segment_rules", mode = "function"),
              "rules module not loaded")

  inp <- .make_rules_inputs()
  res <- generate_segment_rules(
    data = inp$data, clusters = inp$clusters,
    clustering_vars = inp$clustering_vars,
    question_labels = inp$question_labels, max_depth = 3,
    segment_names = c("Segment 1", "Segment 2", "Segment 3"))

  expect_true(all(is.finite(res$segment_accuracy)))
  expect_true(all(res$segment_accuracy >= 0 & res$segment_accuracy <= 1))
  # The fitted-class label must map to a real segment, not an out-of-range index
  expect_true(all(grepl("THEN Segment [1-3]$", res$rules_text)))
})


test_that("the Classification Rules section renders in the HTML report", {
  # Guards the page-builder gate: it previously keyed on a non-existent
  # "classification_rules" field and defaulted to hidden, so the section
  # silently dropped from the report even when rules were generated.
  skip_if_not_installed("rpart")
  skip_if_not(requireNamespace("htmltools", quietly = TRUE), "htmltools not installed")
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  td <- generate_segment_test_data(n = 300, k_true = 3, n_vars = 10, seed = 42)
  cfg <- generate_test_config(td, mode = "final", method = "kmeans", k_fixed = 3)
  cfg$generate_rules <- TRUE
  cfg$scale_max <- 10

  num <- td$data[, td$clustering_vars, drop = FALSE]
  for (col in td$clustering_vars) {
    num[[col]][is.na(num[[col]])] <- median(num[[col]], na.rm = TRUE)
  }
  sc <- scale(num)
  dl <- list(original_data = td$data, data = td$data, scaled_data = sc,
             clustering_data = num, clustering_vars = td$clustering_vars, config = cfg,
             scale_params = list(center = attr(sc, "scaled:center"),
                                 scale = attr(sc, "scaled:scale")))
  g <- segment_guard_init()
  cr <- run_clustering(dl, cfg, g)
  vm <- calculate_validation_metrics(data = sc, model = cr$model, k = cr$k,
                                     clusters = cr$clusters, calculate_gap = FALSE)
  sn <- paste("Segment", seq_len(cr$k))
  pr <- create_full_segment_profile(data = td$data, clusters = cr$clusters,
          clustering_vars = td$clustering_vars, profile_vars = cfg$profile_vars)
  rules <- generate_segment_rules(td$data, cr$clusters, td$clustering_vars,
             td$question_labels, 3, sn)

  results <- list(mode = "final", cluster_result = cr, validation_metrics = vm,
    profile_result = pr, segment_names = sn, enhanced = list(rules = rules),
    data_list = dl)

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  rep <- generate_segment_html_report(results = results, config = cfg, output_path = out)

  expect_equal(rep$status, "PASS")
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl('data-seg-section="rules"', html, fixed = TRUE),
              info = "Rules section must be present in the rendered report")
  expect_true(grepl("IF .*THEN Segment", html),
              info = "An extracted IF..THEN rule must render")
})
