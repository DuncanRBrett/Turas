# ==============================================================================
# TABS — DATA-LAYER WRITER (V11, data-centric report v2)
# ==============================================================================
# Emits the `data-agg` JSON island consumed by the v2 (data-centric) renderer,
# alongside the existing Excel/HTML outputs. Aggregates only — no microdata.
#
# The shape is documented and verified in
# prototypes/report-redesign/fable/v2/SESSION_1_TABS_WRITER.md. The renderer's
# hard contract (src/js/20_data.js d2.validate) requires only a non-empty
# questions[] and columns[]; every other field is read defensively, so optional
# structures (net_members, index_scores, ...) are omitted in this first cut and
# added when microdata/live-filtering land.
#
# Row classification runs through the shared helpers in report_shared.R
# (normalize_question_table, detect_available_stats, classify_row_labels), which
# must be sourced first — they define what counts as a category / NET / mean row
# for every consumer of a question table.
# ==============================================================================

# Null-coalesce — defined locally only if the tabs helper is not already in scope
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}


#' Map a tabs Variable_Type to a v2 renderer question type
#'
#' @param vt Character, the tabs question/Variable type
#' @return One of "single" | "multi" | "scale" | "nps" | "numeric". Numeric
#'   open-counts map to "numeric" (not "scale") so the v2 index dashboard can
#'   tell a rated touchpoint apart from an unbounded count — only scale/nps
#'   questions are colour-banded against a scale maximum.
#' @export
map_question_type <- function(vt) {
  switch(as.character(vt %||% ""),
    "Single_Choice"   = "single",
    "Single_Response" = "single",
    "Multi_Mention"   = "multi",
    "Multi_Response"  = "multi",
    "Rating"          = "scale",
    "Likert"          = "scale",
    "Numeric"         = "numeric",
    "NPS"             = "nps",
    "Ranking"         = "single",
    "single"
  )
}


#' Build the sampling-aware significance legend note
#'
#' Probability designs speak confidence-interval language; non-probability
#' designs get the honest softened wording. Mirrors the prototype's
#' 21c_confidence.js sampling labels.
#'
#' @param alpha Numeric significance level (e.g. 0.05)
#' @param sampling_method Character design code
#' @return A single legend sentence
#' @export
build_sig_note <- function(alpha = 0.05, sampling_method = "Not_Specified") {
  conf <- round((1 - as.numeric(alpha %||% 0.05)) * 100)
  is_prob <- as.character(sampling_method %||% "Not_Specified") %in%
    c("Random", "Stratified", "Cluster", "Census")
  interval <- if (is_prob) "confidence intervals" else "stability intervals"
  sprintf(paste0(
    "Capital letters mark a column whose value is significantly higher than ",
    "the lettered column at the %d%% level; the Total column is not tested. ",
    "Ranges around values are %s."), conf, interval)
}


#' Encode an image file as a base64 data URI for inline embedding
#'
#' Supports SVG / PNG / JPG. Returns NULL when the path is missing, the file
#' does not exist, the format is unsupported, or base64enc is unavailable — the
#' renderer then falls back to the brand dot.
#'
#' @param path Absolute path to a logo image, or NULL
#' @return A "data:...;base64,..." string, or NULL
#' @export
encode_logo_data_uri <- function(path) {
  if (is.null(path) || !nzchar(as.character(path)) || !file.exists(path)) return(NULL)
  if (!requireNamespace("base64enc", quietly = TRUE)) return(NULL)
  ext <- tolower(tools::file_ext(path))
  if (ext == "svg") {
    svg <- paste(readLines(path, warn = FALSE), collapse = "\n")
    return(paste0("data:image/svg+xml;base64,", base64enc::base64encode(charToRaw(svg))))
  }
  if (ext %in% c("png", "jpg", "jpeg")) {
    mime <- if (ext == "png") "image/png" else "image/jpeg"
    raw_bytes <- readBin(path, "raw", file.info(path)$size)
    return(paste0("data:", mime, ";base64,", base64enc::base64encode(raw_bytes)))
  }
  NULL
}


#' Build the project block of the data layer
#'
#' @param config_obj The tabs config object
#' @param tracking_enabled Logical; TRUE when a tracking island will be inlined
#'   (the renderer only shows the Tracking tab when this is TRUE AND a prior-wave
#'   island is present)
#' @return A named list of project metadata
#' @export
build_dl_project <- function(config_obj, tracking_enabled = FALSE) {
  # The config loader surfaces an empty cell as the literal string "NA", so
  # treat that (and whitespace-only) as blank — no display/metadata field is
  # ever legitimately "NA", and shipping a bare "NA" into the report header or
  # the About panel would look like a defect.
  blank <- function(x) {
    if (is.null(x) || length(x) == 0) return(TRUE)
    if (length(x) > 1) return(FALSE)
    if (is.na(x)) return(TRUE)
    s <- trimws(as.character(x))
    !nzchar(s) || s == "NA"
  }
  name <- if (!blank(config_obj$project_title)) config_obj$project_title
          else if (!blank(config_obj$project_name)) config_obj$project_name
          else "Turas Report"
  # [[ ]] access: $alpha would PARTIAL-MATCH alpha_secondary/alpha_default when
  # a config lacks alpha, silently testing at the wrong level.
  alpha <- suppressWarnings(as.numeric(config_obj[["alpha"]] %||% 0.05))
  if (length(alpha) != 1L || is.na(alpha) || alpha <= 0 || alpha >= 1) alpha <- 0.05
  # The secondary (dual-sig) level and the Bonferroni flag travel with the report
  # so the in-browser recompute engine tests at the SAME levels as the published
  # letters (the config loader can hand us "NA" strings — treat those as absent).
  alpha2 <- suppressWarnings(as.numeric(config_obj[["alpha_secondary"]]))
  if (length(alpha2) != 1L || is.na(alpha2) || alpha2 <= alpha || alpha2 >= 1) alpha2 <- 0.20
  bon_raw <- config_obj$bonferroni_correction
  bonferroni <- if (is.logical(bon_raw)) {
    isTRUE(bon_raw)
  } else {
    !(toupper(trimws(as.character(bon_raw %||% "TRUE"))) %in% c("FALSE", "F", "N", "NO", "0"))
  }
  sm <- as.character(config_obj$sampling_method %||% "Not_Specified")
  proj <- list(
    name               = as.character(name),
    client             = if (blank(config_obj$client_name)) "" else as.character(config_obj$client_name),
    wave               = if (blank(config_obj$wave)) "" else as.character(config_obj$wave),
    brand_colour       = as.character(config_obj$brand_colour %||% "#323367"),
    accent_colour      = as.character(config_obj$accent_colour %||% "#CC9900"),
    low_base_threshold = as.numeric(config_obj$significance_min_base %||% 30),
    alpha              = alpha,
    alpha_secondary    = alpha2,
    # Which level the report OPENS on. The setting has been registered,
    # validated and offered by the config template for a long time, but nothing
    # ever consumed it — so an operator who set alpha_default = secondary got no
    # warning and no effect (review 2026-08-21, I-25). Only meaningful when a
    # secondary level is configured; the renderer ignores it otherwise.
    alpha_default      = {
      # Only honoured when the study actually CONFIGURED a secondary level.
      # alpha_secondary above always carries a number (it falls back to 0.20),
      # so the renderer cannot tell configured from defaulted — and
      # validate_dual_significance_config() returns early when the setting is
      # absent, so "alpha_default = secondary" on a single-alpha study is never
      # refused either. Without this gate such a study would open in dual mode
      # showing an 80% level it never asked for.
      ad <- tolower(trimws(as.character(config_obj$alpha_default %||% "primary")))
      has_secondary <- !is.null(config_obj[["alpha_secondary"]]) &&
        !is.na(suppressWarnings(as.numeric(config_obj[["alpha_secondary"]])))
      if (identical(ad, "secondary") && has_secondary) "secondary" else "primary"
    },
    bonferroni         = bonferroni,
    sampling_method    = sm,
    sig_note           = build_sig_note(alpha, sm),
    tracking           = list(enabled = isTRUE(tracking_enabled), default_scope = "all")
  )
  # The crosstab heat tint's base colour. Emitted ONLY when the operator set it,
  # so an island from a config that never mentions heatmap_colour is byte-identical
  # to the ones already committed and the tint stays on the brand colour
  # (production review 2026-08, I11 — the setting was whitelisted, templated and
  # documented, and read by nothing).
  if (!blank(config_obj$heatmap_colour)) {
    proj$heatmap_colour <- as.character(config_obj$heatmap_colour)
  }
  # Exec-summary cover. Carried ONLY when the study opted in, so a config that
  # never mentions it emits a byte-identical island and its saved copies open on
  # the dashboard as they always have. The cover changes what a client sees when
  # they open the file, which is a per-project decision, not a default.
  if (isTRUE(config_obj$html_report_v2_cover)) {
    proj$cover <- TRUE
    # How many pins the cover lists. Carried only when the study set it, so a
    # config that names no count emits the same island it always did and the
    # renderer's default of 5 stands. 0 = ALL (no limit).
    cf <- suppressWarnings(as.numeric(config_obj$html_report_v2_cover_findings))
    if (length(cf) == 1L && !is.na(cf) && cf >= 0) {
      proj$cover_findings <- cf
    }
  }
  # Total universe size (finite population correction). Carried only when a
  # usable value is configured; the renderer derives the overall response /
  # coverage rate from it (TR.MICRO.n / population_size) and corrects the Total
  # column's intervals. Omitted -> no correction (byte-identical to today).
  pop_size <- suppressWarnings(as.numeric(config_obj$population_size))
  if (length(pop_size) == 1L && !is.na(pop_size) && pop_size > 1) {
    proj$population_size <- pop_size
  }
  # Disclosure-control threshold (V13). Carried only when actually engaged (>1), so a
  # report without it is byte-identical to today. The renderer hides identifying detail
  # (comment demographic tags now, small cells next) whenever the live filtered audience
  # falls below it — set it to the full sample size to forbid any sub-group drill-down.
  mrb <- suppressWarnings(as.numeric(config_obj$min_reporting_base))
  if (length(mrb) == 1L && !is.na(mrb) && mrb > 1) {
    proj$min_reporting_base <- mrb
  }
  # Current wave's order key for the trend axis (twice-yearly / sub-annual
  # trackers). Carried only when config wave_order is set — annual trackers key
  # off the parsed 4-digit year and stay byte-identical. Without it the renderer's
  # current-wave x-key re-parses the year, so a 2025 H2 point collides with the
  # 2025 H1 wave (which the published history already keys as 2025).
  wo <- suppressWarnings(as.numeric(config_obj$wave_order))
  if (length(wo) == 1L && !is.na(wo)) {
    proj$wave_order <- wo
  }
  # Display precision (config DECIMAL PLACES). The crosstab rounds to these for
  # display and tests on the underlying counts; the renderer must use the SAME
  # places or a tab can show a figure — or a wave-on-wave change — that the
  # published table cannot reproduce. Significance is unaffected: it never reads
  # these. Defaults match the config template, so an older config is unchanged.
  dp <- function(key, fallback) {
    v <- suppressWarnings(as.numeric(config_obj[[key]]))
    if (length(v) == 1L && !is.na(v) && v >= 0 && v <= 4) v else fallback
  }
  proj$format <- list(
    percent_decimals = dp("decimal_places_percent", 0),
    rating_decimals  = dp("decimal_places_ratings", 1),
    index_decimals   = dp("decimal_places_index", 1)
  )

  # Tab-visibility flags (V12). Crosstabs is always shown; tabList() filters the
  # rest against these. Defaults TRUE so existing reports are unchanged; a tab
  # still self-hides when its island is absent (e.g. Qualitative without DATA_QUAL).
  proj$tabs <- list(
    dashboard   = isTRUE(config_obj$show_dashboard %||% TRUE),
    patterns    = isTRUE(config_obj$show_patterns %||% TRUE),
    differences = isTRUE(config_obj$show_differences %||% TRUE),
    tracking    = isTRUE(config_obj$show_tracking %||% TRUE),
    qualitative = isTRUE(config_obj$show_qualitative %||% TRUE)
  )
  # Patterns-tab levers (optional; omitted -> engine defaults, byte-identical).
  # patterns_headline -> island field takeout_headline (the JS contract predates
  # the tab's rename): the apex KPI question codes, in the order given.
  # patterns_exclude_banners: banner labels/ids the Patterns scan must skip —
  # operational cuts like Interviewer. I() keeps one-element lists as JSON
  # arrays under auto_unbox (the JS expects arrays).
  ph <- .dl_split_csv(config_obj$patterns_headline)
  if (length(ph) > 0) proj$takeout_headline <- I(ph)
  pxb <- .dl_split_csv(config_obj$patterns_exclude_banners)
  if (length(pxb) > 0) proj$patterns_exclude_banners <- I(pxb)
  # patterns_banner: the POSITIVE selection — the Group overview portrays only
  # the named banner group(s) (label or id; comma-separated for more than one).
  pb <- .dl_split_csv(config_obj$patterns_banner)
  if (length(pb) > 0) proj$patterns_banner <- I(pb)
  # Fieldwork caveat for the "how sure" panel (substitution etc.) — plain text,
  # escaped at render; carried only when non-empty so old islands are unchanged.
  sn <- config_obj$sampling_note
  if (!is.null(sn) && length(sn) >= 1 && !is.na(sn[1]) && nzchar(trimws(sn[1]))) {
    proj$sampling_note <- trimws(as.character(sn[1]))
  }
  # Weighted designs carry a design effect the published data layer doesn't
  # expose per column, so the report's FPC re-letters significance only when
  # unweighted. Carried for the renderer to gate that (intervals are FPC'd
  # regardless). Omitted when FALSE -> unweighted reports unchanged.
  if (isTRUE(config_obj$apply_weighting)) {
    proj$weighted <- TRUE
    # Surface the weighting to the reader (badge + base rows), mirroring the
    # Excel workbook. The per-column weighted/effective bases already ride in
    # each question's `bases` (nWeighted/nEff); these just drive the display.
    wl <- config_obj$weight_label
    if (!is.null(wl) && length(wl) >= 1 && !is.na(wl[1]) && nzchar(trimws(wl[1])))
      proj$weight_label <- as.character(wl[1])
    wv <- config_obj$weight_variable
    if (!is.null(wv) && length(wv) >= 1 && !is.na(wv[1]) && nzchar(trimws(wv[1])))
      proj$weight_variable <- as.character(wv[1])
    # Base-row visibility. The unweighted count always shows in the HTML (it
    # anchors the low-base flag and is the disclosure requirement); the effective
    # base and the weighted base are each toggleable, both defaulting on. Absence
    # of the key -> TRUE, so the weighted base shows unless explicitly dropped.
    proj$show_unweighted_n  <- isTRUE(config_obj$show_unweighted_n)
    proj$show_effective_n   <- isTRUE(config_obj$show_effective_n)
    proj$show_weighted_base <- is.null(config_obj$show_weighted_base) ||
      isTRUE(config_obj$show_weighted_base)
  }
  # Inline researcher / client logos as data URIs when configured; omit (the
  # renderer shows the brand dot) otherwise. researcher_logo_path falls back to
  # the legacy single logo_path.
  researcher <- encode_logo_data_uri(config_obj$researcher_logo_path %||% config_obj$logo_path)
  if (!is.null(researcher)) proj$researcher_logo <- researcher
  client_logo <- encode_logo_data_uri(config_obj$client_logo_path)
  if (!is.null(client_logo)) proj$client_logo <- client_logo

  # Chart colours — carry the configured palette so v2 charts follow the colour
  # scheme instead of a flat brand ramp. The resolved 7-colour
  # palette (chart_palette_preset + any per-sentiment overrides) lets the
  # renderer colour categories semantically (negative -> red, positive -> green);
  # chart_series carries configured banner-series colours for multi-column
  # charts; chart_bar_colour is the single-series bar default. get_palette_colours
  # comes from report_shared.R, sourced alongside the writer — guard so the
  # writer still works without it (the renderer then keeps its brand-shade
  # fallback). Only well-formed hex values are carried so template placeholder
  # text (e.g. "Optional") never reaches the renderer.
  is_hex <- function(x) !blank(x) && grepl("^#?[0-9A-Fa-f]{6}$", trimws(as.character(x)))
  if (exists("get_palette_colours", mode = "function")) {
    preset <- as.character(config_obj$chart_palette_preset %||% "warm")
    pal <- tryCatch(get_palette_colours(preset, overrides = config_obj),
                    error = function(e) NULL)
    if (!is.null(pal) && length(pal) > 0) proj$chart_palette <- pal
  }
  series <- Filter(is_hex, lapply(1:8, function(i) config_obj[[paste0("chart_series_colour_", i)]]))
  if (length(series) > 0) proj$chart_series <- lapply(series, function(v) trimws(as.character(v)))
  if (is_hex(config_obj$chart_bar_colour)) {
    proj$chart_bar_colour <- trimws(as.character(config_obj$chart_bar_colour))
  }

  # Report metadata — pre-fills the v2 Report tab's Background & method,
  # Executive summary and (read-only) About from the config's Comments sheet
  # and closing section. Background/exec stay
  # editable (analyst can refine); the analyst's edits persist. Carried only
  # when at least one field is set.
  cfg_chr <- function(key) {
    if (blank(config_obj[[key]])) "" else as.character(config_obj[[key]])
  }
  meta <- list(
    analyst     = cfg_chr("analyst_name"),
    email       = cfg_chr("analyst_email"),
    phone       = cfg_chr("analyst_phone"),
    company     = cfg_chr("company_name"),
    fieldwork   = cfg_chr("fieldwork_dates"),
    closing     = cfg_chr("closing_notes"),
    verbatim    = cfg_chr("verbatim_filename"),
    background  = cfg_chr("background_text"),
    exec_summary = cfg_chr("executive_summary"),
    # How this study's numbers were actually built (Comments _REPORT_CONSTRUCTION).
    # Stands in place of the About card's default construction sentence, which
    # describes a stock Turas report and cannot know about stages around it.
    construction = cfg_chr("report_construction")
  )
  if (any(nzchar(unlist(meta)))) proj$report_meta <- meta

  # Study slides — exhibits authored in the config's AddedSlides sheet (text
  # blocks, or images resolved and embedded by load_qualitative_sheet). Carried
  # only when the sheet holds usable rows, so a config without one emits a
  # byte-identical island. These are the REPORT AUTHOR's, distinct from the
  # reader's own Added slides, which live in browser state and never come from
  # here — hence read-only in the app, like the narrative sections.
  slides <- Filter(Negate(is.null), lapply(config_obj$qualitative_slides %||% list(),
    function(s) {
      title <- if (blank(s$title)) "" else trimws(as.character(s$title))
      text  <- if (blank(s$content)) "" else trimws(as.character(s$content))
      img   <- if (blank(s$image_data)) "" else as.character(s$image_data)
      # a row with neither words nor a picture is nothing to show
      if (!nzchar(title) && !nzchar(text) && !nzchar(img)) return(NULL)
      out <- list(title = title, text = text)
      if (nzchar(img)) {
        out$image <- img
        # intrinsic pixels, when the format let us read them — the deck export
        # needs them to place the picture without stretching it
        if (!is.null(s$image_w) && !is.null(s$image_h)) {
          out$w <- as.integer(s$image_w)
          out$h <- as.integer(s$image_h)
        }
      }
      out
    }))
  if (length(slides) > 0) proj$slides <- unname(slides)
  proj
}


#' Build the columns[] array of the data layer
#'
#' One entry per banner column (Total first), in banner_info$internal_keys
#' order — the order every row.pct/n/sig array is indexed by.
#'
#' @param banner_info Banner structure from create_banner_structure()
#' @param config_obj Optional config object; when it carries a population_size
#'   and/or Population frame, each column gains a \code{population} field (the
#'   known universe N) used for the finite population correction. Omitted when
#'   no population is configured for that column -> no correction.
#' @return A list of {key, group, label, letter[, population]}
#' @export
build_dl_columns <- function(banner_info, config_obj = NULL) {
  keys    <- banner_info$internal_keys
  letters <- banner_info$letters
  k2d     <- banner_info$key_to_display
  c2b     <- banner_info$column_to_banner

  # Population inputs (all optional). resolve_column_populations() in
  # report_shared.R is the ONE resolver — the significance engine calls it too,
  # so a column's interval and its letters engage the FPC on the same terms.
  frame <- config_obj$population_frame
  col_pops <- resolve_column_populations(banner_info, config_obj)

  # Banner-label map, kept here only for the unmatched-row diagnostic below.
  banner_label_by_code <- list()
  if (!is.null(frame)) {
    groups <- tryCatch(build_banner_groups(banner_info), error = function(e) NULL)
    if (!is.null(groups)) {
      for (lbl in names(groups)) {
        code <- groups[[lbl]]$banner_code
        if (!is.null(code)) banner_label_by_code[[as.character(code)]] <- lbl
      }
    }
  }

  # Collect each non-total column's (banner label, subgroup label) so we can
  # report any Population row that matched no column (a typo / stale label) —
  # otherwise an unmatched group silently gets a standard interval.
  col_idents <- list()

  cols <- lapply(seq_along(keys), function(i) {
    key <- keys[i]
    grp_code <- if (!is.null(c2b) && key %in% names(c2b)) unname(c2b[[key]]) else NA_character_
    is_total <- identical(key, "TOTAL::Total") || identical(grp_code, "TOTAL")
    group <- if (is_total) "total" else if (!is.na(grp_code)) grp_code else "total"
    label <- if (!is.null(k2d) && key %in% names(k2d)) unname(k2d[[key]]) else key
    letter <- ""
    if (!is_total && i <= length(letters)) {
      l <- letters[i]
      if (!is.na(l) && l != "-") letter <- as.character(l)
    }
    entry <- list(key = as.character(key), group = as.character(group),
                  label = as.character(label), letter = letter)
    banner_label <- if (!is_total && !is.na(grp_code)) {
      banner_label_by_code[[as.character(grp_code)]]
    } else {
      NULL
    }
    if (!is_total) {
      col_idents[[length(col_idents) + 1]] <<- list(
        label = label,
        banner = if (is.null(banner_label)) NA_character_ else banner_label)
    }
    # Attach the known population N: the study total for the Total column, the
    # frame match for a banner subgroup. Carried only when found.
    pop <- unname(col_pops[[as.character(key)]])
    if (!is.na(pop) && is.finite(pop) && pop > 1) entry$population <- as.numeric(pop)
    entry
  })

  .warn_unmatched_population(frame, col_idents)
  cols
}


#' Console diagnostic for Population rows that matched no report column
#'
#' Turas runs in Shiny, so a silently-ignored population (typo / stale label)
#' must be visible in the console. Reports how many subgroup rows matched and
#' names any that did not, so the analyst can fix the spelling. No-op when no
#' Population frame is configured.
#'
#' @param frame Population frame (banner/group/population) or NULL
#' @param col_idents List of {label, banner} for the non-total columns
#' @keywords internal
.warn_unmatched_population <- function(frame, col_idents) {
  if (is.null(frame) || nrow(frame) == 0 || length(col_idents) == 0) return(invisible(NULL))
  norm <- function(x) tolower(trimws(as.character(x)))
  col_lab <- vapply(col_idents, function(c) norm(c$label), character(1))
  col_ban <- vapply(col_idents, function(c) norm(c$banner), character(1))
  matched <- logical(nrow(frame))
  for (r in seq_len(nrow(frame))) {
    g <- norm(frame$group[r])
    b <- frame$banner[r]
    hit <- col_lab == g
    if (!is.na(b) && nzchar(trimws(b))) hit <- hit & (col_ban == norm(b))
    matched[r] <- any(hit)
  }
  n_ok <- sum(matched)
  cat(sprintf("  [INFO] Population: matched %d of %d subgroup row(s) to report columns.\n",
              n_ok, nrow(frame)))
  if (any(!matched)) {
    cat("  [WARNING] These Population rows matched NO report column (check spelling",
        "against the banner labels — they keep a standard interval):\n")
    for (r in which(!matched)) {
      ban <- frame$banner[r]
      tag <- if (!is.na(ban) && nzchar(trimws(ban))) sprintf(" [Banner: %s]", ban) else ""
      cat(sprintf("    - \"%s\"%s\n", frame$group[r], tag))
    }
  }
  invisible(NULL)
}


#' Split a comma/semicolon-separated config value into a trimmed character vector
#'
#' For optional list-valued Settings keys (patterns_headline,
#' patterns_exclude_banners). NULL / NA / empty -> character(0), so the caller
#' can omit the island field entirely.
#'
#' @param x Raw config value (single string or NULL)
#' @return Character vector of non-empty trimmed parts
.dl_split_csv <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return(character(0))
  parts <- trimws(strsplit(as.character(x[1]), "[,;]")[[1]])
  parts[nzchar(parts)]
}

#' Build the banner_groups[] array of the data layer
#'
#' @param banner_info Banner structure
#' @return A list of {id, name}
#' @export
build_dl_banner_groups <- function(banner_info) {
  bg <- build_banner_groups(banner_info)
  lapply(names(bg), function(lbl) {
    list(id = as.character(bg[[lbl]]$banner_code), name = as.character(lbl))
  })
}


#' Category label of one result ("" when none)
#' @keywords internal
.dl_cat_label <- function(q) {
  cc <- q$category
  blank <- is.null(cc) || length(cc) < 1 || is.na(cc[1]) ||
    !nzchar(as.character(cc[1]))
  if (blank) "" else as.character(cc[1])
}

#' Unique non-blank categories in the workbook's category order
#'
#' Ordered by the Selection sheet's CategoryOrder (numeric) then
#' first-appearance, like the crosstab workbook (workbook_builder.R).
#' Categories without a CategoryOrder sort after those with one (key = Inf),
#' keeping appearance order — so a config that sets no order is unchanged.
#'
#' @param all_results The tabs results list
#' @return Character vector of category labels, ordered
#' @keywords internal
.dl_category_seq <- function(all_results) {
  codes <- names(all_results)
  cats <- vapply(all_results, .dl_cat_label, character(1))
  uniq <- setdiff(unique(cats), "")
  if (!length(uniq)) return(character(0))
  key <- vapply(uniq, function(cc) {
    raw <- all_results[[codes[match(cc, cats)]]]$category_order
    ord <- suppressWarnings(as.numeric(raw))
    if (length(ord) == 1 && !is.na(ord)) ord else Inf
  }, numeric(1))
  uniq[order(key, seq_along(uniq))]
}

#' Question codes grouped by category, in the workbook's category order
#'
#' Categories ordered by CategoryOrder then appearance; questions keep their
#' within-category (Selection) order; uncategorised questions sort last. This
#' is the order the crosstab workbook uses, so the v2 report groups and starts
#' the same way (e.g. an "Overall metrics" category with CategoryOrder 1 leads).
#'
#' @param all_results The tabs results list
#' @return Character vector of question codes, reordered
#' @keywords internal
.dl_ordered_codes <- function(all_results) {
  codes <- names(all_results)
  cats <- vapply(all_results, .dl_cat_label, character(1))
  grouped <- unlist(lapply(.dl_category_seq(all_results),
                           function(cc) codes[cats == cc]), use.names = FALSE)
  c(grouped, codes[cats == ""])
}

#' Build the categories[] array of the data layer
#'
#' Unique non-blank question categories, in the workbook's category order
#' (CategoryOrder then first-appearance).
#'
#' @param all_results The tabs results list
#' @return A list of category-label strings
#' @export
build_dl_categories <- function(all_results) {
  as.list(.dl_category_seq(all_results))
}


#' Trimmed string from an optional sheet cell, "NA"-safe ("" when unusable)
#'
#' The config/structure loaders can surface an empty Excel cell as NA or as the
#' literal string "NA"; both (and whitespace-only) read as blank. Only the
#' first element of a vector cell is considered.
#'
#' @param x A cell value (any type, possibly NULL / NA / "NA")
#' @return A trimmed non-blank character string, or "" when blank/unusable
#' @keywords internal
.dl_chr_cell <- function(x) {
  if (is.null(x) || length(x) < 1 || is.na(x[1])) return("")
  s <- trimws(as.character(x[1]))
  if (!nzchar(s) || identical(s, "NA")) "" else s
}


#' Find a question's row on the structure workbook's Questions sheet
#'
#' Looks the code up in survey_structure$questions (exact, case-sensitive —
#' the same matching prepare_question_data uses). Source of the optional
#' reader-experience columns (ShortLabel, Scale_Min/Scale_Max,
#' LinkedOpenQuestion).
#'
#' @param code Question code (character)
#' @param survey_structure Loaded structure (needs $questions), or NULL
#' @return A one-row data frame, or NULL when absent/unmatched
#' @keywords internal
.dl_structure_question_row <- function(code, survey_structure) {
  qs <- survey_structure$questions
  if (is.null(qs) || !is.data.frame(qs) || !"QuestionCode" %in% names(qs) ||
      is.null(code) || !nzchar(code)) {
    return(NULL)
  }
  hit <- qs[!is.na(qs$QuestionCode) & qs$QuestionCode == code, , drop = FALSE]
  if (nrow(hit) == 0) NULL else hit[1, , drop = FALSE]
}


#' Build one questions[] entry from a tabs question result
#'
#' Pivots the long-format result table into wide pct/n/sig arrays (one cell per
#' banner column, in internal_keys order) and the bases[] array.
#'
#' @param q_result A single element of all_results
#' @param banner_info Banner structure (supplies the column order)
#' @param config_obj The tabs config object
#' @param low_base Numeric low-base threshold
#' @param survey_structure Optional structure; when supplied, scale/NPS questions
#'   carry index_scores so means recompute live under filters / custom banners
#' @return A question list, or NULL if the result has no usable table
#' @export
build_dl_question <- function(q_result, banner_info, config_obj, low_base,
                              survey_structure = NULL) {
  table <- q_result$table
  if (is.null(table) || !is.data.frame(table) || nrow(table) == 0) return(NULL)
  if (!all(c("RowLabel", "RowType") %in% names(table))) return(NULL)

  table <- normalize_question_table(table)
  stats <- detect_available_stats(table)
  cls   <- classify_row_labels(table, q_result$question_type)
  keys  <- banner_info$internal_keys

  # The quantity that lands in each row's `pct` array. A config that turns the
  # column percentage off (show_percent_column = N) puts ROW percentages or raw
  # FREQUENCIES there instead — the island used to carry no field naming it, so
  # the v2 renderer labelled every one of them "%" and a counts-only table
  # shipped "142%" (review 2026-08, C1). `stat` travels with the values so the
  # renderer, the exports and the Patterns scan know what they are holding.
  primary_stat <- if (stats$has_col_pct) "Column %"
                  else if (stats$has_row_pct) "Row %"
                  else if (stats$has_freq) "Frequency"
                  else if (stats$has_mean) "Average"
                  else "Frequency"

  base_types <- c("Base (n=)", "Base", "Base (n)",
                  "Unweighted Base", "Weighted Base", "Effective Base")
  # Median and Mode belong here with the other summary statistics. Without them
  # a numeric question's Median row was COMPUTED (numeric_processor honours
  # show_numeric_median), written to the workbook, and then silently dropped on
  # the way into the v2 report: the "mean" branch below does `next` when a row's
  # RowType is absent from this list. The Excel and the interactive report
  # disagreed, with no warning either way.
  mean_types <- c("Average", "Index", "Score", "Std Dev", "StdDev", "ChiSquare",
                  "Median", "Mode", "RatioMean")

  # RowType -> what the reader must recompute for this row under a filter.
  # "mean" is the headline statistic (Average / Index / Score); the rest each
  # need their own recompute and must never fall back to the mean.
  mean_stat_of <- function(row_type) {
    switch(row_type,
      "Median" = "median", "Mode" = "mode",
      "Std Dev" = "sd", "StdDev" = "sd",
      "RatioMean" = "ratio", "ChiSquare" = "chi",
      "mean")
  }

  # Rows are keyed by (RowLabel, RowSource) — NOT label alone — so a
  # BoxCategory NET sharing its label with a displayed option (e.g. box
  # "Satisfied" grouping options that include "Satisfied") keeps BOTH rows.
  # Unique labels collapsed the pair and silently dropped the NET row from the
  # v2 report. Tables without RowSource have one "" source per label, so their
  # iteration order and output are unchanged.
  row_src <- if ("RowSource" %in% names(table)) {
    s <- trimws(as.character(table$RowSource))
    ifelse(is.na(s), "", s)
  } else {
    rep("", nrow(table))
  }

  # Numeric values for (label, source, RowType) across every column, NA where absent
  vals_for <- function(lbl, src, rtype) {
    sel <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                 table$RowLabel == lbl & row_src == src &
                 table$RowType == rtype, , drop = FALSE]
    vapply(keys, function(k) {
      if (nrow(sel) > 0 && k %in% names(table)) {
        suppressWarnings(as.numeric(sel[1, k]))
      } else NA_real_
    }, numeric(1), USE.NAMES = FALSE)
  }
  # The letters of one Sig-style row, cell by cell. "-" (the Total column's
  # placeholder) reads as "no letters" in the island.
  sig_cells <- function(sel) {
    vapply(keys, function(k) {
      if (nrow(sel) > 0 && k %in% names(table)) {
        v <- as.character(sel[1, k])
        if (is.na(v) || v == "" || v == "-") "" else v
      } else ""
    }, character(1), USE.NAMES = FALSE)
  }
  # sig_type is "Sig." (primary) or "Sig.2" (secondary, dual-alpha runs only).
  sig_for <- function(lbl, src, sig_type = "Sig.") {
    sig_cells(table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                    table$RowLabel == lbl & row_src == src &
                    table$RowType == sig_type, , drop = FALSE])
  }
  # Which letters belong to a MEAN-kind row.
  #
  # A "summary" block (standard_processor / numeric_processor) is emitted as the
  # headline statistic (Average | Index | Score), THEN Median / Mode / Std Dev /
  # Outliers, THEN its Sig. row — so normalize_question_table's forward-fill
  # labels that Sig. row with whichever descriptive row came last. Matching on
  # label alone would hang the mean's letters on Std Dev, which is never tested.
  # The block's sig row tests the headline statistic, so it goes there and
  # nowhere else. Composite blocks put their sig row directly under the row it
  # tests, so they still match on label.
  mean_sig_for <- function(lbl, src, rtype, sig_type = "Sig.") {
    if (identical(src, "summary")) {
      if (!rtype %in% c("Average", "Index", "Score")) return(rep("", length(keys)))
      sel <- table[!is.na(table$RowType) & row_src == "summary" &
                   table$RowType == sig_type, , drop = FALSE]
      # One sig row per summary block: it tests the headline statistic, so it
      # goes to the mean regardless of which descriptive row the forward-fill
      # labelled it with.
      if (nrow(sel) == 1) return(sig_cells(sel))
      # SEVERAL sig rows means several mean blocks in one table — an Allocation
      # question emits one Average row per option, each with its own Sig. row.
      # This used to return nothing, so a multi-option allocation showed letters
      # in the Excel workbook and none in the report: the same Excel/report
      # disagreement the D1 work removed for numeric questions (review
      # 2026-08-21, I-5). Here the forward-filled label IS the discriminator —
      # each Sig. row inherits its own Average row's label — so match on it.
      if (nrow(sel) > 1) return(sig_for(lbl, src, sig_type))
      return(rep("", length(keys)))
    }
    sig_for(lbl, src, sig_type)
  }
  null_vec  <- function() as.list(rep(NA_real_, length(keys)))  # serialises to [null,...]
  empty_sig <- function() as.list(rep("", length(keys)))

  # RowSource -> row class, mirroring classify_row_labels' primary branch; NA
  # when the source is blank/unknown (fall back to the per-label classifier,
  # whose first-source-wins answer is only ambiguous for label collisions).
  src_class <- function(src) {
    if (!nzchar(src)) return(NA_character_)
    if (src %in% c("individual", "ranking")) return("category")
    if (src %in% c("boxcategory", "net_positive")) return("net")
    if (src %in% c("summary", "chi_square", "composite", "ranking_mean")) return("mean")
    NA_character_
  }

  keep_rows <- !is.na(table$RowLabel) & nzchar(table$RowLabel)
  pair_ids  <- paste(table$RowLabel, row_src, sep = "\r")
  ord_idx   <- which(keep_rows & !duplicated(pair_ids))

  rows <- list()
  metric_type <- NA_character_   # the headline summary-stat kind, if any
  for (ri in ord_idx) {
    lbl <- table$RowLabel[ri]
    src <- row_src[ri]
    lbl_types <- unique(table$RowType[!is.na(table$RowLabel) &
                                      table$RowLabel == lbl & row_src == src])
    # Base rows are carried by bases[] — skip them here
    if (length(lbl_types) > 0 && all(lbl_types %in% base_types)) next

    cl <- src_class(src)
    if (is.na(cl)) cl <- cls[[lbl]]
    if (is.null(cl) || is.na(cl)) cl <- "category"

    if (cl == "mean") {
      mrt <- intersect(lbl_types, mean_types)
      if (length(mrt) == 0) next
      if (is.na(metric_type) && mrt[1] %in% c("Average", "Mean", "Index", "Score")) {
        metric_type <- mrt[1]
      }
      # Mean rows carry R's letters like every other row (D1: the R engine is
      # the source of truth for every published statistic). Before this they
      # carried none, so the published view showed a bare Average while the
      # workbook lettered it — and the 80% set-difference below would have read
      # a 95% result as an 80%-only one.
      # WHICH statistic this mean-kind row is. Without it the reader had only
      # the label to go on, and recognised nothing but "Standard Deviation" —
      # so under a filter every Median row silently redisplayed the recomputed
      # MEAN (electricity: median R310 published, R563.68 shown to anyone who
      # filtered to men, whose real median is R300). Row TYPE decides now.
      mrow <- list(
        kind = "mean", label = lbl, mstat = mean_stat_of(mrt[1]),
        pct = as.list(vals_for(lbl, src, mrt[1])), n = null_vec(),
        sig = if (stats$has_sig) as.list(mean_sig_for(lbl, src, mrt[1])) else empty_sig())
      if (stats$has_sig2) {
        mrow$sig2 <- as.list(mean_sig_for(lbl, src, mrt[1], "Sig.2"))
      }
      rows[[length(rows) + 1]] <- mrow
    } else {
      pr <- vals_for(lbl, src, primary_stat)
      # A row absent from the question's primary statistic substitutes another
      # one — so a single row can hold a different quantity from its neighbours
      # (a Frequency-only row sitting among column percentages). Record which,
      # so the renderer labels THAT row for what it is instead of printing a
      # count with a percent sign beside real percentages (C1).
      row_stat <- primary_stat
      if (all(is.na(pr))) {
        for (fb in c("Column %", "Row %", "Frequency")) {
          if (fb == primary_stat) next
          alt <- vals_for(lbl, src, fb)
          if (!all(is.na(alt))) { pr <- alt; row_stat <- fb; break }
        }
      }
      kind <- if (cl == "net") "net" else "category"
      # Box-category rows (e.g. "Good (9 - 10)", "Top 2 Box") carry a real
      # Frequency in the source, so the "Counts" toggle shows n= for them.
      # Only a true "NET POSITIVE" row is a percentage-point
      # difference, not a count — it keeps a null n, matching the renderer's
      # computed path which also nulls that row's n.
      is_net_diff <- kind == "net" && grepl("^NET POSITIVE", lbl, ignore.case = TRUE)
      crow <- list(
        kind = kind, label = lbl,
        pct = as.list(pr),
        n   = if (is_net_diff) null_vec() else as.list(vals_for(lbl, src, "Frequency")),
        sig = if (stats$has_sig) as.list(sig_for(lbl, src)) else empty_sig())
      # Dual-alpha runs carry the Sig.2 row verbatim so the published view shows
      # R's 80% letters instead of recomputing them from the 0dp-rounded counts
      # (D4). Absent on single-alpha runs -> byte-identical island.
      if (stats$has_sig2) crow$sig2 <- as.list(sig_for(lbl, src, "Sig.2"))
      # Emitted only when this row differs from the question's own statistic, so
      # an ordinary column-% report stays byte-identical.
      if (!identical(row_stat, primary_stat)) crow$stat <- row_stat
      rows[[length(rows) + 1]] <- crow
    }
  }

  # Weighted designs: the published cell counts are WEIGHTED but the base row shows the
  # UNWEIGHTED n, so the renderer must recompute proportions on the weighted base and size
  # significance/intervals on the Kish effective base. Carry both alongside the unweighted n
  # (which still drives display + the low-base flag). Omitted for unweighted -> byte-identical.
  weighted_report <- isTRUE(config_obj$apply_weighting)
  bases <- lapply(keys, function(k) {
    bn <- NA_real_; bw <- NA_real_; be <- NA_real_
    if (!is.null(q_result$bases) && k %in% names(q_result$bases)) {
      bk <- q_result$bases[[k]]
      u <- bk$unweighted
      if (!is.null(u) && length(u) >= 1) bn <- suppressWarnings(as.numeric(u[1]))
      if (weighted_report) {
        w <- bk$weighted
        if (!is.null(w) && length(w) >= 1) bw <- suppressWarnings(as.numeric(w[1]))
        e <- bk$effective
        if (!is.null(e) && length(e) >= 1) be <- suppressWarnings(as.numeric(e[1]))
      }
    }
    entry <- list(n = bn, low = is.na(bn) || bn < low_base)
    if (weighted_report && !is.na(bw) && bw > 0) entry$nWeighted <- bw
    if (weighted_report && !is.na(be) && be > 0) entry$nEff <- be
    entry
  })

  cat_val <- q_result$category
  cat_val <- if (is.null(cat_val) || length(cat_val) == 0 || is.na(cat_val[1])) ""
             else as.character(cat_val[1])

  # Theme = optional Level-2 grouping (under Category/Section) for the Executive
  # Takeout patterns view. "" when untagged; the JS falls back to the section.
  theme_val <- q_result$theme
  theme_val <- if (is.null(theme_val) || length(theme_val) == 0 || is.na(theme_val[1])) ""
               else as.character(theme_val[1])

  # KeyShare = the analyst-declared favourable share for the Patterns scan
  # (Selection sheet column; see question_orchestrator.R). "" when undeclared —
  # the JS then leaves the question out of the scan.
  key_share_val <- q_result$key_share
  key_share_val <- if (is.null(key_share_val) || length(key_share_val) == 0 || is.na(key_share_val[1])) ""
                   else as.character(key_share_val[1])

  # Source / Formula = the question's provenance (Selection sheet). Source names
  # where the numbers came from, Formula how a derived one was worked out. Both
  # "" when the analyst declared neither.
  source_val <- q_result$source
  source_val <- if (is.null(source_val) || length(source_val) == 0 || is.na(source_val[1])) ""
                else trimws(as.character(source_val[1]))
  formula_val <- q_result$formula
  formula_val <- if (is.null(formula_val) || length(formula_val) == 0 || is.na(formula_val[1])) ""
                 else trimws(as.character(formula_val[1]))

  # BaseFilter / FilterLabel = the question's own audience (Selection sheet).
  # A routed question ("asked only of shops that allow signwriting") reports a
  # smaller base than the survey total, and the base on its own never says WHY
  # — so the analyst's label travels with the question and the card states the
  # audience next to the n. FilterLabel wins when both are set; the raw filter
  # expression is the fallback (the same rule the Excel workbook applies).
  # A label with no BaseFilter is legitimate: the routing happened in the
  # questionnaire, so the data arrives already restricted.
  filter_label_val <- q_result$filter_label
  filter_label_val <- if (is.null(filter_label_val) || length(filter_label_val) == 0 ||
                          is.na(filter_label_val[1])) ""
                      else trimws(as.character(filter_label_val[1]))
  base_filter_val <- q_result$base_filter
  base_filter_val <- if (is.null(base_filter_val) || length(base_filter_val) == 0 ||
                         is.na(base_filter_val[1])) ""
                     else trimws(as.character(base_filter_val[1]))

  q_type_v2 <- map_question_type(q_result$question_type)

  # Scale maximum for the dashboard gauge/heatmap ("% of each scale's
  # maximum"). Without it the renderer assumes 100, so a 0-10 mean reads as
  # ~7% and every card shows weak/red. Sourced from the project's configured
  # scale (dashboard_scale_mean / dashboard_scale_index). NA -> null for
  # questions with no summary-stat row (they are not on the dashboard).
  # scale_max feeds the gauge/heatmap normalisation; gauge_green/gauge_amber
  # are the project's configured colour thresholds (raw values, e.g. >=7
  # green / >=5 amber).
  #
  # Only rated touchpoints (scale / nps) get a scale_max. A Numeric open-count
  # (e.g. "how many hours did you lose?") carries a Mean row but has no scale
  # maximum, so colour-banding it as a "% of 10" is meaningless and direction-
  # blind (9 hours lost would read strong/green). Leaving these NA also makes
  # the renderer's indexQuestions() filter exclude them from the dashboard.
  scale_max <- NA_real_
  gauge_green <- NA_real_
  gauge_amber <- NA_real_
  is_composite <- identical(as.character(q_result$question_type %||% ""), "Composite")
  if (!is.na(metric_type) && q_type_v2 %in% c("scale", "nps")) {
    if (metric_type == "Index") {
      scale_max   <- as.numeric(config_obj$dashboard_scale_index %||% 10)
      gauge_green <- as.numeric(config_obj$dashboard_green_index %||% 7)
      gauge_amber <- as.numeric(config_obj$dashboard_amber_index %||% 5)
    } else if (metric_type == "Score") {
      scale_max <- 100   # NPS-style; no configured raw thresholds -> % fallback
    } else {
      scale_max   <- as.numeric(config_obj$dashboard_scale_mean %||% 10)
      gauge_green <- as.numeric(config_obj$dashboard_green_mean %||% 7)
      gauge_amber <- as.numeric(config_obj$dashboard_amber_mean %||% 5)
    }
  } else if (is_composite) {
    # A composite index (e.g. Q_Engage / Q_Value) is the mean of rated items, so
    # it sits on the project's rating scale — but it maps to type "single" and so
    # skips the block above. Give it the index scale_max + thresholds so it
    # appears AND colours on the dashboard like the touchpoints it summarises.
    scale_max   <- as.numeric(config_obj$dashboard_scale_index %||% config_obj$dashboard_scale_mean %||% 10)
    gauge_green <- as.numeric(config_obj$dashboard_green_index %||% config_obj$dashboard_green_mean %||% 7)
    gauge_amber <- as.numeric(config_obj$dashboard_amber_index %||% config_obj$dashboard_amber_mean %||% 5)
  }

  # index_scores (display label -> numeric score) lets the renderer recompute
  # means/NPS from microdata under a live filter or custom banner. Omitted
  # (NULL -> absent in JSON) when the structure is not supplied or the type
  # carries no per-option score — the published mean still shows unfiltered.
  index_scores <- derive_index_scores(q_result, survey_structure)
  # net_diffs (NET POSITIVE = favourable box - unfavourable box) lets that row
  # recompute too; box NET rows recompute from per-respondent box membership
  # (TR.MICRO.boxes). Box scores fix the diff direction for best-first scales.
  net_diffs <- derive_net_diffs(rows, derive_box_scores(q_result, survey_structure))

  out <- list(
    code        = as.character(q_result$question_code %||% ""),
    title       = as.character(q_result$question_text %||% ""),
    category    = cat_val,
    theme       = theme_val,
    key_share   = key_share_val,
    type        = q_type_v2,
    bases       = bases,
    rows        = rows,
    scale_max   = scale_max,
    gauge_green = gauge_green,
    gauge_amber = gauge_amber
  )
  # What the rows' `pct` arrays actually hold. Emitted only when it is NOT the
  # column percentage (the overwhelming default), so every report built from an
  # ordinary config is byte-identical and the reader defaults to "Column %".
  if (!identical(primary_stat, "Column %")) out$stat <- primary_stat
  if (!is.null(index_scores)) out$index_scores <- index_scores
  if (!is.null(net_diffs)) out$net_diffs <- net_diffs
  # The two data columns behind a ratio-of-totals row, so the reader can
  # re-total them over whoever is in the audience. Both are questions in their
  # own right, so their per-respondent scores are already in the island.
  if (!is.null(q_result$ratio)) out$ratio <- q_result$ratio
  # AreaSummary: the question that summarises its area/theme (Patterns tab).
  # Emitted only when TRUE so untagged configs stay byte-identical.
  if (isTRUE(q_result$area_summary)) out$area_summary <- TRUE

  # Composite index (e.g. Q_Engage = the mean of the twelve engagement items).
  # A composite now carries per-respondent scores in the microdata island like
  # any rated question, so it recomputes live and can be tracked across waves —
  # but it is the AVERAGE of questions that are themselves in the report, so the
  # Patterns families that scan every rated question must skip it or it competes
  # with its own components. The renderer cannot tell a composite from an
  # ordinary "single" by type alone, so it is flagged here. Emitted only when
  # TRUE, so a study with no composites produces byte-identical output.
  if (is_composite) out$composite <- TRUE

  # Audience note: emitted only when the analyst set one, so a config with
  # neither column produces byte-identical output.
  if (nzchar(filter_label_val)) out$filter_label <- filter_label_val
  if (nzchar(base_filter_val)) out$base_filter <- base_filter_val

  # Provenance: same rule — a config without the columns produces byte-identical
  # output, so only a study that declares where its numbers come from gets the
  # source note on its cards.
  if (nzchar(source_val)) out$source <- source_val
  if (nzchar(formula_val)) out$formula <- formula_val

  # Reader-experience source fields (READER_EXPERIENCE_PLAN.md §E). All are
  # OPTIONAL columns on the structure workbook's Questions sheet; each key is
  # emitted only when its cell is usable, so a config without the columns
  # produces byte-identical output.
  #
  # [[ ]] not $: srow is a tibble, and $ on a tibble column that does not exist
  # warns ("Unknown or uninitialised column"). Harmless — .dl_chr_cell() treats
  # NULL as absent — but it fired once per optional column per question, which
  # was 150 of the tabs suite's warnings and exactly the noise that buries a
  # real one (review 2026-08-21, M-19).
  srow <- .dl_structure_question_row(out$code, survey_structure)
  if (!is.null(srow)) {
    # E/A2: analyst-authored short label for tight surfaces (cards, chart and
    # PPTX titles) — replaces mid-word auto-truncation of the question text.
    sl <- .dl_chr_cell(srow[["ShortLabel"]])
    if (nzchar(sl)) out$short_label <- sl

    # E: explicit scale bounds — remove scale inference; feed bands, index
    # maths and chart axes. Only honoured when BOTH parse as numbers and
    # min < max; a half-filled or inverted pair is ignored (inference stands).
    smin <- suppressWarnings(as.numeric(.dl_chr_cell(srow[["Scale_Min"]])))
    smax <- suppressWarnings(as.numeric(.dl_chr_cell(srow[["Scale_Max"]])))
    if (length(smin) == 1L && length(smax) == 1L &&
        !is.na(smin) && !is.na(smax) && smin < smax) {
      out$scale_min <- smin
      out$scale_max <- smax   # explicit declaration overrides the inferred max
    }

    # E/C2: declared closed->open question link (the open-end that explains
    # this closed question). Emitted here; build_data_layer() validates the
    # target against the run and drops it — with a console NOTE — when broken.
    lo <- .dl_chr_cell(srow[["LinkedOpenQuestion"]])
    if (nzchar(lo)) out$linked_open <- lo
  }

  # E/B3: per-question analyst headline (Comments sheet's optional Headline
  # column, carried as the "headlines" attribute by load_comments_sheet).
  headlines <- attr(config_obj$comments, "headlines", exact = TRUE)
  if (!is.null(headlines) && nzchar(out$code)) {
    hl <- .dl_chr_cell(headlines[[out$code]])
    if (nzchar(hl)) out$headline <- hl
  }

  out
}


#' Per-question analyst comments from the config's Comments sheet
#'
#' Keyed by question code; each value a list of \code{{banner, text}} entries
#' (banner NA = general, serialises to JSON null). These pre-fill the v2
#' report's per-question insight box; the analyst's own edits in the report
#' override them. Returns NULL when no
#' comments are configured, so the key is omitted and existing reports are
#' byte-identical.
#'
#' @param config_obj Configuration object (config_obj$comments)
#' @return Named list keyed by question code, or NULL
#' @keywords internal
build_dl_comments <- function(config_obj) {
  cm <- config_obj$comments
  if (is.null(cm) || length(cm) == 0) return(NULL)
  out <- list()
  for (code in names(cm)) {
    entries <- cm[[code]]
    if (is.null(entries) || length(entries) == 0) next
    clean <- list()
    for (e in entries) {
      txt <- if (is.null(e$text)) "" else trimws(as.character(e$text))
      if (!nzchar(txt) || identical(txt, "NA")) next
      banner_blank <- is.null(e$banner) ||
        (length(e$banner) == 1 && is.na(e$banner))
      bn <- if (banner_blank) NA_character_ else as.character(e$banner)
      clean[[length(clean) + 1]] <- list(banner = bn, text = txt)
    }
    if (length(clean)) out[[code]] <- clean
  }
  if (length(out)) out else NULL
}


#' Human-readable AI model attribution for the methodology note
#'
#' Mirrors get_model_display_name() in modules/shared/lib/ai/ai_provider.R, kept
#' inline so the data layer carries no dependency on the AI modules being
#' sourced. Known model IDs get a friendly name; others show verbatim.
#'
#' @param cfg The AI sidecar's `config` list (model + provider)
#' @return Character display string, e.g. "Claude Sonnet 4.6 (Anthropic)"
#' @keywords internal
.dl_ai_model_display <- function(cfg) {
  model    <- cfg$model %||% "AI model"
  provider <- cfg$provider %||% "anthropic"
  pretty <- list(
    "claude-sonnet-4-6" = "Claude Sonnet 4.6",
    "claude-opus-4-8"   = "Claude Opus 4.8"
  )[[model]]
  if (!is.null(pretty)) model <- pretty
  label <- list(
    anthropic = "Anthropic", openai = "OpenAI",
    google = "Google", ollama = "Ollama (local)"
  )[[provider]] %||% provider
  sprintf("%s (%s)", model, label)
}


#' Per-question AI insights from the AI sidecar (file I/O)
#'
#' Reads the AI insights JSON sidecar the run refreshes before this point
#' (generate_ai_insights_sidecar in ai_insights_step.R)
#' (\code{<config>_ai_insights.json}) and shapes it for the v2 data layer: the
#' per-question callouts the model flagged as noteworthy, the executive summary,
#' and a human-readable model attribution. Returns NULL when AI insights are
#' disabled, the sidecar is absent/unreadable, or nothing noteworthy exists — so
#' the \code{ai} key is omitted and AI-free reports stay byte-identical.
#'
#' This helper performs file I/O and therefore lives OUTSIDE the pure
#' build_data_layer(); callers read it once and pass the result via \code{ai}.
#'
#' @param config_obj Configuration object (needs enable_ai_insights +
#'   config_file_path)
#' @return A list \code{{model, callouts, execSummary}} or NULL
#' @keywords internal
build_dl_ai <- function(config_obj) {
  if (!isTRUE(config_obj$enable_ai_insights)) return(NULL)
  cfp <- config_obj$config_file_path %||% ""
  if (!nzchar(cfp)) return(NULL)
  sidecar_path <- paste0(tools::file_path_sans_ext(cfp), "_ai_insights.json")
  if (!file.exists(sidecar_path)) return(NULL)

  sc <- tryCatch(
    jsonlite::fromJSON(paste(readLines(sidecar_path, warn = FALSE), collapse = "\n"),
                       simplifyVector = FALSE),
    error = function(e) NULL)
  if (is.null(sc) || !isTRUE(sc$config$enabled)) return(NULL)

  blank <- function(x) {
    v <- trimws(as.character(x %||% ""))
    !nzchar(v) || identical(v, "NA")
  }

  # Per-question callouts — only those the model flagged as noteworthy.
  callouts <- list()
  qs <- sc$questions %||% list()
  for (code in names(qs)) {
    co <- qs[[code]]$ai_callout
    if (is.null(co) || !isTRUE(co$has_insight) || blank(co$narrative)) next
    conf  <- co$confidence %||% "high"
    entry <- list(text = trimws(as.character(co$narrative)), confidence = conf)
    if (!blank(co$data_limitations) && conf %in% c("medium", "low")) {
      entry$caveat <- trimws(as.character(co$data_limitations))
    }
    callouts[[code]] <- entry
  }

  # Executive summary (carry the verified flag so the renderer can label drafts).
  exec <- NULL
  es <- sc$executive_summary
  if (!is.null(es) && !blank(es$narrative)) {
    exec <- list(text = trimws(as.character(es$narrative)), verified = isTRUE(es$verified))
  }

  if (length(callouts) == 0L && is.null(exec)) return(NULL)

  out <- list(model = .dl_ai_model_display(sc$config))
  if (length(callouts) > 0L) out$callouts <- callouts
  if (!is.null(exec)) out$execSummary <- exec
  out
}


#' Build the complete data-agg structure (pure — no file I/O)
#'
#' @param all_results List of question results
#' @param banner_info Banner structure
#' @param config_obj Configuration object
#' @param survey_structure Optional structure; threaded to build_dl_question so
#'   scale/NPS questions carry index_scores for live mean recompute
#' @param tracking_enabled Logical; sets project.tracking.enabled (the Tracking
#'   tab also requires a prior-wave island to actually appear)
#' @param ai Optional AI insights structure from build_dl_ai() (callouts +
#'   executive summary + model attribution). NULL omits the \code{ai} key.
#' @return A list mirroring the data-agg JSON shape
#' @export
build_data_layer <- function(all_results, banner_info, config_obj,
                             survey_structure = NULL, tracking_enabled = FALSE,
                             ai = NULL) {
  project <- build_dl_project(config_obj, tracking_enabled = tracking_enabled)
  low_base <- project$low_base_threshold

  # Group questions by category (CategoryOrder then appearance) so the v2
  # report groups by the same sections the workbook does.
  questions <- list()
  for (q_code in .dl_ordered_codes(all_results)) {
    q <- build_dl_question(all_results[[q_code]], banner_info, config_obj, low_base,
                           survey_structure)
    if (!is.null(q)) {
      questions[[length(questions) + 1]] <- q
    } else {
      # A malformed/empty table must not vanish silently: the Excel workbook
      # still carries this question, so an unnamed skip here ships an HTML
      # report that quietly disagrees with it (review 2026-08, I15).
      cat(sprintf(paste0(
        "  [NOTE] Question %s: results table is missing or malformed - ",
        "omitted from the v2 report (the Excel workbook may still carry it).\n"),
        q_code))
    }
  }
  questions <- .validate_linked_open(questions, all_results, survey_structure)

  columns <- .validate_column_populations(
    build_dl_columns(banner_info, config_obj), questions
  )

  dl <- list(
    schema_version = 2L,
    project        = project,
    columns        = columns,
    banner_groups  = build_dl_banner_groups(banner_info),
    categories     = build_dl_categories(all_results),
    questions      = questions
  )
  # Per-question analyst comments (config Comments sheet) pre-fill the report's
  # insight boxes. Omitted entirely when none are configured.
  comments <- build_dl_comments(config_obj)
  if (!is.null(comments)) dl$comments <- comments

  # AI callouts + executive summary (read from the AI sidecar by the caller and
  # passed in). Omitted entirely when AI insights are off or nothing surfaced.
  if (!is.null(ai)) dl$ai <- ai
  dl
}


#' Validate declared closed->open question links against the run
#'
#' A LinkedOpenQuestion must name a question that exists in this run — either a
#' processed question (all_results) or one defined on the structure workbook's
#' Questions sheet (open-ends are typically defined there but not crosstabbed).
#' A broken code is reported with a console NOTE — never silently, Turas runs
#' under Shiny — and the \code{linked_open} key is dropped for that question.
#' Questions without the field pass through untouched (byte-identical).
#'
#' @param questions Question list from build_dl_question()
#' @param all_results The tabs results list (processed question codes)
#' @param survey_structure Loaded structure (needs $questions), or NULL
#' @return The question list, with broken links removed
#' @keywords internal
.validate_linked_open <- function(questions, all_results, survey_structure) {
  if (!length(questions)) return(questions)
  known <- names(all_results) %||% character(0)
  qs <- survey_structure$questions
  if (!is.null(qs) && is.data.frame(qs) && "QuestionCode" %in% names(qs)) {
    known <- union(known, as.character(qs$QuestionCode[!is.na(qs$QuestionCode)]))
  }
  for (i in seq_along(questions)) {
    lo <- questions[[i]]$linked_open
    if (is.null(lo)) next
    if (!(lo %in% known)) {
      cat(sprintf(paste0(
        "  [NOTE] Question %s: LinkedOpenQuestion \"%s\" does not match any question ",
        "in this run — link omitted. Check the code against the Questions sheet.\n"),
        questions[[i]]$code, lo))
      questions[[i]]$linked_open <- NULL
    }
  }
  questions
}


#' Drop any column population smaller than the column's achieved base
#'
#' A configured universe N below the responding n is impossible (you cannot
#' interview more people than exist) and, carried through, renders zero-width
#' intervals, a clamped "100% of N" coverage note beside a visibly larger
#' base, and broken significance letters. The population is dropped for that
#' column (standard intervals apply) and the problem is reported loudly on
#' the console — Turas runs under Shiny, so silence would hide it.
#'
#' @param columns Column list from build_dl_columns()
#' @param questions Question list from build_dl_question() (bases per column)
#' @return The column list, with impossible populations removed
#' @keywords internal
.validate_column_populations <- function(columns, questions) {
  if (!length(columns) || !length(questions)) return(columns)
  for (i in seq_along(columns)) {
    pop <- columns[[i]]$population
    if (is.null(pop)) next
    achieved <- 0
    for (q in questions) {
      bn <- tryCatch(q$bases[[i]]$n, error = function(e) NULL)
      if (!is.null(bn) && length(bn) == 1L && is.finite(bn) && bn > achieved) {
        achieved <- bn
      }
    }
    if (achieved > pop) {
      cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
      cat("│ Code: CFG_POPULATION_BELOW_BASE\n")
      cat(sprintf("│ Column: %s\n", columns[[i]]$label))
      cat(sprintf(
        "│ Configured population N = %s is SMALLER than the achieved\n│ base n = %s — impossible, so the finite population\n",
        format(pop, big.mark = ","), format(achieved, big.mark = ",")
      ))
      cat("│ correction is DISABLED for this column (standard intervals).\n")
      cat("│ Fix population_size / the Population sheet and re-run.\n")
      cat("└───────────────────────────────────────────────────────┘\n\n")
      columns[[i]]$population <- NULL
    }
  }
  columns
}


#' Serialise a data-layer list to the JSON string the renderer reads
#'
#' Arrays are preserved (never unboxed); NA cells become JSON null.
#'
#' @param data_layer A list from build_data_layer()
#' @return A single JSON string
#' @export
serialize_data_layer <- function(data_layer) {
  jsonlite::toJSON(data_layer, auto_unbox = TRUE, na = "null",
                   null = "null", digits = 6, pretty = FALSE)
}


#' Write the data-layer JSON island for the v2 renderer
#'
#' @param all_results List of question results from the tabs run
#' @param banner_info Banner structure from create_banner_structure()
#' @param config_obj Configuration object
#' @param output_path Destination .json path
#' @param survey_structure Optional survey structure (reserved; unused in v1)
#'
#' @return A list with structure:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{output_file}{Path written (if PASS)}
#'   \item{file_size_mb}{Size of the written file (if PASS)}
#'   \item{n_questions}{Number of questions emitted (if PASS)}
#'
#' @examples
#' \dontrun{
#'   res <- write_data_layer(all_results, banner_info, config_obj, "report_data.json")
#'   if (res$status == "PASS") message("wrote ", res$output_file)
#' }
#' @export
write_data_layer <- function(all_results, banner_info, config_obj,
                             output_path, survey_structure = NULL) {

  refuse <- function(code, message, how_to_fix) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", code, "\n")
    cat("Message:", message, "\n")
    cat("Fix:", how_to_fix, "\n")
    cat("==================\n\n")
    list(status = "REFUSED", code = code, message = message,
         how_to_fix = how_to_fix, context = list(call = sys.call()))
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(refuse("PKG_JSONLITE_MISSING", "Package 'jsonlite' is required to write the data layer.",
                  "Install it with renv::install('jsonlite')."))
  }
  if (is.null(all_results) || !is.list(all_results) || length(all_results) == 0) {
    return(refuse("DATA_NO_QUESTIONS", "all_results is empty — nothing to emit.",
                  "Run the crosstab analysis before writing the data layer."))
  }
  if (is.null(banner_info) || is.null(banner_info$internal_keys) ||
      length(banner_info$internal_keys) == 0) {
    return(refuse("DATA_NO_COLUMNS", "banner_info has no internal_keys (no banner columns).",
                  "Ensure the banner structure was built before writing the data layer."))
  }

  data_layer <- tryCatch(
    build_data_layer(all_results, banner_info, config_obj, survey_structure,
                     ai = build_dl_ai(config_obj)),
    error = function(e) e)
  if (inherits(data_layer, "error")) {
    return(refuse("DATA_LAYER_BUILD_FAILED", conditionMessage(data_layer),
                  "Check the all_results / banner_info structures for this run."))
  }
  if (length(data_layer$questions) == 0) {
    return(refuse("DATA_NO_QUESTIONS", "No questions produced a usable table.",
                  "Confirm the questions have RowLabel/RowType tables."))
  }

  json <- serialize_data_layer(data_layer)

  written <- tryCatch({
    writeLines(json, output_path, useBytes = TRUE); TRUE
  }, error = function(e) e)
  if (inherits(written, "error")) {
    return(refuse("IO_WRITE_FAILED", conditionMessage(written),
                  paste0("Check that the output directory exists and is writable: ", output_path)))
  }

  size_mb <- file.info(output_path)$size / 1024 / 1024
  cat(sprintf("  Data layer: %s (%.2f MB, %d questions)\n",
              basename(output_path), size_mb, length(data_layer$questions)))

  list(status = "PASS", output_file = output_path,
       file_size_mb = size_mb, n_questions = length(data_layer$questions))
}
