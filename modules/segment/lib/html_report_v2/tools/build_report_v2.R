# ==============================================================================
# Build a v2 (data-centric) segment report from the synthetic fixture.
# Runs the real final-mode pipeline -> maps the profile onto the v2 data layer
# -> bundles the self-contained *_report_v2.html. Writes to a temp dir + emits
# the agg JSON sidecar (for the node validation harness). Nothing is written
# into the repo.
#
# Run:  TURAS_ROOT=/path/to/Turas Rscript .../tools/build_report_v2.R
# ==============================================================================

suppressWarnings(suppressMessages({
  root <- Sys.getenv("TURAS_ROOT", getwd()); Sys.setenv(TURAS_ROOT = root)
  source(file.path(root, "modules/segment/R/00_main.R"))
  source(file.path(root, "modules/segment/tests/fixtures/generate_test_data.R"))
  source(file.path(root, "modules/segment/lib/html_report_v2/data_layer_writer.R"))
  source(file.path(root, "modules/segment/lib/html_report_v2/build_report_v2.R"))
}))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

outdir <- file.path(tempdir(), "seg_v2"); dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# --- final-mode pipeline on the synthetic fixture ---------------------------
td <- generate_segment_test_data(n = 300, k_true = 3, n_vars = 10, seed = 42)
cfg <- generate_test_config(td, mode = "final", method = "kmeans", k_fixed = 3)
cfg$report_title <- "Synthetic Segmentation — data-centric report v2"
cfg$project_name <- "Turas Segment v2"
cfg$analyst_name <- "Duncan Brett"
cfg$brand_colour <- "#323367"; cfg$accent_colour <- "#CC9900"; cfg$scale_max <- 10

num <- td$data[, td$clustering_vars]; for (c in td$clustering_vars) num[[c]][is.na(num[[c]])] <- median(num[[c]], na.rm = TRUE)
sc <- scale(num)
dl_in <- list(original_data = td$data, data = td$data, scaled_data = sc, clustering_data = num,
              clustering_vars = td$clustering_vars, config = cfg,
              scale_params = list(center = attr(sc, "scaled:center"), scale = attr(sc, "scaled:scale")))
g <- segment_guard_init()
cr <- run_clustering(dl_in, cfg, g)
vm <- calculate_validation_metrics(data = sc, model = cr$model, k = cr$k, clusters = cr$clusters, calculate_gap = FALSE)
sn <- paste("Segment", seq_len(cr$k))
pr <- create_full_segment_profile(data = td$data, clusters = cr$clusters,
        clustering_vars = td$clustering_vars, profile_vars = cfg$profile_vars)
gq <- tryCatch(identify_golden_questions(data = num, clusters = cr$clusters,
        segment_names = sn, n_top = length(td$clustering_vars), n_trees = 200),
        error = function(e) NULL)   # all questions -> full short-form screener
vuln <- tryCatch(calculate_vulnerability(data = sc, clusters = cr$clusters,
        centers = cr$centers, method = "kmeans"), error = function(e) NULL)

results <- list(mode = "final", cluster_result = cr, validation_metrics = vm,
                profile_result = pr, segment_names = sn, golden_questions = gq,
                vulnerability = vuln, data_list = dl_in)

# --- data layer -> JSON island ---------------------------------------------
dl <- build_segment_data_layer(results, cfg)
json <- serialize_segment_data_layer(dl)
json_path <- file.path(outdir, "segment_data.json")
writeLines(json, json_path, useBytes = TRUE)

# --- bundle the self-contained report --------------------------------------
out_path <- file.path(outdir, "segment_report_v2.html")
res <- seg_write_report_v2(json, out_path, title = cfg$report_title)

cat("\n==== SEGMENT REPORT v2 ====\n")
cat("status :", res$status, "\n")
cat("report :", res$output_file %||% out_path, "\n")
cat("agg    :", json_path, "\n")
cat("size_mb:", round(res$file_size_mb %||% NA, 2), "\n")
cat("columns:", length(dl$columns), " questions:", length(dl$questions),
    " segments:", cr$k, "\n")
