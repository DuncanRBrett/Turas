# ==============================================================================
# BRAND MODULE — ROLE MAP V2 (CONVENTION-FIRST + OPTIONAL OVERRIDE)
# ==============================================================================
# New public entry for the rebuild. Infers role entries from question codes
# (00_role_inference.R) and optionally merges per-role overrides from an
# optional Survey_Structure 'QuestionMap' sheet.
#
# Coexists with the legacy 00_role_map.R during migration. Elements that have
# migrated to the new shape call build_brand_role_map(); elements still on
# the legacy path call load_role_map(). The legacy file is deleted at cutover.
#
# Returned entries follow the shape declared in 00_role_inference.R.
#
# VERSION: 2.0
# ==============================================================================

BRAND_ROLE_MAP_V2_VERSION <- "2.0"


# ==============================================================================
# PUBLIC ENTRY
# ==============================================================================

#' Build the brand role map (convention-first + override)
#'
#' @param structure List from a Survey_Structure loader. Must contain:
#'   - questions: data frame (Questions sheet)
#'   - brands:    data frame (Brands sheet) or NULL
#'   - questionmap: data frame (QuestionMap sheet) or NULL — optional override
#' @param brand_config List from Brand_Config loader. Must contain:
#'   - categories: data frame with CategoryCode + Active columns
#' @param data Optional. Data frame of respondent data. When supplied, the
#'   resolver populates the \code{columns} field of each entry with concrete
#'   data column names (slot columns for Multi_Mention roots, the per-brand
#'   column for per_brand entries). Without \code{data}, columns is left NULL
#'   (caller can resolve later).
#' @return Named list of role entries.
#' @export
build_brand_role_map <- function(structure, brand_config, data = NULL) {
  if (!isTRUE(.require_structure(structure))) return(list())
  questions <- structure$questions
  brands    <- structure$brands
  questionmap <- structure$questionmap  # may be NULL

  active_cats <- .active_categories(brand_config)

  # Step 1: convention-first inference
  role_map <- infer_role_map(questions, brands, active_cats)

  # Step 2: apply QuestionMap overrides (optional)
  if (!is.null(questionmap) && nrow(questionmap) > 0L) {
    role_map <- .apply_questionmap_overrides(role_map, questionmap, structure)
  }

  # Step 3: resolve columns against data (optional)
  if (!is.null(data)) {
    role_map <- .resolve_columns(role_map, data)
  }

  role_map
}

#' Resolve columns against data for a built role map
#'
#' Useful when the role map was built without data and is later applied to a
#' specific data frame. Mutates each entry's columns field in place.
#' @export
resolve_role_columns <- function(role_map, data) {
  .resolve_columns(role_map, data)
}


# ==============================================================================
# INTERNAL
# ==============================================================================

.active_categories <- function(brand_config) {
  if (is.null(brand_config) || is.null(brand_config$categories)) {
    return(character(0))
  }
  cats <- brand_config$categories
  if (!"Active" %in% names(cats)) return(as.character(cats$CategoryCode))
  as.character(cats$CategoryCode[
    !is.na(cats$Active) & toupper(cats$Active) == "Y"
  ])
}

.require_structure <- function(structure) {
  if (is.null(structure)) {
    cat("\n[REFUSED: DATA_MISSING] build_brand_role_map: structure is NULL\n",
        "  Fix: Pass a valid structure list from load_brand_survey_structure()\n",
        sep = "")
    return(FALSE)
  }
  if (is.null(structure$questions)) {
    cat("\n[REFUSED: DATA_MISSING] build_brand_role_map: structure$questions missing\n",
        "  Fix: Ensure Survey_Structure.xlsx has a Questions sheet\n",
        sep = "")
    return(FALSE)
  }
  TRUE
}

#' Apply QuestionMap override rows to an inferred role map
#'
#' Each QuestionMap row carries: Role, ColumnRoot or ColumnPattern,
#' Variable_Type, OptionMapScale (optional), Notes (optional). The Role
#' must match an existing inferred role (override) or be a new role
#' the convention couldn't infer (insert).
#'
#' @keywords internal
.apply_questionmap_overrides <- function(role_map, qm, structure) {
  for (i in seq_len(nrow(qm))) {
    row <- qm[i, , drop = FALSE]
    role <- .nz_str(row$Role)
    if (is.na(role) || role == "") next  # skip blank rows

    existing <- role_map[[role]]
    # ColumnRoot is the canonical name; ClientCode is what the template uses —
    # accept either so the standard QuestionMap template works without renaming.
    column_root <- .nz_str(row$ColumnRoot %||% row$ColumnPattern %||% row$ClientCode)
    variable_type <- .nz_str(row$Variable_Type)
    option_scale  <- .nz_str(row$OptionMapScale)

    if (is.null(existing)) {
      # New role — minimal entry
      role_map[[role]] <- list(
        role = role, category = NA_character_,
        client_code = column_root, variable_type = variable_type,
        column_root = column_root, per_brand = FALSE,
        columns = NULL, applicable_brands = NULL,
        question_text = NA_character_, option_scale = option_scale,
        option_map = NULL, notes = "QuestionMap insert",
        detail = list()
      )
    } else {
      # Existing role — selectively override fields
      if (!is.na(column_root) && column_root != "") {
        existing$column_root <- column_root
      }
      if (!is.na(variable_type) && variable_type != "") {
        existing$variable_type <- variable_type
      }
      if (!is.na(option_scale) && option_scale != "") {
        existing$option_scale <- option_scale
      }
      existing$notes <- paste(existing$notes, "| QuestionMap override")
      role_map[[role]] <- existing
    }
  }
  role_map
}

#' Populate columns field on every entry against actual data column names
#'
#' For Multi_Mention roots: finds slot columns matching ^{root}_[0-9]+$.
#' For per_brand entries: keeps the existing single column name (set during
#' inference) but verifies it exists.
#' For per_category / system: ditto.
#'
#' @keywords internal
.resolve_columns <- function(role_map, data) {
  data_names <- names(data)
  for (role in names(role_map)) {
    e <- role_map[[role]]
    if (isTRUE(e$per_brand)) {
      # Compound per-brand entry: resolve to a NAMED character vector,
      # one entry per applicable_brand whose column exists.
      brands <- as.character(e$applicable_brands %||% character(0))
      cols <- setNames(character(0), character(0))
      for (b in brands) {
        col <- paste0(e$column_root, "_", b)
        if (col %in% data_names) cols[b] <- col
      }
      e$columns <- cols
    } else if (e$variable_type == "Multi_Mention") {
      pat <- paste0("^", .regex_escape(e$column_root), "_[0-9]+$")
      slots <- grep(pat, data_names, value = TRUE)
      idx   <- as.integer(sub(paste0("^", .regex_escape(e$column_root), "_"),
                              "", slots))
      e$columns <- slots[order(idx)]
    } else {
      e$columns <- if (e$column_root %in% data_names) e$column_root
                   else character(0)
    }
    role_map[[role]] <- e
  }
  role_map
}

.regex_escape <- function(s) {
  gsub("([\\.\\+\\*\\?\\(\\)\\[\\]\\{\\}\\|\\^\\$])", "\\\\\\1", s, perl = TRUE)
}

.nz_str <- function(x) {
  if (is.null(x)) return(NA_character_)
  v <- as.character(x)
  if (length(v) == 0L) return(NA_character_)
  v <- v[1]
  if (is.na(v) || nchar(trimws(v)) == 0L) NA_character_ else trimws(v)
}

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
