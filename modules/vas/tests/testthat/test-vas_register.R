# test-vas_register.R
# The report register - the human gate. Dispositions must survive a refresh,
# automatic flags must fire on the documented patterns, and only Exclude may
# drop a respondent from the numbers.

register_fixture_source <- function() {
  fixture_source(
    Respondent = c("Thabo M", "Test", "Nomsa D", "Sipho K"),
    Interviewer = c("Lindiwe", "Sebenzile/test", "Vanessa", "Khombo"),
    RespCell = c("0821234567", "0111111111", "Pp00000000", "0821234567"),
    `Date Submitted` = c("25 July 2026 10:00:00", "23 July 2026 13:22:00",
                         "25 July 2026 11:00:00", "25 July 2026 12:00:00")
  )
}

test_that("the test patterns fire on names, cells and the field start date", {
  pattern <- describe_test_pattern(
    respondent = c("Thabo M", "Test", "duncan", "Nomsa D"),
    interviewer = c("Lindiwe", "Leanne", "dunca", "Vanessa"),
    cell = c("0821234567", "0111111111", "12", "Pp00000000"),
    submitted = rep("25 July 2026 10:00:00", 4)
  )
  expect_equal(pattern[1], "")
  expect_equal(pattern[2], "test name")
  expect_equal(pattern[3], "test name; implausible cell number")
  expect_equal(pattern[4], "implausible cell number")
})

test_that("interviews before the field start are flagged", {
  pattern <- describe_test_pattern(
    respondent = c("Thabo M", "Nomsa D"),
    interviewer = c("Lindiwe", "Vanessa"),
    cell = c("0821234567", "0834567890"),
    submitted = c("23 July 2026 13:22:00", "25 July 2026 10:00:00"),
    field_start = "2026-07-24"
  )
  expect_equal(pattern[1], "before field start")
  expect_equal(pattern[2], "")
})

test_that("a duplicated plausible cell number is flagged on both rows", {
  rows <- build_register_rows(register_fixture_source())
  expect_equal(rows$`Duplicate cell`, c("duplicate", "", "", "duplicate"))
  # the implausible numbers are not counted as duplicates of each other
  expect_equal(rows$`Test pattern`[3], "implausible cell number")
})

test_that("a refresh carries dispositions and keeps vanished rows", {
  fresh <- build_register_rows(register_fixture_source())
  existing <- data.frame(
    check.names = FALSE, stringsAsFactors = FALSE,
    `Response ID` = c("2", "99"),
    Disposition = c("Exclude", "Include"),
    Reason = c("test interview", "spot checked")
  )
  merged <- merge_register(fresh, existing)

  expect_equal(merged$Disposition[merged$`Response ID` == "2"], "Exclude")
  expect_equal(merged$Reason[merged$`Response ID` == "2"], "test interview")
  expect_true(is.na(merged$Disposition[merged$`Response ID` == "1"]))

  vanished <- merged[merged$`Response ID` == "99", ]
  expect_equal(nrow(vanished), 1L)
  expect_equal(vanished$Disposition, "Include")
  expect_equal(vanished$`Test pattern`, "no longer in the export")
})

test_that("defaults send flagged rows to Review and clean rows to Include", {
  register <- apply_default_dispositions(build_register_rows(register_fixture_source()))
  expect_equal(register$Disposition, c("Review", "Review", "Review", "Review"))

  clean <- build_register_rows(fixture_source(
    Respondent = c("Thabo M"), Interviewer = c("Lindiwe"),
    RespCell = c("0821234567"), `Date Submitted` = c("25 July 2026 10:00:00")
  ))
  expect_equal(apply_default_dispositions(clean)$Disposition, "Include")

  decided <- build_register_rows(register_fixture_source())
  decided$Disposition <- "Exclude"
  expect_equal(unique(apply_default_dispositions(decided)$Disposition), "Exclude")
})

test_that("only Exclude drops a respondent from the source", {
  source_data <- register_fixture_source()
  register <- apply_default_dispositions(build_register_rows(source_data))
  register$Disposition <- c("Include", "Exclude", "Review", "Include")

  filtered <- filter_source_by_register(source_data, register)
  expect_equal(filtered$excluded, "2")
  expect_equal(filtered$source$response_id, c("1", "3", "4"))
  expect_equal(nrow(filtered$source$data), 3L)
})

test_that("derived flags annotate the register and push it to Review", {
  register <- build_register_rows(register_fixture_source())
  wide <- data.frame(
    ResponseID = c("1", "3"),
    OutlierFlag = c(TRUE, FALSE),
    ShareOfWallet_Transacted_Midpoint = c(NA_real_, 1.599),
    stringsAsFactors = FALSE
  )
  annotated <- annotate_register_flags(register, wide)
  expect_equal(annotated$`Outlier flag`[1], "outlier answer")
  expect_equal(annotated$`Outlier flag`[2], "")            # excluded: not in wide
  expect_equal(annotated$`Outlier flag`[3], "share of wallet over 100%")
  expect_equal(annotated$`Share of wallet`[3], "160%")
})

test_that("the register survives a write-and-read round trip", {
  path <- file.path(tempdir(), "register_roundtrip.xlsx")
  on.exit(unlink(path), add = TRUE)

  register <- apply_default_dispositions(build_register_rows(register_fixture_source()))
  register$Disposition[2] <- "Exclude"
  register$Reason[2] <- "test interview"
  write_report_register(register, path)

  read_back <- read_report_register(path)
  expect_equal(nrow(read_back), 4L)
  expect_equal(read_back$Disposition[read_back$`Response ID` == "2"], "Exclude")
  expect_equal(read_back$Reason[read_back$`Response ID` == "2"], "test interview")

  # and a full refresh against the written file keeps the exclusion working
  gate <- refresh_report_register(register_fixture_source(), path,
                                  qc_log_path = file.path(tempdir(), "no_qc_log.xlsx"))
  expect_equal(gate$filtered$excluded, "2")
  expect_equal(gate$new_count, 0L)
})

test_that("a missing register file means every row is new", {
  gate <- refresh_report_register(register_fixture_source(),
                                  file.path(tempdir(), "register_absent.xlsx"),
                                  qc_log_path = file.path(tempdir(), "no_qc_log.xlsx"))
  expect_equal(gate$new_count, 4L)
  expect_equal(length(gate$filtered$excluded), 0L)
})

# The QC log has been written on two sheets since 2026-07-27 ("Open queries"
# and "Closed and settled"). Reading only the first would lose the status of
# every query already checked off - the one the register most needs.

write_qc_log_fixture <- function(path, sheets) {
  wb <- openxlsx::createWorkbook()
  for (name in names(sheets)) {
    openxlsx::addWorksheet(wb, name)
    # the real file carries a title and a subtitle above the header row
    openxlsx::writeData(wb, name, "VAS 2026 - QC query log", startRow = 1)
    openxlsx::writeData(wb, name, "Work the queries here.", startRow = 2)
    openxlsx::writeData(wb, name, sheets[[name]], startRow = 4)
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
}

test_that("QC status is read from every sheet of the log, not just the first", {
  path <- file.path(tempdir(), "qc_log_two_sheets.xlsx")
  on.exit(unlink(path), add = TRUE)
  write_qc_log_fixture(path, list(
    `Open queries` = data.frame(
      `Response ID` = c("1"), Status = c("In progress"),
      check.names = FALSE),
    `Closed and settled` = data.frame(
      `Response ID` = c("3", "4"),
      Status = c("Checked - OK", "Checked - problem"),
      check.names = FALSE)))

  register <- build_register_rows(register_fixture_source())
  joined <- join_qc_status(register, path)
  status <- setNames(joined$`QC status`, joined$`Response ID`)
  expect_equal(unname(status["1"]), "In progress")
  expect_equal(unname(status["3"]), "Checked - OK")
  expect_equal(unname(status["4"]), "Checked - problem")
  expect_equal(unname(status["2"]), "")        # no query, left alone
})

test_that("a one-sheet log from before the split still reads", {
  path <- file.path(tempdir(), "qc_log_one_sheet.xlsx")
  on.exit(unlink(path), add = TRUE)
  write_qc_log_fixture(path, list(
    `QC log` = data.frame(
      `Response ID` = c("1", "3"),
      Status = c("Open", "Checked - OK"),
      check.names = FALSE)))

  joined <- join_qc_status(build_register_rows(register_fixture_source()), path)
  status <- setNames(joined$`QC status`, joined$`Response ID`)
  expect_equal(unname(status["1"]), "Open")
  expect_equal(unname(status["3"]), "Checked - OK")
})

test_that("a log sheet with no query table is skipped, not fatal", {
  path <- file.path(tempdir(), "qc_log_with_lookup.xlsx")
  on.exit(unlink(path), add = TRUE)
  write_qc_log_fixture(path, list(
    `Open queries` = data.frame(`Response ID` = "1", Status = "Open",
                                check.names = FALSE),
    Sections = data.frame(Section = "Warmup", `Page ID` = 17,
                          check.names = FALSE)))

  joined <- join_qc_status(build_register_rows(register_fixture_source()), path)
  expect_equal(joined$`QC status`[joined$`Response ID` == "1"], "Open")
})
