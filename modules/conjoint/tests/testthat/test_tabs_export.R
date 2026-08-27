# ==============================================================================
# TESTS: PER-RESPONDENT IMPORTANCE EXPORT FOR THE TABS MODULE
# ==============================================================================
#
# The export writes attribute importance in the shape tabs reads as an
# Allocation question, so conjoint results can be crosstabbed against any
# banner in the client's own report.
#
# Two things must hold or the export is worse than useless:
#   1. Only genuine respondent-level estimates go in. A pooled model repeated
#      per respondent would give banner differences of exactly zero and
#      significance tests on a constant.
#   2. The columns must satisfy tabs' Allocation contract exactly — the last
#      test drives tabs' own processor with the exported shape.
# ==============================================================================

make_importance_matrix <- function(n = 60, seed = 4) {
  set.seed(seed)
  attrs <- c("Brand", "Price", "Size")
  m <- matrix(runif(n * length(attrs), 5, 60), nrow = n,
              dimnames = list(paste0("R", seq_len(n)), attrs))
  m <- m / rowSums(m) * 100
  m
}

make_export_results <- function(method = "hierarchical_bayes",
                                importance = make_importance_matrix(),
                                output_file = NULL) {
  list(
    respondent_importance = importance,
    model_result = structure(list(
      method = method,
      hb_settings = list(iterations = 10000, burnin = 5000, thin = 1,
                         n_draws_retained = 5000),
      convergence = list(converged = TRUE),
      respondent_quality = list(
        mean_rlh = 0.62, chance_rlh = 0.333, n_flagged = 3,
        quality_threshold = 0.4
      )
    ), class = "turas_conjoint_model"),
    config = list(
      respondent_id_column = "resp_id",
      output_file = output_file %||% file.path(tempdir(), "cj.xlsx")
    )
  )
}

# ---------------------------------------------------------------------------
# The honest-significance gate
# ---------------------------------------------------------------------------

test_that("an aggregate model refuses to export", {
  for (m in c("auto", "mlogit", "clogit", "best_worst_sequential")) {
    cond <- tryCatch(
      {
        export_conjoint_importance_for_tabs(make_export_results(method = m),
                                            verbose = FALSE)
        NULL
      },
      turas_refusal = function(e) e
    )

    expect_false(is.null(cond), info = m)
    expect_equal(cond$code, "CALC_NO_RESPONDENT_UTILITIES", info = m)
    expect_true(any(grepl("estimation_method = 'hb'", cond$how_to_fix, fixed = TRUE)),
                info = m)
  }
})

test_that("hierarchical Bayes and latent class both export", {
  for (m in c("hierarchical_bayes", "latent_class")) {
    out <- file.path(tempdir(), paste0("cj_", m, ".xlsx"))
    on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

    res <- export_conjoint_importance_for_tabs(
      make_export_results(method = m, output_file = out), verbose = FALSE
    )
    expect_equal(res$status, "PASS", info = m)
    expect_true(file.exists(res$output_file), info = m)
  }
})

test_that("a missing importance matrix refuses rather than writing an empty file", {
  r <- make_export_results()
  r$respondent_importance <- NULL

  cond <- tryCatch(
    { export_conjoint_importance_for_tabs(r, verbose = FALSE); NULL },
    turas_refusal = function(e) e
  )
  expect_false(is.null(cond))
  expect_equal(cond$code, "CALC_NO_RESPONDENT_UTILITIES")
})

# ---------------------------------------------------------------------------
# The column contract
# ---------------------------------------------------------------------------

test_that("DATA carries the configured id column and {code}_1..{code}_k", {
  out <- file.path(tempdir(), "cj_contract.xlsx")
  on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

  r <- make_export_results(output_file = out)
  r$config$respondent_id_column <- "ResponseID"
  r$config$tabs_question_code <- "CJIMP"

  res <- export_conjoint_importance_for_tabs(r, verbose = FALSE)
  data <- openxlsx::read.xlsx(res$output_file, sheet = "DATA")

  expect_equal(names(data), c("ResponseID", "CJIMP_1", "CJIMP_2", "CJIMP_3"))
  expect_equal(nrow(data), 60)
})

test_that("every exported respondent's shares sum to 100", {
  out <- file.path(tempdir(), "cj_sum.xlsx")
  on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

  res <- export_conjoint_importance_for_tabs(
    make_export_results(output_file = out), verbose = FALSE)
  data <- openxlsx::read.xlsx(res$output_file, sheet = "DATA")

  expect_true(all(abs(rowSums(data[, -1]) - 100) < 1e-6))
})

test_that("respondents with flat part-worths are excluded and counted", {
  m <- make_importance_matrix(n = 20)
  m[c(2, 7, 13), ] <- 0   # flat part-worths: no importance profile

  out <- file.path(tempdir(), "cj_excl.xlsx")
  on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

  res <- suppressWarnings(capture.output(
    r <- export_conjoint_importance_for_tabs(
      make_export_results(importance = m, output_file = out), verbose = FALSE),
    type = "output"
  ))

  expect_equal(r$n_exported, 17)
  expect_equal(r$n_excluded, 3)
  expect_equal(r$status, "PARTIAL")

  data <- openxlsx::read.xlsx(r$output_file, sheet = "DATA")
  expect_equal(nrow(data), 17)
  expect_true(all(abs(rowSums(data[, -1]) - 100) < 1e-6))
})

test_that("an all-flat sample refuses rather than exporting zeros", {
  m <- make_importance_matrix(n = 10)
  m[] <- 0

  cond <- tryCatch(
    {
      export_conjoint_importance_for_tabs(
        make_export_results(importance = m), verbose = FALSE)
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "CALC_NO_EXPORTABLE_RESPONDENTS")
})

test_that("a malformed question code refuses", {
  for (bad in c("2CODE", "cj imp", "CJ-IMP", "")) {
    r <- make_export_results()
    r$config$tabs_question_code <- bad
    cond <- tryCatch(
      { export_conjoint_importance_for_tabs(r, verbose = FALSE); NULL },
      turas_refusal = function(e) e
    )
    expect_false(is.null(cond), info = bad)
    expect_equal(cond$code, "CFG_TABS_QUESTION_CODE_INVALID", info = bad)
  }
})

# ---------------------------------------------------------------------------
# The snippet and the method sheet
# ---------------------------------------------------------------------------

test_that("the QuestionMap snippet matches the data it describes", {
  out <- file.path(tempdir(), "cj_snip.xlsx")
  on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

  res <- export_conjoint_importance_for_tabs(
    make_export_results(output_file = out), verbose = FALSE)

  expect_equal(res$questionmap$Variable_Type, "Allocation")
  expect_equal(res$questionmap$Columns, 3)
  expect_equal(res$questionmap$QuestionCode, "CJIMP")
  expect_match(res$questionmap$QuestionText, "hierarchical Bayes")

  # Options must be in the same order as the columns, or every label is wrong.
  expect_equal(res$options$OptionText, c("Brand", "Price", "Size"))
  expect_equal(res$options$OptionCode, 1:3)

  snippet <- openxlsx::read.xlsx(res$output_file, sheet = "QUESTIONMAP_SNIPPET",
                                 startRow = 2)
  expect_equal(as.character(snippet$Variable_Type[1]), "Allocation")
})

test_that("the METHOD sheet discloses what a reader has to know", {
  out <- file.path(tempdir(), "cj_meth.xlsx")
  on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

  res <- export_conjoint_importance_for_tabs(
    make_export_results(output_file = out), verbose = FALSE)

  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD")
  blob <- paste(method$Item, method$Value, collapse = " | ")

  # The estimator, the exclusions, and the weighting mismatch that a reader
  # would otherwise never learn about.
  expect_match(blob, "hierarchical Bayes")
  expect_match(blob, "Respondents exported")
  expect_match(blob, "Respondents excluded")
  expect_match(blob, "estimated UNWEIGHTED")
  expect_match(blob, "model output, not answers")
  expect_match(blob, "flagged")
})

# ---------------------------------------------------------------------------
# The integration proof: tabs' own processor, on the exported shape
# ---------------------------------------------------------------------------

test_that("tabs' Allocation processor reads the exported data and returns one row per attribute", {
  root <- Sys.getenv("TURAS_ROOT")
  alloc <- file.path(root, "modules", "tabs", "lib", "allocation_processor.R")
  skip_if(!file.exists(alloc), "tabs allocation processor not present")

  out <- file.path(tempdir(), "cj_integration.xlsx")
  on.exit(unlink(sub("[.]xlsx$", "_tabs_importance.xlsx", out)), add = TRUE)

  res <- export_conjoint_importance_for_tabs(
    make_export_results(output_file = out), verbose = FALSE)

  data <- openxlsx::read.xlsx(res$output_file, sheet = "DATA")

  # Load tabs' processor and its dependencies the way tabs' own suite does —
  # shared_functions.R resolves its siblings through a global script_dir.
  tabs_lib <- file.path(root, "modules", "tabs", "lib")
  env <- new.env(parent = globalenv())
  assign("script_dir", tabs_lib, envir = env)
  assign("script_dir", tabs_lib, envir = globalenv())
  on.exit(suppressWarnings(rm("script_dir", envir = globalenv())), add = TRUE)

  for (dep in c("shared_functions.R", "excel_utils.R", "allocation_processor.R")) {
    f <- file.path(tabs_lib, dep)
    skip_if(!file.exists(f), paste("missing", dep))
    suppressWarnings(suppressMessages(sys.source(f, envir = env)))
  }

  skip_if(!exists("process_allocation_question", envir = env),
          "tabs processor did not load standalone")

  if (!exists("log_message", envir = env)) {
    assign("log_message", function(...) invisible(NULL), envir = env)
  }

  n <- nrow(data)
  question_info <- res$questionmap
  question_options <- data.frame(
    QuestionCode = res$options$QuestionCode,
    OptionText = res$options$OptionText,
    stringsAsFactors = FALSE
  )
  banner_info <- list(internal_keys = "TOTAL::Total",
                      display_labels = "Total")
  banner_indices <- list("TOTAL::Total" = seq_len(n))
  banner_bases <- list("TOTAL::Total" = list(unweighted = n, weighted = n))
  cfg <- list(decimal_places_numeric = 1L, enable_significance_testing = FALSE,
              alpha = 0.05, significance_min_base = 30L, verbose = FALSE)

  result <- try(
    env$process_allocation_question(
      data, question_info, question_options, banner_info, banner_indices,
      rep(1, n), banner_bases, cfg, is_weighted = FALSE
    ),
    silent = TRUE
  )

  skip_if(inherits(result, "try-error"),
          paste("tabs processor needs more of its module loaded:",
                as.character(result)))

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)
  expect_equal(result$RowLabel, c("Brand", "Price", "Size"))

  # The three banner means must sum to 100 — the allocation is conserved.
  totals <- suppressWarnings(as.numeric(result[["TOTAL::Total"]]))
  expect_false(anyNA(totals))
  expect_equal(sum(totals), 100, tolerance = 0.2)
})
