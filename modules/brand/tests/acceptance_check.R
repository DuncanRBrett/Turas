# ==============================================================================
# PORTFOLIO ACCEPTANCE CHECKS (§11)
# Run with: Rscript modules/brand/tests/acceptance_check.R
# ==============================================================================

find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  stop("Cannot find TURAS_ROOT")
}
TURAS_ROOT <- find_root()
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE)))
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
brand_r_dir <- file.path(TURAS_ROOT, "modules", "brand", "R")
assign("brand_script_dir_override", brand_r_dir, envir = globalenv())
for (f in list.files(brand_r_dir, pattern = "\\.R$", full.names = FALSE)) {
  fpath <- file.path(brand_r_dir, f)
  tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}

cat("=== PORTFOLIO ACCEPTANCE CHECKS (§11) ===\n\n")

# ---------------------------------------------------------------------------
# Shared fixture: 3 categories, 200 respondents each = 600 total
# ---------------------------------------------------------------------------
set.seed(42L)
N <- 200
cats_codes <- c("CAT1", "CAT2", "CAT3")
brands_per_cat <- list(
  CAT1 = c("IPK", "A1", "B1", "C1"),
  CAT2 = c("IPK", "A2", "B2", "C2"),
  CAT3 = c("IPK", "A3", "B3", "C3")
)
make_data <- function(n = N) {
  d <- data.frame(matrix(0L, n, 0))
  for (cc in cats_codes) {
    d[[paste0("SQ1_", cc)]] <- rbinom(n, 1, 0.6)
    d[[paste0("SQ2_", cc)]] <- as.integer(d[[paste0("SQ1_", cc)]] == 1 & rbinom(n, 1, 0.7))
    for (b in brands_per_cat[[cc]]) {
      col <- paste0("BRANDAWARE_", cc, "_", b)
      p   <- if (b == "IPK") 0.75 else runif(1, 0.25, 0.55)
      d[[col]] <- as.integer(d[[paste0("SQ1_", cc)]] == 1 & rbinom(n, 1, p))
    }
  }
  d
}
make_structure <- function() {
  brands_df <- do.call(rbind, lapply(cats_codes, function(cc) {
    data.frame(Category = paste0("Cat_", cc), BrandCode = brands_per_cat[[cc]],
               DisplayOrder = seq_along(brands_per_cat[[cc]]),
               stringsAsFactors = FALSE)
  }))
  qmap <- data.frame(
    Role       = paste0("funnel.awareness.", cats_codes),
    ClientCode = paste0("BRANDAWARE_", cats_codes),
    stringsAsFactors = FALSE
  )
  list(brands = brands_df, questionmap = qmap)
}
make_categories <- function() {
  data.frame(Category = paste0("Cat_", cats_codes), stringsAsFactors = FALSE)
}
make_config <- function(min_base = 20L) {
  list(
    focal_brand = "IPK", portfolio_timeframe = "3m", portfolio_min_base = min_base,
    portfolio_cooccur_min_pairs = 5L, portfolio_edge_top_n = 40L,
    portfolio_extension_baseline = "all", focal_home_category = "",
    element_portfolio = TRUE, cross_category_awareness = TRUE
  )
}
DATA      <- make_data()
STRUCTURE <- make_structure()
CATS      <- make_categories()
CONFIG    <- make_config()

# ---------------------------------------------------------------------------
# CRITERION 2 — Integration: run_portfolio() produces PASS with all sub-analyses
# ---------------------------------------------------------------------------
cat("--- Criterion 2: Integration test ---\n")
r2 <- run_portfolio(DATA, CATS, STRUCTURE, CONFIG)
cat2_ok <- identical(r2$status, "PASS") &&
  !is.null(r2$footprint_matrix) &&
  !is.null(r2$clutter) &&
  !is.null(r2$strength) &&
  !is.null(r2$constellation) &&
  !is.null(r2$supporting)
cat(if (cat2_ok) "  PASS: run_portfolio returns PASS with all 5 sub-analyses\n" else
  "  FAIL: integration test failed\n")

# ---------------------------------------------------------------------------
# CRITERION 3 — TRS refusal codes (§9)
# ---------------------------------------------------------------------------
cat("\n--- Criterion 3: TRS refusal codes ---\n")
cfg_noaware <- within(make_config(), { cross_category_awareness <- FALSE })
r_noaware <- tryCatch(
  run_portfolio(DATA, CATS, STRUCTURE, cfg_noaware),
  error = function(e) list(status = "REFUSED", code = "ERROR", message = e$message)
)
cat(sprintf("  CFG_PORTFOLIO_AWARENESS_OFF: %s\n",
  if (identical(r_noaware$status, "REFUSED") &&
      identical(r_noaware$code, "CFG_PORTFOLIO_AWARENESS_OFF")) "PASS" else "FAIL"))

# CALC_CONSTELLATION_TOO_SPARSE
sparse_d <- DATA
for (b in c("A1","B1","C1","A2","B2","C2","A3","B3","C3")) {
  for (cc in cats_codes) {
    col <- paste0("BRANDAWARE_", cc, "_", b)
    if (col %in% names(sparse_d)) sparse_d[[col]] <- 0L
  }
}
r_sparse <- compute_constellation(sparse_d, CATS, STRUCTURE, CONFIG)
cat(sprintf("  CALC_CONSTELLATION_TOO_SPARSE: %s\n",
  if (identical(r_sparse$status, "REFUSED") &&
      identical(r_sparse$code, "CALC_CONSTELLATION_TOO_SPARSE")) "PASS" else "FAIL"))

# CALC_EXTENSION_NO_FOCAL_AWARENESS — triggered when no BRANDAWARE_*_IPK columns
no_focal_d <- DATA
ipk_cols <- grep("BRANDAWARE_.*_IPK$", names(no_focal_d), value = TRUE)
no_focal_d <- no_focal_d[, setdiff(names(no_focal_d), ipk_cols), drop = FALSE]
r_nofocal <- compute_extension_table(no_focal_d, CATS, STRUCTURE, CONFIG)
cat(sprintf("  CALC_EXTENSION_NO_FOCAL_AWARENESS: %s\n",
  if (identical(r_nofocal$status, "REFUSED") &&
      identical(r_nofocal$code, "CALC_EXTENSION_NO_FOCAL_AWARENESS")) "PASS" else "FAIL"))

# ---------------------------------------------------------------------------
# CRITERION 4 — Structural: Jaccard in [0,1], lift > 0, footprint in [0,100]
# ---------------------------------------------------------------------------
cat("\n--- Criterion 4: Structural tests ---\n")
r4 <- r2
if (!is.null(r4$constellation$edges) && nrow(r4$constellation$edges) > 0) {
  j_range <- range(r4$constellation$edges$jaccard, na.rm = TRUE)
  cat(sprintf("  Jaccard range: [%.3f, %.3f] %s\n", j_range[1], j_range[2],
    if (j_range[1] >= 0 && j_range[2] <= 1) "PASS" else "FAIL"))
}
if (!is.null(r4$extension$extension_df) && nrow(r4$extension$extension_df) > 0) {
  non_home <- r4$extension$extension_df[!r4$extension$extension_df$is_home, ]
  if (nrow(non_home) > 0) {
    lift_pos <- all(non_home$lift[!non_home$low_base_flag] > 0, na.rm = TRUE)
    cat(sprintf("  Lift > 0 for non-home cats: %s\n", if (lift_pos) "PASS" else "FAIL"))
  }
}
if (!is.null(r4$footprint_matrix)) {
  fp_vals <- unlist(r4$footprint_matrix[, setdiff(names(r4$footprint_matrix), "Brand")],
                     use.names = FALSE)
  fp_vals <- fp_vals[!is.na(fp_vals)]
  cat(sprintf("  Footprint in [0,100]: %s\n",
    if (all(fp_vals >= 0 & fp_vals <= 100)) "PASS" else "FAIL"))
}

# ---------------------------------------------------------------------------
# CRITERION 7 — Low-base suppression: min_base=9999 → all cats suppressed
# ---------------------------------------------------------------------------
cat("\n--- Criterion 7: Low-base suppression ---\n")
r7 <- run_portfolio(DATA, CATS, STRUCTURE, make_config(min_base = 9999L))
suppressed_all <- length(r7$suppressions$low_base_cats) >= length(cats_codes) ||
  (identical(r7$status, "REFUSED") || is.null(r7$footprint_matrix) ||
   is.null(r7$clutter$clutter_df) || nrow(r7$clutter$clutter_df) == 0)
cat(sprintf("  All cats suppressed with min_base=9999: %s\n",
  if (suppressed_all) "PASS" else "FAIL"))
cat(sprintf("  Suppressed cats: %s\n", paste(r7$suppressions$low_base_cats, collapse=", ")))

# ---------------------------------------------------------------------------
# CRITERION 8 — Performance: run_portfolio on 600 respondents × 3 cats
# ---------------------------------------------------------------------------
cat("\n--- Criterion 8: Performance test ---\n")
t8 <- system.time(
  run_portfolio(DATA, CATS, STRUCTURE, CONFIG)
)
cat(sprintf("  run_portfolio on 600 resp × 3 cats: %.2f sec %s\n",
  t8["elapsed"],
  if (t8["elapsed"] < 3.0) "PASS" else "WARN (>3s)"))

# ---------------------------------------------------------------------------
# CRITERION 9 — Excel+CSV outputs: 6 sheets present
# ---------------------------------------------------------------------------
cat("\n--- Criterion 9: Excel + CSV outputs ---\n")
tmp_dir <- tempdir()
csv_r <- write_portfolio_csv(r2, tmp_dir, CONFIG)
csv_files <- list.files(file.path(tmp_dir, "portfolio"), pattern = "\\.csv$")
cat(sprintf("  CSV files written: %d %s\n", length(csv_files),
  if (length(csv_files) >= 5) "PASS" else "FAIL"))

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  hs <- openxlsx::createStyle(fontName = "Calibri", fontSize = 11,
    fontColour = "#FFFFFF", fgFill = "#323367", textDecoration = "bold")
  write_portfolio_sheets(r2, wb, hs, CONFIG)
  pf_sheets <- names(wb)[grepl("^Portfolio_", names(wb))]
  cat(sprintf("  Excel portfolio sheets: %d %s\n", length(pf_sheets),
    if (length(pf_sheets) >= 5) "PASS" else "FAIL"))
  cat(sprintf("  Sheets: %s\n", paste(pf_sheets, collapse=", ")))
}

# ---------------------------------------------------------------------------
# CRITERION 10 — No igraph: pure-R layout works
# ---------------------------------------------------------------------------
cat("\n--- Criterion 10: Pure-R FR layout (no igraph required) ---\n")
pos <- .fr_layout_r(n = 5L, adj = matrix(0.5, 5, 5) - diag(0.5, 5), n_iter = 20L)
cat(sprintf("  .fr_layout_r returns 5x2 matrix: %s\n",
  if (is.matrix(pos) && all(dim(pos) == c(5, 2))) "PASS" else "FAIL"))
# Simulate run without igraph by using pure-R path directly
pos2 <- .fr_layout_r(n = 3L, adj = matrix(c(0,.5,.3,.5,0,.4,.3,.4,0), 3, 3), n_iter = 10L)
cat(sprintf("  Deterministic (same seed): %s\n",
  if (identical(.fr_layout_r(3, matrix(0.3, 3, 3), n_iter = 10L),
                .fr_layout_r(3, matrix(0.3, 3, 3), n_iter = 10L))) "PASS" else "FAIL"))

cat("\n=== END ACCEPTANCE CHECKS ===\n")
