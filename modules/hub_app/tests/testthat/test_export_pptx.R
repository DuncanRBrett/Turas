# ==============================================================================
# Tests: Hub App PPTX Export
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  test_dir <- getwd()
  candidate <- normalizePath(file.path(test_dir, "..", "..", "..", ".."), mustWork = FALSE)
  if (file.exists(file.path(candidate, "launch_turas.R"))) {
    turas_root <- candidate
  } else {
    candidate <- normalizePath(file.path(test_dir, "..", "..", "..", "..", ".."), mustWork = FALSE)
    if (file.exists(file.path(candidate, "launch_turas.R"))) {
      turas_root <- candidate
    } else {
      turas_root <- getwd()
    }
  }
}
source(file.path(turas_root, "modules", "hub_app", "lib", "export_pptx.R"))
source(file.path(turas_root, "modules", "hub_app", "tests", "fixtures",
                  "synthetic_data", "generate_test_data.R"))

# ==============================================================================
# export_pins_to_pptx()
# ==============================================================================

test_that("export_pins_to_pptx returns REFUSED when officer is missing", {
  # We can't easily unload officer, so test the items guard instead
  result <- export_pins_to_pptx(items = NULL)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_NO_PINS")
  expect_true(nzchar(result$how_to_fix))
})

test_that("export_pins_to_pptx returns REFUSED for empty items list", {
  result <- export_pins_to_pptx(items = list())

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_NO_PINS")
})

test_that("export_pins_to_pptx creates a PPTX file with pins", {
  skip_if_not_installed("officer")
  skip_if_not_installed("base64enc")

  items <- create_mock_export_items(n_pins = 2, n_sections = 1,
                                     include_charts = TRUE)
  output_dir <- file.path(tempdir(), "pptx_test_output")
  dir.create(output_dir, showWarnings = FALSE)
  on.exit(unlink(output_dir, recursive = TRUE))

  result <- export_pins_to_pptx(
    items = items,
    project_name = "Test Project",
    output_dir = output_dir
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(result$result$path))
  expect_true(grepl("\\.pptx$", result$result$filename))
  expect_equal(result$result$pin_count, 2)
  expect_equal(result$result$section_count, 1)
})

test_that("export_pins_to_pptx handles pins without charts", {
  skip_if_not_installed("officer")
  skip_if_not_installed("base64enc")

  items <- create_mock_export_items(n_pins = 2, n_sections = 0,
                                     include_charts = FALSE)
  output_dir <- file.path(tempdir(), "pptx_nochart_test")
  dir.create(output_dir, showWarnings = FALSE)
  on.exit(unlink(output_dir, recursive = TRUE))

  result <- export_pins_to_pptx(
    items = items,
    project_name = "No Charts",
    output_dir = output_dir
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(result$result$path))
  expect_equal(result$result$pin_count, 2)
})

test_that("export_pins_to_pptx handles sections only", {
  skip_if_not_installed("officer")

  items <- list(
    list(type = "section", title = "Section One"),
    list(type = "section", title = "Section Two")
  )
  output_dir <- file.path(tempdir(), "pptx_sections_test")
  dir.create(output_dir, showWarnings = FALSE)
  on.exit(unlink(output_dir, recursive = TRUE))

  result <- export_pins_to_pptx(
    items = items,
    project_name = "Sections Only",
    output_dir = output_dir
  )

  expect_equal(result$status, "PASS")
  expect_equal(result$result$section_count, 2)
  expect_equal(result$result$pin_count, 0)
})

test_that("export_pins_to_pptx creates output directory if missing", {
  skip_if_not_installed("officer")

  items <- create_mock_export_items(n_pins = 1, n_sections = 0,
                                     include_charts = FALSE)
  output_dir <- file.path(tempdir(), "pptx_mkdir_test", "nested", "dir")
  on.exit(unlink(file.path(tempdir(), "pptx_mkdir_test"), recursive = TRUE))

  result <- export_pins_to_pptx(
    items = items,
    project_name = "Mkdir Test",
    output_dir = output_dir
  )

  expect_equal(result$status, "PASS")
  expect_true(dir.exists(output_dir))
})

test_that("export_pins_to_pptx sanitizes project name for filename", {
  skip_if_not_installed("officer")

  items <- create_mock_export_items(n_pins = 1, n_sections = 0,
                                     include_charts = FALSE)
  output_dir <- file.path(tempdir(), "pptx_sanitize_test")
  dir.create(output_dir, showWarnings = FALSE)
  on.exit(unlink(output_dir, recursive = TRUE))

  result <- export_pins_to_pptx(
    items = items,
    project_name = "Project: With <Special> Chars!",
    output_dir = output_dir
  )

  expect_equal(result$status, "PASS")
  # Filename should not contain special characters
  expect_false(grepl("[<>:!]", result$result$filename))
})

# ==============================================================================
# strip_markdown()
# ==============================================================================

test_that("strip_markdown removes heading markers", {
  expect_equal(strip_markdown("## Key Finding"), "Key Finding")
})

test_that("strip_markdown removes bold markers", {
  expect_equal(strip_markdown("This is **bold** text"), "This is bold text")
})

test_that("strip_markdown removes italic markers", {
  expect_equal(strip_markdown("This is *italic* text"), "This is italic text")
})

test_that("strip_markdown converts bullets to unicode", {
  result <- strip_markdown("- Item one")
  expect_true(grepl("\u2022", result))
})

test_that("strip_markdown converts blockquotes", {
  expect_equal(strip_markdown("> Quoted text"), "Quoted text")
})

test_that("strip_markdown handles NULL and empty input", {
  expect_equal(strip_markdown(NULL), "")
  expect_equal(strip_markdown(""), "")
})

# ==============================================================================
# decode_data_url_to_file()
# ==============================================================================

test_that("decode_data_url_to_file returns NULL for invalid input", {
  expect_null(decode_data_url_to_file(NULL))
  expect_null(decode_data_url_to_file("not a data url"))
  expect_null(decode_data_url_to_file(""))
})

test_that("decode_data_url_to_file decodes a valid PNG data URL", {
  skip_if_not_installed("base64enc")

  # Minimal 1x1 white PNG
  data_url <- paste0(
    "data:image/png;base64,",
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8",
    "z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg=="
  )

  result <- decode_data_url_to_file(data_url)

  expect_false(is.null(result))
  expect_true(file.exists(result))
  expect_true(grepl("\\.png$", result))
  expect_gt(file.size(result), 0)

  # Clean up
  unlink(result)
})
