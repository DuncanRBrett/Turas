# ==============================================================================
# MODULE: SUMMARY_BUILDER.R
# ==============================================================================
#
# PURPOSE:
#   Build Index_Summary sheet that consolidates all key metrics
#   Extracts means, indices, NPS scores, top box summaries, and composites
#
# FUNCTIONS:
#   - build_index_summary_table() - Main builder
#   - extract_metric_rows() - Extract specific row types
#   - insert_section_headers() - Apply section grouping
#   - format_summary_for_excel() - Prepare for Excel output
#
# VERSION: 1.0.0
# DATE: 2025-11-06
# ==============================================================================

#' Build Index Summary Table
#'
#' Build complete summary table from all results
#'
#' @param results_list List of standard question results
#' @param composite_results List of composite results
#' @param banner_info Banner structure information
#' @param config Configuration list
#' @param composite_defs Data frame of composite definitions (optional)
#' @return Data frame ready for Excel output
#' @export
build_index_summary_table <- function(results_list, composite_results,
                                       banner_info, config,
                                       composite_defs = NULL) {

  message("Building index summary table...")
  message(sprintf("  results_list has %d items", length(results_list)))
  message(sprintf("  composite_results has %d items", length(composite_results)))
  message(sprintf("  Banner has %d internal_keys: %s",
                  length(banner_info$internal_keys),
                  paste(banner_info$internal_keys, collapse = ", ")))

  # Extract metric rows from standard questions
  metric_rows <- extract_metric_rows(results_list, banner_info, config)
  message(sprintf("  Extracted %d metric rows", nrow(metric_rows)))
  if (nrow(metric_rows) > 0) {
    message(sprintf("  Metric rows columns: %s", paste(names(metric_rows), collapse = ", ")))
  }

  # Extract composite rows
  composite_rows <- extract_composite_rows(
    composite_results,
    banner_info,
    composite_defs,
    config
  )

  # Combine
  if (nrow(metric_rows) > 0 && nrow(composite_rows) > 0) {
    all_metrics <- rbind(metric_rows, composite_rows)
  } else if (nrow(metric_rows) > 0) {
    all_metrics <- metric_rows
  } else if (nrow(composite_rows) > 0) {
    all_metrics <- composite_rows
  } else {
    # No metrics at all
    return(data.frame())
  }

  # Organize by composite groups (composite followed by its source questions)
  all_metrics <- organize_by_composite_groups(all_metrics, composite_defs, config)

  # Get show_sections setting
  show_sections <- get_config_value(config, "index_summary_show_sections", TRUE)

  # Validate show_sections is not NULL or length zero
  if (is.null(show_sections) || length(show_sections) == 0) {
    show_sections <- TRUE
  }

  # Insert section headers if enabled
  if (show_sections && "Section" %in% names(all_metrics)) {
    all_metrics <- insert_section_headers(all_metrics, banner_info)
  }

  # Format for Excel
  summary_table <- format_summary_for_excel(all_metrics, banner_info, config)

  return(summary_table)
}

#' Extract Metric Rows
#'
#' Extract metric rows (Average, Index, Score, Top/Bottom Box) from results
#'
#' @param results_list List of question results
#' @param banner_info Banner structure
#' @param config Configuration list
#' @return Data frame with metric rows
#' @keywords internal
extract_metric_rows <- function(results_list, banner_info, config) {

  metric_list <- list()
  internal_keys <- banner_info$internal_keys

  for (question_code in names(results_list)) {
    question_result <- results_list[[question_code]]

    # ISSUE #1 FIX: Skip ranking questions - they shouldn't be in index summary
    if (!is.null(question_result$question_type) &&
        length(question_result$question_type) > 0 &&
        question_result$question_type == "Ranking") {
      message(sprintf("    Skipping ranking question: %s", question_code))
      next
    }

    # Standard questions use 'table', composites use 'question_table'
    table <- if (!is.null(question_result$table)) {
      question_result$table
    } else if (!is.null(question_result$question_table)) {
      question_result$question_table
    } else {
      NULL
    }

    if (is.null(table)) {
      next
    }

    # Find metric rows
    avg_rows <- table[table$RowType == "Average", , drop = FALSE]
    idx_rows <- table[table$RowType == "Index", , drop = FALSE]
    score_rows <- table[table$RowType == "Score", , drop = FALSE]

    # Also get "Top Box" or "Bottom Box" rows
    box_rows <- table[grepl("Top.*Box|Bottom.*Box", table$RowLabel, ignore.case = TRUE), , drop = FALSE]
    # Exclude significance rows
    box_rows <- box_rows[box_rows$RowType != "Sig.", , drop = FALSE]

    # Combine
    all_rows <- rbind(avg_rows, idx_rows, score_rows, box_rows)

    if (nrow(all_rows) > 0) {
      message(sprintf("    Question %s: found %d metric rows (cols: %s)",
                      question_code, nrow(all_rows),
                      paste(names(all_rows), collapse = ", ")))

      # Replace generic labels (Mean, Average, Index, Score) with question text
      question_text <- if (!is.null(question_result$question_text) &&
                          length(question_result$question_text) > 0) {
        as.character(question_result$question_text)
      } else {
        question_code
      }

      # Add question code to the label
      full_label <- paste0(question_code, " - ", question_text)

      # ISSUE #2 FIX: Update RowLabel for metric rows to use question text with code
      for (i in 1:nrow(all_rows)) {
        current_label <- all_rows$RowLabel[i]
        # For Top/Bottom Box, prepend question text
        if (grepl("Top.*Box|Bottom.*Box", current_label, ignore.case = TRUE)) {
          all_rows$RowLabel[i] <- paste0(full_label, " - ", current_label)
        }
        # For all other metric labels (Average, Index, Score, NPS, etc.), replace with full question label
        else {
          all_rows$RowLabel[i] <- full_label
        }
      }

      # Add metadata
      all_rows$QuestionCode <- question_code
      all_rows$IsComposite <- FALSE
      all_rows$Section <- NA_character_

      # Ensure all banner columns exist
      for (key in internal_keys) {
        if (!key %in% names(all_rows)) {
          all_rows[[key]] <- NA_character_
        }
      }

      metric_list[[length(metric_list) + 1]] <- all_rows
    }
  }

  if (length(metric_list) == 0) {
    # Return empty data frame with expected structure
    empty_df <- data.frame(
      RowLabel = character(0),
      RowType = character(0),
      QuestionCode = character(0),
      IsComposite = logical(0),
      Section = character(0),
      stringsAsFactors = FALSE
    )

    # Add banner columns
    for (key in internal_keys) {
      empty_df[[key]] <- character(0)
    }

    return(empty_df)
  }

  result <- do.call(rbind, metric_list)
  rownames(result) <- NULL

  return(result)
}

#' Extract Composite Rows
#'
#' Extract composite metric rows
#'
#' @param composite_results List of composite results
#' @param banner_info Banner structure
#' @param composite_defs Composite definitions
#' @param config Configuration
#' @return Data frame with composite rows
#' @keywords internal
extract_composite_rows <- function(composite_results, banner_info,
                                    composite_defs, config) {

  # Check if composites should be shown
  show_composites <- get_config_value(config, "index_summary_show_composites", TRUE)

  # Validate show_composites is not NULL or length zero
  if (is.null(show_composites) || length(show_composites) == 0) {
    show_composites <- TRUE
  }

  if (!show_composites || length(composite_results) == 0) {
    # Return empty data frame
    empty_df <- data.frame(
      RowLabel = character(0),
      RowType = character(0),
      QuestionCode = character(0),
      IsComposite = logical(0),
      Section = character(0),
      stringsAsFactors = FALSE
    )

    for (key in banner_info$internal_keys) {
      empty_df[[key]] <- character(0)
    }

    return(empty_df)
  }

  composite_list <- list()
  internal_keys <- banner_info$internal_keys

  for (comp_code in names(composite_results)) {
    comp_result <- composite_results[[comp_code]]

    if (is.null(comp_result$question_table)) {
      next
    }

    table <- comp_result$question_table

    # Get metric row (should be Average, Index, or Score)
    metric_row <- table[table$RowType %in% c("Average", "Index", "Score"), , drop = FALSE]

    if (nrow(metric_row) > 0) {
      # Check if excluded from summary
      if (!is.null(composite_defs)) {
        comp_def <- composite_defs[composite_defs$CompositeCode == comp_code, ]

        if (nrow(comp_def) > 0) {
          exclude <- comp_def$ExcludeFromSummary[1]
          if (!is.na(exclude) && toupper(trimws(exclude)) == "Y") {
            next  # Skip this composite
          }

          # Get section
          section <- comp_def$SectionLabel[1]
          if (is.na(section)) {
            section <- NA_character_
          }
        } else {
          section <- NA_character_
        }
      } else {
        section <- NA_character_
      }

      # Add source questions info to the label
      if (!is.null(comp_def$SourceQuestions) && length(comp_def$SourceQuestions) > 0 && !is.na(comp_def$SourceQuestions[1])) {
        source_codes <- trimws(strsplit(as.character(comp_def$SourceQuestions[1]), ",")[[1]])
        metric_row$RowLabel <- paste0(metric_row$RowLabel, " (", paste(source_codes, collapse = ", "), ")")
      }

      # Mark as composite
      metric_row$QuestionCode <- comp_code
      metric_row$IsComposite <- TRUE
      metric_row$Section <- section

      # Ensure all banner columns exist
      for (key in internal_keys) {
        if (!key %in% names(metric_row)) {
          metric_row[[key]] <- NA_character_
        }
      }

      composite_list[[length(composite_list) + 1]] <- metric_row
    }
  }

  if (length(composite_list) == 0) {
    # Return empty data frame
    empty_df <- data.frame(
      RowLabel = character(0),
      RowType = character(0),
      QuestionCode = character(0),
      IsComposite = logical(0),
      Section = character(0),
      stringsAsFactors = FALSE
    )

    for (key in internal_keys) {
      empty_df[[key]] <- character(0)
    }

    return(empty_df)
  }

  result <- do.call(rbind, composite_list)
  rownames(result) <- NULL

  return(result)
}

#' Organize Metrics by Composite Groups
#'
#' Reorganize metrics to group composites with their source questions
#' Composites appear first, followed immediately by their source questions (indented)
#'
#' @param metrics_df Data frame with all metrics (standard + composite)
#' @param composite_defs Composite definitions data frame
#' @param config Configuration list
#' @return Reorganized data frame
#' @keywords internal
organize_by_composite_groups <- function(metrics_df, composite_defs, config) {

  # Silently organize metrics

  if (nrow(metrics_df) == 0) {
    return(metrics_df)
  }

  # If no composites, just sort by Section then RowLabel
  if (is.null(composite_defs) || nrow(composite_defs) == 0) {
    show_sections <- get_config_value(config, "index_summary_show_sections", TRUE)
    if (is.null(show_sections) || length(show_sections) == 0) {
      show_sections <- TRUE
    }

    if (show_sections && "Section" %in% names(metrics_df)) {
      metrics_df$SortKey <- ifelse(is.na(metrics_df$Section) | metrics_df$Section == "",
                                    paste0("ZZZ", metrics_df$RowLabel),
                                    paste0(metrics_df$Section, "_", metrics_df$RowLabel))
      metrics_df <- metrics_df[order(metrics_df$SortKey), ]
      metrics_df$SortKey <- NULL
    } else {
      metrics_df <- metrics_df[order(metrics_df$RowLabel), ]
    }
    return(metrics_df)
  }

  # Build map of source questions to composites
  source_map <- list()  # source_question_code -> list of composite codes
  for (i in 1:nrow(composite_defs)) {
    comp_code <- composite_defs$CompositeCode[i]
    sources <- composite_defs$SourceQuestions[i]

    if (!is.na(sources) && nchar(trimws(sources)) > 0) {
      source_codes <- trimws(strsplit(as.character(sources), ",")[[1]])
      for (src in source_codes) {
        if (!src %in% names(source_map)) {
          source_map[[src]] <- character(0)
        }
        source_map[[src]] <- c(source_map[[src]], comp_code)
      }
    }
  }

  # Separate metrics into composites and non-composites
  composite_metrics <- metrics_df[!is.na(metrics_df$IsComposite) &
                                   metrics_df$IsComposite == TRUE, , drop = FALSE]
  standard_metrics <- metrics_df[is.na(metrics_df$IsComposite) |
                                  metrics_df$IsComposite == FALSE, , drop = FALSE]

  # Build organized list
  organized_rows <- list()

  # Get unique sections from composites (in order)
  if ("Section" %in% names(composite_metrics)) {
    sections <- unique(composite_metrics$Section[!is.na(composite_metrics$Section) &
                                                   composite_metrics$Section != ""])
    sections <- sort(sections)
  } else {
    sections <- character(0)
  }

  # Process each section
  for (section in sections) {
    section_composites <- composite_metrics[!is.na(composite_metrics$Section) &
                                             composite_metrics$Section == section, , drop = FALSE]

    for (i in 1:nrow(section_composites)) {
      comp_row <- section_composites[i, , drop = FALSE]
      comp_code <- comp_row$QuestionCode[1]

      # Add composite row
      organized_rows[[length(organized_rows) + 1]] <- comp_row

      # Find and add source questions for this composite
      comp_def <- composite_defs[composite_defs$CompositeCode == comp_code, ]
      if (nrow(comp_def) > 0 && !is.na(comp_def$SourceQuestions[1])) {
        source_codes <- trimws(strsplit(as.character(comp_def$SourceQuestions[1]), ",")[[1]])

        for (src_code in source_codes) {
          src_rows <- standard_metrics[standard_metrics$QuestionCode == src_code, , drop = FALSE]
          if (nrow(src_rows) > 0) {
            # Indent source question labels
            for (j in 1:nrow(src_rows)) {
              src_rows$RowLabel[j] <- paste0("  ", src_rows$RowLabel[j])
            }
            organized_rows[[length(organized_rows) + 1]] <- src_rows
          }
        }
      }
    }
  }

  # Add composites without sections
  no_section_composites <- composite_metrics[is.na(composite_metrics$Section) |
                                              composite_metrics$Section == "", , drop = FALSE]

  for (i in 1:nrow(no_section_composites)) {
    comp_row <- no_section_composites[i, , drop = FALSE]
    comp_code <- comp_row$QuestionCode[1]

    # Add composite row
    organized_rows[[length(organized_rows) + 1]] <- comp_row

    # Find and add source questions
    comp_def <- composite_defs[composite_defs$CompositeCode == comp_code, ]
    if (nrow(comp_def) > 0 && !is.na(comp_def$SourceQuestions[1])) {
      source_codes <- trimws(strsplit(as.character(comp_def$SourceQuestions[1]), ",")[[1]])

      for (src_code in source_codes) {
        src_rows <- standard_metrics[standard_metrics$QuestionCode == src_code, , drop = FALSE]
        if (nrow(src_rows) > 0) {
          # Indent source question labels
          for (j in 1:nrow(src_rows)) {
            src_rows$RowLabel[j] <- paste0("  ", src_rows$RowLabel[j])
          }
          organized_rows[[length(organized_rows) + 1]] <- src_rows
        }
      }
    }
  }

  # Add remaining standard metrics that aren't part of any composite
  source_question_codes <- names(source_map)
  remaining_metrics <- standard_metrics[!standard_metrics$QuestionCode %in% source_question_codes, , drop = FALSE]

  if (nrow(remaining_metrics) > 0) {
    # Sort remaining by section then label
    if ("Section" %in% names(remaining_metrics)) {
      remaining_metrics$SortKey <- ifelse(is.na(remaining_metrics$Section) | remaining_metrics$Section == "",
                                          paste0("ZZZ", remaining_metrics$RowLabel),
                                          paste0(remaining_metrics$Section, "_", remaining_metrics$RowLabel))
      remaining_metrics <- remaining_metrics[order(remaining_metrics$SortKey), ]
      remaining_metrics$SortKey <- NULL
    } else {
      remaining_metrics <- remaining_metrics[order(remaining_metrics$RowLabel), ]
    }

    organized_rows[[length(organized_rows) + 1]] <- remaining_metrics
  }

  # Combine all organized rows
  if (length(organized_rows) == 0) {
    return(metrics_df)
  }

  result <- do.call(rbind, organized_rows)
  rownames(result) <- NULL

  return(result)
}

#' Insert Section Headers
#'
#' Insert section header rows into summary table
#' PRESERVES EXISTING ORDER - just inserts headers where section changes
#'
#' @param metrics_df Data frame with metrics (already organized)
#' @param banner_info Banner structure
#' @return Data frame with section headers inserted
#' @keywords internal
insert_section_headers <- function(metrics_df, banner_info) {

  if (!"Section" %in% names(metrics_df)) {
    return(metrics_df)
  }

  if (nrow(metrics_df) == 0) {
    return(metrics_df)
  }

  internal_keys <- banner_info$internal_keys
  result_rows <- list()

  current_section <- NULL

  # Iterate through rows in existing order
  for (i in 1:nrow(metrics_df)) {
    row <- metrics_df[i, , drop = FALSE]
    row_section <- row$Section[1]

    # Check if section changed (and is not NA/empty)
    if (!is.na(row_section) && row_section != "") {
      # Check if section changed
      section_changed <- is.null(current_section) ||
                        is.na(current_section) ||
                        current_section != row_section

      if (section_changed) {
        # Insert section header
        header_row <- data.frame(
          RowLabel = row_section,
          RowType = "SectionHeader",
          QuestionCode = NA_character_,
          IsComposite = NA,
          Section = row_section,
          stringsAsFactors = FALSE
        )

        # Add empty values for all banner columns
        for (key in internal_keys) {
          header_row[[key]] <- ""
        }

        # Add StyleHint if it exists
        if ("StyleHint" %in% names(row)) {
          header_row$StyleHint <- "SectionHeader"
        }

        result_rows[[length(result_rows) + 1]] <- header_row
        current_section <- row_section
      }
    } else {
      # Row has no section - reset current_section
      current_section <- NULL
    }

    # Add the data row
    result_rows[[length(result_rows) + 1]] <- row
  }

  result <- do.call(rbind, result_rows)
  rownames(result) <- NULL

  return(result)
}

#' Format Summary for Excel
#'
#' Format summary table for Excel output with special styling cues
#'
#' @param metrics_df Data frame with metrics
#' @param banner_info Banner structure
#' @param config Configuration
#' @return Formatted data frame
#' @keywords internal
format_summary_for_excel <- function(metrics_df, banner_info, config) {

  if (nrow(metrics_df) == 0) {
    return(metrics_df)
  }

  # Add style hints
  metrics_df$StyleHint <- "Normal"

  # Section headers
  if ("RowType" %in% names(metrics_df) && length(metrics_df$RowType) > 0) {
    section_idx <- which(metrics_df$RowType == "SectionHeader")
    if (length(section_idx) > 0) {
      metrics_df$StyleHint[section_idx] <- "SectionHeader"
    }
  }

  # Composite rows
  if ("IsComposite" %in% names(metrics_df) && length(metrics_df$IsComposite) > 0) {
    composite_idx <- which(!is.na(metrics_df$IsComposite) & metrics_df$IsComposite == TRUE)
    if (length(composite_idx) > 0) {
      metrics_df$StyleHint[composite_idx] <- "Composite"
    }
  }

  # Add prefix to composite labels
  if ("IsComposite" %in% names(metrics_df) && length(metrics_df$IsComposite) > 0) {
    composite_idx <- which(!is.na(metrics_df$IsComposite) & metrics_df$IsComposite == TRUE)
    if (length(composite_idx) > 0 && "RowLabel" %in% names(metrics_df)) {
      metrics_df$RowLabel[composite_idx] <- paste0("\u2192 ",
                                                    metrics_df$RowLabel[composite_idx])
    }
  }

  # Clean up display
  metrics_df$RowLabel <- trimws(metrics_df$RowLabel)

  # Get decimal places setting
  decimal_places <- get_config_value(config, "index_summary_decimal_places", 1)

  # No need to reformat - values already formatted from processing
  # Just ensure consistency

  return(metrics_df)
}

message("[OK] Turas>Tabs summary_builder module loaded")
