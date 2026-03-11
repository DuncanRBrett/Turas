# ==============================================================================
# MAXDIFF DEMO - RUN SHOWCASE
# ==============================================================================
# Demonstrates the full MaxDiff module v11.0 with all features:
# - Count-based scores + Aggregate logit + HB estimation
# - TURF portfolio optimization
# - Anchored MaxDiff (must-have threshold)
# - Item discrimination (consensus vs polarizing)
# - HTML report + Interactive simulator
#
# PREREQUISITES:
# 1. Run from Turas project root directory
# 2. Demo data must exist (run generate_demo_data.R first)
# 3. Demo config must exist (run create_demo_config.R first)
#
# USAGE:
#   setwd("/path/to/Turas")
#   source("examples/maxdiff/demo_showcase/run_demo.R")
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("  TURAS MAXDIFF MODULE v11.0 - DEMO SHOWCASE\n")
cat("  Smartphone Feature Prioritization Study\n")
cat("================================================================================\n\n")

# ==============================================================================
# SECTION 0: PREREQUISITES
# ==============================================================================

cat("--- Section 0: Checking prerequisites ---\n\n")

# Check working directory
if (!file.exists("launch_turas.R") && !file.exists("CLAUDE.md")) {
  stop("Please set working directory to the Turas project root.\n  Use: setwd('/path/to/Turas')")
}

demo_dir <- "examples/maxdiff/demo_showcase"

# Check demo data
if (!file.exists(file.path(demo_dir, "demo_data.csv"))) {
  cat("Demo data not found. Generating...\n")
  source(file.path(demo_dir, "generate_demo_data.R"))
}

# Check config
config_path <- file.path(demo_dir, "Demo_MaxDiff_Config.xlsx")
if (!file.exists(config_path)) {
  cat("Demo config not found. Creating...\n")
  source(file.path(demo_dir, "create_demo_config.R"))
}

# Check packages
required_pkgs <- c("openxlsx")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Required package '%s' not installed. Install with: install.packages('%s')", pkg, pkg))
  }
}

has_survival <- requireNamespace("survival", quietly = TRUE)
has_cmdstanr <- requireNamespace("cmdstanr", quietly = TRUE)

cat("  Working directory: OK\n")
cat("  Demo data: OK\n")
cat("  Demo config: OK\n")
cat(sprintf("  survival package: %s\n", if (has_survival) "Available" else "Not available (simple logit fallback)"))
cat(sprintf("  cmdstanr package: %s\n", if (has_cmdstanr) "Available" else "Not available (approximate HB fallback)"))

# ==============================================================================
# SECTION 1: SOURCE MODULE
# ==============================================================================

cat("\n--- Section 1: Loading MaxDiff module ---\n\n")

# Source shared utilities
shared_lib <- file.path("modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# Source MaxDiff module (sets script_dir_override for path resolution)
assign("script_dir_override", file.path(getwd(), "modules", "maxdiff", "R"), envir = globalenv())
source(file.path("modules", "maxdiff", "R", "00_main.R"))

cat("  Module loaded successfully.\n")

# ==============================================================================
# SECTION 2: RUN ANALYSIS
# ==============================================================================

cat("\n--- Section 2: Running MaxDiff analysis ---\n\n")

results <- run_maxdiff(config_path, verbose = TRUE)

# ==============================================================================
# SECTION 3: PRINT KEY RESULTS
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("  RESULTS SUMMARY\n")
cat("================================================================================\n\n")

# Count scores
if (!is.null(results$count_scores)) {
  cat("--- COUNT-BASED SCORES (Top 5) ---\n")
  cs <- results$count_scores
  if ("BW_Score" %in% names(cs)) {
    cs <- cs[order(-cs$BW_Score), ]
    top5 <- head(cs, 5)
    for (i in seq_len(nrow(top5))) {
      cat(sprintf("  %d. %s (BW: %.3f, Best%%: %.1f, Worst%%: %.1f)\n",
                  i, top5$Item_Label[i] %||% top5$Item_ID[i],
                  top5$BW_Score[i], top5$Best_Pct[i], top5$Worst_Pct[i]))
    }
  }
  cat("\n")
}

# Logit results
if (!is.null(results$logit_results)) {
  cat("--- AGGREGATE LOGIT ---\n")
  lu <- results$logit_results$utilities
  if (!is.null(lu)) {
    lu <- lu[order(-lu$Logit_Utility), ]
    top3 <- head(lu, 3)
    for (i in seq_len(nrow(top3))) {
      cat(sprintf("  %d. %s (Utility: %.3f)\n",
                  i, top3$Item_Label[i] %||% top3$Item_ID[i], top3$Logit_Utility[i]))
    }
  }
  if (!is.null(results$logit_results$fit_stats)) {
    fs <- results$logit_results$fit_stats
    cat(sprintf("  McFadden R2: %.4f\n", fs$pseudo_r2 %||% fs$mcfadden_r2 %||% NA))
  }
  cat("\n")
}

# HB results
if (!is.null(results$hb_results)) {
  cat("--- HIERARCHICAL BAYES ---\n")
  pop <- results$hb_results$population_utilities
  if (!is.null(pop)) {
    pop <- pop[order(-pop$HB_Utility_Mean), ]
    top3 <- head(pop, 3)
    for (i in seq_len(nrow(top3))) {
      cat(sprintf("  %d. %s (Utility: %.3f, SD: %.3f)\n",
                  i, top3$Item_Label[i] %||% top3$Item_ID[i],
                  top3$HB_Utility_Mean[i], top3$HB_Utility_SD[i]))
    }
  }
  if (!is.null(results$hb_results$diagnostics)) {
    hd <- results$hb_results$diagnostics
    cat(sprintf("  Max R-hat: %.4f\n", hd$max_rhat %||% NA))
    cat(sprintf("  Quality Score: %.0f/100\n", hd$quality_score %||% NA))
  }
  cat("\n")
}

# Preference shares
if (!is.null(results$hb_results$individual_utilities)) {
  tryCatch({
    cat("--- PREFERENCE SHARES ---\n")
    shares <- compute_preference_shares(individual_utils = results$hb_results$individual_utilities)
    shares_sorted <- sort(shares, decreasing = TRUE)
    for (i in seq_len(min(5, length(shares_sorted)))) {
      cat(sprintf("  %s: %.1f%%\n", names(shares_sorted)[i], shares_sorted[i]))
    }
    cat("\n")
  }, error = function(e) {
    cat(sprintf("  (Could not compute preference shares: %s)\n\n", e$message))
  })
}

# TURF results
if (!is.null(results$turf_results) && results$turf_results$status == "PASS") {
  cat("--- TURF PORTFOLIO OPTIMIZATION ---\n")
  turf <- results$turf_results$incremental_table
  for (i in seq_len(nrow(turf))) {
    cat(sprintf("  Step %d: +%s (Reach: %.1f%%, +%.1f%%)\n",
                turf$Step[i], turf$Item_Label[i],
                turf$Reach_Pct[i], turf$Incremental_Pct[i]))
  }
  cat("\n")
}

# Anchor data
if (!is.null(results$anchor_data)) {
  cat("--- ANCHORED MAXDIFF (Must-Haves) ---\n")
  ad <- results$anchor_data
  must_haves <- ad[ad$Is_Must_Have == TRUE, ]
  if (nrow(must_haves) > 0) {
    cat("  Must-Have items (anchor rate > 50%):\n")
    for (i in seq_len(nrow(must_haves))) {
      cat(sprintf("    %s: %.0f%%\n",
                  must_haves$Item_Label[i] %||% must_haves$Item_ID[i],
                  must_haves$Anchor_Rate[i] * 100))
    }
  } else {
    cat("  No items met the must-have threshold.\n")
  }
  cat("\n")
}

# Item discrimination
if (!is.null(results$discrimination_data)) {
  cat("--- ITEM DISCRIMINATION ---\n")
  disc <- results$discrimination_data
  for (cls in c("Universal Favorite", "Polarizing", "Low Priority")) {
    items_in_cls <- disc[disc$Classification_Label == cls, ]
    if (nrow(items_in_cls) > 0) {
      labels <- paste(items_in_cls$Item_Label %||% items_in_cls$Item_ID, collapse = ", ")
      cat(sprintf("  %s: %s\n", cls, labels))
    }
  }
  cat("\n")
}

# ==============================================================================
# SECTION 4: OUTPUT FILES
# ==============================================================================

cat("--- OUTPUT FILES ---\n")

output_dir <- file.path(demo_dir, "output")
if (dir.exists(output_dir)) {
  files <- list.files(output_dir, full.names = TRUE)
  for (f in files) {
    size_kb <- round(file.info(f)$size / 1024, 1)
    cat(sprintf("  %s (%.1f KB)\n", basename(f), size_kb))
  }
}

if (!is.null(results$output_path)) {
  cat(sprintf("\n  Excel results: %s\n", results$output_path))
}
if (!is.null(results$html_report_path)) {
  cat(sprintf("  HTML report:   %s\n", results$html_report_path))
}
if (!is.null(results$simulator_path)) {
  cat(sprintf("  Simulator:     %s\n", results$simulator_path))
}

cat("\n================================================================================\n")
cat("  DEMO COMPLETE\n")
cat("  Open the HTML report in your browser to explore results interactively.\n")
cat("================================================================================\n\n")
