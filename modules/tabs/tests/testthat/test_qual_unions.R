# ==============================================================================
# TABS MODULE — QUALITATIVE SHEET-UNION TESTS
# ==============================================================================
#
# Known-answer tests for qual_unions.R: parsing the CommentSheet mapping, deriving
# the synthetic union code, scanning the Selection sheet for union specs, and
# reassembling member sheets into one band-stamped question — plus an end-to-end
# check that the band + split survive into the DATA_QUAL island.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_unions.R")
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
  stop("Could not locate Turas root for sourcing qual_unions.R")
}

.root <- detect_turas_root()
source(file.path(.root, "modules/tabs/lib/qual_workbook_reader.R"))  # qual_sheet_code
source(file.path(.root, "modules/tabs/lib/qual_unions.R"))
source(file.path(.root, "modules/tabs/lib/qual_assemble.R"))         # respondent master
source(file.path(.root, "modules/tabs/lib/qual_island_builder.R"))   # end-to-end island
source(file.path(.root, "modules/tabs/lib/score_utils.R"))           # nps_bucket_score

# ---- Fixtures (shape mirrors qual_classify_sheet output) ---------------------

mk_rec <- function(id, text) {
  list(id = id, text = text, noteworthy = FALSE, noteworthy_tier = 0L,
       noteworthy_marker = "", sentiment = NA_integer_, rating = NA_real_,
       themeVals = list(), demos = list())
}
mk_reader_q <- function(sheet, records, themes = list()) {
  list(skip = FALSE, sheet = sheet, code = qual_sheet_code(sheet), title = sheet,
       type = if (length(themes)) "themed" else "raw", header_row = 5L,
       roles = list(id = 1L, verbatim = 3L, noteworthy = 2L, sentiment = NA_integer_,
                    rating = NA_integer_, themes = themes, demos = list()),
       records = records,
       meta = list(dropped_codes = 0L, n_records = length(records),
                   n_themes = length(themes), n_demos = 0L))
}

# ---- qual_parse_comment_sheet ------------------------------------------------

test_that("a single sheet is not a union (backward compatible)", {
  p <- qual_parse_comment_sheet("Q75Comment")
  expect_false(p$union)
  expect_equal(length(p$members), 1L)
  expect_equal(p$members[[1]]$sheet, "Q75Comment")
})

test_that("blank / NA CommentSheet yields no members", {
  expect_equal(length(qual_parse_comment_sheet("")$members), 0L)
  expect_equal(length(qual_parse_comment_sheet(NA)$members), 0L)
  expect_equal(length(qual_parse_comment_sheet("NA")$members), 0L)
})

test_that("a colon-mapped multi-sheet cell parses to bands", {
  p <- qual_parse_comment_sheet(
    "DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter")
  expect_true(p$union)
  expect_equal(length(p$members), 3L)
  expect_equal(p$members[[1]]$sheet, "DetractorComment")
  expect_equal(p$members[[1]]$band, "Detractor")
  expect_equal(p$members[[3]]$band, "Promoter")
})

test_that("a multi-sheet cell without ':' defaults each band to the sheet name", {
  p <- qual_parse_comment_sheet("SheetA; SheetB")
  expect_true(p$union)
  expect_equal(p$members[[2]]$band, "SheetB")
})

# ---- qual_union_code ---------------------------------------------------------

test_that("union code derives from the open-end QuestionCode, else from members", {
  members <- qual_parse_comment_sheet("A:x; B:y")$members
  expect_equal(qual_union_code("Q79", members), qual_sheet_code("Q79"))
  expect_equal(qual_union_code("", members), qual_sheet_code("A_B"))
  expect_equal(qual_union_code(NA, members), qual_sheet_code("A_B"))
})

# ---- qual_selection_unions ---------------------------------------------------

test_that("Selection scan finds only the union rows, with resolved members + defaults", {
  sel <- data.frame(
    QuestionCode = c("Q75", "Q79"),
    CommentSheet = c("Q75Comment",
                     "DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter"),
    CommentLink = c("Q75", "Q79"),
    QuestionText = c("Would you recommend", "How likely to recommend"),
    stringsAsFactors = FALSE)
  unions <- qual_selection_unions(sel)
  expect_equal(length(unions), 1L)                       # only Q79 unions
  u <- unions[[1]]
  expect_equal(u$code, qual_sheet_code("Q79"))
  expect_equal(u$dim, QUAL_SPLIT_DIM_DEFAULT)            # no SplitDimension col -> default
  expect_equal(u$link_target, "Q79")
  expect_equal(u$score_question, "Q79")                  # defaults to CommentLink target
  expect_equal(u$order, c("Detractor", "Passive", "Promoter"))
  expect_equal(u$members[[1]]$code, qual_sheet_code("DetractorComment"))
})

test_that("empty / column-less Selection yields no unions", {
  expect_equal(length(qual_selection_unions(NULL)), 0L)
  expect_equal(length(qual_selection_unions(data.frame(x = 1))), 0L)
})

# ---- qual_apply_sheet_unions -------------------------------------------------

test_that("three band sheets reassemble into one question with bands stamped", {
  qs <- list(
    mk_reader_q("Q02Comment", list(mk_rec("1", "orders are fine"))),          # untouched
    mk_reader_q("DetractorComment", list(mk_rec("54", "must improve energy"))),
    mk_reader_q("PassiveComment",   list(mk_rec("8", "ok service"), mk_rec("9", "average"))),
    mk_reader_q("PromoterComment",  list(mk_rec("11", "best service"))))
  sel <- data.frame(
    QuestionCode = "Q79",
    CommentSheet = "DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter",
    CommentLink = "Q79", stringsAsFactors = FALSE)
  unions <- qual_selection_unions(sel)
  out <- qual_apply_sheet_unions(qs, unions)

  codes <- vapply(out, function(q) q$code, character(1))
  expect_true(qual_sheet_code("Q02Comment") %in% codes)                       # non-member kept
  expect_false(qual_sheet_code("DetractorComment") %in% codes)                # members consumed
  expect_true(qual_sheet_code("Q79") %in% codes)                             # union present

  u <- out[[which(codes == qual_sheet_code("Q79"))]]
  expect_equal(u$type, "raw")
  expect_equal(length(u$records), 4L)                                         # 1 + 2 + 1
  expect_equal(u$split$dim, "NPS band")
  expect_equal(unlist(u$split$bands), c("Detractor", "Passive", "Promoter"))
  bands <- vapply(u$records, function(r) r$band, character(1))
  expect_equal(sort(bands), c("Detractor", "Passive", "Passive", "Promoter"))
})

test_that("no unions -> questions pass through untouched", {
  qs <- list(mk_reader_q("Q02Comment", list(mk_rec("1", "hi"))))
  expect_identical(qual_apply_sheet_unions(qs, list()), qs)
})

test_that("a themed member makes the union themed and unions theme labels", {
  th <- list(list(col = 4L, label = "Service"))
  qs <- list(
    mk_reader_q("DetractorComment", list(mk_rec("1", "bad")), themes = th),
    mk_reader_q("PromoterComment",  list(mk_rec("2", "good")), themes = th))
  unions <- qual_selection_unions(data.frame(
    QuestionCode = "Q79",
    CommentSheet = "DetractorComment:Detractor; PromoterComment:Promoter",
    stringsAsFactors = FALSE))
  u <- qual_apply_sheet_unions(qs, unions)[[1]]
  expect_equal(u$type, "themed")
  expect_equal(length(u$roles$themes), 1L)                                    # merged by label
  expect_equal(u$roles$themes[[1]]$label, "Service")
})

# ---- End-to-end: band + split survive into the DATA_QUAL island --------------

test_that("band + split reach the serialised island", {
  qs <- list(
    mk_reader_q("DetractorComment", list(mk_rec("54", "improve energy drinks"))),
    mk_reader_q("PromoterComment",  list(mk_rec("11", "best service"), mk_rec("12", "on time"))))
  unions <- qual_selection_unions(data.frame(
    QuestionCode = "Q79",
    CommentSheet = "DetractorComment:Detractor; PromoterComment:Promoter",
    stringsAsFactors = FALSE))
  qs <- qual_apply_sheet_unions(qs, unions)
  master <- qual_build_respondent_master(qs)
  island <- qual_build_data_qual(qs, master,
                                 list(text_mode = "full", demographic_cuts = "allow"))

  q <- island$questions[[1]]
  expect_equal(q$code, qual_sheet_code("Q79"))
  expect_equal(q$split$dim, "NPS band")
  expect_equal(unlist(q$split$bands), c("Detractor", "Promoter"))
  rec_bands <- vapply(q$records, function(r) if (is.null(r$band)) NA_character_ else r$band, character(1))
  expect_true(all(c("Detractor", "Promoter") %in% rec_bands))
})

# ---- Band derivation from the recommend score --------------------------------

test_that("band label keyword classification + bucket mapping", {
  expect_equal(qual_classify_band_label("Detractor"), "detractor")
  expect_equal(qual_classify_band_label("Passives"), "passive")
  expect_equal(qual_classify_band_label("NPS Promoter"), "promoter")
  expect_true(is.na(qual_classify_band_label("Segment A")))

  m <- qual_band_label_map(c("Detractor", "Passive", "Promoter"))
  expect_equal(m$promoter, "Promoter")
  expect_equal(qual_bucket_to_label(100, m), "Promoter")
  expect_equal(qual_bucket_to_label(0, m), "Passive")
  expect_equal(qual_bucket_to_label(-100, m), "Detractor")
  expect_true(is.na(qual_bucket_to_label(NA, m)))
})

test_that("the score wins over sheet-of-origin, and mismatches reassign", {
  qs <- list(
    mk_reader_q("DetractorComment", list(mk_rec("54", "improve energy"))),
    mk_reader_q("PassiveComment",   list()),
    mk_reader_q("PromoterComment",  list(mk_rec("11", "best"), mk_rec("12", "on time"),
                                         mk_rec("77", "not in survey"))))
  unions <- qual_selection_unions(data.frame(
    QuestionCode = "Q79",
    CommentSheet = "DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter",
    CommentLink = "Q79", stringsAsFactors = FALSE))
  qs <- qual_apply_sheet_unions(qs, unions)

  # host survey: id 54 -> row1 (score 6, detractor), 11 -> row2 (10, promoter),
  # 12 -> row3 (8, passive => disagrees with the promoter sheet), 77 absent from the map.
  survey <- data.frame(RID = c("54", "11", "12"), Q79 = c("6", "10", "8"),
                       stringsAsFactors = FALSE)
  id_to_idx <- stats::setNames(c(0L, 1L, 2L), c("54", "11", "12"))

  out <- qual_derive_bands(qs, unions, survey, id_to_idx)
  u <- out[[which(vapply(out, function(q) q$code, character(1)) == qual_sheet_code("Q79"))]]
  band_of <- function(id) {
    for (r in u$records) if (identical(r$id, id)) return(r$band)
    NA_character_
  }
  expect_equal(band_of("54"), "Detractor")   # score agrees with sheet
  expect_equal(band_of("11"), "Promoter")    # score agrees with sheet
  expect_equal(band_of("12"), "Passive")     # score OVERRIDES the promoter sheet
  expect_equal(band_of("77"), "Promoter")    # not in survey -> keeps sheet-of-origin
})

test_that("derivation is a no-op when the score question is absent from the survey", {
  qs <- qual_apply_sheet_unions(
    list(mk_reader_q("DetractorComment", list(mk_rec("54", "x"))),
         mk_reader_q("PromoterComment",  list(mk_rec("11", "y")))),
    qual_selection_unions(data.frame(
      QuestionCode = "Q79",
      CommentSheet = "DetractorComment:Detractor; PromoterComment:Promoter",
      CommentLink = "Q79", stringsAsFactors = FALSE)))
  survey <- data.frame(RID = c("54", "11"), SomethingElse = c("1", "2"), stringsAsFactors = FALSE)
  out <- qual_derive_bands(qs, list(qual_selection_unions(data.frame(
    QuestionCode = "Q79",
    CommentSheet = "DetractorComment:Detractor; PromoterComment:Promoter",
    CommentLink = "Q79", stringsAsFactors = FALSE))[[1]]),
    survey, stats::setNames(c(0L, 1L), c("54", "11")))
  expect_identical(out, qs)   # Q79 not a survey column -> unchanged
})
