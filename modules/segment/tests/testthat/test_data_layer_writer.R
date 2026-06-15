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
