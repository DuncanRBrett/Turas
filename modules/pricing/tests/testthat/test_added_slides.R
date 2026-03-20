# ==============================================================================
# TURAS PRICING MODULE - ADDED SLIDES TESTS
# ==============================================================================
# Tests for: load_added_slides() in 01_config.R
#            build_added_slides_panel() in 03_page_builder.R
# ==============================================================================

# ------------------------------------------------------------------------------
# load_added_slides
# ------------------------------------------------------------------------------

test_that("load_added_slides returns NULL when sheet is absent", {
  # Create a minimal config file without AddedSlides sheet
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "foo", Value = "bar"))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_added_slides(tmp)
  expect_null(result)
})

test_that("load_added_slides reads valid AddedSlides sheet", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "foo", Value = "bar"))

  openxlsx::addWorksheet(wb, "AddedSlides")
  slides_data <- data.frame(
    slide_title = c("Key Finding", "Market Context"),
    content = c("Our product is **competitively priced**", "## Landscape\n- Comp A: $35\n- Comp B: $42"),
    display_order = c(1, 2),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "AddedSlides", slides_data)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_added_slides(tmp)

  expect_true(is.list(result))
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$title, "Key Finding")
  expect_equal(result[[2]]$title, "Market Context")
  expect_true(grepl("competitively priced", result[[1]]$content))
  expect_null(result[[1]]$image_data)
})

test_that("load_added_slides auto-sequences display_order when missing", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "AddedSlides")
  slides_data <- data.frame(
    slide_title = c("Slide A", "Slide B", "Slide C"),
    content = c("Content A", "Content B", "Content C"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "AddedSlides", slides_data)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_added_slides(tmp)

  expect_equal(length(result), 3)
  expect_equal(result[[1]]$order, 1)
  expect_equal(result[[2]]$order, 2)
  expect_equal(result[[3]]$order, 3)
})

test_that("load_added_slides skips empty title rows", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "AddedSlides")
  slides_data <- data.frame(
    slide_title = c("Real Slide", "", NA, "Another Slide"),
    content = c("Content", "", "", "More content"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "AddedSlides", slides_data)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_added_slides(tmp)

  expect_equal(length(result), 2)
  expect_equal(result[[1]]$title, "Real Slide")
  expect_equal(result[[2]]$title, "Another Slide")
})

test_that("load_added_slides returns NULL when required columns missing", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "AddedSlides")
  # Wrong column names
  wrong_data <- data.frame(
    title = c("Slide 1"),
    body = c("Some content"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "AddedSlides", wrong_data)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_added_slides(tmp)
  expect_null(result)
})

test_that("load_added_slides handles Added_Slides alternate sheet name", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Added_Slides")
  slides_data <- data.frame(
    slide_title = c("Test Slide"),
    content = c("Test content"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Added_Slides", slides_data)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_added_slides(tmp)

  expect_equal(length(result), 1)
  expect_equal(result[[1]]$title, "Test Slide")
})


# ------------------------------------------------------------------------------
# build_added_slides_panel
# ------------------------------------------------------------------------------

test_that("build_added_slides_panel renders empty state with no slides", {
  html <- build_added_slides_panel(NULL)

  expect_true(is.character(html))
  expect_true(grepl("panel-slides", html))
  expect_true(grepl("No slides yet", html))
  # Empty state should be visible (no display:none)
  expect_false(grepl('id="pr-slides-empty" style="display:none;', html, fixed = TRUE))
})

test_that("build_added_slides_panel renders config slides", {
  slides <- list(
    list(id = "slide-1", title = "Finding One", content = "Important result", order = 1, image_data = NULL),
    list(id = "slide-2", title = "Finding Two", content = "Another result", order = 2, image_data = NULL)
  )

  html <- build_added_slides_panel(slides)

  expect_true(grepl("Finding One", html))
  expect_true(grepl("Finding Two", html))
  expect_true(grepl("pr-slide-card", html))
  # Empty state should be hidden
  expect_true(grepl('id="pr-slides-empty" style="display:none;', html, fixed = TRUE))
})

test_that("build_added_slides_panel embeds image data", {
  slides <- list(
    list(
      id = "slide-img",
      title = "Image Slide",
      content = "Has an image",
      order = 1,
      image_data = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=="
    )
  )

  html <- build_added_slides_panel(slides)

  expect_true(grepl("data:image/png;base64", html))
  expect_true(grepl("pr-slide-img-thumb", html))
})
