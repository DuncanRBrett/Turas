# ==============================================================================
# TABS. SHARED REPORT HELPERS
# ==============================================================================
# Row/banner shape helpers and the chart colour palette, shared by the JSON
# data-layer writer (the v2 interactive report) and, historically, the classic
# HTML report's transformer.
#
# These functions lived in html_report/01_data_transformer.R and
# html_report/07_chart_builder.R until the classic report was retired
# (2026-08). They are the only part of that module the v2 pipeline ever used,
# so they were lifted out unchanged rather than deleted with it. Anything that
# needs to classify a question table's rows, name a banner group, or resolve a
# palette preset sources this file, not a report builder.
# ==============================================================================

#' Build Banner Groups Structure
#'
#' Extracts banner group definitions from banner_info into a clean
#' structure mapping group name -> columns, keys, and letters.
#'
#' @param banner_info List from create_banner_structure()
#' @return Named list of banner groups
#' @export
build_banner_groups <- function(banner_info) {
  groups <- list()

  # banner_info$banner_info is a named list keyed by banner question code
  # banner_info$banner_headers has label, start_col, end_col
  # banner_info$internal_keys has all keys in order (first is TOTAL::Total)
  # banner_info$letters has corresponding letters

  all_keys <- banner_info$internal_keys
  all_letters <- banner_info$letters
  all_columns <- banner_info$columns

  for (bq_code in names(banner_info$banner_info)) {
    bq <- banner_info$banner_info[[bq_code]]

    # Get the display label for this group from banner_headers
    group_label <- bq_code  # fallback
    found_banner_label <- FALSE
    if (!is.null(banner_info$banner_headers)) {
      # Find matching header by position
      for (i in seq_len(nrow(banner_info$banner_headers))) {
        hdr <- banner_info$banner_headers[i, ]
        # Match by checking if this banner's keys fall within the header's column range
        bq_positions <- which(all_keys %in% bq$internal_keys)
        if (length(bq_positions) > 0 && !is.na(hdr$start_col) && !is.na(hdr$end_col)) {
          # banner_headers positions are 1-indexed from the data columns (excluding Total)
          # Check if any of this banner's positions fall in this header's range
          in_range <- bq_positions >= hdr$start_col & bq_positions <= hdr$end_col
          if (any(in_range, na.rm = TRUE)) {
            group_label <- hdr$label
            found_banner_label <- TRUE
            break
          }
        }
      }
    }

    # V10.8: Only fall back to QuestionText if no BannerLabel was found.
    # Previously this block unconditionally overwrote the BannerLabel.
    # Use a flag (not string comparison) because BannerLabel may equal the code.
    if (!found_banner_label) {
      # No BannerLabel found from banner_headers. Try QuestionText
      if (!is.null(bq$question) && !is.null(bq$question$QuestionText)) {
        qt <- as.character(bq$question$QuestionText)
        if (length(qt) > 0 && !is.na(qt[1]) && nzchar(qt[1])) {
          group_label <- qt[1]
        }
      }
    }

    display_label <- group_label

    groups[[display_label]] <- list(
      banner_code = bq_code,
      internal_keys = bq$internal_keys,
      letters = bq$letters,
      display_labels = if (!is.null(bq$columns)) bq$columns
                       else sapply(bq$internal_keys, function(k) {
                         parts <- strsplit(k, "::")[[1]]
                         if (length(parts) >= 2) parts[length(parts)] else k
                       }, USE.NAMES = FALSE)
    )
  }

  groups
}


#' Detect Available Statistics for a Question
#'
#' Scans the RowType column to determine which statistics are present.
#'
#' @param question_table Data.frame from all_results[[q]]$table
#' @return Named list of logicals
#' @export
detect_available_stats <- function(question_table) {
  row_types <- unique(question_table$RowType)

  list(
    has_freq = "Frequency" %in% row_types,
    has_col_pct = "Column %" %in% row_types,
    has_row_pct = "Row %" %in% row_types,
    has_sig = "Sig." %in% row_types,
    has_sig2 = "Sig.2" %in% row_types,   # Secondary sig level (dual-alpha feature, V10.10)
    has_mean = "Average" %in% row_types,
    has_index = "Index" %in% row_types,
    has_score = "Score" %in% row_types,
    has_sd = any(c("Std Dev", "StdDev") %in% row_types)
  )
}


#' Classify Row Labels as Category, NET, or Mean
#'
#' Determines whether each unique RowLabel is a regular category,
#' a NET/box-category summary, or a mean/summary statistic.
#'
#' Uses the RowSource column (if available) as the primary classifier,
#' falling back to regex pattern matching for backward compatibility.
#'
#' @param question_table Data.frame from question result
#' @param question_type Character, question type (e.g., "Single_Choice")
#' @return Named character vector: RowLabel -> "category"|"net"|"mean"
#' @export
classify_row_labels <- function(question_table, question_type = "Single_Choice") {

  # Get all unique labels and their associated row types and sources
  labels <- unique(question_table$RowLabel)
  # Remove NA labels
  labels <- labels[!is.na(labels) & labels != ""]

  has_row_source <- "RowSource" %in% names(question_table)

  label_types <- sapply(labels, function(lbl) {
    unique(question_table$RowType[!is.na(question_table$RowLabel) & question_table$RowLabel == lbl])
  }, simplify = FALSE)

  # Build RowSource lookup per label (first non-NA source wins)
  label_sources <- if (has_row_source) {
    sapply(labels, function(lbl) {
      sources <- question_table$RowSource[!is.na(question_table$RowLabel) & question_table$RowLabel == lbl]
      sources <- sources[!is.na(sources) & sources != ""]
      if (length(sources) > 0) sources[1] else NA_character_
    }, USE.NAMES = TRUE)
  } else {
    NULL
  }

  classification <- character(length(labels))
  names(classification) <- labels

  # Common NET/box-category patterns (case-insensitive) - fallback for data without RowSource
  net_patterns <- c(
    "^NET\\b", "^NET ", "\\bNET\\b",
    "^TOP BOX", "^BOTTOM BOX", "^TOP 2", "^BOTTOM 2",
    "^TOP 3", "^BOTTOM 3",
    "NET POSITIVE", "NET NEGATIVE",
    "^Promoter", "^Detractor", "^Passive",
    "^NPS\\b", "NPS \\(",
    "^Good or ", "^Terrible or ",
    "^Agree or ", "^Disagree or ",
    "Fully trust", "Some trust", "Do not trust",
    "^Satisfied or ", "^Dissatisfied or ",
    "^Average$",
    # Box-category labels with parenthetical ranges e.g. "Dissatisfied (1-5)"
    "\\(\\d+-\\d+\\)",
    # Common exclusion/composite categories
    "^DK\\s*/\\s*NA$", "^DK/NA$", "^Don't know\\s*/", "^Refused\\s*/",
    # Common box-category summary labels (Likert, satisfaction, sentiment)
    "^Negative$", "^Neutral$", "^Positive$",
    "^Would switch$", "^Would not switch$", "^Undecided$",
    "^Poor\\s", "^Good or\\s", "^Below average",
    "^Satisfied$", "^Dissatisfied$", "^Neither"
  )

  for (lbl in labels) {
    types <- label_types[[lbl]]

    # ── Primary: Use RowSource if available ──
    if (!is.null(label_sources) && !is.na(label_sources[lbl])) {
      src <- label_sources[lbl]
      if (src %in% c("individual", "ranking")) {
        classification[lbl] <- "category"
        next
      } else if (src %in% c("boxcategory", "net_positive")) {
        classification[lbl] <- "net"
        next
      } else if (src %in% c("summary", "chi_square", "composite", "ranking_mean")) {
        classification[lbl] <- "mean"
        next
      }
    }

    # ── Fallback: regex-based classification (backward compatibility) ──

    # Mean/summary statistics - always classified as "mean"
    if (any(types %in% c("Average", "Index", "Score", "Std Dev", "StdDev", "ChiSquare"))) {
      classification[lbl] <- "mean"
      next
    }

    # Check against NET patterns
    is_net <- FALSE
    for (pat in net_patterns) {
      match_result <- tryCatch(grepl(pat, lbl, ignore.case = TRUE), error = function(e) FALSE)
      if (isTRUE(match_result)) {
        is_net <- TRUE
        break
      }
    }

    if (is_net) {
      classification[lbl] <- "net"
    } else {
      classification[lbl] <- "category"
    }
  }

  classification
}


#' Normalise a Question Table for Row Matching
#'
#' Trims RowLabel/RowType and forward-fills RowLabel and RowSource so every
#' sub-row (Column %, Sig., ...) inherits its parent option's label/source.
#' The source data only sets these on the first RowType for each item.
#'
#' Shared by the HTML transformer (transform_single_question) and the JSON
#' data-layer writer so both classify rows from an identical table shape.
#'
#' @param table Data.frame from all_results[[q]]$table (needs RowLabel, RowType)
#' @return The same data.frame with RowLabel/RowType trimmed and RowLabel +
#'   RowSource (if present) forward-filled.
#' @export
normalize_question_table <- function(table) {
  # Coerce RowLabel to character and trim whitespace to avoid matching issues
  table$RowLabel <- trimws(as.character(table$RowLabel))
  table$RowType <- trimws(as.character(table$RowType))

  # Forward-fill RowLabel: the source data only sets RowLabel on the first
  # RowType for each item (typically Frequency), leaving Column %, Sig., etc.
  # with empty labels. Propagate each non-empty label downward.
  #
  # Sig rows (RowType "Sig." / "Sig.2") are excluded from setting last_label
  # because in dual-alpha mode they carry a confidence label ("Sig. (95%)")
  # rather than the option label. They must inherit the option label like any
  # other sub-row, so the matcher can pair them with their parent option.
  sig_row_types_ff <- c("Sig.", "Sig.2")
  last_label <- ""
  for (i in seq_len(nrow(table))) {
    if (!is.na(table$RowLabel[i]) && nzchar(table$RowLabel[i]) &&
        !table$RowType[i] %in% sig_row_types_ff) {
      last_label <- table$RowLabel[i]
    } else {
      table$RowLabel[i] <- last_label
    }
  }

  # Forward-fill RowSource: same logic as RowLabel. Sub-rows (Column %, Sig.)
  # inherit the source type from their parent frequency row.
  if ("RowSource" %in% names(table)) {
    last_source <- ""
    for (i in seq_len(nrow(table))) {
      if (!is.na(table$RowSource[i]) && nzchar(table$RowSource[i])) {
        last_source <- table$RowSource[i]
      } else {
        table$RowSource[i] <- last_source
      }
    }
  }

  table
}


# ==============================================================================
# CHART COLOUR PALETTE
# ==============================================================================
# Five presets plus a brand-generated monochrome ramp. The v2 data layer reads
# these into the island so its charts and the workbook agree on sentiment
# colours; individual stops can be overridden per project from Settings.
# ==============================================================================


#' Get palette colours for a preset
#'
#' Returns a named list of 7 semantic colours for the given preset.
#' Supports individual overrides from config.
#'
#' @param preset Character: "warm", "cool", "research", "teal", "red", or "brand"
#' @param overrides Named list of individual colour overrides (optional).
#'   For "brand" preset, must include \code{brand_colour} hex value.
#' @return Named list with: negative, mod_negative, neutral, mod_positive,
#'         positive, dk_na, other
#' @keywords internal
get_palette_colours <- function(preset = "warm", overrides = NULL) {

  palettes <- list(
    # Warm earth tones. Dusty rose through sage/teal
    warm = list(
      negative     = "#b85450",
      mod_negative = "#d4918e",
      neutral      = "#c9a96e",
      mod_positive = "#7daa8c",
      positive     = "#4a7c6f",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Cool professional. Muted burgundy through deep teal
    cool = list(
      negative     = "#a65461",
      mod_negative = "#c78f93",
      neutral      = "#94a3b8",
      mod_positive = "#6f9fa8",
      positive     = "#3d7a8a",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Purple-green diverging. Research/academic standard (colorblind-safe)
    research = list(
      negative     = "#8e4585",
      mod_negative = "#b891b5",
      neutral      = "#b8b8b8",
      mod_positive = "#7daa8c",
      positive     = "#3d7a5f",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Monochromatic teal. Light-to-dark single-hue gradient, muted
    teal = list(
      negative     = "#d4edea",
      mod_negative = "#a3d5cf",
      neutral      = "#6dbfb8",
      mod_positive = "#4a9e95",
      positive     = "#2d7a72",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Monochromatic red. Coca-Cola-inspired, muted (hue ~4°, sat 45%)
    red = list(
      negative     = "#e8cbcb",
      mod_negative = "#cfa0a0",
      neutral      = "#b07272",
      mod_positive = "#8f4d4d",
      positive     = "#6e2b2b",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    )
  )

  preset_lower <- tolower(preset)

  # "brand" preset: generate monochromatic gradient from brand_colour

  if (preset_lower == "brand") {
    brand_hex <- if (!is.null(overrides$brand_colour) && nzchar(overrides$brand_colour)) {
      overrides$brand_colour
    } else {
      "#323367"  # fallback
    }
    pal <- .generate_mono_palette(brand_hex)
  } else {
    # Select preset (fall back to warm if unrecognised)
    pal <- palettes[[preset_lower]]
    if (is.null(pal)) pal <- palettes[["warm"]]
  }

  # Apply individual overrides from config
  if (!is.null(overrides)) {
    override_map <- list(
      chart_negative_colour     = "negative",
      chart_mod_negative_colour = "mod_negative",
      chart_neutral_colour      = "neutral",
      chart_mod_positive_colour = "mod_positive",
      chart_positive_colour     = "positive",
      chart_dk_colour           = "dk_na"
    )
    for (cfg_key in names(override_map)) {
      if (!is.null(overrides[[cfg_key]]) && nzchar(overrides[[cfg_key]])) {
        pal[[ override_map[[cfg_key]] ]] <- overrides[[cfg_key]]
      }
    }
  }

  pal
}


#' Generate monochromatic palette from a single hex colour
#'
#' Produces 5 gradient stops from light (90% lightness) to dark (30% lightness)
#' at the same hue/saturation, desaturated slightly for a muted look.
#'
#' @param hex Character, hex colour (e.g. "#323367")
#' @return Named list with negative, mod_negative, neutral, mod_positive,
#'         positive, dk_na, other
#' @keywords internal
.generate_mono_palette <- function(hex) {
  # Parse hex to RGB (0-255)
  hex_clean <- sub("^#", "", hex)
  r <- strtoi(substr(hex_clean, 1, 2), 16L) / 255
  g <- strtoi(substr(hex_clean, 3, 4), 16L) / 255
  b <- strtoi(substr(hex_clean, 5, 6), 16L) / 255

  # RGB -> HSL
  cmax <- max(r, g, b)
  cmin <- min(r, g, b)
  delta <- cmax - cmin

  # Lightness
  l <- (cmax + cmin) / 2

  # Saturation
  if (delta == 0) {
    s <- 0
    h <- 0
  } else {
    s <- if (l < 0.5) delta / (cmax + cmin) else delta / (2 - cmax - cmin)
    h <- if (cmax == r) {
      60 * (((g - b) / delta) %% 6)
    } else if (cmax == g) {
      60 * ((b - r) / delta + 2)
    } else {
      60 * ((r - g) / delta + 4)
    }
    if (h < 0) h <- h + 360
  }

  # Desaturate slightly for muted look (cap at 45%)
  s_muted <- min(s, 0.45)

  # Generate 5 lightness stops: light → dark
  lightness_stops <- c(0.88, 0.74, 0.58, 0.44, 0.30)

  hsl_to_hex <- function(h, s, l) {
    c_val <- (1 - abs(2 * l - 1)) * s
    x <- c_val * (1 - abs((h / 60) %% 2 - 1))
    m <- l - c_val / 2
    if (h < 60)       { r1 <- c_val; g1 <- x;     b1 <- 0 }
    else if (h < 120) { r1 <- x;     g1 <- c_val; b1 <- 0 }
    else if (h < 180) { r1 <- 0;     g1 <- c_val; b1 <- x }
    else if (h < 240) { r1 <- 0;     g1 <- x;     b1 <- c_val }
    else if (h < 300) { r1 <- x;     g1 <- 0;     b1 <- c_val }
    else              { r1 <- c_val; g1 <- 0;     b1 <- x }
    ri <- round((r1 + m) * 255)
    gi <- round((g1 + m) * 255)
    bi <- round((b1 + m) * 255)
    sprintf("#%02x%02x%02x", ri, gi, bi)
  }

  colours <- vapply(lightness_stops, function(lv) hsl_to_hex(h, s_muted, lv), character(1))

  list(
    negative     = colours[1],
    mod_negative = colours[2],
    neutral      = colours[3],
    mod_positive = colours[4],
    positive     = colours[5],
    dk_na        = "#d1cdc7",
    other        = "#c5c0b8"
  )
}


# ==============================================================================
# POPULATION FRAME RESOLUTION (finite population correction)
# ==============================================================================
# One resolver, two callers. The data-layer writer uses it to stamp each column
# with its universe N; the significance engine uses it to size that column's
# tests on the FPC-corrected base. They MUST agree. A column whose interval
# narrows but whose letters do not (or the reverse) is worse than no correction.

#' Resolve a banner column's known population from the Population frame
#'
#' Matches a column's subgroup label (and, when given, its banner) against the
#' optional Population sheet. A banner-scoped row wins over an unscoped one; the
#' match is case-insensitive on trimmed labels. Returns NULL when no usable
#' population is found, so callers omit the field entirely (no correction).
#'
#' @param col_label The column's display label (e.g. "Masters")
#' @param banner_label The column's banner question label, or NA
#' @param frame The population frame (data.frame banner/group/population) or NULL
#' @return Numeric population (> 1) or NULL
#' @export
.resolve_column_population <- function(col_label, banner_label, frame) {
  if (is.null(frame) || nrow(frame) == 0 || is.null(col_label) || is.na(col_label)) {
    return(NULL)
  }
  norm <- function(x) tolower(trimws(as.character(x)))
  same_group <- norm(frame$group) == norm(col_label)
  if (!any(same_group)) return(NULL)
  cand <- frame[same_group, , drop = FALSE]
  # Prefer a row whose Banner matches this column's banner label; otherwise an
  # unscoped (blank-Banner) row.
  if (!is.null(banner_label) && !is.na(banner_label)) {
    scoped <- !is.na(cand$banner) & norm(cand$banner) == norm(banner_label)
    if (any(scoped)) return(cand$population[which(scoped)[1]])
  }
  unscoped <- is.na(cand$banner)
  if (any(unscoped)) return(cand$population[which(unscoped)[1]])
  # A scoped row for a different banner only, not a match for this column.
  NULL
}


#' Resolve every banner column's known universe N
#'
#' The per-key form of \code{.resolve_column_population()}: the Total column
#' takes the study's \code{population_size}, each banner column its Population
#' sheet match. Returns \code{NA_real_} for a column with no usable universe, so
#' callers treat it as "no correction" without a special case.
#'
#' Both consumers of a column's universe go through here. The data-layer writer
#' (which stamps \code{population} on each column so intervals narrow) and the
#' significance engine (which sizes that column's tests on the FPC-corrected
#' base). A second implementation is how a report ends up with narrower
#' intervals and unchanged letters.
#'
#' @param banner_info Banner structure from create_banner_structure()
#' @param config_obj Tabs config object (reads population_frame, population_size)
#' @return Named numeric vector over banner_info$internal_keys; NA where unknown
#' @export
resolve_column_populations <- function(banner_info, config_obj = NULL) {
  keys <- banner_info$internal_keys
  out  <- setNames(rep(NA_real_, length(keys)), keys)
  if (is.null(config_obj) || length(keys) == 0) return(out)

  frame    <- config_obj$population_frame
  pop_size <- suppressWarnings(as.numeric(config_obj$population_size))
  pop_size <- if (length(pop_size) == 1L && !is.na(pop_size) && pop_size > 1) pop_size else NA_real_

  # banner_code -> the human label the Population sheet's Banner column uses.
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

  k2d <- banner_info$key_to_display
  c2b <- banner_info$column_to_banner

  for (i in seq_along(keys)) {
    key <- keys[i]
    grp_code <- if (!is.null(c2b) && key %in% names(c2b)) unname(c2b[[key]]) else NA_character_
    is_total <- identical(key, "TOTAL::Total") || identical(grp_code, "TOTAL")
    if (is_total) {
      out[i] <- pop_size
      next
    }
    label <- if (!is.null(k2d) && key %in% names(k2d)) unname(k2d[[key]]) else key
    banner_label <- if (!is.na(grp_code)) banner_label_by_code[[as.character(grp_code)]] else NULL
    pop <- .resolve_column_population(label, banner_label, frame)
    if (!is.null(pop) && is.finite(pop) && pop > 1) out[i] <- as.numeric(pop)
  }
  out
}


#' FPC multipliers for one question's banner columns
#'
#' The number each column's effective base is multiplied by before it is tested:
#' \code{apply_fpc(1, n_actual, N)}, i.e. \code{(N - 1) / (N - n_actual)} when the
#' correction engages. 1 when the universe is unknown or coverage is below
#' \code{FPC_MIN_COVERAGE}; \code{Inf} at a full census, which the tests read as
#' "no sampling error left. Exclude this column from pairing".
#'
#' n_actual is the column's UNWEIGHTED base FOR THIS QUESTION: a routed question
#' covers less of the same universe than an all-respondent one, so its columns
#' are corrected less.
#'
#' @param question_bases Named list of per-key bases with an $unweighted field
#' @param col_populations Named numeric vector from resolve_column_populations()
#' @param keys Character vector of internal keys (defaults to the bases' names)
#' @return Named numeric vector of multipliers, one per key (all 1 with no config)
#' @export
build_fpc_multipliers <- function(question_bases, col_populations, keys = NULL) {
  if (is.null(keys)) keys <- names(question_bases)
  out <- setNames(rep(1, length(keys)), keys)
  if (is.null(col_populations) || length(col_populations) == 0) return(out)

  for (i in seq_along(keys)) {
    key <- keys[i]
    N <- if (key %in% names(col_populations)) unname(col_populations[[key]]) else NA_real_
    if (is.na(N)) next
    base_info <- question_bases[[key]]
    n_actual <- if (!is.null(base_info) && !is.null(base_info$unweighted)) {
      suppressWarnings(as.numeric(base_info$unweighted[1]))
    } else NA_real_
    if (is.na(n_actual)) next
    # apply_fpc(1, ...) IS the multiplier. Deriving it here instead would be a
    # second implementation of the floor and the census rule.
    out[i] <- apply_fpc(1, n_actual, N)
  }
  out
}
