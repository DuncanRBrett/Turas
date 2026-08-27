# ==============================================================================
# TESTS: A GENERATED TEMPLATE IS A CONFIG THIS MODULE CAN LOAD
# ==============================================================================
#
# There was no test that the module's own template survives its own loader.
# It did not: the template shipped Project_Name/Analyst_Name in a STUDY
# IDENTIFICATION section AND project_name/analyst_name under HTML REPORT, so
# once duplicate settings became a refusal (M5), every freshly generated
# template refused to load and no new project could start.
#
# This is the gate that should have caught it.
# ==============================================================================

make_template <- function() {
  path <- tempfile(fileext = ".xlsx")
  invisible(capture.output(
    generate_conjoint_config_template(output_path = path),
    type = "output"
  ))
  path
}

test_that("a bare template refuses, naming the Attributes sheet", {
  # The template's example attribute rows are prefixed and skipped, so a
  # template nobody has filled in has no attributes at all. That must refuse
  # with instructions, not run a phone study the user never designed.
  path <- make_template()
  on.exit(unlink(path), add = TRUE)

  cond <- tryCatch(
    {
      invisible(capture.output(load_conjoint_config(path, verbose = FALSE),
                               type = "output"))
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "CFG_NO_ATTRIBUTES_DEFINED")
})

test_that("a generated template loads once its Attributes sheet is filled in", {
  path <- make_template()
  on.exit(unlink(path), add = TRUE)
  expect_true(file.exists(path))

  # The loader needs data_file to resolve, so point it at something real.
  wb <- openxlsx::loadWorkbook(path)
  sh <- openxlsx::read.xlsx(path, sheet = "Settings", colNames = FALSE,
                            skipEmptyRows = FALSE)
  data_row <- which(tolower(trimws(as.character(sh[[1]]))) == "data_file")
  expect_length(data_row, 1)

  csv <- file.path(dirname(path), "roundtrip_data.csv")
  write.csv(data.frame(a = 1), csv, row.names = FALSE)
  on.exit(unlink(csv), add = TRUE)

  openxlsx::writeData(wb, "Settings", basename(csv),
                      startRow = data_row, startCol = 2, colNames = FALSE)

  # Fill in two real attributes, as a user would.
  attr_hdr <- find_config_header_row(path, "Attributes",
                                     c("AttributeName", "NumLevels", "LevelNames"))
  real <- data.frame(
    AttributeName = c("Flavour", "Pack"),
    NumLevels = c(3, 2),
    LevelNames = c("Plain, Salted, Smoked", "Box, Bag"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Attributes", real,
                      startRow = attr_hdr + 1, startCol = 1, colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  config <- NULL
  cond <- tryCatch(
    {
      invisible(capture.output(
        config <- load_conjoint_config(path, verbose = FALSE),
        type = "output"
      ))
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_null(cond,
              info = if (is.null(cond)) "" else paste(cond$code, cond$problem))
  expect_false(is.null(config))
  expect_gt(nrow(config$attributes), 0)
})

test_that("a generated template has no duplicated setting names", {
  path <- make_template()
  on.exit(unlink(path), add = TRUE)

  hdr <- find_config_header_row(path, "Settings", c("Setting", "Value"))
  df <- .clean_settings_df(openxlsx::read.xlsx(path, sheet = "Settings",
                                               startRow = hdr))
  names_seen <- tolower(trimws(as.character(df$Setting)))
  names_seen <- names_seen[!is.na(names_seen) & nzchar(names_seen)]

  dups <- unique(names_seen[duplicated(names_seen)])
  expect_equal(dups, character(0))
})

test_that("every setting the template offers is one the module reads", {
  path <- make_template()
  on.exit(unlink(path), add = TRUE)

  hdr <- find_config_header_row(path, "Settings", c("Setting", "Value"))
  df <- .clean_settings_df(openxlsx::read.xlsx(path, sheet = "Settings",
                                               startRow = hdr))
  offered <- tolower(trimws(as.character(df$Setting)))
  offered <- offered[!is.na(offered) & nzchar(offered)]

  known <- tolower(.known_conjoint_settings())
  dead <- setdiff(offered, known)

  # A template knob the loader never reads is a promise the module does not
  # keep. There are none left; a new one has to be deliberate.
  expect_equal(dead, character(0),
               info = paste("dead template settings:",
                            paste(dead, collapse = ", ")))
})

test_that("no retired setting has crept back into the template", {
  path <- make_template()
  on.exit(unlink(path), add = TRUE)

  hdr <- find_config_header_row(path, "Settings", c("Setting", "Value"))
  df <- .clean_settings_df(openxlsx::read.xlsx(path, sheet = "Settings",
                                               startRow = hdr))
  offered <- tolower(trimws(as.character(df$Setting)))
  offered <- offered[!is.na(offered) & nzchar(offered)]

  expect_equal(intersect(offered, names(CONJOINT_RETIRED_SETTINGS)), character(0))
})
