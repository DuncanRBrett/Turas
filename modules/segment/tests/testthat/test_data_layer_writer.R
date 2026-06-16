# ==============================================================================
# SEGMENT MODULE TESTS - DATA-CENTRIC REPORT v2 DATA-LAYER WRITER
# ==============================================================================
# Validates that build_segment_data_layer() maps the segment profile onto the
# v2 report's `agg` contract (the shape the renderer's d2.validate requires).
# Presentation-layer only — no statistics are recomputed.
# ==============================================================================

# The v2 writer is not part of the core module load — source it here.
local({
  root <- Sys.getenv("TURAS_ROOT", "")
  writer <- file.path(root, "modules", "segment", "lib", "html_report_v2",
                      "data_layer_writer.R")
  if (nzchar(root) && file.exists(writer) &&
      !exists("build_segment_data_layer", mode = "function")) {
    source(writer, local = FALSE)
  }
})

# A small final-mode solution + its profile, for the writer to map.
.seg_v2_fixture <- function() {
  td <- generate_segment_test_data(n = 200, k_true = 3, n_vars = 6, seed = 42)
  cfg <- generate_test_config(td, mode = "final", method = "kmeans", k_fixed = 3)
  cfg$scale_max <- 10
  num <- td$data[, td$clustering_vars, drop = FALSE]
  for (col in td$clustering_vars) {
    num[[col]][is.na(num[[col]])] <- median(num[[col]], na.rm = TRUE)
  }
  sc <- scale(num)
  dl_in <- list(original_data = td$data, data = td$data, scaled_data = sc,
                clustering_data = num, clustering_vars = td$clustering_vars, config = cfg,
                scale_params = list(center = attr(sc, "scaled:center"),
                                    scale = attr(sc, "scaled:scale")))
  g <- segment_guard_init()
  cr <- run_clustering(dl_in, cfg, g)
  pr <- create_full_segment_profile(data = td$data, clusters = cr$clusters,
          clustering_vars = td$clustering_vars, profile_vars = cfg$profile_vars)
  list(results = list(mode = "final", cluster_result = cr, profile_result = pr,
                      segment_names = paste("Segment", seq_len(cr$k)), data_list = dl_in),
       config = cfg, profile = pr$clustering_profile, k = cr$k)
}


test_that("build_segment_data_layer emits the v2 agg contract shape", {
  skip_if_not(exists("build_segment_data_layer", mode = "function"), "v2 writer not loaded")
  f <- .seg_v2_fixture()
  dl <- build_segment_data_layer(f$results, f$config)

  expect_false(is.null(dl))
  expect_equal(dl$schema_version, 2L)
  # columns = Total (first) + one per segment; segments grouped + lettered
  expect_equal(length(dl$columns), 1L + f$k)
  expect_equal(dl$columns[[1]]$key, "Total")
  expect_equal(dl$columns[[1]]$group, "total")
  expect_equal(dl$columns[[2]]$group, "segment")
  expect_equal(dl$columns[[2]]$letter, "A")
  # one banner group, one question per profile variable
  expect_equal(length(dl$banner_groups), 1L)
  expect_equal(dl$banner_groups[[1]]$id, "segment")
  expect_equal(length(dl$questions), nrow(f$profile))
  # ANOVA differentiation stats carried for the native Importance view
  expect_true(is.numeric(dl$questions[[1]]$f_stat))
  expect_true(is.numeric(dl$questions[[1]]$p_value))
})


test_that("each question carries a mean row whose pct matches the profile means", {
  skip_if_not(exists("build_segment_data_layer", mode = "function"), "v2 writer not loaded")
  f <- .seg_v2_fixture()
  dl <- build_segment_data_layer(f$results, f$config)

  q1 <- dl$questions[[1]]
  expect_equal(length(q1$rows), 1L)
  expect_equal(q1$rows[[1]]$kind, "mean")
  expect_equal(length(q1$rows[[1]]$pct), 1L + f$k)     # Total + segments
  expect_equal(length(q1$bases), 1L + f$k)
  expect_equal(q1$scale_max, 10)

  # pct == the profile row (Overall, Segment_1..k) for that variable — the writer
  # re-presents existing means, it does not recompute them.
  prow <- f$profile[f$profile$Variable == q1$code, , drop = FALSE]
  expected <- as.numeric(c(prow$Overall, prow$Segment_1, prow$Segment_2, prow$Segment_3))
  got <- as.numeric(unlist(q1$rows[[1]]$pct))
  expect_equal(got, expected, tolerance = 1e-6)
})


test_that("build_segment_data_layer carries golden questions when present", {
  skip_if_not_installed("randomForest")
  skip_if_not(exists("build_segment_data_layer", mode = "function"), "v2 writer not loaded")
  skip_if_not(exists("identify_golden_questions", mode = "function"), "golden questions not loaded")

  f <- .seg_v2_fixture()
  num <- f$results$data_list$clustering_data
  gq <- identify_golden_questions(data = num, clusters = f$results$cluster_result$clusters,
          segment_names = f$results$segment_names, n_top = 4, n_trees = 100)
  skip_if(is.null(gq) || gq$status == "SKIPPED", "golden questions not computed")

  res <- f$results
  res$golden_questions <- gq
  dl <- build_segment_data_layer(res, f$config)

  expect_false(is.null(dl$golden))
  expect_true(length(dl$golden$questions) >= 1L)
  expect_true(is.numeric(dl$golden$overall_accuracy))
  q1 <- dl$golden$questions[[1]]
  expect_true(is.numeric(q1$cumulative_accuracy))   # the accuracy curve value
  expect_true(is.numeric(q1$importance_pct))
  expect_true(nzchar(q1$title))                      # mapped to a question label
})


test_that("build_segment_data_layer carries overlap (centroid distances)", {
  skip_if_not(exists("build_segment_data_layer", mode = "function"), "v2 writer not loaded")
  f <- .seg_v2_fixture()
  dl <- build_segment_data_layer(f$results, f$config)

  expect_false(is.null(dl$overlap))
  expect_equal(length(dl$overlap$labels), f$k)
  expect_equal(length(dl$overlap$distance), f$k)
  d <- dl$overlap$distance
  expect_equal(as.numeric(d[[1]][[1]]), 0)                                   # self-distance
  expect_equal(as.numeric(d[[1]][[2]]), as.numeric(d[[2]][[1]]), tolerance = 1e-6)  # symmetric
})


test_that("build_segment_data_layer carries vulnerability when present", {
  skip_if_not(exists("build_segment_data_layer", mode = "function"), "v2 writer not loaded")
  skip_if_not(exists("calculate_vulnerability", mode = "function"), "vulnerability not loaded")

  f <- .seg_v2_fixture()
  vuln <- tryCatch(calculate_vulnerability(data = f$results$data_list$scaled_data,
            clusters = f$results$cluster_result$clusters,
            centers = f$results$cluster_result$centers, method = "kmeans"),
            error = function(e) NULL)
  skip_if(is.null(vuln), "vulnerability not computed")

  res <- f$results
  res$vulnerability <- vuln
  dl <- build_segment_data_layer(res, f$config)

  expect_false(is.null(dl$vulnerability))
  expect_equal(length(dl$vulnerability$segments), f$k)
  expect_true(is.numeric(dl$vulnerability$segments[[1]]$pct_vulnerable))
  expect_true(is.numeric(dl$vulnerability$overall_pct_vulnerable))
  expect_false(is.null(dl$vulnerability$switching))                          # where members would move
})


test_that("serialize_segment_data_layer produces engine-parseable JSON", {
  skip_if_not(exists("serialize_segment_data_layer", mode = "function"), "v2 writer not loaded")
  f <- .seg_v2_fixture()
  dl <- build_segment_data_layer(f$results, f$config)
  json <- serialize_segment_data_layer(dl)

  expect_true(is.character(json) && nchar(json) > 100)
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(parsed$schema_version, 2L)
  expect_equal(length(parsed$questions), nrow(f$profile))
  expect_equal(length(parsed$columns), 1L + f$k)
  # pct must serialise as an array (one value per column), never a bare scalar
  expect_equal(length(parsed$questions[[1]]$rows[[1]]$pct), 1L + f$k)
})
