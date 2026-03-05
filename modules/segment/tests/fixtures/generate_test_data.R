# ==============================================================================
# SEGMENT MODULE - TEST DATA GENERATOR
# ==============================================================================
# Generates synthetic survey data with known cluster structure for testing.
#
# Features:
#   - 300 respondents, 10 numeric vars, 3 true clusters
#   - 5% MCAR missingness
#   - 3 deliberate outliers
#   - Demographics: gender, age_group, region
#   - Fixed seed for reproducibility
# ==============================================================================


#' Generate Synthetic Segmentation Test Data
#'
#' Creates a reproducible test dataset with known cluster structure.
#'
#' @param n Total respondents (default 300)
#' @param k_true True number of clusters (default 3)
#' @param n_vars Number of numeric clustering variables (default 10)
#' @param missing_rate Proportion of MCAR missingness (default 0.05)
#' @param n_outliers Number of outlier cases to inject (default 3)
#' @param seed Random seed (default 42)
#' @return List with data (data.frame), true_clusters, metadata
#' @export
generate_segment_test_data <- function(n = 300, k_true = 3, n_vars = 10,
                                        missing_rate = 0.05, n_outliers = 3,
                                        seed = 42) {

  set.seed(seed)

  # Cluster sizes (roughly equal)
  cluster_sizes <- diff(round(seq(0, n - n_outliers, length.out = k_true + 1)))

  # Generate cluster centers (well-separated)
  centers <- matrix(0, nrow = k_true, ncol = n_vars)
  for (i in seq_len(k_true)) {
    # Each cluster has distinct pattern on different variable subsets
    shift <- (i - 1) * 2
    centers[i, ] <- rep(5, n_vars)  # Base value at 5 (scale 1-10)

    # Create distinct signatures
    if (i == 1) {
      centers[i, 1:4] <- c(8, 7, 8, 7)   # High on vars 1-4
      centers[i, 5:7] <- c(3, 3, 4)       # Low on vars 5-7
    } else if (i == 2) {
      centers[i, 1:4] <- c(3, 4, 3, 4)   # Low on vars 1-4
      centers[i, 5:7] <- c(8, 7, 8)       # High on vars 5-7
      centers[i, 8:10] <- c(7, 6, 7)      # Moderate-high on vars 8-10
    } else if (i == 3) {
      centers[i, 1:4] <- c(5, 5, 5, 5)   # Average on vars 1-4
      centers[i, 5:7] <- c(5, 5, 5)       # Average on vars 5-7
      centers[i, 8:10] <- c(2, 3, 2)      # Low on vars 8-10
    }
  }

  # Generate data from each cluster
  data_list <- list()
  true_clusters <- integer(0)

  for (i in seq_len(k_true)) {
    ni <- cluster_sizes[i]
    cluster_data <- matrix(NA, nrow = ni, ncol = n_vars)

    for (j in seq_len(n_vars)) {
      cluster_data[, j] <- rnorm(ni, mean = centers[i, j], sd = 1.0)
    }

    # Clamp to 1-10 scale
    cluster_data <- pmax(1, pmin(10, cluster_data))

    data_list[[i]] <- cluster_data
    true_clusters <- c(true_clusters, rep(i, ni))
  }

  # Combine clusters
  numeric_data <- do.call(rbind, data_list)

  # Add outliers
  if (n_outliers > 0) {
    outlier_data <- matrix(NA, nrow = n_outliers, ncol = n_vars)
    for (j in seq_len(n_vars)) {
      outlier_data[, j] <- runif(n_outliers, min = 0, max = 10)
    }
    # Make outliers extreme on some variables
    outlier_data[1, 1:3] <- c(10, 10, 10)
    outlier_data[2, 5:7] <- c(1, 1, 1)
    if (n_outliers >= 3) outlier_data[3, 8:10] <- c(10, 10, 10)

    numeric_data <- rbind(numeric_data, outlier_data)
    true_clusters <- c(true_clusters, rep(NA_integer_, n_outliers))
  }

  # Create variable names
  var_names <- paste0("q", seq_len(n_vars))
  colnames(numeric_data) <- var_names

  # Add demographics
  total_n <- nrow(numeric_data)
  gender <- sample(c("Male", "Female", "Non-binary"), total_n, replace = TRUE,
                   prob = c(0.48, 0.48, 0.04))
  age_group <- sample(c("18-24", "25-34", "35-44", "45-54", "55+"), total_n,
                      replace = TRUE, prob = c(0.15, 0.25, 0.25, 0.20, 0.15))
  region <- sample(c("North", "South", "East", "West"), total_n, replace = TRUE)

  # Create data frame
  df <- data.frame(
    respondent_id = paste0("R", sprintf("%04d", seq_len(total_n))),
    numeric_data,
    gender = gender,
    age_group = age_group,
    region = region,
    stringsAsFactors = FALSE
  )

  # Inject MCAR missingness
  n_missing <- round(total_n * n_vars * missing_rate)
  if (n_missing > 0) {
    miss_rows <- sample(seq_len(total_n), n_missing, replace = TRUE)
    miss_cols <- sample(seq_len(n_vars), n_missing, replace = TRUE)
    for (m in seq_len(n_missing)) {
      df[miss_rows[m], var_names[miss_cols[m]]] <- NA
    }
  }

  # Create question labels
  question_labels <- setNames(
    paste0("Satisfaction with ", c("Product Quality", "Customer Service",
      "Value for Money", "Brand Trust", "Ease of Use", "Innovation",
      "Reliability", "Speed of Delivery", "After-sales Support",
      "Overall Experience")),
    var_names
  )

  list(
    data = df,
    true_clusters = true_clusters,
    clustering_vars = var_names,
    id_variable = "respondent_id",
    profile_vars = c("gender", "age_group", "region"),
    question_labels = question_labels,
    centers = centers,
    n = total_n,
    k_true = k_true,
    n_vars = n_vars,
    n_outliers = n_outliers,
    seed = seed
  )
}


#' Generate Minimal Test Config List
#'
#' Creates a config list suitable for testing without needing an Excel file.
#'
#' @param test_data Output from generate_segment_test_data()
#' @param mode "exploration" or "final"
#' @param method "kmeans", "hclust", or "gmm"
#' @param k_fixed Fixed k (for final mode)
#' @return Config list
#' @export
generate_test_config <- function(test_data, mode = "final", method = "kmeans",
                                  k_fixed = 3) {

  list(
    project_name = "Test Segmentation",
    analyst_name = "Test Runner",
    data_file = "test_data.csv",
    id_variable = test_data$id_variable,
    clustering_vars = test_data$clustering_vars,
    profile_vars = test_data$profile_vars,
    question_labels = test_data$question_labels,
    method = method,
    mode = mode,
    k_fixed = if (mode == "final") k_fixed else NULL,
    k_min = 2,
    k_max = 6,
    nstart = 10,
    linkage_method = "ward.D2",
    gmm_model_type = "VVV",
    min_segment_size_pct = 5,
    missing_threshold = 0.3,
    scale_method = "zscore",
    segment_names = "auto",
    auto_name_style = "simple",
    output_folder = tempdir(),
    output_prefix = "test_",
    create_dated_folder = FALSE,
    save_model = FALSE,
    html_report = FALSE,
    generate_rules = FALSE,
    generate_action_cards = FALSE,
    run_stability_check = FALSE,
    variable_selection = FALSE,
    outlier_detection = FALSE,
    outlier_method = "mahalanobis",
    outlier_handling = "flag",
    rules_max_depth = 3,
    scale_max = 10,
    seed = 42,
    brand_colour = "#323367",
    accent_colour = "#CC9900",
    report_title = "Test Segmentation Report",
    stability_n_runs = 10
  )
}
