# ==============================================================================
# TESTS: EVERY conjoint_refuse() CALL IS SHAPED CORRECTLY
# ==============================================================================
#
# conjoint_refuse() takes code/title/problem/why_it_matters/how_to_fix. Two
# calls in 11_hierarchical_bayes.R passed `message =` instead, so instead of
# refusing they raised a raw R "unused argument" error — on the data-validation
# path, which is exactly where a user needs the refusal text. They survived
# because the HB tests always skipped.
#
# There are ~100 call sites; this walks all of them from the parse tree.
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", unset = "")
if (!nzchar(turas_root)) {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(dir, "modules", "conjoint", "R", "00_main.R"))) {
      turas_root <- dir
      break
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
}

collect_calls <- function(expr, fname, out = list()) {
  if (is.call(expr)) {
    if (identical(as.character(expr[[1]])[1], fname)) {
      out[[length(out) + 1]] <- expr
    }
    for (part in as.list(expr)[-1]) {
      if (!missing(part) && (is.call(part) || is.expression(part))) {
        out <- collect_calls(part, fname, out)
      }
    }
  }
  out
}

test_that("every conjoint_refuse() call uses arguments the function actually has", {
  module_dir <- file.path(turas_root, "modules", "conjoint")
  files <- c(
    list.files(file.path(module_dir, "R"), pattern = "[.]R$", full.names = TRUE),
    list.files(file.path(module_dir, "lib"), pattern = "[.]R$",
               full.names = TRUE, recursive = TRUE)
  )
  expect_gt(length(files), 0)

  allowed <- names(formals(conjoint_refuse))
  expect_true("problem" %in% allowed)

  offenders <- character(0)
  n_calls <- 0

  for (f in files) {
    exprs <- tryCatch(parse(f), error = function(e) NULL)
    if (is.null(exprs)) next

    for (e in as.list(exprs)) {
      for (cl in collect_calls(e, "conjoint_refuse")) {
        n_calls <- n_calls + 1
        arg_names <- names(as.list(cl))[-1]
        arg_names <- arg_names[nzchar(arg_names)]
        bad <- setdiff(arg_names, allowed)
        if (length(bad) > 0) {
          offenders <- c(offenders, sprintf("%s: %s",
                                            basename(f),
                                            paste(bad, collapse = ", ")))
        }
      }
    }
  }

  expect_gt(n_calls, 50)
  expect_equal(offenders, character(0))
})

test_that("every conjoint_refuse() call supplies the required fields", {
  module_dir <- file.path(turas_root, "modules", "conjoint")
  files <- c(
    list.files(file.path(module_dir, "R"), pattern = "[.]R$", full.names = TRUE),
    list.files(file.path(module_dir, "lib"), pattern = "[.]R$",
               full.names = TRUE, recursive = TRUE)
  )

  required <- c("code", "title", "problem", "why_it_matters", "how_to_fix")
  missing_fields <- character(0)

  for (f in files) {
    exprs <- tryCatch(parse(f), error = function(e) NULL)
    if (is.null(exprs)) next

    for (e in as.list(exprs)) {
      for (cl in collect_calls(e, "conjoint_refuse")) {
        arg_names <- names(as.list(cl))[-1]
        arg_names <- arg_names[nzchar(arg_names)]
        gap <- setdiff(required, arg_names)
        if (length(gap) > 0) {
          code <- tryCatch(as.character(as.list(cl)$code), error = function(e) "?")
          missing_fields <- c(missing_fields,
                              sprintf("%s [%s] missing: %s", basename(f),
                                      paste(code, collapse = ""),
                                      paste(gap, collapse = ", ")))
        }
      }
    }
  }

  expect_equal(missing_fields, character(0))
})
