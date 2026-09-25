# ==============================================================================
# CONJOINT - ADVERSARIAL GATE
# ==============================================================================
# One pipeline run (helper_pipeline_fixture.R) with:
#   - level names starting with = - + @ and level names with non-ASCII text
#   - choice-set ids that restart at 1 for every respondent (the set is only
#     unique within a respondent)
# Part-worths, SEs and importance are checked against the hand MNL on the
# same data, with sets keyed by respondent x set; the labels are checked in
# the workbook, the island and the simulator. Estimation is unweighted by
# design (the module takes no weights), so there is no weighted case here.
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)
source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_reference_mnl.R"), local = TRUE)

skip_if_not(requireNamespace("mlogit", quietly = TRUE), "mlogit not installed")

ADV_ATTRS <- list(Brand = c("=Premium", "-Lite", "+Plus"),
                  Colour = c("Café", "Crème brûlée"),
                  Format = c("@Home", "Store", "Online"))
ADV_TRUTH <- c("Brand-Lite" = -0.6, "Brand+Plus" = 0.7, "ColourCrème brûlée" = 0.4,
               "FormatStore" = 0.3, "FormatOnline" = -0.5)
ADV <- generate_synthetic_cbc(n_respondents = 300, n_tasks = 8, n_alts = 3, seed = 17,
                              attributes = ADV_ATTRS, true_utilities = ADV_TRUTH)
# Set ids restart for each respondent: 1..8.
ADV$data$task_id <- ((ADV$data$task_id - 1) %% 8) + 1
PA <- cj_pipe_run(ADV$data, ADV_ATTRS, settings = list(generate_tabs_export = "N"))
ADV$data$set_key <- paste(ADV$data$resp_id, ADV$data$task_id)
REF_A <- cj_ref_mnl(ADV$data, ADV_ATTRS, "set_key")

test_that("the adversarial run completes and writes its deliverables", {
  expect_true(file.exists(PA$workbook), info = paste(tail(PA$log, 30), collapse = "\n"))
  expect_true(file.exists(PA$island))
  expect_true(file.exists(PA$simulator))
})

test_that("part-worths and SEs equal the hand MNL with sets keyed by respondent", {
  pw <- cj_pipe_sheet(PA$workbook, "Part-Worth Utilities")
  pw <- pw[!is.na(pw$Attribute), ]
  pw$Level <- sub("^'", "", pw$Level)   # the shared xlsx escape, see below
  for (a in names(ADV_ATTRS)) {
    lv <- ADV_ATTRS[[a]]
    r <- cj_ref_centred(REF_A$coef, REF_A$vcov, a, lv)
    rows <- pw[pw$Attribute == a, ][match(lv, pw$Level[pw$Attribute == a]), ]
    expect_false(anyNA(rows$Utility), info = a)
    expect_equal(rows$Utility, unname(r$utility), tolerance = 1e-4, info = a)
    expect_equal(rows$Std_Error, unname(r$se), tolerance = 1e-4, info = a)
  }
})

test_that("labels starting with = - + @ and non-ASCII labels survive every deliverable", {
  j <- jsonlite::fromJSON(PA$island)
  for (k in seq_len(nrow(j$utilities))) {
    expect_equal(j$utilities$levels[[k]], ADV_ATTRS[[j$utilities$attribute[k]]])
  }
  h <- paste(readLines(PA$simulator, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(h, regexpr('(?s)<script type="application/json" id="cj-simulator-data">.*?</script>', h, perl = TRUE))
  d <- jsonlite::fromJSON(sub("(?s)^<script[^>]*>", "", sub("</script>$", "", m), perl = TRUE),
                          simplifyVector = FALSE)
  for (at in d$attributes) {
    expect_equal(vapply(at$levels, `[[`, "", "name"), ADV_ATTRS[[at$name]], info = at$name)
  }
  # Workbook: text, never a formula cell. The shared escape may prefix one
  # apostrophe to a leading = - + @ (platform-wide display matter, parked).
  parts <- utils::unzip(PA$workbook, list = TRUE)$Name
  sheets <- grep("^xl/worksheets/sheet[0-9]+[.]xml$", parts, value = TRUE)
  # The Market Simulator sheet holds the module's own formulas; every other
  # sheet must carry none.
  wbxml <- paste(readLines(unz(PA$workbook, "xl/workbook.xml"), warn = FALSE), collapse = "")
  names_in_order <- regmatches(wbxml, gregexpr('(?<=<sheet name=")[^"]+', wbxml, perl = TRUE))[[1]]
  for (i in seq_along(sheets)) {
    sx <- paste0("xl/worksheets/sheet", i, ".xml")
    if (identical(names_in_order[i], "Market Simulator")) next
    xml <- paste(readLines(unz(PA$workbook, sx), warn = FALSE), collapse = "")
    expect_false(grepl("<f>", xml, fixed = TRUE), info = names_in_order[i])
  }
  sd <- cj_pipe_sheet(PA$workbook, "Simulator Data")
  expect_true(all(paste0("Format|", ADV_ATTRS$Format) %in% sub("\\|'", "|", sd$Key)))
})

test_that("the Excel Market Simulator finds every configured level in its lookup table", {
  # Total Utility is VLOOKUP(Attribute & "|" & <product cell>) into the
  # Simulator Data keys, wrapped in IFERROR(..., 0). A product cell whose
  # text does not match a key silently contributes 0. The shared escape
  # writes "=Premium" into a product cell as "'=Premium"; the key column
  # used to be built from the unescaped level, so the lookup missed.
  sd <- cj_pipe_sheet(PA$workbook, "Simulator Data")
  ms <- openxlsx::read.xlsx(PA$workbook, "Market Simulator", colNames = FALSE, skipEmptyRows = FALSE)
  hdr <- which(ms[[1]] == "Attribute")[1]
  rows <- (hdr + 1):(hdr + length(ADV_ATTRS))
  for (r in rows) for (col in 2:6) {
    key <- paste0(ms[[1]][r], "|", ms[[col]][r])
    expect_true(key %in% sd$Key, info = key)
  }
  # And every level a user can pick, as the Level column shows it, has a key.
  expect_true(all(paste0(sd$Attribute, "|", sd$Level)[!is.na(sd$Attribute)] %in% sd$Key))
})
