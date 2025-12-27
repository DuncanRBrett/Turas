# ==============================================================================
# SHARED DATA LOADING FUNCTIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides data loading utilities for survey structure and response data
#
# CONTENTS:
# - Load survey structure (questions and options)
# - Load survey data (multiple formats)
# - Smart loading with CSV caching for large Excel files
#
# SUPPORTED FORMATS:
# - Excel (.xlsx, .xls)
# - CSV (.csv)
# - SPSS (.sav via haven package)
#
# PERFORMANCE NOTES:
# - Excel: ~10MB/sec
# - CSV (base R): ~50MB/sec
# - CSV (data.table): ~500MB/sec (auto-enabled if available)
# - SPSS: ~20MB/sec
# - Smart loader auto-caches large Excel files as CSV
# ==============================================================================

#' Load complete survey structure
#'
#' USAGE: Load at start of analysis to get questions and options
#' DESIGN: Returns list with project config, questions, and options
#' VALIDATION: Basic checks here, comprehensive validation in validation.R
#' ERROR HANDLING: Detailed, actionable error messages
#'
#' @param structure_file_path Character, path to Survey_Structure.xlsx
#' @param project_root Character, optional project root for resolving paths
#' @return List with $project, $questions, $options, $structure_file, $project_root
#' @export
#' @examples
#' survey_structure <- load_survey_structure("Survey_Structure.xlsx")
#' questions <- survey_structure$questions
#' options <- survey_structure$options
load_survey_structure <- function(structure_file_path, project_root = NULL) {
  # Get constants from parent environment
  SUPPORTED_CONFIG_FORMATS <- tryCatch(
    get("SUPPORTED_CONFIG_FORMATS", envir = .GlobalEnv),
    error = function(e) c("xlsx", "xls")
  )

  # Validate path
  validate_file_path(structure_file_path, "structure_file_path",
                    must_exist = TRUE,
                    required_extensions = SUPPORTED_CONFIG_FORMATS)

  # Determine project root
  if (is.null(project_root)) {
    project_root <- dirname(structure_file_path)
  }

  cat("Loading survey structure from:", basename(structure_file_path), "\n")

  # Load sheets with error handling
  tryCatch({
    # Load Project sheet
    project_config <- load_config_sheet(structure_file_path, "Project")

    # Load Questions sheet
    questions_df <- readxl::read_excel(structure_file_path, sheet = "Questions", col_types = "text")

    # Load Options sheet
    options_df <- readxl::read_excel(structure_file_path, sheet = "Options", col_types = "text")

  }, error = function(e) {
    tabs_refuse(
      code = "IO_STRUCTURE_LOAD_FAILED",
      title = "Failed to Load Survey Structure",
      problem = sprintf("Failed to load survey structure from %s. Error: %s", basename(structure_file_path), conditionMessage(e)),
      why_it_matters = "Survey structure is required to understand questions, options, and data layout.",
      how_to_fix = "Troubleshooting: 1) Verify file has sheets: Project, Questions, Options, 2) Check file is not corrupted, 3) Ensure file is not open in Excel"
    )
  })

  # Validate Questions sheet structure
  required_question_cols <- c("QuestionCode", "QuestionText", "Variable_Type", "Columns")
  missing_q <- setdiff(required_question_cols, names(questions_df))

  if (length(missing_q) > 0) {
    tabs_refuse(
      code = "DATA_INVALID_QUESTIONS_STRUCTURE",
      title = "Invalid Questions Sheet Structure",
      problem = sprintf("Questions sheet missing required columns: %s", paste(missing_q, collapse = ", ")),
      why_it_matters = "Questions sheet must have standard columns to define survey structure properly.",
      how_to_fix = sprintf("Found columns: %s. Required columns: %s. Add missing columns to your Questions sheet.",
        paste(names(questions_df), collapse = ", "),
        paste(required_question_cols, collapse = ", "))
    )
  }

  # Validate Options sheet structure
  required_option_cols <- c("QuestionCode", "OptionText", "DisplayText")
  missing_o <- setdiff(required_option_cols, names(options_df))

  if (length(missing_o) > 0) {
    tabs_refuse(
      code = "DATA_INVALID_OPTIONS_STRUCTURE",
      title = "Invalid Options Sheet Structure",
      problem = sprintf("Options sheet missing required columns: %s", paste(missing_o, collapse = ", ")),
      why_it_matters = "Options sheet must have standard columns to define answer choices properly.",
      how_to_fix = sprintf("Found columns: %s. Required columns: %s. Add missing columns to your Options sheet.",
        paste(names(options_df), collapse = ", "),
        paste(required_option_cols, collapse = ", "))
    )
  }

  # Success message
  cat(sprintf(
    "✓ Loaded: %d questions, %d options\n",
    nrow(questions_df),
    nrow(options_df)
  ))

  return(list(
    project = project_config,
    questions = questions_df,
    options = options_df,
    structure_file = structure_file_path,
    project_root = project_root
  ))
}

#' Load survey data file (V9.9.1: CSV fast-path + .sav label handling)
#'
#' SUPPORTED FORMATS: .xlsx, .xls, .csv, .sav (SPSS via haven package)
#'
#' PERFORMANCE:
#'   - Excel: ~10MB/sec on typical hardware
#'   - CSV (base R): ~50MB/sec
#'   - CSV (data.table): ~500MB/sec [V9.9.1: Auto-enabled if package available]
#'   - SPSS: ~20MB/sec
#'
#' MEMORY: Loads entire file into RAM
#'   - Files >500MB will show warning
#'   - Consider splitting very large datasets
#'
#' SPSS LABELS (V9.9.1):
#'   - convert_labelled=FALSE (default): Keeps SPSS labels (labelled class)
#'   - convert_labelled=TRUE: Converts to plain R types (numeric/character/factor)
#'   - Use TRUE if downstream code expects standard R types
#'
#' @param data_file_path Character, path to data file (relative or absolute)
#' @param project_root Character, optional project root for resolving relative paths
#' @param convert_labelled Logical, convert SPSS labelled to plain R types (default: FALSE)
#' @return Data frame with survey responses
#' @export
#' @examples
#' survey_data <- load_survey_data("Data/survey.xlsx", project_root)
#' survey_data <- load_survey_data("Data/spss_data.sav", project_root)
#'
#' # For .sav with label conversion
#' survey_data <- load_survey_data("Data/spss_data.sav", project_root,
#'                                 convert_labelled = TRUE)
load_survey_data <- function(data_file_path, project_root = NULL,
                             convert_labelled = FALSE) {
  # Get constants from parent environment
  SUPPORTED_DATA_FORMATS <- tryCatch(
    get("SUPPORTED_DATA_FORMATS", envir = .GlobalEnv),
    error = function(e) c("xlsx", "xls", "csv", "sav")
  )

  # Resolve path if relative
  if (!is.null(project_root) && !file.exists(data_file_path)) {
    data_file_path <- resolve_path(project_root, data_file_path)
  }

  # Validate file exists
  validate_file_path(data_file_path, "data_file_path", must_exist = TRUE)

  cat("Loading survey data from:", basename(data_file_path), "\n")

  # Detect file type
  file_ext <- tolower(tools::file_ext(data_file_path))

  if (!file_ext %in% SUPPORTED_DATA_FORMATS) {
    tabs_refuse(
      code = "IO_UNSUPPORTED_FORMAT",
      title = "Unsupported File Format",
      problem = sprintf("Unsupported file type: .%s", file_ext),
      why_it_matters = "Only specific file formats are supported for reliable data loading.",
      how_to_fix = sprintf("Convert your file to one of these supported formats: %s", paste0(".", SUPPORTED_DATA_FORMATS, collapse = ", "))
    )
  }

  # Load data with format-specific handling
  survey_data <- tryCatch({
    switch(file_ext,
      "xlsx" = readxl::read_excel(data_file_path),
      "xls"  = readxl::read_excel(data_file_path),
      "csv"  = {
        # V9.9.1: CSV fast-path via data.table if available
        if (is_package_available("data.table")) {
          cat("  Using data.table::fread() for faster loading...\n")
          data.table::fread(data_file_path, data.table = FALSE)
        } else {
          read.csv(data_file_path, stringsAsFactors = FALSE)
        }
      },
      "sav"  = {
        # SPSS support via haven package
        if (!is_package_available("haven")) {
          tabs_refuse(
            code = "ENV_MISSING_PACKAGE",
            title = "Missing Required Package",
            problem = ".sav files require the 'haven' package which is not installed",
            why_it_matters = "The haven package is required to read SPSS (.sav) data files.",
            how_to_fix = "Install the package with: install.packages('haven')"
          )
        }

        dat <- haven::read_sav(data_file_path)

        # V9.9.1: Optional label conversion
        if (convert_labelled) {
          cat("  Converting SPSS labels to plain R types...\n")
          # Remove label attributes but keep numeric values
          dat <- haven::zap_labels(dat)
          # Optionally convert value labels to factors:
          # dat <- haven::as_factor(dat, levels = "labels")
        }

        dat
      }
    )
  }, error = function(e) {
    tabs_refuse(
      code = "IO_DATA_LOAD_FAILED",
      title = "Failed to Load Data File",
      problem = sprintf("Failed to load data file %s. Error: %s", basename(data_file_path), conditionMessage(e)),
      why_it_matters = "Survey data must be loaded successfully to perform any analysis.",
      how_to_fix = "Troubleshooting: 1) Verify file is not corrupted, 2) Check file is not open in another program, 3) For Excel: try saving as .csv and retry, 4) Check file permissions"
    )
  })

  # Validate loaded data
  if (!is.data.frame(survey_data)) {
    tabs_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Data Type",
      problem = sprintf("Data file loaded but is not a data frame (got: %s)", paste(class(survey_data), collapse = ", ")),
      why_it_matters = "Survey data must be in data frame format for processing.",
      how_to_fix = "Ensure your data file contains tabular data (rows and columns), not other R objects."
    )
  }

  if (nrow(survey_data) == 0) {
    tabs_refuse(
      code = "DATA_EMPTY_FILE",
      title = "Empty Data File",
      problem = "Data file is empty (0 rows)",
      why_it_matters = "Cannot perform analysis on an empty dataset.",
      how_to_fix = "Ensure your data file contains at least one row of survey responses."
    )
  }

  if (ncol(survey_data) == 0) {
    tabs_refuse(
      code = "DATA_NO_COLUMNS",
      title = "No Columns in Data",
      problem = "Data file has no columns",
      why_it_matters = "Survey data must have columns representing questions and responses.",
      how_to_fix = "Ensure your data file has proper column headers and data columns."
    )
  }

  # Success message
  cat(sprintf(
    "✓ Loaded: %s rows, %s columns\n",
    format(nrow(survey_data), big.mark = ","),
    format(ncol(survey_data), big.mark = ",")
  ))

  return(survey_data)
}

#' Load Survey Data with Smart Caching (V10.0)
#'
#' For large Excel files (>50MB), automatically creates a CSV cache
#' for dramatically faster subsequent loads. Excel loads at ~10MB/sec
#' while CSV via data.table loads at ~500MB/sec (50x faster).
#'
#' USAGE: Drop-in replacement for load_survey_data() when working with
#' large Excel files that are read multiple times.
#'
#' CACHING BEHAVIOR:
#' - Cache file stored alongside source as {filename}_cache.csv
#' - Cache auto-regenerates when source file is modified
#' - Cache only created if file size exceeds threshold
#' - Falls back to standard load_survey_data() if caching not beneficial
#'
#' @param data_file_path Character, path to data file
#' @param project_root Character, optional project root
#' @param auto_cache Logical, enable CSV caching for large files (default: TRUE)
#' @param cache_threshold_mb Numeric, file size threshold in MB for caching (default: 50)
#' @param convert_labelled Logical, convert SPSS labels (default: FALSE)
#' @return Data frame with survey responses
#' @export
#' @examples
#' # Standard usage - will cache large Excel files automatically
#' survey_data <- load_survey_data_smart("Data/large_survey.xlsx", project_root)
#'
#' # Disable caching
#' survey_data <- load_survey_data_smart("Data/survey.xlsx", auto_cache = FALSE)
#'
#' # Lower threshold (cache files >10MB)
#' survey_data <- load_survey_data_smart("Data/survey.xlsx", cache_threshold_mb = 10)
load_survey_data_smart <- function(data_file_path, project_root = NULL,
                                   auto_cache = TRUE,
                                   cache_threshold_mb = 50,
                                   convert_labelled = FALSE) {

  # Resolve path if relative
  if (!is.null(project_root) && !file.exists(data_file_path)) {
    data_file_path <- resolve_path(project_root, data_file_path)
  }

  file_ext <- tolower(tools::file_ext(data_file_path))

  # Smart caching for large Excel files
  if (auto_cache && file_ext %in% c("xlsx", "xls")) {
    file_size_mb <- file.info(data_file_path)$size / 1024^2

    if (file_size_mb > cache_threshold_mb && is_package_available("data.table")) {
      csv_cache_path <- sub("\\.(xlsx|xls)$", "_cache.csv", data_file_path)

      # Check if cache exists and is newer than source
      cache_valid <- file.exists(csv_cache_path) &&
                     file.mtime(csv_cache_path) >= file.mtime(data_file_path)

      if (!cache_valid) {
        cat(sprintf("Large Excel file (%.1f MB) detected. Creating CSV cache...\n", file_size_mb))
        data <- readxl::read_excel(data_file_path)
        data.table::fwrite(data, csv_cache_path)
        cat("✓ CSV cache created:", basename(csv_cache_path), "\n")
        return(as.data.frame(data))
      } else {
        cat("Loading from CSV cache (faster)...\n")
        return(data.table::fread(csv_cache_path, data.table = FALSE))
      }
    }
  }

  # Default: use standard loader
  load_survey_data(data_file_path, project_root, convert_labelled)
}

# ==============================================================================
# END OF SHARED_DATA_LOADING.R
# ==============================================================================
