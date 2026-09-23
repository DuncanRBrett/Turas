# ==============================================================================
# WHAT IF - GUARD LAYER
# ==============================================================================
#
# Validates a study spec before anything is fitted. The spec is the in-memory
# form of a What if study (session 2 builds it from a config workbook):
#
#   id          study id, one string
#   y           outcome codes 1..n_cat, lowest category first, no NA
#   outcome     list(levels, score, score_label): category labels low to high,
#               and the score each category contributes to the headline number
#               (NPS: -100, 0, 100)
#   weights     NULL or positive numbers, one per respondent
#   scale       list(min, max, centre, good) for rating and nested levers
#   levers      list of levers: key, label, kind (rating | nested | coverage),
#               values, has (nested only), optional target and expected (+1/-1)
#   context     named list: key -> list(label, values), one value per respondent
#   baselines   context keys entered in the lever model as ridge-penalised
#               baselines (empty = ratings only)
#   profile     optional list(keys, structural, rules) for "Build a ..."
#   bundles     optional list of list(name, text, moves = c(lever_key = move))
#
# Read spec fields with [[ ]] where a name could be the start of another
# (profile and penalty_grid_profile are safe today; keep it that way): `$` on a
# list matches partial names, and a missing profile once picked up a penalty
# grid instead.
#
# Every failure is a TRS refusal naming the field and the fix.
#
# ==============================================================================

WHATIF_LEVER_KINDS <- c("rating", "nested", "coverage")

#' Validate a What if Study Spec
#'
#' @param spec Study spec (see file header)
#' @return The spec with defaults filled in. Refuses on any problem.
#' @keywords internal
whatif_guard_spec <- function(spec) {
  if (!is.list(spec)) {
    whatif_refuse("CFG_SPEC_NOT_LIST", "Study spec is not a list",
      "The What if engine was given something other than a study spec list.",
      "Without a spec the engine cannot know the outcome, the levers or the groups.",
      "Pass the list built from the What if config.")
  }
  spec <- whatif_guard_outcome(spec)
  n <- length(spec$y)
  spec <- whatif_guard_weights(spec, n)
  spec <- whatif_guard_levers(spec, n)
  spec <- whatif_guard_context(spec, n)
  spec <- whatif_guard_bundles(spec)
  spec <- whatif_guard_settings(spec)
  spec
}


#' @keywords internal
whatif_guard_outcome <- function(spec) {
  y <- spec$y
  oc <- spec$outcome
  if (is.null(oc) || is.null(oc[["levels"]]) || is.null(oc[["score"]])) {
    whatif_refuse("CFG_OUTCOME_MISSING", "Outcome not defined",
      "The spec has no outcome levels and scores.",
      "The headline number (NPS or a top-box share) is built from the category scores.",
      "Set outcome = list(levels = c(...), score = c(...)), lowest category first.")
  }
  n_cat <- length(oc$levels)
  if (n_cat < 2 || length(oc$score) != n_cat || any(!is.finite(oc$score))) {
    whatif_refuse("CFG_OUTCOME_SCORE", "Outcome levels and scores do not match",
      sprintf("The outcome has %d levels and %d scores; it needs at least 2 levels and one finite score per level.",
              n_cat, length(oc$score)),
      "Each category's score feeds the headline number; a missing score makes it undefined.",
      "Give one score per outcome level, for example c(-100, 0, 100) for NPS.")
  }
  if (is.null(y) || length(y) == 0 || any(is.na(y)) || any(y != round(y)) ||
      any(y < 1) || any(y > n_cat)) {
    whatif_refuse("DATA_OUTCOME_CODES", "Outcome codes out of range",
      sprintf("The outcome must be whole numbers from 1 to %d with no missing values.", n_cat),
      "Respondents without a valid outcome cannot enter the model.",
      "Drop respondents with no outcome answer and code the outcome 1 (lowest) upward.",
      details = sprintf("Observed values: %s", paste(utils::head(sort(unique(y)), 10), collapse = ", ")))
  }
  counts <- tabulate(y, n_cat)
  if (any(counts == 0)) {
    whatif_refuse("DATA_OUTCOME_EMPTY_CATEGORY", "An outcome category is empty",
      sprintf("Outcome category '%s' has no respondents.", oc$levels[which(counts == 0)[1]]),
      "An ordinal model cannot place a threshold for a category nobody is in.",
      "Merge the empty category with its neighbour in the outcome banding.")
  }
  spec$y <- as.integer(y)
  if (is.null(oc$score_label)) spec$outcome$score_label <- "Score"
  spec$n_cat <- n_cat
  spec
}


#' @keywords internal
whatif_guard_weights <- function(spec, n) {
  w <- spec$weights
  if (is.null(w)) {
    spec$weights <- rep(1, n)
    spec$weighted <- FALSE
    return(spec)
  }
  if (length(w) != n || any(!is.finite(w)) || any(w <= 0)) {
    whatif_refuse("DATA_WEIGHTS_INVALID", "Weights are not usable",
      sprintf("Weights must be %d positive, finite numbers (one per respondent).", n),
      "A zero, negative or missing weight silently drops or reverses a respondent.",
      "Check the weight variable, or set weights to NULL for an unweighted run.",
      details = sprintf("Length %d; non-finite %d; not positive %d",
                        length(w), sum(!is.finite(w)), sum(is.finite(w) & w <= 0)))
  }
  spec$weights <- as.numeric(w)
  spec$weighted <- TRUE
  spec
}


#' @keywords internal
whatif_guard_levers <- function(spec, n) {
  levers <- spec$levers
  if (!is.list(levers) || length(levers) == 0) {
    whatif_refuse("CFG_NO_LEVERS", "No levers",
      "The spec has no levers.",
      "The What if model links the outcome to levers; with none there is nothing to simulate.",
      "Add at least one lever (a rating, nested rating or coverage question).")
  }
  sc <- spec$scale
  keys <- vapply(levers, function(lv) as.character(lv$key %||% ""), character(1))
  if (any(!nzchar(keys)) || anyDuplicated(keys)) {
    whatif_refuse("CFG_LEVER_KEYS", "Lever keys missing or repeated",
      "Every lever needs its own key.",
      "Moves and bundles find a lever by its key; a repeated key would move the wrong lever.",
      "Give each lever a unique key, usually its question code.",
      details = paste("Keys:", paste(keys, collapse = ", ")))
  }
  needs_scale <- any(vapply(levers, function(lv) lv$kind %in% c("rating", "nested"), logical(1)))
  if (needs_scale) {
    ok <- is.list(sc) && all(c("min", "max", "centre", "good") %in% names(sc)) &&
      all(vapply(sc[c("min", "max", "centre", "good")], function(v) is.numeric(v) && length(v) == 1 && is.finite(v), logical(1))) &&
      sc$min < sc$max && sc$centre >= sc$min && sc$centre <= sc$max &&
      sc$good >= sc$min && sc$good <= sc$max
    if (!ok) {
      whatif_refuse("CFG_SCALE_INVALID", "Rating scale not defined",
        "Rating levers need scale = list(min, max, centre, good) with min < max and centre and good inside the scale.",
        "Moves are clipped to the scale and the fix lifts respondents to 'good'; without them the moves are undefined.",
        "Set the scale, for example list(min = 1, max = 5, centre = 3, good = 4).")
    }
  }
  for (i in seq_along(levers)) {
    levers[[i]] <- whatif_guard_one_lever(levers[[i]], n, sc)
  }
  spec$levers <- levers
  spec
}


#' @keywords internal
whatif_guard_one_lever <- function(lv, n, sc) {
  key <- lv$key
  if (is.null(lv$label)) lv$label <- key
  if (!isTRUE(lv$kind %in% WHATIF_LEVER_KINDS)) {
    whatif_refuse("CFG_LEVER_KIND", "Unknown lever kind",
      sprintf("Lever '%s' has kind '%s'.", key, paste(lv$kind, collapse = " ")),
      "The kind decides how the lever enters the model and which moves apply.",
      "Set kind to rating, nested or coverage.")
  }
  v <- lv$values
  if (!is.numeric(v) || length(v) != n) {
    whatif_refuse("DATA_LEVER_LENGTH", "Lever values do not match the respondents",
      sprintf("Lever '%s' has %d numeric values; the outcome has %d respondents.", key, length(v), n),
      "Each respondent needs one value per lever, in the same order as the outcome.",
      "Build every lever from the same respondent rows as the outcome.")
  }
  lv$expected <- lv$expected %||% 1
  if (!isTRUE(lv$expected %in% c(-1, 1))) {
    whatif_refuse("CFG_LEVER_EXPECTED", "Expected direction must be +1 or -1",
      sprintf("Lever '%s' has expected direction %s.", key, paste(lv$expected, collapse = " ")),
      "The sign check counts refits that point against the expected direction.",
      "Use +1 when a higher value should raise the outcome, -1 when it should lower it.")
  }
  if (lv$kind == "coverage") {
    if (any(is.na(v)) || any(!v %in% c(0, 1))) {
      whatif_refuse("DATA_COVERAGE_NOT_BINARY", "Coverage lever is not 0 or 1",
        sprintf("Coverage lever '%s' must be 1 (has the service) or 0 (does not), with no missing values.", key),
        "Extend and withdraw switch the service on or off; other values have no meaning.",
        "Recode the question to 0 and 1 before it enters the spec.")
    }
    return(lv)
  }
  lv$target <- lv$target %||% sc$good
  if (!is.numeric(lv$target) || length(lv$target) != 1 || lv$target < sc$min || lv$target > sc$max) {
    whatif_refuse("CFG_LEVER_TARGET", "Fix target outside the scale",
      sprintf("Lever '%s' has fix target %s; the scale runs %s to %s.", key,
              paste(lv$target, collapse = " "), sc$min, sc$max),
      "The fix lifts respondents to the target; a target off the scale is not a rating anyone can give.",
      "Set the target to a point on the scale, usually the 'good' point.")
  }
  if (lv$kind == "rating") {
    if (any(is.na(v))) {
      whatif_refuse("DATA_LEVER_MISSING", "Rating lever has missing values",
        sprintf("Rating lever '%s' has %d missing values.", key, sum(is.na(v))),
        "The model needs every respondent's rating; dropping them silently changes the sample.",
        c("Set don't-know answers to the question's middle or median rating before building the spec, and say so in the notes.",
          "Or, if the question is routed, make the lever nested with has = answered."))
    }
  } else {
    has <- lv$has
    if (!is.logical(has) || length(has) != n || any(is.na(has))) {
      whatif_refuse("DATA_NESTED_HAS", "Nested lever needs 'has'",
        sprintf("Nested lever '%s' needs has = TRUE/FALSE for all %d respondents.", key, n),
        "A nested rating only exists for respondents who have the service.",
        "Set has to TRUE where the respondent was asked the rating.")
    }
    if (any(is.na(v[has]))) {
      whatif_refuse("DATA_LEVER_MISSING", "Nested lever missing where it applies",
        sprintf("Nested lever '%s' has %d missing ratings among respondents who have the service.", key, sum(is.na(v[has]))),
        "Those respondents would enter the model with no rating.",
        "Impute don't-know answers or set has = FALSE for them.")
    }
    if (!any(has) || all(has)) {
      whatif_refuse("DATA_NESTED_NO_CONTRAST", "Nested lever has no contrast",
        sprintf("Nested lever '%s' applies to %s respondents.", key, if (any(has)) "all" else "no"),
        "The model cannot separate having the service from its rating.",
        "Use kind = rating when everyone was asked, or drop the lever.")
    }
  }
  vv <- if (lv$kind == "nested") v[lv$has] else v
  if (any(vv < sc$min | vv > sc$max)) {
    whatif_refuse("DATA_LEVER_OFF_SCALE", "Lever values outside the scale",
      sprintf("Lever '%s' has values outside %s to %s.", key, sc$min, sc$max),
      "Moves are clipped to the scale, so an off-scale value breaks every move.",
      "Recode the question onto the study scale before it enters the spec.",
      details = sprintf("Range observed: %s to %s", min(vv), max(vv)))
  }
  lv
}


#' @keywords internal
whatif_guard_context <- function(spec, n) {
  ctx <- spec$context %||% list()
  if (length(ctx) && (is.null(names(ctx)) || any(!nzchar(names(ctx))))) {
    whatif_refuse("CFG_CONTEXT_NAMES", "Context variables need names",
      "Every context variable must be named by its key.",
      "Baselines, groups and the profile builder find context variables by key.",
      "Pass context as a named list: key = list(label, values).")
  }
  for (k in names(ctx)) {
    v <- ctx[[k]]$values
    if (is.null(ctx[[k]]$label)) ctx[[k]]$label <- k
    if (length(v) != n || any(is.na(v))) {
      whatif_refuse("DATA_CONTEXT_INVALID", "Context variable incomplete",
        sprintf("Context '%s' needs %d values with none missing (found %d values, %d missing).",
                k, n, length(v), sum(is.na(v))),
        "A respondent with no value falls out of every group and baseline built on it.",
        "Fill missing context values with an explicit level such as 'Not said'.")
    }
    ctx[[k]]$values <- as.character(v)
  }
  spec$context <- ctx
  check_keys <- function(keys, what) {
    bad <- setdiff(keys, names(ctx))
    if (length(bad)) {
      whatif_refuse("CFG_CONTEXT_UNKNOWN", sprintf("Unknown context in %s", what),
        sprintf("The %s names context keys that are not in the spec: %s.", what, paste(bad, collapse = ", ")),
        "The engine cannot use a variable it was not given.",
        "Add the variable to context or remove it from the list.")
    }
  }
  spec$baselines <- as.character(spec$baselines %||% character(0))
  check_keys(spec$baselines, "baselines")
  if (!is.null(spec[["profile"]])) {
    pr <- spec[["profile"]]
    check_keys(pr$keys, "profile")
    pr$structural <- as.character(pr$structural %||% character(0))
    if (length(setdiff(pr$structural, pr$keys))) {
      whatif_refuse("CFG_STRUCTURAL_NOT_PROFILE", "Structural trait not in the profile",
        sprintf("Structural traits must be profile keys: %s is not.",
                paste(setdiff(pr$structural, pr$keys), collapse = ", ")),
        "Structure rules constrain the profile sentence; a trait outside it cannot be constrained.",
        "Add the trait to the profile keys or remove it from structural.")
    }
    pr$rules <- whatif_guard_rules(pr$rules, pr$structural, ctx)
    spec[["profile"]] <- pr
  }
  spec
}


#' Validate Structure Rules
#'
#' A rule blocks one combination of two structural levels, for example
#' course = "Bachelor of Social Work" with year = "Masters". Rules may name
#' structural traits only: personal traits are never blocked (brief decision 10).
#'
#' @param rules NULL or data frame with key1, level1, key2, level2
#' @param structural Structural profile keys
#' @param ctx Context list
#' @return Data frame of rules (possibly empty)
#' @keywords internal
whatif_guard_rules <- function(rules, structural, ctx) {
  empty <- data.frame(key1 = character(0), level1 = character(0),
                      key2 = character(0), level2 = character(0), stringsAsFactors = FALSE)
  if (is.null(rules) || NROW(rules) == 0) return(empty)
  need <- c("key1", "level1", "key2", "level2")
  if (!is.data.frame(rules) || !all(need %in% names(rules))) {
    whatif_refuse("CFG_RULES_COLUMNS", "Structure rules malformed",
      "Structure rules must be a table with columns key1, level1, key2, level2.",
      "Each row blocks one impossible combination in Build a ...; a malformed table blocks nothing.",
      "Build the rules table with those four columns.")
  }
  rules <- data.frame(lapply(rules[need], as.character), stringsAsFactors = FALSE)
  personal <- setdiff(unique(c(rules$key1, rules$key2)), structural)
  if (length(personal)) {
    whatif_refuse("CFG_RULE_ON_PERSONAL_TRAIT", "Structure rule on a personal trait",
      sprintf("Structure rules may only name structural traits; these are not: %s.", paste(personal, collapse = ", ")),
      "A combination nobody in the sample has can still be a real person (a male Masters student); blocking it would be wrong.",
      "Remove the rule, or mark the trait structural if the programme or business really fixes it.")
  }
  for (i in seq_len(nrow(rules))) {
    for (s in 1:2) {
      k <- rules[[paste0("key", s)]][i]
      l <- rules[[paste0("level", s)]][i]
      if (!l %in% ctx[[k]]$values) {
        whatif_refuse("CFG_RULE_UNKNOWN_LEVEL", "Structure rule names an unknown level",
          sprintf("Rule %d names %s = '%s', which no respondent has.", i, k, l),
          "A rule on a misspelt level blocks nothing and hides the typo.",
          "Correct the level text to match the data exactly.")
      }
    }
    if (rules$key1[i] == rules$key2[i]) {
      whatif_refuse("CFG_RULE_SAME_TRAIT", "Structure rule pairs a trait with itself",
        sprintf("Rule %d pairs %s with itself.", i, rules$key1[i]),
        "A profile has one level per trait, so the rule can never apply.",
        "Pair two different structural traits.")
    }
  }
  rules
}


#' @keywords internal
whatif_guard_bundles <- function(spec) {
  keys <- vapply(spec$levers, `[[`, character(1), "key")
  for (b in spec$bundles %||% list()) {
    mv <- b$moves
    if (is.null(b$name) || !length(mv) || is.null(names(mv)) || length(setdiff(names(mv), keys))) {
      whatif_refuse("CFG_BUNDLE_INVALID", "Bundle names unknown levers",
        sprintf("Bundle '%s' must name levers in the spec: %s.", b$name %||% "?",
                paste(setdiff(names(mv), keys), collapse = ", ")),
        "A bundle that moves a lever the model does not have would report a gain it never computed.",
        "Use lever keys exactly as they appear in the levers list.")
    }
    for (k in names(mv)) {
      lv <- spec$levers[[match(k, keys)]]
      if (!mv[[k]] %in% whatif_moves_for_kind(lv$kind)) {
        whatif_refuse("CFG_BUNDLE_MOVE", "Bundle move does not fit the lever",
          sprintf("Bundle '%s' asks lever '%s' (%s) to '%s'.", b$name, k, lv$kind, mv[[k]]),
          "Rating moves do not apply to coverage levers, and the reverse.",
          sprintf("Use one of: %s.", paste(whatif_moves_for_kind(lv$kind), collapse = ", ")))
      }
    }
  }
  spec
}


#' @keywords internal
whatif_guard_settings <- function(spec) {
  spec$n_boot <- as.integer(spec$n_boot %||% 100L)
  spec$seed <- as.integer(spec$seed %||% 20260923L)
  spec$folds <- as.integer(spec$folds %||% 5L)
  spec$cv_seed <- as.integer(spec$cv_seed %||% 7L)
  spec$penalty_levers <- spec$penalty_levers %||% WHATIF_LEVER_PENALTY
  spec$penalty_grid_baselines <- spec$penalty_grid_baselines %||% WHATIF_BASELINE_PENALTIES
  spec$penalty_grid_profile <- spec$penalty_grid_profile %||% WHATIF_PROFILE_PENALTIES
  if (is.na(spec$n_boot) || spec$n_boot < 0 || is.na(spec$folds) || spec$folds < 2 ||
      length(spec$y) < 2 * spec$folds) {
    whatif_refuse("CFG_SETTINGS_INVALID", "Bootstrap or fold settings invalid",
      sprintf("n_boot must be 0 or more and folds at least 2 with twice as many respondents (n_boot %s, folds %s, n %d).",
              spec$n_boot, spec$folds, length(spec$y)),
      "Ranges and the cross-validated penalty depend on these settings.",
      "Use the defaults: n_boot = 100, folds = 5.")
  }
  if (any(spec$penalty_grid_baselines <= 0) || any(spec$penalty_grid_profile <= 0) || spec$penalty_levers < 0) {
    whatif_refuse("CFG_PENALTY_INVALID", "Penalty grid invalid",
      "Baseline and profile penalties must be positive; the lever penalty must be zero or more.",
      "With no penalty the context terms overfit, which is the calibration problem the baselines exist to fix.",
      "Use the default grids.")
  }
  spec
}


#' Null-Default Operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
