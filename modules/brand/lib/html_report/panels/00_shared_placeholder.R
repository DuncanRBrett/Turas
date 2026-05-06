# ==============================================================================
# BRAND MODULE - SHARED PLACEHOLDER CARD HELPER
# ==============================================================================
# A single helper used by every brand-module element panel that supports
# placeholder mode (rendered when an element is enabled in config but the
# data has not yet been collected). Ensures all "Data not yet collected"
# cards across the brand report look and behave identically.
#
# Used by:
#   - 07_dba_panel.R           (DBA placeholder)
#   - 10_branded_reach_panel.R (Branded Reach placeholder)
#
# The card is wrapped in a section root the existing TurasPins library
# can capture; pin button is a sibling of the body so toolbar export
# can include placeholder cards in collated PNG/PDF output.
#
# VERSION: 1.0
# ==============================================================================

BRAND_SHARED_PLACEHOLDER_VERSION <- "1.0"


#' Build a placeholder card for an element awaiting first-wave data
#'
#' Renders a clean "Data not yet collected" card. The card includes a
#' short title, an explanatory note, an optional badge label (e.g. the
#' wave label), and a small icon. Visual treatment matches the brand-
#' module card pattern so the placeholder reads as informational, not
#' broken.
#'
#' @param scope_id Character. The DOM id for the section root (e.g.
#'   "section-dba" or "section-branded-reach-DSS"). Used by TurasPins
#'   to scope a pin to this card.
#' @param title Character. Card title (e.g. "Distinctive Brand Assets").
#' @param note Character. Body text shown to the analyst (typically the
#'   element's PLACEHOLDER_NOTE constant). Used as-is, escaped for HTML.
#' @param badge Character. Optional small badge text shown below the
#'   title (e.g. wave label or category label).
#' @param next_step Character. Optional one-line action recommendation
#'   shown beneath the note (e.g. "Add MarketingReach assets to the
#'   Survey_Structure to populate this panel").
#'
#' @return Character. A single HTML fragment.
#'
#' @examples
#' \dontrun{
#'   build_shared_placeholder_card(
#'     scope_id = "section-dba",
#'     title    = "Distinctive Brand Assets",
#'     note     = "Data not yet collected for DBA",
#'     badge    = "Wave 1"
#'   )
#' }
#'
#' @export
build_shared_placeholder_card <- function(scope_id,
                                            title,
                                            note,
                                            badge     = "",
                                            next_step = "") {

  if (is.null(scope_id) || !nzchar(scope_id)) scope_id <- "section-placeholder"
  if (is.null(title)    || !nzchar(title))    title    <- "Element"
  if (is.null(note)     || !nzchar(note))     note     <- "Data not yet collected"

  badge_html <- if (nzchar(badge))
    sprintf('<span class="brand-placeholder-badge">%s</span>',
            .brand_placeholder_esc(badge)) else ""

  next_step_html <- if (nzchar(next_step))
    sprintf('<p class="brand-placeholder-next">%s</p>',
            .brand_placeholder_esc(next_step)) else ""

  sprintf(
    '<section class="brand-placeholder-card" id="%s" data-section="%s">
      <div class="brand-placeholder-icon" aria-hidden="true">%s</div>
      <div class="brand-placeholder-body">
        <h3 class="brand-placeholder-title">%s</h3>
        %s
        <p class="brand-placeholder-note">%s</p>
        %s
      </div>
    </section>',
    .brand_placeholder_esc(scope_id),
    .brand_placeholder_esc(scope_id),
    .brand_placeholder_clock_svg(),
    .brand_placeholder_esc(title),
    badge_html,
    .brand_placeholder_esc(note),
    next_step_html
  )
}


#' Build the shared placeholder CSS bundle
#'
#' Returns a CSS string scoped to \code{.brand-placeholder-*} classes.
#' Designed to read cleanly in light report themes; dark-theme variants
#' kick in via the existing \code{.theme-dark} ancestor selector if the
#' host page sets it.
#'
#' @return Character. CSS string, no surrounding \code{<style>} tags.
#'
#' @export
build_shared_placeholder_styles <- function() {
'.brand-placeholder-card{
  display:flex;align-items:flex-start;gap:18px;
  padding:24px 28px;margin:24px 0;
  background:#fbfaf6;border:1px solid #e6e3da;border-radius:8px;
  max-width:760px;
}
.brand-placeholder-icon{
  flex:0 0 36px;width:36px;height:36px;color:#8a8478;
}
.brand-placeholder-icon svg{width:36px;height:36px;display:block;}
.brand-placeholder-body{flex:1 1 auto;}
.brand-placeholder-title{
  margin:0 0 4px 0;font-size:16px;font-weight:600;color:#1f2933;
}
.brand-placeholder-badge{
  display:inline-block;padding:2px 8px;margin-bottom:8px;
  background:#efece4;border-radius:999px;
  font-size:11px;font-weight:600;color:#5e574a;letter-spacing:0.4px;
  text-transform:uppercase;
}
.brand-placeholder-note{
  margin:6px 0 0 0;font-size:14px;line-height:1.5;color:#3b424c;
}
.brand-placeholder-next{
  margin:8px 0 0 0;font-size:13px;line-height:1.5;color:#5b6470;
  font-style:italic;
}
.theme-dark .brand-placeholder-card{
  background:#1e2733;border-color:#2c3a4a;
}
.theme-dark .brand-placeholder-title{color:#e6ebf1;}
.theme-dark .brand-placeholder-badge{
  background:#2c3a4a;color:#cfd6df;
}
.theme-dark .brand-placeholder-note{color:#bcc4cd;}
.theme-dark .brand-placeholder-next{color:#9aa3ad;}
'
}


# ==============================================================================
# Internal helpers
# ==============================================================================

.brand_placeholder_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

# A subtle clock-face icon — communicates "awaiting" without alarm.
.brand_placeholder_clock_svg <- function() {
'<svg viewBox="0 0 36 36" fill="none" stroke="currentColor" stroke-width="2"
   stroke-linecap="round" stroke-linejoin="round" role="img"
   aria-label="Awaiting data">
  <circle cx="18" cy="18" r="14"></circle>
  <polyline points="18,10 18,18 24,21"></polyline>
</svg>'
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand shared placeholder helper loaded (v%s)",
                  BRAND_SHARED_PLACEHOLDER_VERSION))
}
