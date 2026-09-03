# ==============================================================================
# TABS MODULE. READER-MARK STABLE KEYS (the `rid` token + its sidecar)
# ==============================================================================
#
# Reader marks (shortlist, highlighted passages, hub memberships) live in the
# reader's browser, keyed per comment. Until I20 that key was `qcode#idx`, and
# `idx` is POSITIONAL. The respondent's place in the sorted id list (Phase 1) or
# the host survey's row index (Phase 2). Re-export the data and every mark
# silently re-attaches to a different respondent's comment.
#
# The fix is an opaque per-respondent token, `rid`, that rides each island record
# alongside `idx`. It is minted here, R-side, and persisted in a sidecar next to
# the config (`<config>_reader_keys.json`) that NEVER ships in any deliverable.
#
# WHY A RANDOM TOKEN AND NOT THE RESPONDENT ID: the island is readable in
# View-Source. A shipped ResponseID would let anyone holding the raw export join
# an "anonymous" comment back to a named respondent. A uniform-random token
# carries zero bits of the id, so it discloses nothing under any privacy dial,
# there is nothing to brute-force toward. (A content hash collides on duplicate
# verbatims and dies on a typo fix; a keyed hash of the id is only as good as a
# secret salt over a small guessable id space. Both were rejected. See
# docs/tabs_production_review_2026-08/I20_READER_MARK_REKEYING_DESIGN.md §2.)
#
# APPEND-ONLY, NEVER DELETE: an id that drops out of one export keeps its sidecar
# entry, so a respondent who returns in the next export re-attaches to their old
# marks. A corrupt sidecar is NEVER re-minted over. Silent re-minting would
# orphan every mark the reader has made.
#
# Depends on: jsonlite. Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_reader_keys.R")
# ==============================================================================

# Token width in hex characters. 16 hex = 64 bits: collisions are not a practical
# concern at survey scale, and uniqueness is checked against the map regardless.
QUAL_RID_HEX <- 16L
# Sidecar format version, so a future shape change can be detected rather than
# guessed at.
QUAL_READER_KEYS_VERSION <- 1L

#' The sidecar path for a config: `<config-without-extension>_reader_keys.json`.
#'
#' Beside the config, exactly like the AI-insights sidecar
#' (`build_dl_ai`, data_layer_writer.R). It lives in the project folder, travels
#' with the project, and is never copied into a deliverable.
#'
#' @param config_file_path The loaded config's own path.
#' @return The sidecar path, or NA_character_ when no config path is known.
qual_reader_keys_path <- function(config_file_path) {
  if (is.null(config_file_path) || length(config_file_path) != 1L ||
      is.na(config_file_path) || !nzchar(trimws(config_file_path))) {
    return(NA_character_)
  }
  paste0(tools::file_path_sans_ext(trimws(config_file_path)), "_reader_keys.json")
}

#' Mint one 16-hex reader token, avoiding any token already in `taken`.
#'
#' Uses `sample()` (no new dependency). The caller restores the RNG state, so
#' minting can never shift a seeded bootstrap elsewhere in the run.
#'
#' @param taken Character vector of tokens already issued.
#' @return A 16-character lowercase hex string not present in `taken`.
qual_mint_rid <- function(taken = character(0)) {
  alphabet <- c(as.character(0:9), letters[1:6])
  for (attempt in seq_len(100L)) {
    token <- paste0(sample(alphabet, QUAL_RID_HEX, replace = TRUE), collapse = "")
    if (!(token %in% taken)) return(token)
  }
  # Unreachable at any realistic sample size (64 bits of entropy per draw); the
  # loop bound exists so a degenerate RNG cannot hang the run.
  paste0(sample(alphabet, QUAL_RID_HEX, replace = TRUE), collapse = "")
}

#' Read the reader-key sidecar.
#'
#' @param path The sidecar path.
#' @return list(status, map). `status` is "ABSENT" (no file, mint fresh),
#'   "PASS" (map read) or "CORRUPT" (unreadable/unparseable, the caller must
#'   NOT re-mint, or every existing mark is orphaned).
qual_read_reader_keys <- function(path) {
  if (is.na(path) || !file.exists(path)) return(list(status = "ABSENT", map = character(0)))
  parsed <- tryCatch(
    jsonlite::fromJSON(paste(readLines(path, warn = FALSE), collapse = "\n"),
                       simplifyVector = FALSE),
    error = function(e) NULL)
  if (is.null(parsed) || is.null(parsed$keys) || !is.list(parsed$keys)) {
    return(list(status = "CORRUPT", map = character(0)))
  }
  keys <- parsed$keys
  ids <- names(keys)
  if (is.null(ids)) return(list(status = "CORRUPT", map = character(0)))
  vals <- vapply(keys, function(v) {
    if (is.null(v) || length(v) != 1L || is.na(v)) NA_character_ else as.character(v)
  }, character(1), USE.NAMES = FALSE)
  keep <- !is.na(vals) & nzchar(vals) & nzchar(ids)
  list(status = "PASS", map = stats::setNames(vals[keep], ids[keep]))
}

#' Write the reader-key sidecar.
#' @param path The sidecar path.
#' @param map Named character vector (id -> token).
#' @return TRUE on success, FALSE when the write failed.
qual_write_reader_keys <- function(path, map) {
  payload <- list(version = QUAL_READER_KEYS_VERSION,
                  built = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                  keys = as.list(map))
  ok <- tryCatch({
    jsonlite::write_json(payload, path, pretty = TRUE, auto_unbox = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  isTRUE(ok)
}

#' Boxed console warning (Shiny-visible) for a reader-key failure mode.
#' @param title Short headline.
#' @param lines Character vector of detail lines.
#' @return invisible(NULL).
qual_reader_keys_warn <- function(title, lines) {
  cat("\n┌─── TURAS READER-KEY WARNING ────────────────────────────────┐\n")
  cat("│", title, "\n")
  for (line in lines) cat("│", line, "\n")
  cat("└─────────────────────────────────────────────────────────────┘\n\n")
  invisible(NULL)
}

#' Load or mint the per-respondent reader tokens for a project.
#'
#' Append-only: known ids keep their token, new ids get one, and ids absent from
#' this export keep their sidecar entry (so a respondent who drops out of one
#' export and returns in the next re-attaches to their old marks). The file is
#' rewritten only when something was minted.
#'
#' `ids` must be the SAME id universe the island keys records by, i.e.
#' `names(master$id_to_idx)`, which is the normalised workbook id in Phase 1 and
#' the normalised host ResponseID in Phase 2. Ids pass through untouched so a
#' token lookup matches a record's `id` exactly.
#'
#' @param ids Character vector of respondent ids (duplicates and blanks dropped).
#' @param config_obj The tabs config object (needs `config_file_path`).
#' @return A list with structure:
#'   \item{status}{"PASS" (map usable, sidecar current), "WRITE_FAILED" (map
#'     usable but not persisted), "NO_PATH" (no config path, no rids) or
#'     "CORRUPT" (unreadable sidecar, no rids, file left untouched)}
#'   \item{map}{Named character vector, id -> token; NULL when no rids apply}
#'   \item{path}{The sidecar path, or NA_character_}
#'   \item{minted}{How many tokens this call created}
#'
#' @examples
#' \dontrun{
#'   keys <- qual_reader_keys(names(master$id_to_idx), config_obj)
#'   island <- qual_build_data_qual(questions, master, cfg, rid_map = keys$map)
#' }
#' @export
qual_reader_keys <- function(ids, config_obj = list()) {
  path <- qual_reader_keys_path(config_obj$config_file_path)
  if (is.na(path)) {
    qual_reader_keys_warn(
      "No config file path. Reader marks cannot be given stable keys.",
      c("Reader marks stay keyed by position, so a re-export can silently",
        "re-attach a mark to a different respondent's comment.",
        "Fix: run from a saved config so the reader-key sidecar has a home."))
    return(list(status = "NO_PATH", map = NULL, path = NA_character_, minted = 0L))
  }

  existing <- qual_read_reader_keys(path)
  if (identical(existing$status, "CORRUPT")) {
    qual_reader_keys_warn(
      sprintf("Reader-key sidecar unreadable: %s", basename(path)),
      c("It was NOT rewritten. Re-minting would orphan every reader mark.",
        "This report ships without stable comment keys, so existing marks are",
        "temporarily invisible (they are not deleted).",
        "Fix: restore the file from a backup, or delete it to start fresh."))
    return(list(status = "CORRUPT", map = NULL, path = path, minted = 0L))
  }

  ids <- as.character(ids)
  ids <- unique(ids[!is.na(ids) & nzchar(ids)])
  map <- existing$map
  fresh <- setdiff(ids, names(map))

  if (length(fresh)) {
    # Restore the RNG afterwards: minting must never shift a seeded bootstrap or
    # any other reproducible draw elsewhere in the run.
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    old_seed <- if (had_seed) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL
    on.exit({
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = globalenv())
      } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      }
    }, add = TRUE)
    taken <- unname(map)
    minted <- character(length(fresh))
    for (i in seq_along(fresh)) {
      token <- qual_mint_rid(taken)
      minted[[i]] <- token
      taken <- c(taken, token)
    }
    map <- c(map, stats::setNames(minted, fresh))
  }

  if (!length(fresh)) {
    return(list(status = "PASS", map = map, path = path, minted = 0L))
  }
  if (!qual_write_reader_keys(path, map)) {
    qual_reader_keys_warn(
      sprintf("Could not write the reader-key sidecar: %s", basename(path)),
      c("This report's comment keys are correct, but the tokens minted now are",
        "not saved. The NEXT rebuild will mint different ones and marks made",
        "against this build will not carry over.",
        "Fix: check the folder is writable, then rebuild."))
    return(list(status = "WRITE_FAILED", map = map, path = path, minted = length(fresh)))
  }
  list(status = "PASS", map = map, path = path, minted = length(fresh))
}
