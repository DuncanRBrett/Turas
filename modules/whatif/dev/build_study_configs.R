#!/usr/bin/env Rscript
# ==============================================================================
# WHAT IF - BUILD THE SACAP 2025 AND CCPB 2026 CONFIGS
# ==============================================================================
#
# Writes the two study configs the prototypes defined in code
# (prototypes/nps-simulator/study_sacap.py and study_ccpb.py), as What if
# config workbooks the analyst can open and edit. The data paths point at the
# project folders; nothing is written there. The configs land in the folder
# given as the first argument.
#
# Usage, from the Turas root:
#   Rscript modules/whatif/dev/build_study_configs.R <output folder>
#
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[1] else "."
source(file.path("modules", "whatif", "source_whatif.R"))
source(file.path("modules", "whatif", "lib", "generate_config_template.R"))
source(file.path("modules", "shared", "template_styles.R"))

df <- function(...) data.frame(..., stringsAsFactors = FALSE, check.names = FALSE)
onedrive <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files"

# ---------------------------------------------------------------- SACAP 2025
sacap_root <- file.path(onedrive, "Projects/SACAP/Student_Annual/03_Waves/Student_Annual-2025")
sacap <- generate_whatif_config_template(
  file.path(out_dir, "SACAP_Student_Annual-2025_WhatIf_Config.xlsx"),
  settings = list(
    project_name = "SACAP Student Survey 2025", study_title = "SACAP Student Survey 2025",
    brand_name = "SACAP", unit_noun = "student", units_noun = "students",
    data_file = file.path(sacap_root, "03_Data/SACAP_Student_Annual-2025_Data.xlsx"),
    structure_file = file.path(sacap_root, "SACAP_Student_Annual-2025_Survey_Structure v2.xlsx"),
    output_folder = "output", output_name = "SACAP_Student_Annual-2025_WhatIf",
    id_variable = "ID", base_filter_variable = "Q001", base_filter_values = "Complete; Converted",
    outcome_question = "Q017", outcome_text = "Would you recommend SACAP to others as a place to study? (Q017)",
    scale_min = 1, scale_max = 5, scale_centre = 3, scale_good = 4, scale_step = "notch",
    min_group = 5, reliability_floor = 30, profile_builder = "Y", n_boot = 100),
  levers = df(
    Key = c("Q025", "Q026", "Q027", "Q021", "Q029", "Q063", "Q064", "Q065", "REG", "Q013", "Q078"),
    Label = c("Educators delivering content", "Assessment feedback", "Course content", "Value for money",
              "MySACAP usability", "Staff friendly and approachable", "Student admin", "Email responsiveness",
              "Registration or re-registration", "Orientation", "Time with fellow students"),
    Kind = c(rep("rating", 9), "nested", "rating"),
    Questions = c("Q025", "Q026", "Q027", "Q021", "Q029", "Q063", "Q064", "Q065", "Q010; Q011", "Q013", "Q078"),
    Include = c(rep("Y", 8), "N", "N", "N"),
    Note = c("", "", "", "Behaves partly like a second measure of how students feel about SACAP overall",
             "", "", "", "", "New students rate registration, returning students re-registration",
             "First-time students only", "")),
  context = df(
    Key = c("campus", "course", "year", "reg", "gender", "age", "intensity"),
    Question = c("Q002", "Q005", "Q006", "Q009", "Q100", "Q099", "Q004"),
    Label = c("Campus", "Course", "Year of study", "New or returning", "Gender", "Age", "Full or part time"),
    CollapseUnder = c("", "40", "", "", "", "", ""),
    CollapseLabel = c("", "Other courses", "", "", "", "", ""),
    MissingLabel = c("", "Other programmes", "Other", "", "Other or not said", "Not said", ""),
    Order = c("", "", "1st year; 2nd year; 3rd year; Honours; Masters; Other", "", "", "numeric", ""),
    Filter = "Y", Baseline = "Y", Profile = "Y",
    Structural = c("Y", "Y", "Y", "N", "N", "N", "Y")),
  recodes = df(
    Key = c(rep("year", 9), "reg", "reg", "gender", "gender", "age", "intensity", "intensity"),
    From = c("1st year modules", "2nd year modules", "3rd year modules", "4th year modules",
             "1st year Honours modules", "2nd year Honours modules", "1st year Masters modules",
             "2nd year Masters modules", "3rd year Masters modules",
             "I registered for the 1st time", "I re-registered",
             "Prefer not to say", "Other -(Please specify)", "Prefer not to say",
             "Full time three or more modules", "Part time two or less modules"),
    To = c("1st year", "2nd year", "3rd year", "Other", "Honours", "Honours", "Masters", "Masters", "Masters",
           "First-time", "Returning", "Other or not said", "Other or not said", "Not said", "Full time", "Part time")),
  sentence = df(
    Text = c("A", "", "student aged", ", studying", "on", ", in", ", registered with", "."),
    Key = c("gender", "reg", "age", "intensity", "course", "year", "campus", NA),
    Style = c("lower", "lower", "", "lower", "", "", "", "")),
  crossings = df(
    Key1 = c("campus", "campus", "course", "campus", "course", "campus", "course", "campus", "course", "gender"),
    Key2 = c("course", "year", "year", "reg", "reg", "gender", "gender", "age", "age", "age")),
  bundles = df(
    Name = c("Teaching", "Service"),
    Description = c("Educators, assessment feedback and course content each one notch up",
                    "Staff, student admin and email responsiveness each one notch up"),
    Moves = c("Q025=up1; Q026=up1; Q027=up1", "Q063=up1; Q064=up1; Q065=up1")),
  title = "What if: SACAP Student Survey 2025")
print(sacap)

# ---------------------------------------------------------------- CCPB 2026
ccpb_root <- file.path(onedrive, "TurasProjects/CCPB/CSAT/W2026")
channels <- c("1" = "General Dealer", "3" = "Local QSR", "5" = "Liquor", "6" = "Petroleum", "7" = "National QSR",
              "8" = "Superette", "9" = "Pubs & clubs", "10" = "Restaurants", "11" = "Spaza", "12" = "Supermarket",
              "13" = "Wholesalers", "14" = "Recreational", "15" = "General merchandiser", "16" = "Mass merchandiser")
ccpb <- generate_whatif_config_template(
  file.path(out_dir, "CCPB_CSAT_W2026_WhatIf_Config.xlsx"),
  settings = list(
    project_name = "CCPB Main Study 2026", study_title = "CCPB Main Study 2026",
    brand_name = "CCPB", unit_noun = "outlet", units_noun = "outlets",
    data_file = file.path(ccpb_root, "02 Data/CCPB_CSAT_2026.xlsx"),
    structure_file = file.path(ccpb_root, "CCPB_CSAT_W2026_Survey_Structure short.xlsx"),
    output_folder = "output", output_name = "CCPB_CSAT_W2026_WhatIf", id_variable = "Response ID",
    outcome_question = "Q79",
    outcome_text = "Would you recommend Coca-Cola Peninsula Beverages as a distributor? (Q79)",
    scale_min = 1, scale_max = 10, scale_centre = 8, scale_good = 8, scale_step = "point",
    min_group = 5, reliability_floor = 30, profile_builder = "Y", n_boot = 100),
  levers = df(
    Key = c("ordering", "delivery", "invoicing", "merch", "rep", "signage", "coolers", "mgr", "ccpbmerch", "promo",
            "called", "shops"),
    Label = c("Ease of ordering", "Delivery", "Invoicing", "Merchandising", "Sales rep", "Signage condition",
              "Has Coca-Cola coolers", "Knows its CCPB sales manager", "CCPB does the merchandising",
              "Offered a promotion in last 3 months", "Called CCPB in the last 12 months", "Shops around for suppliers"),
    Kind = c(rep("rating", 5), "nested", rep("coverage", 6)),
    Questions = c("Q02", "Q08; Q09; Q10", "Q13", "Q22", "Q27; Q28; Q202", "Q42", "Q43", "Q33", "Q16", "Q29", "Q35", "Q05"),
    CoverageValues = c(rep("", 6), "Yes", "Yes", "CCPB sales person / rep; CCPB merchandiser", "Yes",
                       "1 month; Within the last week; 3 months; 3-6 months; 6-12 months",
                       "Sometimes shop around; Always shop around"),
    Include = c(rep("Y", 10), "Symptom", "Symptom"),
    Note = c("", "average of delivery overall, product condition, delivery team", "", "",
             "average of rep overall, complaints, help with coolers and signage", "only outlets with Coke signage",
             "", "", "", "",
             "Outlets call when something has gone wrong, so calling is a sign of a problem, not a cause.",
             "Shopping around is itself a measure of loyalty; it moves with the outcome rather than driving it."),
    HasLabel = c(rep("", 5), "Has Coke signage", rep("", 6))),
  context = df(
    Key = c("centre", "office", "method", "size", "channel", "coolers_ctx", "mgr_ctx", "merch_ctx"),
    Question = c("S01", "S05", "S11", "S04", "S09", "Q43", "Q33", "Q16"),
    Label = c("Centre", "Sales office", "Sales method", "Outlet size", "Channel", "Coolers", "Sales manager",
              "Merchandising by"),
    Levels = c("display", rep("", 7)),
    CollapseUnder = c("", "30", "", "", "30", "", "", ""),
    CollapseLabel = c("", "Other offices", "", "", "Other channels", "", "", ""),
    MissingLabel = c(rep("", 7), "Someone else or nobody"),
    Filter = "Y", Baseline = "N", Profile = "Y",
    Structural = c("Y", "Y", "Y", "Y", "N", "N", "N", "N")),
  recodes = df(
    Key = c(rep("size", 4), rep("channel", length(channels)), "coolers_ctx", "coolers_ctx", "mgr_ctx", "mgr_ctx",
            rep("merch_ctx", 5)),
    From = c("1.Micro", "2.Small", "3.Medium", "4.Large", names(channels), "Yes", "No", "Yes", "No",
             "CCPB sales person / rep", "CCPB merchandiser", "Yourself / own staff",
             "Coast and Country merchandiser", "Nobody"),
    To = c("Micro", "Small", "Medium", "Large", unname(channels), "Has coolers", "No coolers",
           "Knows the sales manager", "Does not know the sales manager",
           "CCPB", "CCPB", "Own staff", "Someone else or nobody", "Someone else or nobody")),
  sentence = df(
    Text = c("A", "", "on", ", in", ", served from", ". It", ",", ", and its merchandising is done by", "."),
    Key = c("size", "channel", "method", "centre", "office", "coolers_ctx", "mgr_ctx", "merch_ctx", NA),
    Style = c("lower", "", "", "", "", "lower", "lower", "lower", "")),
  crossings = df(
    Key1 = c("centre", "centre", "channel", "office", "method", "centre", "channel", "size", "channel", "channel"),
    Key2 = c("channel", "size", "size", "channel", "size", "coolers_ctx", "coolers_ctx", "coolers_ctx", "mgr_ctx",
             "merch_ctx")),
  bundles = df(
    Name = c("Service basics", "Coverage push"),
    Description = c("Delivery, sales rep and ease of ordering each one point up",
                    "Coolers and a known sales manager extended to every outlet without them"),
    Moves = c("delivery=up1; rep=up1; ordering=up1", "coolers=extend; mgr=extend")),
  title = "What if: CCPB Main Study 2026")
print(ccpb)
