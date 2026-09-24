# ==============================================================================
# WHAT IF - PREFLIGHT
# ==============================================================================
#
# Checks that need judgement rather than a refusal. Each finding is a row in
# keydriver's preflight log shape: Component, Check, Field, Message, Severity
# (Error / Warning / Info). Warnings make the run PARTIAL; they never stop it.
#
#   before the fit   outcome categories, don't-know shares, routed questions,
#                    overlapping levers, likely symptoms, coverage with no
#                    contrast, small context levels, proposed Structure rules
#   after the fit    the sign check and the baseline penalty
#
# Proposed Structure rules (brief decision 10): every pair of levels of two
# STRUCTURAL context variables that no respondent has together, where one side
# has at least structure_min_side respondents. They are listed for the analyst
# to confirm on the Structure sheet; the run never applies them by itself.
#
# ==============================================================================

#' Words That Suggest an Outcome or a Symptom Rather Than a Lever
WHATIF_SYMPTOM_WORDS <- c("contact", "call", "complain", "complaint", "switch", "shop around",
                          "recommend", "trust", "loyal", "expectation", "likely", "intend",
                          "shops around")


#' @keywords internal
whatif_log_row <- function(check, field, message, severity) {
  data.frame(Component = "Preflight", Check = check, Field = field, Message = message,
             Severity = severity, stringsAsFactors = FALSE)
}


#' Preflight Checks Before the Fit
#'
#' @param prep Output of whatif_prepare()
#' @param cfg Config
#' @return List with log (data frame) and proposed_structure (data frame)
#' @keywords internal
whatif_preflight <- function(prep, cfg) {
  s <- cfg$settings
  spec <- prep$spec
  rows <- list()
  add <- function(...) rows[[length(rows) + 1]] <<- whatif_log_row(...)
  n <- length(spec$y)

  # outcome
  counts <- tabulate(spec$y, length(spec$outcome$levels))
  add("Outcome", s$outcome_question,
      sprintf("%d modelled: %s. %d rows in the file; %d removed by the base filter; %d with no answer in any outcome band.",
              n, paste(sprintf("%s %d", spec$outcome$levels, counts), collapse = ", "),
              prep$dropped$n_file, prep$dropped$base_filter, prep$dropped$no_outcome), "Info")
  for (k in which(counts < 30)) {
    add("Outcome", spec$outcome$levels[k],
        sprintf("Only %d respondents are %s. Effects at that end of the outcome rest on very few people.",
                counts[k], spec$outcome$levels[k]), "Warning")
  }

  # levers
  q_text <- whatif_question_texts(prep$paths$structure)
  for (lv in spec$levers) {
    info <- prep$lever_info[[lv$key]]
    if (!is.null(lv$missing) && lv$missing > 0) {
      share <- lv$missing / if (lv$kind == "nested") sum(lv$has) else n
      add("Don't know", lv$key,
          sprintf("%d answers (%.0f%%) set to the %s rating: %s.", lv$missing, 100 * share, s$dont_know,
                  paste(info$items, collapse = ", ")),
          if (share > 0.10) "Warning" else "Info")
    }
    if (lv$kind == "rating" && info$answered < 0.90) {
      add("Routed question", lv$key,
          sprintf("Only %.0f%% answered %s. If it was asked of some respondents only, make it a nested lever so moves touch only them.",
                  100 * info$answered, paste(info$items, collapse = ", ")), "Warning")
    }
    if (lv$kind == "coverage") {
      share <- mean(lv$values)
      if (share < 0.05 || share > 0.95) {
        add("Coverage contrast", lv$key,
            sprintf("%.0f%% have it. With so little contrast its effect is poorly measured.", 100 * share), "Warning")
      }
    }
    words <- tolower(paste(lv$label, paste(q_text[info$items], collapse = " ")))
    hit <- WHATIF_SYMPTOM_WORDS[vapply(WHATIF_SYMPTOM_WORDS, grepl, logical(1), x = words, fixed = TRUE)]
    if (length(hit)) {
      add("Possible symptom or outcome", lv$key,
          sprintf("The wording mentions '%s'. Check this is something the client can act on, not a second measure of the outcome or a sign of a problem (set Include = Symptom if so).",
                  paste(hit, collapse = "', '")), "Warning")
    }
  }

  # overlapping levers
  scored <- Filter(function(lv) lv$kind %in% c("rating", "nested"), spec$levers)
  if (length(scored) > 1) {
    M <- sapply(scored, function(lv) lv$values)
    R <- suppressWarnings(stats::cor(M, use = "pairwise.complete.obs"))
    for (a in seq_len(ncol(R) - 1)) for (b in (a + 1):ncol(R)) {
      if (!is.na(R[a, b]) && R[a, b] > s$correlation_flag) {
        add("Overlapping levers", paste(scored[[a]]$key, scored[[b]]$key, sep = " + "),
            sprintf("They correlate at %.2f. Entered separately, one can take the other's effect and flip sign; consider averaging them into one lever.",
                    R[a, b]), "Warning")
      }
    }
  }

  # context
  for (k in names(spec$context)) {
    tab <- table(spec$context[[k]]$values)
    small <- tab[tab < s$min_group]
    if (length(small)) {
      add("Small groups", k,
          sprintf("%d level(s) under the minimum group of %d: %s. Client-safe files will not publish them on their own.",
                  length(small), s$min_group, paste(sprintf("%s (%d)", names(small), small), collapse = ", ")),
          "Info")
    }
  }

  proposed <- whatif_propose_structure(spec, cfg)
  if (nrow(proposed)) {
    add("Proposed Structure rules", "Structure",
        sprintf("%d combination(s) of structural traits that no respondent has, where one side has %d or more. Confirm the real ones on the Structure sheet (see the Proposed_Structure output sheet).",
                nrow(proposed), s$structure_min_side), "Info")
  }
  list(log = do.call(rbind, rows), proposed_structure = proposed)
}


#' Preflight Rows After the Fit
#'
#' @param model Fitted model
#' @return Data frame of log rows (possibly empty)
#' @keywords internal
whatif_preflight_after_fit <- function(model) {
  rows <- list()
  sg <- model$sign
  labels <- stats::setNames(vapply(model$spec$levers, `[[`, "", "label"), sg$key)
  for (i in which(sg$unclear)) {
    rows[[length(rows) + 1]] <- whatif_log_row("Sign check", sg$key[i],
      sprintf("%s points against its expected direction in %.0f%% of refits. It is shown as 'effect unclear'; consider averaging it with the lever it overlaps, or dropping it.",
              labels[[sg$key[i]]], 100 * sg$wrong_share[i]), "Warning")
  }
  for (wmsg in model$warnings[!grepl("^Sign check", model$warnings)]) {
    rows[[length(rows) + 1]] <- whatif_log_row("Model", "", wmsg, "Warning")
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}


#' Propose Structure Rules from the Data
#'
#' @param spec Engine spec
#' @param cfg Config (structural flags, existing rules, structure_min_side)
#' @return Data frame Key1, Level1, N1, Key2, Level2, N2, AlreadyRule
#' @keywords internal
whatif_propose_structure <- function(spec, cfg) {
  keys <- cfg$context$Key[whatif_flag(cfg$context$Structural)]
  min_side <- cfg$settings$structure_min_side
  out <- list()
  if (length(keys) < 2) return(data.frame())
  existing <- paste(cfg$structure$Key1, cfg$structure$Level1, cfg$structure$Key2, cfg$structure$Level2, sep = "\r")
  existing <- c(existing, paste(cfg$structure$Key2, cfg$structure$Level2, cfg$structure$Key1, cfg$structure$Level1, sep = "\r"))
  for (a in seq_len(length(keys) - 1)) for (b in (a + 1):length(keys)) {
    va <- spec$context[[keys[a]]]$values
    vb <- spec$context[[keys[b]]]$values
    tab <- table(va, vb)
    ra <- rowSums(tab)
    cb <- colSums(tab)
    for (i in rownames(tab)) for (j in colnames(tab)) {
      if (tab[i, j] == 0 && (ra[[i]] >= min_side || cb[[j]] >= min_side)) {
        out[[length(out) + 1]] <- data.frame(
          Key1 = keys[a], Level1 = i, N1 = ra[[i]], Key2 = keys[b], Level2 = j, N2 = cb[[j]],
          AlreadyRule = paste(keys[a], i, keys[b], j, sep = "\r") %in% existing,
          stringsAsFactors = FALSE)
      }
    }
  }
  if (!length(out)) return(data.frame())
  do.call(rbind, out)
}


#' Question Texts from the Survey_Structure, if There Is One
#' @keywords internal
whatif_question_texts <- function(path) {
  if (is.null(path) || !file.exists(path)) return(character(0))
  q <- tryCatch(suppressMessages(load_config_table_sheet(path, "Questions",
                                                         required_cols = c("QuestionCode", "QuestionText"),
                                                         col_types = "text")), error = function(e) NULL)
  if (is.null(q) || !all(c("QuestionCode", "QuestionText") %in% names(q))) return(character(0))
  stats::setNames(as.character(q$QuestionText), trimws(as.character(q$QuestionCode)))
}
