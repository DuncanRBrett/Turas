# ==============================================================================
# SHARED CORRESPONDENCE ANALYSIS RENDERER - TURAS
# ==============================================================================
# Renders one or more CA maps into a single self-contained HTML file: inline
# SVG, inline CSS, no external assets, so the file can be mailed or archived
# and still open in ten years. Each map carries its own notes and its input
# matrix, because a map without its numbers cannot be audited.
#
# DEPENDENCIES: None (base R only)
# ==============================================================================

CA_HTML_NAVY <- "#1F3864"
CA_HTML_ACCENT <- "#C55A11"
CA_HTML_GREY <- "#8A8F98"

#' Escape text for HTML/SVG
#'
#' @param text A character vector.
#'
#' @return The escaped vector.
.ca_escape <- function(text) {
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  return(gsub(">", "&gt;", text, fixed = TRUE))
}

#' Nudge overlapping labels apart (internal)
#'
#' A greedy pass: labels are placed in reading order; one that overlaps an
#' already-placed label's box is pushed down in 13px steps until it fits.
#' Points never move - only their text does.
#'
#' @param labels A data frame with x, y (text anchor) and text.
#'
#' @return The data frame with y adjusted.
.ca_place_labels <- function(labels) {
  box <- function(x, y, text) {
    c(left = x, right = x + 6.8 * nchar(text), top = y - 10, bottom = y + 3)
  }
  overlaps <- function(a, b) {
    a["left"] < b["right"] && b["left"] < a["right"] &&
      a["top"] < b["bottom"] && b["top"] < a["bottom"]
  }
  placed <- list()
  order_index <- order(labels$y, labels$x)
  for (i in order_index) {
    attempt <- 0L
    repeat {
      candidate <- box(labels$x[i], labels$y[i], labels$text[i])
      collision <- any(vapply(placed, overlaps, logical(1), a = candidate))
      if (!collision || attempt >= 8L) {
        break
      }
      labels$y[i] <- labels$y[i] + 13
      attempt <- attempt + 1L
    }
    placed[[length(placed) + 1L]] <- box(labels$x[i], labels$y[i], labels$text[i])
  }
  return(labels)
}

#' Build the SVG for one CA map (internal)
#'
#' Both point sets are drawn in principal coordinates on a shared, equally
#' scaled plane. Attribute point size can reflect stated importance.
#'
#' @param ca The PASS/PARTIAL list from \code{run_correspondence_analysis()}.
#' @param importance Optional named numeric (attribute -> 0..1) for sizing.
#' @param width,height Pixel size of the SVG.
#'
#' @return A single character value: the SVG element.
.ca_svg <- function(ca, importance = NULL, width = 920, height = 620) {
  pad_to_2d <- function(coords) {
    if (ncol(coords) >= 2) {
      return(coords)
    }
    return(cbind(coords, Dim2 = rep(0, nrow(coords))))
  }
  rows <- pad_to_2d(ca$row_coords)
  cols <- pad_to_2d(ca$col_coords)
  if (length(ca$explained) < 2) {
    ca$explained <- c(ca$explained, 0)
  }
  all_x <- c(rows[, 1], cols[, 1])
  all_y <- c(rows[, 2], cols[, 2])
  extent <- max(abs(c(all_x, all_y)), 1e-6) * 1.15
  margin <- 46
  scale <- (min(width, height) / 2 - margin) / extent
  px <- function(x) width / 2 + x * scale
  py <- function(y) height / 2 - y * scale

  parts <- c(
    sprintf('<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg" style="max-width:100%%;height:auto;background:#FFFFFF;border:1px solid #E3E6EB;">',
            width, height),
    sprintf('<line x1="0" y1="%.1f" x2="%d" y2="%.1f" stroke="%s" stroke-width="1"/>',
            py(0), width, py(0), CA_HTML_GREY),
    sprintf('<line x1="%.1f" y1="0" x2="%.1f" y2="%d" stroke="%s" stroke-width="1"/>',
            px(0), px(0), height, CA_HTML_GREY),
    sprintf('<text x="%d" y="%.1f" font-size="11" fill="%s" text-anchor="end">Dim 1 (%.0f%%)</text>',
            width - 8, py(0) - 6, CA_HTML_GREY, 100 * ca$explained[1]),
    sprintf('<text x="%.1f" y="14" font-size="11" fill="%s">Dim 2 (%.0f%%)</text>',
            px(0) + 6, CA_HTML_GREY, 100 * ca$explained[2])
  )
  labels <- data.frame(
    kind = c(rep("entity", nrow(rows)), rep("attribute", nrow(cols))),
    text = c(rownames(rows), rownames(cols)),
    point_x = c(px(rows[, 1]), px(cols[, 1])),
    point_y = c(py(rows[, 2]), py(cols[, 2])),
    stringsAsFactors = FALSE
  )
  labels$x <- labels$point_x + 8
  labels$y <- labels$point_y + 4
  labels <- .ca_place_labels(labels)

  for (i in seq_len(nrow(labels))) {
    entity <- identical(labels$kind[i], "entity")
    colour <- if (entity) CA_HTML_NAVY else CA_HTML_ACCENT
    label <- .ca_escape(labels$text[i])
    marker <- if (entity) {
      sprintf('<circle cx="%.1f" cy="%.1f" r="5" fill="%s"><title>%s</title></circle>',
              labels$point_x[i], labels$point_y[i], colour, label)
    } else {
      size <- 5
      if (!is.null(importance) && labels$text[i] %in% names(importance)) {
        size <- 4 + 6 * importance[[labels$text[i]]]
      }
      sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" transform="rotate(45 %.1f %.1f)" fill="%s"><title>%s</title></rect>',
              labels$point_x[i] - size / 2, labels$point_y[i] - size / 2,
              size, size, labels$point_x[i], labels$point_y[i], colour, label)
    }
    # a leader line when the label had to move away from its point
    leader <- if (abs(labels$y[i] - (labels$point_y[i] + 4)) > 14) {
      sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="0.6" opacity="0.5"/>',
              labels$point_x[i], labels$point_y[i], labels$x[i] - 2,
              labels$y[i] - 4, colour)
    } else ""
    parts <- c(parts, sprintf(
      '<g>%s%s<text x="%.1f" y="%.1f" font-size="12"%s fill="%s">%s</text></g>',
      marker, leader, labels$x[i], labels$y[i],
      if (entity) "" else ' font-style="italic"', colour, label))
  }
  return(paste(c(parts, "</svg>"), collapse = "\n"))
}

#' Build an HTML table from a numeric matrix (internal)
#'
#' @param m The matrix.
#' @param base_n Optional named vector appended as a "Base" column.
#' @param digits Rounding for display.
#'
#' @return A single character value: the table element.
.ca_html_table <- function(m, base_n = NULL, digits = 1) {
  header <- paste0("<th></th>",
                   paste(sprintf("<th>%s</th>", .ca_escape(colnames(m))), collapse = ""),
                   if (!is.null(base_n)) "<th>Base</th>" else "")
  body <- vapply(seq_len(nrow(m)), function(i) {
    cells <- paste(sprintf("<td>%s</td>", format(round(m[i, ], digits), trim = TRUE)),
                   collapse = "")
    base <- if (!is.null(base_n)) sprintf("<td>%d</td>", as.integer(base_n[i])) else ""
    sprintf("<tr><th>%s</th>%s%s</tr>", .ca_escape(rownames(m)[i]), cells, base)
  }, character(1))
  return(sprintf('<div class="scroll"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>',
                 header, paste(body, collapse = "\n")))
}

#' Render one or more CA maps into a self-contained HTML report
#'
#' @param maps A list; each element a list with \code{ca} (the engine result),
#'   \code{matrix_result} (from \code{build_association_matrix()}, for the
#'   audit table), \code{title}, \code{notes} (character vector), and
#'   optionally \code{importance} (named 0..1 for attribute sizing).
#' @param main_title The page title.
#' @param subtitle One line under the title (say what the bases are).
#' @param path Where to write the .html.
#'
#' @return A list: status "PASS" and the path, or a REFUSED list.
#'
#' @export
render_ca_report_html <- function(maps, main_title, subtitle, path) {
  usable <- Filter(function(m) !identical(m$ca$status, "REFUSED"), maps)
  if (!length(usable)) {
    return(list(
      status = "REFUSED", code = "DATA_CA_NOTHING_TO_RENDER",
      message = "Every map in the list was refused by the engine, so there is nothing to draw.",
      how_to_fix = "Check the engine refusal messages for each map."
    ))
  }
  sections <- vapply(maps, function(entry) {
    if (identical(entry$ca$status, "REFUSED")) {
      return(sprintf('<section><h2>%s</h2><p class="refused">Not drawn: %s</p></section>',
                     .ca_escape(entry$title), .ca_escape(entry$ca$message)))
    }
    notes <- c(entry$notes, entry$ca$warnings,
               if (length(entry$matrix_result$excluded)) {
                 sprintf("Excluded from this map: %s.",
                         paste(entry$matrix_result$excluded, collapse = "; "))
               })
    notes_html <- if (length(notes)) {
      sprintf("<ul>%s</ul>", paste(sprintf("<li>%s</li>", .ca_escape(notes)), collapse = ""))
    } else ""
    sprintf('<section><h2>%s</h2>%s%s<h3>The numbers behind this map</h3>%s</section>',
            .ca_escape(entry$title), .ca_svg(entry$ca, entry$importance), notes_html,
            .ca_html_table(entry$matrix_result$matrix, entry$matrix_result$base_n))
  }, character(1))

  html <- paste(c(
    "<!DOCTYPE html><html><head><meta charset='utf-8'>",
    sprintf("<title>%s</title>", .ca_escape(main_title)),
    "<style>",
    "body{font-family:'Segoe UI',Calibri,Arial,sans-serif;margin:2rem auto;max-width:1000px;color:#26303B;}",
    sprintf("h1{color:%s;margin-bottom:0.2rem;} h2{color:%s;margin-top:2.4rem;}", CA_HTML_NAVY, CA_HTML_NAVY),
    ".subtitle{color:#5A6472;margin-top:0;}",
    "table{border-collapse:collapse;font-size:0.85rem;} th,td{border:1px solid #E3E6EB;padding:4px 8px;text-align:right;}",
    "th{background:#F4F6FA;text-align:left;} .scroll{overflow-x:auto;}",
    "ul{color:#5A6472;font-size:0.9rem;} .refused{color:#A33;}",
    sprintf(".legend span.e{color:%s;font-weight:bold;} .legend span.a{color:%s;font-style:italic;}", CA_HTML_NAVY, CA_HTML_ACCENT),
    "</style></head><body>",
    sprintf("<h1>%s</h1><p class='subtitle'>%s</p>", .ca_escape(main_title), .ca_escape(subtitle)),
    "<p class='legend'><span class='e'>&#9679; Entities (channels)</span> &nbsp; <span class='a'>&#9670; Attributes</span>. Distances within a colour are meaningful; entity-to-attribute proximity is directional, not metric.</p>",
    sections,
    sprintf("<p class='subtitle'>Generated by the Turas CA engine v%s. Self-contained file; the tables above are the exact input to each map.</p>", CA_ENGINE_VERSION),
    "</body></html>"), collapse = "\n")
  writeLines(html, path, useBytes = TRUE)
  return(list(status = "PASS", path = path))
}
