# ==============================================================================
# MAXDIFF TESTS - CONFIGURATION UTILITIES
# ==============================================================================

# ==============================================================================
# parse_yes_no() extended tests
# ==============================================================================

test_that("parse_yes_no handles YES/yes/Yes case variations", {
  expect_true(parse_yes_no("YES"))
  expect_true(parse_yes_no("yes"))
  expect_true(parse_yes_no("Yes"))
  expect_true(parse_yes_no("yEs"))
})

test_that("parse_yes_no handles TRUE/true/1 as truthy", {
  expect_true(parse_yes_no("TRUE"))
  expect_true(parse_yes_no("true"))
  expect_true(parse_yes_no("True"))
  expect_true(parse_yes_no("1"))
  expect_true(parse_yes_no(1))
  expect_true(parse_yes_no(TRUE))
})

test_that("parse_yes_no handles Y/T shorthand as truthy", {
  expect_true(parse_yes_no("Y"))
  expect_true(parse_yes_no("y"))
  expect_true(parse_yes_no("T"))
  expect_true(parse_yes_no("t"))
})

test_that("parse_yes_no handles NO/FALSE/0/N/F as falsy", {
  expect_false(parse_yes_no("NO"))
  expect_false(parse_yes_no("no"))
  expect_false(parse_yes_no("FALSE"))
  expect_false(parse_yes_no("false"))
  expect_false(parse_yes_no("0"))
  expect_false(parse_yes_no(0))
  expect_false(parse_yes_no(FALSE))
  expect_false(parse_yes_no("N"))
  expect_false(parse_yes_no("n"))
  expect_false(parse_yes_no("F"))
  expect_false(parse_yes_no("f"))
})

test_that("parse_yes_no returns default for unrecognized strings", {
  expect_false(parse_yes_no("maybe"))
  expect_false(parse_yes_no("unknown"))
  expect_false(parse_yes_no(""))
  expect_true(parse_yes_no("maybe", default = TRUE))
  expect_true(parse_yes_no("xyz", default = TRUE))
})

test_that("parse_yes_no handles NULL, NA, and empty inputs", {
  expect_false(parse_yes_no(NULL))
  expect_false(parse_yes_no(NA))
  expect_false(parse_yes_no(character(0)))
  expect_true(parse_yes_no(NULL, default = TRUE))
  expect_true(parse_yes_no(NA, default = TRUE))
})

test_that("parse_yes_no handles vector input (takes first element)", {
  expect_true(parse_yes_no(c("YES", "NO")))
  expect_false(parse_yes_no(c("NO", "YES")))
})

# ==============================================================================
# safe_numeric() extended tests
# ==============================================================================

test_that("safe_numeric converts valid numeric strings", {
  expect_equal(safe_numeric("3.14"), 3.14)
  expect_equal(safe_numeric("42"), 42)
  expect_equal(safe_numeric("-7.5"), -7.5)
  expect_equal(safe_numeric("0"), 0)
  expect_equal(safe_numeric("1e3"), 1000)
})

test_that("safe_numeric passes through numeric values", {
  expect_equal(safe_numeric(42), 42)
  expect_equal(safe_numeric(3.14), 3.14)
  expect_equal(safe_numeric(-1L), -1)
})

test_that("safe_numeric returns default for invalid input", {
  expect_equal(safe_numeric("not_a_number", default = 0), 0)
  expect_equal(safe_numeric("abc", default = -1), -1)
  expect_equal(safe_numeric("", default = 99), 99)
})

test_that("safe_numeric returns default for NULL, NA, empty", {
  expect_equal(safe_numeric(NULL, default = -1), -1)
  expect_equal(safe_numeric(NA, default = 99), 99)
  expect_equal(safe_numeric(numeric(0), default = 5), 5)
  expect_equal(safe_numeric(character(0), default = 10), 10)
})

test_that("safe_numeric default is NA_real_ when not specified", {
  result <- safe_numeric("invalid")
  expect_true(is.na(result))
})

# ==============================================================================
# safe_integer() extended tests
# ==============================================================================

test_that("safe_integer converts valid inputs", {
  expect_equal(safe_integer("5"), 5L)
  expect_equal(safe_integer(10), 10L)
  expect_equal(safe_integer(3.7), 3L)  # truncates
  expect_equal(safe_integer("100"), 100L)
})

test_that("safe_integer returns default for invalid input", {
  expect_equal(safe_integer("abc", default = 0), 0L)
  expect_equal(safe_integer("3.14.15", default = -1), -1L)
})

test_that("safe_integer returns default for NULL, NA, empty", {
  expect_equal(safe_integer(NULL, default = 0), 0L)
  expect_equal(safe_integer(NA, default = 5), 5L)
  expect_equal(safe_integer(numeric(0), default = 7), 7L)
  expect_equal(safe_integer(character(0), default = 3), 3L)
})

test_that("safe_integer result is integer type", {
  result <- safe_integer("42")
  expect_true(is.integer(result))
})

# ==============================================================================
# Config validation: missing required fields
# ==============================================================================

test_that("validate_option refuses NULL value", {
  skip_if(!exists("validate_option", mode = "function"))

  result <- tryCatch(
    validate_option(NULL, c("YES", "NO"), "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_option refuses NA value", {
  skip_if(!exists("validate_option", mode = "function"))

  result <- tryCatch(
    validate_option(NA, c("YES", "NO"), "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_positive_integer refuses negative values", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- tryCatch(
    validate_positive_integer(-5, "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_positive_integer refuses non-numeric strings", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- tryCatch(
    validate_positive_integer("abc", "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_positive_integer refuses NULL", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- tryCatch(
    validate_positive_integer(NULL, "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_numeric_range refuses out-of-range values", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  result <- tryCatch(
    validate_numeric_range(150, "test_param", min_val = 0, max_val = 100),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_numeric_range accepts in-range values", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  result <- validate_numeric_range(50, "test_param", min_val = 0, max_val = 100)
  expect_equal(result, 50)
})

test_that("validate_file_path refuses NULL path", {
  skip_if(!exists("validate_file_path", mode = "function"))

  result <- tryCatch(
    validate_file_path(NULL, "test_path"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_file_path refuses empty string", {
  skip_if(!exists("validate_file_path", mode = "function"))

  result <- tryCatch(
    validate_file_path("", "test_path"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_file_path refuses non-existent file", {
  skip_if(!exists("validate_file_path", mode = "function"))

  result <- tryCatch(
    validate_file_path("/nonexistent/path/file.xlsx", "test_path", must_exist = TRUE),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_file_path refuses wrong extension", {
  skip_if(!exists("validate_file_path", mode = "function"))

  tmp <- tempfile(fileext = ".csv")
  writeLines("test", tmp)

  result <- tryCatch(
    validate_file_path(tmp, "test_path", must_exist = TRUE, extensions = c("xlsx")),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))

  unlink(tmp)
})


# ==============================================================================
# A6 (H6): the shipped template loads through the real loader
# ==============================================================================

test_that("H6: the generated template round-trips through load_maxdiff_config", {
  tpl_script <- file.path(TURAS_ROOT, "modules", "maxdiff", "templates",
                          "create_maxdiff_template.R")
  skip_if(!file.exists(tpl_script), "template generator not present")

  out <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out), add = TRUE)

  # Generate without triggering the run-if-executed block
  env <- new.env()
  assign("TURAS_LAUNCHER_ACTIVE", TRUE, envir = env)
  sys.source(tpl_script, envir = env)
  capture.output(env$create_maxdiff_template(out))

  # The old template refused in three separate ways (pattern-schema
  # SURVEY_MAPPING, per-level SEGMENT_SETTINGS, sheet="1"): it could not
  # complete a run at all. The regenerated one must load clean.
  cfg <- load_maxdiff_config(out)

  expect_equal(cfg$mode, "DESIGN")
  expect_true(is.integer(cfg$project_settings$Data_File_Sheet))
  expect_equal(cfg$project_settings$Choice_Value_Type, "ITEM_ID")
  expect_true(all(c("Field_Type", "Field_Name", "Task_Number") %in%
                    names(cfg$survey_mapping)))
  expect_true(all(cfg$survey_mapping$Field_Type %in%
                    c("VERSION", "BEST_CHOICE", "WORST_CHOICE")))
  expect_equal(nrow(cfg$segment_settings), 3)
  expect_true(all(c("Segment_ID", "Segment_Label", "Variable_Name") %in%
                    names(cfg$segment_settings)))
  expect_true(isTRUE(cfg$output_settings$Generate_HTML_Report))
  # Score_Rescale_Method reaches the engine (the old Utility_Scale row was
  # silently dropped).
  expect_equal(cfg$output_settings$Score_Rescale_Method, "0_100")
})

test_that("M10: a duplicate setting row refuses; an unknown one warns", {
  df_dup <- data.frame(Setting_Name = c("Project_Name", "Mode", "Seed", "Seed"),
                       Value = c("X", "DESIGN", "1", "2"),
                       stringsAsFactors = FALSE)
  expect_error(parse_project_settings(df_dup, project_root = "."),
               "CFG_DUPLICATE_SETTING|more than once")

  df_unknown <- data.frame(Setting_Name = c("Project_Name", "Mode", "Porject_Nmae"),
                           Value = c("X", "DESIGN", "oops"),
                           stringsAsFactors = FALSE)
  out <- capture.output(res <- parse_project_settings(df_unknown, project_root = "."))
  expect_true(any(grepl("MAXD_UNKNOWN_SETTINGS", out)))
  expect_true(any(grepl("Porject_Nmae", out)))
})
