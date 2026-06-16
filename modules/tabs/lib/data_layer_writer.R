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
# Row classification reuses the HTML transformer's helpers
# (normalize_question_table, detect_available_stats, classify_row_labels) so the
# JSON and HTML reports can never drift on what counts as a category / NET /
# mean row. Requires html_report/01_data_transformer.R to be sourced.
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
#' renderer then falls back to the brand dot. (The classic HTML report has its
#' own equivalent embed_logo; sharing them is a safe future refactor.)
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
  alpha <- as.numeric(config_obj$alpha %||% 0.05)
  sm <- as.character(config_obj$sampling_method %||% "Not_Specified")
  proj <- list(
    name               = as.character(name),
    client             = if (blank(config_obj$client_name)) "" else as.character(config_obj$client_name),
    wave               = if (blank(config_obj$wave)) "" else as.character(config_obj$wave),
    brand_colour       = as.character(config_obj$brand_colour %||% "#323367"),
    accent_colour      = as.character(config_obj$accent_colour %||% "#CC9900"),
    low_base_threshold = as.numeric(config_obj$significance_min_base %||% 30),
    alpha              = alpha,
    sampling_method    = sm,
    sig_note           = build_sig_note(alpha, sm),
    tracking           = list(enabled = isTRUE(tracking_enabled), default_scope = "all")
  )
  # Inline researcher / client logos as data URIs when configured; omit (the
  # renderer shows the brand dot) otherwise. researcher_logo_path falls back to
  # the legacy single logo_path, mirroring the classic report.
  researcher <- encode_logo_data_uri(config_obj$researcher_logo_path %||% config_obj$logo_path)
  if (!is.null(researcher)) proj$researcher_logo <- researcher
  client_logo <- encode_logo_data_uri(config_obj$client_logo_path)
  if (!is.null(client_logo)) proj$client_logo <- client_logo

  # Report metadata — pre-fills the v2 Report tab's Background & method,
  # Executive summary and (read-only) About from the config's Comments sheet
  # and closing section, mirroring the classic report. Background/exec stay
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
    exec_summary = cfg_chr("executive_summary")
  )
  if (any(nzchar(unlist(meta)))) proj$report_meta <- meta
  proj
}


#' Build the columns[] array of the data layer
#'
#' One entry per banner column (Total first), in banner_info$internal_keys
#' order — the order every row.pct/n/sig array is indexed by.
#'
#' @param banner_info Banner structure from create_banner_structure()
#' @return A list of {key, group, label, letter}
#' @export
build_dl_columns <- function(banner_info) {
  keys    <- banner_info$internal_keys
  letters <- banner_info$letters
  k2d     <- banner_info$key_to_display
  c2b     <- banner_info$column_to_banner
  lapply(seq_along(keys), function(i) {
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
    list(key = as.character(key), group = as.character(group),
         label = as.character(label), letter = letter)
  })
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

#' Unique non-blank categories in the classic report's order
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

#' Question codes grouped by category, in the classic report's order
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
#' Unique non-blank question categories, in the classic report's order
#' (CategoryOrder then first-appearance).
#'
#' @param all_results The tabs results list
#' @return A list of category-label strings
#' @export
build_dl_categories <- function(all_results) {
  as.list(.dl_category_seq(all_results))
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

  primary_stat <- if (stats$has_col_pct) "Column %"
                  else if (stats$has_row_pct) "Row %"
                  else if (stats$has_freq) "Frequency"
                  else if (stats$has_mean) "Average"
                  else "Frequency"

  base_types <- c("Base (n=)", "Base", "Base (n)",
                  "Unweighted Base", "Weighted Base", "Effective Base")
  mean_types <- c("Average", "Index", "Score", "Std Dev", "StdDev", "ChiSquare")

  # Numeric values for (label, RowType) across every column, NA where absent
  vals_for <- function(lbl, rtype) {
    sel <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                 table$RowLabel == lbl & table$RowType == rtype, , drop = FALSE]
    vapply(keys, function(k) {
      if (nrow(sel) > 0 && k %in% names(table)) {
        suppressWarnings(as.numeric(sel[1, k]))
      } else NA_real_
    }, numeric(1), USE.NAMES = FALSE)
  }
  sig_for <- function(lbl) {
    sel <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                 table$RowLabel == lbl & table$RowType == "Sig.", , drop = FALSE]
    vapply(keys, function(k) {
      if (nrow(sel) > 0 && k %in% names(table)) {
        v <- as.character(sel[1, k])
        if (is.na(v) || v == "" || v == "-") "" else v
      } else ""
    }, character(1), USE.NAMES = FALSE)
  }
  null_vec  <- function() as.list(rep(NA_real_, length(keys)))  # serialises to [null,...]
  empty_sig <- function() as.list(rep("", length(keys)))

  ord_labels <- unique(table$RowLabel[!is.na(table$RowLabel) & nzchar(table$RowLabel)])

  rows <- list()
  metric_type <- NA_character_   # the headline summary-stat kind, if any
  for (lbl in ord_labels) {
    lbl_types <- unique(table$RowType[!is.na(table$RowLabel) & table$RowLabel == lbl])
    # Base rows are carried by bases[] — skip them here
    if (length(lbl_types) > 0 && all(lbl_types %in% base_types)) next

    cl <- cls[[lbl]]
    if (is.null(cl) || is.na(cl)) cl <- "category"

    if (cl == "mean") {
      mrt <- intersect(lbl_types, mean_types)
      if (length(mrt) == 0) next
      if (is.na(metric_type) && mrt[1] %in% c("Average", "Mean", "Index", "Score")) {
        metric_type <- mrt[1]
      }
      rows[[length(rows) + 1]] <- list(
        kind = "mean", label = lbl,
        pct = as.list(vals_for(lbl, mrt[1])), n = null_vec(), sig = empty_sig())
    } else {
      pr <- vals_for(lbl, primary_stat)
      if (all(is.na(pr))) {
        for (fb in c("Column %", "Row %", "Frequency")) {
          if (fb == primary_stat) next
          alt <- vals_for(lbl, fb)
          if (!all(is.na(alt))) { pr <- alt; break }
        }
      }
      kind <- if (cl == "net") "net" else "category"
      # Box-category rows (e.g. "Good (9 - 10)", "Top 2 Box") carry a real
      # Frequency in the source, so the "Counts" toggle shows n= just like the
      # classic report. Only a true "NET POSITIVE" row is a percentage-point
      # difference, not a count — it keeps a null n, matching the renderer's
      # computed path which also nulls that row's n.
      is_net_diff <- kind == "net" && grepl("^NET POSITIVE", lbl, ignore.case = TRUE)
      rows[[length(rows) + 1]] <- list(
        kind = kind, label = lbl,
        pct = as.list(pr),
        n   = if (is_net_diff) null_vec() else as.list(vals_for(lbl, "Frequency")),
        sig = if (stats$has_sig) as.list(sig_for(lbl)) else empty_sig())
    }
  }

  bases <- lapply(keys, function(k) {
    bn <- NA_real_
    if (!is.null(q_result$bases) && k %in% names(q_result$bases)) {
      u <- q_result$bases[[k]]$unweighted
      if (!is.null(u) && length(u) >= 1) bn <- suppressWarnings(as.numeric(u[1]))
    }
    list(n = bn, low = is.na(bn) || bn < low_base)
  })

  cat_val <- q_result$category
  cat_val <- if (is.null(cat_val) || length(cat_val) == 0 || is.na(cat_val[1])) ""
             else as.character(cat_val[1])

  q_type_v2 <- map_question_type(q_result$question_type)

  # Scale maximum for the dashboard gauge/heatmap ("% of each scale's
  # maximum"). Without it the renderer assumes 100, so a 0-10 mean reads as
  # ~7% and every card shows weak/red. Sourced from the project's configured
  # scale (dashboard_scale_mean / dashboard_scale_index). NA -> null for
  # questions with no summary-stat row (they are not on the dashboard).
  # scale_max feeds the gauge/heatmap normalisation; gauge_green/gauge_amber
  # are the project's configured colour thresholds (raw values, e.g. >=7
  # green / >=5 amber) so the v2 dashboard colours match the classic report.
  #
  # Only rated touchpoints (scale / nps) get a scale_max. A Numeric open-count
  # (e.g. "how many hours did you lose?") carries a Mean row but has no scale
  # maximum, so colour-banding it as a "% of 10" is meaningless and direction-
  # blind (9 hours lost would read strong/green). Leaving these NA also makes
  # the renderer's indexQuestions() filter exclude them from the dashboard.
  scale_max <- NA_real_
  gauge_green <- NA_real_
  gauge_amber <- NA_real_
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
  }

  # index_scores (display label -> numeric score) lets the renderer recompute
  # means/NPS from microdata under a live filter or custom banner. Omitted
  # (NULL -> absent in JSON) when the structure is not supplied or the type
  # carries no per-option score — the published mean still shows unfiltered.
  index_scores <- derive_index_scores(q_result, survey_structure)
  # net_diffs (NET POSITIVE = top box - bottom box) lets that row recompute too;
  # box NET rows recompute from per-respondent box membership (TR.MICRO.boxes).
  net_diffs <- derive_net_diffs(rows)

  out <- list(
    code        = as.character(q_result$question_code %||% ""),
    title       = as.character(q_result$question_text %||% ""),
    category    = cat_val,
    type        = q_type_v2,
    bases       = bases,
    rows        = rows,
    scale_max   = scale_max,
    gauge_green = gauge_green,
    gauge_amber = gauge_amber
  )
  if (!is.null(index_scores)) out$index_scores <- index_scores
  if (!is.null(net_diffs)) out$net_diffs <- net_diffs
  out
}


#' Per-question analyst comments from the config's Comments sheet
#'
#' Keyed by question code; each value a list of \code{{banner, text}} entries
#' (banner NA = general, serialises to JSON null). These pre-fill the v2
#' report's per-question insight box, mirroring the classic report; the
#' analyst's own edits in the report override them. Returns NULL when no
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


#' Build the complete data-agg structure (pure — no file I/O)
#'
#' @param all_results List of question results
#' @param banner_info Banner structure
#' @param config_obj Configuration object
#' @param survey_structure Optional structure; threaded to build_dl_question so
#'   scale/NPS questions carry index_scores for live mean recompute
#' @param tracking_enabled Logical; sets project.tracking.enabled (the Tracking
#'   tab also requires a prior-wave island to actually appear)
#' @return A list mirroring the data-agg JSON shape
#' @export
build_data_layer <- function(all_results, banner_info, config_obj,
                             survey_structure = NULL, tracking_enabled = FALSE) {
  project <- build_dl_project(config_obj, tracking_enabled = tracking_enabled)
  low_base <- project$low_base_threshold

  # Group questions by category in the classic report's order (CategoryOrder
  # then appearance) so the v2 report opens on, and groups by, the same sections.
  questions <- list()
  for (q_code in .dl_ordered_codes(all_results)) {
    q <- build_dl_question(all_results[[q_code]], banner_info, config_obj, low_base,
                           survey_structure)
    if (!is.null(q)) questions[[length(questions) + 1]] <- q
  }

  dl <- list(
    schema_version = 2L,
    project        = project,
    columns        = build_dl_columns(banner_info),
    banner_groups  = build_dl_banner_groups(banner_info),
    categories     = build_dl_categories(all_results),
    questions      = questions
  )
  # Per-question analyst comments (config Comments sheet) pre-fill the report's
  # insight boxes. Omitted entirely when none are configured.
  comments <- build_dl_comments(config_obj)
  if (!is.null(comments)) dl$comments <- comments
  dl
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
    build_data_layer(all_results, banner_info, config_obj, survey_structure),
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
