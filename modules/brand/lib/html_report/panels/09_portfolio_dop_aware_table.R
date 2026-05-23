# ==============================================================================
# BRAND MODULE - PORTFOLIO DUPLICATION OF AWARENESS TABLE
# ==============================================================================
# Renders the Duplication of Awareness table that sits below the constellation
# chart on the Competitive Set sub-tab.
#
# View toggle: Observed / Expected (Sharp's D) / Deviation. Switching views
# is a pure JS swap — the renderer emits all three matrices in a single JSON
# payload and the client-side renderer in brand_portfolio_panel.js
# (pf-dopa-* hooks) picks the active one and rebuilds the table.
#
# Category chips are shared with the constellation chart: when a chip is
# clicked the JS reads the new active cat and re-renders the matrix.
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


#' Build Duplication of Awareness HTML block
#'
#' Mounts the view toggle, the D coefficient header line, the JSON payload
#' script tag, and the empty table host. The JS hydrator fills the table
#' for the active category.
#'
#' @param dop_aware List. \code{panel_data$dop_awareness} block.
#' @param focal_brand Character. Focal brand code (drives row pinning).
#' @param focal_colour Character. Focal brand colour (hex).
#'
#' @return Character. HTML fragment, or "" when no DoA data is available.
#' @keywords internal
build_pf_dop_aware_block <- function(dop_aware, focal_brand, focal_colour) {
  if (is.null(dop_aware) || length(dop_aware$by_cat %||% list()) == 0) {
    return("")
  }

  payload_json <- .pf_dopa_to_json(dop_aware, focal_brand, focal_colour)
  data_script <- sprintf(
    '<script type="application/json" id="pf-dopa-data">%s</script>',
    payload_json
  )

  view_toggle <- paste0(
    '<div class="pf-dopa-view-toggle" role="tablist" aria-label="Matrix view">',
    '<button type="button" class="pf-dopa-view-btn pf-dopa-view-on" data-pf-dopa-view="observed">Observed</button>',
    '<button type="button" class="pf-dopa-view-btn" data-pf-dopa-view="expected">Expected (Sharp&#39;s D)</button>',
    '<button type="button" class="pf-dopa-view-btn" data-pf-dopa-view="deviation">Deviation</button>',
    '</div>'
  )

  d_line <- paste0(
    '<div class="pf-dopa-d-line">',
    'Sharp&#39;s duplication coefficient ',
    '<span class="pf-dopa-d-value" data-pf-dopa-d>&mdash;</span> ',
    'for <span class="pf-dopa-cat-label" data-pf-dopa-cat-label>&mdash;</span>',
    '</div>'
  )

  reading <- .pf_dopa_reading_guide()

  paste0(
    '<div class="pf-dopa-block" id="pf-dopa">',
    '<div class="pf-dopa-header">',
    '<h4 class="pf-dopa-title">Duplication of Awareness</h4>',
    '<p class="pf-dopa-sub">Within the active category, what % of one brand&#39;s awares are also aware of every other brand &mdash; benchmarked against Sharp&#39;s Duplication Law.</p>',
    '</div>',
    data_script,
    '<div class="pf-dopa-controls">',
    view_toggle,
    d_line,
    '</div>',
    sprintf('<div id="pf-dopa-table-host" class="pf-dopa-table-host" data-pf-dopa-focal="%s"></div>',
            .pf_esc(focal_brand)),
    reading,
    '</div>'
  )
}


# ==============================================================================
# JSON PAYLOAD
# ==============================================================================

#' Serialise per-category Duplication of Awareness for the JS hydrator.
#'
#' Emits one entry per category with brand codes/labels, the three matrices
#' flattened to row-major arrays, awareness penetrations, D, and the low-base
#' brand flags. Compact: typical category with 8 brands ≈ 1KB.
#'
#' @keywords internal
.pf_dopa_to_json <- function(dop_aware, focal_brand, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")

  by_cat <- dop_aware$by_cat %||% list()
  cats <- lapply(by_cat, function(c) {
    list(
      cat_code        = as.character(c$cat_code),
      cat_label       = as.character(c$cat_label %||% c$cat_code),
      brand_codes     = as.character(c$brand_codes),
      brand_lbls      = as.character(c$brand_lbls),
      aware_pcts      = .pf_dopa_mat_to_rows(c$aware_pcts),
      n_aware_w       = .pf_dopa_mat_to_rows(c$n_aware_w),
      n_aware_uw      = as.integer(c$n_aware_uw),
      D               = if (is.null(c$D) || is.na(c$D)) NA_real_
                        else as.numeric(c$D),
      observed        = .pf_dopa_mat_to_rows(c$observed_matrix),
      expected        = .pf_dopa_mat_to_rows(c$expected_matrix),
      deviation       = .pf_dopa_mat_to_rows(c$deviation_matrix),
      low_base_brands = as.character(c$low_base_brands %||% character(0)),
      n_buyers_uw     = as.integer(c$n_buyers_uw %||% 0L),
      n_buyers_w      = as.numeric(c$n_buyers_w %||% 0)
    )
  })

  payload <- list(
    focal_brand  = as.character(focal_brand %||% ""),
    focal_colour = as.character(focal_colour %||% "#1A5276"),
    cat_order    = as.character(dop_aware$cat_order %||% character(0)),
    cats         = cats
  )
  tryCatch(
    jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 3),
    error = function(e) "{}"
  )
}


#' Flatten a numeric matrix to row-major arrays-of-arrays for JSON.
#'
#' Preserves NA as NA (which jsonlite emits as null). Vectors pass through
#' unchanged.
#'
#' @keywords internal
.pf_dopa_mat_to_rows <- function(m) {
  if (is.null(m)) return(NULL)
  if (!is.matrix(m)) return(as.numeric(m))
  lapply(seq_len(nrow(m)), function(i) as.numeric(m[i, ]))
}


# ==============================================================================
# READING GUIDE
# ==============================================================================

.pf_dopa_reading_guide <- function() {
  paste0(
    '<div class="pf-dopa-reading">',

    '<p class="pf-dopa-reading-line"><strong>How to read it:</strong> ',
    'Pick a row (brand A) and a column (brand B). The cell tells you what percentage of the people aware of A are also aware of B &mdash; ',
    'within the currently selected category. Rows always sum out of A&#39;s awares (so the diagonal is 100%). The matrix is asymmetric: ',
    'A&rarr;B will usually differ from B&rarr;A because the two brands have different awareness penetrations.</p>',

    '<p class="pf-dopa-reading-line"><strong>What the three views show:</strong> ',
    '<em>Observed</em> &mdash; what we actually saw in the data. ',
    '<em>Expected (Sharp&#39;s D)</em> &mdash; what we would expect if brands were mentally co-known in proportion to their overall awareness, with no special competitive ties. ',
    'Sharp&#39;s duplication law says expected[i,j] = D &times; aware%(j), where D is fit from the off-diagonal cells. ',
    '<em>Deviation</em> &mdash; observed minus expected, in percentage points. This is the diagnostic view.</p>',

    '<p class="pf-dopa-reading-line"><strong>What the deviation means:</strong> ',
    '<strong>Positive cells</strong> = brands that over-share awareness. Their awares are <em>more</em> likely than expected to also know the partner &mdash; these are direct mental-space rivals. ',
    '<strong>Negative cells</strong> = partition brands. Their awares are <em>less</em> likely than expected to know the partner &mdash; the two brands sit in genuinely different mental spaces. ',
    'A row dominated by negative cells flags a brand whose awares are unusually self-contained. A column dominated by positive cells flags a brand that gets &ldquo;ridden along&rdquo; with other brands&#39; awareness.</p>',

    '<p class="pf-dopa-reading-line"><strong>About D:</strong> ',
    'D is a single number per category. It tells you, on average, how strongly each percentage point of brand-j awareness translates into rival-pair co-awareness. ',
    'Compare D across categories to see where the awareness universe is structurally tighter (high D = more shared minds, fewer partitions) versus more fragmented (low D = more partition structure, brands more independently known).</p>',

    '<p class="pf-dopa-reading-line"><strong>How to use it alongside the constellation:</strong> ',
    'The constellation visualises which brands cluster in mental space. The deviation table tells you <em>how unusual</em> any given pair is once you account for each brand&#39;s overall awareness level. ',
    'A big bright edge in the constellation chart that turns out to have a near-zero deviation means the co-awareness is just what you&#39;d expect for two well-known brands &mdash; not a true competitive tie. ',
    'A high deviation between two small brands means an unusually strong mental link that the constellation may not visually emphasise.</p>',

    '<p class="pf-dopa-reading-line"><strong>How this reconciles with the constellation&rsquo;s Jaccard score:</strong> ',
    'The constellation&rsquo;s Jaccard score and this table&rsquo;s DoA cells are three views of the same underlying overlap &mdash; they always reconcile if you do the maths. ',
    'For any two brands A and B: ',
    '<code class="pf-ex-formula">both = aware%(A) &times; DoA(A&rarr;B) = aware%(B) &times; DoA(B&rarr;A)</code> ',
    '<code class="pf-ex-formula">union = aware%(A) + aware%(B) &minus; both</code> ',
    '<code class="pf-ex-formula">Jaccard(A,B) = both &divide; union</code> ',
    'So if brand A has 45% awareness, brand B has 72% awareness, and the DoA cells are A&rarr;B = 79% and B&rarr;A = 49%, then both = 0.45 &times; 0.79 = 35.5%, union = 45 + 72 &minus; 35.5 = 81.5%, and Jaccard = 35.5 / 81.5 = 44%. All three numbers describe the same pair.</p>',

    '<p class="pf-dopa-reading-line"><strong>Why the three numbers still tell you different things:</strong> ',
    '<em>Jaccard</em> is symmetric &mdash; one number per pair, computed over everyone who knows <em>either</em> brand. ',
    '<em>DoA cells</em> are asymmetric &mdash; two numbers per pair, computed over the awares of the row brand. ',
    'For a small brand competing against a much larger one, the two DoA cells are usually very different: the small brand&rsquo;s awares almost all also know the giant (high A&rarr;B), but the giant&rsquo;s awares only sometimes know the small brand (lower B&rarr;A). ',
    'The Jaccard collapses both into one number and hides that asymmetry. ',
    'Read the constellation when you want a single visual map of which brands cluster; read the DoA table when you need to see <em>which direction</em> the dependency runs and whether it&rsquo;s more or less duplication than Sharp&rsquo;s Law predicts.</p>',

    '</div>'
  )
}
