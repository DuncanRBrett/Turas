# ==============================================================================
# ALCHEMER PARSER - MAIN ORCHESTRATION
# ==============================================================================
# Main entry point for AlchemerParser module
# Coordinates parsing of Alchemer survey files and generates Tabs config files
# ==============================================================================

#' Run AlchemerParser
#'
#' @description
#' Orchestrates the complete parsing workflow:
#' 1. Load and validate input files
#' 2. Parse data export map, translation export, and Word questionnaire
#' 3. Classify question types
#' 4. Generate question codes
#' 5. Create output files for Tabs module
#'
#' @param project_dir Directory containing the three input files
#' @param project_name Optional project name (extracted from filenames if NULL)
#' @param output_dir Directory for output files (defaults to project_dir)
#' @param verbose Print progress messages (default TRUE)
#'
#' @return List containing:
#'   \item{questions}{Parsed question structure}
#'   \item{validation_flags}{List of issues requiring review}
#'   \item{outputs}{Paths to generated output files}
#'   \item{summary}{Summary statistics}
#'
#' @export
run_alchemerparser <- function(project_dir,
                               project_name = NULL,
                               output_dir = NULL,
                               verbose = TRUE) {

  # Validate inputs
  if (!dir.exists(project_dir)) {
    alchemerparser_refuse(
      code = "IO_DIR_NOT_FOUND",
      title = "Project Directory Not Found",
      problem = sprintf("Cannot find project directory: %s", project_dir),
      why_it_matters = "AlchemerParser requires access to input files in the specified directory.",
      how_to_fix = c(
        "Check that the directory path is correct",
        "Verify the directory exists",
        "Check for typos in the path"
      )
    )
  }

  if (is.null(output_dir)) {
    output_dir <- project_dir
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # ==============================================================================
  # STEP 1: Locate and validate input files
  # ==============================================================================
  if (verbose) {
    cat("\n")
    cat("==============================================================================\n")
    cat("  ALCHEMER PARSER\n")
    cat("==============================================================================\n\n")
    cat("Step 1: Locating input files...\n")
  }

  files <- locate_input_files(project_dir, project_name, verbose)

  if (is.null(project_name)) {
    project_name <- files$project_name
  }

  if (verbose) {
    cat(sprintf("  Project name: %s\n", project_name))
    cat(sprintf("  Data export map: %s\n", basename(files$data_map)))
    cat(sprintf("  Translation export: %s\n", basename(files$translation)))
    cat(sprintf("  Questionnaire: %s\n", basename(files$questionnaire)))
  }

  # ==============================================================================
  # STEP 2: Parse data export map
  # ==============================================================================
  if (verbose) {
    cat("\nStep 2: Parsing data export map...\n")
  }

  parsed_data <- parse_data_export_map(files$data_map, verbose)

  if (verbose) {
    cat(sprintf("  Found %d questions with %d total columns\n",
                length(parsed_data$questions),
                parsed_data$n_columns))
  }

  # ==============================================================================
  # STEP 3: Parse translation export
  # ==============================================================================
  if (verbose) {
    cat("\nStep 3: Parsing translation export...\n")
  }

  translation_data <- parse_translation_export(files$translation, verbose)

  if (verbose) {
    cat(sprintf("  Found %d questions and %d options\n",
                translation_data$n_questions,
                translation_data$n_options))
  }

  # ==============================================================================
  # STEP 4: Parse Word questionnaire
  # ==============================================================================
  if (verbose) {
    cat("\nStep 4: Parsing Word questionnaire...\n")
  }

  word_hints <- parse_word_questionnaire(files$questionnaire, verbose)

  if (verbose) {
    cat(sprintf("  Extracted hints for %d questions\n",
                length(word_hints)))
  }

  # ==============================================================================
  # STEP 5: Classify questions and detect types
  # ==============================================================================
  if (verbose) {
    cat("\nStep 5: Classifying question types...\n")
  }

  questions <- classify_questions(
    parsed_data$questions,
    translation_data,
    word_hints,
    verbose
  )

  if (verbose) {
    # Extract variable types (handling both grid and non-grid questions)
    all_types <- unlist(lapply(questions, function(q) {
      if (q$is_grid) {
        # For grid questions, get types from sub-questions
        sapply(q$sub_questions, function(sq) sq$variable_type)
      } else {
        # For non-grid questions, get type directly
        q$variable_type
      }
    }))

    type_summary <- table(all_types)
    cat("  Question type distribution:\n")
    for (type in names(type_summary)) {
      cat(sprintf("    %s: %d\n", type, type_summary[type]))
    }
  }

  # ==============================================================================
  # STEP 6: Generate question codes
  # ==============================================================================
  if (verbose) {
    cat("\nStep 6: Generating question codes...\n")
  }

  questions <- generate_question_codes(questions, verbose)

  if (verbose) {
    cat(sprintf("  Generated codes for %d questions\n", length(questions)))
  }

  # ==============================================================================
  # STEP 7: Validate and flag issues
  # ==============================================================================
  if (verbose) {
    cat("\nStep 7: Validating results...\n")
  }

  validation <- validate_parsing(questions, translation_data, word_hints, verbose)

  if (verbose) {
    if (length(validation$flags) > 0) {
      cat(sprintf("  Found %d items for review:\n", length(validation$flags)))

      # Count by severity
      severity_counts <- table(sapply(validation$flags, function(f) f$severity))
      for (sev in names(severity_counts)) {
        cat(sprintf("    %s: %d\n", sev, severity_counts[sev]))
      }
    } else {
      cat("  No validation issues found\n")
    }
  }

  # ==============================================================================
  # STEP 8: Generate output files
  # ==============================================================================
  if (verbose) {
    cat("\nStep 8: Generating output files...\n")
  }

  outputs <- generate_output_files(
    questions,
    project_name,
    output_dir,
    validation$flags,
    verbose
  )

  if (verbose) {
    cat("  Generated files:\n")
    cat(sprintf("    - %s\n", basename(outputs$crosstab_config)))
    cat(sprintf("    - %s\n", basename(outputs$survey_structure)))
    cat(sprintf("    - %s\n", basename(outputs$data_headers)))
  }

  # ==============================================================================
  # Prepare summary
  # ==============================================================================

  # Count total columns (handling both grid and non-grid questions)
  total_columns <- sum(sapply(questions, function(q) {
    if (q$is_grid) {
      sum(sapply(q$sub_questions, function(sq) sq$n_columns))
    } else {
      q$n_columns
    }
  }))

  # Extract all variable types (handling both grid and non-grid questions)
  all_types <- unlist(lapply(questions, function(q) {
    if (q$is_grid) {
      sapply(q$sub_questions, function(sq) sq$variable_type)
    } else {
      q$variable_type
    }
  }))

  summary <- list(
    project_name = project_name,
    n_questions = length(questions),
    n_columns = total_columns,
    n_flags = length(validation$flags),
    type_distribution = table(all_types)
  )

  if (verbose) {
    cat("\n")
    cat("==============================================================================\n")
    cat("  PARSING COMPLETE\n")
    cat("==============================================================================\n")
    cat(sprintf("  Total questions: %d\n", summary$n_questions))
    cat(sprintf("  Total data columns: %d\n", summary$n_columns))
    cat(sprintf("  Items flagged for review: %d\n", summary$n_flags))
    cat("\n")
  }

  # Return results
  invisible(list(
    questions = questions,
    validation_flags = validation$flags,
    outputs = outputs,
    summary = summary
  ))
}


#' Locate Input Files
#'
#' @description
#' Scans project directory for the three required input files.
#' Extracts project name from filenames.
#'
#' @param project_dir Directory to search
#' @param project_name Optional project name filter
#' @param verbose Print messages
#'
#' @return List with file paths and extracted project name
#'
#' @keywords internal
locate_input_files <- function(project_dir, project_name = NULL, verbose = TRUE) {

  # List all files in directory
  all_files <- list.files(project_dir, full.names = TRUE)

  # Find questionnaire (Word doc)
  questionnaire_pattern <- if (!is.null(project_name)) {
    paste0(project_name, "_questionnaire\\.docx?$")
  } else {
    "_questionnaire\\.docx?$"
  }

  questionnaire <- grep(questionnaire_pattern, all_files,
                        value = TRUE, ignore.case = TRUE)

  if (length(questionnaire) == 0) {
    alchemerparser_refuse(
      code = "IO_QUESTIONNAIRE_NOT_FOUND",
      title = "Questionnaire File Not Found",
      problem = "No questionnaire file found in project directory.",
      why_it_matters = "AlchemerParser requires the Word questionnaire to parse survey structure.",
      how_to_fix = c(
        "Ensure the questionnaire file is named *_questionnaire.docx",
        "Check that the file is in the project directory",
        "Verify the file has .docx or .doc extension"
      )
    )
  }
  if (length(questionnaire) > 1) {
    alchemerparser_refuse(
      code = "IO_MULTIPLE_QUESTIONNAIRES",
      title = "Multiple Questionnaire Files Found",
      problem = "Found multiple *_questionnaire.docx files in directory.",
      why_it_matters = "Cannot determine which questionnaire to parse when multiple files exist.",
      how_to_fix = c(
        "Specify the project_name parameter to disambiguate",
        "Remove extra questionnaire files from the directory",
        "Keep only one questionnaire file per project directory"
      ),
      observed = paste("Found:", length(questionnaire), "files")
    )
  }

  # Extract project name from questionnaire if not provided
  if (is.null(project_name)) {
    questionnaire_base <- basename(questionnaire)
    project_name <- sub("_questionnaire\\.docx?$", "", questionnaire_base,
                       ignore.case = TRUE)
  }

  # Find data export map
  data_map_pattern <- paste0(project_name, "_data_export_map\\.xlsx?$")
  data_map <- grep(data_map_pattern, all_files,
                   value = TRUE, ignore.case = TRUE)

  if (length(data_map) == 0) {
    alchemerparser_refuse(
      code = "IO_DATA_MAP_NOT_FOUND",
      title = "Data Export Map Not Found",
      problem = sprintf("No data export map found for project '%s'.", project_name),
      why_it_matters = "Data export map is required to understand data column structure.",
      how_to_fix = c(
        sprintf("Ensure the file is named %s_data_export_map.xlsx", project_name),
        "Export the data map from Alchemer survey settings",
        "Check that the file is in the project directory"
      )
    )
  }

  # Find translation export
  translation_pattern <- paste0(project_name, "_translation-export\\.xls")
  translation <- grep(translation_pattern, all_files,
                      value = TRUE, ignore.case = TRUE)

  if (length(translation) == 0) {
    alchemerparser_refuse(
      code = "IO_TRANSLATION_NOT_FOUND",
      title = "Translation Export Not Found",
      problem = sprintf("No translation export found for project '%s'.", project_name),
      why_it_matters = "Translation export is required to get question and option texts.",
      how_to_fix = c(
        sprintf("Ensure the file is named %s_translation-export.xls", project_name),
        "Export the translation file from Alchemer",
        "Check that the file is in the project directory"
      )
    )
  }

  return(list(
    project_name = project_name,
    questionnaire = questionnaire,
    data_map = data_map,
    translation = translation
  ))
}


#' Null-Coalescing Operator
#'
#' @description Returns first non-NULL value
#'
#' @keywords internal
`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}
