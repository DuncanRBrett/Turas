#!/usr/bin/env Rscript
# ==============================================================================
# WHAT IF - ONE-OFF CHECK AGAINST THE PYTHON PROTOTYPE ON SACAP 2025
# ==============================================================================
#
# Session 1 verification (docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md, section 6).
# Not part of the test suite: it reads client data, which never enters tests/
# or git. It writes nothing; every result goes to the console.
#
# The data preparation copies prototypes/nps-simulator/study_sacap.py line for
# line, unweighted (SACAP student reports run unweighted).
#
# Usage, from the Turas root:
#   Rscript modules/whatif/dev/verify_sacap_2025.R <path to
#     SACAP_Student_Annual-2025_Data_weighted.xlsx> [n_boot] [weighted]
#
# Pass "weighted" as the third argument to use the file's weight column; the
# prototype's weighted figures are in prototypes/nps-simulator/PLAN.md.
#
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1 || !file.exists(args[1])) {
  cat("[What if] Give the path to SACAP_Student_Annual-2025_Data_weighted.xlsx as the first argument.\n")
  quit(status = 1)
}
data_path <- args[1]
n_boot <- if (length(args) >= 2) as.integer(args[2]) else 100L
use_weights <- length(args) >= 3 && identical(args[3], "weighted")
cat(sprintf("Run: %s, %d bootstrap refits\n", if (use_weights) "WEIGHTED" else "unweighted", n_boot))

root <- getwd()
source(file.path(root, "modules", "shared", "lib", "trs_refusal.R"))
for (f in sort(list.files(file.path(root, "modules", "whatif", "R"), pattern = "\\.R$", full.names = TRUE))) source(f)

# ---------------------------------------------------------------- data (study_sacap.py)
d <- openxlsx::read.xlsx(data_path, sheet = 1, skipEmptyRows = FALSE, na.strings = "")
d <- d[d$Q001 %in% c("Complete", "Converted"), , drop = FALSE]
s <- suppressWarnings(as.numeric(d$Q017))
stopifnot(!anyNA(s))
cat(sprintf("Respondents: %d (prototype 1361)\n", nrow(d)))

LABELS <- c("Terrible", "Not very good", "About average", "Good", "Excellent")
LEVERS <- list(c("Q025", "Educators delivering content"), c("Q026", "Assessment feedback"),
               c("Q027", "Course content"), c("Q021", "Value for money"), c("Q029", "MySACAP usability"),
               c("Q063", "Staff friendly and approachable"), c("Q064", "Student admin"),
               c("Q065", "Email responsiveness"))
levers <- lapply(LEVERS, function(l) {
  r <- match(d[[l[1]]], LABELS)
  miss <- sum(is.na(r))
  r[is.na(r)] <- round(stats::median(r, na.rm = TRUE))
  list(key = l[1], label = l[2], kind = "rating", values = as.numeric(r), missing = miss)
})
cat("Don't know set to the median:", paste(sprintf("%s %d", vapply(levers, `[[`, "", "key"),
                                                   vapply(levers, `[[`, 0L, "missing")), collapse = ", "),
    "(prototype: Q025 0, Q026 6, Q027 1, Q021 59, Q029 5, Q063 28, Q064 28, Q065 26)\n")

year_band <- function(v) {
  v <- as.character(v)
  out <- rep("Other", length(v))
  out[startsWith(v, "1st")] <- "1st year"
  out[startsWith(v, "2nd")] <- "2nd year"
  out[startsWith(v, "3rd")] <- "3rd year"
  out[grepl("Masters", v, fixed = TRUE)] <- "Masters"
  out[grepl("Honours", v, fixed = TRUE)] <- "Honours"
  out
}
course_raw <- trimws(ifelse(is.na(d$Q005), "Other programmes", as.character(d$Q005)))
course_n <- table(course_raw)[course_raw]
course <- ifelse(course_n >= 40, course_raw, "Other courses")
gender <- ifelse(is.na(d$Q100), "x", as.character(d$Q100))
gender <- ifelse(gender %in% c("Female", "Male"), gender, "Other or not said")
age <- ifelse(is.na(d$Q099), "Not said", as.character(d$Q099))
age[age == "Prefer not to say"] <- "Not said"
context <- list(
  campus = list(label = "Campus", values = trimws(as.character(d$Q002))),
  course = list(label = "Course", values = unname(course)),
  year = list(label = "Year of study", values = year_band(d$Q006)),
  reg = list(label = "New or returning",
             values = ifelse(grepl("1st", as.character(d$Q009), fixed = TRUE), "First-time", "Returning")),
  gender = list(label = "Gender", values = gender),
  age = list(label = "Age", values = age),
  intensity = list(label = "Full or part time",
                   values = ifelse(grepl("Part", as.character(d$Q004), fixed = TRUE), "Part time", "Full time"))
)

spec <- list(
  id = "sacap",
  y = ifelse(s >= 9, 3L, ifelse(s <= 6, 1L, 2L)),
  outcome = list(levels = c("Detractor", "Passive", "Promoter"), score = c(-100, 0, 100), score_label = "NPS"),
  weights = if (use_weights) as.numeric(d$weight) else NULL,
  scale = list(min = 1, max = 5, centre = 3, good = 4),
  levers = levers,
  context = context,
  baselines = character(0),
  profile = list(keys = c("gender", "reg", "age", "intensity", "course", "year", "campus"),
                 structural = c("intensity", "course", "year", "campus"),
                 rules = data.frame(key1 = "course", level1 = "Bachelor of Social Work",
                                    key2 = "year", level2 = "Masters", stringsAsFactors = FALSE)),
  bundles = list(
    list(name = "Teaching", moves = c(Q025 = "up1", Q026 = "up1", Q027 = "up1")),
    list(name = "Service", moves = c(Q063 = "up1", Q064 = "up1", Q065 = "up1"))),
  n_boot = n_boot
)

# ---------------------------------------------------------------- 1. ratings only, against the prototype
cat("\n==== 1. Ratings only (no baselines), against study_sacap.py ====\n")
t0 <- Sys.time()
m0 <- whatif_run_engine(spec)
if (is_refusal(m0)) quit(status = 1)
cat(sprintf("Engine time %.1f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
proto_b <- c(0.39866, 0.05111, 0.51667, 0.91122, 0.21973, 0.26793, 0.1535, 0.05558)
proto_c <- c(0.42593, 2.16351)
cat("Main fit coefficients, R:        ", sprintf("%.5f", m0$main$b), "\n")
cat("Main fit coefficients, prototype:", sprintf("%.5f", proto_b), "\n")
cat(sprintf("Largest coefficient difference %.2e; thresholds R %.5f %.5f vs prototype %.5f %.5f\n",
            max(abs(m0$main$b - proto_b)), m0$main$theta[1], m0$main$theta[2], proto_c[1], proto_c[2]))
cat(sprintf("Held-out pseudo R2 %.3f (prototype 0.204, different fold draw)\n", m0$cv_r2))
cat("Sign check, share of refits with a negative slope:\n")
print(m0$sign[, c("key", "wrong_share", "unclear")], row.names = FALSE)
cat("(prototype: Q025 0, Q026 0.29, Q027 0, Q021 0, Q029 0.01, Q063 0, Q064 0.06, Q065 0.31)\n")

all_res <- whatif_group_results(m0, list(all = rep(TRUE, length(spec$y))))$all
cat(sprintf("\nAll students: actual NPS %.1f (prototype 45.6 unweighted, 46.6 weighted), n %d\n", all_res$actual, all_res$n))
lv <- all_res$levers
show <- lv[lv$move %in% c("slip1", "floor"), ]
show$range <- sprintf("[%.1f, %.1f]", show$lo, show$hi)
show$est <- round(show$est, 1)
show$per_100 <- round(show$per_100, 1)
print(show[, c("key", "move", "est", "range", "need", "per_100")], row.names = FALSE)
cat("Prototype, slip1 / floor [range]: Q025 -10.9 / 1.9; Q026 -1.3 / 0.5; Q027 -14.4 / 2.1;\n",
    "  Q021 -26.3 [-31.0,-22.0] / 14.1 [11.7,16.5]; Q029 -5.9 / 1.3; Q063 -7.2 / 1.5; Q064 -3.9 / 2.1; Q065 -1.4 / 1.0\n",
    "  need 173, 373, 148, 471, 207, 188, 392, 481\n", sep = "")
vfm <- lv[lv$key == "Q021", ]
cat(sprintf("VALUE FOR MONEY: slip1 %.1f, lift to Good %.1f (brief target -26.3 and +14.1)\n",
            vfm$est[vfm$move == "slip1"], vfm$est[vfm$move == "floor"]))
cat("Bundles: ", paste(sprintf("%s %.1f [%.1f, %.1f]", all_res$bundles$name, all_res$bundles$est,
                               all_res$bundles$lo, all_res$bundles$hi), collapse = "; "),
    " (prototype Teaching 16.4, Service 8.1)\n", sep = "")
pm <- m0$profile
cat(sprintf("Profile model: penalty %s, held-out pseudo R2 %.4f, real profiles 5/50/95 %.1f / %.1f / %.1f (prototype 5, 0.0132, 19.6 / 48.8 / 64.2)\n",
            format(pm$penalty), pm$cv_r2, pm$spread[1], pm$spread[2], pm$spread[3]))

# ---------------------------------------------------------------- 2. agreement with ordinal::clm
cat("\n==== 2. Unpenalised fit against ordinal::clm, SACAP 2025 ====\n")
X <- m0$design$X
w0 <- m0$spec$weights
f0 <- whatif_fit_ordinal(X, spec$y, w0, 3, 0)
dd <- data.frame(X)
dd$y <- factor(spec$y, ordered = TRUE)
dd$.w <- w0
ref <- ordinal::clm(stats::reformulate(colnames(X), "y"), data = dd, weights = .w, link = "logit")
cat(sprintf("Largest difference: coefficients %.2e, thresholds %.2e\n",
            max(abs(f0$b - stats::coef(ref)[colnames(X)])), max(abs(f0$theta - ref$alpha))))

# ---------------------------------------------------------------- 3. structure rule
cat("\n==== 3. Structure rule: Bachelor of Social Work with Masters ====\n")
bad <- whatif_profile_predict(m0, c(gender = "Female", reg = "Returning", age = "23 - 24", intensity = "Full time",
                                    course = "Bachelor of Social Work", year = "Masters", campus = "Cape Town"))
cat("Refused:", is_refusal(bad), if (is_refusal(bad)) bad$code else "", "\n")
ok <- whatif_profile_predict(m0, c(gender = "Male", reg = "Returning", age = "23 - 24", intensity = "Full time",
                                   course = "Bachelor of Social Work", year = "3rd year", campus = "Cape Town"))
cat(sprintf("Allowed profile (male, BSW, 3rd year, Cape Town): NPS %.1f [%.1f, %.1f]\n", ok[["est"]], ok[["lo"]], ok[["hi"]]))
tab <- table(context$course$values, context$year$values)
cat(sprintf("Course by year of study (collapsed prototype versions): %d of %d cells empty\n", sum(tab == 0), length(tab)))

# ---------------------------------------------------------------- 4. calibration, baselines off and on
cat("\n==== 4. Calibration, unweighted, baselines off and on ====\n")
spec_on <- spec
spec_on$baselines <- names(context)
spec_on$profile <- NULL
m1 <- whatif_run_engine(spec_on)
cat("Baseline penalty cross-validation:\n")
print(m1$baseline_cv, row.names = FALSE)
c0 <- whatif_calibration(m0)
c1 <- whatif_calibration(m1)
fmt_cal <- function(cal, label) {
  cat(sprintf("%s: held-out pseudo R2 %.3f; %d of %d groups of 30+ outside their 95%% band (about %.1f expected by chance); median |predicted - actual| %.1f NPS points\n",
              label, cal$cv_r2, cal$n_outside, cal$n_groups, 0.05 * cal$n_groups, cal$median_abs_error))
}
fmt_cal(c0, "Ratings only        ")
fmt_cal(c1, "With baselines      ")
both <- merge(c0$table[, c("variable", "level", "n", "actual", "predicted", "z")],
              c1$table[, c("variable", "level", "predicted", "z")],
              by = c("variable", "level"), suffixes = c("_off", "_on"), sort = FALSE)
both <- both[order(-abs(both$z_off)), ]
num <- vapply(both, is.numeric, logical(1))
both[num] <- lapply(both[num], round, 1)
both$n <- as.integer(both$n)
options(width = 200)
print(both, row.names = FALSE)

res_on <- whatif_group_results(m1, list(all = rep(TRUE, length(spec$y))))$all$levers
v1 <- res_on[res_on$key == "Q021", ]
cat(sprintf("\nWith baselines, all students, value for money: slip1 %.1f, lift to Good %.1f\n",
            v1$est[v1$move == "slip1"], v1$est[v1$move == "floor"]))
cmp <- merge(lv[lv$move == "floor", c("key", "est")], res_on[res_on$move == "floor", c("key", "est")],
             by = "key", suffixes = c("_ratings_only", "_with_baselines"))
cmp[, 2:3] <- round(cmp[, 2:3], 1)
print(cmp, row.names = FALSE)
cat("\nDone. Nothing was written.\n")
