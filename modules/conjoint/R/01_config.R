# ==============================================================================
# CONJOINT CONFIG LOADER
# ==============================================================================

#' Load Conjoint Configuration
#'
#' Loads and validates conjoint study configuration from Excel file.
#'
#' @param config_file Path to configuration Excel file
#' @return List with validated configuration
#' @keywords internal
load_conjoint_config <- function(config_file) {

  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file, call. = FALSE)
  }

  # Load settings
  settings <- openxlsx::read.xlsx(config_file, sheet = "Settings")
  settings_list <- setNames(as.list(settings$Value), settings$Setting)

  # Load attributes definition
  attributes <- openxlsx::read.xlsx(config_file, sheet = "Attributes")

  # Validate attributes
  required_cols <- c("AttributeName", "NumLevels", "LevelNames")
  missing_cols <- setdiff(required_cols, names(attributes))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in Attributes sheet: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Parse level names (comma-separated)
  attributes$levels_list <- lapply(attributes$LevelNames, function(x) {
    trimws(strsplit(as.character(x), ",")[[1]])
  })

  # Validate level counts match
  for (i in seq_len(nrow(attributes))) {
    actual_levels <- length(attributes$levels_list[[i]])
    expected_levels <- attributes$NumLevels[i]
    if (actual_levels != expected_levels) {
      stop(sprintf("Attribute '%s': expected %d levels but found %d",
                   attributes$AttributeName[i], expected_levels, actual_levels),
           call. = FALSE)
    }
  }

  # Load design (if exists)
  design <- NULL
  if ("Design" %in% openxlsx::getSheetNames(config_file)) {
    design <- openxlsx::read.xlsx(config_file, sheet = "Design")
  }

  list(
    settings = settings_list,
    attributes = attributes,
    design = design
  )
}
