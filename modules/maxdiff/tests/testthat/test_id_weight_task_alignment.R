# ==============================================================================
# MAXDIFF TESTS - A4: IDs, WEIGHTS AND TASK ALIGNMENT (H1, H2, H3, M13)
# ==============================================================================
# Four ways the module silently mis-joined:
#   H1  segments merged on the data's FIRST column, not the configured ID
#   H2  a typo'd Weight_Variable became weight = 1, reported as "weighted"
#   H3  a failed Task_Number lookup fell back to the design row POSITION
#   M13 Task_Number extraction only matched trailing digits, so the
#       template's own MaxDiff_T1_Best naming yielded NA

.a4_design <- function() {
  data.frame(
    Version = c(1L, 1L),
    Task_Number = c(1L, 2L),
    Item1_ID = c("APPLE", "CHERRY"),
    Item2_ID = c("BANANA", "DATE"),
    Item3_ID = c("CHERRY", "APPLE"),
    stringsAsFactors = FALSE
  )
}

.a4_mapping <- function() {
  data.frame(
    Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE",
                   "BEST_CHOICE", "WORST_CHOICE"),
    Field_Name = c("Version", "T1_Best", "T1_Worst", "T2_Best", "T2_Worst"),
    Task_Number = c(NA, 1L, 1L, 2L, 2L),
    stringsAsFactors = FALSE
  )
}

.a4_items <- function() {
  data.frame(
    Item_ID = c("APPLE", "BANANA", "CHERRY", "DATE"),
    Item_Label = c("Apple", "Banana", "Cherry", "Date"),
    Item_Group = "Fruit", Display_Order = 1:4,
    Include = 1L, Anchor_Item = 0L,
    stringsAsFactors = FALSE
  )
}

.a4_data <- function() {
  data.frame(
    Region = c("North", "South"),          # deliberately column 1: NOT the ID
    RespID = c("R1", "R2"),
    Version = c(1L, 1L),
    T1_Best = c("APPLE", "BANANA"), T1_Worst = c("CHERRY", "APPLE"),
    T2_Best = c("DATE", "CHERRY"), T2_Worst = c("APPLE", "DATE"),
    stringsAsFactors = FALSE
  )
}

.a4_long <- function() {
  cfg <- list(project_settings = list(Respondent_ID_Variable = "RespID",
                                      Weight_Variable = NULL,
                                      Choice_Value_Type = "ITEM_ID"))
  build_maxdiff_long(.a4_data(), .a4_mapping(), .a4_design(), cfg, verbose = FALSE)
}

# ------------------------------------------------------------------------------
# H1: segments join on the configured ID
# ------------------------------------------------------------------------------

test_that("H1: segments join on the configured respondent ID, not column 1", {
  long <- .a4_long()
  segs <- data.frame(Segment_ID = "SEG1",
                     Segment_Label = "Region",
                     Variable_Name = "Region",
                     Segment_Def = "",
                     Include_in_Output = 1L,
                     stringsAsFactors = FALSE)
  out_settings <- list(Min_Respondents_Per_Segment = 1L)

  res <- compute_segment_scores(long, .a4_data(), segs, .a4_items(),
                                out_settings, verbose = FALSE,
                                resp_id_var = "RespID")
  # With the ID configured, the join works even though RespID is column 2 —
  # both Region levels resolve to real respondents.
  expect_false(is.null(res))
  expect_true(is.data.frame(res$segment_scores))
  expect_true(all(c("North", "South") %in% res$segment_scores$Segment_Value))
})

test_that("H1: a respondent ID absent from the data refuses, loudly", {
  long <- .a4_long()
  segs <- data.frame(Segment_ID = "SEG1", Segment_Label = "All",
                     Variable_Name = "Region", Segment_Def = "",
                     Include_in_Output = 1L, stringsAsFactors = FALSE)

  expect_error(
    compute_segment_scores(long, .a4_data(), segs, .a4_items(),
                           list(Min_Respondents_Per_Segment = 1L),
                           verbose = FALSE, resp_id_var = "NoSuchColumn"),
    "DATA_SEGMENT_ID_MISSING|not a column"
  )
})

# ------------------------------------------------------------------------------
# H2: configured-but-absent columns refuse at validation
# ------------------------------------------------------------------------------

test_that("H2: a typo'd Weight_Variable fails validation instead of weight=1", {
  v <- validate_survey_data(.a4_data(), .a4_mapping(), .a4_design(), .a4_items(),
                            verbose = FALSE, choice_value_type = "ITEM_ID",
                            weight_variable = "Wieght",     # the typo
                            respondent_id_variable = "RespID")
  expect_false(v$valid)
  expect_true(any(grepl("Wieght", v$issues)))
})

test_that("H2: a typo'd Respondent_ID_Variable fails validation", {
  v <- validate_survey_data(.a4_data(), .a4_mapping(), .a4_design(), .a4_items(),
                            verbose = FALSE, choice_value_type = "ITEM_ID",
                            respondent_id_variable = "RespondentID")
  expect_false(v$valid)
  expect_true(any(grepl("RespondentID", v$issues)))
})

test_that("H2: a present weight column runs through validate_maxdiff_weights", {
  d <- .a4_data()
  d$W <- c(1.2, -0.5)   # a negative weight must surface
  v <- validate_survey_data(d, .a4_mapping(), .a4_design(), .a4_items(),
                            verbose = FALSE, choice_value_type = "ITEM_ID",
                            weight_variable = "W",
                            respondent_id_variable = "RespID")
  expect_true(length(c(v$issues, v$warnings)) > 0)
  expect_true(any(grepl("non-positive|Weights", c(v$issues, v$warnings))))
})

# ------------------------------------------------------------------------------
# H3: no silent positional design fallback
# ------------------------------------------------------------------------------

test_that("H3: a task with no matching design row refuses with counts", {
  design <- .a4_design()
  design$Task_Number <- c(101L, 102L)   # will never match tasks 1 and 2
  cfg <- list(project_settings = list(Respondent_ID_Variable = "RespID",
                                      Weight_Variable = NULL,
                                      Choice_Value_Type = "ITEM_ID"))

  expect_error(
    build_maxdiff_long(.a4_data(), .a4_mapping(), design, cfg, verbose = FALSE),
    "DESIGN_TASK_MISMATCH|no design row"
  )
})

# ------------------------------------------------------------------------------
# M13: Task_Number extraction from an infix T{n}
# ------------------------------------------------------------------------------

test_that("M13: MaxDiff_T1_Best style names yield their task number", {
  df <- data.frame(
    Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE"),
    Field_Name = c("Version", "MaxDiff_T7_Best", "MaxDiff_T7_Worst"),
    stringsAsFactors = FALSE
  )
  parsed <- parse_survey_mapping(df)
  expect_equal(parsed$Task_Number[parsed$Field_Name == "MaxDiff_T7_Best"], 7L)
  expect_equal(parsed$Task_Number[parsed$Field_Name == "MaxDiff_T7_Worst"], 7L)
})

test_that("M13: trailing digits still work as the fallback", {
  df <- data.frame(
    Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE"),
    Field_Name = c("Version", "Best_3", "Worst_3"),
    stringsAsFactors = FALSE
  )
  parsed <- parse_survey_mapping(df)
  expect_equal(parsed$Task_Number[parsed$Field_Name == "Best_3"], 3L)
})
