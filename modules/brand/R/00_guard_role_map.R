# ==============================================================================
# BRAND MODULE - ROLE-REGISTRY GUARD LAYER (ROLE_REGISTRY.md §12)
# ==============================================================================
# Validates a role map against the survey data. Every refusal code here is
# listed in §12 of the role registry and tested in test_guard_role_registry.R.
#
# The guard layer runs AFTER load_role_map() has resolved every row's
# ColumnPattern. It does not re-resolve patterns; its job is to check that
# the resolved columns exist in the data, that OptionMap scales are
# populated, and that respondent-level invariants hold.
#
# DEPENDENCIES:
# - modules/brand/R/00_guard.R (brand_refuse + brand_with_refusal_handler)
# - modules/brand/R/00_role_map.R (load_role_map feeds this layer)
#
# VERSION: 1.0
# ==============================================================================

BRAND_ROLE_GUARD_VERSION <- "1.0"



# ==============================================================================
# ROLE-REGISTRY GUARD LAYER (ROLE_REGISTRY.md §12)
# ==============================================================================
# Validates a role map against the survey data. Every refusal code here is
# listed in §12 of the role registry and tested in test_guard_role_registry.R.
#
# The guard layer runs AFTER load_role_map() has resolved every row's
# ColumnPattern. It does not re-resolve patterns; its job is to check that
# the resolved columns exist in the data, that OptionMap scales are
# populated, and that respondent-level invariants hold.
# ==============================================================================

#' Validate a role map against the survey data
#'
#' Enforces every rule in ROLE_REGISTRY §12:
#' \enumerate{
#'   \item Every required role has a QuestionMap entry with matching columns.
#'   \item Declared ColumnPatterns resolve to columns that exist in the data.
#'   \item OptionMap scales for Single_Response / Likert / Rating / NPS roles
#'     are populated.
#'   \item \code{system.respondent.id} values are unique per row when present.
#'   \item \code{system.respondent.weight} values are numeric, non-negative,
#'     non-zero-sum when present.
#'   \item Per-brand data columns are consistent with the declared brand list
#'     (warns on orphan columns that point at brands not in the brand list).
#' }
#'
#' @param role_map Named list from \code{load_role_map()}.
#' @param required_roles Character vector of roles whose absence is a refusal.
#' @param data Data frame of survey responses. Required.
#' @param brand_list Data frame with a BrandCode column, or NULL.
#'
#' @return List. Either \code{list(status = "PASS")} or
#'   \code{list(status = "PARTIAL", warnings = ...)} when orphan columns are
#'   detected. Refusals are thrown via the TRS refusal system.
#'
#' @export
guard_validate_role_map <- function(role_map,
                                    required_roles,
                                    data,
                                    brand_list = NULL) {

  .guard_require_data(data)
  .guard_require_required_roles_present(role_map, required_roles)

  warnings_list <- character(0)
  for (role_name in names(role_map)) {
    entry <- role_map[[role_name]]
    .guard_columns_exist(entry, data)
    .guard_option_scale(entry)
  }

  .guard_respondent_id(role_map, data)
  .guard_respondent_weight(role_map, data)

  orphan_warn <- .guard_brand_orphans(role_map, data, brand_list)
  if (length(orphan_warn) > 0) {
    warnings_list <- c(warnings_list, orphan_warn)
  }

  if (length(warnings_list) > 0) {
    return(list(status = "PARTIAL", warnings = warnings_list))
  }
  list(status = "PASS")
}


# ------------------------------------------------------------------------------
# Top-level argument checks
# ------------------------------------------------------------------------------

.guard_require_data <- function(data) {
  if (!is.null(data) && is.data.frame(data) && nrow(data) > 0) {
    return(invisible(TRUE))
  }
  brand_refuse(
    code = "DATA_EMPTY",
    title = "No Data for Role-Map Guard",
    problem = "Role-map guard requires a non-empty data frame.",
    why_it_matters = paste(
      "Columns cannot be checked against a NULL or zero-row data frame.",
      "The guard runs after data is loaded; an empty input indicates an",
      "upstream loader problem."
    ),
    how_to_fix = c(
      "Check the data loading step in run_brand().",
      "Verify the data file exists and has rows."
    )
  )
}


.guard_require_required_roles_present <- function(role_map, required_roles) {
  if (is.null(required_roles) || length(required_roles) == 0) {
    return(invisible(TRUE))
  }
  missing_roles <- setdiff(required_roles, names(role_map))
  if (length(missing_roles) == 0) return(invisible(TRUE))
  brand_refuse(
    code = "CFG_ROLE_MISSING",
    title = "Required Role(s) Missing from QuestionMap",
    problem = sprintf(
      "QuestionMap does not declare %d required role(s): %s.",
      length(missing_roles), paste(missing_roles, collapse = ", ")),
    why_it_matters = paste(
      "Required roles are ones the element cannot run without. A missing",
      "required role is always an operator configuration error, never a",
      "silent fall-through."
    ),
    how_to_fix = c(
      paste("Add one QuestionMap row per missing role:",
            paste(missing_roles, collapse = ", ")),
      "See modules/brand/docs/ROLE_REGISTRY.md for the role catalogue."
    ),
    missing = missing_roles
  )
}


# ------------------------------------------------------------------------------
# Per-role checks
# ------------------------------------------------------------------------------

.guard_columns_exist <- function(entry, data) {
  if (length(entry$columns) == 0) {
    brand_refuse(
      code = "CFG_PATTERN_MISMATCH",
      title = "ColumnPattern Resolved to No Columns",
      problem = sprintf(
        "Role '%s' (pattern '%s') resolved to zero columns.",
        entry$role, entry$column_pattern),
      why_it_matters = paste(
        "An empty resolution means the pattern's token sources (brands,",
        "CEPs, etc.) are empty or the pattern is self-inconsistent. Either",
        "way the element has no data to read."
      ),
      how_to_fix = c(
        "Check the Brands / CEPs lists in Survey_Structure.xlsx.",
        sprintf("Review the ColumnPattern for role '%s'.", entry$role)
      )
    )
  }
  missing_cols <- setdiff(entry$columns, names(data))
  if (length(missing_cols) == 0) return(invisible(TRUE))
  brand_refuse(
    code = "CFG_COLUMN_NOT_FOUND",
    title = "Declared Column Not Found in Data",
    problem = sprintf(
      "Role '%s' pattern '%s' resolved to %d column(s); %d missing from data.",
      entry$role, entry$column_pattern,
      length(entry$columns), length(missing_cols)),
    why_it_matters = paste(
      "The role map declared these columns should exist. Missing columns",
      "indicate a mismatch between the ColumnPattern and the actual data",
      "file. Silent substitution would mask a real data-integrity issue."
    ),
    how_to_fix = c(
      paste("Verify the column names in the data file match the pattern."),
      "Check that ClientCode in QuestionMap matches the data's column prefix.",
      "If the project uses a different naming convention, update ColumnPattern."
    ),
    expected = entry$columns,
    missing  = missing_cols
  )
}


.guard_option_scale <- function(entry) {
  scaled_types <- c("Single_Response", "Likert", "Rating", "NPS")
  if (!(entry$variable_type %in% scaled_types)) return(invisible(TRUE))
  scale_name <- entry$option_scale
  if (is.null(scale_name) || is.na(scale_name) || scale_name == "") {
    return(invisible(TRUE))
  }
  if (!is.null(entry$option_map) && nrow(entry$option_map) > 0) {
    return(invisible(TRUE))
  }
  brand_refuse(
    code = "CFG_OPTIONMAP_INCOMPLETE",
    title = "OptionMap Scale Not Populated",
    problem = sprintf(
      "Role '%s' declares OptionMapScale '%s' but that scale has no rows.",
      entry$role, scale_name),
    why_it_matters = paste(
      "Single_Response / Likert / Rating / NPS roles rely on the OptionMap",
      "to map code values to positional roles (e.g. attitude.love). Without",
      "those rows the element cannot interpret the codes."
    ),
    how_to_fix = c(
      sprintf("Add OptionMap rows for scale '%s'.", scale_name),
      "Each code value in the data should map to a positional role or be blank.",
      "See modules/brand/docs/ROLE_REGISTRY.md §11.2."
    ),
    missing = scale_name
  )
}


# ------------------------------------------------------------------------------
# Respondent-level invariants
# ------------------------------------------------------------------------------

.guard_respondent_id <- function(role_map, data) {
  id_entry <- role_map[["system.respondent.id"]]
  if (is.null(id_entry)) return(invisible(TRUE))
  id_col <- id_entry$columns[1]
  if (!(id_col %in% names(data))) return(invisible(TRUE))

  ids <- data[[id_col]]
  dup_count <- sum(duplicated(ids))
  if (dup_count == 0) return(invisible(TRUE))
  brand_refuse(
    code = "DATA_RESPONDENT_ID_DUPLICATE",
    title = "Respondent IDs Are Not Unique",
    problem = sprintf(
      "Column '%s' has %d duplicated respondent ID value(s).",
      id_col, dup_count),
    why_it_matters = paste(
      "The module assumes one row per respondent. Duplicated IDs imply",
      "either a long-format export or a join bug, both of which would",
      "corrupt every downstream calculation."
    ),
    how_to_fix = c(
      "Deduplicate rows before analysis.",
      "Check the export settings in the survey platform (should be one row per respondent).",
      "If panel data, verify wave-specific IDs are being used."
    )
  )
}


.guard_respondent_weight <- function(role_map, data) {
  w_entry <- role_map[["system.respondent.weight"]]
  if (is.null(w_entry)) return(invisible(TRUE))
  w_col <- w_entry$columns[1]
  if (!(w_col %in% names(data))) return(invisible(TRUE))

  w <- suppressWarnings(as.numeric(data[[w_col]]))
  if (all(is.na(w))) {
    brand_refuse(
      code = "DATA_WEIGHT_NON_NUMERIC",
      title = "Weight Column Is Not Numeric",
      problem = sprintf("Column '%s' does not coerce to numeric.", w_col),
      why_it_matters = paste(
        "Weights must be numeric and non-negative; non-numeric weights",
        "produce arbitrary weighted results."
      ),
      how_to_fix = sprintf(
        "Fix the '%s' column in the data file (expected numeric values).",
        w_col)
    )
  }
  if (any(w < 0, na.rm = TRUE)) {
    brand_refuse(
      code = "DATA_WEIGHT_NEGATIVE",
      title = "Weights Contain Negative Values",
      problem = sprintf(
        "Column '%s' contains %d negative value(s).",
        w_col, sum(w < 0, na.rm = TRUE)),
      why_it_matters = paste(
        "Negative weights are undefined for proportion estimation; they",
        "would produce nonsensical or divergent weighted statistics."
      ),
      how_to_fix = "Fix the weight column so all values are non-negative."
    )
  }
  if (sum(w, na.rm = TRUE) <= 0) {
    brand_refuse(
      code = "DATA_WEIGHT_ZERO_SUM",
      title = "Weights Sum to Zero",
      problem = sprintf(
        "Column '%s' sums to %.3f.", w_col, sum(w, na.rm = TRUE)),
      why_it_matters = paste(
        "Zero-sum weights make every weighted average undefined (division",
        "by zero). The guard refuses rather than produce silent NaNs."
      ),
      how_to_fix = "Inspect the weight derivation; at least some rows must have non-zero weight."
    )
  }
  invisible(TRUE)
}


# ------------------------------------------------------------------------------
# Brand orphan warning
# ------------------------------------------------------------------------------

.guard_brand_orphans <- function(role_map, data, brand_list) {
  if (is.null(brand_list) || !("BrandCode" %in% names(brand_list))) {
    return(character(0))
  }
  declared_brands <- as.character(brand_list$BrandCode)

  suspect_pats <- c("{brand_code}", "{brandcode}")
  per_brand_entries <- Filter(function(e) {
    any(vapply(suspect_pats, function(p)
      grepl(p, e$column_pattern, fixed = TRUE), logical(1)))
  }, role_map)

  warns <- character(0)
  for (entry in per_brand_entries) {
    resolved_brand_cols <- entry$columns
    if (!is.na(entry$client_code) && nzchar(entry$client_code)) {
      suffix_regex <- sprintf(
        "^%s_(.+)$", gsub("([.\\\\^$*+?()\\[\\]|])", "\\\\\\1",
                          entry$client_code))
      candidates <- grep(suffix_regex, names(data), value = TRUE)
      if (length(candidates) == 0) next
      suffixes <- sub(suffix_regex, "\\1", candidates)
      first_parts <- sapply(strsplit(suffixes, "_", fixed = TRUE),
                            function(x) x[1])
      orphan_brands <- setdiff(unique(first_parts), declared_brands)
      if (length(orphan_brands) > 0) {
        warns <- c(warns, sprintf(
          paste("Data contains columns for brand code(s) '%s' under pattern",
                "'%s' that are not in the declared Brands list. These",
                "columns will be ignored."),
          paste(orphan_brands, collapse = ", "), entry$column_pattern))
      }
    }
  }
  warns
}

# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand role-registry guard loaded (v%s)",
                  BRAND_ROLE_GUARD_VERSION))
}
