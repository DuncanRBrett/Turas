# ==============================================================================
# BRAND MODULE - FUNNEL OUTPUT (Excel + CSV per FUNNEL_SPEC_v2 §7)
# ==============================================================================
# Writes:
#   - funnel_{category_code}.xlsx  (4 sheets: Stage_Matrix, Conversions,
#                                   Attitude_Decomposition, Metadata)
#   - funnel_{category_code}_long.csv (one row per brand x stage, with
#                                      ClientCode + QuestionText on every
#                                      row so downstream consumers do not
#                                      need the role registry)
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_OUTPUT_VERSION <- "2.0"


# ==============================================================================
# PUBLIC: write_funnel_excel
# ==============================================================================

#' Write a funnel Excel workbook (4 sheets)
#'
#' @param result List from \code{run_funnel()}.
#' @param brand_list Data frame with BrandCode and BrandLabel.
#' @param role_map Named list. Used to enrich header rows with ClientCode +
#'   QuestionText. NULL is allowed — the workbook still writes, minus that
#'   enrichment.
#' @param output_path Character. Full path to the .xlsx file to write.
#' @param config List of the funnel.* config values used at runtime.
#'
#' @return \code{output_path} invisibly. Throws a TRS refusal if the file
#'   cannot be written.
#'
#' @export
write_funnel_excel <- function(result, brand_list, role_map = NULL,
                               output_path, config = list()) {
  .require_valid_result(result)
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  }
  wb <- openxlsx::createWorkbook()
  .write_stage_matrix_sheet(wb, result, brand_list, role_map)
  .write_conversions_sheet(wb, result, brand_list)
  .write_attitude_sheet(wb, result, brand_list)
  .write_metadata_sheet(wb, result, brand_list, config)

  tryCatch(
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE),
    error = function(e) brand_refuse(
      code = "IO_FUNNEL_EXCEL_WRITE_FAILED",
      title = "Cannot Write Funnel Workbook",
      problem = sprintf("openxlsx failed to save '%s': %s",
                        output_path, conditionMessage(e)),
      why_it_matters = paste(
        "The Excel output is a required deliverable for every brand",
        "study. A save failure means the operator sees nothing."),
      how_to_fix = c(
        "Check that the output directory is writable.",
        "Check that the file is not already open in Excel."
      )
    )
  )
  invisible(output_path)
}


# ==============================================================================
# PUBLIC: write_funnel_csv
# ==============================================================================

#' Write the long-format funnel CSV
#'
#' One row per brand x stage. Includes ClientCode and QuestionText so
#' downstream consumers (tracker, external analysis) do not need the
#' Survey_Structure workbook to interpret the data.
#'
#' @param result List from \code{run_funnel()}.
#' @param brand_list Data frame with BrandCode, BrandLabel.
#' @param role_map Optional. Pulled from \code{load_role_map()}.
#' @param output_path Full path to the CSV.
#' @param config Named list; \code{category_code}, \code{wave_label} used.
#'
#' @return \code{output_path} invisibly.
#'
#' @export
write_funnel_csv <- function(result, brand_list, role_map = NULL,
                             output_path, config = list()) {
  .require_valid_result(result)
  df <- .build_long_csv_df(result, brand_list, role_map, config)
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  }
  tryCatch(
    {
      if (requireNamespace("data.table", quietly = TRUE)) {
        data.table::fwrite(df, output_path)
      } else {
        utils::write.csv(df, output_path, row.names = FALSE)
      }
    },
    error = function(e) brand_refuse(
      code = "IO_FUNNEL_CSV_WRITE_FAILED",
      title = "Cannot Write Funnel Long CSV",
      problem = sprintf("Write to '%s' failed: %s",
                        output_path, conditionMessage(e)),
      why_it_matters = paste(
        "Tracker concatenates the long CSV across waves. A write failure",
        "means the wave is missing from cross-wave views."),
      how_to_fix = "Check file-system permissions for the output folder."
    )
  )
  invisible(output_path)
}


# ==============================================================================
# INTERNAL: SHEET BUILDERS
# ==============================================================================

.write_stage_matrix_sheet <- function(wb, result, brand_list, role_map) {
  openxlsx::addWorksheet(wb, "Stage_Matrix")
  stages <- result$stages
  if (is.null(stages) || nrow(stages) == 0) return(invisible(NULL))

  stage_keys <- unique(as.character(stages$stage_key))
  brands <- as.character(brand_list$BrandCode)
  brand_labels <- as.character(brand_list$BrandLabel %||% brand_list$BrandCode)

  header <- .stage_header_rows(role_map, stage_keys)
  body <- .stage_body_rows(stages, stage_keys, brands, brand_labels)
  base_row <- .stage_base_row(stages, stage_keys)

  # Write each section at its own startRow. Writing three separate
  # sections avoids R's strict rbind column-type matching (header rows
  # are character, body and base rows carry numeric percentages).
  openxlsx::writeData(wb, "Stage_Matrix", header, startRow = 1,
                      colNames = FALSE)
  openxlsx::writeData(wb, "Stage_Matrix", body,
                      startRow = nrow(header) + 1, colNames = FALSE)
  openxlsx::writeData(wb, "Stage_Matrix", base_row,
                      startRow = nrow(header) + nrow(body) + 1,
                      colNames = FALSE)
}


.stage_header_rows <- function(role_map, stage_keys) {
  rm_lookup <- .role_map_lookup_for_stages(role_map)
  client_codes <- vapply(stage_keys, function(k)
    rm_lookup[[k]]$client_code %||% "", character(1))
  question_texts <- vapply(stage_keys, function(k)
    rm_lookup[[k]]$question_text %||% "", character(1))
  stage_labels <- vapply(stage_keys, .stage_label_export, character(1))

  # Header is three rows with the same column count as the body:
  # col 1 = row label, col 2 = blank (BrandLabel column), then one
  # column per stage carrying ClientCode / QuestionText / Stage label.
  header_mat <- rbind(
    c("ClientCode",   "", client_codes),
    c("QuestionText", "", question_texts),
    c("Stage",        "", stage_labels)
  )
  out <- as.data.frame(header_mat, stringsAsFactors = FALSE,
                       check.names = FALSE)
  names(out) <- c("BrandCode", "BrandLabel",
                  paste0("stage_", seq_along(stage_keys)))
  out
}


.stage_body_rows <- function(stages, stage_keys, brands, brand_labels) {
  mat <- matrix(NA_real_, nrow = length(brands), ncol = length(stage_keys),
                dimnames = list(brands, stage_keys))
  for (k in stage_keys) {
    for (b in brands) {
      row <- stages[stages$stage_key == k & stages$brand_code == b, ,
                    drop = FALSE]
      if (nrow(row) > 0) mat[b, k] <- round(100 * row$pct_weighted, 2)
    }
  }
  out <- data.frame(
    BrandCode = brands, BrandLabel = brand_labels,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  for (i in seq_along(stage_keys)) {
    out[[paste0("stage_", i)]] <- unname(mat[, i])
  }
  out
}


.stage_base_row <- function(stages, stage_keys) {
  totals <- vapply(stage_keys, function(k) {
    sum(stages$base_unweighted[stages$stage_key == k], na.rm = TRUE)
  }, numeric(1))
  out <- data.frame(BrandCode = "Base (unweighted, all brands)",
                    BrandLabel = "",
                    stringsAsFactors = FALSE, check.names = FALSE)
  for (i in seq_along(stage_keys)) {
    out[[paste0("stage_", i)]] <- unname(totals[i])
  }
  out
}


.write_conversions_sheet <- function(wb, result, brand_list) {
  openxlsx::addWorksheet(wb, "Conversions")
  conv <- result$conversions
  if (is.null(conv) || nrow(conv) == 0) return(invisible(NULL))

  brands <- as.character(brand_list$BrandCode)
  labels <- as.character(brand_list$BrandLabel %||% brand_list$BrandCode)
  transitions <- unique(paste(conv$from_stage, conv$to_stage, sep = "_to_"))

  out <- data.frame(BrandCode = brands, BrandLabel = labels,
                    stringsAsFactors = FALSE)
  for (tr in transitions) {
    parts <- strsplit(tr, "_to_", fixed = TRUE)[[1]]
    vals <- vapply(brands, function(b) {
      row <- conv[conv$brand_code == b &
                    conv$from_stage == parts[1] &
                    conv$to_stage == parts[2], , drop = FALSE]
      if (nrow(row) == 0) NA_real_ else round(row$value, 4)
    }, numeric(1))
    out[[tr]] <- unname(vals)
  }
  openxlsx::writeData(wb, "Conversions", out)
}


.write_attitude_sheet <- function(wb, result, brand_list) {
  openxlsx::addWorksheet(wb, "Attitude_Decomposition")
  att <- result$attitude_decomposition
  if (is.null(att) || nrow(att) == 0) return(invisible(NULL))

  positions <- c("attitude.love","attitude.prefer","attitude.ambivalent",
                 "attitude.reject","attitude.no_opinion")
  brands <- as.character(brand_list$BrandCode)
  labels <- as.character(brand_list$BrandLabel %||% brand_list$BrandCode)

  out <- data.frame(BrandCode = brands, BrandLabel = labels,
                    stringsAsFactors = FALSE)
  for (p in positions) {
    vals <- vapply(brands, function(b) {
      row <- att[att$brand_code == b & att$attitude_role == p, , drop = FALSE]
      if (nrow(row) == 0) NA_real_ else round(100 * row$pct, 2)
    }, numeric(1))
    out[[.attitude_label(p)]] <- unname(vals)
  }
  out$Aware_Base_Unweighted <- vapply(brands, function(b) {
    sub <- att[att$brand_code == b, , drop = FALSE]
    if (nrow(sub) == 0) NA_real_ else sub$base[1]
  }, numeric(1))

  openxlsx::writeData(wb, "Attitude_Decomposition", out)
}


.write_metadata_sheet <- function(wb, result, brand_list, config) {
  openxlsx::addWorksheet(wb, "Metadata")
  rows <- data.frame(
    Key = c("category_type", "focal_brand", "wave",
            "n_unweighted", "n_weighted",
            "stage_count", "conversion_metric",
            "warn_base", "suppress_base",
            "significance_note"),
    Value = c(
      result$meta$category_type %||% "",
      result$meta$focal_brand %||% "",
      as.character(result$meta$wave %||% ""),
      as.character(result$meta$n_unweighted %||% ""),
      as.character(result$meta$n_weighted %||% ""),
      as.character(result$meta$stage_count %||% ""),
      config$`funnel.conversion_metric` %||% "ratio",
      as.character(config$`funnel.warn_base` %||% 75),
      as.character(config$`funnel.suppress_base` %||% 0),
      paste("Two-proportion z-test. Panel sampling is non-probability;",
            "margin of error is not reported.")
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Metadata", rows)
}


# ==============================================================================
# INTERNAL: LONG-FORMAT CSV
# ==============================================================================

.build_long_csv_df <- function(result, brand_list, role_map, config) {
  stages <- result$stages
  if (is.null(stages) || nrow(stages) == 0) {
    return(.empty_long_df())
  }
  brand_name_for <- stats::setNames(
    as.character(brand_list$BrandLabel %||% brand_list$BrandCode),
    as.character(brand_list$BrandCode))

  role_lookup <- .role_map_lookup_for_stages(role_map)
  stage_keys <- unique(as.character(stages$stage_key))
  stage_index <- stats::setNames(seq_along(stage_keys), stage_keys)

  sig_focal <- .sig_lookup(result$sig_results, "focal_vs_competitor")
  sig_avg   <- .sig_lookup(result$sig_results, "focal_vs_cat_avg")

  data.frame(
    brand_code = stages$brand_code,
    brand_name = unname(brand_name_for[stages$brand_code]),
    stage_index = unname(stage_index[stages$stage_key]),
    stage_label = vapply(stages$stage_key, .stage_label_export,
                         character(1)),
    stage_key = stages$stage_key,
    pct_weighted = stages$pct_weighted,
    pct_unweighted = stages$pct_unweighted,
    base_weighted = stages$base_weighted,
    base_unweighted = stages$base_unweighted,
    warning_flag = stages$warning_flag,
    sig_vs_focal = vapply(seq_len(nrow(stages)), function(i)
      sig_focal[[paste(stages$stage_key[i], stages$brand_code[i],
                       sep = "|")]] %||% "na", character(1)),
    sig_vs_cat_avg = vapply(seq_len(nrow(stages)), function(i)
      sig_avg[[paste(stages$stage_key[i], "category_avg", sep = "|")]]
        %||% "na", character(1)),
    wave_label = as.character(config$wave_label %||% result$meta$wave %||% ""),
    category_code = as.character(config$category_code %||% ""),
    client_code = vapply(stages$stage_key,
      function(k) role_lookup[[k]]$client_code %||% "", character(1)),
    question_text = vapply(stages$stage_key,
      function(k) role_lookup[[k]]$question_text %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}


.empty_long_df <- function() {
  data.frame(brand_code = character(0), brand_name = character(0),
             stage_index = integer(0), stage_label = character(0),
             stage_key = character(0),
             pct_weighted = numeric(0), pct_unweighted = numeric(0),
             base_weighted = numeric(0), base_unweighted = numeric(0),
             warning_flag = character(0),
             sig_vs_focal = character(0), sig_vs_cat_avg = character(0),
             wave_label = character(0), category_code = character(0),
             client_code = character(0), question_text = character(0),
             stringsAsFactors = FALSE)
}


.sig_lookup <- function(sig_df, comparison) {
  if (is.null(sig_df) || nrow(sig_df) == 0) return(list())
  sub <- sig_df[sig_df$comparison == comparison, , drop = FALSE]
  if (nrow(sub) == 0) return(list())
  stats::setNames(
    ifelse(sub$significant, sub$direction, "not_sig"),
    paste(sub$stage_key, sub$brand_code, sep = "|")
  )
}


# ==============================================================================
# INTERNAL: SMALL HELPERS
# ==============================================================================

.require_valid_result <- function(result) {
  if (is.null(result) || identical(result$status, "REFUSED")) {
    brand_refuse(
      code = "DATA_FUNNEL_EMPTY",
      title = "Cannot Write Funnel Output: No Result",
      problem = "The funnel result is NULL or REFUSED.",
      why_it_matters = paste(
        "Writing an Excel / CSV with no data would produce a misleading",
        "empty deliverable. The writer refuses instead."),
      how_to_fix = c(
        "Check run_funnel() return value before calling the writer.",
        "If the funnel element was intentionally skipped, do not call the writer."
      )
    )
  }
}


.stage_label_export <- function(key) {
  labels <- c(
    aware              = "Aware",
    consideration      = "Consideration",
    bought_long        = "Bought",
    bought_target      = "Frequent",
    preferred          = "Preferred",
    current_owner_d    = "Current owner",
    long_tenured_d     = "Long-tenured owner",
    current_customer_s = "Current customer",
    long_tenured_s     = "Long-tenured customer"
  )
  unname(labels[key]) %||% key
}


.attitude_label <- function(role) {
  labels <- c(attitude.love = "Love", attitude.prefer = "Prefer",
              attitude.ambivalent = "Ambivalent",
              attitude.reject = "Reject",
              attitude.no_opinion = "No Opinion")
  unname(labels[role]) %||% role
}


#' Map stage keys to their driving role entry in the role map
#' @keywords internal
.role_map_lookup_for_stages <- function(role_map) {
  if (is.null(role_map)) return(list())
  mapping <- c(
    aware              = "funnel.awareness",
    consideration      = "funnel.attitude",
    bought_long        = "funnel.transactional.bought_long",
    bought_target      = "funnel.transactional.bought_target",
    preferred          = "funnel.transactional.frequency",
    current_owner_d    = "funnel.durable.current_owner",
    long_tenured_d     = "funnel.durable.tenure",
    current_customer_s = "funnel.service.current_customer",
    long_tenured_s     = "funnel.service.tenure"
  )
  out <- list()
  for (stage_key in names(mapping)) {
    role <- mapping[[stage_key]]
    if (!is.null(role_map[[role]])) out[[stage_key]] <- role_map[[role]]
  }
  out
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel output loaded (v%s)",
                  BRAND_FUNNEL_OUTPUT_VERSION))
}
