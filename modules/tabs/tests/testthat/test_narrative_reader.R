# ==============================================================================
# TABS MODULE - NARRATIVE READER (Word document -> report screens)
# ==============================================================================
#
# Stage 1 of NARRATIVE_SCREENS_BRIEF.md. The narrative_file setting names a Word
# document; each Heading 1 is one screen of the report's Background and
# Executive summary. These tests pin:
#
#   - the EXACT block list read from the committed fixture, which carries every
#     feature the reader honours and every one it ignores
#   - the count of each ignored feature, and that the console names it
#   - the refusals: missing file, not a .docx, not readable as Word
#   - the Comments-sheet fallback, converted to the same shape
#   - the setting at the layer that whitelists it, and the screens arriving on
#     config_obj through the REAL load_crosstabs_config()
#   - project.narrative on the island, and its JSON shape
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_narrative_reader.R")
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
source(file.path(turas_root, "modules/tabs/lib/crosstabs/narrative_reader.R"))
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))

FIXTURE_DIR <- file.path(turas_root, "modules/tabs/tests/fixtures/narrative")
FIXTURE <- file.path(FIXTURE_DIR, "narrative_fixture.docx")
# the builders, for small one-off documents (sourcing writes nothing)
source(file.path(FIXTURE_DIR, "generate_narrative_fixture.R"))

read_quietly <- function(path) {
  out <- NULL
  console <- capture.output(out <- read_narrative_docx(path))
  attr(out, "console") <- console
  out
}

run <- function(text, bold = FALSE, italic = FALSE) list(text = text, bold = bold, italic = italic)
# a Turas link's words: the run carries link = the question code
link_run <- function(text, code) c(run(text), list(link = code))
para <- function(...) list(type = "paragraph", runs = list(...))
item <- function(text, level = 0L, ordered = FALSE, number = NULL) {
  out <- list(level = level, ordered = ordered, runs = list(run(text)))
  if (!is.null(number)) out$number <- number
  out
}

# The fixture's own picture bytes, straight out of the package
fixture_png <- function() {
  d <- tempfile("fxpng"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  utils::unzip(FIXTURE, files = "word/media/image1.png", exdir = d)
  p <- file.path(d, "word/media/image1.png")
  readBin(p, "raw", file.info(p)$size)
}

# ==============================================================================
# THE FIXTURE, BLOCK BY BLOCK
# ==============================================================================

test_that("the fixture reads to exactly the expected screens and blocks", {
  skip_if_not(file.exists(FIXTURE), "narrative fixture not present")
  screens <- read_quietly(FIXTURE)

  # Pictures: check the data URI carries the embedded file's own bytes, then
  # stand in a marker so the whole structure can be compared as one literal.
  png_src <- paste0("data:image/png;base64,", base64enc::base64encode(fixture_png()))
  for (i in seq_along(screens)) {
    for (j in seq_along(screens[[i]]$blocks)) {
      if (identical(screens[[i]]$blocks[[j]]$type, "image")) {
        expect_identical(screens[[i]]$blocks[[j]]$src, png_src)
        screens[[i]]$blocks[[j]]$src <- "<png>"
      }
    }
  }
  attr(screens, "ignored") <- NULL
  attr(screens, "console") <- NULL

  expected <- list(
    list(id = "background-method", title = "Background & method", blocks = list(
      para(run("This study has "), run("136", bold = TRUE), run(" responses and "),
           run("two", italic = TRUE), run(" sections.")),
      para(run("See the Turas site for more.")),
      para(run("Line one line two")),
      # a Turas link in a heading keeps its words and loses the link
      list(type = "subheading", text = "How we asked"),
      list(type = "list", items = list(
        item("Online survey"), item("Invites by email", level = 1L),
        list(level = 0L, ordered = FALSE,
             runs = list(run("Two "), link_run("reminders", "Q2"))))),
      # the reader keeps any turas: code; the island check drops unknown ones
      para(run("A paragraph "), link_run("between lists", "Q999"), run(".")),
      list(type = "list", items = list(
        item("First step", ordered = TRUE, number = 1L),
        item("Second step", ordered = TRUE, number = 2L))),
      list(type = "table", rows = list(
        list("Group", "n", "%"), list("Staff", "136", "58% of invites"))),
      para(run("Response rate fell to 58%."))
    )),
    list(id = "executive-summary", title = "Executive summary", blocks = list(
      # Word split the link over two runs; they merge, the plain words do not
      para(link_run("Ratings", "Q1"), run(" are stable.")),
      list(type = "quote", runs = list(run("\"Culture varies by campus.\""))),
      list(type = "image", src = "<png>", alt = "Response chart", width = 40L, height = 20L),
      para(run("Text before.")),
      list(type = "image", src = "<png>", width = 40L, height = 20L),
      para(run("Text after.")),
      para(run("Visible text.")),
      para(run("Equation follows.")),
      list(type = "subheading", text = "Minor heading", level = 3L),
      list(type = "list", items = list(item("Styled bullet")))
    )),
    list(id = "executive-summary-2", title = "Executive summary", blocks = list(
      para(run("Second occurrence."))
    ))
  )
  expect_identical(screens, expected)
})

test_that("every ignored feature in the fixture is counted exactly once", {
  skip_if_not(file.exists(FIXTURE), "narrative fixture not present")
  screens <- read_quietly(FIXTURE)
  ignored <- attr(screens, "ignored")

  expected <- c(
    # hyperlinks: the web link, the Turas link in a heading, the w:anchor link
    preamble = 1L, minor_headings = 0L, hyperlinks = 3L, tracked_changes = 2L,
    comments = 1L, footnotes = 1L, text_boxes = 1L, shapes = 1L, smartart = 1L,
    charts = 1L, picture_formats = 1L, linked_pictures = 1L, table_drawings = 1L,
    merged_tables = 1L, nested_tables = 0L, embedded_objects = 1L,
    content_controls = 1L, columns = 1L, headers_footers = 1L)
  expect_identical(ignored, expected)
  # the text box's VML fallback twin is not a second text box, and its words
  # never leak into the paragraph that anchors it
  all_text <- paste(unlist(lapply(screens, function(s) s$blocks)), collapse = " ")
  expect_false(grepl("Hidden box text", all_text, fixed = TRUE))
  # deleted text is gone; the footnote and the comment bodies never arrive
  expect_false(grepl("rose", all_text, fixed = TRUE))
  expect_false(grepl("Weighted to staff", all_text, fixed = TRUE))
  expect_false(grepl("Check this figure", all_text, fixed = TRUE))
  expect_false(grepl("Inside a control", all_text, fixed = TRUE))
  expect_false(grepl("Fixture narrative", all_text, fixed = TRUE))
})

test_that("the console names every skipped kind and how many", {
  skip_if_not(file.exists(FIXTURE), "narrative fixture not present")
  console <- attr(read_quietly(FIXTURE), "console")
  joined <- paste(console, collapse = "\n")

  expect_true(grepl("narrative_fixture.docx: 3 screens, 20 blocks, 2 pictures", joined, fixed = TRUE))
  for (key in names(.NARRATIVE_IGNORED)) {
    # none in the fixture, so no line (its one Heading 3 is now a sub-heading)
    if (key %in% c("nested_tables", "minor_headings")) next
    expect_true(grepl(.NARRATIVE_IGNORED[[key]][1], joined, fixed = TRUE), info = key)
  }
  expect_true(grepl("2 tracked change(s)", joined, fixed = TRUE))
  expect_true(grepl("3 hyperlink(s). The words are kept and the link is dropped.", joined, fixed = TRUE))
  expect_true(grepl("[INFO] Narrative file: 3 Turas links kept, to Q2, Q999, Q1.", joined, fixed = TRUE))
  expect_true(grepl("Found: EMF.", joined, fixed = TRUE))
  # a kind with nothing skipped says nothing
  expect_false(grepl("table(s) inside a table", joined, fixed = TRUE))
  # no em dash in anything a person reads
  expect_false(grepl("\u2014", joined, fixed = TRUE))
})

# ==============================================================================
# SMALLER DOCUMENTS
# ==============================================================================

test_that("a document with no Heading 1 is one screen titled Executive summary", {
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(fx_par(fx_run("First.")), fx_par(fx_run("Sub"), style = "Kop2"),
                                 fx_par(fx_run("Second."))))
  screens <- read_quietly(p)
  expect_length(screens, 1)
  expect_identical(screens[[1]]$id, "executive-summary")
  expect_identical(screens[[1]]$title, "Executive summary")
  expect_identical(screens[[1]]$blocks, list(
    para(run("First.")), list(type = "subheading", text = "Sub"), para(run("Second."))))
  expect_identical(attr(screens, "ignored")[["preamble"]], 0L)
  # said in the console, so a document whose headings were missed is noticed
  expect_true(any(grepl("no Heading 1 was found", attr(screens, "console"), fixed = TRUE)))
})

test_that("a document with no text is no screens, loudly, and no narrative", {
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(fx_par(), fx_par()))
  screens <- read_quietly(p)
  expect_length(screens, 0)
  expect_true(any(grepl("holds no text the report can show", attr(screens, "console"), fixed = TRUE)))

  cfg <- file.path(dirname(p), "cfg.xlsx")
  out <- capture.output(n <- load_narrative(list(narrative_file = basename(p)), cfg))
  expect_null(n)
})

test_that("an oversized picture is refused loudly and its screen keeps its text", {
  big <- c(narrative_fixture_png(), as.raw(sample(0:255, TABS_SLIDE_IMAGE_MAX_BYTES + 10, replace = TRUE)))
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p,
    paste0(fx_par(fx_run("Findings"), style = "berschrift1"), fx_par(fx_run("Kept.")),
           fx_par(fx_picture("rIdBig"))),
    doc_rels = '<Relationship Id="rIdBig" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/big.png"/>',
    media = list("big.png" = big))
  screens <- read_quietly(p)
  expect_identical(screens[[1]]$blocks, list(para(run("Kept."))))
  expect_true(any(grepl("NARRATIVE PICTURE TOO LARGE", attr(screens, "console"), fixed = TRUE)))
})

test_that("screen ids are heading slugs; only a repeated title is suffixed by order", {
  expect_identical(
    .narrative_screen_ids(c("Executive summary", "The 2026 view", "Executive  summary")),
    c("executive-summary", "the-2026-view", "executive-summary-2"))
})

test_that("the title code is a fixed polynomial over code points", {
  # known answer: ("a" = 97) * 31 + ("b" = 98) = 3105 = 0xc21
  expect_identical(.narrative_title_code("ab"), "0000c21")
  expect_identical(.narrative_title_code("\u2605"), sprintf("%07x", 0x2605L))
})

test_that("titles that slug alike, or have no ASCII at all, keep their ids when reordered", {
  titles <- c("Q1: Results", "Q1 results", "\u2605 \u8981\u70b9", "\u2605\u2605")
  ids <- .narrative_screen_ids(titles)
  expect_identical(ids, c(
    paste0("q1-results-", .narrative_title_code("Q1: Results")),
    paste0("q1-results-", .narrative_title_code("Q1 results")),
    paste0("screen-", .narrative_title_code("\u2605 \u8981\u70b9")),
    paste0("screen-", .narrative_title_code("\u2605\u2605"))))
  expect_length(unique(ids), 4)
  # the property the pins rely on: an id belongs to its title, not its position
  expect_identical(.narrative_screen_ids(rev(titles)), rev(ids))
})

# ==============================================================================
# LIST NUMBERS AND STYLE ROLES
# ==============================================================================

# The list items of a document's one screen, as "text=number" (or "text" for a
# bullet), in document order
numbers_of <- function(screens) {
  items <- unlist(lapply(screens[[1]]$blocks, function(b) {
    if (identical(b$type, "list")) b$items else NULL
  }), recursive = FALSE)
  vapply(items, function(it) {
    if (is.null(it$number)) it$runs[[1]]$text else paste0(it$runs[[1]]$text, "=", it$number)
  }, character(1))
}

test_that("a numbered list interrupted by a paragraph keeps counting, as Word does", {
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(
    fx_par(fx_run("Recommendations"), style = "berschrift1"),
    fx_par(fx_run("One"), num = c(2, 0)), fx_par(fx_run("Two"), num = c(2, 0)),
    fx_par(fx_run("An aside between them.")),
    fx_par(fx_run("Three"), num = c(2, 0))))
  screens <- read_quietly(p)
  expect_identical(vapply(screens[[1]]$blocks, function(b) b$type, character(1)),
                   c("list", "paragraph", "list"))
  expect_identical(numbers_of(screens), c("One=1", "Two=2", "Three=3"))
})

test_that("list numbers honour start values, restarts and nested levels", {
  # num 4 is the decimal list again, restarted at 5 (Word's "Set numbering value")
  numbering <- sub("</w:numbering>", paste0(
    '<w:num w:numId="4"><w:abstractNumId w:val="1"/>',
    '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/></w:lvlOverride></w:num>',
    "</w:numbering>"), narrative_fixture_numbering(), fixed = TRUE)
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(
    fx_par(fx_run("Plan"), style = "berschrift1"),
    fx_par(fx_run("a"), num = c(2, 0)), fx_par(fx_run("a.1"), num = c(2, 1)),
    fx_par(fx_run("a.2"), num = c(2, 1)), fx_par(fx_run("b"), num = c(2, 0)),
    fx_par(fx_run("b.1"), num = c(2, 1)), fx_par(fx_run("bullet"), num = c(1, 0)),
    fx_par(fx_run("x"), num = c(4, 0)), fx_par(fx_run("y"), num = c(4, 0))),
    numbering_xml = numbering)
  # a deeper level restarts under each new parent; a bullet has no number; the
  # restarted list instance counts from its own start value
  expect_identical(numbers_of(read_quietly(p)), c(
    "a=1", "a.1=1", "a.2=2", "b=2", "b.1=1", "bullet", "x=5", "y=6"))
})

test_that("a heading style built on Heading 1 starts a screen; TOC Heading does not", {
  styles <- sub("</w:styles>", paste0(
    '<w:style w:type="paragraph" w:styleId="TRLHeading"><w:name w:val="TRL Heading"/>',
    '<w:basedOn w:val="berschrift1"/></w:style>',
    '<w:style w:type="paragraph" w:styleId="TOCHeading"><w:name w:val="TOC Heading"/>',
    '<w:basedOn w:val="berschrift1"/><w:pPr><w:outlineLvl w:val="9"/></w:pPr></w:style>',
    '<w:style w:type="paragraph" w:styleId="Sub"><w:name w:val="Section sub"/>',
    '<w:basedOn w:val="Normal"/><w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>',
    '<w:style w:type="paragraph" w:styleId="PullQuote"><w:name w:val="Pull quote"/>',
    '<w:basedOn w:val="Quote"/></w:style>',
    "</w:styles>"), narrative_fixture_styles(), fixed = TRUE)
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(
    fx_par(fx_run("Background"), style = "TRLHeading"), fx_par(fx_run("Why.")),
    fx_par(fx_run("Findings"), style = "TRLHeading"),
    fx_par(fx_run("Contents"), style = "TOCHeading"),
    fx_par(fx_run("What moved"), style = "Sub"),
    fx_par(fx_run("Said it all."), style = "PullQuote")), styles_xml = styles)
  screens <- read_quietly(p)
  expect_identical(vapply(screens, function(s) s$title, character(1)),
                   c("Background", "Findings"))
  expect_identical(screens[[2]]$blocks, list(
    para(run("Contents")),
    list(type = "subheading", text = "What moved"),
    list(type = "quote", runs = list(run("Said it all.")))))
  expect_false(any(grepl("no Heading 1 was found", attr(screens, "console"), fixed = TRUE)))
})

# ==============================================================================
# COLOUR, HIGHLIGHTER, HEADING 3 AND 4, LIST FORMATS, WIDE PICTURES
# ==============================================================================

# A run with raw run properties, for the marks fx_run does not write
fx_run_props <- function(text, props) {
  sprintf('<w:r><w:rPr>%s</w:rPr><w:t xml:space="preserve">%s</w:t></w:r>', props, fx_esc(text))
}

test_that("a Turas link on nothing but spaces is no link, and the console counts it as dropped", {
  rels <- paste0(
    '<Relationship Id="rQ1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="turas:Q1" TargetMode="External"/>',
    '<Relationship Id="rQ2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="turas:Q2" TargetMode="External"/>')
  body <- paste0(
    fx_par(fx_run("Findings"), style = "berschrift1"),
    # a space-only link mid-sentence, and one at the end the trim removes
    fx_par(fx_run("Awareness"), fx_link("rQ1", fx_link_run(" ")), fx_run("rose.")),
    fx_par(fx_run("Usage held."), fx_link("rQ2", fx_link_run(" "))),
    # a real link split over two runs, one of them only a space, still links
    fx_par(fx_link("rQ2", fx_link_run("usage"), fx_link_run(" ")), fx_run("is flat.")))
  path <- tempfile(fileext = ".docx")
  on.exit(unlink(path), add = TRUE)
  write_narrative_docx(path, body, doc_rels = rels)
  screens <- read_quietly(path)
  blocks <- screens[[1]]$blocks
  expect_identical(blocks[[1]]$runs, list(run("Awareness rose.")))
  expect_identical(blocks[[2]]$runs, list(run("Usage held.")))
  expect_identical(blocks[[3]]$runs, list(link_run("usage ", "Q2"), run("is flat.")))
  expect_identical(attr(screens, "ignored")[["hyperlinks"]], 2L)
  console <- paste(attr(screens, "console"), collapse = "\n")
  expect_true(grepl("[INFO] Narrative file: 1 Turas link kept, to Q2.", console, fixed = TRUE))
  expect_false(grepl("kept, to .", console, fixed = TRUE))
})

test_that("only a turas: address is a Turas link, read case-blind, trimmed and decoded", {
  targets <- c(rA = "TURAS: Q7 ", rB = "turas:Q%5F1", rC = "turas:", rD = "https://example.org",
               rE = "mailto:a@b.c")
  rels <- paste(vapply(names(targets), function(id) sprintf(
    '<Relationship Id="%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="%s" TargetMode="External"/>',
    id, targets[[id]]), character(1)), collapse = "")
  body <- paste0(fx_par(fx_run("Links")), paste(vapply(names(targets), function(id) {
    fx_par(fx_run("Go "), fx_link(id, fx_link_run(paste0("to ", id))))
  }, character(1)), collapse = ""))
  path <- tempfile(fileext = ".docx")
  on.exit(unlink(path), add = TRUE)
  write_narrative_docx(path, body, doc_rels = rels)
  screens <- read_quietly(path)
  links <- vapply(screens[[1]]$blocks[-1], function(b) b$runs[[length(b$runs)]]$link %||% "",
                  character(1))
  expect_identical(links, c("Q7", "Q_1", "", "", ""))
  # the three that are not Turas links keep their words and are counted
  expect_identical(attr(screens, "ignored")[["hyperlinks"]], 3L)
  expect_identical(screens[[1]]$blocks[[4]]$runs,
                   list(run("Go to rC")))
})

test_that("a font colour with a hue, and the highlighter, mark a run; black and greys do not", {
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(
    fx_par(fx_run("Findings"), style = "berschrift1"),
    fx_par(fx_run("Plain, "),
           fx_run_props("red", '<w:color w:val="C00000"/>'),
           fx_run_props(" and theme blue", '<w:b/><w:color w:val="4472C4" w:themeColor="accent1"/>'),
           fx_run_props(" black", '<w:color w:val="000000" w:themeColor="text1"/>'),
           fx_run_props(" grey", '<w:color w:val="7F7F7F"/>'),
           fx_run_props(" auto", '<w:color w:val="auto"/>'),
           fx_run_props(" marked", '<w:highlight w:val="yellow"/>'),
           fx_run_props(" unmarked", '<w:highlight w:val="none"/>'))))
  runs <- read_quietly(p)[[1]]$blocks[[1]]$runs
  expect_identical(runs, list(
    run("Plain, "),
    list(text = "red", bold = FALSE, italic = FALSE, colour = TRUE),
    list(text = " and theme blue", bold = TRUE, italic = FALSE, colour = TRUE),
    run(" black grey auto"),
    list(text = " marked", bold = FALSE, italic = FALSE, highlight = TRUE),
    run(" unmarked")))
})

test_that("Heading 3 is a small sub-heading; Heading 4 is a paragraph and is named", {
  styles <- sub("</w:styles>", paste0(
    '<w:style w:type="paragraph" w:styleId="Heading4"><w:name w:val="heading 4"/>',
    '<w:basedOn w:val="Normal"/></w:style></w:styles>'), narrative_fixture_styles(), fixed = TRUE)
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(
    fx_par(fx_run("Findings"), style = "berschrift1"),
    fx_par(fx_run("Big point"), style = "Kop2"),
    fx_par(fx_run("Smaller point"), style = "Heading3"),
    fx_par(fx_run("Smallest"), style = "Heading4")), styles_xml = styles)
  screens <- read_quietly(p)
  expect_identical(screens[[1]]$blocks, list(
    list(type = "subheading", text = "Big point"),
    list(type = "subheading", text = "Smaller point", level = 3L),
    para(run("Smallest"))))
  expect_identical(attr(screens, "ignored")[["minor_headings"]], 1L)
  expect_true(any(grepl("1 Heading 4 or lower", attr(screens, "console"), fixed = TRUE)))
})

test_that("letter and roman list numbering is kept; plain numbers carry no format", {
  numbering <- sub("</w:numbering>", paste0(
    '<w:abstractNum w:abstractNumId="5"><w:lvl w:ilvl="0"><w:start w:val="1"/>',
    '<w:numFmt w:val="upperRoman"/></w:lvl></w:abstractNum>',
    '<w:num w:numId="6"><w:abstractNumId w:val="5"/></w:num></w:numbering>'),
    narrative_fixture_numbering(), fixed = TRUE)
  p <- tempfile(fileext = ".docx")
  on.exit(unlink(p), add = TRUE)
  write_narrative_docx(p, paste0(
    fx_par(fx_run("Plan"), style = "berschrift1"),
    fx_par(fx_run("one"), num = c(2, 0)), fx_par(fx_run("one.a"), num = c(2, 1)),
    fx_par(fx_run("I"), num = c(6, 0)), fx_par(fx_run("II"), num = c(6, 0))),
    numbering_xml = numbering)
  items <- read_quietly(p)[[1]]$blocks[[1]]$items
  formats <- vapply(items, function(it) it$format %||% "(none)", character(1))
  expect_identical(formats, c("(none)", "lowerLetter", "upperRoman", "upperRoman"))
  expect_identical(vapply(items, function(it) it$number, integer(1)), c(1L, 1L, 1L, 2L))
})

test_that("a picture Word shows across the text width is wide; a small one is not", {
  wide_pic <- sub('cx="914400"', 'cx="5486400"', fx_picture("rIdPng", id = 2), fixed = TRUE)
  png_rel <- '<Relationship Id="rIdPng" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/p.png"/>'
  pictures_of <- function(sect) {
    p <- tempfile(fileext = ".docx")
    on.exit(unlink(p), add = TRUE)
    write_narrative_docx(p, paste0(
      fx_par(fx_run("Findings"), style = "berschrift1"),
      fx_par(fx_picture("rIdPng", id = 1)), fx_par(wide_pic), sect),
      doc_rels = png_rel, media = list("p.png" = narrative_fixture_png()))
    Filter(function(b) identical(b$type, "image"), read_quietly(p)[[1]]$blocks)
  }
  # A4 (11906 twips) less 1in margins each side = 9026 twips of text; the
  # wide one is 6in = 8640 twips (96%), the small one 1in = 1440 twips (16%)
  a4 <- '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:left="1440" w:right="1440"/></w:sectPr>'
  pics <- pictures_of(a4)
  expect_null(pics[[1]]$wide)
  expect_true(isTRUE(pics[[2]]$wide))
  # margins not stated: Word's 1in default, so the same answer
  pics <- pictures_of('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>')
  expect_true(isTRUE(pics[[2]]$wide))
  # 3in side margins leave 3386 twips of text: a 1in picture (43%) is still not wide
  pics <- pictures_of('<w:sectPr><w:pgSz w:w="11906"/><w:pgMar w:left="4320" w:right="4200"/></w:sectPr>')
  expect_null(pics[[1]]$wide)
  # no page size at all: nothing is called wide
  pics <- pictures_of("")
  expect_null(pics[[2]]$wide)
})

test_that("the JS suites' island fixture is the reader's current output", {
  skip_if_not(file.exists(FIXTURE), "narrative fixture not present")
  island_path <- file.path(turas_root,
    "modules/tabs/lib/html_report_v2/tests/fixtures/narrative_island.json")
  capture.output(word <- read_narrative_docx(FIXTURE))
  fresh <- narrative_island_fixture(word)
  if (identical(Sys.getenv("TURAS_REGEN_NARRATIVE_ISLAND"), "1")) {
    jsonlite::write_json(fresh, island_path, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  }
  committed <- jsonlite::fromJSON(island_path, simplifyVector = FALSE)
  expect_identical(committed$word, fresh$word)
  expect_identical(committed$comments, fresh$comments)
})

# ==============================================================================
# REFUSALS
# ==============================================================================

test_that("a missing narrative file refuses, naming the resolved path", {
  d <- tempfile("narrmiss"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  cfg <- file.path(d, "Crosstab_Config.xlsx")

  out <- capture.output(err <- tryCatch(
    load_narrative(list(narrative_file = "Summary.docx"), cfg),
    turas_refusal = function(e) e))
  expect_s3_class(err, "turas_refusal")
  expect_match(conditionMessage(err), "IO_NARRATIVE_FILE_NOT_FOUND", fixed = TRUE)
  joined <- paste(out, collapse = "\n")
  expect_true(grepl("IO_NARRATIVE_FILE_NOT_FOUND", joined, fixed = TRUE))
  expect_true(grepl(file.path(normalizePath(d), "Summary.docx"), joined, fixed = TRUE))
})

test_that("a file that is not a .docx, or not readable as one, refuses", {
  d <- tempfile("narrbad"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  cfg <- file.path(d, "cfg.xlsx")

  writeLines("old binary Word", file.path(d, "Summary.doc"))
  capture.output(err <- tryCatch(load_narrative(list(narrative_file = "Summary.doc"), cfg),
                                 turas_refusal = function(e) e))
  expect_s3_class(err, "turas_refusal")
  expect_match(conditionMessage(err), "IO_NARRATIVE_FILE_NOT_DOCX", fixed = TRUE)

  writeLines("not a zip at all", file.path(d, "Broken.docx"))
  capture.output(err <- tryCatch(load_narrative(list(narrative_file = "Broken.docx"), cfg),
                                 turas_refusal = function(e) e))
  expect_s3_class(err, "turas_refusal")
  expect_match(conditionMessage(err), "IO_NARRATIVE_FILE_UNREADABLE", fixed = TRUE)
})

test_that("the path resolves against the config folder and tolerates quotes", {
  d <- tempfile("narrpath"); dir.create(file.path(d, "05_Reporting"), recursive = TRUE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  file.copy(FIXTURE, file.path(d, "05_Reporting", "Narrative.docx"))
  cfg <- file.path(d, "Crosstab_Config.xlsx")

  for (v in c("05_Reporting/Narrative.docx", "'05_Reporting/Narrative.docx'",
              sprintf('"%s"', file.path(d, "05_Reporting", "Narrative.docx")))) {
    expect_identical(resolve_narrative_file(v, cfg),
                     normalizePath(file.path(d, "05_Reporting", "Narrative.docx")), info = v)
  }
})

# ==============================================================================
# COMMENTS FALLBACK
# ==============================================================================

test_that("the Comments cells convert to the same screen shape", {
  screens <- narrative_from_comments(
    "Staff survey, fourth wave.\n\nMethod:\n- Online\n* 136 responses",
    "Ratings are stable.\r\n- Satisfaction 3.9\n- Engagement 4.16\n\nParticipation fell.")
  expect_identical(screens, list(
    list(id = "background-method", title = "Background & method", blocks = list(
      para(run("Staff survey, fourth wave.")),
      para(run("Method:")),
      list(type = "list", items = list(item("Online"), item("136 responses"))))),
    list(id = "executive-summary", title = "Executive summary", blocks = list(
      para(run("Ratings are stable.")),
      list(type = "list", items = list(item("Satisfaction 3.9"), item("Engagement 4.16"))),
      para(run("Participation fell."))))
  ))
})

test_that("a blank Comments cell gives no screen, and both blank give none", {
  expect_null(narrative_from_comments(NULL, NULL))
  expect_null(narrative_from_comments("", "  "))
  one <- narrative_from_comments(NULL, "Only this.")
  expect_length(one, 1)
  expect_identical(one[[1]]$id, "executive-summary")
  # a blank setting takes the fallback, exactly as before the setting existed
  expect_identical(
    load_narrative(list(narrative_file = "", executive_summary = "Only this."), "cfg.xlsx"),
    one)
  expect_identical(
    load_narrative(list(narrative_file = NA, executive_summary = "Only this."), "cfg.xlsx"),
    one)
})

test_that("fieldwork dates stand in for a blank _BACKGROUND, as the Report tab always did", {
  para <- function(text) list(type = "paragraph",
                              runs = list(list(text = text, bold = FALSE, italic = FALSE)))
  bg <- narrative_from_comments(NULL, NULL, "May 2026")
  expect_length(bg, 1)
  expect_identical(bg[[1]]$id, "background-method")
  expect_identical(bg[[1]]$blocks, list(para("Fieldwork: May 2026.")))
  # the loader passes the setting through on the blank-key path
  both <- load_narrative(list(narrative_file = "", fieldwork_dates = "May 2026",
                              executive_summary = "Only this."), "cfg.xlsx")
  expect_identical(vapply(both, `[[`, "", "id"), c("background-method", "executive-summary"))
  # authored background text wins, and blank dates add nothing
  expect_identical(narrative_from_comments("Why.", NULL, "May 2026")[[1]]$blocks,
                   list(para("Why.")))
  expect_null(narrative_from_comments(NULL, NULL, "  "))
})

# ==============================================================================
# THE SETTING, THE LOADER AND THE ISLAND
# ==============================================================================

test_that("narrative_file is read by the builder and whitelisted", {
  expect_true("narrative_file" %in% TABS_KNOWN_SETTINGS)
  expect_identical(build_config_object(list(narrative_file = "Summary.docx"))$narrative_file,
                   "Summary.docx")
  expect_identical(build_config_object(list(structure_file = "x.xlsx"))$narrative_file, "")
})

test_that("the screens reach config_obj through the REAL config loader", {
  demo_dir <- file.path(turas_root, "examples/tabs/demo_survey")
  skip_if_not(file.exists(file.path(demo_dir, "Demo_Crosstab_Config.xlsx")),
    "Demo survey fixture not found")
  skip_if_not(file.exists(FIXTURE), "narrative fixture not present")

  d <- tempfile("narre2e"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  file.copy(list.files(demo_dir, full.names = TRUE), d, recursive = TRUE)
  dir.create(file.path(d, "05_Reporting"))
  file.copy(FIXTURE, file.path(d, "05_Reporting", "Narrative.docx"))
  cfg <- file.path(d, "Demo_Crosstab_Config.xlsx")

  settings <- openxlsx::read.xlsx(cfg, sheet = "Settings", colNames = FALSE,
                                  skipEmptyRows = FALSE)
  wb <- openxlsx::loadWorkbook(cfg)
  openxlsx::writeData(wb, "Settings",
    data.frame(a = "narrative_file", b = "05_Reporting/Narrative.docx"),
    startRow = nrow(settings) + 1, colNames = FALSE)
  openxlsx::saveWorkbook(wb, cfg, overwrite = TRUE)

  capture.output(res <- suppressMessages(load_crosstabs_config(cfg)))
  capture.output(direct <- read_narrative_docx(file.path(d, "05_Reporting", "Narrative.docx")))
  expect_identical(res$config_obj$narrative, direct)
  expect_identical(vapply(res$config_obj$narrative, function(s) s$id, character(1)),
                   c("background-method", "executive-summary", "executive-summary-2"))

  # and a Settings cell pointing at nothing stops the load
  wb <- openxlsx::loadWorkbook(cfg)
  openxlsx::writeData(wb, "Settings",
    data.frame(a = "narrative_file", b = "05_Reporting/Gone.docx"),
    startRow = nrow(settings) + 1, colNames = FALSE)
  openxlsx::saveWorkbook(wb, cfg, overwrite = TRUE)
  capture.output(err <- tryCatch(suppressMessages(load_crosstabs_config(cfg)),
                                 turas_refusal = function(e) e))
  expect_s3_class(err, "turas_refusal")
  expect_match(conditionMessage(err), "IO_NARRATIVE_FILE_NOT_FOUND", fixed = TRUE)
})

test_that("with no setting, the loader converts the Comments cells", {
  demo_dir <- file.path(turas_root, "examples/tabs/demo_survey")
  skip_if_not(file.exists(file.path(demo_dir, "Demo_Crosstab_Config.xlsx")),
    "Demo survey fixture not found")

  d <- tempfile("narrcmt"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  file.copy(list.files(demo_dir, full.names = TRUE), d, recursive = TRUE)
  cfg <- file.path(d, "Demo_Crosstab_Config.xlsx")
  wb <- openxlsx::loadWorkbook(cfg)
  openxlsx::addWorksheet(wb, "Comments")
  openxlsx::writeData(wb, "Comments", data.frame(
    QuestionCode = c("_BACKGROUND", "_EXECUTIVE_SUMMARY"),
    Comment = c("Fourth wave.", "Stable.\n- Up\n- Down"), stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, cfg, overwrite = TRUE)

  capture.output(res <- suppressMessages(load_crosstabs_config(cfg)))
  expect_identical(res$config_obj$narrative,
                   narrative_from_comments("Fourth wave.", "Stable.\n- Up\n- Down"))
  # report_meta still carries the same cells for the About card and cover
  expect_identical(res$config_obj$executive_summary, "Stable.\n- Up\n- Down")
})

test_that("project.narrative rides the island only when there are screens", {
  screens <- narrative_from_comments("Fourth wave.", NULL)
  proj <- build_dl_project(list(narrative = screens))
  expect_identical(proj$narrative, screens)
  expect_false("narrative" %in% names(build_dl_project(list())))
  expect_false("narrative" %in% names(build_dl_project(list(narrative = NULL))))
  # the real loader's shape when there are no screens: narrative_file is set
  # (blank) and narrative is absent, so $ would have read narrative_file
  cfg <- list(narrative_file = "")
  cfg$narrative <- NULL
  expect_false("narrative" %in% names(build_dl_project(cfg)))
  expect_false("narrative" %in% names(build_dl_project(list(narrative_file = "C:/doc.docx"))))
})

test_that("the island JSON keeps screens, blocks, items and table rows as arrays", {
  skip_if_not(file.exists(FIXTURE), "narrative fixture not present")
  one_cell <- list(list(id = "t", title = "T", blocks = list(
    list(type = "table", rows = list(list("Only"))),
    list(type = "list", items = list(item("Solo"))))))
  capture.output(fixture <- read_narrative_docx(FIXTURE))

  for (screens in list(one_cell, fixture)) {
    json <- as.character(serialize_data_layer(list(project = build_dl_project(
      list(narrative = screens)))))
    back <- jsonlite::fromJSON(json, simplifyVector = FALSE)$project$narrative
    expect_length(back, length(screens))
    expect_true(is.list(back[[1]]$blocks))
    # the reader's ignored counts ride config_obj as an attribute, for the
    # console and these tests; they must never reach the client's file
    expect_false(grepl('"ignored"', json, fixed = TRUE))
  }
  json <- as.character(serialize_data_layer(list(project = build_dl_project(
    list(narrative = one_cell)))))
  expect_true(grepl('"rows":[["Only"]]', json, fixed = TRUE))
  expect_true(grepl('"items":[{"level":0,"ordered":false,"runs":[{"text":"Solo"', json, fixed = TRUE))
  expect_true(grepl('"narrative":[{"id":"t"', json, fixed = TRUE))
})
