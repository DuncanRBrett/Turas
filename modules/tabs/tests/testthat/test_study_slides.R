# ==============================================================================
# TABS MODULE - STUDY SLIDES (config AddedSlides sheet -> the v2 report)
# ==============================================================================
#
# The AddedSlides sheet was read by load_qualitative_sheet() and then dropped on
# the floor: nothing in the module consumed config_obj$qualitative_slides, so a
# filled-in sheet had no effect on any report. These tests cover the wiring that
# carries it through, and the two guards added with it:
#
#   - .slide_image_pixel_size(): intrinsic size read from the file's own header,
#     in base R, so a slide exported to PowerPoint keeps its aspect ratio
#   - TABS_SLIDE_IMAGE_MAX_BYTES: the config route embeds at BUILD time and had
#     no size limit at all — an oversized picture is refused (loudly) and the
#     slide keeps its text, rather than a 12 MB report nobody can send
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_study_slides.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))

# ==============================================================================
# FIXTURES — real image files, written by base R's own devices
# ==============================================================================

# Genuine PNG/JPEG/GIF-less fixtures: grDevices writes real files, so the header
# parser is tested against actual encoder output rather than bytes we invented.
make_png <- function(dir, w, h, name = "slide.png") {
  p <- file.path(dir, name)
  grDevices::png(p, width = w, height = h)
  graphics::plot.new()
  grDevices::dev.off()
  p
}
make_jpeg <- function(dir, w, h, name = "slide.jpg") {
  p <- file.path(dir, name)
  grDevices::jpeg(p, width = w, height = h)
  graphics::plot.new()
  grDevices::dev.off()
  p
}

# A config workbook carrying only what the slides loader reads.
write_slides_config <- function(dir, rows) {
  path <- file.path(dir, "cfg.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "AddedSlides")
  openxlsx::writeData(wb, "AddedSlides", rows)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

# ==============================================================================
# 1. Header parsing
# ==============================================================================

context("study slides: intrinsic image size")

test_that("pixel size is read from a real PNG and a real JPEG header", {
  d <- tempfile("slidesize"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  png_path <- make_png(d, 640, 360)
  raw_png <- readBin(png_path, "raw", file.info(png_path)$size)
  expect_equal(.slide_image_pixel_size(raw_png, "png"), list(w = 640L, h = 360L))

  jpg_path <- make_jpeg(d, 800, 200)
  raw_jpg <- readBin(jpg_path, "raw", file.info(jpg_path)$size)
  expect_equal(.slide_image_pixel_size(raw_jpg, "jpg"), list(w = 800L, h = 200L))
  expect_equal(.slide_image_pixel_size(raw_jpg, "jpeg"), list(w = 800L, h = 200L))
})

test_that("a format with no readable header returns NULL rather than a guess", {
  # NULL is the honest answer: the report still shows the picture, and only the
  # PowerPoint export loses the aspect ratio. Inventing a size would silently
  # distort a slide in a client deck.
  expect_null(.slide_image_pixel_size(as.raw(c(1, 2, 3, 4)), "svg"))
  expect_null(.slide_image_pixel_size(as.raw(c(1, 2, 3, 4)), "webp"))
  expect_null(.slide_image_pixel_size(as.raw(c(1, 2, 3, 4)), "png"))   # bad signature
  expect_null(.slide_image_pixel_size(raw(0), "png"))                  # empty file
  # a JPEG truncated mid-marker must not loop or error
  expect_null(.slide_image_pixel_size(as.raw(c(255, 216, 255, 224, 0, 16)), "jpg"))
})

# ==============================================================================
# 2. The loader
# ==============================================================================

context("study slides: AddedSlides loader")

test_that("a slide's image is embedded with its intrinsic size", {
  d <- tempfile("slideload"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  make_png(d, 320, 240, "pic.png")
  cfg <- write_slides_config(d, data.frame(
    slide_title = "Qual phase", content = "Six groups.", image_path = "pic.png",
    stringsAsFactors = FALSE))

  slides <- load_qualitative_sheet(cfg)
  expect_length(slides, 1)
  expect_equal(slides[[1]]$title, "Qual phase")
  expect_true(grepl("^data:image/png;base64,", slides[[1]]$image_data))
  expect_equal(slides[[1]]$image_w, 320L)
  expect_equal(slides[[1]]$image_h, 240L)
})

test_that("an oversized image is refused loudly, and the slide keeps its text", {
  d <- tempfile("slidebig"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  big <- file.path(d, "huge.png")
  writeBin(as.raw(rep(0L, TABS_SLIDE_IMAGE_MAX_BYTES + 1)), big)
  cfg <- write_slides_config(d, data.frame(
    slide_title = "Too big", content = "Words survive.", image_path = "huge.png",
    stringsAsFactors = FALSE))

  out <- capture.output(slides <- load_qualitative_sheet(cfg))

  expect_length(slides, 1)
  expect_null(slides[[1]]$image_data)               # the picture is left out…
  expect_equal(slides[[1]]$content, "Words survive.")  # …the slide is not
  # Turas runs behind a Shiny app: the operator only ever sees the console, so
  # a refusal that does not print there is a silent failure.
  joined <- paste(out, collapse = "\n")
  expect_true(grepl("SLIDE IMAGE TOO LARGE", joined))
  expect_true(grepl("Too big", joined))
  expect_true(grepl("huge.png", joined))
})

test_that("an image just under the limit is still embedded", {
  d <- tempfile("slideedge"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  ok <- file.path(d, "ok.png")
  writeBin(as.raw(rep(0L, TABS_SLIDE_IMAGE_MAX_BYTES - 1)), ok)
  cfg <- write_slides_config(d, data.frame(
    slide_title = "Fits", content = "", image_path = "ok.png",
    stringsAsFactors = FALSE))

  slides <- load_qualitative_sheet(cfg)
  expect_true(grepl("^data:image/png;base64,", slides[[1]]$image_data))
  # no header on this filler, so no size — and that must not fail the load
  expect_null(slides[[1]]$image_w)
})

test_that("the sheet reaches config_obj through the REAL config loader", {
  # The join that mattered: this feature spent its whole life loading correctly
  # and being consumed by nothing. Unit-testing load_qualitative_sheet() would
  # have passed throughout. So drive the real load_crosstabs_config() over a real
  # config workbook and assert the slides come out the other end, on the object
  # run_crosstabs actually hands to the data-layer writer
  # (run_crosstabs.R: config_result$config_obj -> build_data_layer).
  demo_dir <- file.path(turas_root, "examples/tabs/demo_survey")
  skip_if_not(file.exists(file.path(demo_dir, "Demo_Crosstab_Config.xlsx")),
    "Demo survey fixture not found")

  d <- tempfile("slidee2e"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  file.copy(list.files(demo_dir, full.names = TRUE), d, recursive = TRUE)
  cfg <- file.path(d, "Demo_Crosstab_Config.xlsx")
  make_png(d, 500, 250, "pic.png")

  wb <- openxlsx::loadWorkbook(cfg)
  openxlsx::addWorksheet(wb, "AddedSlides")
  openxlsx::writeData(wb, "AddedSlides", data.frame(
    slide_title = "Qual exhibit", content = "From the groups.",
    image_path = "pic.png", stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, cfg, overwrite = TRUE)

  res <- suppressMessages(load_crosstabs_config(cfg))
  slides <- res$config_obj$qualitative_slides

  expect_length(slides, 1)
  expect_equal(slides[[1]]$title, "Qual exhibit")
  expect_true(grepl("^data:image/png;base64,", slides[[1]]$image_data))
  expect_equal(c(slides[[1]]$image_w, slides[[1]]$image_h), c(500L, 250L))
})

test_that("a missing image file says so loudly and keeps the slide", {
  d <- tempfile("slidegone"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  cfg <- write_slides_config(d, data.frame(
    slide_title = "No picture", content = "Text only.", image_path = "nope.png",
    stringsAsFactors = FALSE))

  out <- capture.output(slides <- load_qualitative_sheet(cfg))
  joined <- paste(out, collapse = "\n")
  expect_length(slides, 1)
  expect_null(slides[[1]]$image_data)
  expect_equal(slides[[1]]$content, "Text only.")
  expect_true(grepl("SLIDE IMAGE NOT FOUND", joined))
  expect_true(grepl("No picture", joined))
  # the path it actually looked at, so the operator can see the resolution
  expect_true(grepl("nope.png", joined))
})

test_that("a path pasted with quotes around it still resolves", {
  # Found the hard way on CCPB (2026-08-11): the image_path cell held
  # /Users/…/RatingsMap.png' — one trailing apostrophe, picked up from copying
  # the path. The file existed, the path looked right in the sheet, and the
  # slide rendered text-only. Dragging a file into a terminal or using a
  # "copy as path" command is the normal way to fill this cell, so wrapping
  # quotes are tolerated rather than punished.
  d <- tempfile("slidequote"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  make_png(d, 320, 240, "pic.png")
  abs_path <- file.path(d, "pic.png")

  variants <- list(
    paste0(abs_path, "'"),          # the real CCPB case: trailing only
    paste0("'", abs_path, "'"),     # both, single
    paste0('"', abs_path, '"'),     # both, double
    paste0("  '", abs_path, "'  ")  # and with stray whitespace
  )
  for (v in variants) {
    cfg <- write_slides_config(d, data.frame(
      slide_title = "Quoted", content = "", image_path = v,
      stringsAsFactors = FALSE))
    slides <- suppressWarnings(load_qualitative_sheet(cfg))
    expect_true(grepl("^data:image/png;base64,", slides[[1]]$image_data), info = v)
    expect_equal(slides[[1]]$image_w, 320L, info = v)
  }
})
