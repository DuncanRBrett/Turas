# ==============================================================================
# TABS MODULE — QUALITATIVE WORKBOOK READER (pure classification + normalisation)
# ==============================================================================
#
# Turns one coded-comment worksheet into a structured qual question. The logic is
# PURE: it operates on an already-read sheet (a list of normalised character rows),
# so it is unit-testable without touching Excel. A thin openxlsx wrapper (separate
# file) reads the workbook and feeds normalised rows in.
#
# Design + the real-workbook quirks this absorbs are documented in
#   modules/tabs/docs/QUALITATIVE_TAB_BUILD_NOTES.md  (§A structural matrix, §B algo)
#
# Header rows FLOAT (detected by an ID anchor, never a fixed offset); columns are
# classified by name-regex + value-type sampling + position relative to the
# verbatim, never by absolute index. Stray theme/sentiment codes are quarantined
# (counted, never coerced, never silently dropped).
#
# Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_workbook_reader.R")
# ==============================================================================

# ---- Constants (single source of truth; see build notes §B) ------------------

QUAL_ID_PATTERN            <- "^(response\\s*)?id$"
QUAL_NOTEWORTHY_PATTERN    <- "noteworthy"
QUAL_VERBATIM_NAME_PATTERN <- "^(comment|comments|verbatim|response|feedback)$"
QUAL_SENTIMENT_NAME_PATTERN <- "^(overall\\s*sentiment|sentiment|theme)$"
QUAL_RATING_PATTERN        <- "rating"
QUAL_CONTENTS_PATTERN      <- "^contents$"

# Valence codes carried by theme cells and the overall-sentiment column.
QUAL_SENTIMENT_CODES <- c("1", "2", "3")
# Tokens that mean "missing" in a demographic cell (beyond blank).
QUAL_MISSING_TOKENS  <- c("", "-")

# Noteworthy-column codes (case-insensitive), graded into three tiers. Any non-blank
# value is at least "noteworthy" (tier 1) — so legacy marks like "y" still count — and
# an explicit single-letter code promotes it: "m" -> must-read (tier 2), "p" -> priority
# (tier 3, the "lead with in a presentation" comments). Word aliases kept for back-compat.
QUAL_PRIORITY_MARKERS <- c("p", "priority")
QUAL_MUSTREAD_MARKERS <- c("m", "must read", "must-read", "must", "must-read!", "critical")

# Verbatim-suppression markers (case-insensitive). "hide"/"hidden" in the noteworthy
# column withholds THIS comment's verbatim text from the report — it is counted in the
# theme distribution like any other, but its text never ships (the build-time twin of a
# reader who does not want a comment surfaced). A hide marker is NOT noteworthy: it
# forces tier 0, so it can never be mistaken for an editorial "feature this" mark. This
# is the one reserved exception to "any non-blank marker is at least noteworthy".
QUAL_HIDE_MARKERS <- c("hide", "hidden")

# A column is the overall-sentiment column only if at least this fraction of its
# rows are populated (sentiment is dense; themes are sparse).
QUAL_SENTIMENT_DENSITY_MIN <- 0.5
# The overall-sentiment column is almost entirely valid {1,2,3} codes — this guards
# against a mislabelled but mostly-text column being read as sentiment.
QUAL_SENTIMENT_PURITY_MIN <- 0.8
# A theme column may carry the odd quarantined stray, so it needs only a MAJORITY of
# valid codes; the positional guard (right of the verbatim) already excludes cuts.
QUAL_THEME_PURITY_MIN <- 0.5
# A Rating column is numeric; categorical "ratings" (e.g. "Excellent") stay cuts.
QUAL_RATING_NUMERIC_MIN <- 0.8

# ---- Small helpers -----------------------------------------------------------

#' Drop NA entries from a vector.
#' @param x A vector.
#' @return `x` without NA elements.
qual_drop_na <- function(x) x[!is.na(x)]

#' Normalise raw cell values to trimmed character, with "" for blank/NA.
#' @param x A vector of raw cell values (character, numeric, factor, ...).
#' @return A character vector, trimmed, NA/blank collapsed to "".
qual_norm_cells <- function(x) {
  out <- trimws(as.character(x))
  out[is.na(out)] <- ""
  out
}

#' Fraction of values that are non-blank (population density).
#' @param values A normalised character vector.
#' @return A number in [0, 1].
qual_density <- function(values) {
  if (!length(values)) return(0)
  mean(nzchar(values))
}

#' Fraction of NON-BLANK values that are valid sentiment codes {1,2,3}.
#' @param values A normalised character vector.
#' @return A number in [0, 1]; 0 when there are no non-blank values.
qual_code_purity <- function(values) {
  nonblank <- values[nzchar(values)]
  if (!length(nonblank)) return(0)
  mean(nonblank %in% QUAL_SENTIMENT_CODES)
}

#' Index of the first header column matching a pattern (case-insensitive).
#' @param header Normalised header cells.
#' @param pattern A regex.
#' @return The 1-based column index, or NA_integer_.
qual_first_match <- function(header, pattern) {
  hit <- which(grepl(pattern, header, ignore.case = TRUE))
  if (length(hit)) hit[[1]] else NA_integer_
}

# ---- Header + column-value access -------------------------------------------

#' Find the header row: the first row whose first cell is an ID anchor.
#'
#' Header rows float (a preamble of question text + a derivable summary block sits
#' above them), so we anchor on the `ID` / `Response ID` cell rather than offsetting.
#' @param rows A list of normalised character rows.
#' @return The 1-based header row index, or 0L when none exists (metadata sheet).
qual_find_header_row <- function(rows) {
  for (i in seq_along(rows)) {
    first <- if (length(rows[[i]]) >= 1) rows[[i]][[1]] else ""
    if (grepl(QUAL_ID_PATTERN, first, ignore.case = TRUE)) return(i)
  }
  0L
}

#' Normalised data-cell values for one column (rows below the header).
#' @param rows A list of normalised character rows.
#' @param header_row The header row index.
#' @param col The 1-based column index.
#' @return A character vector of that column's data cells ("" for blanks).
qual_column_values <- function(rows, header_row, col) {
  n <- length(rows)
  if (header_row >= n) return(character(0))
  vapply(seq.int(header_row + 1L, n), function(i) {
    r <- rows[[i]]
    if (length(r) >= col) r[[col]] else ""
  }, character(1))
}

# ---- Per-role column detection ----------------------------------------------

#' Detect the verbatim column: a name match wins; else the longest mean-length column.
#'
#' SACS labels the verbatim with the question text (no "Comment" header), so when no
#' name matches we fall back to the column whose non-blank cells are longest on average.
#' @param header Normalised header cells.
#' @param col_values List of normalised value vectors, one per column.
#' @param exclude Column indices to ignore (id, noteworthy).
#' @return The verbatim column index, or NA_integer_.
qual_detect_verbatim_col <- function(header, col_values, exclude) {
  candidates <- setdiff(seq_along(header), exclude)
  if (!length(candidates)) return(NA_integer_)
  named <- candidates[grepl(QUAL_VERBATIM_NAME_PATTERN, header[candidates], ignore.case = TRUE)]
  if (length(named)) return(named[[1]])
  mean_len <- vapply(candidates, function(c) {
    nb <- col_values[[c]][nzchar(col_values[[c]])]
    if (length(nb)) mean(nchar(nb)) else 0
  }, numeric(1))
  candidates[[which.max(mean_len)]]
}

#' Detect the overall-sentiment column: right of the verbatim, name-matched, dense, codes ⊆ {1,2,3}.
#'
#' Some workbooks mislabel it (e.g. SACAP NPS calls it "Theme"), so the name match is
#' necessary but not sufficient — density + code purity disambiguate it from a theme.
#' @return The sentiment column index, or NA_integer_.
qual_detect_sentiment_col <- function(header, col_values, verbatim_col, note_col) {
  if (is.na(verbatim_col)) return(NA_integer_)
  candidates <- which(grepl(QUAL_SENTIMENT_NAME_PATTERN, header, ignore.case = TRUE))
  candidates <- candidates[candidates > verbatim_col]
  if (!is.na(note_col)) candidates <- setdiff(candidates, note_col)
  for (c in candidates) {
    vals <- col_values[[c]]
    if (qual_density(vals) >= QUAL_SENTIMENT_DENSITY_MIN &&
        qual_code_purity(vals) >= QUAL_SENTIMENT_PURITY_MIN) {
      return(c)
    }
  }
  NA_integer_
}

#' Detect a NUMERIC rating column (named /rating/ with numeric values).
#'
#' Categorical "ratings" (e.g. SACAP "Excellent"/"Good") are not numeric and stay
#' demographic cuts; only a genuinely numeric Rating becomes the per-record number.
#' @return The rating column index, or NA_integer_.
qual_detect_rating_col <- function(header, col_values) {
  for (c in which(grepl(QUAL_RATING_PATTERN, header, ignore.case = TRUE))) {
    nb <- col_values[[c]][nzchar(col_values[[c]])]
    numeric_frac <- if (length(nb)) mean(!is.na(suppressWarnings(as.numeric(nb)))) else 0
    if (numeric_frac >= QUAL_RATING_NUMERIC_MIN) return(c)
  }
  NA_integer_
}

#' Theme columns: named columns right of the verbatim whose values are ⊆ {1,2,3}.
#' @param reserved Column indices already claimed (id/verbatim/noteworthy/sentiment/rating).
#' @return A list of `list(col, label)`.
qual_theme_columns <- function(header, col_values, verbatim_col, reserved) {
  if (is.na(verbatim_col)) return(list())
  out <- list()
  for (c in seq_along(header)) {
    if (c <= verbatim_col || c %in% reserved || !nzchar(header[[c]])) next
    vals <- col_values[[c]]
    if (any(nzchar(vals)) && qual_code_purity(vals) >= QUAL_THEME_PURITY_MIN) {
      out[[length(out) + 1L]] <- list(col = c, label = header[[c]])
    }
  }
  out
}

#' Demographic / cut columns: named columns strictly between the ID and the verbatim.
#' @param theme_cols Integer column indices already claimed as themes.
#' @return A list of `list(col, label)`.
qual_demo_columns <- function(header, verbatim_col, id_col, reserved, theme_cols) {
  if (is.na(verbatim_col)) return(list())
  lo <- if (is.na(id_col)) 0L else id_col
  out <- list()
  for (c in seq_along(header)) {
    if (c <= lo || c >= verbatim_col) next
    if (c %in% reserved || c %in% theme_cols || !nzchar(header[[c]])) next
    out[[length(out) + 1L]] <- list(col = c, label = header[[c]])
  }
  out
}

#' Classify every column of a sheet into roles.
#' @param header Normalised header cells.
#' @param rows A list of normalised character rows.
#' @param header_row The header row index.
#' @return A list with id, verbatim, noteworthy, sentiment, rating, themes, demos.
qual_classify_columns <- function(header, rows, header_row) {
  col_values <- lapply(seq_along(header), function(c) qual_column_values(rows, header_row, c))
  id_col   <- qual_first_match(header, QUAL_ID_PATTERN)
  note_col <- qual_first_match(header, QUAL_NOTEWORTHY_PATTERN)
  verbatim_col  <- qual_detect_verbatim_col(header, col_values, qual_drop_na(c(id_col, note_col)))
  sentiment_col <- qual_detect_sentiment_col(header, col_values, verbatim_col, note_col)
  rating_col    <- qual_detect_rating_col(header, col_values)
  reserved <- qual_drop_na(c(id_col, verbatim_col, note_col, sentiment_col, rating_col))
  themes <- qual_theme_columns(header, col_values, verbatim_col, reserved)
  theme_cols <- vapply(themes, function(t) t$col, integer(1))
  demos  <- qual_demo_columns(header, verbatim_col, id_col, reserved, theme_cols)
  list(id = id_col, verbatim = verbatim_col, noteworthy = note_col,
       sentiment = sentiment_col, rating = rating_col, themes = themes, demos = demos)
}

# ---- Title + record extraction ----------------------------------------------

#' Derive the question title: last non-blank preamble line; else a non-generic
#' verbatim header (SACS); else "" (caller falls back to the sheet name).
qual_extract_title <- function(rows, header_row, roles, header) {
  if (header_row > 1L) {
    for (i in seq.int(header_row - 1L, 1L)) {
      first <- if (length(rows[[i]]) >= 1) rows[[i]][[1]] else ""
      if (nzchar(first)) return(first)
    }
  }
  vcol <- roles$verbatim
  if (!is.na(vcol) && nzchar(header[[vcol]]) &&
      !grepl(QUAL_VERBATIM_NAME_PATTERN, header[[vcol]], ignore.case = TRUE)) {
    return(header[[vcol]])
  }
  ""
}

#' A sentiment/rating cell coerced to an integer code, or NA when out of range/blank.
qual_code_or_na <- function(v) if (v %in% QUAL_SENTIMENT_CODES) as.integer(v) else NA_integer_

#' A numeric cell coerced to a number, or NA when not numeric/blank.
qual_num_or_na <- function(v) {
  x <- suppressWarnings(as.numeric(v))
  if (is.na(x)) NA_real_ else x
}

#' Map a noteworthy marker to a tier ordinal: 0 = other, 1 = noteworthy, 2 = must-read,
#' 3 = priority.
#'
#' Any non-blank marker is at least "noteworthy"; a marker in the must-read set is
#' promoted to tier 2, and one in the priority set to tier 3. Marker-agnostic and
#' case-insensitive, so "Yes"/"x"/"n" all read as tier 1, a coder's "m"/"Must read"
#' as tier 2, and "p"/"Priority" as tier 3. The one exception is a hide marker
#' ("hide"/"hidden"): it means "withhold this verbatim", not "feature it", so it reads
#' as tier 0 (see qual_verbatim_hidden and QUAL_HIDE_MARKERS).
#' @param marker The raw noteworthy cell value.
#' @param mustread Character vector of must-read markers (lower-case).
#' @param priority Character vector of priority markers (lower-case).
#' @return An integer tier (0, 1, 2 or 3).
qual_noteworthy_tier <- function(marker, mustread = QUAL_MUSTREAD_MARKERS,
                                 priority = QUAL_PRIORITY_MARKERS) {
  m <- tolower(trimws(marker))
  if (!nzchar(m)) return(0L)
  if (m %in% QUAL_HIDE_MARKERS) return(0L)   # a hide marker is a suppression, never noteworthy
  if (m %in% priority) return(3L)
  if (m %in% mustread) return(2L)
  1L
}

#' Whether a noteworthy-column marker withholds this comment's verbatim ("hide"/"hidden").
#' Case-insensitive. A hidden comment is still counted in every distribution; only its
#' text is withheld (build-time). Kept separate from the tier so the two axes — editorial
#' emphasis vs suppression — never collide in one value.
#' @param marker The raw noteworthy cell value.
#' @return TRUE when the marker is a hide token.
qual_verbatim_hidden <- function(marker) {
  tolower(trimws(marker)) %in% QUAL_HIDE_MARKERS
}

#' Build one record from a data row; quarantines out-of-range theme/sentiment codes.
#' @return `list(record, dropped)`; `record` is NULL for a fully-blank trailing row.
qual_record_from_row <- function(r, roles) {
  cell <- function(c) if (!is.na(c) && length(r) >= c) r[[c]] else ""
  id <- cell(roles$id); text <- cell(roles$verbatim)
  # A repeated header row (some sheets stack sub-tables) is not a respondent — skip it
  # without counting, so its header labels never leak in as data.
  if (grepl(QUAL_ID_PATTERN, id, ignore.case = TRUE)) return(list(record = NULL, dropped = 0L))
  if (!nzchar(id) && !nzchar(text)) return(list(record = NULL, dropped = 0L))
  dropped <- 0L
  theme_vals <- list()
  for (th in roles$themes) {
    v <- cell(th$col)
    if (!nzchar(v)) next
    if (v %in% QUAL_SENTIMENT_CODES) theme_vals[[th$label]] <- as.integer(v) else dropped <- dropped + 1L
  }
  sent_raw <- cell(roles$sentiment)
  sentiment <- qual_code_or_na(sent_raw)
  if (is.na(sentiment) && nzchar(sent_raw)) dropped <- dropped + 1L
  demos <- list()
  for (d in roles$demos) {
    v <- cell(d$col)
    demos[[d$label]] <- if (v %in% QUAL_MISSING_TOKENS) NA_character_ else v
  }
  note_marker <- cell(roles$noteworthy)
  tier <- qual_noteworthy_tier(note_marker)
  hidden <- qual_verbatim_hidden(note_marker)
  record <- list(id = id, text = text,
                 noteworthy = tier >= 1L, noteworthy_tier = tier, noteworthy_marker = note_marker,
                 hidden = hidden,
                 sentiment = sentiment, rating = qual_num_or_na(cell(roles$rating)),
                 themeVals = theme_vals, demos = demos)
  list(record = record, dropped = dropped)
}

#' Extract all per-respondent records below the header, accumulating dropped-code count.
#' @return `list(records, dropped_codes)`.
qual_extract_records <- function(rows, header_row, roles) {
  records <- list(); dropped <- 0L
  n <- length(rows)
  if (header_row >= 1L && header_row < n) {
    for (i in seq.int(header_row + 1L, n)) {
      built <- qual_record_from_row(rows[[i]], roles)
      if (is.null(built$record)) next
      dropped <- dropped + built$dropped
      records[[length(records) + 1L]] <- built$record
    }
  }
  list(records = records, dropped_codes = dropped)
}

#' Derive a stable, non-empty question code from a sheet name (slug).
qual_sheet_code <- function(sheet_name) {
  slug <- gsub("[^A-Za-z0-9]+", "_", trimws(sheet_name))
  slug <- gsub("^_+|_+$", "", slug)
  if (!nzchar(slug)) slug <- "Q"
  paste0("QUAL_", toupper(slug))
}

#' Classify and extract one worksheet into a qual question (or a skip marker).
#'
#' This is the reader's public entry point for a single sheet. It never throws: a
#' metadata sheet (Contents), a sheet with no ID-anchored header, or one with no
#' detectable verbatim column returns `list(skip = TRUE, reason = ...)` so the
#' caller can log it and move on (TRS refusals live in the I/O wrapper).
#' @param rows A list of normalised character rows (use `qual_norm_cells` upstream).
#' @param sheet_name The worksheet name.
#' @return A question list (skip = FALSE) or a skip marker (skip = TRUE).
#' @examples
#' \dontrun{
#'   q <- qual_classify_sheet(normalised_rows, "Culture")
#'   if (!q$skip && q$type == "themed") str(q$roles$themes)
#' }
qual_classify_sheet <- function(rows, sheet_name) {
  if (grepl(QUAL_CONTENTS_PATTERN, trimws(sheet_name), ignore.case = TRUE)) {
    return(list(skip = TRUE, reason = "contents", sheet = sheet_name))
  }
  header_row <- qual_find_header_row(rows)
  if (header_row == 0L) return(list(skip = TRUE, reason = "no_header", sheet = sheet_name))
  header <- rows[[header_row]]
  roles <- qual_classify_columns(header, rows, header_row)
  if (is.na(roles$verbatim)) {
    return(list(skip = TRUE, reason = "no_verbatim", sheet = sheet_name))
  }
  title <- qual_extract_title(rows, header_row, roles, header)
  if (!nzchar(title)) title <- trimws(sheet_name)
  extracted <- qual_extract_records(rows, header_row, roles)
  list(skip = FALSE, sheet = sheet_name, code = qual_sheet_code(sheet_name),
       title = title, type = if (length(roles$themes)) "themed" else "raw",
       header_row = header_row, roles = roles, records = extracted$records,
       meta = list(dropped_codes = extracted$dropped_codes,
                   n_records = length(extracted$records),
                   n_themes = length(roles$themes), n_demos = length(roles$demos)))
}
