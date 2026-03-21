# ==============================================================================
# SEGMENT MODULE - CONFIGURATION
# ==============================================================================
# Load and validate segmentation configuration from Excel.
# Uses shared config_utils.R for loading, adds segment-specific validation.
#
# Config sheet format: Two-column (parameter | value) in "Config" sheet.
#
# New v11.0 parameters:
#   - method (kmeans | hclust | gmm)
#   - linkage_method (for hclust)
#   - gmm_model_type (for GMM)
#   - html_report (TRUE/FALSE)
#   - brand_colour, accent_colour, report_title
#   - html_show_* section visibility flags
# ==============================================================================


#' Format Variable Name with Label
#'
#' Returns "variable: label" if label exists, otherwise just "variable".
#'
#' @param variable Character, variable name(s)
#' @param question_labels Named vector of labels
#' @return Character vector of formatted variable names
#' @export
format_variable_label <- function(variable, question_labels = NULL) {
  if (is.null(question_labels) || length(question_labels) == 0) {
    return(variable)
  }

  sapply(variable, function(v) {
    if (v %in% names(question_labels)) {
      paste0(v, ": ", question_labels[v])
    } else {
      v
    }
  }, USE.NAMES = FALSE)
}


#' Load Question Labels from Excel File
#'
#' Two-column format (variable | label). Optional - continues without labels if file not found.
#'
#' @param labels_file Character, path to Excel labels file
#' @return Named vector of labels or NULL
#' @export
load_question_labels <- function(labels_file) {
  if (!file.exists(labels_file)) {
    message(sprintf("[TRS INFO] Question labels file not found: %s - continuing without labels",
                   labels_file))
    return(NULL)
  }

  if (!grepl("\\.(xlsx|xls)$", labels_file, ignore.case = TRUE)) {
    message("[TRS INFO] Question labels file must be Excel format - continuing without labels")
    return(NULL)
  }

  tryCatch({
    cat(sprintf("Loading question labels from: %s\n", basename(labels_file)))
    sheet_names <- c("Labels", "Questions", "Sheet1", "Data")
    labels_df <- NULL

    for (sheet in sheet_names) {
      labels_df <- tryCatch(readxl::read_excel(labels_file, sheet = sheet),
                            error = function(e) NULL)
      if (!is.null(labels_df)) break
    }

    if (is.null(labels_df) || ncol(labels_df) < 2) {
      message("[TRS INFO] Could not read question labels - continuing without labels")
      return(NULL)
    }

    labels_df <- labels_df[, 1:2]
    names(labels_df) <- c("variable", "label")
    labels_df <- labels_df[!is.na(labels_df$variable) & !is.na(labels_df$label), ]

    if (nrow(labels_df) == 0) return(NULL)

    labels_vec <- as.character(labels_df$label)
    names(labels_vec) <- as.character(labels_df$variable)
    cat(sprintf("  Loaded %d question labels\n", length(labels_vec)))
    labels_vec

  }, error = function(e) {
    message(sprintf("[TRS INFO] Error loading question labels: %s", e$message))
    NULL
  })
}


#' Read Segmentation Configuration from Excel
#'
#' @param config_file Path to Excel config file
#' @return Named list of raw configuration parameters
#' @export
read_segment_config <- function(config_file) {
  validate_file_path(config_file, "config_file", must_exist = TRUE,
                    required_extensions = c("xlsx", "xls"))

  cat("Loading segmentation configuration from:", basename(config_file), "\n")

  config <- load_config_sheet(config_file, sheet_name = "Config")

  if (length(config) == 0) {
    segment_refuse(
      code = "CFG_EMPTY_CONFIG",
      title = "Empty Configuration File",
      problem = "Configuration file is empty or has no valid settings.",
      why_it_matters = "Segmentation requires configuration to run.",
      how_to_fix = "Add settings to the Config sheet in your configuration file."
    )
  }

  cat(sprintf("  Loaded %d configuration parameters\n", length(config)))

  # Load optional Insights sheet (section_key -> insight_text)
  config$.insights <- tryCatch({
    ins <- openxlsx::read.xlsx(config_file, sheet = "Insights")
    if (!is.null(ins) && nrow(ins) > 0 && all(c("Section", "Insight") %in% names(ins))) {
      ins_list <- setNames(as.character(ins$Insight), tolower(trimws(ins$Section)))
      ins_list <- ins_list[nzchar(ins_list)]
      if (length(ins_list) > 0) {
        cat(sprintf("  Loaded %d pre-configured insights\n", length(ins_list)))
      }
      ins_list
    } else {
      NULL
    }
  }, error = function(e) NULL)

  # Load optional About sheet (analyst details)
  config$.about <- tryCatch({
    abt <- openxlsx::read.xlsx(config_file, sheet = "About")
    if (!is.null(abt) && nrow(abt) > 0 && all(c("Setting", "Value") %in% names(abt))) {
      about_list <- setNames(as.character(abt$Value), tolower(trimws(abt$Setting)))
      about_list <- about_list[nzchar(about_list)]
      if (length(about_list) > 0) {
        cat(sprintf("  Loaded %d about/analyst details\n", length(about_list)))
      }
      about_list
    } else {
      NULL
    }
  }, error = function(e) NULL)

  # Load optional Slides sheet (title, content, image_path)
  config$.slides <- tryCatch({
    sl <- openxlsx::read.xlsx(config_file, sheet = "Slides")
    if (!is.null(sl) && nrow(sl) > 0 && "Title" %in% names(sl)) {
      slides <- lapply(seq_len(nrow(sl)), function(i) {
        list(
          title = as.character(sl$Title[i] %||% ""),
          content = as.character(sl$Content[i] %||% ""),
          image_path = as.character(sl$Image[i] %||% "")
        )
      })
      cat(sprintf("  Loaded %d pre-configured slides\n", length(slides)))
      slides
    } else {
      NULL
    }
  }, error = function(e) NULL)

  config
}


#' Validate Segmentation Configuration
#'
#' Validates all parameters and applies defaults. Returns enriched config.
#'
#' @param config Named list from read_segment_config()
#' @return Validated configuration list with defaults applied
#' @export
# ---------------------------------------------------------------------------
# Helper: Parse comma-or-semicolon-separated string into character vector
# ---------------------------------------------------------------------------
parse_delimited_vars <- function(str_val) {
  if (is.null(str_val) || !nzchar(trimws(as.character(str_val)))) return(NULL)
  vars <- trimws(unlist(strsplit(str_val, ",")))
  if (length(vars) == 1) vars <- trimws(unlist(strsplit(str_val, ";")))
  vars
}

# ---------------------------------------------------------------------------
# Helper: Validate required params and clustering method
# ---------------------------------------------------------------------------
validate_segment_required_and_method <- function(config) {
  data_file <- get_char_config(config, "data_file", required = TRUE)
  id_variable <- get_char_config(config, "id_variable", required = TRUE)

  clustering_vars <- parse_delimited_vars(
    get_char_config(config, "clustering_vars", required = TRUE)
  )

  if (length(clustering_vars) < 2) {
    segment_refuse(
      code = "CFG_INSUFFICIENT_VARS",
      title = "Insufficient Clustering Variables",
      problem = sprintf("Only %d clustering variable(s) specified.", length(clustering_vars)),
      why_it_matters = "Segmentation requires at least 2 variables to find meaningful clusters.",
      how_to_fix = "Add more variables to the clustering_vars setting."
    )
  }

  # Clustering method
  method <- tolower(get_char_config(config, "method", default_value = "kmeans"))
  methods <- trimws(unlist(strsplit(method, ",")))
  if (length(methods) == 1 && methods[1] == "all") {
    methods <- c("kmeans", "hclust", "gmm")
  }

  valid_methods <- c("kmeans", "hclust", "gmm")
  invalid <- setdiff(methods, valid_methods)
  if (length(invalid) > 0) {
    segment_refuse(
      code = "CFG_INVALID_METHOD",
      title = "Invalid Clustering Method",
      problem = sprintf("Method(s) '%s' not supported.", paste(invalid, collapse = ", ")),
      why_it_matters = "Only supported methods produce valid results.",
      how_to_fix = sprintf("Set method to one or more of: %s (comma-separated)", paste(valid_methods, collapse = ", "))
    )
  }

  is_multi_method <- length(methods) > 1
  method <- methods[1]

  list(
    data_file = data_file, id_variable = id_variable,
    clustering_vars = clustering_vars,
    method = method, methods = methods, is_multi_method = is_multi_method,
    linkage_method = get_char_config(config, "linkage_method", default_value = "ward.D2"),
    gmm_model_type = get_config_value(config, "gmm_model_type", default_value = NULL)
  )
}

# ---------------------------------------------------------------------------
# Helper: Validate K parameters, data handling, outliers, variable selection
# ---------------------------------------------------------------------------
validate_segment_analysis_params <- function(config, clustering_vars) {
  data_sheet <- get_char_config(config, "data_sheet", default_value = "Data")
  profile_vars <- parse_delimited_vars(get_config_value(config, "profile_vars", default_value = NULL))

  # K parameters
  k_fixed_val <- get_config_value(config, "k_fixed", default_value = NULL)
  k_fixed <- if (!is.null(k_fixed_val) && !is.na(k_fixed_val) && nzchar(trimws(as.character(k_fixed_val)))) {
    as.integer(k_fixed_val)
  } else {
    NULL
  }

  k_min <- get_numeric_config(config, "k_min", default_value = 3, min = 2, max = 10)
  k_max <- get_numeric_config(config, "k_max", default_value = 6, min = 2, max = 15)
  nstart <- get_numeric_config(config, "nstart", default_value = 50, min = 1, max = 200)
  seed <- get_numeric_config(config, "seed", default_value = 123, min = 1)

  if (k_min >= k_max) {
    segment_refuse(
      code = "CFG_INVALID_K_RANGE",
      title = "Invalid K Range",
      problem = sprintf("k_min (%d) must be less than k_max (%d).", k_min, k_max),
      why_it_matters = "Exploration mode needs a valid range to test.",
      how_to_fix = "Set k_max greater than k_min."
    )
  }

  if (!is.null(k_fixed) && k_fixed < 2) {
    segment_refuse(
      code = "CFG_INVALID_K_FIXED",
      title = "Invalid K Fixed Value",
      problem = sprintf("k_fixed must be at least 2, got: %d", k_fixed),
      why_it_matters = "A segment solution needs at least 2 clusters.",
      how_to_fix = "Set k_fixed to 2 or greater."
    )
  }

  # Data handling
  missing_data <- get_char_config(config, "missing_data",
    default_value = "listwise_deletion",
    allowed_values = c("listwise_deletion", "mean_imputation", "median_imputation", "refuse"))
  missing_threshold <- get_numeric_config(config, "missing_threshold", default_value = 15, min = 0, max = 100)
  standardize <- get_logical_config(config, "standardize", default_value = TRUE)
  min_segment_size_pct <- get_numeric_config(config, "min_segment_size_pct", default_value = 10, min = 0, max = 50)

  # Outlier detection
  outlier_detection <- get_logical_config(config, "outlier_detection", default_value = FALSE)
  outlier_method <- get_char_config(config, "outlier_method", default_value = "zscore",
    allowed_values = c("zscore", "mahalanobis"))
  outlier_threshold <- get_numeric_config(config, "outlier_threshold", default_value = 3.0, min = 1.0, max = 5.0)
  outlier_min_vars <- get_numeric_config(config, "outlier_min_vars", default_value = 1, min = 1)
  outlier_handling <- get_char_config(config, "outlier_handling", default_value = "flag",
    allowed_values = c("none", "flag", "remove"))
  outlier_alpha <- get_numeric_config(config, "outlier_alpha", default_value = 0.001, min = 0.0001, max = 0.1)

  if (outlier_detection && outlier_min_vars > length(clustering_vars)) {
    segment_refuse(
      code = "CFG_INVALID_OUTLIER_MIN_VARS",
      title = "Invalid outlier_min_vars",
      problem = sprintf("outlier_min_vars (%d) exceeds clustering variables (%d).",
                       outlier_min_vars, length(clustering_vars)),
      why_it_matters = "Cannot require more outlier variables than exist.",
      how_to_fix = sprintf("Set outlier_min_vars between 1 and %d.", length(clustering_vars))
    )
  }

  # Variable selection
  variable_selection <- get_logical_config(config, "variable_selection", default_value = FALSE)
  variable_selection_method <- get_char_config(config, "variable_selection_method",
    default_value = "variance_correlation",
    allowed_values = c("variance_correlation", "factor_analysis", "both"))
  max_clustering_vars <- get_numeric_config(config, "max_clustering_vars", default_value = 10, min = 2, max = 20)
  varsel_min_variance <- get_numeric_config(config, "varsel_min_variance", default_value = 0.1, min = 0.01, max = 1.0)
  varsel_max_correlation <- get_numeric_config(config, "varsel_max_correlation", default_value = 0.8, min = 0.5, max = 0.95)

  # Validation metrics
  k_selection_metrics_str <- get_char_config(config, "k_selection_metrics", default_value = "silhouette,elbow")
  k_selection_metrics <- trimws(unlist(strsplit(k_selection_metrics_str, ",")))

  # Output settings
  output_folder <- get_char_config(config, "output_folder", default_value = "output/")
  output_prefix <- get_char_config(config, "output_prefix", default_value = "seg_")
  create_dated_folder <- get_logical_config(config, "create_dated_folder", default_value = TRUE)
  save_model <- get_logical_config(config, "save_model", default_value = TRUE)

  # Segment names
  segment_names_str <- get_char_config(config, "segment_names", default_value = "auto")
  segment_names <- if (segment_names_str != "auto") {
    trimws(unlist(strsplit(segment_names_str, ",")))
  } else {
    "auto"
  }

  if (!identical(segment_names, "auto") && !is.null(k_fixed)) {
    if (length(segment_names) != k_fixed) {
      segment_refuse(
        code = "CFG_SEGMENT_NAMES_MISMATCH",
        title = "Segment Names Count Mismatch",
        problem = sprintf("segment_names count (%d) doesn't match k_fixed (%d).",
                         length(segment_names), k_fixed),
        why_it_matters = "Each segment needs a unique name.",
        how_to_fix = sprintf("Provide exactly %d segment names.", k_fixed)
      )
    }
  }

  list(
    data_sheet = data_sheet, profile_vars = profile_vars,
    k_fixed = k_fixed, k_min = k_min, k_max = k_max, nstart = nstart, seed = seed,
    missing_data = missing_data, missing_threshold = missing_threshold,
    standardize = standardize, min_segment_size_pct = min_segment_size_pct,
    outlier_detection = outlier_detection, outlier_method = outlier_method,
    outlier_threshold = outlier_threshold, outlier_min_vars = outlier_min_vars,
    outlier_handling = outlier_handling, outlier_alpha = outlier_alpha,
    variable_selection = variable_selection, variable_selection_method = variable_selection_method,
    max_clustering_vars = max_clustering_vars, varsel_min_variance = varsel_min_variance,
    varsel_max_correlation = varsel_max_correlation,
    k_selection_metrics = k_selection_metrics,
    output_folder = output_folder, output_prefix = output_prefix,
    create_dated_folder = create_dated_folder, segment_names = segment_names,
    save_model = save_model
  )
}

# ---------------------------------------------------------------------------
# Helper: Parse HTML report and enhanced feature settings
# ---------------------------------------------------------------------------
parse_segment_feature_params <- function(config, clustering_vars) {
  # HTML report settings
  html_report <- get_logical_config(config, "html_report", default_value = FALSE)
  brand_colour <- get_char_config(config, "brand_colour", default_value = "#323367")
  accent_colour <- get_char_config(config, "accent_colour", default_value = "#CC9900")
  report_title <- get_char_config(config, "report_title", default_value = "Segmentation Report")

  html_show <- list(
    exec_summary = get_logical_config(config, "html_show_exec_summary", default_value = TRUE),
    overview     = get_logical_config(config, "html_show_overview", default_value = TRUE),
    validation   = get_logical_config(config, "html_show_validation", default_value = TRUE),
    importance   = get_logical_config(config, "html_show_importance", default_value = TRUE),
    profiles     = get_logical_config(config, "html_show_profiles", default_value = TRUE),
    demographics = get_logical_config(config, "html_show_demographics", default_value = TRUE),
    rules        = get_logical_config(config, "html_show_rules", default_value = TRUE),
    cards        = get_logical_config(config, "html_show_cards", default_value = TRUE),
    stability    = get_logical_config(config, "html_show_stability", default_value = TRUE),
    membership   = get_logical_config(config, "html_show_membership", default_value = TRUE),
    guide        = get_logical_config(config, "html_show_guide", default_value = TRUE)
  )

  # Enhanced features
  n_clustering_vars <- length(clustering_vars)
  golden_questions_n <- get_numeric_config(config, "golden_questions_n",
                                            default_value = max(n_clustering_vars, 5),
                                            min = 1, max = 100)
  auto_name_style <- get_char_config(config, "auto_name_style", default_value = "descriptive",
    allowed_values = c("descriptive", "persona", "simple"))
  demographic_vars <- parse_delimited_vars(get_config_value(config, "demographic_vars", default_value = NULL))

  run_stability_check <- get_logical_config(config, "run_stability_check", default_value = FALSE)
  stability_n_runs <- get_numeric_config(config, "stability_n_runs", default_value = 5, min = 3, max = 20)
  generate_rules <- get_logical_config(config, "generate_rules", default_value = FALSE)
  rules_max_depth <- get_numeric_config(config, "rules_max_depth", default_value = 3, min = 1, max = 5)
  generate_action_cards <- get_logical_config(config, "generate_action_cards", default_value = FALSE)
  scale_max <- get_numeric_config(config, "scale_max", default_value = 10, min = 1, max = 100)
  use_lca <- get_logical_config(config, "use_lca", default_value = FALSE)

  # Metadata
  project_name <- get_char_config(config, "project_name", default_value = "Segmentation Analysis")
  analyst_name <- get_char_config(config, "analyst_name", default_value = "Analyst")
  description <- as.character(get_config_value(config, "description", default_value = "") %||% "")

  # Question labels
  question_labels_file <- get_config_value(config, "question_labels_file", default_value = NULL)
  question_labels <- NULL
  if (!is.null(question_labels_file) && nzchar(trimws(as.character(question_labels_file)))) {
    question_labels <- load_question_labels(question_labels_file)
  }

  segment_names_file <- get_config_value(config, "segment_names_file", default_value = NULL)

  list(
    html_report = html_report, brand_colour = brand_colour, accent_colour = accent_colour,
    report_title = report_title,
    html_show_exec_summary = html_show$exec_summary, html_show_overview = html_show$overview,
    html_show_validation = html_show$validation, html_show_importance = html_show$importance,
    html_show_profiles = html_show$profiles, html_show_demographics = html_show$demographics,
    html_show_rules = html_show$rules, html_show_cards = html_show$cards,
    html_show_stability = html_show$stability, html_show_membership = html_show$membership,
    html_show_guide = html_show$guide,
    golden_questions_n = golden_questions_n, auto_name_style = auto_name_style,
    demographic_vars = demographic_vars, run_stability_check = run_stability_check,
    stability_n_runs = stability_n_runs, generate_rules = generate_rules,
    rules_max_depth = rules_max_depth, generate_action_cards = generate_action_cards,
    scale_max = scale_max, use_lca = use_lca,
    project_name = project_name, analyst_name = analyst_name, description = description,
    question_labels_file = question_labels_file, question_labels = question_labels,
    segment_names_file = segment_names_file
  )
}

validate_segment_config <- function(config) {
  cat("Validating configuration...\n")

  # Step 1: Required params + clustering method
  req <- validate_segment_required_and_method(config)

  # Step 2: Analysis params (K, data handling, outliers, output)
  analysis <- validate_segment_analysis_params(config, req$clustering_vars)

  # Step 3: HTML report + enhanced features
  features <- parse_segment_feature_params(config, req$clustering_vars)

  # Assemble validated config
  validated_config <- c(
    req,
    analysis,
    features,
    list(
      insights = config$.insights,
      about = config$.about,
      slides = config$.slides,
      mode = if (is.null(analysis$k_fixed)) "exploration" else "final"
    )
  )

  # Summary output
  cat(sprintf("  Configuration validated\n"))
  cat(sprintf("  Mode: %s\n", validated_config$mode))
  if (req$is_multi_method) {
    cat(sprintf("  Methods: %s (multi-method comparison)\n", paste(toupper(req$methods), collapse = ", ")))
  } else {
    cat(sprintf("  Method: %s\n", toupper(req$method)))
  }
  cat(sprintf("  Clustering variables: %d\n", length(req$clustering_vars)))

  if (validated_config$mode == "exploration") {
    cat(sprintf("  K range: %d to %d\n", analysis$k_min, analysis$k_max))
  } else {
    cat(sprintf("  Fixed K: %d\n", analysis$k_fixed))
  }

  if (req$method == "hclust") cat(sprintf("  Linkage: %s\n", req$linkage_method))
  if (req$method == "gmm" && !is.null(req$gmm_model_type)) cat(sprintf("  GMM model: %s\n", req$gmm_model_type))
  if (features$html_report) cat("  HTML report: enabled\n")

  validated_config
}
