# ==============================================================================
# WHAT IF - SYNTHETIC PROJECT ON DISK
# ==============================================================================
#
# Writes a small study the way a real one arrives: a data file with labelled
# ratings and don't-know answers, a Survey_Structure with an Options sheet, and
# a What if config. Built from whatif_synthetic_study() so the truth is known.
# Everything goes into the folder given (a temporary folder in the tests).
#
#   data.csv       ID, Status (two Partial rows), NPS 0-10, labelled ratings
#                  (T1 and T2 average into Teaching; A1 has DK answers), an
#                  either/or pair (R_NEW for new, R_RET for returning), a
#                  nested online rating (blank where not used), mentor Yes/No,
#                  a called-us symptom, context columns, a weight
#   structure.xlsx Options for the labelled questions; A1's DK is excluded by
#                  ExcludeFromIndex, T2's DK only by a blank Index_Weight
#   config.xlsx    written by generate_whatif_config_template()
#
# ==============================================================================

whatif_write_test_project <- function(dir, n = 500, seed = 11, config = list()) {
  sp <- whatif_synthetic_study(n = n, seed = seed)
  set.seed(seed + 1)
  L5 <- c("Terrible", "Not very good", "About average", "Good", "Excellent")
  lab <- function(v) L5[v]
  teach <- sp$levers[[1]]$values
  t2 <- pmin(5, pmax(1, teach + sample(c(-1, 0, 0, 1), n, TRUE)))
  admin <- sp$levers[[2]]$values
  a1 <- lab(admin)
  a1[sample(n, 20)] <- "DK"
  t2l <- lab(t2)
  t2l[sample(n, 3)] <- "DK"
  new <- sp$context$year$values == "1st"
  noise <- lab(sp$levers[[3]]$values)
  online <- ifelse(sp$levers[[4]]$has, lab(sp$levers[[4]]$values), NA)
  nps <- vapply(sp$y, function(b) sample(list(0:6, 7:8, 9:10)[[b]], 1), numeric(1))
  d <- data.frame(
    ID = sprintf("R%04d", seq_len(n)),
    Status = "Complete",
    NPS = nps,
    T1 = lab(teach), T2 = t2l, A1 = a1, N1 = noise,
    R_NEW = ifelse(new, lab(pmin(5, admin + 1)), NA),
    R_RET = ifelse(new, NA, lab(admin)),
    ONLINE = online,
    MENTOR = ifelse(sp$levers[[5]]$values == 1, "Yes", "No"),
    CALLED = ifelse(runif(n) < 0.1 + 0.2 * (sp$y == 1), "Yes", "No"),
    CAMPUS = sp$context$campus$values,
    COURSE = sp$context$course$values,
    YEAR = sp$context$year$values,
    GENDER = ifelse(runif(n) < 0.03, NA, sp$context$gender$values),
    W = round(runif(n, 0.5, 1.8), 3),
    stringsAsFactors = FALSE, check.names = FALSE)
  extra <- d[1:2, ]
  extra$ID <- c("P0001", "P0002")
  extra$Status <- "Partial"
  d <- rbind(d, extra)
  utils::write.csv(d, file.path(dir, "data.csv"), row.names = FALSE, na = "")

  opt_rows <- function(q, dk_excluded = TRUE) {
    data.frame(QuestionCode = q, OptionText = c(L5, "DK"), DisplayText = c(L5, "Don't know"),
               DisplayOrder = 1:6, ExcludeFromIndex = c(rep("", 5), if (dk_excluded) "Y" else ""),
               Index_Weight = c("0", "25", "50", "75", "100", ""), BoxCategory = "", stringsAsFactors = FALSE)
  }
  opts <- rbind(opt_rows("T1"), opt_rows("T2", dk_excluded = FALSE), opt_rows("A1"), opt_rows("N1"),
                opt_rows("R_NEW"), opt_rows("R_RET"), opt_rows("ONLINE"),
                data.frame(QuestionCode = "YEAR", OptionText = c("1st", "2nd", "3rd", "Honours", "Masters"),
                           DisplayText = c("First", "Second", "Third", "Honours", "Masters"), DisplayOrder = 1:5,
                           ExcludeFromIndex = "", Index_Weight = "",
                           BoxCategory = c("Undergrad", "Undergrad", "Undergrad", "Postgrad", "Postgrad"),
                           stringsAsFactors = FALSE))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Options")
  openxlsx::writeData(wb, "Options", opts)
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", data.frame(
    QuestionCode = c("T1", "T2", "A1", "N1", "CALLED"),
    QuestionText = c("Teaching quality", "Teaching materials", "Admin", "Parking", "Have you had to call us to complain?")))
  turas_saveWorkbook(wb, file.path(dir, "structure.xlsx"), overwrite = TRUE)

  settings <- utils::modifyList(list(
    study_title = "Synthetic study", brand_name = "Test College", unit_noun = "student", units_noun = "students",
    data_file = "data.csv", structure_file = "structure.xlsx", output_folder = "out", output_name = "synthetic",
    id_variable = "ID", weight_variable = "W", base_filter_variable = "Status", base_filter_values = "Complete",
    outcome_question = "NPS", scale_min = 1, scale_max = 5, scale_centre = 3, scale_good = 4, n_boot = 20,
    min_group = 5), config)
  generate_whatif_config_template(
    file.path(dir, "config.xlsx"), settings = settings,
    levers = data.frame(
      Key = c("teach", "admin", "noise", "reg", "online", "mentor", "called"),
      Label = c("Teaching", "Admin", "Parking", "Registration", "Online support", "Mentor", "Called us"),
      Kind = c("rating", "rating", "rating", "rating", "nested", "coverage", "coverage"),
      Questions = c("T1; T2", "A1", "N1", "R_NEW; R_RET", "ONLINE", "MENTOR", "CALLED"),
      CoverageValues = c(rep("", 5), "Yes", "Yes"),
      Include = c("Y", "Y", "Y", "Y", "Y", "Y", "Symptom"),
      Note = c(rep("", 6), "Students call when something has gone wrong."),
      stringsAsFactors = FALSE),
    context = data.frame(
      Key = c("campus", "course", "year", "gender"),
      Question = c("CAMPUS", "COURSE", "YEAR", "GENDER"),
      Label = c("Campus", "Course", "Year of study", "Gender"),
      MissingLabel = c("", "", "", "Not said"),
      Order = c("", "", "1st; 2nd; 3rd; Honours; Masters", ""),
      Filter = "Y", Baseline = "Y", Profile = "Y",
      Structural = c("Y", "Y", "Y", "N"), stringsAsFactors = FALSE),
    sentence = data.frame(Text = c("A", "student in", "on", "at", "."),
                          Key = c("gender", "year", "course", "campus", NA),
                          Style = c("lower", "", "", "", ""), stringsAsFactors = FALSE),
    structure = data.frame(Key1 = "course", Level1 = "BA", Key2 = "year", Level2 = "Masters", stringsAsFactors = FALSE),
    crossings = data.frame(Key1 = c("campus", "course"), Key2 = c("course", "year"), stringsAsFactors = FALSE),
    bundles = data.frame(Name = "Teaching and admin", Description = "Both one point up",
                         Moves = "teach=up1; admin=up1", stringsAsFactors = FALSE))
  invisible(list(dir = dir, config = file.path(dir, "config.xlsx"), data = d, study = sp))
}
