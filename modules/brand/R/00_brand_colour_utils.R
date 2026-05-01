# ==============================================================================
# BRAND MODULE — COLOUR UTILITIES
# ==============================================================================
# Shared palette and colour-assignment logic used by all panel data builders.
#
# Key principle: colours are assigned once in R using brand_list position, so
# every panel receives a fully-populated brand_colours map with no two brands
# sharing the same colour. The JS hash fallback in brand_colours.js is only
# reached if a brand somehow appears outside this map (edge case).
# ==============================================================================

# 18-entry palette ordered for maximum visual distinctiveness when assigned
# sequentially.  The focal brand always receives config$colour_focal (navy by
# default), so these 18 slots cover the non-focal competitor brands.
#
# Design notes:
#   - First 8 entries are maximally distinct hues (red, orange, green, yellow,
#     teal, purple, rose, brown) — most studies have ≤8 competitors.
#   - Blues (indices 8–10) are placed later to avoid clashing with the default
#     focal navy (#1A5276).
#   - Entries 10–17 extend coverage for large studies (9–18 competitors).
#   - Must stay in sync with PALETTE in brand_colours.js.
BRAND_COLOUR_PALETTE <- c(
  "#e15759",  #  0  red
  "#f28e2b",  #  1  orange
  "#59a14f",  #  2  green
  "#edc948",  #  3  yellow
  "#76b7b2",  #  4  teal
  "#b07aa1",  #  5  mauve
  "#d37295",  #  6  dark rose
  "#9c755f",  #  7  brown
  "#4e79a7",  #  8  steel blue  (placed here to avoid clashing with focal navy)
  "#499894",  #  9  dark teal
  "#e8a838",  # 10  amber
  "#1e8449",  # 11  dark green
  "#7d3c98",  # 12  deep purple
  "#2980b9",  # 13  bright blue
  "#ff9da7",  # 14  light rose
  "#bab0ac",  # 15  warm grey
  "#9d7660",  # 16  tan
  "#79706e"   # 17  charcoal
)


#' Build a fully-populated brand colour map.
#'
#' Every brand in \code{brand_list} receives a unique colour:
#' \itemize{
#'   \item Explicit hex from the Brands sheet \code{Colour} column (highest
#'     priority — user-set colours are always honoured).
#'   \item Focal brand falls back to \code{focal_colour} if not explicitly set.
#'   \item All remaining brands are assigned palette colours sequentially based
#'     on their position in \code{brand_list} (focal excluded), ensuring no two
#'     brands share a colour for any study with ≤18 non-focal brands.
#' }
#'
#' @param brand_list Data frame. Must have a \code{BrandCode} column.
#'   May optionally have a \code{Colour} column with hex strings.
#' @param focal_code Character or NULL. Focal brand code.
#' @param focal_colour Character. Hex colour for the focal brand.
#'   Defaults to Turas navy.
#' @param palette Character vector. Ordered palette for auto-assignment of
#'   non-focal brands. Defaults to \code{BRAND_COLOUR_PALETTE}.
#'
#' @return Named list mapping every BrandCode in \code{brand_list} to a hex
#'   colour string. Always returns a non-empty list when brand_list is valid.
#'
#' @export
build_full_brand_colour_map <- function(brand_list,
                                         focal_code    = NULL,
                                         focal_colour  = "#1A5276",
                                         palette       = BRAND_COLOUR_PALETTE) {
  if (is.null(brand_list) || !is.data.frame(brand_list) || nrow(brand_list) == 0) {
    return(list())
  }

  if (!("BrandCode" %in% names(brand_list))) return(list())

  codes          <- trimws(as.character(brand_list$BrandCode))
  has_colour_col <- "Colour" %in% names(brand_list)

  # ---- Step 1: Read explicit per-brand hex codes from Brands sheet ----------
  explicit <- list()
  if (has_colour_col) {
    for (i in seq_along(codes)) {
      col <- brand_list$Colour[i]
      if (is.null(col) || is.na(col)) next
      col <- trimws(as.character(col))
      if (!nzchar(col)) next
      if (!grepl("^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", col)) {
        message(sprintf("[BRAND COLOURS] Brand '%s': '%s' is not a valid hex — skipped.",
                        codes[i], col))
        next
      }
      explicit[[codes[i]]] <- col
    }
  }

  # ---- Step 2: Assign colours -----------------------------------------------
  out         <- list()
  palette_idx <- 1L
  n_palette   <- length(palette)

  for (code in codes) {
    if (!is.null(explicit[[code]])) {
      # Explicit entry always wins
      out[[code]] <- explicit[[code]]
    } else if (!is.null(focal_code) && code == focal_code) {
      # Focal brand gets the project focal colour
      out[[code]] <- focal_colour
    } else {
      # Auto-assign next palette slot (skip focal's slot if focal is in range)
      # Wrap if we run out of palette entries — still better than hash collisions
      out[[code]] <- palette[[(palette_idx - 1L) %% n_palette + 1L]]
      palette_idx <- palette_idx + 1L
    }
  }

  out
}
