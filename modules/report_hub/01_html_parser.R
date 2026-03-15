#' HTML Report Parser
#'
#' Parses a Turas HTML report file and extracts its components:
#' CSS blocks, JS blocks, content panels, header, footer, and metadata.
#' This is the foundation for the DOM merge approach.

#' Parse a Turas HTML Report
#'
#' @param report_path Path to the HTML report file
#' @param report_key Unique key for this report (e.g., "tracker", "tabs")
#' @return TRS-compliant list with parsed components
parse_html_report <- function(report_path, report_key) {

  if (!file.exists(report_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_FILE_NOT_FOUND",
      message = sprintf("Report file not found: %s", report_path),
      how_to_fix = "Check the file path."
    ))
  }

  # Read full file
  lines <- readLines(report_path, warn = FALSE, encoding = "UTF-8")
  html <- paste(lines, collapse = "\n")

  # --- Detect report type ---
  report_type <- detect_report_type(html)
  if (is.null(report_type)) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = sprintf("Cannot detect report type for: %s", basename(report_path)),
      how_to_fix = "The file must be a Turas-generated HTML report (tracker, tabs, catdriver, keydriver, weighting, or confidence)."
    ))
  }

  # --- Extract CSS blocks ---
  css_blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  # --- Extract script blocks ---
  all_scripts <- extract_blocks(html, "<script[^>]*>", "</script>")

  # Separate data scripts from executable JS
  data_scripts <- list()
  js_blocks <- list()
  for (s in all_scripts) {
    if (grepl('type="application/json"', s$open_tag, fixed = TRUE)) {
      # Extract the id attribute
      id_match <- regmatches(s$open_tag, regexpr('id="[^"]*"', s$open_tag))
      s$id <- if (length(id_match) > 0) gsub('id="|"', '', id_match) else NULL
      data_scripts <- c(data_scripts, list(s))
    } else {
      js_blocks <- c(js_blocks, list(s))
    }
  }

  # --- Extract header ---
  header <- extract_header(html, report_type)

  # --- Extract content panels ---
  content_panels <- extract_content_panels(html, report_type)

  # --- Extract report tab navigation ---
  report_tabs <- extract_report_tabs(html)

  # --- Extract footer ---
  footer <- extract_footer(html, report_type)

  # --- Extract help overlay ---
  help_overlay <- extract_help_overlay(html, report_type)

  # --- Extract metadata ---
  metadata <- extract_metadata(html, report_type)

  # --- Extract pinned views data ---
  pinned_data <- "[]"
  for (ds in data_scripts) {
    if (!is.null(ds$id) && ds$id == "pinned-views-data") {
      pinned_data <- trimws(ds$content)
      break
    }
  }

  return(list(
    status = "PASS",
    result = list(
      report_key = report_key,
      report_type = report_type,
      css_blocks = css_blocks,
      js_blocks = js_blocks,
      data_scripts = data_scripts,
      header = header,
      report_tabs = report_tabs,
      content_panels = content_panels,
      footer = footer,
      help_overlay = help_overlay,
      metadata = metadata,
      pinned_data = pinned_data,
      raw_html = html
    ),
    message = sprintf("Parsed %s report: %d CSS blocks, %d JS blocks, %d panels",
                      report_type, length(css_blocks), length(js_blocks),
                      length(content_panels))
  ))
}


#' Detect Report Type from HTML Content
#'
#' @param html Full HTML string
#' @return "tracker", "tabs", "catdriver", "keydriver", "weighting", "confidence", or NULL
detect_report_type <- function(html) {
  # Check for explicit meta tag first (all modern Turas reports include this)
  for (type in c("tracker", "tabs", "catdriver", "keydriver", "weighting", "confidence", "maxdiff", "conjoint", "segment", "pricing")) {
    pattern <- sprintf('<meta\\s+name="turas-report-type"\\s+content="%s"', type)
    if (grepl(pattern, html)) return(type)
  }
  # Fallback: detect by structural markers (older reports without meta tag)
  if (grepl('id="tab-crosstabs"', html, fixed = TRUE)) {
    return("tabs")
  }
  if (grepl('id="tab-metrics"', html, fixed = TRUE) &&
      grepl('id="tab-overview"', html, fixed = TRUE)) {
    return("tracker")
  }
  if (grepl('class="tk-header"', html, fixed = TRUE)) {
    return("tracker")
  }
  if (grepl('class="ci-header"', html, fixed = TRUE)) {
    return("confidence")
  }
  if (grepl('class="wt-header"', html, fixed = TRUE)) {
    return("weighting")
  }
  if (grepl('class="md-header"', html, fixed = TRUE) &&
      grepl('Turas MaxDiff', html, fixed = TRUE)) {
    return("maxdiff")
  }
  if (grepl('class="cj-header"', html, fixed = TRUE)) {
    return("conjoint")
  }
  if (grepl('class="seg-header"', html, fixed = TRUE)) {
    return("segment")
  }
  return(NULL)
}


#' Extract Blocks Between Open/Close Tags
#'
#' @param html Full HTML string
#' @param open_pattern Regex for opening tag
#' @param close_tag Literal closing tag
#' @return List of blocks, each with open_tag, content, full_block
extract_blocks <- function(html, open_pattern, close_tag) {
  blocks <- list()

  # Use gregexpr to find all opening tags
  open_matches <- gregexpr(open_pattern, html)[[1]]
  if (open_matches[1] == -1) return(blocks)

  open_lengths <- attr(open_matches, "match.length")

  for (i in seq_along(open_matches)) {
    start_pos <- open_matches[i]
    open_tag_end <- start_pos + open_lengths[i]
    open_tag <- substr(html, start_pos, open_tag_end - 1)

    # Find the matching close tag after this opening tag
    close_pos <- regexpr(close_tag, substr(html, open_tag_end, nchar(html)), fixed = TRUE)
    if (close_pos == -1) next

    close_abs <- open_tag_end + close_pos - 1
    content <- substr(html, open_tag_end, close_abs - 1)
    full_block <- substr(html, start_pos, close_abs + nchar(close_tag) - 1)

    blocks <- c(blocks, list(list(
      open_tag = open_tag,
      content = content,
      full_block = full_block,
      start_pos = start_pos,
      end_pos = close_abs + nchar(close_tag) - 1
    )))
  }

  return(blocks)
}


#' Extract Header HTML
#'
#' @param html Full HTML string
#' @param report_type "tracker" or "tabs"
#' @return Header HTML string
extract_header <- function(html, report_type) {
  if (report_type == "tracker") {
    # Tracker: <header class="tk-header">...</header>
    m <- regexpr('<header class="tk-header">[\\s\\S]*?</header>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "catdriver") {
    # Catdriver: <div class="cd-header">...</div>
    m <- regexpr('<div class="cd-header">[\\s\\S]*?</div>\\s*</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "keydriver") {
    # Keydriver: <div class="kd-header">...</div>
    m <- regexpr('<div class="kd-header">[\\s\\S]*?</div>\\s*</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "confidence") {
    # Confidence: <div class="ci-header">...</div>
    m <- regexpr('<div class="ci-header">[\\s\\S]*?</div>\\s*</div>\\s*</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "weighting") {
    # Weighting: <div class="wt-header">...</div>
    m <- regexpr('<div class="wt-header">[\\s\\S]*?</div>\\s*</div>\\s*</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "maxdiff") {
    # MaxDiff: <header class="md-header">...</header>
    m <- regexpr('<header class="md-header">[\\s\\S]*?</header>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "conjoint") {
    # Conjoint: <header class="cj-header">...</header>
    m <- regexpr('<header class="cj-header">[\\s\\S]*?</header>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else if (report_type == "segment") {
    # Segment: <div class="seg-header">...</div>
    m <- regexpr('<div class="seg-header">[\\s\\S]*?</div>\\s*</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  } else {
    # Tabs: <div class="header">...</div> (up to report-tabs)
    m <- regexpr('<div class="header">[\\s\\S]*?</div>\\s*</div>\\s*</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  }
  return("")
}


#' Extract Report Tab Navigation
#'
#' @param html Full HTML string
#' @return List with tab_html and tab_names
extract_report_tabs <- function(html) {
  tab_html <- ""

  # Try module-specific section navs first (catdriver/keydriver)
  for (prefix in c("kd", "cd")) {
    pattern <- sprintf('<div[^>]*class="[^"]*%s-section-nav[^"]*"[^>]*>[\\s\\S]*?</div>', prefix)
    m <- regexpr(pattern, html, perl = TRUE)
    if (m > 0) {
      tab_html <- regmatches(html, m)
      break
    }
  }

  # Fallback: tracker/tabs use <div class="report-tabs">...</div>
  if (!nzchar(tab_html)) {
    m <- regexpr('<div class="report-tabs">[\\s\\S]*?</div>', html, perl = TRUE)
    if (m > 0) tab_html <- regmatches(html, m)
  }

  # Extract tab names from data-tab or data-kd-section or data-cd-section attributes
  tab_names <- character(0)
  for (attr_name in c("data-tab", "data-kd-section", "data-cd-section")) {
    pattern <- sprintf('%s="([^"]*)"', attr_name)
    tab_matches <- gregexpr(pattern, tab_html)[[1]]
    if (tab_matches[1] != -1) {
      for (i in seq_along(tab_matches)) {
        len <- attr(tab_matches, "match.length")[i]
        attr_str <- substr(tab_html, tab_matches[i], tab_matches[i] + len - 1)
        tab_names <- c(tab_names, gsub(sprintf('%s="|"', attr_name), '', attr_str))
      }
      break  # found tabs, stop trying other attribute names
    }
  }

  # Filter out "pinned" — the hub manages its own pinned tab
  tab_names <- tab_names[tab_names != "pinned"]

  return(list(
    html = tab_html,
    tab_names = tab_names
  ))
}


#' Extract Content Panels (tab-panel divs)
#'
#' @param html Full HTML string
#' @param report_type "tracker", "tabs", "catdriver", or "keydriver"
#' @return Named list of panel HTML strings (keyed by tab name)
extract_content_panels <- function(html, report_type) {
  panels <- list()

  # Catdriver/Keydriver: sections use class="cd-section"/"kd-section" with id="kd-section-*"
  if (report_type %in% c("catdriver", "keydriver")) {
    prefix <- if (report_type == "catdriver") "cd" else "kd"
    section_pattern <- sprintf('id="%s-section-([^"]*)"', prefix)
    id_matches <- gregexpr(section_pattern, html, perl = TRUE)[[1]]
    if (id_matches[1] == -1) return(panels)

    section_ids <- character(0)
    for (i in seq_along(id_matches)) {
      len <- attr(id_matches, "match.length")[i]
      attr_str <- substr(html, id_matches[i], id_matches[i] + len - 1)
      section_id <- sub(sprintf('id="%s-section-([^"]*)"', prefix), '\\1', attr_str, perl = TRUE)
      section_ids <- c(section_ids, section_id)
    }

    for (idx in seq_along(section_ids)) {
      sid <- section_ids[idx]
      full_id <- sprintf("%s-section-%s", prefix, sid)
      pattern <- sprintf('<div[^>]*id="%s"', full_id)
      start <- regexpr(pattern, html, perl = TRUE)
      if (start == -1) next

      search_from <- start + 10
      end_markers <- c()

      # Next section
      if (idx < length(section_ids)) {
        next_id <- sprintf('%s-section-%s', prefix, section_ids[idx + 1])
        next_pos <- regexpr(sprintf('<div[^>]*id="%s"', next_id),
                            substr(html, search_from, nchar(html)), perl = TRUE)
        if (next_pos > 0) end_markers <- c(end_markers, search_from + next_pos - 2)
      }

      # Pinned panel or footer
      footer_pattern <- sprintf('%s-footer', prefix)
      ft_pos <- regexpr(footer_pattern, substr(html, search_from, nchar(html)), fixed = TRUE)
      if (ft_pos > 0) end_markers <- c(end_markers, search_from + ft_pos - 2)

      sc_pos <- regexpr('\n<script>', substr(html, search_from, nchar(html)), fixed = TRUE)
      if (sc_pos > 0) end_markers <- c(end_markers, search_from + sc_pos - 2)

      if (length(end_markers) > 0) {
        end_pos <- min(end_markers)
      } else {
        body_end <- regexpr('</body>', substr(html, search_from, nchar(html)), fixed = TRUE)
        end_pos <- if (body_end > 0) search_from + body_end - 2 else nchar(html)
      }

      panel_html <- substr(html, start, end_pos)
      panel_html <- sub("\\s+$", "", panel_html)

      # Skip pinned panel — hub manages its own
      if (sid != "pinned") {
        panels[[sid]] <- panel_html
      }
    }
    return(panels)
  }

  # Tracker/Tabs: Find all tab-panel divs by their id pattern: id="tab-{name}"
  # We need to extract each complete panel including all nested content
  panel_ids <- c()
  id_matches <- gregexpr('id="tab-([^"]*)"\\s+class="tab-panel', html)[[1]]
  if (id_matches[1] == -1) return(panels)

  for (i in seq_along(id_matches)) {
    len <- attr(id_matches, "match.length")[i]
    attr_str <- substr(html, id_matches[i], id_matches[i] + len - 1)
    id_val <- sub('id="tab-([^"]*)".*', '\\1', attr_str)
    panel_ids <- c(panel_ids, id_val)
  }

  # For each panel, extract from its opening div to the start of the next panel
  # (or to the pinned-views-data script / footer / end of body)
  for (idx in seq_along(panel_ids)) {
    panel_id <- panel_ids[idx]
    full_id <- paste0("tab-", panel_id)

    # Find the start position of this panel's opening div
    pattern <- sprintf('<div id="%s"', full_id)
    start <- regexpr(pattern, html, fixed = TRUE)
    if (start == -1) next

    # Find the end: start of the next panel, or pinned-views-data, or footer, or </body>
    search_from <- start + 10
    end_markers <- c()

    # Next panel
    if (idx < length(panel_ids)) {
      next_pattern <- sprintf('<div id="tab-%s"', panel_ids[idx + 1])
      next_pos <- regexpr(next_pattern, substr(html, search_from, nchar(html)), fixed = TRUE)
      if (next_pos > 0) end_markers <- c(end_markers, search_from + next_pos - 2)
    }

    # Pinned views data script
    pv_pos <- regexpr('<script type="application/json" id="pinned-views-data"',
                      substr(html, search_from, nchar(html)), fixed = TRUE)
    if (pv_pos > 0) end_markers <- c(end_markers, search_from + pv_pos - 2)

    # Footer — tracker and confidence have footers after content panels
    if (report_type == "tracker") {
      ft_pos <- regexpr('<footer class="tk-footer"',
                        substr(html, search_from, nchar(html)), fixed = TRUE)
      if (ft_pos > 0) end_markers <- c(end_markers, search_from + ft_pos - 2)
    }
    if (report_type == "confidence") {
      ft_pos <- regexpr('<div class="ci-footer"',
                        substr(html, search_from, nchar(html)), fixed = TRUE)
      if (ft_pos > 0) end_markers <- c(end_markers, search_from + ft_pos - 2)
    }

    # Script blocks after content
    sc_pos <- regexpr('\n<script>',
                      substr(html, search_from, nchar(html)), fixed = TRUE)
    if (sc_pos > 0) end_markers <- c(end_markers, search_from + sc_pos - 2)

    if (length(end_markers) > 0) {
      end_pos <- min(end_markers)
    } else {
      # Fallback: up to </body>
      body_end <- regexpr('</body>', substr(html, search_from, nchar(html)), fixed = TRUE)
      end_pos <- if (body_end > 0) search_from + body_end - 2 else nchar(html)
    }

    panel_html <- substr(html, start, end_pos)
    # Trim trailing whitespace
    panel_html <- sub("\\s+$", "", panel_html)

    # Skip the pinned panel — hub manages its own
    if (panel_id != "pinned") {
      panels[[panel_id]] <- panel_html
    }
  }

  return(panels)
}


#' Extract Footer HTML
#'
#' @param html Full HTML string
#' @param report_type "tracker" or "tabs"
#' @return Footer HTML string
extract_footer <- function(html, report_type) {
  if (report_type == "tracker") {
    m <- regexpr('<footer class="tk-footer">[\\s\\S]*?</footer>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  }
  if (report_type == "catdriver") {
    m <- regexpr('<div class="cd-footer">[\\s\\S]*?</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  }
  if (report_type == "keydriver") {
    m <- regexpr('<div class="kd-footer">[\\s\\S]*?</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  }
  if (report_type == "confidence") {
    m <- regexpr('<div class="ci-footer">[\\s\\S]*?</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  }
  if (report_type == "weighting") {
    m <- regexpr('<div class="wt-footer">[\\s\\S]*?</div>', html, perl = TRUE)
    if (m > 0) return(regmatches(html, m))
  }
  # Tabs footer is inside content panels — already captured, no separate extraction
  return("")
}


#' Extract Help Overlay HTML
#'
#' Extracts the help overlay modal from report HTML. Tabs reports use
#' \code{<div class="help-overlay" id="help-overlay">}, tracker reports use
#' \code{<div id="tk-help-overlay" class="tk-help-overlay">}. Other report
#' types do not have help overlays.
#'
#' The help overlay sits outside the tab-panel divs in source HTML, so it
#' must be extracted separately from content panels.
#'
#' @param html Full HTML string
#' @param report_type Report type string
#' @return Help overlay HTML string, or empty string if not found
#' @keywords internal
extract_help_overlay <- function(html, report_type) {
  # Determine the opening tag pattern based on report type
  open_pattern <- NULL
  if (report_type == "tabs") {
    open_pattern <- '<div\\s+class="help-overlay"\\s+id="help-overlay"[^>]*>'
  } else if (report_type == "tracker") {
    open_pattern <- '<div\\s+id="tk-help-overlay"[^>]*>'
  }

  if (is.null(open_pattern)) return("")

  # Find the opening tag
  m <- regexpr(open_pattern, html, perl = TRUE)
  if (m == -1) return("")

  # Use div-counting to find the balanced closing tag
  extract_balanced_div(html, m)
}


#' Extract a Balanced Div Block from HTML
#'
#' Starting from a known opening \code{<div} position, counts nested div
#' opens and closes to find the matching closing \code{</div>} tag.
#'
#' @param html Full HTML string
#' @param start_pos Position of the opening \code{<div} tag
#' @return The complete balanced HTML string from opening to closing div
#' @keywords internal
extract_balanced_div <- function(html, start_pos) {
  depth <- 0
  pos <- start_pos
  n <- nchar(html)

  while (pos <= n) {
    # Find next <div or </div> from current position
    rest <- substr(html, pos, n)
    open_m <- regexpr("<div[\\s>]", rest, perl = TRUE)
    close_m <- regexpr("</div>", rest, fixed = TRUE)

    open_abs <- if (open_m > 0) pos + open_m - 1 else n + 1
    close_abs <- if (close_m > 0) pos + close_m - 1 else n + 1

    if (open_abs <= n && open_abs < close_abs) {
      # Found an opening div first
      depth <- depth + 1
      pos <- open_abs + 4  # skip past "<div"
    } else if (close_abs <= n) {
      # Found a closing div
      depth <- depth - 1
      if (depth == 0) {
        # This is the matching close for our opening div
        return(substr(html, start_pos, close_abs + 5))  # +5 for "</div>"
      }
      pos <- close_abs + 6  # skip past "</div>"
    } else {
      # No more divs found
      break
    }
  }

  # Fallback: return from start to end (shouldn't happen with valid HTML)
  return(substr(html, start_pos, n))
}


#' Extract Metadata from HTML
#'
#' Extracts both legacy HTML-based metadata and new \code{<meta>} tag metadata
#' embedded by Turas report generators for clean hub extraction.
#'
#' @param html Full HTML string
#' @param report_type "tracker" or "tabs"
#' @return Named list of metadata
extract_metadata <- function(html, report_type) {
  meta <- list(report_type = report_type)

  # --- Helper: extract content from <meta name="X" content="Y"> ---
  extract_meta_tag <- function(name) {
    pat <- sprintf('<meta\\s+name="%s"\\s+content="([^"]*)"', name)
    m <- regexpr(pat, html, perl = TRUE)
    if (m > 0) {
      val <- sub(pat, '\\1', regmatches(html, m))
      if (nzchar(val)) return(val)
    }
    return(NULL)
  }

  # Project title from <title> tag
  title_m <- regexpr('<title>([^<]*)</title>', html)
  if (title_m > 0) {
    meta$title <- sub('<title>([^<]*)</title>', '\\1', regmatches(html, title_m))
  }

  # Generation timestamp from meta tag
  meta$generated <- extract_meta_tag("turas-generated")

  if (report_type == "tracker") {
    # Extract from header elements
    proj_m <- regexpr('class="tk-header-project">([^<]*)<', html)
    if (proj_m > 0) {
      meta$project_title <- sub('class="tk-header-project">([^<]*)<', '\\1',
                                regmatches(html, proj_m))
    }

    # Badge bar stats (legacy extraction)
    badge_m <- regexpr('class="tk-badge-bar">[\\s\\S]*?</div>', html, perl = TRUE)
    if (badge_m > 0) {
      badge_html <- regmatches(html, badge_m)
      meta$badge_bar <- badge_html
    }

    # Brand name
    brand_m <- regexpr('class="tk-brand-name">([^<]*)<', html)
    if (brand_m > 0) {
      meta$brand_name <- sub('class="tk-brand-name">([^<]*)<', '\\1',
                             regmatches(html, brand_m))
    }

    # --- New meta-tag extraction (preferred, falls back to badge_bar regex) ---
    meta$n_metrics <- extract_meta_tag("turas-metrics")
    meta$n_waves <- extract_meta_tag("turas-waves")
    meta$n_segments <- extract_meta_tag("turas-segments")
    meta$baseline_label <- extract_meta_tag("turas-baseline-label")
    meta$latest_label <- extract_meta_tag("turas-latest-label")

    # Fallback: parse badge bar if meta tags not present (older reports)
    if (is.null(meta$n_metrics) && !is.null(meta$badge_bar)) {
      nums <- regmatches(meta$badge_bar,
                         gregexpr("<strong>(\\d+)</strong>", meta$badge_bar))[[1]]
      if (length(nums) >= 1) meta$n_metrics <- gsub("<[^>]+>", "", nums[1])
      if (length(nums) >= 2) meta$n_waves <- gsub("<[^>]+>", "", nums[2])
      if (length(nums) >= 3) meta$n_segments <- gsub("<[^>]+>", "", nums[3])
    }

  } else {
    # Tabs: extract from tab-summary data attributes (legacy)
    summary_m <- regexpr('id="tab-summary"[^>]*>', html)
    if (summary_m > 0) {
      summary_tag <- regmatches(html, summary_m)

      # data-project-title
      pt <- regmatches(summary_tag, regexpr('data-project-title="[^"]*"', summary_tag))
      if (length(pt) > 0) meta$project_title <- gsub('data-project-title="|"', '', pt)

      # data-fieldwork
      fw <- regmatches(summary_tag, regexpr('data-fieldwork="[^"]*"', summary_tag))
      if (length(fw) > 0) meta$fieldwork <- gsub('data-fieldwork="|"', '', fw)

      # data-company
      co <- regmatches(summary_tag, regexpr('data-company="[^"]*"', summary_tag))
      if (length(co) > 0) meta$company <- gsub('data-company="|"', '', co)

      # data-brand-colour
      bc <- regmatches(summary_tag, regexpr('data-brand-colour="[^"]*"', summary_tag))
      if (length(bc) > 0) meta$brand_colour <- gsub('data-brand-colour="|"', '', bc)
    }

    # --- New meta-tag extraction (preferred) ---
    meta$total_n <- extract_meta_tag("turas-total-n")
    meta$n_questions <- extract_meta_tag("turas-questions")
    meta$n_banner_groups <- extract_meta_tag("turas-banner-groups")
    meta$weighted <- extract_meta_tag("turas-weighted")
    meta$fieldwork <- meta$fieldwork %||% extract_meta_tag("turas-fieldwork")

    # Use title for project_title fallback
    if (is.null(meta$project_title) && !is.null(meta$title)) {
      meta$project_title <- meta$title
    }
  }

  # --- Confidence report metadata ---
  if (report_type == "confidence") {
    # Project title from header
    proj_m <- regexpr('class="ci-header-project">([^<]*)<', html)
    if (proj_m > 0) {
      meta$project_title <- sub('class="ci-header-project">([^<]*)<', '\\1',
                                regmatches(html, proj_m))
    }

    # Meta tag extraction
    meta$total_n <- extract_meta_tag("turas-total-n")
    meta$n_questions <- extract_meta_tag("turas-questions")

    # Use title for fallback
    if (is.null(meta$project_title) && !is.null(meta$title)) {
      meta$project_title <- sub("^Turas Confidence Analysis - ", "", meta$title)
    }
  }

  # --- Weighting report metadata ---
  if (report_type == "weighting") {
    # Project title from header
    proj_m <- regexpr('class="wt-header-project">([^<]*)<', html)
    if (proj_m > 0) {
      meta$project_title <- sub('class="wt-header-project">([^<]*)<', '\\1',
                                regmatches(html, proj_m))
    }

    # Meta tag extraction
    meta$total_n <- extract_meta_tag("turas-total-n")
    meta$n_weights <- extract_meta_tag("turas-weights")

    # Use title for fallback
    if (is.null(meta$project_title) && !is.null(meta$title)) {
      meta$project_title <- sub("^Turas Weighting Report - ", "", meta$title)
    }
  }

  return(meta)
}
