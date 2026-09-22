# ==============================================================================
# NARRATIVE FIXTURE. Generator for the Word document the narrative reader reads
# ==============================================================================
#
# Writes narrative_fixture.docx, the document test_narrative_reader.R asserts
# the exact block list of. The file is COMMITTED; this script is how it was
# made, so it can be rebuilt when the reader's scope deliberately changes.
#
# WHY IT IS HAND-WRITTEN XML. officer can write headings, paragraphs and tables,
# but not text boxes, SmartArt, charts, tracked changes, comments or a numbered
# list it guarantees. The fixture has to carry every feature the reader honours
# AND every one it ignores (NARRATIVE_SCREENS_BRIEF.md, "Scope: the fixed
# list"), so the parts are written directly and zipped.
#
# WHAT THE FIXTURE DELIBERATELY CARRIES:
#   - a Title paragraph before the first Heading 1 (skipped as preamble)
#   - Heading 1 under a non-English style id ("berschrift1", named "heading 1"),
#     so the reader is proved to match style NAMES, as localised Word writes them
#   - Heading 2 under the Dutch id "Kop2"; one Heading 3 (read as a paragraph)
#   - bold and italic runs, a hyperlink, a soft line break
#   - a bulleted list with a nested level, a numbered list, and a bullet whose
#     numbering comes from its style (List Bullet) rather than the paragraph
#   - a Quote paragraph; a picture on its own; a picture mid-paragraph
#   - a simple table (one cell holding two paragraphs, one cell a picture) and a
#     table with a merged cell (skipped whole)
#   - a tracked insertion and deletion, a footnote, a comment, a text box (with
#     its VML fallback twin, which must be counted once), a shape, a chart, a
#     SmartArt graphic, an EMF picture, a linked picture, an equation, a content
#     control, a two-column section, a header with text and an empty footer
#   - an empty paragraph, and a duplicated Heading 1
#
# The chart and SmartArt drawings point at relationship ids with no part behind
# them. The reader never follows those, and a real part would add nothing to
# what is tested. LibreOffice opens the file; Word may offer to repair it.
#
# REGENERATE WITH (from the Turas root):
#   Rscript modules/tabs/tests/fixtures/narrative/generate_narrative_fixture.R
#
# Sourcing this file only defines the builders (the tests use them for small
# one-off documents); it writes nothing unless run as a script.
# ==============================================================================

NARRATIVE_FIXTURE_NS <- paste(
  'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"',
  'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"',
  'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"',
  'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"',
  'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"',
  'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"',
  'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"',
  'xmlns:v="urn:schemas-microsoft-com:vml"',
  'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"',
  'mc:Ignorable="wps"'
)

# ---- small XML builders ------------------------------------------------------

fx_esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

fx_run <- function(text, bold = FALSE, italic = FALSE) {
  rpr <- paste0(if (bold) "<w:b/>" else "", if (italic) "<w:i/>" else "")
  if (nzchar(rpr)) rpr <- paste0("<w:rPr>", rpr, "</w:rPr>")
  sprintf('<w:r>%s<w:t xml:space="preserve">%s</w:t></w:r>', rpr, fx_esc(text))
}

fx_par <- function(..., style = NULL, num = NULL) {
  ppr <- ""
  if (!is.null(style)) ppr <- paste0(ppr, sprintf('<w:pStyle w:val="%s"/>', style))
  if (!is.null(num)) {
    ppr <- paste0(ppr, sprintf('<w:numPr><w:ilvl w:val="%d"/><w:numId w:val="%d"/></w:numPr>',
                               num[2], num[1]))
  }
  if (nzchar(ppr)) ppr <- paste0("<w:pPr>", ppr, "</w:pPr>")
  paste0("<w:p>", ppr, paste0(..., collapse = ""), "</w:p>")
}

fx_drawing <- function(uri, inner, name = "Drawing", descr = "", id = 1) {
  sprintf(paste0(
    '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">',
    '<wp:extent cx="914400" cy="457200"/><wp:docPr id="%d" name="%s" descr="%s"/>',
    '<a:graphic><a:graphicData uri="%s">%s</a:graphicData></a:graphic>',
    '</wp:inline></w:drawing></w:r>'), id, fx_esc(name), fx_esc(descr), uri, inner)
}

fx_picture <- function(rid, descr = "", id = 1, linked = FALSE) {
  blip <- if (linked) sprintf('<a:blip r:link="%s"/>', rid) else sprintf('<a:blip r:embed="%s"/>', rid)
  fx_drawing("http://schemas.openxmlformats.org/drawingml/2006/picture", paste0(
    '<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="pic"/><pic:cNvPicPr/></pic:nvPicPr>',
    '<pic:blipFill>', blip, '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>',
    '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="914400" cy="457200"/></a:xfrm>',
    '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'),
    name = "Picture", descr = descr, id = id)
}

fx_cell <- function(...) paste0("<w:tc><w:tcPr/>", paste0(..., collapse = ""), "</w:tc>")
fx_row <- function(...) paste0("<w:tr>", paste0(..., collapse = ""), "</w:tr>")
fx_table <- function(...) paste0("<w:tbl><w:tblPr/><w:tblGrid/>", paste0(..., collapse = ""), "</w:tbl>")

# ---- package writer ----------------------------------------------------------

#' Write a minimal .docx from its parts
#'
#' @param path Output .docx path
#' @param body_xml The inside of w:body (paragraphs, tables, sectPr)
#' @param doc_rels Extra Relationship elements for word/_rels/document.xml.rels
#' @param media Named list of raw vectors, written to word/media/<name>
#' @param extra_parts Named list of XML strings, written to word/<name>
#' @param styles_xml,numbering_xml Replace the default styles / numbering parts
#' @return path, invisibly
write_narrative_docx <- function(path, body_xml, doc_rels = "", media = list(),
                                 extra_parts = list(),
                                 styles_xml = narrative_fixture_styles(),
                                 numbering_xml = narrative_fixture_numbering()) {
  root <- tempfile("narrative_docx_")
  dir.create(file.path(root, "_rels"), recursive = TRUE)
  dir.create(file.path(root, "word", "_rels"), recursive = TRUE)
  dir.create(file.path(root, "word", "media"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  put <- function(rel, txt) writeLines(txt, file.path(root, rel), useBytes = TRUE)

  put("[Content_Types].xml", paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Default Extension="png" ContentType="image/png"/>',
    '<Default Extension="emf" ContentType="image/x-emf"/>',
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>',
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>',
    '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>',
    if ("header1.xml" %in% names(extra_parts)) '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>' else "",
    if ("footer1.xml" %in% names(extra_parts)) '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>' else "",
    if ("footnotes.xml" %in% names(extra_parts)) '<Override PartName="/word/footnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"/>' else "",
    if ("comments.xml" %in% names(extra_parts)) '<Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>' else "",
    '</Types>'))
  put(file.path("_rels", ".rels"), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>',
    '</Relationships>'))
  put(file.path("word", "_rels", "document.xml.rels"), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    '<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>',
    doc_rels, '</Relationships>'))
  put(file.path("word", "document.xml"), paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:document ', NARRATIVE_FIXTURE_NS, '><w:body>', body_xml, '</w:body></w:document>'))
  put(file.path("word", "styles.xml"), styles_xml)
  put(file.path("word", "numbering.xml"), numbering_xml)
  for (nm in names(extra_parts)) put(file.path("word", nm), extra_parts[[nm]])
  for (nm in names(media)) writeBin(media[[nm]], file.path(root, "word", "media", nm))

  files <- list.files(root, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  # [Content_Types].xml first, as Word writes it
  files <- c("[Content_Types].xml", setdiff(files, "[Content_Types].xml"))
  # zip::zip changes directory to root, so the target has to be absolute
  target <- file.path(normalizePath(dirname(path)), basename(path))
  if (file.exists(target)) unlink(target)
  zip::zip(target, files = files, root = root, mode = "mirror")
  invisible(path)
}

narrative_fixture_styles <- function() {
  sty <- function(id, name, extra = "") {
    sprintf('<w:style w:type="paragraph" w:styleId="%s"><w:name w:val="%s"/>%s</w:style>',
            id, name, extra)
  }
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>',
    sty("Title", "Title", '<w:basedOn w:val="Normal"/>'),
    sty("berschrift1", "heading 1", '<w:basedOn w:val="Normal"/>'),
    sty("Kop2", "heading 2", '<w:basedOn w:val="Normal"/>'),
    sty("Heading3", "heading 3", '<w:basedOn w:val="Normal"/>'),
    sty("Quote", "Quote", '<w:basedOn w:val="Normal"/>'),
    sty("ListParagraph", "List Paragraph", '<w:basedOn w:val="Normal"/>'),
    sty("ListBullet", "List Bullet",
        '<w:basedOn w:val="Normal"/><w:pPr><w:numPr><w:numId w:val="3"/></w:numPr></w:pPr>'),
    '</w:styles>')
}

narrative_fixture_numbering <- function() {
  lvl <- function(i, fmt) sprintf('<w:lvl w:ilvl="%d"><w:start w:val="1"/><w:numFmt w:val="%s"/></w:lvl>', i, fmt)
  paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    '<w:abstractNum w:abstractNumId="0">', lvl(0, "bullet"), lvl(1, "bullet"), '</w:abstractNum>',
    '<w:abstractNum w:abstractNumId="1">', lvl(0, "decimal"), lvl(1, "lowerLetter"), '</w:abstractNum>',
    '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>',
    '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>',
    '<w:num w:numId="3"><w:abstractNumId w:val="0"/></w:num>',
    '</w:numbering>')
}

# A real PNG from base R's own device, so the pixel-size reader is tested on
# genuine encoder output. 40 x 20 keeps the committed fixture small.
narrative_fixture_png <- function(w = 40, h = 20) {
  p <- tempfile(fileext = ".png")
  on.exit(unlink(p), add = TRUE)
  grDevices::png(p, width = w, height = h)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  grDevices::dev.off()
  readBin(p, "raw", file.info(p)$size)
}

# ---- the committed fixture ---------------------------------------------------

build_narrative_fixture <- function(path) {
  W <- "http://schemas.openxmlformats.org/drawingml/2006"

  textbox <- paste0(
    '<w:r><mc:AlternateContent><mc:Choice Requires="wps"><w:drawing>',
    '<wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="1" ',
    'behindDoc="0" locked="0" layoutInCell="1" allowOverlap="1"><wp:simplePos x="0" y="0"/>',
    '<wp:positionH relativeFrom="column"><wp:posOffset>0</wp:posOffset></wp:positionH>',
    '<wp:positionV relativeFrom="paragraph"><wp:posOffset>0</wp:posOffset></wp:positionV>',
    '<wp:extent cx="914400" cy="457200"/><wp:wrapNone/><wp:docPr id="20" name="Text Box 1"/>',
    '<a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">',
    '<wps:wsp><wps:spPr/><wps:txbx><w:txbxContent>', fx_par(fx_run("Hidden box text")),
    '</w:txbxContent></wps:txbx><wps:bodyPr/></wps:wsp></a:graphicData></a:graphic>',
    '</wp:anchor></w:drawing></mc:Choice><mc:Fallback><w:pict><v:shape><v:textbox>',
    '<w:txbxContent>', fx_par(fx_run("Hidden box text")), '</w:txbxContent>',
    '</v:textbox></v:shape></w:pict></mc:Fallback></mc:AlternateContent></w:r>')

  shape <- fx_drawing("http://schemas.microsoft.com/office/word/2010/wordprocessingShape",
    '<wps:wsp><wps:spPr><a:prstGeom prst="rightArrow"><a:avLst/></a:prstGeom></wps:spPr><wps:bodyPr/></wps:wsp>',
    name = "Arrow", id = 21)
  chart <- fx_drawing(paste0(W, "/chart"),
    '<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" r:id="rIdChartMissing"/>',
    name = "Chart", id = 22)
  smartart <- fx_drawing(paste0(W, "/diagram"),
    '<dgm:relIds xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" r:dm="rIdDgmMissing" r:lo="rIdDgmMissing" r:qs="rIdDgmMissing" r:cs="rIdDgmMissing"/>',
    name = "Diagram", id = 23)

  body <- paste0(
    fx_par(fx_run("Fixture narrative"), style = "Title"),
    fx_par(fx_run("Background & method"), style = "berschrift1"),
    fx_par(fx_run("This study has "), fx_run("136", bold = TRUE), fx_run(" responses and "),
           fx_run("two", italic = TRUE), fx_run(" sections.")),
    fx_par(fx_run("See the "), '<w:hyperlink r:id="rIdLink">', fx_run("Turas site"),
           '</w:hyperlink>', fx_run(" for more.")),
    fx_par('<w:r><w:t>Line one</w:t><w:br/><w:t>line two</w:t></w:r>'),
    fx_par(fx_run("How we asked"), style = "Kop2"),
    fx_par(fx_run("Online survey"), style = "ListParagraph", num = c(1, 0)),
    fx_par(fx_run("Invites by email"), style = "ListParagraph", num = c(1, 1)),
    fx_par(fx_run("Two reminders"), style = "ListParagraph", num = c(1, 0)),
    fx_par(fx_run("A paragraph between lists.")),
    fx_par(fx_run("First step"), style = "ListParagraph", num = c(2, 0)),
    fx_par(fx_run("Second step"), style = "ListParagraph", num = c(2, 0)),
    fx_table(
      fx_row(fx_cell(fx_par(fx_run("Group"), fx_picture("rIdImg1", id = 2))),
             fx_cell(fx_par(fx_run("n"))), fx_cell(fx_par(fx_run("%")))),
      fx_row(fx_cell(fx_par(fx_run("Staff"))), fx_cell(fx_par(fx_run("136"))),
             fx_cell(fx_par(fx_run("58%")), fx_par(fx_run("of invites"))))),
    fx_par(fx_run("Response rate "),
           '<w:ins w:id="1" w:author="A" w:date="2026-09-22T00:00:00Z">', fx_run("fell "), '</w:ins>',
           '<w:del w:id="2" w:author="A" w:date="2026-09-22T00:00:00Z"><w:r><w:delText xml:space="preserve">rose </w:delText></w:r></w:del>',
           fx_run("to 58%.")),
    fx_par(fx_run("Executive summary"), style = "berschrift1"),
    fx_par('<w:commentRangeStart w:id="0"/>', fx_run("Ratings are stable."),
           '<w:commentRangeEnd w:id="0"/><w:r><w:commentReference w:id="0"/></w:r>',
           '<w:r><w:footnoteReference w:id="1"/></w:r>'),
    fx_par(fx_run("\"Culture varies by campus.\""), style = "Quote"),
    fx_par(fx_picture("rIdImg1", descr = "Response chart", id = 3)),
    fx_par(fx_run("Text before."), fx_picture("rIdImg1", id = 4), fx_run("Text after.")),
    fx_par(fx_run("Visible text."), textbox),
    fx_par(shape),
    fx_par(chart),
    fx_par(smartart),
    fx_par(fx_picture("rIdImg2", descr = "Pasted chart", id = 5)),
    fx_par(fx_picture("rIdLinked", id = 6, linked = TRUE)),
    fx_par(fx_run("Equation follows."), '<m:oMath><m:r><m:t>x</m:t></m:r></m:oMath>'),
    fx_table(
      fx_row('<w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr>', fx_par(fx_run("Merged")), '</w:tc>'),
      fx_row(fx_cell(fx_par(fx_run("a"))), fx_cell(fx_par(fx_run("b"))))),
    fx_par(fx_run("Minor heading"), style = "Heading3"),
    fx_par(),
    fx_par(fx_run("Styled bullet"), style = "ListBullet"),
    '<w:sdt><w:sdtPr/><w:sdtContent>', fx_par(fx_run("Inside a control")), '</w:sdtContent></w:sdt>',
    fx_par(fx_run("Executive summary"), style = "berschrift1"),
    fx_par(fx_run("Second occurrence.")),
    '<w:sectPr><w:headerReference w:type="default" r:id="rIdHdr1"/>',
    '<w:footerReference w:type="default" r:id="rIdFtr1"/>',
    '<w:pgSz w:w="11906" w:h="16838"/><w:cols w:num="2" w:space="720"/></w:sectPr>')

  rel <- function(id, type, target, external = FALSE) {
    sprintf('<Relationship Id="%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/%s" Target="%s"%s/>',
            id, type, target, if (external) ' TargetMode="External"' else "")
  }
  rels <- paste0(
    rel("rIdImg1", "image", "media/image1.png"),
    rel("rIdImg2", "image", "media/image2.emf"),
    rel("rIdLinked", "image", "file:///C:/charts/linked.png", external = TRUE),
    rel("rIdLink", "hyperlink", "https://example.org/turas", external = TRUE),
    rel("rIdHdr1", "header", "header1.xml"),
    rel("rIdFtr1", "footer", "footer1.xml"),
    rel("rIdFootnotes", "footnotes", "footnotes.xml"),
    rel("rIdComments", "comments", "comments.xml"))

  wpart <- function(tag, inner) {
    sprintf('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:%s %s>%s</w:%s>',
            tag, NARRATIVE_FIXTURE_NS, inner, tag)
  }
  extra <- list(
    "header1.xml" = wpart("hdr", fx_par(fx_run("Confidential"))),
    "footer1.xml" = wpart("ftr", fx_par()),
    "footnotes.xml" = wpart("footnotes", paste0(
      '<w:footnote w:type="separator" w:id="-1">', fx_par(), '</w:footnote>',
      '<w:footnote w:id="1">', fx_par(fx_run("Weighted to staff numbers.")), '</w:footnote>')),
    "comments.xml" = wpart("comments", paste0(
      '<w:comment w:id="0" w:author="A" w:date="2026-09-22T00:00:00Z">',
      fx_par(fx_run("Check this figure.")), '</w:comment>')))

  # Not a real EMF: the reader decides on the extension alone and never
  # decodes it, which is exactly the behaviour under test.
  media <- list("image1.png" = narrative_fixture_png(),
                "image2.emf" = as.raw(c(1, 0, 0, 0, 0x6c, 0, 0, 0)))

  write_narrative_docx(path, body, doc_rels = rels, media = media, extra_parts = extra)
}

# ---- the JS suites' island fixture ------------------------------------------

#' The content of html_report_v2/tests/fixtures/narrative_island.json
#'
#' project.narrative exactly as the island carries it, for the reader's output
#' on the committed fixture ("word") and for a small Comments fallback
#' ("comments"). Each goes through the real island serializer and back, so the
#' node suites see what a browser sees. test_narrative_reader.R compares the
#' committed file with this and, with TURAS_REGEN_NARRATIVE_ISLAND=1 set,
#' rewrites it. Needs the reader and data_layer_writer.R loaded.
#'
#' @param word_screens read_narrative_docx() on narrative_fixture.docx
#' @return A list(_about, word, comments), as the JSON file holds it
narrative_island_fixture <- function(word_screens) {
  as_island <- function(screens) {
    json <- as.character(serialize_data_layer(list(project = build_dl_project(
      list(narrative = screens)))))
    jsonlite::fromJSON(json, simplifyVector = FALSE)$project$narrative
  }
  attr(word_screens, "ignored") <- NULL
  list(
    `_about` = paste(
      "project.narrative exactly as the R build emits it (the island serializer).",
      "'word' is read_narrative_docx() on",
      "modules/tabs/tests/fixtures/narrative/narrative_fixture.docx; 'comments' is",
      "narrative_from_comments('Why we ran it.\\n\\n- one\\n- two', 'First.\\nSecond.').",
      "Never edit by hand: rerun test_narrative_reader.R with",
      "TURAS_ROOT set and TURAS_REGEN_NARRATIVE_ISLAND=1."),
    word = as_island(word_screens),
    comments = as_island(narrative_from_comments("Why we ran it.\n\n- one\n- two",
                                                 "First.\nSecond.")))
}

if (sys.nframe() == 0) {
  here <- file.path("modules", "tabs", "tests", "fixtures", "narrative")
  if (!dir.exists(here)) {
    cat("Run this from the Turas root folder.\n")
    quit(status = 1)
  }
  out <- file.path(here, "narrative_fixture.docx")
  build_narrative_fixture(out)
  cat("Wrote", out, "\n")
}
