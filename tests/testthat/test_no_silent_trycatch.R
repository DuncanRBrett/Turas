# tests/testthat/test_no_silent_trycatch.R
# ------------------------------------------------------------------------------
# Guardrail: forbid "silent" tryCatch handlers (error=function(e){...}) that
# swallow errors without any console signalling.
#
# This is intentionally conservative: it will fail if it finds an error handler
# body that contains neither:
#   - turas_refuse()/catdriver_refuse()/stop()
#   - warning()/message()/cat()/cli_*() logging
# nor an explicit rethrow (stop(e), rlang::abort, etc.)
#
# If a specific handler is intentionally silent (strongly discouraged), add an
# allowlist entry with file + line + a short reason.
# ------------------------------------------------------------------------------

testthat::test_that("No silent tryCatch error handlers exist", {

  # ---- config ----
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  # directories to skip (vendored deps, build output, etc.)
  skip_dirs <- c(
    "/renv/", "/packrat/", "/.git/", "/.Rproj.user/", "/.pytest_cache/",
    "/_book/", "/docs/", "/inst/doc/", "/vignettes/", "/man/", "/data/",
    "/tests/testthat/_snaps/"
  )

  # files to skip (this test file contains example patterns that would false-positive)
  skip_files <- c(
    "test_no_silent_trycatch.R"
  )

  # allowlist: exact matches to suppress known false positives.
  # Format: list(list(file="relative/path.R", line=123, why="..."), ...)
  allowlist <- list(
    # Example:
    # list(file="modules/foo/R/bar.R", line=87, why="Handled upstream; console logs elsewhere")
  )

  # what "counts" as explicit signalling (any of these substrings inside handler body)
  required_signals <- c(
    "turas_refuse", "catdriver_refuse", "stop(", "rlang::abort", "abort(",
    "warning(", "message(", "cat(", "cli::cli_", "cli_", "print(", "traceback("
  )

  # quick patterns that are almost always silent
  # (We also do a structured check below, this just helps catch trivial cases fast)
  obviously_silent <- c(
    "error\\s*=\\s*function\\s*\\(\\s*e\\s*\\)\\s*\\{\\s*NULL\\s*\\}",
    "error\\s*=\\s*function\\s*\\(\\s*e\\s*\\)\\s*\\{\\s*\\}",
    "error\\s*=\\s*function\\s*\\(\\s*e\\s*\\)\\s*\\{\\s*#.*\\s*\\}"
  )

  # ---- helpers ----
  is_skipped_path <- function(p) {
    # skip by directory
    if (any(vapply(skip_dirs, function(d) grepl(d, p, fixed = TRUE), logical(1)))) {
      return(TRUE)
    }
    # skip by filename
    fname <- basename(p)
    if (any(vapply(skip_files, function(f) fname == f, logical(1)))) {
      return(TRUE)
    }
    FALSE
  }

  rel_path <- function(p) sub(paste0("^", root, "/?"), "", p)

  # find all R files under the repo root
  r_files <- list.files(
    path = root,
    pattern = "\\.[Rr]$",
    recursive = TRUE,
    full.names = TRUE
  )
  r_files <- r_files[!vapply(r_files, is_skipped_path, logical(1))]

  # no files? fail early, because tests might be running from wrong cwd
  testthat::expect_true(length(r_files) > 0)

  findings <- list()

  # ---- scan ----
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
    if (!length(lines)) next

    txt <- paste(lines, collapse = "\n")

    # 1) catch obviously-silent handlers quickly
    for (pat in obviously_silent) {
      if (grepl(pat, txt, perl = TRUE)) {
        findings[[length(findings) + 1]] <- list(
          file = rel_path(f),
          line = NA_integer_,
          kind = "obvious_silent",
          snippet = pat
        )
      }
    }

    # 2) structured check: locate each "error = function(e) { ... }" block
    # We'll do a simple brace-matching parse starting from each match.
    m <- gregexpr("error\\s*=\\s*function\\s*\\(\\s*e\\s*\\)\\s*\\{", txt, perl = TRUE)[[1]]
    if (length(m) == 1 && m[1] == -1) next

    for (start in m) {
      # find handler body boundaries via brace matching
      open_brace <- regexpr("\\{", substr(txt, start, nchar(txt)), perl = TRUE)[[1]]
      if (open_brace == -1) next
      open_pos <- start + open_brace - 1

      # walk forward char-by-char to find the matching closing brace
      depth <- 0L
      end_pos <- NA_integer_
      for (i in open_pos:nchar(txt)) {
        ch <- substr(txt, i, i)
        if (ch == "{") depth <- depth + 1L
        if (ch == "}") {
          depth <- depth - 1L
          if (depth == 0L) { end_pos <- i; break }
        }
      }
      if (is.na(end_pos)) next

      body <- substr(txt, open_pos + 1L, end_pos - 1L)

      # Ignore bodies that clearly rethrow (stop/abort) or clearly signal.
      has_signal <- any(vapply(required_signals, function(s) grepl(s, body, fixed = TRUE), logical(1)))

      if (!has_signal) {
        # compute approximate line number (best-effort)
        prefix <- substr(txt, 1L, start)
        line_no <- 1L + sum(strsplit(prefix, "\n", fixed = TRUE)[[1]] != "") - 1L
        findings[[length(findings) + 1]] <- list(
          file = rel_path(f),
          line = line_no,
          kind = "silent_handler",
          snippet = trimws(substr(body, 1L, min(220L, nchar(body))))
        )
      }
    }
  }

  # ---- apply allowlist ----
  if (length(findings) > 0 && length(allowlist) > 0) {
    findings <- Filter(function(x) {
      # keep finding if it does NOT match any allowlist entry
      !any(vapply(allowlist, function(a) {
        same_file <- isTRUE(a$file == x$file)
        same_line <- isTRUE(is.na(a$line) || is.na(x$line) || a$line == x$line)
        same_file && same_line
      }, logical(1)))
    }, findings)
  }

  # ---- assert ----
  if (length(findings) > 0) {
    msg_lines <- c(
      "Silent tryCatch error handlers detected (must log/warn/refuse/stop):",
      ""
    )

    for (x in findings) {
      msg_lines <- c(
        msg_lines,
        sprintf("- %s%s [%s]", x$file, if (!is.na(x$line)) paste0(":", x$line) else "", x$kind),
        sprintf("  Snippet: %s", gsub("\\s+", " ", x$snippet)),
        ""
      )
    }

    testthat::fail(paste(msg_lines, collapse = "\n"))
  }

  testthat::succeed()
})
