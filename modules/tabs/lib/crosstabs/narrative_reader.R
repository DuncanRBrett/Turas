# ==============================================================================
# TABS - NARRATIVE READER (Word document -> report screens)
# ==============================================================================
#
# The report's Background and Executive summary can be written in a Word
# document named by the narrative_file setting. Each Heading 1 starts one
# screen. This file reads that document into a list of screens,
#
#   list(id = "executive-summary", title = "Executive summary", blocks = list(...))
#
# and, when the setting is blank, converts the Comments sheet's _BACKGROUND and
# _EXECUTIVE_SUMMARY cells into the same shape, so everything downstream has
# one input. The screens ride to the report as project.narrative
# (data_layer_writer.R). Build brief: modules/tabs/docs/NARRATIVE_SCREENS_BRIEF.md.
#
# BLOCK KINDS (the fixed scope list; nothing else is half-read):
#   subheading  list(type, text)                        Heading 2
#   paragraph   list(type, runs)                        Normal text
#   quote       list(type, runs)                        Quote style
#   list        list(type, items = list(list(level, ordered, runs, number?)))
#               number: the number Word shows, on ordered items only
#   image       list(type, src, alt?, width?, height?)  embedded picture
#   table       list(type, rows = list(list("cell", ...))) text cells only
# A run is list(text, bold, italic).
#
# Everything outside that list is counted and named in the console, never
# silently dropped and never partly rendered. The counts ride on the result as
# attr(screens, "ignored") so the tests can assert them.
#
# Word is read as its own XML (xml2), not through officer::docx_summary, because
# the summary carries neither run formatting nor picture positions.
# ==============================================================================

.NARRATIVE_NS <- c(
  w   = "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
  r   = "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
  wp  = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
  a   = "http://schemas.openxmlformats.org/drawingml/2006/main",
  pic = "http://schemas.openxmlformats.org/drawingml/2006/picture",
  mc  = "http://schemas.openxmlformats.org/markup-compatibility/2006",
  wps = "http://schemas.microsoft.com/office/word/2010/wordprocessingShape",
  v   = "urn:schemas-microsoft-com:vml",
  m   = "http://schemas.openxmlformats.org/officeDocument/2006/math",
  pr  = "http://schemas.openxmlformats.org/package/2006/relationships"
)

.NARRATIVE_PICTURE_URI <- "http://schemas.openxmlformats.org/drawingml/2006/picture"
.NARRATIVE_IMAGE_MIME <- c(png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
                           gif = "image/gif")

# Title of the single screen a document without any Heading 1 becomes, and of
# the Comments fallback screens (the Report tab's own card titles, 32_report.js).
.NARRATIVE_UNTITLED <- "Executive summary"
.NARRATIVE_FALLBACK_TITLES <- c(background = "Background & method",
                                exec = "Executive summary")

# What is skipped, in console order: the noun, and what happened plus the fix.
.NARRATIVE_IGNORED <- list(
  preamble         = c("paragraph(s) before the first Heading 1", "Not read. Put them under a Heading 1."),
  minor_headings   = c("Heading 3 or lower", "Read as ordinary paragraphs."),
  hyperlinks       = c("hyperlink(s)", "The words are kept and the link is dropped."),
  tracked_changes  = c("tracked change(s)", "Read as if accepted. Accept or reject them in Word to be sure."),
  comments         = c("comment(s)", "Review comments never reach the report."),
  footnotes        = c("footnote(s) or endnote(s)", "Not read. Move the note into the text."),
  text_boxes       = c("text box(es)", "Not read. Move the words into the body text."),
  shapes           = c("shape(s) or drawing(s)", "Not read."),
  smartart         = c("SmartArt graphic(s)", "Not read. Paste it as a picture instead."),
  charts           = c("native Word chart(s)", "Not read. Pin the Turas chart after this screen instead."),
  picture_formats  = c("picture(s) in a format a browser cannot show", "Not read. Paste the picture as PNG or JPEG."),
  linked_pictures  = c("linked picture(s)", "Not read. Insert the picture into the document rather than linking to it."),
  table_drawings   = c("picture(s) or drawing(s) inside a table", "Not read. Only the words in a table are kept."),
  merged_tables    = c("table(s) with merged cells", "Not read. Unmerge the cells, or pin the Turas table instead."),
  nested_tables    = c("table(s) inside a table", "Not read."),
  embedded_objects = c("embedded object(s) or equation(s)", "Not read."),
  content_controls = c("content control(s) or other blocks", "Not read. Remove the control and keep its text."),
  columns          = c("multi-column section(s)", "Read in order as one column."),
  headers_footers  = c("header(s) or footer(s) with content", "Not read.")
)

# ==============================================================================
# SETTING -> SCREENS
# ==============================================================================

#' Build the report narrative for a loaded config
#'
#' When \code{narrative_file} is set, the Word document is read (a missing or
#' unreadable file refuses the run). When it is blank, the Comments sheet's
#' background and executive summary text are converted to the same shape, so
#' a project that never mentions the setting behaves exactly as before.
#'
#' @param config_obj The config object from build_config_object(), after the
#'   Comments sheet has filled background_text / executive_summary
#' @param config_file Path to the config workbook (relative paths resolve
#'   against its folder)
#' @return A list of screens, or NULL when there is nothing to show
#' @keywords internal
load_narrative <- function(config_obj, config_file) {
  raw <- config_obj$narrative_file
  if (is_blank_setting(raw)) {
    return(narrative_from_comments(config_obj$background_text,
                                   config_obj$executive_summary,
                                   config_obj$fieldwork_dates))
  }
  path <- resolve_narrative_file(raw, config_file)
  screens <- read_narrative_docx(path)
  if (length(screens) == 0) NULL else screens
}

#' Resolve the narrative_file setting to an existing .docx, or refuse
#'
#' Resolved the way AddedSlides image_path is (load_qualitative_sheet): wrapping
#' quotes stripped, then the path as given, then relative to the config file's
#' own folder.
#'
#' @param raw The setting value
#' @param config_file Path to the config workbook
#' @return The resolved path
#' @keywords internal
resolve_narrative_file <- function(raw, config_file) {
  given <- gsub("^['\"]+|['\"]+$", "", trimws(as.character(raw)[1]))
  # the folder, not the file: normalizePath leaves a path to a file that does
  # not exist unresolved, and the refusal must print where it really looked
  config_dir <- normalizePath(dirname(config_file), mustWork = FALSE)
  path <- given
  if (!file.exists(path) || dir.exists(path)) path <- file.path(config_dir, given)

  if (!file.exists(path) || dir.exists(path)) {
    tabs_refuse(
      code = "IO_NARRATIVE_FILE_NOT_FOUND",
      title = "Narrative Word File Not Found",
      problem = sprintf("The narrative_file setting names '%s', and no file was found there.", given),
      why_it_matters = paste(
        "The report's Background and Executive summary come from this document.",
        "Running without it would ship a report with no summary, or an out of date one."),
      how_to_fix = c(
        "Check the narrative_file cell on the Settings sheet.",
        "A relative path is resolved against the config file's own folder.",
        "Leave the cell blank to use the Comments sheet's _BACKGROUND and _EXECUTIVE_SUMMARY cells instead."),
      details = sprintf("Looked for: %s", normalizePath(path, mustWork = FALSE))
    )
  }
  if (!identical(tolower(tools::file_ext(path)), "docx")) {
    tabs_refuse(
      code = "IO_NARRATIVE_FILE_NOT_DOCX",
      title = "Narrative File Is Not a Word Document",
      problem = sprintf("The narrative_file setting names '%s', which is not a .docx file.", basename(path)),
      why_it_matters = "Only a Word .docx document can be read for the report's summary screens.",
      how_to_fix = "Save the narrative in Word as a Word Document (.docx) and point narrative_file at that file.",
      details = sprintf("File: %s", normalizePath(path, mustWork = FALSE))
    )
  }
  normalizePath(path)
}

#' Refuse a narrative document that cannot be read as Word XML
#' @keywords internal
.narrative_unreadable <- function(path, cause) {
  tabs_refuse(
    code = "IO_NARRATIVE_FILE_UNREADABLE",
    title = "Narrative Word File Could Not Be Read",
    problem = sprintf("'%s' could not be read as a Word document.", basename(path)),
    why_it_matters = "The report's Background and Executive summary come from this document.",
    how_to_fix = c(
      "Open the file in Word and save it again as a Word Document (.docx), not Strict Open XML.",
      "If the file lives in OneDrive, make sure it is downloaded to this computer.",
      "Close any other copy of the file that is still being written, then re-run."),
    details = sprintf("File: %s. Cause: %s", path, cause)
  )
}

# ==============================================================================
# WORD DOCUMENT -> SCREENS
# ==============================================================================

#' Read a Word document into report screens
#'
#' Each Heading 1 starts a screen, titled by its text. Content before the first
#' Heading 1 is skipped (and named); a document with no Heading 1 at all is one
#' screen titled "Executive summary". Screen ids are the heading text as a
#' slug, with "-2", "-3" on repeats, so a pin survives the sections being
#' reordered.
#'
#' @param path Path to an existing .docx
#' @return A list of screens list(id, title, blocks), with attr "ignored" (a
#'   named integer vector of what was skipped). Empty when the document holds
#'   no content.
#' @keywords internal
read_narrative_docx <- function(path) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    tabs_refuse(
      code = "PKG_XML2_MISSING",
      title = "Package xml2 Not Installed",
      problem = "The narrative_file setting needs the 'xml2' package to read Word documents.",
      why_it_matters = "Without it the report's summary screens cannot be read.",
      how_to_fix = "Run renv::restore() (xml2 is in the project lockfile), then re-run."
    )
  }

  pkg <- tempfile("turas_narrative_")
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)

  parts <- tryCatch({
    unzipped <- utils::unzip(path, exdir = pkg)
    if (length(unzipped) == 0) .narrative_unreadable(path, "the file is not a zip package")
    .narrative_parts(pkg, path)
  }, error = function(e) {
    if (inherits(e, "turas_refusal")) stop(e)
    .narrative_unreadable(path, conditionMessage(e))
  }, warning = function(w) {
    .narrative_unreadable(path, conditionMessage(w))
  })

  counts <- setNames(integer(length(.NARRATIVE_IGNORED)), names(.NARRATIVE_IGNORED))
  ctx <- new.env(parent = emptyenv())
  ctx$parts <- parts
  ctx$counts <- counts
  ctx$list_counters <- list()   # numId -> the count at each list level

  screens <- tryCatch({
    out <- .narrative_assemble(ctx)
    .narrative_count_document(ctx)
    out
  }, error = function(e) {
    if (inherits(e, "turas_refusal")) stop(e)
    .narrative_unreadable(path, conditionMessage(e))
  })

  attr(screens, "ignored") <- ctx$counts
  .narrative_report(screens, ctx, path)
  screens
}

#' Locate and parse the parts the reader needs
#' @keywords internal
.narrative_parts <- function(pkg, path) {
  ns <- .NARRATIVE_NS
  rel_map <- function(rels_path) {
    if (!file.exists(rels_path)) {
      return(data.frame(id = character(0), type = character(0), target = character(0),
                        external = logical(0), stringsAsFactors = FALSE))
    }
    rx <- xml2::read_xml(rels_path)
    nodes <- xml2::xml_find_all(rx, "//pr:Relationship", ns)
    data.frame(
      id = xml2::xml_attr(nodes, "Id"),
      type = sub(".*/", "", xml2::xml_attr(nodes, "Type")),
      target = xml2::xml_attr(nodes, "Target"),
      external = !is.na(xml2::xml_attr(nodes, "TargetMode")) &
        xml2::xml_attr(nodes, "TargetMode") == "External",
      stringsAsFactors = FALSE)
  }

  # The main part, from the package relationships (Word always writes
  # word/document.xml, but the package says where it is)
  pkg_rels <- rel_map(file.path(pkg, "_rels", ".rels"))
  main <- pkg_rels$target[pkg_rels$type == "officeDocument"][1]
  if (is.na(main)) main <- "word/document.xml"
  main <- sub("^/", "", main)
  main_path <- file.path(pkg, main)
  if (!file.exists(main_path)) .narrative_unreadable(path, "the package holds no Word document part")
  main_dir <- dirname(main_path)

  doc <- xml2::read_xml(main_path)
  body <- xml2::xml_find_first(doc, "/w:document/w:body", ns)
  if (inherits(body, "xml_missing")) {
    .narrative_unreadable(path, "no Word document body was found (a Strict Open XML file reads this way)")
  }

  rels <- rel_map(file.path(main_dir, "_rels", paste0(basename(main_path), ".rels")))
  part_path <- function(target) {
    if (startsWith(target, "/")) file.path(pkg, sub("^/", "", target)) else file.path(main_dir, target)
  }
  read_part <- function(type) {
    t <- rels$target[rels$type == type & !rels$external]
    p <- if (length(t) > 0) part_path(t[1]) else NA_character_
    if (!is.na(p) && file.exists(p)) xml2::read_xml(p) else NULL
  }

  list(
    body = body,
    rels = rels,
    part_path = part_path,
    styles = .narrative_styles(read_part("styles")),
    numbering = read_part("numbering"),
    header_footer = lapply(
      rels$target[rels$type %in% c("header", "footer") & !rels$external],
      function(t) { p <- part_path(t); if (file.exists(p)) xml2::read_xml(p) else NULL })
  )
}

#' Paragraph styles: id -> lower-case name, basedOn, and any list numbering
#'
#' Matched by NAME, not id: a localised Word writes "berschrift1" or "Kop1" as
#' the id of the style it still names "heading 1".
#' @keywords internal
.narrative_styles <- function(styles_xml) {
  if (is.null(styles_xml)) return(list(by_id = list(), default = NA_character_))
  ns <- .NARRATIVE_NS
  nodes <- xml2::xml_find_all(styles_xml, "//w:style[@w:type='paragraph']", ns)
  by_id <- list()
  default <- NA_character_
  for (s in nodes) {
    id <- xml2::xml_attr(s, "w:styleId", ns)
    if (is.na(id)) next
    name_node <- xml2::xml_find_first(s, "w:name", ns)
    num_node <- xml2::xml_find_first(s, "w:pPr/w:numPr", ns)
    name <- xml2::xml_attr(name_node, "w:val", ns)
    by_id[[id]] <- list(
      name = if (is.na(name)) "" else tolower(trimws(name)),
      based_on = xml2::xml_attr(xml2::xml_find_first(s, "w:basedOn", ns), "w:val", ns),
      num = if (inherits(num_node, "xml_missing")) NULL else .narrative_numpr(num_node),
      # Word's outline level, 0 = level 1. NA when the style does not set one.
      outline = suppressWarnings(as.integer(xml2::xml_attr(
        xml2::xml_find_first(s, "w:pPr/w:outlineLvl", ns), "w:val", ns)))
    )
    if (identical(xml2::xml_attr(s, "w:default", ns), "1")) default <- id
  }
  list(by_id = by_id, default = default)
}

#' list(num_id, ilvl) from a w:numPr node (either may be NA)
#' @keywords internal
.narrative_numpr <- function(node) {
  ns <- .NARRATIVE_NS
  list(
    num_id = xml2::xml_attr(xml2::xml_find_first(node, "w:numId", ns), "w:val", ns),
    ilvl = suppressWarnings(as.integer(
      xml2::xml_attr(xml2::xml_find_first(node, "w:ilvl", ns), "w:val", ns)))
  )
}

#' Is a list level ordered (numbers, letters) rather than bulleted?
#' @keywords internal
.narrative_ordered <- function(numbering, num_id, ilvl) {
  if (is.null(numbering)) return(FALSE)
  ns <- .NARRATIVE_NS
  num <- xml2::xml_find_first(numbering, sprintf("//w:num[@w:numId='%s']", num_id), ns)
  if (inherits(num, "xml_missing")) return(FALSE)
  lvl_q <- sprintf("w:lvl[@w:ilvl='%d']/w:numFmt", ilvl)
  fmt <- xml2::xml_attr(xml2::xml_find_first(
    num, sprintf("w:lvlOverride[@w:ilvl='%d']/%s", ilvl, lvl_q), ns), "w:val", ns)
  if (is.na(fmt)) {
    abs_id <- xml2::xml_attr(xml2::xml_find_first(num, "w:abstractNumId", ns), "w:val", ns)
    abs <- xml2::xml_find_first(numbering, sprintf("//w:abstractNum[@w:abstractNumId='%s']", abs_id), ns)
    fmt <- xml2::xml_attr(xml2::xml_find_first(abs, lvl_q, ns), "w:val", ns)
  }
  !is.na(fmt) && !(fmt %in% c("bullet", "none"))
}

#' The number a list level starts counting from (w:start), 1 when unset
#'
#' A startOverride on the list instance wins, then a level redefined on the
#' instance, then the abstract definition's level.
#' @keywords internal
.narrative_level_start <- function(numbering, num_id, ilvl) {
  if (is.null(numbering)) return(1L)
  ns <- .NARRATIVE_NS
  num <- xml2::xml_find_first(numbering, sprintf("//w:num[@w:numId='%s']", num_id), ns)
  if (inherits(num, "xml_missing")) return(1L)
  over <- sprintf("w:lvlOverride[@w:ilvl='%d']", ilvl)
  val <- xml2::xml_attr(xml2::xml_find_first(num, paste0(over, "/w:startOverride"), ns), "w:val", ns)
  if (is.na(val)) {
    val <- xml2::xml_attr(xml2::xml_find_first(
      num, sprintf("%s/w:lvl[@w:ilvl='%d']/w:start", over, ilvl), ns), "w:val", ns)
  }
  if (is.na(val)) {
    abs_id <- xml2::xml_attr(xml2::xml_find_first(num, "w:abstractNumId", ns), "w:val", ns)
    abs <- xml2::xml_find_first(numbering, sprintf("//w:abstractNum[@w:abstractNumId='%s']", abs_id), ns)
    val <- xml2::xml_attr(xml2::xml_find_first(
      abs, sprintf("w:lvl[@w:ilvl='%d']/w:start", ilvl), ns), "w:val", ns)
  }
  n <- suppressWarnings(as.integer(val))
  if (is.na(n)) 1L else n
}

#' The number Word shows on a list paragraph, advancing the list's counter
#'
#' Word counts per list instance (numId) and per level, in document order: a
#' paragraph between two items of the same list does not restart it, so an
#' "aside" between items 2 and 3 still leaves the next item numbered 3. An item
#' at a shallower level restarts every deeper level. Counters live on ctx, so
#' they carry across screens exactly as they do across Word's own pages.
#' @keywords internal
.narrative_list_number <- function(ctx, num_id, level) {
  counters <- ctx$list_counters[[num_id]] %||% rep(NA_integer_, 9L)
  idx <- min(max(level, 0L), 8L) + 1L
  if (idx < 9L) counters[(idx + 1L):9L] <- NA_integer_
  counters[idx] <- if (is.na(counters[idx])) {
    .narrative_level_start(ctx$parts$numbering, num_id, idx - 1L)
  } else counters[idx] + 1L
  ctx$list_counters[[num_id]] <- counters
  counters[idx]
}

# ==============================================================================
# BODY WALK
# ==============================================================================

#' Walk the body into screens
#' @keywords internal
.narrative_assemble <- function(ctx) {
  ns <- .NARRATIVE_NS
  items <- list()
  for (node in xml2::xml_children(ctx$parts$body)) {
    nm <- xml2::xml_name(node, ns)
    if (nm == "w:p") {
      items[[length(items) + 1L]] <- .narrative_paragraph(node, ctx)
    } else if (nm == "w:tbl") {
      block <- .narrative_table(node, ctx)
      if (!is.null(block)) items[[length(items) + 1L]] <- list(kind = "block", block = block)
    } else if (nm %in% c("w:sectPr", "w:bookmarkStart", "w:bookmarkEnd", "w:proofErr",
                         "w:commentRangeStart", "w:commentRangeEnd",
                         "w:permStart", "w:permEnd")) {
      next  # layout or markup, no content of its own
    } else {
      ctx$counts[["content_controls"]] <- ctx$counts[["content_controls"]] + 1L
    }
  }

  has_h1 <- any(vapply(items, function(it) identical(it$kind, "h1"), logical(1)))
  ctx$has_h1 <- has_h1
  screens <- list()
  current <- if (has_h1) NULL else list(title = .NARRATIVE_UNTITLED, blocks = list())

  add_block <- function(block) {
    n <- length(current$blocks)
    if (block$type == "list" && n > 0 && current$blocks[[n]]$type == "list") {
      current$blocks[[n]]$items <<- c(current$blocks[[n]]$items, block$items)
    } else {
      current$blocks[[n + 1L]] <<- block
    }
  }

  for (it in items) {
    if (identical(it$kind, "h1")) {
      if (!is.null(current)) screens[[length(screens) + 1L]] <- current
      current <- list(title = it$title, blocks = list())
      for (b in it$blocks) add_block(b)
      next
    }
    if (is.null(current)) {
      # before the first Heading 1 of a document that has one
      if (!identical(it$kind, "empty")) {
        ctx$counts[["preamble"]] <- ctx$counts[["preamble"]] + 1L
      }
      next
    }
    if (identical(it$kind, "block")) {
      add_block(it$block)
    } else if (identical(it$kind, "blocks")) {
      for (b in it$blocks) add_block(b)
    }
  }
  if (!is.null(current)) screens[[length(screens) + 1L]] <- current

  # A headingless document with nothing in it is no screen at all
  if (!has_h1 && length(screens) == 1L && length(screens[[1]]$blocks) == 0L) {
    screens <- list()
  }

  ids <- .narrative_screen_ids(vapply(screens, function(s) s$title, character(1)))
  lapply(seq_along(screens), function(i) {
    list(id = ids[i], title = screens[[i]]$title, blocks = screens[[i]]$blocks)
  })
}

#' Screen ids: each title's own, so a pin follows its section when reordered
#'
#' The id is the title as a lower-case ASCII slug. Two DIFFERENT titles that
#' slug alike ("Q1: Results", "Q1 results") each add a code computed from their
#' exact wording, and a title with no ASCII letter or digit at all ("★ 要点") is
#' "screen-" plus that code, so neither case falls back to document position.
#' Only a genuinely repeated title takes "-2", "-3" in order, as the brief says.
#'
#' @param titles Screen titles in document order
#' @return Character vector of unique ids, one per title
#' @keywords internal
.narrative_screen_ids <- function(titles) {
  titles <- gsub("\\s+", " ", trimws(titles))
  base <- gsub("^-+|-+$", "", gsub("[^a-z0-9]+", "-", tolower(titles)))
  codes <- vapply(titles, .narrative_title_code, character(1), USE.NAMES = FALSE)
  base[!nzchar(base)] <- paste0("screen-", codes[!nzchar(base)])
  for (b in unique(base)) {
    same <- base == b
    if (length(unique(titles[same])) > 1L) base[same] <- paste0(b, "-", codes[same])
  }
  out <- base
  seen <- list()
  for (i in seq_along(base)) {
    n <- (seen[[base[i]]] %||% 0L) + 1L
    seen[[base[i]]] <- n
    if (n > 1L) out[i] <- paste0(base[i], "-", n)
  }
  out
}

# Modulus of the title code: a prime under 2^26, so every step of the
# polynomial below stays an exact integer in a double (31 * 2^26 < 2^53).
.NARRATIVE_CODE_MOD <- 67108859

#' A short code computed from a title's exact characters (7 hex digits)
#'
#' Base R only and the same on every platform: a polynomial over the Unicode
#' code points, not a locale-dependent transliteration.
#' @keywords internal
.narrative_title_code <- function(title) {
  h <- 0
  for (cp in utf8ToInt(enc2utf8(title))) h <- (h * 31 + cp) %% .NARRATIVE_CODE_MOD
  sprintf("%07x", as.integer(h))
}

#' Classify one body paragraph and read its content
#'
#' @return list(kind = "h1", title, blocks) for a Heading 1; list(kind =
#'   "blocks", blocks) otherwise; list(kind = "empty") when it holds nothing.
#' @keywords internal
.narrative_paragraph <- function(p, ctx) {
  ns <- .NARRATIVE_NS
  styles <- ctx$parts$styles
  style_id <- xml2::xml_attr(xml2::xml_find_first(p, "w:pPr/w:pStyle", ns), "w:val", ns)
  if (is.na(style_id)) style_id <- styles$default
  role <- .narrative_style_role(style_id, styles)
  heading_level <- role$heading

  segments <- .narrative_segments(p, ctx)
  runs <- .narrative_runs(Filter(function(s) s$type == "run", segments))
  images <- lapply(Filter(function(s) s$type == "image", segments), function(s) s$block)
  if (length(runs) == 0 && length(images) == 0) return(list(kind = "empty"))
  plain <- paste(vapply(runs, function(r) r$text, character(1)), collapse = "")

  if (identical(heading_level, 1L)) {
    if (!nzchar(plain)) return(list(kind = "blocks", blocks = images))
    return(list(kind = "h1", title = gsub("\\s+", " ", plain), blocks = images))
  }
  if (identical(heading_level, 2L)) {
    blocks <- if (nzchar(plain)) list(list(type = "subheading", text = gsub("\\s+", " ", plain))) else list()
    return(list(kind = "blocks", blocks = c(blocks, images)))
  }
  if (!is.na(heading_level)) {
    ctx$counts[["minor_headings"]] <- ctx$counts[["minor_headings"]] + 1L
  }

  # List numbering: the paragraph's own, else its style's (List Bullet et al.)
  num <- NULL
  num_node <- xml2::xml_find_first(p, "w:pPr/w:numPr", ns)
  if (!inherits(num_node, "xml_missing")) num <- .narrative_numpr(num_node)
  if (is.null(num) || is.na(num$num_id)) num <- .narrative_style_num(style_id, styles)

  if (is.na(heading_level) && !is.null(num) && !is.na(num$num_id) && num$num_id != "0") {
    level <- if (is.na(num$ilvl)) 0L else num$ilvl
    blocks <- list()
    if (length(runs) > 0) {
      item <- list(level = level,
                   ordered = .narrative_ordered(ctx$parts$numbering, num$num_id, level),
                   runs = runs)
      # counted only for an item that is shown, so the report never skips a number
      number <- .narrative_list_number(ctx, num$num_id, level)
      if (item$ordered) item$number <- number
      blocks <- list(list(type = "list", items = list(item)))
    }
    return(list(kind = "blocks", blocks = c(blocks, images)))
  }

  # A paragraph or quote keeps each picture where it sits in the text
  type <- if (identical(role$kind, "quote")) "quote" else "paragraph"
  blocks <- list()
  pending <- list()
  flush <- function() {
    r <- .narrative_runs(pending)
    if (length(r) > 0) blocks[[length(blocks) + 1L]] <<- list(type = type, runs = r)
    pending <<- list()
  }
  for (s in segments) {
    if (s$type == "run") {
      pending[[length(pending) + 1L]] <- s
    } else {
      flush()
      blocks[[length(blocks) + 1L]] <- s$block
    }
  }
  flush()
  list(kind = "blocks", blocks = blocks)
}

#' What a paragraph style makes a paragraph: a heading (and its level), a
#' quote, or plain text
#'
#' Follows basedOn, the way list numbering does, so a house style built on
#' Heading 1 ("TRL Heading", say) starts a screen just as Heading 1 does. At
#' each step: a built-in heading name decides it; else an outline level set on
#' the style decides it (Word's own "TOC Heading" is based on Heading 1 but
#' sets body-text level 9, so it is not a heading); else a style named Quote
#' makes a quote; else the style it is based on is asked.
#'
#' @return list(kind = "heading" | "quote" | "text", heading = level or NA)
#' @keywords internal
.narrative_style_role <- function(style_id, styles) {
  text <- list(kind = "text", heading = NA_integer_)
  seen <- character(0)
  while (!is.na(style_id) && !(style_id %in% seen)) {
    seen <- c(seen, style_id)
    s <- styles$by_id[[style_id]]
    if (is.null(s)) return(text)
    named <- regmatches(s$name, regexec("^heading ([1-9])$", s$name))[[1]]
    if (length(named) == 2) return(list(kind = "heading", heading = as.integer(named[2])))
    if (!is.null(s$outline) && !is.na(s$outline)) {
      if (s$outline >= 0L && s$outline <= 8L) {
        return(list(kind = "heading", heading = s$outline + 1L))
      }
      return(text)
    }
    if (identical(s$name, "quote")) return(list(kind = "quote", heading = NA_integer_))
    style_id <- s$based_on
  }
  text
}

#' A style's list numbering, following basedOn
#' @keywords internal
.narrative_style_num <- function(style_id, styles) {
  seen <- character(0)
  while (!is.na(style_id) && !(style_id %in% seen)) {
    seen <- c(seen, style_id)
    s <- styles$by_id[[style_id]]
    if (is.null(s)) return(NULL)
    if (!is.null(s$num) && !is.na(s$num$num_id)) return(s$num)
    style_id <- s$based_on
  }
  NULL
}

#' The paragraph's content in order: text runs and pictures
#'
#' Reads only the paragraph's own runs. Text inside a text box lives in
#' w:txbxContent under a drawing and is never reached from here. Deleted text
#' (w:del, w:moveFrom) is skipped and inserted text kept, so tracked changes
#' read as if accepted. With \code{pictures = FALSE} (table cells) drawings are
#' passed over; the whole-document count names them.
#' @keywords internal
.narrative_segments <- function(p, ctx, pictures = TRUE) {
  ns <- .NARRATIVE_NS
  out <- list()
  walk <- function(node) {
    for (child in xml2::xml_children(node)) {
      nm <- xml2::xml_name(child, ns)
      if (nm == "w:r") {
        read_run(child)
      } else if (nm %in% c("w:hyperlink", "w:ins", "w:moveTo", "w:smartTag",
                           "w:customXml", "w:fldSimple", "w:bdo", "w:dir")) {
        walk(child)
      } else if (nm == "w:sdt") {
        content <- xml2::xml_find_first(child, "w:sdtContent", ns)
        if (!inherits(content, "xml_missing")) walk(content)
      }
      # w:del, w:moveFrom, w:pPr, bookmarks, comment ranges, equations: nothing
    }
  }
  read_run <- function(r) {
    rpr <- xml2::xml_find_first(r, "w:rPr", ns)
    bold <- .narrative_toggle(rpr, "w:b")
    italic <- .narrative_toggle(rpr, "w:i")
    for (child in xml2::xml_children(r)) {
      nm <- xml2::xml_name(child, ns)
      text <- NULL
      if (nm == "w:t") {
        text <- xml2::xml_text(child)
      } else if (nm %in% c("w:tab", "w:cr")) {
        text <- " "
      } else if (nm == "w:br") {
        # a soft line break reads as a space; a page or column break is layout
        br_type <- xml2::xml_attr(child, "w:type", ns)
        if (is.na(br_type) || br_type == "textWrapping") text <- " "
      } else if (nm == "w:noBreakHyphen") {
        text <- "-"
      } else if (nm == "w:drawing" && pictures) {
        read_drawing(child)
      } else if (nm == "mc:AlternateContent" && pictures) {
        # the Choice is what Word shows; the Fallback is its older twin
        for (d in xml2::xml_find_all(child, "mc:Choice/w:drawing", ns)) read_drawing(d)
      }
      if (!is.null(text)) {
        out[[length(out) + 1L]] <<- list(type = "run", text = text, bold = bold, italic = italic)
      }
    }
  }
  read_drawing <- function(d) {
    uri <- xml2::xml_attr(xml2::xml_find_first(d, ".//a:graphicData", ns), "uri")
    if (!identical(uri, .NARRATIVE_PICTURE_URI)) return(invisible(NULL))  # counted by kind later
    block <- .narrative_picture(d, ctx)
    if (!is.null(block)) out[[length(out) + 1L]] <<- list(type = "image", block = block)
  }
  walk(p)
  out
}

#' Is a run toggle (w:b, w:i) on? Present means on unless its value says off.
#' @keywords internal
.narrative_toggle <- function(rpr, tag) {
  if (inherits(rpr, "xml_missing")) return(FALSE)
  node <- xml2::xml_find_first(rpr, tag, .NARRATIVE_NS)
  if (inherits(node, "xml_missing")) return(FALSE)
  val <- xml2::xml_attr(node, "w:val", .NARRATIVE_NS)
  is.na(val) || !(tolower(val) %in% c("0", "false", "off"))
}

#' Merge adjacent runs of the same formatting and trim the ends
#' @keywords internal
.narrative_runs <- function(segments) {
  runs <- list()
  for (s in segments) {
    n <- length(runs)
    if (n > 0 && runs[[n]]$bold == s$bold && runs[[n]]$italic == s$italic) {
      runs[[n]]$text <- paste0(runs[[n]]$text, s$text)
    } else {
      runs[[n + 1L]] <- list(text = s$text, bold = s$bold, italic = s$italic)
    }
  }
  if (length(runs) == 0) return(list())
  runs[[1]]$text <- sub("^\\s+", "", runs[[1]]$text)
  n <- length(runs)
  runs[[n]]$text <- sub("\\s+$", "", runs[[n]]$text)
  runs <- Filter(function(r) nzchar(r$text), runs)
  if (!any(nzchar(trimws(vapply(runs, function(r) r$text, character(1)))))) return(list())
  runs
}

#' An embedded picture as an image block, or NULL (counted or boxed)
#'
#' Embedded as base64 the way AddedSlides pictures are, under the same size
#' limit (TABS_SLIDE_IMAGE_MAX_BYTES), with the intrinsic pixel size read by
#' .slide_image_pixel_size for the deck export.
#' @keywords internal
.narrative_picture <- function(d, ctx) {
  ns <- .NARRATIVE_NS
  blip <- xml2::xml_find_first(d, ".//a:blip", ns)
  embed <- xml2::xml_attr(blip, "r:embed", ns)
  rels <- ctx$parts$rels
  row <- if (!is.na(embed)) which(rels$id == embed) else integer(0)
  if (length(row) == 0 || rels$external[row[1]]) {
    ctx$counts[["linked_pictures"]] <- ctx$counts[["linked_pictures"]] + 1L
    return(NULL)
  }
  file <- ctx$parts$part_path(rels$target[row[1]])
  ext <- tolower(tools::file_ext(file))
  if (!(ext %in% names(.NARRATIVE_IMAGE_MIME))) {
    ctx$counts[["picture_formats"]] <- ctx$counts[["picture_formats"]] + 1L
    ctx$formats <- unique(c(ctx$formats, toupper(ext)))
    return(NULL)
  }
  if (!file.exists(file)) {
    cat(sprintf("  [WARNING] Narrative file: a picture's data (%s) is missing from the document. It was left out.\n",
                basename(file)))
    return(NULL)
  }
  size <- file.info(file)$size
  if (!is.na(size) && size > TABS_SLIDE_IMAGE_MAX_BYTES) {
    cat("\n┌─── TURAS: NARRATIVE PICTURE TOO LARGE ───────────────┐\n")
    cat(sprintf("│ Picture: %s\n", basename(file)))
    cat(sprintf("│ Size:    %.1f MB (limit %.1f MB)\n",
                size / 1024 / 1024, TABS_SLIDE_IMAGE_MAX_BYTES / 1024 / 1024))
    cat("│ Fix:     Compress the picture in Word, or paste a smaller\n")
    cat("│          version, then re-run. The screen's text still shows;\n")
    cat("│          only the picture was left out.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(NULL)
  }
  if (!requireNamespace("base64enc", quietly = TRUE)) {
    cat("  [WARNING] Narrative file: the 'base64enc' package is not installed, so pictures cannot be embedded. Run renv::restore().\n")
    return(NULL)
  }
  raw <- readBin(file, "raw", size)
  block <- list(type = "image",
                src = sprintf("data:%s;base64,%s", .NARRATIVE_IMAGE_MIME[[ext]],
                              base64enc::base64encode(raw)))
  alt <- xml2::xml_attr(xml2::xml_find_first(d, ".//wp:docPr", ns), "descr")
  if (!is.na(alt) && nzchar(trimws(alt))) block$alt <- trimws(alt)
  px <- .slide_image_pixel_size(raw, ext)
  if (!is.null(px) && px$w > 0 && px$h > 0) {
    block$width <- as.integer(px$w)
    block$height <- as.integer(px$h)
  }
  block
}

#' A simple table as a table block, or NULL when it is not simple
#'
#' Text cells by row and column. A table with a merged cell, or with a table
#' inside it, is skipped whole and named: a table read with its merges dropped
#' would put numbers under the wrong heading.
#' @keywords internal
.narrative_table <- function(tbl, ctx) {
  ns <- .NARRATIVE_NS
  if (length(xml2::xml_find_all(tbl, ".//w:tc//w:tbl", ns)) > 0) {
    ctx$counts[["nested_tables"]] <- ctx$counts[["nested_tables"]] + 1L
    return(NULL)
  }
  spans <- suppressWarnings(as.integer(xml2::xml_attr(
    xml2::xml_find_all(tbl, ".//w:tcPr/w:gridSpan", ns), "w:val", ns)))
  merged <- any(!is.na(spans) & spans > 1L) ||
    length(xml2::xml_find_all(tbl, ".//w:tcPr/w:vMerge | .//w:tcPr/w:hMerge", ns)) > 0
  if (merged) {
    ctx$counts[["merged_tables"]] <- ctx$counts[["merged_tables"]] + 1L
    return(NULL)
  }
  # Each row is a list, not a character vector: the island is written with
  # auto_unbox, which would turn a one-cell row into a bare string.
  rows <- lapply(xml2::xml_find_all(tbl, "w:tr", ns), function(tr) {
    lapply(xml2::xml_find_all(tr, "w:tc", ns), function(tc) {
      texts <- vapply(xml2::xml_find_all(tc, "w:p", ns), function(p) {
        segs <- .narrative_segments(p, ctx, pictures = FALSE)
        paste(vapply(.narrative_runs(segs), function(r) r$text, character(1)), collapse = "")
      }, character(1))
      trimws(gsub("\\s+", " ", paste(texts[nzchar(texts)], collapse = " ")))
    })
  })
  rows <- Filter(function(r) length(r) > 0, rows)
  if (length(rows) == 0) return(NULL)
  list(type = "table", rows = rows)
}

# ==============================================================================
# WHOLE-DOCUMENT COUNTS OF WHAT IS NOT READ
# ==============================================================================

#' Count the unsupported features across the document
#'
#' Drawings are classified by their graphicData kind. Anything under an
#' mc:Fallback is the older twin of an mc:Choice and is not counted twice, and
#' anything inside a text box belongs to the text box.
#' @keywords internal
.narrative_count_document <- function(ctx) {
  ns <- .NARRATIVE_NS
  body <- ctx$parts$body
  n <- function(xpath) length(xml2::xml_find_all(body, xpath, ns))
  add <- function(key, k) ctx$counts[[key]] <- ctx$counts[[key]] + as.integer(k)
  live <- "[not(ancestor::mc:Fallback)][not(ancestor::w:txbxContent)][not(ancestor::w:sdt[parent::w:body])]"

  add("hyperlinks", n(paste0(".//w:hyperlink", live)))
  add("tracked_changes", n(paste0(".//w:ins", live)) + n(paste0(".//w:del", live)) +
        n(paste0(".//w:moveFrom", live)) + n(paste0(".//w:moveTo", live)))
  add("comments", n(paste0(".//w:commentReference", live)))
  add("footnotes", n(paste0(".//w:footnoteReference", live)) +
        n(paste0(".//w:endnoteReference", live)))
  add("embedded_objects", n(paste0(".//w:object", live)) + n(paste0(".//m:oMath", live)))
  cols <- suppressWarnings(as.integer(xml2::xml_attr(
    xml2::xml_find_all(body, ".//w:sectPr/w:cols", ns), "w:num", ns)))
  add("columns", sum(!is.na(cols) & cols > 1L))

  for (d in xml2::xml_find_all(body, paste0(".//w:drawing", live))) {
    uri <- xml2::xml_attr(xml2::xml_find_first(d, ".//a:graphicData", ns), "uri")
    if (is.na(uri)) uri <- ""
    in_table <- length(xml2::xml_find_all(d, "ancestor::w:tbl", ns)) > 0
    if (identical(uri, .NARRATIVE_PICTURE_URI)) {
      if (in_table) add("table_drawings", 1L)
      next  # a picture in the body is read, or counted where it was refused
    }
    if (in_table) { add("table_drawings", 1L); next }
    if (grepl("/chart", uri, fixed = TRUE)) {
      add("charts", 1L)
    } else if (grepl("/diagram", uri, fixed = TRUE)) {
      add("smartart", 1L)
    } else if (length(xml2::xml_find_all(d, ".//wps:txbx", ns)) > 0) {
      add("text_boxes", 1L)
    } else {
      add("shapes", 1L)
    }
  }
  # Old-style (VML) drawings that are not the fallback of a modern one
  for (pict in xml2::xml_find_all(body, paste0(".//w:pict", live))) {
    if (length(xml2::xml_find_all(pict, ".//v:textbox", ns)) > 0) add("text_boxes", 1L) else add("shapes", 1L)
  }

  for (part in ctx$parts$header_footer) {
    if (is.null(part)) next
    has_text <- any(nzchar(trimws(xml2::xml_text(xml2::xml_find_all(part, ".//w:t", ns)))))
    has_drawing <- length(xml2::xml_find_all(part, ".//w:drawing | .//w:pict", ns)) > 0
    if (has_text || has_drawing) add("headers_footers", 1L)
  }
  invisible(NULL)
}

#' Console summary: what was read, then one line per kind of thing skipped
#' @keywords internal
.narrative_report <- function(screens, ctx, path) {
  n_blocks <- sum(vapply(screens, function(s) length(s$blocks), integer(1)))
  n_pictures <- sum(vapply(screens, function(s) {
    sum(vapply(s$blocks, function(b) identical(b$type, "image"), logical(1)))
  }, integer(1)))
  cat(sprintf("  [INFO] Narrative file %s: %d screen%s, %d block%s, %d picture%s\n",
              basename(path),
              length(screens), if (length(screens) == 1) "" else "s",
              n_blocks, if (n_blocks == 1) "" else "s",
              n_pictures, if (n_pictures == 1) "" else "s"))
  if (length(screens) > 0 && !isTRUE(ctx$has_h1)) {
    cat(sprintf("  [INFO] Narrative file: no Heading 1 was found, so the whole document is one screen titled \"%s\".\n",
                .NARRATIVE_UNTITLED))
    cat("         To split it into screens, give each section title Word's Heading 1 style.\n")
  }
  if (length(screens) == 0) {
    cat("  [WARNING] Narrative file: the document holds no text the report can show.\n")
    cat("            The report will have no Background or Executive summary screens.\n")
  }
  counts <- ctx$counts
  for (key in names(.NARRATIVE_IGNORED)) {
    k <- counts[[key]]
    if (k == 0L) next
    note <- .NARRATIVE_IGNORED[[key]][2]
    if (key == "picture_formats" && length(ctx$formats) > 0) {
      note <- sprintf("%s Found: %s.", note, paste(ctx$formats, collapse = ", "))
    }
    cat(sprintf("  [WARNING] Narrative file: %d %s. %s\n", k, .NARRATIVE_IGNORED[[key]][1], note))
  }
  invisible(NULL)
}

# ==============================================================================
# COMMENTS SHEET FALLBACK
# ==============================================================================

#' Convert the Comments sheet's summary cells to narrative screens
#'
#' Paragraphs and bullets only, split the way the Report tab's study slides
#' split text (report.slideBodyHtml): a blank line separates blocks, a line
#' starting "- " or "* " is a bullet, any other line is a paragraph.
#'
#' A blank _BACKGROUND with fieldwork_dates set becomes the one-line
#' "Fieldwork: <dates>." background the Report tab has always shown in that
#' case, so a project that never sets narrative_file keeps its Background card.
#'
#' @param background _BACKGROUND text, or NULL
#' @param exec_summary _EXECUTIVE_SUMMARY text, or NULL
#' @param fieldwork The fieldwork_dates setting, or NULL
#' @return A list of up to two screens, or NULL when all are blank
#' @keywords internal
narrative_from_comments <- function(background, exec_summary, fieldwork = NULL) {
  if (is_blank_setting(background) && !is_blank_setting(fieldwork)) {
    background <- sprintf("Fieldwork: %s.", trimws(as.character(fieldwork)[1]))
  }
  sources <- list(background = background, exec = exec_summary)
  keep <- Filter(function(k) !is_blank_setting(sources[[k]]), names(sources))
  if (length(keep) == 0) return(NULL)
  titles <- unname(.NARRATIVE_FALLBACK_TITLES[keep])
  ids <- .narrative_screen_ids(titles)
  lapply(seq_along(keep), function(i) {
    list(id = ids[i], title = titles[i],
         blocks = .narrative_text_blocks(as.character(sources[[keep[i]]])[1]))
  })
}

#' Plain text to paragraph and list blocks
#' @keywords internal
.narrative_text_blocks <- function(text) {
  text <- gsub("\r\n?", "\n", text)
  blocks <- list()
  for (chunk in strsplit(text, "\n[[:space:]]*\n")[[1]]) {
    bullets <- list()
    flush <- function() {
      if (length(bullets) > 0) blocks[[length(blocks) + 1L]] <<- list(type = "list", items = bullets)
      bullets <<- list()
    }
    for (line in strsplit(chunk, "\n", fixed = TRUE)[[1]]) {
      s <- trimws(line)
      if (!nzchar(s)) next
      if (grepl("^[-*][[:space:]]+", s)) {
        bullets[[length(bullets) + 1L]] <- list(
          level = 0L, ordered = FALSE,
          runs = list(list(text = sub("^[-*][[:space:]]+", "", s), bold = FALSE, italic = FALSE)))
        next
      }
      flush()
      blocks[[length(blocks) + 1L]] <- list(
        type = "paragraph", runs = list(list(text = s, bold = FALSE, italic = FALSE)))
    }
    flush()
  }
  blocks
}
