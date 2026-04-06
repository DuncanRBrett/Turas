# ==============================================================================
# TURAS KEY DRIVER ANALYSIS - FULL DEMO SHOWCASE
# ==============================================================================
#
# This script demonstrates ALL keydriver module capabilities:
#
#   1. Core Analysis       - Shapley, Relative Weight, Beta Weight, Correlation
#   2. SHAP Analysis       - XGBoost-based TreeSHAP importance
#   3. Quadrant Analysis   - Importance-Performance Analysis (IPA)
#   4. Bootstrap CIs       - Confidence intervals on importance scores
#   5. Effect Sizes        - Cohen's benchmarks and interpretation
#   6. Segment Comparison  - Cross-segment driver importance
#   7. Executive Summary   - Automated plain-English summary
#   8. Elastic Net         - Penalized variable selection (NEW v10.4)
#   9. NCA                 - Necessary Condition Analysis (NEW v10.4)
#  10. Dominance Analysis  - Complete & conditional dominance (NEW v10.4)
#  11. GAM                 - Nonlinear effects detection (NEW v10.4)
#  12. HTML Report         - Interactive standalone report
#
# Scenario:
#   A telecommunications company surveys 800 customers to understand
#   what drives overall satisfaction. 8 service attributes are tested
#   across 3 customer segments (Business, Residential, Premium).
#
# Usage:
#   source("examples/keydriver/demo_showcase/run_demo.R")
#
# Prerequisites:
#   - openxlsx package installed
#   - Run from Turas project root (or set working directory)
#
# ==============================================================================

cat("\n")
cat("================================================================\n")
cat("  TURAS KEY DRIVER ANALYSIS - DEMO SHOWCASE\n")
cat("  Telecom Customer Satisfaction Study\n")
cat("================================================================\n\n")

# ------------------------------------------------------------------
# Setup: Determine paths
# ------------------------------------------------------------------
demo_dir <- if (exists("demo_dir_override", envir = globalenv())) {
  get("demo_dir_override", envir = globalenv())
} else {
  # Try to detect from source location
  tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) {
    file.path(getwd(), "examples", "keydriver", "demo_showcase")
  })
}

# Find turas root
turas_root <- getwd()
while (!file.exists(file.path(turas_root, "launch_turas.R")) &&
       !dir.exists(file.path(turas_root, "modules", "shared")) &&
       turas_root != dirname(turas_root)) {
  turas_root <- dirname(turas_root)
}

cat(sprintf("Demo directory: %s\n", demo_dir))
cat(sprintf("Turas root: %s\n\n", turas_root))

# ------------------------------------------------------------------
# Step 0: Generate demo data and config
# ------------------------------------------------------------------
cat("STEP 0: Generating synthetic demo data\n")
cat(paste(rep("-", 50), collapse = ""), "\n")

source(file.path(demo_dir, "generate_demo_data.R"))
demo <- generate_telecom_demo_data(n = 800, seed = 42)

data_file <- file.path(demo_dir, "demo_survey_data.csv")
utils::write.csv(demo$data, data_file, row.names = FALSE)
cat(sprintf("  Data: %d respondents, %d variables\n", nrow(demo$data), ncol(demo$data)))
cat(sprintf("  Segments: %s\n", paste(unique(demo$data$customer_type), collapse = ", ")))
cat(sprintf("  Missing: %d cells (%.1f%%)\n",
            sum(is.na(demo$data)),
            100 * sum(is.na(demo$data)) / (nrow(demo$data) * ncol(demo$data))))

# Generate config
source(file.path(demo_dir, "create_demo_config.R"))
config_file <- file.path(demo_dir, "Demo_KeyDriver_Config.xlsx")
create_demo_config(config_file)
cat("\n")

# ------------------------------------------------------------------
# Step 1: Source shared infrastructure
# ------------------------------------------------------------------
cat("STEP 1: Loading Turas infrastructure\n")
cat(paste(rep("-", 50), collapse = ""), "\n")

shared_lib <- file.path(turas_root, "modules", "shared", "lib")
for (f in c("trs_refusal.R", "trs_run_state.R", "trs_banner.R",
            "trs_run_status_writer.R")) {
  fpath <- file.path(shared_lib, f)
  if (file.exists(fpath)) {
    source(fpath)
    cat(sprintf("  Loaded: %s\n", f))
  }
}

# Source keydriver modules
kd_dir <- file.path(turas_root, "modules", "keydriver", "R")
for (f in c("00_guard.R", "00_main.R", "01_config.R", "02_term_mapping.R",
            "02_validation.R", "03_analysis.R", "04_output.R",
            "05_bootstrap.R", "06_effect_size.R", "07_segment_comparison.R",
            "08_executive_summary.R",
            "09_elastic_net.R", "10_nca.R", "11_dominance.R", "12_gam.R")) {
  fpath <- file.path(kd_dir, f)
  if (file.exists(fpath)) {
    source(fpath)
    cat(sprintf("  Loaded: %s\n", f))
  }
}
cat("\n")

# ------------------------------------------------------------------
# Step 2: Run core key driver analysis
# ------------------------------------------------------------------
cat("STEP 2: Running core key driver analysis\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

results <- run_keydriver_analysis(
  config_file = config_file,
  data_file = data_file,
  output_file = file.path(demo_dir, "Demo_KeyDriver_Results.xlsx")
)

cat("\n")

# ------------------------------------------------------------------
# Step 3: Bootstrap confidence intervals
# ------------------------------------------------------------------
cat("\nSTEP 3: Bootstrap Confidence Intervals\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

bootstrap_ci <- bootstrap_importance_ci(
  data = demo$data,
  outcome = "overall_satisfaction",
  drivers = c("network_reliability", "customer_service", "value_for_money",
              "data_speed", "billing_clarity", "coverage_area",
              "app_experience", "contract_flexibility"),
  weights = "weight",
  n_bootstrap = 500,
  ci_level = 0.95
)

cat("\n  Bootstrap Results (95% CI):\n")
cat(paste(rep("-", 70), collapse = ""), "\n")
cat(sprintf("  %-22s %-15s %8s  [%8s, %8s]  %6s\n",
            "Driver", "Method", "Estimate", "Lower", "Upper", "SE"))
cat(paste(rep("-", 70), collapse = ""), "\n")

# Show correlation CIs for each driver
cor_results <- bootstrap_ci[bootstrap_ci$Method == "Correlation", ]
for (i in seq_len(nrow(cor_results))) {
  cat(sprintf("  %-22s %-15s %8.3f  [%8.3f, %8.3f]  %6.3f\n",
              cor_results$Driver[i],
              cor_results$Method[i],
              cor_results$Point_Estimate[i],
              cor_results$CI_Lower[i],
              cor_results$CI_Upper[i],
              cor_results$SE[i]))
}
cat("\n")

# Save bootstrap results
utils::write.csv(bootstrap_ci,
                 file.path(demo_dir, "Demo_Bootstrap_CIs.csv"),
                 row.names = FALSE)
cat(sprintf("  Saved: Demo_Bootstrap_CIs.csv\n"))

# ------------------------------------------------------------------
# Step 4: Effect size interpretation
# ------------------------------------------------------------------
cat("\nSTEP 4: Effect Size Interpretation\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Calculate reduced models for Cohen's f2
r2_full <- summary(results$model)$r.squared
driver_vars <- c("network_reliability", "customer_service", "value_for_money",
                 "data_speed", "billing_clarity", "coverage_area",
                 "app_experience", "contract_flexibility")

r2_reduced <- vapply(driver_vars, function(drv) {
  other_drivers <- setdiff(driver_vars, drv)
  formula_str <- paste("overall_satisfaction ~", paste(other_drivers, collapse = " + "))
  reduced_model <- lm(as.formula(formula_str), data = demo$data, weights = demo$data$weight)
  summary(reduced_model)$r.squared
}, numeric(1))
names(r2_reduced) <- driver_vars

model_info <- list(
  r_squared_full = r2_full,
  r_squared_reduced = r2_reduced
)

effect_results <- generate_effect_interpretation(results$importance, model_summary = model_info)

cat("\n  Effect Size Classifications:\n")
cat(paste(rep("-", 80), collapse = ""), "\n")
for (i in seq_len(nrow(effect_results))) {
  cat(sprintf("  %-22s | %-12s | f2 = %6.3f | %s\n",
              effect_results$Driver[i],
              effect_results$Effect_Size[i],
              effect_results$Effect_Value[i],
              effect_results$Benchmark_Method[i]))
}
cat("\n")

# Save effect size results
utils::write.csv(effect_results,
                 file.path(demo_dir, "Demo_Effect_Sizes.csv"),
                 row.names = FALSE)
cat(sprintf("  Saved: Demo_Effect_Sizes.csv\n"))

# ------------------------------------------------------------------
# Step 5: Segment comparison
# ------------------------------------------------------------------
cat("\nSTEP 5: Segment Comparison Analysis\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

segment_results <- run_segment_importance_comparison(
  data = demo$data,
  outcome = "overall_satisfaction",
  drivers = driver_vars,
  segment_var = "customer_type",
  config = list(top_n = 3, rank_diff_threshold = 3, min_segment_n = 30)
)

cat("\n  Comparison Matrix (Top 5 by Mean Importance):\n")
cat(paste(rep("-", 80), collapse = ""), "\n")
top5 <- head(segment_results$comparison_matrix, 5)
cat(sprintf("  %-22s  %8s  %8s  %8s  %8s\n",
            "Driver", "Business%", "Resid.%", "Premium%", "Mean%"))
cat(paste(rep("-", 80), collapse = ""), "\n")
for (i in seq_len(nrow(top5))) {
  cat(sprintf("  %-22s  %8.1f  %8.1f  %8.1f  %8.1f\n",
              top5$Driver[i],
              top5$Business_Pct[i],
              top5$Residential_Pct[i],
              top5$Premium_Pct[i],
              top5$Mean_Pct[i]))
}

cat("\n  Driver Classifications:\n")
for (i in seq_len(nrow(segment_results$classifications))) {
  cat(sprintf("  %-22s: %s\n",
              segment_results$classifications$Driver[i],
              segment_results$classifications$Classification[i]))
}

cat("\n  Key Insights:\n")
for (insight in segment_results$insights) {
  cat(sprintf("  > %s\n", insight))
}

# Save segment results
utils::write.csv(segment_results$comparison_matrix,
                 file.path(demo_dir, "Demo_Segment_Comparison.csv"),
                 row.names = FALSE)
cat(sprintf("\n  Saved: Demo_Segment_Comparison.csv\n"))

# ------------------------------------------------------------------
# Step 6: Executive summary
# ------------------------------------------------------------------
cat("\nSTEP 6: Executive Summary\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

exec_summary <- generate_executive_summary(results)

# Format and display
text_output <- format_executive_summary(exec_summary, format = "text")
cat("\n")
for (line in text_output) {
  cat(sprintf("  %s\n", line))
}

# Save text version
writeLines(text_output, file.path(demo_dir, "Demo_Executive_Summary.txt"))
cat(sprintf("\n  Saved: Demo_Executive_Summary.txt\n"))

# Save HTML version
html_output <- format_executive_summary(exec_summary, format = "html")
writeLines(html_output, file.path(demo_dir, "Demo_Executive_Summary.html"))
cat(sprintf("  Saved: Demo_Executive_Summary.html\n"))

# ------------------------------------------------------------------
# Step 7: Elastic Net Variable Selection (v10.4)
# ------------------------------------------------------------------
cat("\nSTEP 7: Elastic Net Variable Selection\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

enet_config <- list(
  outcome_var = "overall_satisfaction",
  driver_vars = driver_vars,
  weight_var = "weight",
  settings = list(elastic_net_alpha = 0.5, elastic_net_nfolds = 10)
)

enet_result <- tryCatch(
  run_elastic_net_analysis(demo$data, enet_config),
  error = function(e) { cat(sprintf("  [SKIP] %s\n", e$message)); NULL }
)

if (!is.null(enet_result) && enet_result$status == "PASS") {
  cat("\n  Elastic Net Results (lambda.1se):\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  coefs <- enet_result$result$coefficients
  for (i in seq_len(nrow(coefs))) {
    sel <- if (coefs$Selected_1se[i]) "*" else " "
    cat(sprintf("  %s %-22s  coef=%7.3f  importance=%5.1f%%\n",
                sel, coefs$Driver[i], coefs$Coefficient_1se[i], coefs$Importance_Pct[i]))
  }
  cat(sprintf("\n  Selected: %d / %d drivers\n",
              length(enet_result$result$selected_drivers), length(driver_vars)))
  results$elastic_net <- enet_result$result
}

# ------------------------------------------------------------------
# Step 8: Necessary Condition Analysis (v10.4)
# ------------------------------------------------------------------
cat("\nSTEP 8: Necessary Condition Analysis\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

nca_config <- list(
  outcome_var = "overall_satisfaction",
  driver_vars = driver_vars
)

nca_result <- tryCatch(
  run_nca_analysis(demo$data, nca_config),
  error = function(e) { cat(sprintf("  [SKIP] %s\n", e$message)); NULL }
)

if (!is.null(nca_result) && nca_result$status == "PASS") {
  cat("\n  NCA Results:\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  nca_df <- nca_result$result$nca_summary
  for (i in seq_len(nrow(nca_df))) {
    cat(sprintf("  %-22s  effect=%.3f  p=%.4f  %s\n",
                nca_df$Driver[i], nca_df$NCA_Effect_Size[i],
                nca_df$NCA_p_value[i], nca_df$Classification[i]))
  }
  cat(sprintf("\n  Necessary conditions: %d of %d\n",
              nca_result$result$n_necessary, nca_result$result$n_analysed))
  results$nca <- nca_result$result
}

# ------------------------------------------------------------------
# Step 9: Dominance Analysis (v10.4)
# ------------------------------------------------------------------
cat("\nSTEP 9: Dominance Analysis\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

dom_config <- list(
  outcome_var = "overall_satisfaction",
  driver_vars = driver_vars,
  weight_var = "weight"
)

dom_result <- tryCatch(
  run_dominance_analysis(demo$data, dom_config),
  error = function(e) { cat(sprintf("  [SKIP] %s\n", e$message)); NULL }
)

if (!is.null(dom_result) && dom_result$status == "PASS") {
  cat("\n  General Dominance (Shapley-equivalent R-squared decomposition):\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  dom_df <- dom_result$result$summary
  for (i in seq_len(nrow(dom_df))) {
    cat(sprintf("  #%d  %-22s  R2=%.4f  (%5.1f%%)\n",
                dom_df$Rank[i], dom_df$Driver[i],
                dom_df$General_Dominance[i], dom_df$General_Pct[i]))
  }
  cat(sprintf("\n  Total R-squared: %.4f\n", dom_result$result$total_r_squared))
  results$dominance <- dom_result$result
}

# ------------------------------------------------------------------
# Step 10: GAM Nonlinear Effects (v10.4)
# ------------------------------------------------------------------
cat("\nSTEP 10: GAM Nonlinear Effects\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

gam_config <- list(
  outcome_var = "overall_satisfaction",
  driver_vars = driver_vars,
  weight_var = "weight",
  settings = list(gam_k = 5)
)

gam_result <- tryCatch(
  run_gam_analysis(demo$data, gam_config),
  error = function(e) { cat(sprintf("  [SKIP] %s\n", e$message)); NULL }
)

if (!is.null(gam_result) && gam_result$status == "PASS") {
  cat("\n  Nonlinearity Assessment:\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  gam_df <- gam_result$result$nonlinearity_summary
  for (i in seq_len(nrow(gam_df))) {
    cat(sprintf("  %-22s  EDF=%5.2f  p=%7.4f  %s\n",
                gam_df$Driver[i], gam_df$EDF[i],
                gam_df$p_value[i], gam_df$Shape[i]))
  }
  cat(sprintf("\n  Linear R2: %.3f | GAM deviance: %.3f | Improvement: %.3f\n",
              gam_result$result$linear_r_squared,
              gam_result$result$deviance_explained,
              gam_result$result$improvement))
  results$gam <- gam_result$result
}

# ------------------------------------------------------------------
# Step 11: HTML Report (if library available)
# ------------------------------------------------------------------
cat("\nSTEP 11: Interactive HTML Report\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

html_lib_dir <- file.path(turas_root, "modules", "keydriver", "lib", "html_report")
html_main <- file.path(html_lib_dir, "99_html_report_main.R")

if (file.exists(html_main)) {
  cat("  Loading HTML report library...\n")

  # Set lib dir for submodule sourcing
  assign(".keydriver_lib_dir", file.path(turas_root, "modules", "keydriver", "lib"),
         envir = globalenv())
  source(html_main, local = FALSE)

  html_report_path <- file.path(demo_dir, "Demo_KeyDriver_Report.html")

  # Attach supplementary data to results for HTML report
  results$bootstrap_ci <- bootstrap_ci
  results$effect_sizes <- effect_results
  results$segment_comparison <- segment_results
  results$executive_summary <- exec_summary

  tryCatch({
    if (exists("generate_keydriver_html_report", mode = "function")) {
      html_config <- list(
        brand_colour = "#4472C4",
        accent_colour = "#f59e0b"
      )
      html_result <- generate_keydriver_html_report(
        results = results,
        config = html_config,
        output_path = html_report_path
      )
      if (is.list(html_result) && !is.null(html_result$status) && html_result$status == "REFUSED") {
        cat(sprintf("  [WARN] HTML report refused: %s\n", html_result$message %||% "Unknown"))
      } else if (file.exists(html_report_path)) {
        cat(sprintf("  [OK] HTML report generated: %s\n", html_report_path))
      } else {
        cat("  [WARN] HTML report generation returned but file not created\n")
      }
    } else {
      cat("  [SKIP] generate_keydriver_html_report() not found\n")
    }
  }, error = function(e) {
    cat(sprintf("  [WARN] HTML report generation failed: %s\n", e$message))
    cat("  This is expected if optional dependencies are not installed.\n")
  })
} else {
  cat("  [SKIP] HTML report library not found\n")
}

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
cat("\n")
cat("================================================================\n")
cat("  DEMO COMPLETE\n")
cat("================================================================\n\n")

cat("Generated outputs:\n")
outputs <- c(
  "Demo_KeyDriver_Results.xlsx  - Full Excel results workbook",
  "Demo_Bootstrap_CIs.csv      - Bootstrap confidence intervals",
  "Demo_Effect_Sizes.csv       - Effect size classifications",
  "Demo_Segment_Comparison.csv - Cross-segment comparison matrix",
  "Demo_Executive_Summary.txt  - Plain text executive summary",
  "Demo_Executive_Summary.html - HTML executive summary",
  "Demo_KeyDriver_Report.html  - Interactive HTML report (if available)",
  "                               Includes v10.4: Elastic Net, NCA, Dominance, GAM"
)
for (o in outputs) {
  fname <- trimws(strsplit(o, " - ")[[1]][1])
  exists_flag <- if (file.exists(file.path(demo_dir, fname))) "[OK]" else "[--]"
  cat(sprintf("  %s %s\n", exists_flag, o))
}

cat("\nTrue driver weights (for validation):\n")
for (i in seq_along(demo$true_weights)) {
  cat(sprintf("  %-22s: %.0f%%\n",
              names(demo$true_weights)[i],
              demo$true_weights[i] * 100))
}

cat("\nKey results:\n")
cat(sprintf("  Model R-squared: %.3f\n", summary(results$model)$r.squared))
cat(sprintf("  Run status: %s\n", results$run_status))
cat(sprintf("  Top driver: %s\n", results$importance$Driver[1]))
cat(sprintf("  Sample size: %d\n", nobs(results$model)))

cat("\n================================================================\n")
cat("  Open Demo_KeyDriver_Results.xlsx to explore the full output\n")
cat("================================================================\n\n")
