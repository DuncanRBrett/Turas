# ==============================================================================
# TURAS DESIGN SYSTEM - INTER FONT EMBED
# ==============================================================================
# Generates @font-face CSS with Inter font embedded as base64 woff2.
# Latin + Latin-ext subsets, weights 400/500/600 (variable font).
# Total embed size: ~180KB base64 (adds ~90KB to gzipped HTML).
#
# The font files are stored as .b64 text files in the fonts/ subdirectory
# to keep R source files clean.
#
# VERSION: 1.0.0
# ==============================================================================


#' Generate Inter Font @font-face CSS
#'
#' Returns CSS @font-face declarations with Inter font embedded as base64
#' data URIs. The font is a variable font supporting weights 400-600 in
#' a single file per unicode range.
#'
#' @return Character string of CSS @font-face declarations
#' @export
turas_font_face_css <- function() {
  font_dir <- file.path(
    dirname(sys.frame(1)$ofile %||% ""),
    "fonts"
  )

  # Fallback: find fonts relative to this file's known location
  if (!dir.exists(font_dir)) {
    # Try relative to shared module
    candidates <- c(
      file.path("modules", "shared", "lib", "design_system", "fonts"),
      file.path("..", "modules", "shared", "lib", "design_system", "fonts")
    )
    for (cand in candidates) {
      if (dir.exists(cand)) {
        font_dir <- cand
        break
      }
    }
  }

  # Read base64 font data
  latin_b64 <- ""
  latin_ext_b64 <- ""

  latin_path <- file.path(font_dir, "inter_latin.b64")
  latin_ext_path <- file.path(font_dir, "inter_latin_ext.b64")

  if (file.exists(latin_path)) {
    latin_b64 <- trimws(paste(readLines(latin_path, warn = FALSE), collapse = ""))
  }
  if (file.exists(latin_ext_path)) {
    latin_ext_b64 <- trimws(paste(readLines(latin_ext_path, warn = FALSE), collapse = ""))
  }

  # If fonts not found, return empty string (system fonts will be used)
  if (nchar(latin_b64) == 0) {
    return("/* Inter font files not found - using system font fallback */")
  }

  # Build @font-face declarations
  # Variable font: single file supports weights 400-600
  css_parts <- c()

  # Latin-ext subset (if available)
  if (nchar(latin_ext_b64) > 0) {
    css_parts <- c(css_parts, sprintf(
      '/* latin-ext */
@font-face {
  font-family: "Inter";
  font-style: normal;
  font-weight: 400 600;
  font-display: swap;
  src: url(data:font/woff2;base64,%s) format("woff2");
  unicode-range: U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7,
    U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F,
    U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113,
    U+2C60-2C7F, U+A720-A7FF;
}', latin_ext_b64))
  }

  # Latin subset (core)
  css_parts <- c(css_parts, sprintf(
    '/* latin */
@font-face {
  font-family: "Inter";
  font-style: normal;
  font-weight: 400 600;
  font-display: swap;
  src: url(data:font/woff2;base64,%s) format("woff2");
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6,
    U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC,
    U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}', latin_b64))

  paste(css_parts, collapse = "\n\n")
}


#' Null-coalescing operator (local)
#' @keywords internal
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
