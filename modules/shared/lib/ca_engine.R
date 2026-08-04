# ==============================================================================
# SHARED CORRESPONDENCE ANALYSIS ENGINE - TURAS
# ==============================================================================
# Simple correspondence analysis of a two-way nonnegative matrix, plus a
# builder that assembles an entity x attribute association matrix from
# Turas-shaped multi-mention data (member columns Code_1..Code_N whose cells
# carry the option value when selected).
#
# VERSION HISTORY:
# v1.0 - Built for Electrum VAS 2026 channel x attribute maps (2026-07)
#
# WHAT IS IT?
# CA decomposes the chi-square structure of a frequency table into a small
# number of dimensions, so rows (entities: channels, brands) and columns
# (attributes) can be plotted together. Coordinates here are PRINCIPAL
# coordinates for both rows and columns (the symmetric map convention used
# in market research). Distances between two rows, or between two columns,
# are meaningful; row-to-column proximity is directional, not metric - say
# so in any commentary.
#
# BASE CHOICE (the analyst's decision, not the engine's):
# - a raw count matrix (all respondents) is a true contingency table;
# - an %-of-aware matrix corrects for awareness but is no longer a
#   contingency table - the map is then a profile comparison. Both are
#   accepted; the caller states which was used.
#
# DEPENDENCIES: None (base R only)
# ==============================================================================

CA_ENGINE_VERSION <- "1.0"


#' Run a simple correspondence analysis
#'
#' @param freq_matrix A numeric matrix, rows = entities, columns = attributes,
#'   nonnegative, with dimnames. Counts or percentages (see file header).
#' @param n_dimensions How many dimensions to return (default 2).
#'
#' @return A list with structure:
#'   \item{status}{"PASS", "PARTIAL" (zero rows/columns dropped) or "REFUSED"}
#'   \item{row_coords}{matrix of principal coordinates, one row per entity}
#'   \item{col_coords}{matrix of principal coordinates, one row per attribute}
#'   \item{explained}{proportion of inertia per returned dimension}
#'   \item{singular_values}{all singular values}
#'   \item{total_inertia}{sum of squared singular values}
#'   \item{dropped}{character vector of zero rows/columns removed}
#'   \item{warnings}{character vector (PARTIAL only)}
#'
#' @examples
#' \dontrun{
#'   result <- run_correspondence_analysis(channel_by_attribute_counts)
#'   if (result$status != "REFUSED") plot(result$row_coords)
#' }
#'
#' @export
run_correspondence_analysis <- function(freq_matrix, n_dimensions = 2) {
  checked <- .ca_check_matrix(freq_matrix)
  if (checked$status == "REFUSED") {
    return(checked)
  }
  m <- checked$matrix

  p <- m / sum(m)
  row_mass <- rowSums(p)
  col_mass <- colSums(p)
  standardised <- diag(1 / sqrt(row_mass)) %*%
    (p - outer(row_mass, col_mass)) %*% diag(1 / sqrt(col_mass))
  decomposition <- svd(standardised)

  available <- sum(decomposition$d > 1e-12)
  if (available < 1) {
    return(list(
      status = "REFUSED", code = "CALC_CA_DEGENERATE",
      message = "The matrix has no association structure to decompose (all profiles are identical).",
      how_to_fix = "Check that the matrix holds real association counts, not a constant."
    ))
  }
  dims <- seq_len(min(n_dimensions, available))

  row_coords <- diag(1 / sqrt(row_mass)) %*%
    decomposition$u[, dims, drop = FALSE] %*%
    diag(decomposition$d[dims], nrow = length(dims))
  col_coords <- diag(1 / sqrt(col_mass)) %*%
    decomposition$v[, dims, drop = FALSE] %*%
    diag(decomposition$d[dims], nrow = length(dims))
  dimnames(row_coords) <- list(rownames(m), paste0("Dim", dims))
  dimnames(col_coords) <- list(colnames(m), paste0("Dim", dims))

  inertia <- decomposition$d^2
  result <- list(
    status = if (length(checked$dropped)) "PARTIAL" else "PASS",
    row_coords = row_coords,
    col_coords = col_coords,
    explained = inertia[dims] / sum(inertia),
    singular_values = decomposition$d[seq_len(available)],
    total_inertia = sum(inertia),
    row_mass = row_mass,
    col_mass = col_mass,
    dropped = checked$dropped,
    warnings = if (length(checked$dropped)) {
      sprintf("Dropped all-zero rows/columns: %s", paste(checked$dropped, collapse = ", "))
    } else {
      character(0)
    }
  )
  return(result)
}


#' Validate and clean the input matrix (internal)
#'
#' Drops all-zero rows and columns (they have no profile and break the
#' decomposition), and refuses anything CA cannot use.
#'
#' @param freq_matrix The matrix as given.
#'
#' @return A list: status ("PASS"/"REFUSED"), matrix, dropped.
.ca_check_matrix <- function(freq_matrix) {
  if (!is.matrix(freq_matrix) || !is.numeric(freq_matrix)) {
    return(list(
      status = "REFUSED", code = "DATA_CA_NOT_MATRIX",
      message = "Correspondence analysis needs a numeric matrix.",
      how_to_fix = "Pass a numeric matrix with entity rownames and attribute colnames."
    ))
  }
  if (nrow(freq_matrix) < 2 || ncol(freq_matrix) < 2) {
    # checked before dimnames: an all-rows-dropped matrix (e.g. every entity
    # failed a base gate) arrives 0 x k with NULL rownames, and the useful
    # message is "too small", not "unlabelled"
    return(list(
      status = "REFUSED", code = "DATA_CA_TOO_SMALL",
      message = sprintf("The matrix is %d x %d; CA needs at least 2 x 2. If a base gate ran before this, it may have dropped every entity.",
                        nrow(freq_matrix), ncol(freq_matrix)),
      how_to_fix = "Provide more entities/attributes, or lower the base gate once real sample has accumulated."
    ))
  }
  if (is.null(rownames(freq_matrix)) || is.null(colnames(freq_matrix))) {
    return(list(
      status = "REFUSED", code = "DATA_CA_NO_DIMNAMES",
      message = "The matrix has no row or column names, so the map would be unlabelled.",
      how_to_fix = "Set rownames (entities) and colnames (attributes) before calling."
    ))
  }
  if (anyNA(freq_matrix) || any(freq_matrix < 0)) {
    return(list(
      status = "REFUSED", code = "DATA_CA_INVALID_VALUES",
      message = "The matrix contains missing or negative values.",
      how_to_fix = "Association counts and percentages are nonnegative; check the matrix build."
    ))
  }
  dropped <- c(rownames(freq_matrix)[rowSums(freq_matrix) == 0],
               colnames(freq_matrix)[colSums(freq_matrix) == 0])
  m <- freq_matrix[rowSums(freq_matrix) > 0, colSums(freq_matrix) > 0, drop = FALSE]
  if (nrow(m) < 2 || ncol(m) < 2) {
    return(list(
      status = "REFUSED", code = "DATA_CA_TOO_SMALL",
      message = sprintf("After dropping empty rows/columns the matrix is %d x %d; CA needs at least 2 x 2.",
                        nrow(m), ncol(m)),
      how_to_fix = "Provide more entities/attributes, or check why the matrix is empty."
    ))
  }
  return(list(status = "PASS", matrix = m, dropped = dropped))
}


#' Build an entity x attribute association matrix from Turas-shaped data
#'
#' Multi-mention questions in a Turas dataset arrive as member columns
#' Code_1..Code_N whose cells carry the option VALUE when selected. The
#' Options table (QuestionCode per member, OptionText = value) says which
#' member column carries which entity - so attribute batteries whose option
#' lists differ in order or length are aligned by VALUE, never by position.
#'
#' @param data The respondent-level data frame.
#' @param options A data frame with columns QuestionCode and OptionText
#'   covering the member codes (the generated Survey_Structure Options sheet).
#' @param attribute_questions A named character vector: display label ->
#'   question root code, e.g. c(Safe = "AttrSafe", Fast = "AttrFast").
#' @param entity_values Character vector of option values to include as rows,
#'   in display order. Leave "None of these" / "Other" out to exclude them.
#' @param base_by_entity Optional named list: entity value -> logical vector
#'   (one element per respondent) defining that entity's base, e.g. awareness.
#'   NULL means all respondents count for every entity.
#' @param as_percent_of_base Divide each cell by its entity's base size and
#'   scale to 100 (required for unequal bases to be comparable).
#'
#' @return A list with structure:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{matrix}{entities x attributes, counts or percentages}
#'   \item{base_n}{named vector: the base size behind each entity row}
#'
#' @export
build_association_matrix <- function(data, options, attribute_questions,
                                     entity_values, base_by_entity = NULL,
                                     as_percent_of_base = FALSE) {
  if (is.null(names(attribute_questions)) || any(!nzchar(names(attribute_questions)))) {
    return(list(
      status = "REFUSED", code = "CFG_CA_UNNAMED_ATTRIBUTES",
      message = "attribute_questions must be a named vector: display label -> question code.",
      how_to_fix = 'Pass e.g. c(Safe = "AttrSafe", Fast = "AttrFast").'
    ))
  }
  base_size <- function(value) {
    if (is.null(base_by_entity)) nrow(data) else sum(base_by_entity[[value]], na.rm = TRUE)
  }

  m <- matrix(0, nrow = length(entity_values), ncol = length(attribute_questions),
              dimnames = list(entity_values, names(attribute_questions)))
  for (attribute in names(attribute_questions)) {
    question <- attribute_questions[[attribute]]
    members <- options[grepl(sprintf("^%s_[0-9]+$", question), options$QuestionCode), ]
    for (value in entity_values) {
      member_code <- members$QuestionCode[members$OptionText == value]
      if (length(member_code) != 1L || !member_code %in% names(data)) {
        next  # this battery does not offer this entity; the cell stays 0
      }
      selected <- !is.na(data[[member_code]]) & nzchar(trimws(data[[member_code]]))
      if (!is.null(base_by_entity)) {
        selected <- selected & base_by_entity[[value]]
      }
      m[value, attribute] <- sum(selected, na.rm = TRUE)
    }
  }

  base_n <- vapply(entity_values, base_size, numeric(1))
  if (as_percent_of_base) {
    safe_base <- ifelse(base_n > 0, base_n, NA_real_)
    m <- sweep(m, 1, safe_base, "/") * 100
    m[is.na(m)] <- 0
  }
  return(list(status = "PASS", matrix = m, base_n = base_n))
}


#' Resolve a declarative segment definition to respondent rows
#'
#' A segment is defined against one column of the dataset: either a set of
#' categorical values (\code{values}) or a numeric range (\code{min} /
#' \code{max}). Respondents with a missing answer on the segmenting question
#' are in no segment.
#'
#' @param data The respondent-level data frame.
#' @param definition A list: \code{question} plus \code{values}, or
#'   \code{min} and/or \code{max}.
#'
#' @return A list with structure:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{rows}{logical vector, one element per respondent}
#'
#' @examples
#' \dontrun{
#'   segment_rows(data, list(question = "IncomeBand",
#'                           values = c("Less than R3,500", "R3,500 to R7,999")))
#'   segment_rows(data, list(question = "CategoriesPurchased", min = 8))
#' }
#'
#' @export
segment_rows <- function(data, definition) {
  question <- definition$question
  if (is.null(question) || !nzchar(question)) {
    return(list(
      status = "REFUSED", code = "CFG_CA_SEGMENT_NO_QUESTION",
      message = "The segment definition names no question.",
      how_to_fix = 'Give it one, e.g. list(question = "IncomeBand", values = c(...)).'
    ))
  }
  if (!question %in% names(data)) {
    return(list(
      status = "REFUSED", code = "DATA_CA_SEGMENT_COLUMN_ABSENT",
      message = sprintf("Segment question '%s' is not a column of the dataset.", question),
      how_to_fix = "Check the spelling against the dataset's column names."
    ))
  }
  if (!is.null(definition$values)) {
    return(list(status = "PASS",
                rows = !is.na(data[[question]]) & data[[question]] %in% definition$values))
  }
  if (!is.null(definition$min) || !is.null(definition$max)) {
    numeric_values <- suppressWarnings(as.numeric(data[[question]]))
    lower <- if (is.null(definition$min)) -Inf else definition$min
    upper <- if (is.null(definition$max)) Inf else definition$max
    return(list(status = "PASS",
                rows = !is.na(numeric_values) &
                  numeric_values >= lower & numeric_values <= upper))
  }
  return(list(
    status = "REFUSED", code = "CFG_CA_SEGMENT_EMPTY",
    message = sprintf("Segment on '%s' has neither values nor a min/max range.", question),
    how_to_fix = "Add values = c(...) for a categorical cut, or min/max for a numeric one."
  ))
}

#' Stack per-segment matrices into one comparable space
#'
#' Each entity appears once per segment ("Bank app | Lower income"), so one
#' CA run places all segment profiles on the SAME axes and positions are
#' directly comparable - which independent per-segment maps are not, because
#' each of those computes its own axes.
#'
#' @param matrix_results A named list (segment label -> the gated result of
#'   \code{build_association_matrix()}).
#' @param separator Text between entity and segment in the stacked rownames.
#'
#' @return A single result list in the same shape (\code{matrix},
#'   \code{base_n}, \code{excluded}).
#'
#' @export
stack_segment_matrices <- function(matrix_results, separator = " | ") {
  pieces <- lapply(names(matrix_results), function(label) {
    m <- matrix_results[[label]]$matrix
    rownames(m) <- paste0(rownames(m), separator, label)
    m
  })
  bases <- lapply(names(matrix_results), function(label) {
    base_n <- matrix_results[[label]]$base_n
    names(base_n) <- paste0(names(base_n), separator, label)
    base_n
  })
  return(list(matrix = do.call(rbind, pieces),
              base_n = do.call(c, bases),
              excluded = unname(unlist(lapply(matrix_results, function(r) r$excluded)))))
}

#' Drop entities whose base is too small to plot honestly
#'
#' @param matrix_result The list from \code{build_association_matrix()}.
#' @param min_base Smallest acceptable base per entity row.
#'
#' @return The same list, with \code{matrix} and \code{base_n} filtered and
#'   \code{excluded} naming what was dropped and why.
#'
#' @export
apply_base_gate <- function(matrix_result, min_base = 30) {
  keep <- matrix_result$base_n >= min_base
  excluded <- sprintf("%s (base %d < %d)",
                      names(matrix_result$base_n)[!keep],
                      matrix_result$base_n[!keep], min_base)
  matrix_result$matrix <- matrix_result$matrix[keep, , drop = FALSE]
  matrix_result$base_n <- matrix_result$base_n[keep]
  matrix_result$excluded <- excluded
  return(matrix_result)
}
