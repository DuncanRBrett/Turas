#!/usr/bin/env Rscript
# ==============================================================================
# WHAT IF - SESSION 2 CHECK: THE CONFIGS REPRODUCE THE PROTOTYPE
# ==============================================================================
#
# Runs the SACAP 2025 and CCPB 2026 configs (build_study_configs.R) through the
# config reader and data preparation, with context baselines OFF so the lever
# model is the prototype's, and prints the numbers the prototypes produced
# beside them. Reads client data; writes nothing.
#
# Usage, from the Turas root:
#   Rscript modules/whatif/dev/verify_configs.R <config folder>
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
cfg_dir <- if (length(args)) args[1] else "."
source(file.path("modules", "whatif", "source_whatif.R"))

fit_without_baselines <- function(path) {
  cfg <- whatif_read_config(path)
  cfg$context$Baseline <- "N"
  prep <- whatif_prepare(cfg, verbose = FALSE)
  prep$spec$weights <- NULL   # the prototypes' numbers are unweighted
  model <- whatif_run_engine_impl(prep$spec, verbose = FALSE)
  list(cfg = cfg, prep = prep, model = model)
}
show_levers <- function(model, masks, proto) {
  res <- whatif_group_results_impl(model, masks)
  for (g in names(res)) {
    lv <- res[[g]]$levers
    cat(sprintf("\n  %s: n %d, actual %.1f\n", g, res[[g]]$n, res[[g]]$actual))
    for (key in unique(lv$key)) {
      r <- lv[lv$key == key, ]
      cat(sprintf("    %-10s %s | need %d\n", key,
                  paste(sprintf("%s %+.1f", r$move, r$est), collapse = "  "), r$need[1]))
    }
  }
  res
}

# ---------------------------------------------------------------- SACAP
cat("==== SACAP 2025 (baselines off), against study_sacap.py ====\n")
s <- fit_without_baselines(file.path(cfg_dir, "SACAP_Student_Annual-2025_WhatIf_Config.xlsx"))
m <- s$model
proto_b <- c(0.39866, 0.05111, 0.51667, 0.91122, 0.21973, 0.26793, 0.1535, 0.05558)
cat(sprintf("n %d; largest coefficient difference from the prototype %.2e; thresholds %.5f %.5f (prototype 0.42593 2.16351)\n",
            length(m$spec$y), max(abs(m$main$b - proto_b)), m$main$theta[1], m$main$theta[2]))
res <- show_levers(m, list(all = rep(TRUE, length(m$spec$y))))
v <- res$all$levers[res$all$levers$key == "Q021", ]
cat(sprintf("\n  VALUE FOR MONEY slip1 %.1f, lift to Good %.1f (prototype -26.3, +14.1)\n",
            v$est[v$move == "slip1"], v$est[v$move == "floor"]))
cat("  Bundles:", paste(sprintf("%s %.1f", res$all$bundles$name, res$all$bundles$est), collapse = "; "),
    "(prototype Teaching 16.4, Service 8.1)\n")

# ---------------------------------------------------------------- CCPB
cat("\n==== CCPB 2026 (no baselines in its config), against study_ccpb.py ====\n")
c2 <- fit_without_baselines(file.path(cfg_dir, "CCPB_CSAT_W2026_WhatIf_Config.xlsx"))
m <- c2$model
proto_b <- c(0.31644, 0.47303, 0.03766, 0.10871, 0.38378, -0.12933, 0.20865, 0.44788, 0.66424, 0.66904, 0.18495)
cat("  R:        ", sprintf("%.5f", m$main$b), "\n  prototype:", sprintf("%.5f", proto_b), "\n")
cat(sprintf("n %d; largest coefficient difference %.2e; thresholds %.5f %.5f (prototype -2.48850 0.36097); held-out %.3f (prototype 0.172)\n",
            length(m$spec$y), max(abs(m$main$b - proto_b)), m$main$theta[1], m$main$theta[2], m$cv_r2))
cat("  missing set to the median:", paste(vapply(m$spec$levers, function(lv) sprintf("%s %d", lv$key, lv$missing %||% 0L), ""),
                                          collapse = ", "), "(prototype ordering 12, delivery 18, invoicing 10, merch 15, rep 169)\n")
spaza <- m$spec$context$channel$values == "Spaza"
res <- show_levers(m, list(all = rep(TRUE, length(m$spec$y)), spaza = spaza))
cat("  Prototype, all outlets, slip1 / up1: ordering -4.5 / 1.7; delivery -7.1 / 4.4; rep -5.5 / 3.3; coolers withdraw -5.1 extend 1.2; mgr extend 5.8; ccpbmerch extend 6.6\n")
cat("  Prototype need: 26, 97, 48, 90, 99, 51, 135, 538, 592, 480; Spaza n 186, actual 82.3\n")
fits <- list(m$main)
eta <- drop(m$design$X %*% m$main$b)
e2 <- eta + m$main$b[["delivery_val"]] * m$deltas$delivery$slip1 + m$main$b[["rep_val"]] * m$deltas$rep$slip1
w <- m$spec$weights
change <- stats::weighted.mean(whatif_score_vec(m$main, e2, c(-100, 0, 100))[spaza] -
                               whatif_score_vec(m$main, eta, c(-100, 0, 100))[spaza], w[spaza])
cat(sprintf("  Spaza, delivery and rep both slip one point: %.1f -> %.1f (prototype 82 -> 69 exact)\n",
            res$spaza$actual, res$spaza$actual + change))
