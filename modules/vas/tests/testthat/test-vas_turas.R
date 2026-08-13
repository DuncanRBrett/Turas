# test-vas_turas.R
# The Turas dataset layer: the column plan is the contract, the register gate
# refuses undecided rows, and the assembled data matches the structure.

turas_fixture_index <- function() {
  data.frame(
    alias = c("BankMain", "Awareness", "WC_Town", "Province"),
    type = c("RADIO", "CHECKBOX", "RADIO", "RADIO"),
    q_title = c("What is your main bank?", "Which channels are you aware of?",
                "Which town?", "Which province?"),
    stringsAsFactors = FALSE
  )
}

turas_fixture_headers <- function() {
  c("Response ID", "Status", "Longitude", "gps_maps",
    "Supervisor", "Other (Specify):Supervisor",
    "PPUOwnFreq1", "AirtimeOwnAmount",
    "BankMain", "Other (Specify):BankMain", "Province",
    "Bank: ATM:Awareness", "Bank: on their website:Awareness",
    "Other (Please Specify):Awareness", "Other (Please Specify):Awareness",
    "WC_Town", "Other (Specify):WC_Town")
}

turas_fixture_plan <- function() {
  build_turas_column_plan(turas_fixture_headers(), fixture_real_map(),
                          turas_fixture_index())
}

test_that("headers split on the LAST colon, so option titles keep theirs", {
  parts <- split_export_header(c("Bank: ATM:Awareness", "BankMain"))
  expect_equal(parts$option_title, c("Bank: ATM", NA))
  expect_equal(parts$alias, c("Awareness", "BankMain"))
})

test_that("the plan classifies every column the documented way", {
  plan <- turas_fixture_plan()
  action_of <- function(header) plan$action[match(header, plan$export_header)]

  expect_equal(action_of("Response ID"), "id")
  expect_equal(action_of("Status"), "keep")           # rides in as ResponseStatus
  expect_equal(action_of("Longitude"), "drop")        # admin
  expect_equal(action_of("gps_maps"), "drop")         # GPS machinery
  expect_equal(action_of("Supervisor"), "drop")       # QC field
  expect_equal(action_of("PPUOwnFreq1"), "engine")    # consumed by the derivation
  expect_equal(action_of("AirtimeOwnAmount"), "engine")
  expect_equal(action_of("BankMain"), "keep")
  # a single-choice question's write-in column must NOT become a checkbox
  # member - that declared 21 questions twice (found by the pilot check)
  expect_equal(action_of("Other (Specify):BankMain"), "drop")
  expect_equal(action_of("Bank: ATM:Awareness"), "multi")
  expect_equal(action_of("WC_Town"), "merge_town")
  expect_equal(action_of("Other (Specify):WC_Town"), "drop")   # write-in twin

  # the DUPLICATED "Other (Please Specify)" header: option column kept,
  # write-in twin dropped
  other_rows <- plan[plan$export_header == "Other (Please Specify):Awareness", ]
  expect_equal(sort(other_rows$action), c("drop", "multi"))
})

test_that("the plan refuses when the export and the plan disagree", {
  plan <- turas_fixture_plan()
  expect_error(verify_plan_covers_export(c(turas_fixture_headers(), "NewQuestion"), plan),
               class = "vas_plan_mismatch")
  expect_error(verify_plan_covers_export(turas_fixture_headers()[-3], plan),
               class = "vas_plan_mismatch")
  expect_true(verify_plan_covers_export(turas_fixture_headers(), plan))
})

test_that("a kept structure is verified against the data, not overwritten", {
  path <- file.path(tempdir(), "alignment_structure.xlsx")
  on.exit(unlink(path), add = TRUE)
  questions <- data.frame(
    QuestionCode = c("BankMain", "Awareness"), QuestionText = c("q1", "q2"),
    Variable_Type = c("Single_Response", "Multi_Mention"), Columns = c(1L, 2L),
    stringsAsFactors = FALSE)
  options <- data.frame(QuestionCode = "BankMain", OptionText = "Capitec",
                        DisplayText = "Capitec", DisplayOrder = 1L,
                        stringsAsFactors = FALSE)
  write_turas_structure(questions, options, "data.xlsx", path)

  aligned <- data.frame(ResponseID = "1", BankMain = "Capitec",
                        Awareness_1 = "a", Awareness_2 = "b",
                        check.names = FALSE, stringsAsFactors = FALSE)
  expect_true(verify_structure_alignment(path, aligned))

  drifted <- aligned
  drifted$Awareness_2 <- NULL
  drifted$NewColumn <- "x"
  expect_error(verify_structure_alignment(path, drifted),
               class = "vas_structure_stale")
})

test_that("the register gate refuses undecided rows unless smoke testing", {
  register <- data.frame(
    check.names = FALSE, stringsAsFactors = FALSE,
    `Response ID` = c("1", "2", "3"),
    Disposition = c("Include", "Review", "Exclude")
  )
  expect_error(verify_register_decided(register, c("1", "2", "3")),
               class = "vas_register_undecided")
  # a Review row that is not in this export does not block
  expect_true(verify_register_decided(register, c("1", "3")))
  expect_output(
    expect_true(verify_register_decided(register, c("1", "2", "3"), allow_review = TRUE)),
    "SMOKE TEST")
})

test_that("the assembled data matches the generated structure", {
  headers <- turas_fixture_headers()
  plan <- turas_fixture_plan()
  index <- turas_fixture_index()
  options <- data.frame(
    alias = c("BankMain", "BankMain", "Awareness", "Awareness", "Awareness",
              "Province", "WC_Town"),
    position = c(1, 2, 1, 2, 3, 1, 1),
    value = c("Capitec", "FNB", "Bank ATM", "Bank Website", "Other", "Western Cape",
              "Paarl"),
    title = c("Capitec", "FNB", "Bank: ATM", "Bank: on their website",
              "Other (Please Specify)", "Western Cape", "Paarl"),
    stringsAsFactors = FALSE
  )
  source_data <- new_vas_source(
    origin = "export", response_id = c("1", "2"), status = c("Complete", "Partial"),
    columns = stats::setNames(
      list(c("1", "2"), c("Complete", "Partial"), c(NA, NA), c(NA, NA),
           c("Megan", "Jacky"), c(NA, NA),
           c(NA, NA), c(NA, NA),
           c("Capitec", "FNB"), c(NA, NA), c("Western Cape", NA),
           c("Bank ATM", NA), c(NA, "Bank Website"),
           c(NA, NA), c(NA, NA),
           c("Paarl", NA), c(NA, NA)),
      headers)
  )
  wide <- data.frame(
    ResponseID = c("1", "2"), ResponseStatus = c("Complete", "Partial"),
    TotalValueTransacted = c(100, NA), BuysForOthers = c(TRUE, NA),
    stringsAsFactors = FALSE
  )

  data <- assemble_turas_data(source_data, plan, options, wide)

  expect_equal(data$ResponseID, c("1", "2"))
  expect_equal(data$BankMain, c("Capitec", "FNB"))
  expect_equal(data$Awareness_1, c("Bank ATM", NA))
  expect_equal(data$Awareness_2, c(NA, "Bank Website"))
  expect_equal(data$Town, c("Paarl", NA))
  expect_equal(data$TotalValueTransacted, c(100, NA))
  expect_equal(data$BuysForOthers, c("Yes", NA))     # logical -> Yes/No text

  content <- content_structure_rows(plan, index, options,
                                    sort(unique(stats::na.omit(data$Town))))
  # every declared content data column exists in the data
  for (i in seq_len(nrow(content$questions))) {
    code <- content$questions$QuestionCode[i]
    expected <- if (content$questions$Variable_Type[i] == "Multi_Mention") {
      sprintf("%s_%d", code, seq_len(content$questions$Columns[i]))
    } else code
    expect_true(all(expected %in% names(data)), info = code)
  }
  # OptionText carries the VALUE the export writes, not the display title
  awareness_options <- content$options[content$options$QuestionCode == "Awareness_1", ]
  expect_equal(awareness_options$OptionText, "Bank ATM")
  expect_equal(awareness_options$DisplayText, "Bank: ATM")
})

test_that("a kept structure in the modern template format is read past its title block", {
  # title row, notes row, headers, a [REQUIRED] help row, then the data -
  # the format generate_config_templates.R produces and the tabs engine
  # already reads by scanning for the header row
  path <- file.path(tempdir(), "template_structure.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", data.frame(x = "TURAS Survey Structure"),
                      startRow = 1, colNames = FALSE)
  openxlsx::writeData(wb, "Questions", data.frame(x = "Define every question below."),
                      startRow = 2, colNames = FALSE)
  questions <- data.frame(
    QuestionCode = c("[REQUIRED] Question code", "Gender", "Channels"),
    QuestionText = c("[Optional] text", "Gender", "Channels used"),
    Variable_Type = c("help", "Single_Response", "Multi_Mention"),
    Columns = c("help", "1", "2"),
    stringsAsFactors = FALSE)
  openxlsx::writeData(wb, "Questions", questions, startRow = 3)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  got <- read_template_sheet(path, "Questions",
                             c("QuestionCode", "Variable_Type", "Columns"))
  expect_equal(got$QuestionCode, c("Gender", "Channels"))

  data <- data.frame(ResponseID = "1", Gender = "F",
                     Channels_1 = "a", Channels_2 = "b",
                     stringsAsFactors = FALSE, check.names = FALSE)
  expect_true(verify_structure_alignment(path, data))

  data$Extra <- "x"
  expect_error(verify_structure_alignment(path, data),
               class = "vas_structure_stale")
})

test_that("a workbook with no recognisable header refuses by name", {
  path <- file.path(tempdir(), "headerless.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", data.frame(a = 1:3, b = 4:6))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  expect_error(read_template_sheet(path, "Questions",
                                   c("QuestionCode", "Variable_Type", "Columns")),
               class = "vas_sheet_headerless")
})
