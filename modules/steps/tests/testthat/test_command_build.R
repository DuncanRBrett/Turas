# ==============================================================================
# TESTS - Command construction
# ==============================================================================

# Every test builds against a temp root holding the manifest's entry script, so
# nothing here depends on the real repo layout.
with_probe_root <- function(args, f) {
  root <- tempfile("steps_root_")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("cat('probe')", file.path(root, "probe.R"))
  f(root, test_manifest(args = args))
}


test_that("arguments are emitted in manifest order, entry script first", {
  with_probe_root(list(
    list(id = "alpha", label = "Alpha", type = "text", cli = "--alpha"),
    list(id = "beta",  label = "Beta",  type = "text", cli = "--beta")
  ), function(root, m) {
    res <- steps_build_command(m, list(alpha = "A", beta = "B"), turas_root = root)
    expect_equal(res$status, "PASS")
    expect_equal(res$runtime, "Rscript")
    expect_equal(res$args,
                 c(file.path(root, "probe.R"), "--alpha", "A", "--beta", "B"))
  })
})

test_that("blank optional arguments are omitted", {
  with_probe_root(list(
    list(id = "alpha", label = "Alpha", type = "text", cli = "--alpha"),
    list(id = "beta",  label = "Beta",  type = "text", cli = "--beta")
  ), function(root, m) {
    res <- steps_build_command(m, list(alpha = "", beta = NULL), turas_root = root)
    expect_equal(res$status, "PASS")
    expect_equal(res$args, file.path(root, "probe.R"))
  })
})

test_that("a blank required argument refuses and names the field", {
  with_probe_root(list(
    list(id = "alpha", label = "Alpha", type = "text", cli = "--alpha", required = TRUE)
  ), function(root, m) {
    res <- steps_build_command(m, list(alpha = ""), turas_root = root)
    expect_equal(res$status, "REFUSED")
    expect_equal(res$code, "CFG_STEP_ARG_MISSING")
    expect_true(grepl("Alpha", res$message, fixed = TRUE))
  })
})

test_that("a flag is emitted only when on, and never carries a value", {
  with_probe_root(list(
    list(id = "dry", label = "Dry run", type = "flag", cli = "--dry-run")
  ), function(root, m) {
    entry <- file.path(root, "probe.R")
    expect_equal(steps_build_command(m, list(dry = TRUE),  turas_root = root)$args,
                 c(entry, "--dry-run"))
    expect_equal(steps_build_command(m, list(dry = FALSE), turas_root = root)$args, entry)
    expect_equal(steps_build_command(m, list(),            turas_root = root)$args, entry)
  })
})

test_that("an optional-value switch is always emitted, with the value when given", {
  with_probe_root(list(
    list(id = "rep", label = "Review list", type = "flag_value", cli = "--report-changes")
  ), function(root, m) {
    entry <- file.path(root, "probe.R")
    expect_equal(steps_build_command(m, list(rep = ""), turas_root = root)$args,
                 c(entry, "--report-changes"))
    expect_equal(steps_build_command(m, list(rep = "/tmp/out.xlsx"), turas_root = root)$args,
                 c(entry, "--report-changes", "/tmp/out.xlsx"))
  })
})

test_that("a file argument that must exist refuses when it does not", {
  with_probe_root(list(
    list(id = "input", label = "Input", type = "file", cli = "--input", must_exist = TRUE)
  ), function(root, m) {
    res <- steps_build_command(m, list(input = file.path(root, "nope.xlsx")),
                               turas_root = root)
    expect_equal(res$status, "REFUSED")
    expect_equal(res$code, "IO_STEP_ARG_NOT_FOUND")

    ok <- steps_build_command(m, list(input = file.path(root, "probe.R")),
                              turas_root = root)
    expect_equal(ok$status, "PASS")
  })
})

test_that("an output file argument may name a path that does not exist yet", {
  with_probe_root(list(
    list(id = "out", label = "Output", type = "file", cli = "--appendix",
         must_exist = FALSE)
  ), function(root, m) {
    res <- steps_build_command(m, list(out = file.path(root, "new.xlsx")),
                               turas_root = root)
    expect_equal(res$status, "PASS")
    expect_true(file.path(root, "new.xlsx") %in% res$args)
  })
})

test_that("a missing directory argument refuses", {
  with_probe_root(list(
    list(id = "d", label = "Folder", type = "dir", cli = "--dir")
  ), function(root, m) {
    res <- steps_build_command(m, list(d = file.path(root, "no_such_dir")),
                               turas_root = root)
    expect_equal(res$status, "REFUSED")
    expect_equal(res$code, "IO_STEP_ARG_NOT_FOUND")
  })
})

test_that("two arguments in the same exclusive group refuse, naming both", {
  with_probe_root(list(
    list(id = "cols", label = "Columns", type = "text", cli = "--columns",
         exclusive = "columns"),
    list(id = "pat",  label = "Pattern", type = "text", cli = "--pattern",
         exclusive = "columns")
  ), function(root, m) {
    res <- steps_build_command(m, list(cols = "a,b", pat = "comment"), turas_root = root)
    expect_equal(res$status, "REFUSED")
    expect_equal(res$code, "CFG_STEP_ARGS_CONFLICT")
    expect_true(grepl("Columns", res$message, fixed = TRUE))
    expect_true(grepl("Pattern", res$message, fixed = TRUE))

    # Either one alone is fine.
    expect_equal(steps_build_command(m, list(cols = "a,b"), turas_root = root)$status, "PASS")
    expect_equal(steps_build_command(m, list(pat = "comment"), turas_root = root)$status, "PASS")
  })
})

test_that("a choice outside its choices refuses", {
  with_probe_root(list(
    list(id = "c", label = "Colour", type = "choice", cli = "--colour",
         choices = c("red", "blue"))
  ), function(root, m) {
    expect_equal(steps_build_command(m, list(c = "purple"), turas_root = root)$status,
                 "REFUSED")
    expect_equal(steps_build_command(m, list(c = "red"), turas_root = root)$status,
                 "PASS")
  })
})

test_that("a missing entry script refuses before anything runs", {
  root <- tempfile("steps_root_")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  res <- steps_build_command(test_manifest(args = list()), list(), turas_root = root)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_STEP_ENTRY_NOT_FOUND")
})

test_that("path arguments are absolutised, so the tool gets what the guard checked", {
  with_probe_root(list(
    list(id = "out", label = "Output", type = "file", cli = "--out", must_exist = FALSE),
    list(id = "note", label = "Note", type = "text", cli = "--note")
  ), function(root, m) {
    # "~" means nothing to python; R's file.exists() expands it, so a path that
    # passed the check would fail inside the tool.
    tilde <- steps_build_command(m, list(out = "~/appendix.xlsx"), turas_root = root)
    expect_equal(tilde$status, "PASS")
    expect_true(path.expand("~/appendix.xlsx") %in% tilde$args)
    expect_false(any(grepl("~", tilde$args, fixed = TRUE)))

    # A relative path is resolved rather than left to the child's working dir.
    rel <- steps_build_command(m, list(out = "sub/appendix.xlsx"), turas_root = root)
    expect_true(any(grepl("^(/|[A-Za-z]:)", setdiff(rel$args, file.path(root, "probe.R")))))

    # A non-path value is passed through untouched.
    plain <- steps_build_command(m, list(note = "comment|verbatim"), turas_root = root)
    expect_true("comment|verbatim" %in% plain$args)
  })
})

test_that("values are not shell-escaped in the argument vector, only in the echo", {
  with_probe_root(list(
    list(id = "alpha", label = "Alpha", type = "text", cli = "--alpha")
  ), function(root, m) {
    res <- steps_build_command(m, list(alpha = "a path/with space.xlsx"),
                               turas_root = root)
    expect_true("a path/with space.xlsx" %in% res$args)
    expect_true(grepl("'a path/with space.xlsx'", res$display, fixed = TRUE))
  })
})

test_that("the real comment-appendix build command looks as expected", {
  m <- steps_find_tool("comment_appendix_build")
  script <- file.path(TURAS_ROOT, "scripts", "build_comment_appendix.py")
  appendix <- file.path(tempdir(), "does_not_exist_yet.xlsx")

  res <- steps_build_command(m, list(
    data     = script,          # any existing file: only existence is checked here
    appendix = appendix,
    pattern  = "comment|verbatim",
    dry_run  = TRUE
  ), turas_root = TURAS_ROOT)

  expect_equal(res$status, "PASS")
  expect_equal(res$runtime, "python3")
  expect_equal(res$args, c(
    script,
    "--data", script,
    "--appendix", appendix,
    "--pattern", "comment|verbatim",
    "--dry-run"
  ))
})
