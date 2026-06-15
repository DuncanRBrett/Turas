# ==============================================================================
# Phase 0 baseline generator — CURRENT (classic) segment HTML report
# ==============================================================================
# Mirrors turas_segment_impl() final-mode (R/00_main.R) using the in-memory
# synthetic fixture (no Excel config / data file needed), so we have a faithful
# visual + feature baseline to build the v2 report against. Output goes to a
# temp dir — nothing is written into the repo.
#
# Run:  TURAS_ROOT=/path/to/Turas Rscript .../tools/generate_baseline.R
# ==============================================================================

suppressWarnings(suppressMessages({
  root <- Sys.getenv("TURAS_ROOT", normalizePath(file.path(getwd())))
  Sys.setenv(TURAS_ROOT = root)
  source(file.path(root, "modules/segment/R/00_main.R"))
  source(file.path(root, "modules/segment/tests/fixtures/generate_test_data.R"))
  source(file.path(root, "modules/segment/lib/html_report/99_html_report_main.R"))
}))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

outdir <- file.path(tempdir(), "seg_v2_baseline")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# 1. Synthetic data: 300 respondents, 10 vars, 3 true clusters ----------------
td <- generate_segment_test_data(n = 300, k_true = 3, n_vars = 10, seed = 42)
data <- td$data
clustering_vars <- td$clustering_vars

# 2. Config (final, kmeans, k=3) + enhanced features on -----------------------
config <- generate_test_config(td, mode = "final", method = "kmeans", k_fixed = 3)
config$generate_rules        <- TRUE
config$generate_action_cards <- TRUE
config$report_title  <- "Synthetic Segmentation — Baseline (current report)"
config$project_name  <- "Turas Segment v2 — Phase 0 baseline"
config$analyst_name  <- "Duncan Brett"
config$brand_colour  <- "#323367"
config$accent_colour <- "#CC9900"
config$scale_max     <- 10

# 3. Prepare data (median impute + z-score), mirror orchestrator data_list ----
numeric_data <- data[, clustering_vars, drop = FALSE]
for (col in clustering_vars) {
  med <- median(numeric_data[[col]], na.rm = TRUE)
  numeric_data[[col]][is.na(numeric_data[[col]])] <- med
}
scaled <- scale(numeric_data)
data_list <- list(
  original_data = data, data = data, scaled_data = scaled,
  clustering_data = numeric_data, clustering_vars = clustering_vars,
  config = config,
  scale_params = list(center = attr(scaled, "scaled:center"),
                      scale  = attr(scaled, "scaled:scale"))
)

guard <- segment_guard_init()

# 4. Cluster + validate -------------------------------------------------------
cr <- run_clustering(data_list, config, guard)
vm <- calculate_validation_metrics(data = scaled, model = cr$model, k = cr$k,
                                   clusters = cr$clusters, calculate_gap = FALSE)

# 5. Names + profile ----------------------------------------------------------
segment_names <- tryCatch(generate_segment_names(
  k = cr$k, method = "simple", data = data, clusters = cr$clusters,
  clustering_vars = clustering_vars, question_labels = config$question_labels,
  scale_max = 10), error = function(e) paste("Segment", seq_len(cr$k)))

pr <- create_full_segment_profile(data = data, clusters = cr$clusters,
        clustering_vars = clustering_vars, profile_vars = config$profile_vars)

# 6. Enhanced + vulnerability + golden + exec (each degrades gracefully) ------
enhanced <- list()
enhanced$rules <- tryCatch(generate_segment_rules(data = data, clusters = cr$clusters,
  clustering_vars = clustering_vars, question_labels = config$question_labels,
  max_depth = config$rules_max_depth %||% 3, segment_names = segment_names),
  error = function(e) { cat("rules FAILED:", e$message, "\n"); NULL })
enhanced$cards <- tryCatch(generate_segment_cards(data = data, clusters = cr$clusters,
  clustering_vars = clustering_vars, segment_names = segment_names,
  question_labels = config$question_labels, scale_max = 10),
  error = function(e) { cat("cards FAILED:", e$message, "\n"); NULL })

vulnerability <- tryCatch(calculate_vulnerability(data = scaled, clusters = cr$clusters,
  centers = cr$centers, method = "kmeans"),
  error = function(e) { cat("vuln FAILED:", e$message, "\n"); NULL })

golden_questions <- tryCatch({
  if (exists("identify_golden_questions", mode = "function"))
    identify_golden_questions(data = numeric_data, clusters = cr$clusters,
      segment_names = segment_names, n_top = 5, n_trees = 300) else NULL
}, error = function(e) { cat("golden FAILED:", e$message, "\n"); NULL })

exec_summary <- tryCatch(generate_segment_executive_summary(cluster_result = cr,
  validation_metrics = vm, profile_result = pr, segment_names = segment_names,
  config = config, enhanced = enhanced),
  error = function(e) { cat("exec FAILED:", e$message, "\n"); NULL })

# 7. Assemble results (R/00_main.R:546 shape) + render ------------------------
results <- list(mode = "final", cluster_result = cr, validation_metrics = vm,
  profile_result = pr, segment_names = segment_names, enhanced = enhanced,
  exec_summary = exec_summary, gmm_membership = NULL, vulnerability = vulnerability,
  golden_questions = golden_questions, data_list = data_list)

out_path <- file.path(outdir, "segment_baseline.html")
res <- generate_segment_html_report(results = results, config = config, output_path = out_path)

cat("\n==== BASELINE RESULT ====\n")
cat("status :", res$status, "\n")
cat("file   :", res$output_file %||% out_path, "\n")
cat("size_mb:", res$file_size_mb %||% NA, "\n")
cat("k:", cr$k, " n:", length(cr$clusters), " silhouette:", round(vm$avg_silhouette, 3), "\n")
cat("enhanced:", paste(names(Filter(Negate(is.null), enhanced)), collapse = ", "), "\n")
cat("golden:", !is.null(golden_questions), " vuln:", !is.null(vulnerability),
    " exec:", !is.null(exec_summary), "\n")
