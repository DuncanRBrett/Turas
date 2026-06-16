# ==============================================================================
# SEGMENT MODULE TESTS - DATA-CENTRIC REPORT v2 BUNDLER
# ==============================================================================
# Validates that the v2 bundler inlines the vendored engine, the backward-
# compatible shell seam, and the segment-native views into a single
# self-contained report, and embeds the data island.
# ==============================================================================

local({
  root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(root)) return(invisible())
  hr2 <- file.path(root, "modules", "segment", "lib", "html_report_v2")
  if (!exists("seg_bundle_report_v2_js", mode = "function") &&
      file.exists(file.path(hr2, "build_report_v2.R"))) {
    source(file.path(hr2, "build_report_v2.R"), local = FALSE)
  }
  if (!exists("build_segment_data_layer", mode = "function") &&
      file.exists(file.path(hr2, "data_layer_writer.R"))) {
    source(file.path(hr2, "data_layer_writer.R"), local = FALSE)
  }
})


test_that("bundle includes the engine, the shell seam, and segment-native views", {
  skip_if_not(exists("seg_bundle_report_v2_js", mode = "function"), "v2 bundler not loaded")
  js <- seg_bundle_report_v2_js()

  expect_true(nchar(js) > 50000)                          # the full engine is present
  expect_true(grepl("TR.shell", js, fixed = TRUE))        # engine shell
  expect_true(grepl("TR.app && Array.isArray(TR.app.tabs)", js, fixed = TRUE))  # tab seam
  expect_true(grepl("appRoute", js, fixed = TRUE))        # route seam
  expect_true(grepl("TR.segViews", js, fixed = TRUE))     # segment-native views bundled
  expect_true(grepl("Segment profiles", js, fixed = TRUE))
  expect_true(grepl("seg.profilesHtml", js, fixed = TRUE))  # interactive Profiles render
  expect_true(grepl("data-sortcol", js, fixed = TRUE))      # segment-comparison controls
  expect_true(grepl("seg.golden", js, fixed = TRUE))        # golden questions view
  expect_true(grepl("Golden questions", js, fixed = TRUE))
  expect_false(grepl("</script", js, fixed = TRUE))       # safe to inline in <script>
})


test_that("seg_build_report_v2_html embeds the data island + the native app", {
  skip_if_not(exists("seg_build_report_v2_html", mode = "function"), "v2 bundler not loaded")
  skip_if_not(exists("build_segment_data_layer", mode = "function"), "v2 writer not loaded")

  td <- generate_segment_test_data(n = 150, k_true = 3, n_vars = 5, seed = 42)
  cfg <- generate_test_config(td, mode = "final", method = "kmeans", k_fixed = 3)
  cfg$scale_max <- 10
  num <- td$data[, td$clustering_vars, drop = FALSE]
  for (col in td$clustering_vars) num[[col]][is.na(num[[col]])] <- median(num[[col]], na.rm = TRUE)
  sc <- scale(num)
  dl_in <- list(original_data = td$data, data = td$data, scaled_data = sc, clustering_data = num,
                clustering_vars = td$clustering_vars, config = cfg,
                scale_params = list(center = attr(sc, "scaled:center"), scale = attr(sc, "scaled:scale")))
  g <- segment_guard_init()
  cr <- run_clustering(dl_in, cfg, g)
  pr <- create_full_segment_profile(data = td$data, clusters = cr$clusters,
          clustering_vars = td$clustering_vars, profile_vars = cfg$profile_vars)
  dl <- build_segment_data_layer(
    list(mode = "final", cluster_result = cr, profile_result = pr,
         segment_names = paste("Segment", seq_len(cr$k)), data_list = dl_in), cfg)
  json <- serialize_segment_data_layer(dl)

  html <- seg_build_report_v2_html(json, title = "Bundler Test Report")

  expect_true(grepl("Bundler Test Report", html, fixed = TRUE))  # title token filled
  expect_true(grepl("data-agg", html, fixed = TRUE))             # data island id
  expect_true(grepl("TR.segViews", html, fixed = TRUE))          # native views inlined
  expect_false(grepl('src="http', html))                         # self-contained, no external refs
})
