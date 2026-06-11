#!/usr/bin/env Rscript
# Generate a SACAP-scale synthetic dataset: ~96 questions / ~26,500 table
# cells across a 10-column banner, mirroring the real 7.0 MB crosstabs
# report used for sizing in SPEC.md. Deterministic (seeded), realistic
# label lengths, plausible significance flags. Writes data/scale_data.json.

set.seed(42)

TARGET_CELLS <- 26500
N_BANNER <- 10
BANNER <- list(
  label = "Year of study × Faculty",
  columns = c("Total", "Year 1", "Year 2", "Year 3", "Year 4+",
              "Applied Psych", "Business", "Counselling", "Education", "Social Work"),
  letters = c("T", "A", "B", "C", "D", "E", "F", "G", "H", "I")
)
BASES <- c(1180, 320, 295, 280, 285, 260, 240, 230, 235, 215)

WORDS <- c("support", "teaching", "campus", "online", "career", "wellbeing",
           "facilities", "lecturers", "feedback", "community", "workload",
           "resources", "library", "administration", "fees", "timetable",
           "practical", "placement", "mentorship", "communication")
sentence <- function(n_words) {
  paste0(toupper(substr(WORDS[sample.int(length(WORDS), 1)], 1, 1)),
         paste(sample(WORDS, n_words, replace = TRUE), collapse = " "))
}

sig_for <- function(n_cols) {
  vapply(seq_len(n_cols), function(i) {
    if (i == 1 || runif(1) > 0.15) return("")
    paste(sort(sample(BANNER$letters[-c(1, i)], sample.int(2, 1))), collapse = "")
  }, character(1))
}

pct_rows <- function(labels, sums_to_100) {
  raw <- matrix(runif(length(labels) * N_BANNER, 2, 60),
                nrow = length(labels))
  if (sums_to_100) raw <- sweep(raw, 2, colSums(raw), "/") * 100
  lapply(seq_along(labels), function(i) {
    list(label = labels[i], values = as.list(round(raw[i, ], 1)),
         sig = as.list(sig_for(N_BANNER)))
  })
}

make_single <- function(idx, n_rows) {
  list(id = paste0("q", idx), code = paste0("Q", idx),
       title = paste0(sentence(7), "?"), type = "single",
       base_label = "All respondents", bases = as.list(BASES),
       rows = pct_rows(paste("Option:", vapply(seq_len(n_rows), function(i)
         sentence(sample(2:5, 1)), character(1))), TRUE))
}

make_multi <- function(idx, n_rows) {
  q <- make_single(idx, n_rows)
  q$type <- "multi"
  q$rows <- pct_rows(vapply(seq_len(n_rows), function(i)
    sentence(sample(3:7, 1)), character(1)), FALSE)
  q
}

make_scale <- function(idx) {
  labels <- c("Strongly disagree (1)", "Disagree (2)", "Neutral (3)",
              "Agree (4)", "Strongly agree (5)")
  means <- round(runif(N_BANNER, 3.1, 4.2), 2)
  waves <- lapply(seq_len(N_BANNER), function(i) {
    list(column = BANNER$columns[i],
         values = as.list(round(means[i] + cumsum(runif(4, -0.12, 0.12)) - 0.2, 2)))
  })
  list(id = paste0("q", idx), code = paste0("Q", idx),
       title = paste0(sentence(9), "."), type = "scale",
       scale = list(min = 1, max = 5),
       base_label = "All respondents", bases = as.list(BASES),
       rows = pct_rows(labels, TRUE),
       stats = list(
         list(label = "Mean (1–5)", values = as.list(means),
              sig = as.list(sig_for(N_BANNER)), format = "dec1"),
         list(label = "Top-2 box", values = as.list(round(runif(N_BANNER, 40, 75), 1)),
              sig = as.list(sig_for(N_BANNER)), format = "pct")),
       meta = list(waves = list(
         stat = "Mean (1–5)", format = "dec1",
         labels = c("2022", "2023", "2024", "2025"), series = waves)))
}

make_nps <- function(idx) {
  rows <- pct_rows(c("Promoters (9–10)", "Passives (7–8)",
                     "Detractors (0–6)"), TRUE)
  list(id = paste0("q", idx), code = paste0("Q", idx),
       title = paste0(sentence(8), "?"), type = "nps",
       base_label = "All respondents", bases = as.list(BASES),
       rows = rows,
       stats = list(list(label = "NPS",
         values = as.list(round(runif(N_BANNER, -20, 40))),
         sig = as.list(sig_for(N_BANNER)), format = "nps")))
}

make_numeric <- function(idx) {
  list(id = paste0("q", idx), code = paste0("Q", idx),
       title = paste0(sentence(6), "?"), type = "numeric",
       base_label = "All respondents", bases = as.list(BASES),
       rows = pct_rows(c("None", "1–2", "3–4", "5–6", "7+"), TRUE),
       stats = list(list(label = "Mean",
         values = as.list(round(runif(N_BANNER, 1.5, 5.5), 1)),
         sig = as.list(sig_for(N_BANNER)), format = "dec1")))
}

questions <- list()
sections <- list()
cells <- 0
idx <- 0
section_titles <- c("Module A — Experience", "Module B — Teaching", "Module C — Support",
                    "Module D — Facilities", "Module E — Outcomes", "Module F — Profile")
section_qids <- vector("list", length(section_titles))

while (cells < TARGET_CELLS) {
  idx <- idx + 1
  kind <- idx %% 6
  q <- if (kind %in% c(1, 2)) make_single(idx, sample(18:42, 1))
       else if (kind %in% c(3, 4)) make_multi(idx, sample(14:32, 1))
       else if (kind == 5) make_scale(idx)
       else if (idx %% 12 == 0) make_nps(idx) else make_numeric(idx)
  questions[[idx]] <- q
  n_rows <- length(q$rows) + length(q$stats)
  cells <- cells + n_rows * N_BANNER
  s <- ((idx - 1) %% length(section_titles)) + 1
  section_qids[[s]] <- c(section_qids[[s]], q$id)
}

for (s in seq_along(section_titles)) {
  sections[[s]] <- list(id = paste0("s", s), title = section_titles[s],
                        questions = as.list(section_qids[[s]]))
}

payload <- list(
  schema_version = 1,
  project = list(
    name = "SACAP-Scale Synthetic Study",
    client = "Scale benchmark — same renderer, bigger data",
    wave = "Annual 2025",
    fieldwork = paste0("Synthetic benchmark · ", length(questions),
                       " questions · ", format(cells, big.mark = ","), " table cells"),
    brand_colour = "#1B5E53",
    accent_colour = "#D08A3C",
    sig_note = paste("Synthetic data for size benchmarking. Letters mark columns",
                     "significantly higher at 95% confidence (simulated)."),
    export = list(pptx = TRUE),
    format = list(percent_decimals = 1)
  ),
  banner = BANNER,
  sections = sections,
  questions = questions
)

out <- file.path(dirname(sub("--file=", "",
  grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
  "scale_data.json")
jsonlite::write_json(payload, out, auto_unbox = TRUE, digits = NA)
cat(sprintf("scale_data.json written: %d questions, %s cells, %.0f KB\n",
            length(questions), format(cells, big.mark = ","),
            file.info(out)$size / 1024))
