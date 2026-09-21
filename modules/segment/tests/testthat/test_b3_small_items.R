# Session B3: the small items from the review's LOW list.

test_that("L4: the dead insight textarea is gone from both report builders", {
  # A hidden <textarea id="seg-insight-store"> carried over from an older
  # insight mechanism. No JS reads it: insights are contentEditable and
  # survive save-a-copy through outerHTML, which is why segment dodged the
  # keydriver/catdriver .value loss. The docs still described the textarea.
  root <- Sys.getenv("TURAS_ROOT")
  for (f in c("03_page_builder.R", "07a_combined_builders.R")) {
    src <- paste(readLines(file.path(root, "modules", "segment", "lib",
                                     "html_report", f), warn = FALSE), collapse = "\n")
    expect_false(grepl("seg-insight-store", src, fixed = TRUE))
  }
})

test_that("L2: one refusal code for too few clustering variables", {
  # CFG_INSUFFICIENT_VARS in the parser, CFG_INSUFFICIENT_VARIABLES in the
  # hard guard, for the same condition. A user searching the docs for the code
  # they were given could find either half of the story.
  root <- Sys.getenv("TURAS_ROOT")
  parser <- paste(readLines(file.path(root, "modules", "segment", "R", "01_config.R"),
                            warn = FALSE), collapse = "\n")
  guard <- paste(readLines(file.path(root, "modules", "segment", "R", "00a_guards_hard.R"),
                           warn = FALSE), collapse = "\n")

  expect_true(grepl('"CFG_INSUFFICIENT_VARIABLES"', guard, fixed = TRUE))
  expect_true(grepl('"CFG_INSUFFICIENT_VARIABLES"', parser, fixed = TRUE))
  expect_false(grepl('"CFG_INSUFFICIENT_VARS"', parser, fixed = TRUE))
})

test_that("L2: the refusal still fires, under the single code", {
  d <- data.frame(respondent_id = 1:40, q1 = rnorm(40), q2 = rnorm(40))
  path <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(d, path)

  err <- tryCatch(
    validate_segment_config(list(data_file = path, id_variable = "respondent_id",
                                 clustering_vars = "q1", k_fixed = "3",
                                 method = "kmeans")),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_true(grepl("INSUFFICIENT_VARIABLES", conditionMessage(err)))
})

test_that("L3: the launcher tile names the methods that exist", {
  root <- Sys.getenv("TURAS_ROOT")
  src <- paste(readLines(file.path(root, "launch_turas.R"), warn = FALSE), collapse = "\n")
  i <- regexpr('id = "segment"', src, fixed = TRUE)
  expect_true(i > 0)
  tile <- substr(src, i, i + 400)

  expect_true(grepl("hierarchical", tile, ignore.case = TRUE))
  expect_true(grepl("GMM", tile, fixed = TRUE))
  # It must not advertise what was removed.
  expect_false(grepl("latent class|LCA", tile, ignore.case = TRUE))
})

test_that("L5: the importance table says what its percentages are made of", {
  skip_if_not(exists("build_seg_importance_footnote", mode = "function"),
              "report layer not loaded")

  eta <- as.character(build_seg_importance_footnote(
    data.frame(variable = c("a", "b"), eta_squared = c(0.4, 0.2))))
  fstat <- as.character(build_seg_importance_footnote(
    data.frame(variable = c("a", "b"), f_statistic = c(40, 20))))

  expect_true(grepl("eta", eta, ignore.case = TRUE))
  # F statistics are not additively decomposable, so a share of their total is
  # a ranking aid and not a variance decomposition. The report has to say so.
  expect_true(grepl("F", fstat, fixed = TRUE))
  expect_true(grepl("rank|not a|share", fstat, ignore.case = TRUE))
  expect_null(build_seg_importance_footnote(NULL))
})

test_that("L1: golden_questions_trees is no longer an invisible knob", {
  # Read at 00_main.R via config$golden_questions_trees, parsed nowhere and
  # absent from the template, so it could only ever be its default.
  root <- Sys.getenv("TURAS_ROOT")
  lines <- readLines(file.path(root, "modules", "segment", "R", "00_main.R"),
                     warn = FALSE)
  # Code only: the comment explaining the change names the old key on purpose.
  code <- paste(grep("^\\s*#", lines, value = TRUE, invert = TRUE), collapse = "\n")

  expect_false(grepl("config$golden_questions_trees", code, fixed = TRUE))
  expect_true(grepl("SEGMENT_GOLDEN_QUESTION_TREES", code, fixed = TRUE))
})
