# ==============================================================================
# PIPELINE GATE. Readers for a run's workbook and v2 report
# ==============================================================================
#
# Shared by test_reference_pipeline.R and test_adversarial_pipeline.R. Reads the
# Crosstabs sheet into per-question blocks and the v2 report's data island from
# its HTML, and compares the two cell by cell. No Turas code is sourced: the
# point is to read what a run WROTE.
# ==============================================================================

# The Crosstabs sheet as blocks: code -> data frame(label, type, owner, v1..vk).
# Frequency and Column % rows share the label printed on the Frequency row; a
# Sig row belongs to the last row above it that is not a Standard Deviation
# row (the writer appends a mean's Sig row after its SD row).
.rp_read_workbook <- function(path) {
  x <- openxlsx::read.xlsx(path, sheet = "Crosstabs", colNames = FALSE,
                           skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  ncols <- ncol(x) - 2
  blocks <- list()
  code <- NULL; label <- NULL; owner <- NULL
  for (i in seq_len(nrow(x))) {
    c1 <- x[i, 1]; c2 <- x[i, 2]
    c1 <- if (is.na(c1)) "" else trimws(as.character(c1))
    c2 <- if (is.na(c2)) "" else trimws(as.character(c2))
    if (!nzchar(c2)) {
      m <- regmatches(c1, regexec("^([A-Za-z0-9_]+) - ", c1))[[1]]
      if (length(m) == 2) { code <- m[2]; label <- NULL; owner <- NULL }
      next
    }
    if (is.null(code)) next
    vals <- vapply(seq_len(ncols), function(j) {
      v <- x[i, 2 + j]; if (is.na(v)) "" else trimws(as.character(v))
    }, character(1))
    if (grepl("^(Base|Effective base)", c2)) {
      row_label <- ""
    } else if (c2 %in% c("Sig.", "Sig.2")) {
      row_label <- owner
    } else {
      if (nzchar(c1)) label <- c1
      row_label <- label
      if (c2 != "StdDev") owner <- paste0(label, "\u001f", c2)
    }
    blocks[[code]] <- rbind(blocks[[code]], data.frame(
      label = if (c2 %in% c("Sig.", "Sig.2")) NA_character_ else row_label,
      type = c2, owner = if (c2 %in% c("Sig.", "Sig.2")) row_label else NA_character_,
      t(vals), stringsAsFactors = FALSE))
  }
  blocks
}

.rp_cells <- function(block, label, type) {
  hit <- block[!is.na(block$label) & block$label == label & block$type == type, , drop = FALSE]
  if (nrow(hit) != 1) return(NULL)
  unname(unlist(hit[1, grep("^X", names(hit))]))
}

.rp_sig <- function(block, label, type, sig_type = "Sig.") {
  own <- paste0(label, "\u001f", type)
  hit <- block[!is.na(block$owner) & block$owner == own & block$type == sig_type, , drop = FALSE]
  if (nrow(hit) != 1) return(NULL)
  unname(unlist(hit[1, grep("^X", names(hit))]))
}

.rp_read_island <- function(path) {
  html <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(html, regexec('<script[^>]*id="data-agg"[^>]*>(.*?)</script>', html))[[1]]
  if (length(m) != 2) return(NULL)
  jsonlite::fromJSON(m[2], simplifyVector = FALSE)
}

.rp_blank <- function(v) ifelse(is.na(v) | v == "-", "", v)

# Every island row against its workbook row: percentages, frequencies and both
# letter rows. Returns the mismatches (character) plus the rows checked and the
# rows the island carries, so a caller can assert nothing was silently skipped.
.rp_consistency <- function(xlsx, html) {
  wb <- .rp_read_workbook(xlsx)
  isl <- .rp_read_island(html)
  bad <- character(0)
  n_checked <- 0L
  n_rows <- sum(vapply(isl$questions, function(q) length(q$rows), integer(1)))
  num <- function(v) vapply(v, function(z) if (is.null(z)) NA_real_ else as.numeric(z), numeric(1))
  for (q in isl$questions) {
    block <- wb[[q$code]]
    if (is.null(block)) { bad <- c(bad, paste(q$code, "missing from workbook")); next }
    for (r in q$rows) {
      type <- if (identical(r$kind, "mean")) {
        block$type[!is.na(block$label) & block$label == r$label][1]
      } else "Column %"
      cells <- .rp_cells(block, r$label, type)
      if (is.null(cells)) { bad <- c(bad, paste(q$code, r$label, "row not in workbook")); next }
      if (!isTRUE(all.equal(suppressWarnings(as.numeric(cells)), num(r$pct), tolerance = 1e-9))) {
        bad <- c(bad, paste(q$code, r$label, "pct"))
      }
      if (!identical(r$kind, "mean") && !all(vapply(r$n, is.null, logical(1)))) {
        freq <- .rp_cells(block, r$label, "Frequency")
        if (!isTRUE(all.equal(suppressWarnings(as.numeric(freq)), num(r$n), tolerance = 1e-9))) {
          bad <- c(bad, paste(q$code, r$label, "n"))
        }
      }
      for (lv in list(c("sig", "Sig."), c("sig2", "Sig.2"))) {
        isl_sig <- vapply(if (is.null(r[[lv[1]]])) list() else r[[lv[1]]],
                          function(v) if (is.null(v)) "" else v, character(1))
        wb_sig <- .rp_sig(block, r$label, type, lv[2])
        if (is.null(wb_sig)) wb_sig <- rep("", length(isl_sig))
        if (length(isl_sig) == 0) isl_sig <- rep("", length(wb_sig))
        if (!identical(unname(.rp_blank(wb_sig)), isl_sig)) bad <- c(bad, paste(q$code, r$label, lv[1]))
      }
      n_checked <- n_checked + 1L
    }
  }
  list(bad = bad, n_checked = n_checked, n_rows = n_rows, island = isl, workbook = wb)
}
