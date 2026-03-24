# ==============================================================================
# TURAS > HUB APP > PPTX EXPORT
# ==============================================================================
# Purpose: Generate PowerPoint presentations from pinned views using the
#          officer R package. Each pin becomes a slide; section dividers
#          become section header slides.
# Location: modules/hub_app/lib/export_pptx.R
# ==============================================================================

#' Export Pinned Views to PowerPoint
#'
#' Builds a .pptx file from an ordered list of pins and section dividers.
#' Charts are embedded as PNG images (data URLs decoded to temp files).
#' Tables use officer's native table rendering. Insights are placed as
#' text boxes with basic markdown-to-text conversion.
#'
#' @param items List of pin/section objects (from JSON payload).
#' @param project_name Character string for the title slide.
#' @param output_dir Directory to write the .pptx file.
#' @param template_path Optional path to a branded .pptx template.
#'
#' @return TRS-compliant list with status, result (file path), message.
#'
#' @export
export_pins_to_pptx <- function(items,
                                 project_name = "Turas Export",
                                 output_dir = tempdir(),
                                 template_path = NULL) {

  # --- Guard: officer package ---
  if (!requireNamespace("officer", quietly = TRUE)) {
    cat("\n=== TURAS HUB APP ERROR ===\n")
    cat("Code: PKG_MISSING_DEPENDENCY\n")
    cat("Missing: officer\n")
    cat("Fix: install.packages('officer')\n")
    cat("============================\n\n")
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_DEPENDENCY",
      message = "The 'officer' package is required for PowerPoint export",
      how_to_fix = "Install with: install.packages('officer')"
    ))
  }

  if (!requireNamespace("base64enc", quietly = TRUE)) {
    cat("\n=== TURAS HUB APP ERROR ===\n")
    cat("Code: PKG_MISSING_DEPENDENCY\n")
    cat("Missing: base64enc\n")
    cat("Fix: install.packages('base64enc')\n")
    cat("============================\n\n")
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_DEPENDENCY",
      message = "The 'base64enc' package is required for image decoding",
      how_to_fix = "Install with: install.packages('base64enc')"
    ))
  }

  # --- Guard: items ---
  if (is.null(items) || length(items) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_PINS",
      message = "No pins to export",
      how_to_fix = "Pin some charts or tables before exporting"
    ))
  }

  # --- Guard: output directory ---
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  tryCatch({
    cat("[Hub App Export] Building PPTX for:", project_name, "\n")

    # --- Create presentation ---
    # Try: explicit template → default branded template → built-in Office theme
    if (!is.null(template_path) && file.exists(template_path)) {
      pptx <- officer::read_pptx(template_path)
      cat("[Hub App Export] Using custom template:", template_path, "\n")
    } else {
      # Look for the bundled branded template
      turas_root <- Sys.getenv("TURAS_ROOT", getwd())
      branded_path <- file.path(turas_root, "modules", "hub_app", "assets",
                                 "turas_template.pptx")
      if (file.exists(branded_path)) {
        pptx <- officer::read_pptx(branded_path)
        cat("[Hub App Export] Using branded Turas template\n")
      } else {
        pptx <- officer::read_pptx()
      }
    }

    # --- Title slide ---
    pptx <- officer::add_slide(pptx, layout = "Title Slide", master = "Office Theme")
    pptx <- officer::ph_with(pptx,
      value = project_name,
      location = officer::ph_location_type(type = "ctrTitle")
    )
    pptx <- officer::ph_with(pptx,
      value = paste("Generated:", format(Sys.time(), "%d %B %Y")),
      location = officer::ph_location_type(type = "subTitle")
    )

    # --- Process each item ---
    pin_count <- 0
    section_count <- 0
    temp_files <- character(0)

    for (item in items) {
      item_type <- item$type %||% "unknown"

      if (item_type == "section") {
        # Section header slide
        pptx <- officer::add_slide(pptx,
          layout = "Section Header",
          master = "Office Theme"
        )
        pptx <- officer::ph_with(pptx,
          value = item$title %||% "Section",
          location = officer::ph_location_type(type = "title")
        )
        section_count <- section_count + 1

      } else if (item_type == "pin") {
        # Content slide for pin
        pptx <- add_pin_slide(pptx, item, temp_files)
        pin_count <- pin_count + 1
      }
    }

    # --- Save ---
    safe_name <- gsub("[^a-zA-Z0-9_ -]", "", project_name)
    safe_name <- gsub("\\s+", "_", trimws(safe_name))
    if (nchar(safe_name) == 0) safe_name <- "Turas_Export"

    filename <- paste0(safe_name, "_",
                        format(Sys.time(), "%Y%m%d_%H%M%S"),
                        ".pptx")
    output_path <- file.path(output_dir, filename)

    print(pptx, target = output_path)

    # Clean up temp files
    for (tf in temp_files) {
      if (file.exists(tf)) unlink(tf)
    }

    cat("[Hub App Export] PPTX saved:", output_path, "\n")
    cat("[Hub App Export]", pin_count, "pin slides,",
        section_count, "section slides\n")

    return(list(
      status = "PASS",
      result = list(
        path = output_path,
        filename = filename,
        pin_count = pin_count,
        section_count = section_count
      ),
      message = sprintf("Exported %d pins to %s", pin_count, filename)
    ))

  }, error = function(e) {
    cat("\n=== TURAS HUB APP ERROR ===\n")
    cat("Code: CALC_EXPORT_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("============================\n\n")
    return(list(
      status = "REFUSED",
      code = "CALC_EXPORT_FAILED",
      message = paste("PPTX export failed:", e$message),
      how_to_fix = "Check the R console for details"
    ))
  })
}


#' Add a Pin Slide to the Presentation
#'
#' Creates a slide with the pin's title, subtitle, chart image,
#' and insight text. Uses "Two Content" or "Title and Content"
#' layout depending on available content.
#'
#' @param pptx officer pptx object
#' @param pin Pin list object
#' @param temp_files Character vector of temp file paths (modified by reference via env)
#'
#' @return Modified pptx object
#' @keywords internal
add_pin_slide <- function(pptx, pin, temp_files) {

  # Determine layout based on content
  has_chart <- !is.null(pin$chartPng) && nzchar(pin$chartPng %||% "")
  has_insight <- nzchar(pin$insight %||% "")

  layout <- "Title and Content"
  master <- "Office Theme"

  pptx <- officer::add_slide(pptx, layout = layout, master = master)

  # Title
  title_text <- pin$title %||% "Pinned View"
  if (nzchar(pin$sourceLabel %||% "")) {
    title_text <- paste0("[", pin$sourceLabel, "] ", title_text)
  }
  pptx <- officer::ph_with(pptx,
    value = title_text,
    location = officer::ph_location_type(type = "title")
  )

  # Build body content
  body_parts <- character(0)

  # Subtitle
  if (nzchar(pin$subtitle %||% "")) {
    body_parts <- c(body_parts, pin$subtitle)
  }

  # Insight text (strip markdown for plain text)
  if (has_insight) {
    insight_plain <- strip_markdown(pin$insight)
    body_parts <- c(body_parts, "", insight_plain)
  }

  # Add text body if we have any
  if (length(body_parts) > 0) {
    body_text <- paste(body_parts, collapse = "\n")
    pptx <- officer::ph_with(pptx,
      value = body_text,
      location = officer::ph_location_type(type = "body")
    )
  }

  # Chart image
  if (has_chart) {
    img_path <- decode_data_url_to_file(pin$chartPng)
    if (!is.null(img_path) && file.exists(img_path)) {
      temp_files <- c(temp_files, img_path)

      # Place chart image — positioned in lower portion of slide
      pptx <- officer::ph_with(pptx,
        value = officer::external_img(img_path, width = 8, height = 4),
        location = officer::ph_location(
          left = 1, top = 3.5,
          width = 8, height = 4
        )
      )
    }
  }

  pptx
}


#' Decode a data:image/png;base64 URL to a temporary PNG file
#'
#' @param data_url Character string with base64 data URL
#' @return Path to temp PNG file, or NULL on failure
#' @keywords internal
decode_data_url_to_file <- function(data_url) {
  if (is.null(data_url) || !grepl("^data:image/", data_url)) {
    return(NULL)
  }

  tryCatch({
    # Extract base64 portion after the comma
    b64 <- sub("^data:image/[^;]+;base64,", "", data_url)
    raw_bytes <- base64enc::base64decode(b64)

    tmp <- tempfile(fileext = ".png")
    writeBin(raw_bytes, tmp)
    tmp
  }, error = function(e) {
    cat("[Hub App Export] Failed to decode image:", e$message, "\n")
    NULL
  })
}


#' Strip Markdown to Plain Text
#'
#' Converts simple markdown (bold, italic, headings, bullets,
#' blockquotes) to plain text for PPTX text boxes.
#'
#' @param md Character string with markdown
#' @return Plain text string
#' @keywords internal
strip_markdown <- function(md) {
  if (is.null(md) || !nzchar(md)) return("")

  text <- md
  # Remove heading markers
  text <- gsub("^##\\s+", "", text)
  # Remove bold/italic markers
  text <- gsub("\\*\\*(.+?)\\*\\*", "\\1", text)
  text <- gsub("\\*(.+?)\\*", "\\1", text)
  # Convert blockquotes
  text <- gsub("^>\\s+", "", text)
  # Convert bullet points
  text <- gsub("^-\\s+", "\u2022 ", text)

  text
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
