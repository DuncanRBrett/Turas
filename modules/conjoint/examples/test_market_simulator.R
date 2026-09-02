# ==============================================================================
# EXERCISE THE MARKET SIMULATOR FUNCTIONS ON THE EXAMPLE
# ==============================================================================
#
# Runs the smartphone example, then calls the share-prediction and one-way
# sensitivity functions directly on its utilities table, the same functions
# the standalone HTML simulator's numbers are checked against. Works from any
# working directory: it finds the Turas root by walking up from this file.
#
# Usage:
#   Rscript modules/conjoint/examples/test_market_simulator.R
# ==============================================================================

.find_turas_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules", "conjoint"))) return(normalizePath(home))
  start <- local({
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg))))
    getwd()
  })
  d <- start
  for (i in 1:8) {
    if (dir.exists(file.path(d, "modules", "conjoint", "R"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("Cannot find the Turas root above ", start, ". Run from inside the Turas folder.")
}

turas_root <- .find_turas_root()
setwd(turas_root)

cat("\n", strrep("=", 78), "\n", sep = "")
cat("TURAS CONJOINT: MARKET SIMULATOR FUNCTIONS\n")
cat(strrep("=", 78), "\n\n", sep = "")

cat("1. Loading the module and running the example...\n")
source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))
results <- run_conjoint_analysis(
  config_file = file.path(turas_root, "modules", "conjoint", "examples", "example_config.xlsx"),
  verbose = FALSE
)
if (!is.list(results) || is.null(results$utilities)) {
  stop("The example run did not produce a utilities table; see the messages above.")
}
cat(sprintf("   %d part-worth utilities estimated (%s)\n\n",
            nrow(results$utilities), results$model_result$method))

# --- Three products to compare ---------------------------------------------------

products <- list(
  list(Brand = "Apple", Price = "$299", Screen_Size = "6.7 inches",
       Battery_Life = "24 hours", Camera_Quality = "Excellent"),
  list(Brand = "Samsung", Price = "$399", Screen_Size = "6.1 inches",
       Battery_Life = "18 hours", Camera_Quality = "Good"),
  list(Brand = "OnePlus", Price = "$599", Screen_Size = "5.5 inches",
       Battery_Life = "12 hours", Camera_Quality = "Basic")
)

cat("2. Share of preference, multinomial logit rule:\n")
shares_logit <- predict_market_shares(products = products, utilities = results$utilities,
                                      method = "logit", verbose = FALSE)
for (i in seq_len(nrow(shares_logit))) {
  cat(sprintf("   %-10s %5.1f%%  (total utility %.2f)\n", shares_logit$Product[i],
              shares_logit$Share_Percent[i], shares_logit$Total_Utility[i]))
}
total_share <- sum(shares_logit$Share_Percent)
if (abs(total_share - 100) > 0.1) stop(sprintf("Shares sum to %.1f, not 100.", total_share))
cat("   Shares sum to 100.\n\n")

cat("3. First-choice rule:\n")
shares_fc <- predict_market_shares(products = products, utilities = results$utilities,
                                   method = "first_choice", verbose = FALSE)
winner <- shares_fc$Product[shares_fc$Share_Percent == 100]
cat(sprintf("   Winner: %s\n\n", paste(winner, collapse = ", ")))

cat("4. One-way sensitivity on the first product's price:\n")
if (exists("sensitivity_analysis", mode = "function")) {
  sens <- tryCatch(
    sensitivity_analysis(base_product = products[[1]], competitor_products = products[-1],
                         attribute = "Price", utilities = results$utilities, verbose = FALSE),
    error = function(e) { cat("   sensitivity_analysis:", conditionMessage(e), "\n"); NULL }
  )
  if (is.data.frame(sens)) print(sens, row.names = FALSE)
} else {
  cat("   sensitivity_analysis() is not defined in this build; skipped.\n")
}

cat("\nDone.\n")
invisible(results)
