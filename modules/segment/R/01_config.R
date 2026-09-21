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

  # Resolve relative data_file paths against the config file's directory
  if (!is.null(config$data_file) && nzchar(config$data_file) &&
      !file.exists(config$data_file)) {
    config_dir <- dirname(normalizePath(config_file, winslash = "/", mustWork = FALSE))
    candidate <- file.path(config_dir, config$data_file)
    if (file.exists(candidate)) {
      config$data_file <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
    }
  }

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

  # Load optional Labels sheet (variable -> human-readable label).
  # Documented behaviour: this in-workbook sheet takes precedence over the
  # question_labels_file setting when both are present.
  config$.labels <- tryCatch({
    lbl <- openxlsx::read.xlsx(config_file, sheet = "Labels")
    if (!is.null(lbl) && nrow(lbl) > 0 && ncol(lbl) >= 2) {
      lbl <- lbl[, 1:2]
      names(lbl) <- c("variable", "label")
      lbl <- lbl[!is.na(lbl$variable) & !is.na(lbl$label), ]
      if (nrow(lbl) > 0) {
        vec <- as.character(lbl$label)
        names(vec) <- as.character(lbl$variable)
        cat(sprintf("  Loaded %d question labels from Labels sheet\n", length(vec)))
        vec
      } else {
        NULL
      }
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
      # Was CFG_INSUFFICIENT_VARS. The hard guard refuses the same
      # condition as CFG_INSUFFICIENT_VARIABLES, and two codes for one
      # condition split the trail a user follows (L2).
      code = "CFG_INSUFFICIENT_VARIABLES",
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
  k_selection_metrics_str <- get_char_config(
    config, "k_selection_metrics",
    default_value = "silhouette,elbow,calinski_harabasz,davies_bouldin")
  k_selection_metrics <- tolower(trimws(unlist(strsplit(k_selection_metrics_str, ","))))
  k_selection_metrics <- k_selection_metrics[nzchar(k_selection_metrics)]

  # Only names the module computes. The template used to offer gap_statistic
  # here while nothing read the setting at all, so any spelling passed
  # (independent review 2026-09-21, F4). Silhouette and elbow are always
  # computed because the recommendation is made on silhouette; the two
  # separation indices are added to the k-selection table when named.
  known_metrics <- c("silhouette", "elbow", "calinski_harabasz", "davies_bouldin")
  unknown_metrics <- setdiff(k_selection_metrics, known_metrics)
  if (length(unknown_metrics) > 0) {
    segment_refuse(
      code = "CFG_INVALID_K_SELECTION_METRIC",
      title = "Unknown k-selection metric",
      problem = sprintf("k_selection_metrics names %s, which the module does not compute.",
                        paste(unknown_metrics, collapse = ", ")),
      why_it_matters = paste(
        "A metric named here appears in the k-selection report. Naming one that",
        "nothing computes would leave a column the reader assumes was weighed."
      ),
      how_to_fix = c(
        "Use any of: silhouette, elbow, calinski_harabasz, davies_bouldin.",
        "The gap statistic is not offered here: it is expensive and stays behind calculate_gap in code."
      ),
      expected = known_metrics,
      observed = unknown_metrics
    )
  }

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

  # Both of these were parsed nowhere and therefore dropped by the assembly
  # below, so the template's Y/N and the GUI checkbox controlled nothing and
  # the Declaration sheet never received the name the user typed (H3).
  generate_stats_pack <- toupper(as.character(
    get_config_value(config, "generate_stats_pack", default_value = "Y") %||% "Y"))
  if (!generate_stats_pack %in% c("Y", "N")) {
    segment_refuse(
      code = "CFG_INVALID_STATS_PACK",
      title = "Invalid generate_stats_pack Value",
      problem = sprintf("generate_stats_pack is '%s'.", generate_stats_pack),
      why_it_matters = "The stats pack is a contractual deliverable, so this setting is not guessed at.",
      how_to_fix = "Set generate_stats_pack to Y or N.",
      expected = c("Y", "N"),
      observed = generate_stats_pack
    )
  }
  research_house <- as.character(
    get_config_value(config, "research_house", default_value = "") %||% "")

  # Who the report is for. The report layer already had a "Prepared for X"
  # branch in both the header and the footer, reading config$client_name,
  # which nothing set: unreachable code rather than a working control.
  client_name <- as.character(
    get_config_value(config, "client_name", default_value = "") %||% "")

  # The tabs banner bridge. Off by default: a project with no crosstabs run
  # does not want two more files beside its workbook.
  tabs_export <- toupper(as.character(
    get_config_value(config, "tabs_export", default_value = "N") %||% "N"))
  if (!tabs_export %in% c("Y", "N")) {
    segment_refuse(
      code = "CFG_INVALID_TABS_EXPORT",
      title = "Invalid tabs_export Value",
      problem = sprintf("tabs_export is '%s'.", tabs_export),
      why_it_matters = "Whether the segment column is written back into the survey file is not something to guess at.",
      how_to_fix = "Set tabs_export to Y or N.",
      expected = c("Y", "N"),
      observed = tabs_export
    )
  }
  allow_partial_join <- isTRUE(get_logical_config(config, "allow_partial_join",
                                                  default_value = FALSE))

  # Metadata
  project_name <- get_char_config(config, "project_name", default_value = "Segmentation Analysis")
  analyst_name <- get_char_config(config, "analyst_name", default_value = "Analyst")
  description <- as.character(get_config_value(config, "description", default_value = "") %||% "")

  # Question labels.
  # Precedence: in-workbook Labels sheet (config$.labels) > question_labels_file.
  question_labels_file <- get_config_value(config, "question_labels_file", default_value = NULL)
  question_labels <- NULL
  if (!is.null(config$.labels) && length(config$.labels) > 0) {
    question_labels <- config$.labels
  } else if (!is.null(question_labels_file) && nzchar(trimws(as.character(question_labels_file)))) {
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
    scale_max = scale_max,
    generate_stats_pack = generate_stats_pack,
    research_house = if (nzchar(trimws(research_house))) research_house else NULL,
    client_name = if (nzchar(trimws(client_name))) client_name else NULL,
    tabs_export = tabs_export,
    allow_partial_join = allow_partial_join,
    project_name = project_name, analyst_name = analyst_name, description = description,
    question_labels_file = question_labels_file, question_labels = question_labels,
    segment_names_file = segment_names_file
  )
}

#' Should This Run Write a Stats Pack?
#'
#' One answer for two controls. The config's Y/N is the study's setting; the
#' GUI checkbox writes `turas.generate_stats_pack` and is a decision someone
#' just made with a mouse, so when the option is set it wins.
#'
#' Before September 2026 the option was read with a FALSE default and OR'd
#' against the config, which made it force-on only: an unticked box could
#' never switch the pack off, and neither could the config, because
#' validation dropped the setting before anything read it (H3).
#'
#' @param config The validated configuration
#' @return TRUE if the stats pack should be written
#' @keywords internal
segment_should_write_stats_pack <- function(config) {
  gui_choice <- getOption("turas.generate_stats_pack", NULL)
  if (!is.null(gui_choice)) return(isTRUE(gui_choice))
  isTRUE(toupper(as.character(config$generate_stats_pack %||% "Y")) == "Y")
}


#' Refuse Settings for Removed Features
#'
#' LCA and ensemble clustering were removed by the V2 lift (review
#' 2026-07-11, C2 and M1). Both were config-exposed and documented but
#' unreachable from any production path: a user who followed the README and
#' set `use_lca = TRUE` got ordinary k-means, with no warning, no refusal and
#' no note. Deleting the implementations without this check would leave
#' exactly that bug in place, so a config still asking for either is refused
#' here, before anything else in validation runs.
#'
#' `use_lca = FALSE` is NOT refused. An old template carrying the default
#' must stay runnable.
#'
#' @param config Raw configuration list
#' @return invisible(TRUE), or a refusal
#' @keywords internal
refuse_removed_settings <- function(config) {

  lca_tuning <- grep("^lca_", tolower(names(config) %||% character(0)), value = TRUE)
  wants_lca <- isTRUE(get_logical_config(config, "use_lca", default_value = FALSE)) ||
    length(lca_tuning) > 0

  if (wants_lca) {
    cat("\n[SEGMENT] Config asks for latent class analysis, which has been removed.\n")
    segment_refuse(
      code = "CFG_LCA_REMOVED",
      title = "Latent Class Analysis Has Been Removed",
      problem = paste0(
        "This config asks for latent class analysis (",
        paste(c(if (isTRUE(get_logical_config(config, "use_lca", default_value = FALSE))) "use_lca",
                lca_tuning), collapse = ", "),
        "). LCA was removed from the segment module in September 2026."
      ),
      why_it_matters = paste(
        "The setting never did anything. It was accepted by the config parser and",
        "read by nothing else, so every run that asked for LCA silently produced",
        "ordinary k-means under a report that named k-means. Refusing is how you",
        "find that out instead of inheriting someone else's silent substitution."
      ),
      how_to_fix = c(
        "Delete the use_lca and lca_* rows from the Config sheet.",
        "Choose one of the methods that is really implemented: kmeans, hclust, gmm.",
        "If you need LCA as a real feature, it has to be commissioned and validated against poLCA."
      ),
      expected = "no use_lca or lca_* setting",
      observed = paste(c(if (isTRUE(get_logical_config(config, "use_lca", default_value = FALSE))) "use_lca", lca_tuning), collapse = ", ")
    )
  }

  method_raw <- tolower(as.character(get_config_value(config, "method", default_value = "") %||% ""))
  methods <- trimws(unlist(strsplit(method_raw, ",")))
  if ("ensemble" %in% methods) {
    cat("\n[SEGMENT] Config asks for the ensemble method, which has been removed.\n")
    segment_refuse(
      code = "CFG_ENSEMBLE_REMOVED",
      title = "Ensemble Clustering Has Been Removed",
      problem = "This config sets method = ensemble. Ensemble clustering was removed from the segment module in September 2026.",
      why_it_matters = paste(
        "Three layers disagreed about whether it existed: the parser refused it,",
        "the hard guard allowed it and advertised it, and the dispatcher had no arm",
        "for it. The implementation had no production caller at all."
      ),
      how_to_fix = c(
        "Set method to one or more of: kmeans, hclust, gmm.",
        "To compare methods, list several: method = kmeans,hclust,gmm."
      ),
      expected = c("kmeans", "hclust", "gmm"),
      observed = method_raw
    )
  }

  invisible(TRUE)
}


#' Warn About Config Settings That Did Not Survive Validation
#'
#' `validate_segment_config` rebuilds its result from explicit lists, so any
#' key it does not enumerate disappears. That is how two documented controls
#' came to be dead (`generate_stats_pack`, `research_house`), and it would
#' have happened to the next one added to the template and not to the
#' enumeration. Review H3.
#'
#' This does not refuse. A stray key is usually a typo or an old template,
#' neither of which should stop a run, and the point is that the user finds
#' out rather than that the run dies. It prints to the console because that
#' is where a Shiny user reads anything (project CLAUDE.md).
#'
#' @param raw_config The configuration as read from the workbook
#' @param validated_config The assembled, validated configuration
#' @return invisible character vector of the settings that did not survive
#' @keywords internal
segment_warn_unused_settings <- function(raw_config, validated_config) {

  raw_keys <- names(raw_config) %||% character(0)
  raw_keys <- raw_keys[nzchar(raw_keys) & !grepl("^[.]", raw_keys)]

  # Read by the validators under another name, or consumed as a side effect.
  consumed_elsewhere <- c(
    "k_range",               # split into k_min / k_max
    "question_labels_file",  # loaded into question_labels
    "segment_names"          # handled with the naming style
  )

  unused <- setdiff(raw_keys, c(names(validated_config), consumed_elsewhere))
  if (length(unused) == 0) return(invisible(character(0)))

  cat("\n")
  cat("+--- SEGMENT: settings that did not survive validation ---+\n")
  for (k in unused) {
    cat(sprintf("| %-55s |\n", k))
  }
  cat("| These were read from the Config sheet and are not used by  |\n")
  cat("| the run. Check the spelling against the template, or       |\n")
  cat("| delete them. Nothing below reads them.                     |\n")
  cat("|                                                            |\n")
  cat("| If a setting here IS documented, the module in memory is    |\n")
  cat("| older than the one on disk: quit R and launch again.        |\n")
  cat("+------------------------------------------------------------+\n\n")

  if (exists("showNotification", mode = "function")) {
    try(showNotification(
      paste("Segment: unused config settings:", paste(unused, collapse = ", ")),
      type = "warning", duration = NULL
    ), silent = TRUE)
  }

  invisible(unused)
}


validate_segment_config <- function(config) {
  cat("Validating configuration...\n")

  # Step 0: refuse settings for features that no longer exist, before any
  # other complaint. A removed knob must be named, never quietly ignored.
  refuse_removed_settings(config)

  # Step 1: Required params + clustering method
  req <- validate_segment_required_and_method(config)

  # Step 2: Analysis params (K, data handling, outliers, output)
  analysis <- validate_segment_analysis_params(config, req$clustering_vars)

  # Step 3: HTML report + enhanced features
  features <- parse_segment_feature_params(config, req$clustering_vars)

  # Step 3a: the tabs export belongs to the single-method final run. The
  # multi-method output block has no reader for tabs_export, so a combined run
  # with the setting on wrote no files and said nothing (independent review
  # 2026-09-21, F14). Refuse it here, before a run starts, rather than at the
  # end of one.
  if (isTRUE(req$is_multi_method) &&
      identical(toupper(as.character(features$tabs_export %||% "N")), "Y")) {
    cat("\n[SEGMENT] Config asks for the tabs export while comparing methods, where nothing writes it.\n")
    segment_refuse(
      code = "CFG_TABS_EXPORT_COMBINED",
      title = "The Tabs Export Is Not Written in Combined Mode",
      problem = sprintf(
        "This config compares %d methods (method = %s) and sets tabs_export = Y.",
        length(req$methods), paste(req$methods, collapse = ", ")),
      why_it_matters = paste(
        "Combined mode compares methods and does not choose between them, so",
        "there is no single segment column to write back onto the survey file.",
        "The export belongs to the single-method run you make after choosing",
        "one. Until now the setting was read on the single-method path only and",
        "ignored in silence here, which looked like an export that had happened."
      ),
      how_to_fix = c(
        "Set tabs_export to N for this comparison run.",
        "Then set method to the one method you chose, keep tabs_export = Y, and run again."
      ),
      expected = "tabs_export = N while method names more than one method",
      observed = sprintf("method = %s, tabs_export = Y", paste(req$methods, collapse = ", "))
    )
  }

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

  # Last, so the list it checks is the one the run will actually use.
  segment_warn_unused_settings(config, validated_config)

  validated_config
}
