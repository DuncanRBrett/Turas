# ==============================================================================
# TurasTracker - Aggregate Wave Values Loader
# ==============================================================================
#
# Loads a long-format "values table" of published aggregates so that historical
# waves — which survive only as summary figures, not respondent-level microdata —
# can be tracked alongside recent data waves.
#
# ONE ROW PER NUMBER. Columns:
#   metric_id    (required) stable metric key == the tracker question code
#   wave         (required) wave identifier; alias 'year'. Matched to Waves WaveID
#   metric_type  (required) one of: mean | proportion | nps
#   value        (required) the published figure, as reported (%, mean, NPS net)
#   base         (optional) effective base n for that metric that wave; blank = unknown
#   sd           (optional) dispersion for 'mean' metrics; blank = not recorded
# Any other columns (section, question, source, ...) are ignored.
#
# HONEST-BY-CONSTRUCTION: this loader only reads and validates. It NEVER invents
# a base or an sd. Downstream, a proportion needs value+base, a mean needs
# value+sd+base; where base/sd are blank the comparison is reported as "no test"
# rather than a fabricated result.
#
# SOURCED BY: run_tracker.R (after wave_loader.R). Uses tracker_refuse (00_guard.R).
# ==============================================================================

# Values-table metric vocabulary (kept deliberately small; mapped to the tracker
# canonical types at the point of use). "proportions" is accepted as an alias.
AGGREGATE_VALUE_METRIC_TYPES <- c("mean", "proportion", "nps")


#' Load Aggregate Values Table
#'
#' Reads and validates a long-format aggregate values table for aggregate-wave
#' ingest. Faithful: it does not alter, impute, or invent any figure.
#'
#' @param file_path Character. Path to the values table (.csv or .xlsx).
#' @return A list with structure:
#'   \item{status}{"PASS"}
#'   \item{values}{Data frame: metric_id, wave, metric_type, value, base, sd}
#'   \item{index}{Named list keyed by "metric_id||wave" for O(1) lookup}
#'   \item{n_rows, n_metrics, n_waves}{Counts}
#'   \item{warnings}{Character vector of non-fatal range warnings}
#'   (Throws a turas_refusal condition on any fatal problem.)
#' @export
load_aggregate_values <- function(file_path) {

  if (is.null(file_path) || length(file_path) != 1 || is.na(file_path) ||
      !nzchar(trimws(as.character(file_path)))) {
    tracker_refuse(
      code = "IO_AGGREGATE_FILE_MISSING",
      title = "No Aggregate Values File Specified",
      problem = "load_aggregate_values() was called without a file path.",
      why_it_matters = "An aggregate wave has no respondent data; its values table is the only source of figures.",
      how_to_fix = "Provide the AggregateFile path for the aggregate wave in the Waves sheet."
    )
  }
  file_path <- trimws(as.character(file_path))

  if (!file.exists(file_path)) {
    tracker_refuse(
      code = "IO_AGGREGATE_FILE_NOT_FOUND",
      title = "Aggregate Values File Not Found",
      problem = paste0("Cannot find aggregate values file: ", basename(file_path)),
      why_it_matters = "Cannot load historical aggregate figures without the values table.",
      how_to_fix = c("Check the AggregateFile path in the Waves sheet",
                     "Verify the file exists at the specified location"),
      details = paste0("Expected path: ", file_path)
    )
  }

  ext <- tolower(tools::file_ext(file_path))
  if (!ext %in% c("csv", "xlsx", "xls")) {
    tracker_refuse(
      code = "IO_AGGREGATE_UNSUPPORTED_FORMAT",
      title = "Unsupported Aggregate Values Format",
      problem = paste0("File format '", ext, "' is not supported for the aggregate values table."),
      why_it_matters = "Only CSV and Excel values tables can be read.",
      how_to_fix = "Save the values table as .csv or .xlsx.",
      details = paste0("File path: ", file_path)
    )
  }

  df <- tryCatch({
    if (ext == "csv") {
      read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    } else {
      openxlsx::read.xlsx(file_path, sheet = 1, check.names = FALSE)
    }
  }, error = function(e) {
    tracker_refuse(
      code = "IO_AGGREGATE_READ_FAILED",
      title = "Failed to Read Aggregate Values File",
      problem = paste0("Error reading aggregate values file: ", basename(file_path)),
      why_it_matters = "Cannot load historical figures without successfully reading the file.",
      how_to_fix = c("Check the file is valid and not open in another application",
                     "Verify it is a readable CSV or Excel file"),
      details = conditionMessage(e)
    )
  })

  if (is.null(df) || nrow(df) == 0) {
    tracker_refuse(
      code = "DATA_AGGREGATE_EMPTY",
      title = "Empty Aggregate Values Table",
      problem = paste0("The aggregate values file contains no rows: ", basename(file_path)),
      why_it_matters = "There are no figures to load for the aggregate wave(s).",
      how_to_fix = "Populate the values table with one row per (metric, wave)."
    )
  }

  # --- Resolve columns case-insensitively; 'year' is an alias for 'wave' ---
  names(df) <- trimws(names(df))
  lower <- tolower(names(df))
  # A list (not a named vector) so unmapped columns return NULL instead of
  # erroring — the values table carries extra descriptive columns we ignore.
  alias <- list(metric_id = "metric_id", wave = "wave", year = "wave",
                metric_type = "metric_type", value = "value", base = "base", sd = "sd")
  colmap <- list()
  for (i in seq_along(lower)) {
    canon <- alias[[lower[i]]]
    if (!is.null(canon) && is.null(colmap[[canon]])) colmap[[canon]] <- names(df)[i]
  }

  required <- c("metric_id", "wave", "metric_type", "value")
  missing_req <- setdiff(required, names(colmap))
  if (length(missing_req) > 0) {
    tracker_refuse(
      code = "CFG_AGGREGATE_MISSING_COLUMNS",
      title = "Aggregate Values Table Missing Columns",
      problem = paste0("The values table is missing required column(s): ",
                       paste(missing_req, collapse = ", ")),
      why_it_matters = "Each aggregate figure needs a metric, a wave, a type and a value to be tracked.",
      how_to_fix = "Add the missing column(s). Required: metric_id, wave (or year), metric_type, value. Optional: base, sd.",
      expected = required,
      observed = names(df)
    )
  }

  col <- function(canon) if (!is.null(colmap[[canon]])) df[[colmap[[canon]]]] else NA

  metric_id   <- trimws(as.character(col("metric_id")))
  wave        <- trimws(as.character(col("wave")))
  metric_type <- tolower(trimws(as.character(col("metric_type"))))
  metric_type[metric_type == "proportions"] <- "proportion"   # accept plural alias
  raw_value   <- as.character(col("value"))
  value       <- suppressWarnings(as.numeric(raw_value))

  # --- Fatal: blank metric_id / wave ---
  blank_key <- which(is.na(metric_id) | metric_id == "" | is.na(wave) | wave == "")
  if (length(blank_key) > 0) {
    tracker_refuse(
      code = "DATA_AGGREGATE_BLANK_KEY",
      title = "Aggregate Row Missing metric_id or wave",
      problem = paste0("Row(s) with a blank metric_id or wave: ", paste(head(blank_key, 10), collapse = ", ")),
      why_it_matters = "Every figure must be tied to a metric and a wave to be tracked.",
      how_to_fix = "Fill in metric_id and wave for every row."
    )
  }

  # --- Fatal: invalid metric_type ---
  bad_type <- setdiff(unique(metric_type), AGGREGATE_VALUE_METRIC_TYPES)
  if (length(bad_type) > 0) {
    tracker_refuse(
      code = "DATA_AGGREGATE_INVALID_METRIC_TYPE",
      title = "Invalid Aggregate metric_type",
      problem = paste0("Unrecognised metric_type value(s): ", paste(bad_type, collapse = ", ")),
      why_it_matters = "metric_type routes the figure to the correct significance test.",
      how_to_fix = paste0("Use one of: ", paste(AGGREGATE_VALUE_METRIC_TYPES, collapse = ", "),
                          " (or 'proportions')."),
      observed = bad_type
    )
  }

  # --- Fatal: non-numeric / blank value ---
  bad_value <- which(is.na(value))
  if (length(bad_value) > 0) {
    where <- paste0(metric_id[bad_value], "@", wave[bad_value])
    tracker_refuse(
      code = "DATA_AGGREGATE_NON_NUMERIC_VALUE",
      title = "Non-Numeric or Blank Aggregate Value",
      problem = paste0("value is not a number for: ", paste(head(where, 10), collapse = ", ")),
      why_it_matters = "A blank or text value cannot be plotted or tested. Missing figures should be absent rows, not blank values.",
      how_to_fix = "Ensure every row's value is numeric; delete rows that have no figure.",
      details = paste0("Offending count: ", length(bad_value))
    )
  }

  # --- Optional base / sd: numeric-or-blank, non-negative ---
  parse_optional_numeric <- function(canon, label) {
    if (is.null(colmap[[canon]])) return(rep(NA_real_, nrow(df)))
    raw <- as.character(df[[colmap[[canon]]]])
    num <- suppressWarnings(as.numeric(raw))
    bad <- which(is.na(num) & !is.na(raw) & trimws(raw) != "")
    if (length(bad) > 0) {
      tracker_refuse(
        code = "DATA_AGGREGATE_NON_NUMERIC_BASE",
        title = paste0("Non-Numeric Aggregate ", label),
        problem = paste0(label, " has non-numeric value(s) at: ",
                         paste(head(paste0(metric_id[bad], "@", wave[bad]), 10), collapse = ", ")),
        why_it_matters = paste0(label, " must be a number or blank; text cannot enter a significance test."),
        how_to_fix = paste0("Set ", label, " to a number, or leave it blank (blank = unknown, reported as no test).")
      )
    }
    neg <- which(!is.na(num) & num < 0)
    if (length(neg) > 0) {
      tracker_refuse(
        code = "DATA_AGGREGATE_NEGATIVE_BASE",
        title = paste0("Negative Aggregate ", label),
        problem = paste0(label, " is negative at: ",
                         paste(head(paste0(metric_id[neg], "@", wave[neg]), 10), collapse = ", ")),
        why_it_matters = paste0(label, " cannot be negative."),
        how_to_fix = paste0("Correct the ", label, " value(s).")
      )
    }
    num
  }
  base_v <- parse_optional_numeric("base", "base")
  sd_v   <- parse_optional_numeric("sd", "sd")

  # --- Fatal: duplicate (metric_id, wave) ---
  key <- paste(metric_id, wave, sep = "||")
  dup <- unique(key[duplicated(key)])
  if (length(dup) > 0) {
    tracker_refuse(
      code = "DATA_AGGREGATE_DUPLICATE_KEY",
      title = "Duplicate (metric_id, wave) in Values Table",
      problem = paste0("These metric/wave pairs appear more than once: ",
                       paste(head(gsub("\\|\\|", "@", dup), 10), collapse = ", ")),
      why_it_matters = "Each metric can hold only one figure per wave; duplicates make the value ambiguous.",
      how_to_fix = "Remove or merge the duplicate rows so every (metric_id, wave) is unique."
    )
  }

  out <- data.frame(
    metric_id = metric_id, wave = wave, metric_type = metric_type,
    value = value, base = base_v, sd = sd_v, stringsAsFactors = FALSE
  )

  # --- Non-fatal range warnings (console-visible per Shiny convention) ---
  warnings <- character(0)
  prop_oor <- which(out$metric_type == "proportion" & (out$value < 0 | out$value > 100))
  if (length(prop_oor) > 0) {
    warnings <- c(warnings, sprintf("%d proportion value(s) fall outside 0-100 (stored as-is): %s",
      length(prop_oor), paste(head(paste0(out$metric_id[prop_oor], "@", out$wave[prop_oor]), 5), collapse = ", ")))
  }
  nps_oor <- which(out$metric_type == "nps" & (out$value < -100 | out$value > 100))
  if (length(nps_oor) > 0) {
    warnings <- c(warnings, sprintf("%d NPS value(s) fall outside -100..100 (stored as-is): %s",
      length(nps_oor), paste(head(paste0(out$metric_id[nps_oor], "@", out$wave[nps_oor]), 5), collapse = ", ")))
  }
  for (w in warnings) cat("[TURAS WARNING] Aggregate values: ", w, "\n", sep = "")

  index <- stats::setNames(lapply(seq_len(nrow(out)), function(i) as.list(out[i, ])), key)

  cat(sprintf("  Loaded aggregate values: %d rows, %d metrics, %d waves\n",
              nrow(out), length(unique(out$metric_id)), length(unique(out$wave))))

  list(
    status = "PASS",
    values = out,
    index = index,
    n_rows = nrow(out),
    n_metrics = length(unique(out$metric_id)),
    n_waves = length(unique(out$wave)),
    warnings = warnings
  )
}


#' Look Up One Aggregate Metric Value
#'
#' @param store List. Result of load_aggregate_values().
#' @param metric_id Character. Metric key.
#' @param wave Character. Wave identifier.
#' @return Named list (metric_id, wave, metric_type, value, base, sd) or NULL if absent.
#' @export
get_aggregate_metric <- function(store, metric_id, wave) {
  if (is.null(store) || is.null(store$index)) return(NULL)
  store$index[[paste(trimws(as.character(metric_id)), trimws(as.character(wave)), sep = "||")]]
}
