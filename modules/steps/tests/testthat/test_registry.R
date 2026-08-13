# ==============================================================================
# TESTS - Tool registry and manifest validation
# ==============================================================================

test_that("the built-in registry validates", {
  reg <- steps_registry()
  expect_equal(reg$status, "PASS")
  expect_true(length(reg$result) >= 3)
})

test_that("every built-in tool's script exists under the Turas root", {
  for (m in steps_builtin_manifests()) {
    expect_true(file.exists(file.path(TURAS_ROOT, m$entry)),
                info = sprintf("%s -> %s", m$id, m$entry))
  }
})

test_that("every built-in tool's docs file exists when declared", {
  for (m in steps_builtin_manifests()) {
    if (is.null(m$docs)) next
    expect_true(file.exists(file.path(TURAS_ROOT, m$docs)),
                info = sprintf("%s -> %s", m$id, m$docs))
  }
})

test_that("steps_find_tool finds by id and returns NULL otherwise", {
  expect_equal(steps_find_tool("comment_appendix_build")$id, "comment_appendix_build")
  expect_null(steps_find_tool("no_such_tool"))
  expect_null(steps_find_tool(NULL))
})


# ---- the correctness catch ---------------------------------------------------
# build_comment_appendix.py resolves the comment columns BEFORE it dispatches on
# mode, so the review modes need the same column arguments as the build mode.
# Without them they would silently fall back to the default name pattern and
# review a different set of sheets.

test_that("all three comment-appendix modes carry the column-resolution args", {
  needed <- c("data", "appendix", "columns_file", "pattern")
  for (id in c("comment_appendix_build",
               "comment_appendix_report_changes",
               "comment_appendix_apply_changes")) {
    m <- steps_find_tool(id)
    arg_ids <- vapply(m$args, function(a) a$id, character(1))
    expect_true(all(needed %in% arg_ids),
                info = sprintf("%s is missing: %s", id,
                               paste(setdiff(needed, arg_ids), collapse = ", ")))
  }
})

test_that("dry-run is offered only where the script honours it", {
  # --dry-run is checked after the mode dispatch, so it does nothing in the
  # review modes.
  has_arg <- function(id, arg) {
    arg %in% vapply(steps_find_tool(id)$args, function(a) a$id, character(1))
  }
  expect_true(has_arg("comment_appendix_build", "dry_run"))
  expect_false(has_arg("comment_appendix_report_changes", "dry_run"))
  expect_false(has_arg("comment_appendix_apply_changes", "dry_run"))
})

test_that("the appendix workbook must pre-exist for the review modes only", {
  must_exist <- function(id, arg) {
    a <- Find(function(x) x$id == arg, steps_find_tool(id)$args)
    isTRUE(a$must_exist)
  }
  expect_false(must_exist("comment_appendix_build", "appendix"))
  expect_true(must_exist("comment_appendix_report_changes", "appendix"))
  expect_true(must_exist("comment_appendix_apply_changes", "appendix"))
})

test_that("the optional-value switch is emitted last", {
  m <- steps_find_tool("comment_appendix_report_changes")
  arg_ids <- vapply(m$args, function(a) a$id, character(1))
  expect_equal(tail(arg_ids, 1), "report_changes")
})


# ---- manifest validation refusals --------------------------------------------

test_that("a manifest missing a required field refuses", {
  for (field in c("id", "name", "description", "runtime", "entry")) {
    m <- test_manifest()
    m[[field]] <- NULL
    res <- steps_validate_manifest(m)
    expect_equal(res$status, "REFUSED")
    expect_equal(res$code, "CFG_STEP_MANIFEST_INVALID")
    expect_true(grepl(field, res$message, fixed = TRUE))
  }
})

test_that("a non-identifier tool id refuses", {
  res <- steps_validate_manifest(test_manifest(id = "Not An Id"))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_STEP_MANIFEST_INVALID")
})

test_that("an unknown argument type refuses and names the type", {
  m <- test_manifest(args = list(
    list(id = "x", label = "X", type = "colour", cli = "--x")
  ))
  res <- steps_validate_manifest(m)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_STEP_ARG_INVALID")
  expect_true(grepl("colour", res$message, fixed = TRUE))
})

test_that("an argument with no cli switch refuses", {
  m <- test_manifest(args = list(
    list(id = "x", label = "X", type = "text", cli = "x")
  ))
  res <- steps_validate_manifest(m)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_STEP_ARG_INVALID")
})

test_that("a choice argument with no choices refuses", {
  m <- test_manifest(args = list(
    list(id = "x", label = "X", type = "choice", cli = "--x")
  ))
  res <- steps_validate_manifest(m)
  expect_equal(res$status, "REFUSED")
  expect_true(grepl("choices", res$message, fixed = TRUE))
})

test_that("duplicate argument ids within a manifest refuse", {
  m <- test_manifest(args = list(
    list(id = "x", label = "X1", type = "text", cli = "--x1"),
    list(id = "x", label = "X2", type = "text", cli = "--x2")
  ))
  res <- steps_validate_manifest(m)
  expect_equal(res$status, "REFUSED")
  expect_true(grepl("x", res$message, fixed = TRUE))
})

test_that("a non-logical required or must_exist refuses", {
  m1 <- test_manifest(args = list(
    list(id = "x", label = "X", type = "text", cli = "--x", required = "yes")
  ))
  expect_equal(steps_validate_manifest(m1)$status, "REFUSED")

  m2 <- test_manifest(args = list(
    list(id = "x", label = "X", type = "file", cli = "--x", must_exist = "yes")
  ))
  expect_equal(steps_validate_manifest(m2)$status, "REFUSED")
})

test_that("duplicate tool ids in the registry refuse", {
  res <- steps_validate_registry(list(test_manifest(), test_manifest()))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_STEP_REGISTRY_INVALID")
  expect_true(grepl("probe_tool", res$message, fixed = TRUE))
})

test_that("a manifest with no args is valid", {
  m <- test_manifest()
  m$args <- NULL
  expect_equal(steps_validate_manifest(m)$status, "PASS")
})

test_that("the comment-appendix steps expose --config and --sheet-map", {
  # A topic-named appendix (sheets called Engagement / Values, not Q17 / Q24) needs a
  # column -> sheet mapping. Without one the builder creates a SECOND set of
  # column-named sheets and leaves the coded ones empty — a run that reports success
  # and produces an appendix the report cannot read. The GUI must offer the same way
  # out the CLI has, or the GUI is the path that quietly gets it wrong.
  manifests <- steps_builtin_manifests()
  appendix_steps <- Filter(function(m) grepl("^comment_appendix", m$id), manifests)
  expect_gt(length(appendix_steps), 0)

  for (m in appendix_steps) {
    clis <- vapply(m$args, function(a) as.character(a$cli %||% ""), character(1))
    expect_true("--config" %in% clis,
      info = paste(m$id, "should offer --config"))
    expect_true("--sheet-map" %in% clis,
      info = paste(m$id, "should offer --sheet-map"))

    # --config picks the columns, so it cannot be combined with the other pickers
    cfg <- m$args[[which(clis == "--config")[1]]]
    expect_equal(cfg$exclusive, "columns",
      info = paste(m$id, "--config must sit in the columns exclusive group"))
    # --sheet-map is NOT a column picker: it must stay combinable with all of them
    smap <- m$args[[which(clis == "--sheet-map")[1]]]
    expect_null(smap$exclusive)
  }
})
