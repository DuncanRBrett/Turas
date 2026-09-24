# ==============================================================================
# WHAT IF - FROM CONFIG AND DATA TO THE ENGINE SPEC
# ==============================================================================
#
# Loads the survey data, applies the base filter, and builds everything the
# engine needs from the config:
#
#   outcome    the outcome question banded (NPS: 0-6, 7-8, 9-10) and scored
#   levers     rating, nested and coverage values, items averaged, don't-know
#              answers set by the dont_know rule and counted
#   context    descriptive variables: missing label, BoxCategory or Recodes,
#              small levels collapsed
#   profile, structure rules, baselines, bundles, symptoms
#
# Labelled answers ("Good", "Excellent") become scale points from the
# Survey_Structure Options sheet: their rank by DisplayOrder among options not
# marked ExcludeFromIndex. Excluded options ("DK") are don't-know. Numeric
# answers (0 to 10) are used as they are.
#
# The data is read as text, never type-guessed: a guessed column can turn a
# late text answer into a silent NA.
#
# ==============================================================================

#' Load Survey Data as Text
#'
#' @param path Data file (.xlsx, .xls, .csv or .sav)
#' @return Data frame of character columns
#' @keywords internal
whatif_load_data <- function(path) {
  if (!file.exists(path)) {
    whatif_refuse("IO_DATA_NOT_FOUND", "Data file not found",
      sprintf("The data file '%s' does not exist.", path),
      "The What if model is fitted on this file.",
      "Check data_file on the Settings sheet; a relative path is read from the config's folder.")
  }
  ext <- tolower(tools::file_ext(path))
  d <- switch(ext,
    xlsx = , xls = suppressMessages(readxl::read_excel(path, sheet = 1, col_types = "text", na = "")),
    csv = utils::read.csv(path, colClasses = "character", na.strings = "", check.names = FALSE,
                          encoding = "UTF-8"),
    sav = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        whatif_refuse("PKG_HAVEN_MISSING", "The haven package is needed for .sav files",
          "SPSS files need the haven package, which is not installed.",
          "The data cannot be read without it.",
          "Install haven, or export the data to .xlsx.")
      }
      x <- haven::read_sav(path)
      x[] <- lapply(x, function(col) as.character(haven::as_factor(col, levels = "labels")))
      x
    },
    whatif_refuse("IO_DATA_FORMAT", "Unsupported data file",
      sprintf("'%s' is not .xlsx, .xls, .csv or .sav.", basename(path)),
      "The data cannot be read.",
      "Export the data to .xlsx or .csv.")
  )
  d <- as.data.frame(d, stringsAsFactors = FALSE, check.names = FALSE)
  # A byte-order mark on the first header (CCPB 2026's "Response ID") would
  # make the column impossible to name in the config.
  names(d) <- trimws(sub("^\ufeff", "", names(d)))
  d[] <- lapply(d, function(x) {
    x <- trimws(as.character(x))
    x[!is.na(x) & x == ""] <- NA_character_
    x
  })
  d
}


#' Resolve a Path Against the Config's Folder
#' @keywords internal
whatif_resolve <- function(root, p) {
  if (is.null(p) || is.na(p) || !nzchar(p)) return(NULL)
  if (grepl("^(/|~|[A-Za-z]:[/\\\\])", p)) return(path.expand(p))
  file.path(root, sub("^\\./", "", p))
}


#' Read the Survey_Structure Options Sheet
#'
#' @param path Survey_Structure workbook, or NULL
#' @return Named list by question code: data frame of OptionText, order,
#'   excluded, box (BoxCategory). Empty list when there is no workbook.
#' @keywords internal
whatif_read_options <- function(path) {
  if (is.null(path)) return(list())
  if (!file.exists(path)) {
    whatif_refuse("IO_STRUCTURE_NOT_FOUND", "Survey_Structure file not found",
      sprintf("structure_file '%s' does not exist.", path),
      "Labelled ratings are turned into scale points from its Options sheet.",
      "Check structure_file, or clear it if every lever question is numeric.")
  }
  o <- suppressMessages(load_config_table_sheet(path, "Options", required_cols = c("QuestionCode", "OptionText"),
                                                col_types = "text"))
  o <- as.data.frame(o, stringsAsFactors = FALSE)
  for (m in setdiff(c("DisplayText", "DisplayOrder", "ExcludeFromIndex", "BoxCategory", "Index_Weight"), names(o))) {
    o[[m]] <- NA_character_
  }
  o$QuestionCode <- trimws(o$QuestionCode)
  o$OptionText <- trimws(o$OptionText)
  o <- o[!is.na(o$QuestionCode) & !is.na(o$OptionText), , drop = FALSE]
  split_o <- split(o, o$QuestionCode)
  lapply(split_o, function(q) {
    ord <- suppressWarnings(as.numeric(q$DisplayOrder))
    ord[is.na(ord)] <- seq_len(nrow(q))[is.na(ord)] + 1e6
    q <- q[order(ord), , drop = FALSE]
    # Off the scale: marked ExcludeFromIndex, or, when the question's options
    # carry index weights, an option without one (SACAP 2025 Q027's "DK" has
    # no weight but is not marked excluded).
    iw <- !is.na(q$Index_Weight) & trimws(q$Index_Weight) != ""
    data.frame(text = q$OptionText,
               excluded = whatif_flag(q$ExcludeFromIndex) | (any(iw) & !iw),
               box = trimws(q$BoxCategory), display = trimws(q$DisplayText), stringsAsFactors = FALSE)
  })
}


#' Scores for One Question
#'
#' @param x Character answers
#' @param opts Options for the question (from whatif_read_options), or NULL
#' @return List with value (numeric, NA for don't-know or blank), dk (logical:
#'   answered but not on the scale), answered (logical)
#' @keywords internal
whatif_score_answers <- function(x, opts) {
  answered <- !is.na(x)
  # A numeric answer keeps its number: an NPS question's options run 0 to 10,
  # so their positions (1 to 11) would shift every band by one.
  value <- suppressWarnings(as.numeric(x))
  if (!is.null(opts) && nrow(opts)) {
    if (any(!is.na(value))) {
      excluded_num <- suppressWarnings(as.numeric(opts$text[opts$excluded]))
      value[value %in% excluded_num[!is.na(excluded_num)]] <- NA_real_
    }
    pos <- match(x, opts$text[!opts$excluded])
    value <- ifelse(is.na(value) & !is.na(pos), pos, value)
  }
  list(value = as.numeric(value), dk = answered & is.na(value), answered = answered)
}


#' Band the Outcome
#'
#' @param value Numeric outcome values
#' @param bands Character, "a-b" or "a" per band, lowest first
#' @return Integer band 1..k, NA outside every band
#' @keywords internal
whatif_band <- function(value, bands) {
  out <- rep(NA_integer_, length(value))
  for (i in seq_along(bands)) {
    p <- as.numeric(strsplit(gsub("\\s", "", bands[i]), "(?<=\\d)-", perl = TRUE)[[1]])
    if (length(p) == 1) p <- c(p, p)
    if (length(p) != 2 || anyNA(p)) {
      whatif_refuse("CFG_OUTCOME_BANDS", "Outcome band not understood",
        sprintf("outcome_bands entry '%s' is not a number or a range like 7-8.", bands[i]),
        "Respondents are placed in outcome categories by these ranges.",
        "Write each band as a range, lowest first, for example 0-6; 7-8; 9-10.")
    }
    out[!is.na(value) & value >= p[1] & value <= p[2] & is.na(out)] <- i
  }
  out
}


#' Build the Engine Spec from a Config and Its Data
#'
#' @param cfg Config from whatif_read_config()
#' @param verbose Print progress
#' @return List with spec (for whatif_run_engine), ids (respondent IDs in spec
#'   order), data (the filtered rows, text), options, lever_info (per lever:
#'   items, don't-know count, answered share), dropped (counts), paths
#' @keywords internal
whatif_prepare <- function(cfg, verbose = TRUE) {
  s <- cfg$settings
  root <- cfg$project_root
  data_path <- whatif_resolve(root, s$data_file)
  structure_path <- whatif_resolve(root, s$structure_file)
  d <- whatif_load_data(data_path)
  n_file <- nrow(d)
  opts <- whatif_read_options(structure_path)

  need_col <- function(code, where) {
    if (!code %in% names(d)) {
      whatif_refuse("DATA_COLUMN_MISSING", "Question not in the data",
        sprintf("%s names '%s', which is not a column of the data file.", where, code),
        "The value cannot be built from a column that is not there.",
        "Correct the code to match the data file's column name exactly (case matters).")
    }
  }

  # ---- base filter
  n_filtered_out <- 0L
  if (!is.null(s$base_filter_variable)) {
    need_col(s$base_filter_variable, "base_filter_variable")
    keep <- d[[s$base_filter_variable]] %in% s$base_filter_values
    n_filtered_out <- sum(!keep)
    d <- d[keep, , drop = FALSE]
  }

  # ---- respondent ID
  need_col(s$id_variable, "id_variable")
  ids <- d[[s$id_variable]]
  if (anyNA(ids) || anyDuplicated(ids)) {
    whatif_refuse("DATA_ID_NOT_UNIQUE", "Respondent IDs missing or repeated",
      sprintf("'%s' has %d missing and %d repeated values.", s$id_variable, sum(is.na(ids)), sum(duplicated(ids))),
      "The open report lines What if rows up with the report's respondents by this ID.",
      "Use a column with one unique ID per respondent.")
  }

  # ---- outcome
  need_col(s$outcome_question, "outcome_question")
  oc <- whatif_score_answers(d[[s$outcome_question]], opts[[s$outcome_question]])
  y <- whatif_band(oc$value, s$outcome_bands)
  n_no_outcome <- sum(is.na(y))
  if (n_no_outcome) {
    d <- d[!is.na(y), , drop = FALSE]
    ids <- ids[!is.na(y)]
    y <- y[!is.na(y)]
  }
  n <- nrow(d)
  if (n < 30) {
    whatif_refuse("DATA_TOO_FEW", "Too few respondents",
      sprintf("Only %d respondents have an outcome answer after the base filter.", n),
      "A model on so few respondents says nothing reliable.",
      "Check the base filter and the outcome question.")
  }

  # ---- weights
  w <- NULL
  if (!is.null(s$weight_variable)) {
    need_col(s$weight_variable, "weight_variable")
    w <- suppressWarnings(as.numeric(d[[s$weight_variable]]))
    if (anyNA(w) || any(w <= 0)) {
      whatif_refuse("DATA_WEIGHTS_INVALID", "Weights missing or not positive",
        sprintf("'%s' has %d missing or non-positive weights among the %d respondents modelled.",
                s$weight_variable, sum(is.na(w) | w <= 0), n),
        "A respondent with no usable weight would drop out of every number silently.",
        "Fix the weights, or clear weight_variable for an unweighted run.")
    }
  }

  # ---- levers and symptoms
  scale <- list(min = s$scale_min, max = s$scale_max, centre = s$scale_centre, good = s$scale_good)
  levers <- list()
  symptoms <- list()
  lever_info <- list()
  for (i in seq_len(nrow(cfg$levers))) {
    row <- cfg$levers[i, ]
    include <- toupper(substr(row$Include %||% "Y", 1, 1))
    if (is.na(include)) include <- "Y"
    if (include == "N") next
    kind <- tolower(row$Kind)
    items <- trimws(strsplit(row$Questions, ";", fixed = TRUE)[[1]])
    for (q in items) need_col(q, sprintf("Lever '%s'", row$Key))
    if (include == "S" || kind == "coverage") {
      codes <- trimws(strsplit(row$CoverageValues %||% "", ";", fixed = TRUE)[[1]])
      if (!length(codes) || all(codes == "")) {
        whatif_refuse("CFG_COVERAGE_VALUES", "Coverage lever needs CoverageValues",
          sprintf("'%s' is a coverage lever or symptom with no CoverageValues.", row$Key),
          "Without them the engine cannot tell who has the service.",
          "List the answers that mean 'has it', separated by semicolons (for example Yes).")
      }
      flag <- as.numeric(d[[items[1]]] %in% codes)
      if (include == "S") {
        symptoms[[length(symptoms) + 1]] <- list(key = row$Key, label = row$Label %||% row$Key,
                                                 flag = flag, why = row$Note %||% "")
        next
      }
      lv <- list(key = row$Key, label = row$Label %||% row$Key, kind = "coverage", values = flag,
                 expected = whatif_expected(row))
      levers[[length(levers) + 1]] <- lv
      lever_info[[row$Key]] <- list(items = items, dk = 0L, answered = mean(!is.na(d[[items[1]]])),
                                    has = sum(flag))
      next
    }
    scored <- lapply(items, function(q) whatif_score_answers(d[[q]], opts[[q]]))
    vals <- sapply(scored, `[[`, "value")
    if (!is.matrix(vals)) vals <- matrix(vals, ncol = length(items))
    off <- !is.na(vals) & (vals < scale$min | vals > scale$max)
    if (any(off)) {
      whatif_refuse("DATA_LEVER_OFF_SCALE", "Lever answers outside the scale",
        sprintf("Lever '%s' has %d answers outside %s to %s.", row$Key, sum(off), scale$min, scale$max),
        "Moves are clipped to the scale; an off-scale answer breaks them.",
        "Set scale_min and scale_max to the questions' scale, or check the Options sheet order.")
    }
    has <- if (kind == "nested") {
      if (!is.na(row$HasQuestion)) {
        need_col(row$HasQuestion, sprintf("Lever '%s' HasQuestion", row$Key))
        hv <- trimws(strsplit(row$HasValues %||% "", ";", fixed = TRUE)[[1]])
        hq <- d[[row$HasQuestion]]
        if (length(hv) && any(hv != "")) hq %in% hv else !is.na(hq)
      } else rowSums(!is.na(vals)) > 0
    } else rep(TRUE, n)
    # Don't-know answers (given, but not on the scale) take the dont_know
    # rule's value. A blank item (not asked) is left out of the respondent's
    # average, so a lever built from either/or questions (registration for new
    # students, re-registration for returning ones) averages what was asked.
    # A respondent with no usable item at all takes the rule's value too.
    fill <- vapply(seq_along(items), function(j) {
      f <- if (s$dont_know == "centre") scale$centre else round(stats::median(vals[has, j], na.rm = TRUE))
      if (is.na(f)) scale$centre else f
    }, numeric(1))
    dk <- sapply(scored, `[[`, "dk")
    if (!is.matrix(dk)) dk <- matrix(dk, ncol = length(items))
    n_dk <- 0L
    for (j in seq_along(items)) {
      miss <- dk[, j] & has
      vals[miss, j] <- fill[j]
      n_dk <- n_dk + sum(miss)
    }
    none <- has & rowSums(!is.na(vals)) == 0
    if (any(none)) {
      vals[none, ] <- matrix(fill, sum(none), length(items), byrow = TRUE)
      n_dk <- n_dk + sum(none)
    }
    v <- rowMeans(vals, na.rm = TRUE)
    v[!has] <- NA_real_
    lv <- list(key = row$Key, label = row$Label %||% row$Key, kind = kind, values = v,
               expected = whatif_expected(row), missing = n_dk,
               sub = row$Note %||% "", has_label = row$HasLabel)
    if (!is.na(row$Target)) lv$target <- suppressWarnings(as.numeric(row$Target))
    if (kind == "nested") lv$has <- has
    levers[[length(levers) + 1]] <- lv
    lever_info[[row$Key]] <- list(items = items, dk = n_dk,
                                  answered = mean(rowSums(!is.na(sapply(items, function(q) d[[q]]))) > 0),
                                  has = sum(has))
  }
  if (!length(levers)) {
    whatif_refuse("CFG_NO_LEVERS", "No levers included",
      "Every row on the Levers sheet has Include = N or Symptom.",
      "The model needs at least one lever.",
      "Set Include = Y for the levers to model.")
  }

  # ---- context
  context <- list()
  for (i in seq_len(nrow(cfg$context))) {
    row <- cfg$context[i, ]
    need_col(row$Question, sprintf("Context '%s'", row$Key))
    context[[row$Key]] <- list(label = row$Label %||% row$Key,
                               values = whatif_context_values(row, d[[row$Question]],
                                                              opts[[row$Question]], cfg$recodes),
                               order = row$Order)
  }

  # ---- profile, structure, bundles
  prof_keys <- if (isTRUE(s$profile_builder)) {
    k <- cfg$sentence$Key[!is.na(cfg$sentence$Key)]
    if (!length(k)) cfg$context$Key[whatif_flag(cfg$context$Profile)] else unique(k)
  } else character(0)
  profile <- if (length(prof_keys)) list(
    keys = prof_keys,
    structural = intersect(cfg$context$Key[whatif_flag(cfg$context$Structural)], prof_keys),
    rules = if (nrow(cfg$structure)) data.frame(key1 = cfg$structure$Key1, level1 = cfg$structure$Level1,
                                                key2 = cfg$structure$Key2, level2 = cfg$structure$Level2,
                                                stringsAsFactors = FALSE) else NULL
  ) else NULL
  bundles <- lapply(seq_len(nrow(cfg$bundles)), function(i) {
    b <- cfg$bundles[i, ]
    parts <- trimws(strsplit(b$Moves %||% "", ";", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    kv <- strsplit(parts, "=", fixed = TRUE)
    if (!length(kv) || any(lengths(kv) != 2)) {
      whatif_refuse("CFG_BUNDLE_MOVES", "Bundle moves not understood",
        sprintf("Bundle '%s' Moves '%s' is not in the form key=move; key=move.", b$Name, b$Moves %||% ""),
        "A bundle combines named moves on named levers.",
        "Write the moves like Q025=up1; Q026=up1.")
    }
    list(name = b$Name, text = b$Description %||% "",
         moves = stats::setNames(trimws(vapply(kv, `[`, "", 2)), trimws(vapply(kv, `[`, "", 1))))
  })

  spec <- list(
    id = s$output_name,
    y = as.integer(y),
    outcome = list(levels = s$outcome_labels, score = s$outcome_scores, score_label = s$outcome_score_label),
    weights = w,
    scale = scale,
    levers = levers,
    context = lapply(context, function(cx) cx[c("label", "values")]),
    baselines = cfg$context$Key[whatif_flag(cfg$context$Baseline)],
    profile = profile,
    bundles = bundles,
    n_boot = s$n_boot,
    seed = s$seed
  )
  whatif_say(sprintf("data: %d rows in the file, %d removed by the base filter, %d with no banded outcome; %d modelled",
                     n_file, n_filtered_out, n_no_outcome, n), verbose = verbose)
  list(spec = spec, ids = ids, data = d, options = opts, lever_info = lever_info,
       symptoms = symptoms, context_order = lapply(context, `[[`, "order"),
       dropped = list(n_file = n_file, base_filter = n_filtered_out, no_outcome = n_no_outcome, n = n),
       paths = list(data = data_path, structure = structure_path))
}


#' Expected Direction from a Levers Row
#' @keywords internal
whatif_expected <- function(row) {
  e <- suppressWarnings(as.numeric(row$Expected))
  if (is.na(row$Expected) || is.na(e)) return(1)
  if (!e %in% c(-1, 1)) {
    whatif_refuse("CFG_LEVER_EXPECTED", "Expected must be 1 or -1",
      sprintf("Lever '%s' has Expected '%s'.", row$Key, row$Expected),
      "The sign check compares each refit with this direction.",
      "Use 1 (higher raises the outcome) or -1.")
  }
  e
}


#' Context Values for One Variable
#'
#' Order of steps: missing label, BoxCategory (Levels = box), Recodes, then
#' levels under CollapseUnder respondents merged into CollapseLabel.
#'
#' @keywords internal
whatif_context_values <- function(row, x, opts, recodes) {
  v <- x
  if (!is.na(row$Levels) && tolower(row$Levels) == "display") {
    if (is.null(opts)) {
      whatif_refuse("CFG_CONTEXT_DISPLAY", "DisplayText needs the Survey_Structure",
        sprintf("Context '%s' uses Levels = display, but %s has no options in the Survey_Structure.",
                row$Key, row$Question),
        "Display labels come from the Options sheet.",
        "Set structure_file, or use Recodes instead.")
    }
    dt <- opts$display[match(v, opts$text)]
    v <- ifelse(!is.na(dt) & dt != "", dt, v)
  }
  if (!is.na(row$Levels) && tolower(row$Levels) %in% c("box", "boxcategory")) {
    if (is.null(opts)) {
      whatif_refuse("CFG_CONTEXT_BOX", "BoxCategory needs the Survey_Structure",
        sprintf("Context '%s' uses Levels = box, but %s has no options in the Survey_Structure.",
                row$Key, row$Question),
        "BoxCategory groups come from the Options sheet.",
        "Set structure_file, or use Recodes instead.")
    }
    bx <- opts$box[match(v, opts$text)]
    v <- ifelse(!is.na(bx) & bx != "", bx, v)
  }
  rc <- recodes[recodes$Key == row$Key, , drop = FALSE]
  if (nrow(rc)) {
    to <- rc$To[match(v, rc$From)]
    v <- ifelse(!is.na(to), to, v)
    if (any(is.na(rc$From))) v[is.na(x)] <- rc$To[is.na(rc$From)][1]
  }
  v[is.na(v)] <- row$MissingLabel %||% "Not said"
  cu <- suppressWarnings(as.numeric(row$CollapseUnder))
  if (!is.na(cu) && cu > 1) {
    tab <- table(v)
    small <- names(tab)[tab < cu]
    if (length(small)) v[v %in% small] <- row$CollapseLabel %||% "Other"
  }
  v
}
