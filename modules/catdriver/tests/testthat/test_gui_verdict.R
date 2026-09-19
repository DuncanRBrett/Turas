# ==============================================================================
# CATDRIVER - WHAT THE GUI TELLS A USER HAPPENED (H8, review F33)
# ==============================================================================
# The GUI tested result$run_status == "REFUSED". with_refusal_handler() returns
# "REFUSE" for a refusal and "ERROR" for an unexpected error, so neither string
# ever matched: a refused config was announced as
# "complete (status: REFUSE)", counted among the successes, and passed into the
# unified report beside runs that had actually produced numbers.
#
# Session A repaired the refusal system module-wide. Until this lands, none of
# that repair reaches anyone running from the GUI, which is how Duncan runs it.
# ==============================================================================

test_that("a refusal is a failure, with its code and its reason", {
  refusal <- structure(
    list(run_status = "REFUSE", refused = TRUE, code = "CFG_WEIGHT_VAR_NOT_FOUND",
         title = "WEIGHT VARIABLE NOT IN DATA",
         problem = "The config names 'survey_wieght' as the weight variable.",
         how_to_fix = "Check the spelling."),
    class = c("catdriver_refusal_result", "turas_refusal_result")
  )

  verdict <- catdriver_result_status(refusal)

  expect_false(verdict$ok)
  expect_equal(verdict$kind, "refused")
  expect_equal(verdict$status, "REFUSED")
  expect_equal(verdict$code, "CFG_WEIGHT_VAR_NOT_FOUND")
  expect_true(grepl("survey_wieght", verdict$message))
})

test_that("an unexpected error is a failure", {
  err <- structure(
    list(run_status = "ERROR", refused = FALSE, error = TRUE,
         message = "object 'x' not found"),
    class = c("catdriver_error_result", "turas_error_result")
  )

  verdict <- catdriver_result_status(err)
  expect_false(verdict$ok)
  expect_equal(verdict$kind, "error")
  expect_true(grepl("object 'x' not found", verdict$message))
})

test_that("PASS and PARTIAL are the only successes", {
  pass <- catdriver_result_status(list(run_status = "PASS"))
  expect_true(pass$ok)
  expect_equal(pass$kind, "pass")

  partial <- catdriver_result_status(list(run_status = "PARTIAL",
                                          degraded_reasons = c("a", "b")))
  expect_true(partial$ok)
  expect_equal(partial$kind, "partial")
  expect_true(grepl("2 qualifications", partial$message))
})

test_that("a status nobody has seen before is treated as a failure", {
  # The defect in one line: an unrecognised status used to fall through to the
  # success branch, because the code asked "is it REFUSED?" rather than "did it
  # produce results?".
  odd <- catdriver_result_status(list(run_status = "SOMETHING_NEW"))
  expect_false(odd$ok)
  expect_equal(odd$kind, "unknown")
  expect_true(grepl("unrecognised status", odd$message))

  expect_false(catdriver_result_status(NULL)$ok)
  expect_false(catdriver_result_status(list())$ok)
})

test_that("the real refusal object a run produces is classified as failure", {
  skip_if(!exists("with_refusal_handler", mode = "function"), "TRS handler not loaded")

  # Not a hand-built object: the one the module actually returns.
  real <- with_refusal_handler(
    catdriver_refuse(reason = "CFG_TEST_VERDICT", title = "T",
                     problem = "P", why_it_matters = "W", fix = "F")
  )
  expect_equal(real$run_status, "REFUSE")     # the string the old check missed

  verdict <- catdriver_result_status(real)
  expect_false(verdict$ok)
  expect_equal(verdict$code, "CFG_TEST_VERDICT")

  # and the old test, kept here so the regression is visible
  expect_false(isTRUE(real$run_status == "REFUSED"))
})

test_that("the GUI no longer asks whether run_status is REFUSED", {
  gui <- readLines(file.path(turas_root, "modules", "catdriver", "run_catdriver_gui.R"),
                   warn = FALSE)
  code <- gui[!grepl("^\\s*#", gui)]
  expect_false(any(grepl('run_status\\s*==\\s*"REFUSED"', code)))
  expect_false(any(grepl('status\\s*==\\s*"REFUSED"', code)))
  expect_true(any(grepl("catdriver_result_status", code)))
})
