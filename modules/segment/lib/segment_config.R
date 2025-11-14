# ==============================================================================
# SEGMENTATION CONFIGURATION
# ==============================================================================
# Load and validate segmentation configuration from Excel
# Part of Turas Segmentation Module
# ==============================================================================

# Source shared utilities
source("modules/shared/lib/validation_utils.R")
source("modules/shared/lib/config_utils.R")
source("modules/shared/lib/data_utils.R")

#' Read segmentation configuration from Excel file
#'
#' DESIGN: Two-column format (parameter | value) in "Config" sheet
#' VALIDATION: Comprehensive checks with actionable error messages
#'
#' @param config_file Character, path to Excel config file
#' @return Named list of configuration parameters
#' @export
read_segment_config <- function(config_file) {
  # Validate file exists
  validate_file_path(config_file, "config_file", must_exist = TRUE,
                    required_extensions = c("xlsx", "xls"))

  cat("Loading segmentation configuration from:", basename(config_file), "\n")

  # Load config sheet
  config <- load_config_sheet(config_file, sheet_name = "Config")

  if (length(config) == 0) {
    stop("Configuration file is empty or has no valid settings", call. = FALSE)
  }

  cat(sprintf("✓ Loaded %d configuration parameters\n", length(config)))

  return(config)
}

#' Validate segmentation configuration
#'
#' DESIGN: Checks all required parameters and validates ranges/types
#' RETURNS: Validated config with defaults applied
#'
#' @param config Named list from read_segment_config()
#' @return Validated and enriched configuration list
#' @export
validate_segment_config <- function(config) {
  cat("Validating configuration...\n")

  # ===========================================================================
  # REQUIRED PARAMETERS
  # ===========================================================================

  # Data source
  data_file <- get_char_config(config, "data_file", required = TRUE)
  id_variable <- get_char_config(config, "id_variable", required = TRUE)

  # Segmentation variables
  clustering_vars_str <- get_char_config(config, "clustering_vars", required = TRUE)
  clustering_vars <- trimws(unlist(strsplit(clustering_vars_str, ",")))

  if (length(clustering_vars) < 2) {
    stop("Must specify at least 2 clustering variables. Got: ", length(clustering_vars),
         call. = FALSE)
  }

  if (length(clustering_vars) > 20) {
    warning("Using ", length(clustering_vars),
            " clustering variables. Consider reducing for interpretability.",
            call. = FALSE)
  }

  # ===========================================================================
  # OPTIONAL PARAMETERS WITH DEFAULTS
  # ===========================================================================

  # Data source
  data_sheet <- get_char_config(config, "data_sheet", default_value = "Data")

  # Profiling variables
  profile_vars_str <- get_config_value(config, "profile_vars", default_value = NULL)
  profile_vars <- if (!is.null(profile_vars_str) && nzchar(trimws(profile_vars_str))) {
    trimws(unlist(strsplit(profile_vars_str, ",")))
  } else {
    NULL  # Will use all non-clustering variables
  }

  # Model configuration
  method <- get_char_config(config, "method", default_value = "kmeans",
                           allowed_values = "kmeans")

  k_fixed_val <- get_config_value(config, "k_fixed", default_value = NULL)
  k_fixed <- if (!is.null(k_fixed_val) && !is.na(k_fixed_val) && nzchar(trimws(as.character(k_fixed_val)))) {
    as.integer(k_fixed_val)
  } else {
    NULL  # Exploration mode
  }

  k_min <- get_numeric_config(config, "k_min", default_value = 3, min = 2, max = 10)
  k_max <- get_numeric_config(config, "k_max", default_value = 6, min = 2, max = 15)
  nstart <- get_numeric_config(config, "nstart", default_value = 25, min = 1, max = 100)
  seed <- get_numeric_config(config, "seed", default_value = 123, min = 1)

  # Validate k relationships
  if (k_min >= k_max) {
    stop(sprintf("k_min (%d) must be less than k_max (%d)", k_min, k_max),
         call. = FALSE)
  }

  if (!is.null(k_fixed)) {
    if (k_fixed < 2) {
      stop("k_fixed must be at least 2, got: ", k_fixed, call. = FALSE)
    }
    if (k_fixed > 10) {
      warning("k_fixed = ", k_fixed,
              " is quite large. Consider fewer segments for interpretability.",
              call. = FALSE)
    }
  }

  # Data handling
  missing_data <- get_char_config(config, "missing_data",
                                  default_value = "listwise_deletion",
                                  allowed_values = c("listwise_deletion",
                                                    "mean_imputation",
                                                    "median_imputation",
                                                    "refuse"))

  missing_threshold <- get_numeric_config(config, "missing_threshold",
                                          default_value = 15, min = 0, max = 100)

  standardize <- get_logical_config(config, "standardize", default_value = TRUE)

  min_segment_size_pct <- get_numeric_config(config, "min_segment_size_pct",
                                              default_value = 10, min = 0, max = 50)

  # Outlier detection
  outlier_detection <- get_logical_config(config, "outlier_detection",
                                          default_value = FALSE)

  outlier_method <- get_char_config(config, "outlier_method",
                                    default_value = "zscore",
                                    allowed_values = c("zscore", "mahalanobis"))

  outlier_threshold <- get_numeric_config(config, "outlier_threshold",
                                          default_value = 3.0, min = 1.0, max = 5.0)

  outlier_min_vars <- get_numeric_config(config, "outlier_min_vars",
                                         default_value = 1, min = 1)

  outlier_handling <- get_char_config(config, "outlier_handling",
                                      default_value = "flag",
                                      allowed_values = c("none", "flag", "remove"))

  outlier_alpha <- get_numeric_config(config, "outlier_alpha",
                                      default_value = 0.001, min = 0.0001, max = 0.1)

  # Validate outlier parameters
  if (outlier_detection && outlier_min_vars > length(clustering_vars)) {
    stop(sprintf(
      "outlier_min_vars (%d) cannot exceed number of clustering variables (%d)",
      outlier_min_vars, length(clustering_vars)
    ), call. = FALSE)
  }

  # Validation metrics
  k_selection_metrics_str <- get_char_config(config, "k_selection_metrics",
                                              default_value = "silhouette,elbow")
  k_selection_metrics <- trimws(unlist(strsplit(k_selection_metrics_str, ",")))

  allowed_metrics <- c("silhouette", "elbow", "gap")
  invalid_metrics <- setdiff(k_selection_metrics, allowed_metrics)
  if (length(invalid_metrics) > 0) {
    stop(sprintf("Invalid k_selection_metrics: %s\nAllowed: %s",
                paste(invalid_metrics, collapse = ", "),
                paste(allowed_metrics, collapse = ", ")),
         call. = FALSE)
  }

  # Output settings
  output_folder <- get_char_config(config, "output_folder", default_value = "output/")
  output_prefix <- get_char_config(config, "output_prefix", default_value = "seg_")
  create_dated_folder <- get_logical_config(config, "create_dated_folder",
                                             default_value = TRUE)

  segment_names_str <- get_char_config(config, "segment_names", default_value = "auto")
  segment_names <- if (segment_names_str != "auto") {
    trimws(unlist(strsplit(segment_names_str, ",")))
  } else {
    "auto"
  }

  # If segment names provided and k_fixed set, validate count
  if (!identical(segment_names, "auto") && !is.null(k_fixed)) {
    if (length(segment_names) != k_fixed) {
      stop(sprintf(
        "Number of segment_names (%d) must match k_fixed (%d)\nGot: %s",
        length(segment_names), k_fixed,
        paste(segment_names, collapse = ", ")
      ), call. = FALSE)
    }
  }

  save_model <- get_logical_config(config, "save_model", default_value = TRUE)

  # Metadata (optional)
  project_name <- get_char_config(config, "project_name",
                                  default_value = "Segmentation Analysis")
  analyst_name <- get_char_config(config, "analyst_name",
                                  default_value = "Analyst")
  description <- get_char_config(config, "description",
                                 default_value = "")

  # ===========================================================================
  # CONSTRUCT VALIDATED CONFIG
  # ===========================================================================

  validated_config <- list(
    # Data source
    data_file = data_file,
    data_sheet = data_sheet,
    id_variable = id_variable,

    # Variables
    clustering_vars = clustering_vars,
    profile_vars = profile_vars,

    # Model
    method = method,
    k_fixed = k_fixed,
    k_min = k_min,
    k_max = k_max,
    nstart = nstart,
    seed = seed,

    # Data handling
    missing_data = missing_data,
    missing_threshold = missing_threshold,
    standardize = standardize,
    min_segment_size_pct = min_segment_size_pct,

    # Outlier detection
    outlier_detection = outlier_detection,
    outlier_method = outlier_method,
    outlier_threshold = outlier_threshold,
    outlier_min_vars = outlier_min_vars,
    outlier_handling = outlier_handling,
    outlier_alpha = outlier_alpha,

    # Validation
    k_selection_metrics = k_selection_metrics,

    # Output
    output_folder = output_folder,
    output_prefix = output_prefix,
    create_dated_folder = create_dated_folder,
    segment_names = segment_names,
    save_model = save_model,

    # Metadata
    project_name = project_name,
    analyst_name = analyst_name,
    description = description,

    # Mode detection
    mode = if (is.null(k_fixed)) "exploration" else "final"
  )

  # Success message
  cat(sprintf("✓ Configuration validated\n"))
  cat(sprintf("  Mode: %s\n", validated_config$mode))
  cat(sprintf("  Clustering variables: %d\n", length(clustering_vars)))
  cat(sprintf("  Method: %s\n", method))

  if (validated_config$mode == "exploration") {
    cat(sprintf("  K range: %d to %d\n", k_min, k_max))
  } else {
    cat(sprintf("  Fixed K: %d\n", k_fixed))
  }

  if (outlier_detection) {
    cat(sprintf("  Outlier detection: enabled (%s method)\n", outlier_method))
  } else {
    cat(sprintf("  Outlier detection: disabled\n"))
  }

  return(validated_config)
}
