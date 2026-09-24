# ==============================================================================
# WHAT IF - SYNTHETIC STUDY FOR THE TEST SUITE
# ==============================================================================
#
# Builds an in-memory study spec shaped like the SACAP student survey, with
# every lever kind and a known truth. Nothing is written to disk and no client
# data is involved.
#
#   levers    three 1-5 ratings (teach strong, admin weak, noise has no effect),
#             one nested rating (online support, 60% have it) and one coverage
#             lever (mentor, 40% have it)
#   context   campus (3), course (4), year (1st, 2nd, 3rd, Honours, Masters),
#             gender (2)
#   structure Masters only on the MSc course; Honours only on the BA and MSc
#             courses; the MSc course has only Honours and Masters years
#   offset    Honours students recommend less than their ratings say (-0.9 on
#             the latent scale), which ratings alone cannot explain and
#             context baselines should
#   outcome   Detractor < Passive < Promoter, scored -100, 0, 100
#
# ==============================================================================

whatif_synthetic_study <- function(n = 900, seed = 42, weighted = FALSE, honours_offset = -0.9) {
  set.seed(seed)
  campus <- sample(c("North", "South", "Online"), n, TRUE, c(0.5, 0.3, 0.2))
  course <- sample(c("BA", "BCom", "Cert", "MSc"), n, TRUE, c(0.4, 0.3, 0.2, 0.1))
  year <- character(n)
  year[course == "MSc"] <- sample(c("Honours", "Masters"), sum(course == "MSc"), TRUE)
  year[course == "BA"] <- sample(c("1st", "2nd", "3rd", "Honours"), sum(course == "BA"), TRUE, c(0.35, 0.3, 0.25, 0.1))
  year[course == "BCom"] <- sample(c("1st", "2nd", "3rd"), sum(course == "BCom"), TRUE)
  year[course == "Cert"] <- "1st"
  gender <- sample(c("Female", "Male"), n, TRUE, c(0.7, 0.3))

  rate <- function() pmin(5, pmax(1, round(rnorm(n, 3.6, 1))))
  teach <- rate()
  admin <- rate()
  noise <- rate()
  has_online <- runif(n) < 0.6
  online <- ifelse(has_online, rate(), NA_real_)
  mentor <- as.numeric(runif(n) < 0.4)

  eta <- 0.9 * (teach - 3) + 0.25 * (admin - 3) + 0 * (noise - 3) +
    0.2 * has_online + 0.5 * ifelse(has_online, online - 3, 0) + 0.6 * mentor +
    honours_offset * (year == "Honours")
  y <- as.integer(cut(eta + stats::rlogis(n), c(-Inf, -0.2, 1.3, Inf), labels = FALSE))
  w <- if (weighted) stats::runif(n, 0.4, 2.2) else NULL

  list(
    id = "synthetic",
    y = y,
    outcome = list(levels = c("Detractor", "Passive", "Promoter"), score = c(-100, 0, 100),
                   score_label = "NPS"),
    weights = w,
    scale = list(min = 1, max = 5, centre = 3, good = 4),
    levers = list(
      list(key = "teach", label = "Teaching", kind = "rating", values = teach),
      list(key = "admin", label = "Admin", kind = "rating", values = admin),
      list(key = "noise", label = "Noise", kind = "rating", values = noise),
      list(key = "online", label = "Online support", kind = "nested", values = online, has = has_online),
      list(key = "mentor", label = "Mentor", kind = "coverage", values = mentor)
    ),
    context = list(
      campus = list(label = "Campus", values = campus),
      course = list(label = "Course", values = course),
      year = list(label = "Year of study", values = year),
      gender = list(label = "Gender", values = gender)
    ),
    baselines = character(0),
    profile = list(
      keys = c("gender", "year", "course", "campus"),
      structural = c("year", "course", "campus"),
      rules = data.frame(
        key1 = c("course", "course", "course", "course", "course", "course"),
        level1 = c("BA", "BCom", "Cert", "BCom", "Cert", "MSc"),
        key2 = c("year", "year", "year", "year", "year", "year"),
        level2 = c("Masters", "Masters", "Masters", "Honours", "Honours", "1st"),
        stringsAsFactors = FALSE)
    ),
    bundles = list(
      list(name = "Teaching only", text = "Teaching one point up", moves = c(teach = "up1")),
      list(name = "Everything", text = "Teaching and admin up, mentor extended",
           moves = c(teach = "up1", admin = "up1", mentor = "extend"))
    ),
    n_boot = 30
  )
}
