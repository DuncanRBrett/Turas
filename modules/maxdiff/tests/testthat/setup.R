# ==============================================================================
# MAXDIFF TESTS - SETUP
# ==============================================================================
# Auto-loaded by testthat before running tests
# Sources all module files and provides test data generators

# --- Find project root ---
find_turas_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) || file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- find_turas_root()

# --- Null coalescing ---
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# --- Source shared utilities ---
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# --- Source MaxDiff module ---
maxdiff_r_dir <- file.path(TURAS_ROOT, "modules", "maxdiff", "R")
assign("script_dir_override", maxdiff_r_dir, envir = globalenv())

maxdiff_files <- c(
  "00_guard.R", "utils.R", "01_config.R", "02_validation.R", "03_data.R",
  "04_design.R", "05_counts.R", "06_logit.R", "07_hb.R", "08_segments.R",
  "09_output.R", "10_charts.R", "11_turf.R"
)

for (f in maxdiff_files) {
  fpath <- file.path(maxdiff_r_dir, f)
  if (file.exists(fpath)) {
    tryCatch(source(fpath, local = FALSE), error = function(e) {
      message(sprintf("Warning: Could not source %s: %s", f, e$message))
    })
  }
}

# --- Source HTML report module ---
html_report_dir <- file.path(TURAS_ROOT, "modules", "maxdiff", "lib", "html_report")
if (dir.exists(html_report_dir)) {
  for (f in sort(list.files(html_report_dir, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# --- Source HTML simulator module ---
html_sim_dir <- file.path(TURAS_ROOT, "modules", "maxdiff", "lib", "html_simulator")
if (dir.exists(html_sim_dir)) {
  for (f in sort(list.files(html_sim_dir, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# ==============================================================================
# TEST DATA GENERATORS
# ==============================================================================

#' Generate small synthetic MaxDiff test data
#' @param n_resp Number of respondents
#' @param n_items Number of items
#' @param n_tasks Number of tasks
#' @param items_per_task Items shown per task
generate_test_data <- function(n_resp = 30, n_items = 6, n_tasks = 6, items_per_task = 3) {

  set.seed(123)

  item_ids <- paste0("I", seq_len(n_items))
  true_utils <- rnorm(n_items, 0, 1)
  names(true_utils) <- item_ids

  # Generate individual utilities
  indiv_utils <- matrix(0, nrow = n_resp, ncol = n_items)
  colnames(indiv_utils) <- item_ids
  for (r in seq_len(n_resp)) {
    indiv_utils[r, ] <- true_utils + rnorm(n_items, 0, 0.5)
  }

  # Generate design
  design <- data.frame(
    Version = integer(), Task = integer(), Position = integer(), Item_Number = integer(),
    stringsAsFactors = FALSE
  )
  for (t in seq_len(n_tasks)) {
    shown <- sample(seq_len(n_items), items_per_task)
    for (p in seq_along(shown)) {
      design <- rbind(design, data.frame(Version = 1, Task = t, Position = p, Item_Number = shown[p]))
    }
  }

  # Generate responses
  responses <- list()
  for (r in seq_len(n_resp)) {
    for (t in seq_len(n_tasks)) {
      task_design <- design[design$Task == t, ]
      shown <- task_design$Item_Number
      utils_shown <- indiv_utils[r, shown]

      # Best choice (MNL)
      exp_u <- exp(utils_shown)
      best <- sample(shown, 1, prob = exp_u / sum(exp_u))

      # Worst choice (MNL on remaining with negated utils)
      remaining <- shown[shown != best]
      exp_neg <- exp(-indiv_utils[r, remaining])
      worst <- sample(remaining, 1, prob = exp_neg / sum(exp_neg))

      resp <- data.frame(
        Respondent_ID = sprintf("R%03d", r),
        Version = 1, Task = t,
        Best_Choice = best, Worst_Choice = worst,
        stringsAsFactors = FALSE
      )
      for (p in seq_along(shown)) {
        resp[[sprintf("Shown_%d", p)]] <- shown[p]
      }
      responses[[length(responses) + 1]] <- resp
    }
  }

  survey_data <- do.call(rbind, responses)

  # Items data frame
  items_df <- data.frame(
    Item_ID = item_ids,
    Item_Label = paste("Item", LETTERS[seq_len(n_items)]),
    Item_Group = "Test",
    Include = rep(1, n_items),
    Anchor_Item = rep(0, n_items),
    Display_Order = seq_len(n_items),
    stringsAsFactors = FALSE
  )

  list(
    survey_data = survey_data,
    design = design,
    items = items_df,
    true_utils = true_utils,
    individual_utils = indiv_utils,
    n_resp = n_resp,
    n_items = n_items,
    n_tasks = n_tasks
  )
}

message("MaxDiff test setup complete.")
