# ==============================================================================
# TURAS WEBSITE DEMO GENERATOR
# ==============================================================================
# Builds the synthetic inputs for the public Turas demo report on
# researchlamppost.co.za. Four waves of a fictional customer experience study
# for "Karoo Coffee Roasters" (an invented company; no real client data is
# involved at any point).
#
# Adapted from examples/tabs/demo_survey/generate_demo.R. What is new here:
#   - a ResponseID column, so the comment workbook joins to the survey
#   - three open-end questions plus a coded comment workbook (Qualitative tab)
#   - a Comments sheet carrying _BACKGROUND and _EXECUTIVE_SUMMARY
#   - v2 report settings: microdata island, tracking, cover
#   - three prior waves (2022, 2023, 2024) with a deliberate story in the trend
#
# Usage:
#   Rscript build_website_demo.R <turas_root> <out_root>
#
# Writes <out_root>/w2022 .. w2025, each holding a self-contained tabs project.
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
turas_root <- if (length(args) >= 1) args[1] else "/Users/duncan/Dev/Turas"
out_root   <- if (length(args) >= 2) args[2] else getwd()

suppressPackageStartupMessages(library(openxlsx))
source(file.path(turas_root, "modules/shared/lib/turas_save_workbook_atomic.R"))

cat("=== TURAS WEBSITE DEMO GENERATOR ===\n\n")

COMPANY   <- "Karoo Coffee Roasters"
RESEARCHER <- "The Research LampPost"

# ==============================================================================
# WAVE DEFINITIONS
# ==============================================================================
# Each wave shifts a handful of measures so the Tracking tab has a story:
#   - customer service climbs steadily from 2022
#   - delivery dips hard in 2023, then recovers
#   - the mobile app improves year on year
#   - NPS drifts up
#   - sustainability perception improves late
# Everything else stays broadly flat, so the movers stand out.

waves <- list(
  list(label = "2022", order = 2022, seed = 2022, n = 940,
       fieldwork = "Feb 2022",
       delta = list(Q001 = -0.6, Q005 = -0.9, Q007 = 0.3, Q009 = -0.9,
                    Q014 = -0.3, Q002 = -0.6, Q010 = -0.2)),
  list(label = "2023", order = 2023, seed = 2023, n = 975,
       fieldwork = "Feb 2023",
       delta = list(Q001 = -0.5, Q005 = -0.6, Q007 = -0.6, Q009 = -0.6,
                    Q014 = -0.3, Q002 = -0.45, Q010 = -0.1)),
  list(label = "2024", order = 2024, seed = 2024, n = 990,
       fieldwork = "Feb 2024",
       delta = list(Q001 = -0.3, Q005 = -0.3, Q007 = -0.3, Q009 = -0.3,
                    Q014 = -0.1, Q002 = -0.25)),
  list(label = "2025", order = 2025, seed = 2025, n = 1000,
       fieldwork = "Jan to Feb 2025",
       delta = list())
)

# ==============================================================================
# SURVEY DEFINITION (shared across waves)
# ==============================================================================

q_text <- c(
  Region = "Region", Gender = "Gender", Age_Group = "Age group",
  Segment = "Customer segment",
  Q001 = "How likely are you to recommend us to a friend or colleague?",
  Q002 = "How would you rate your overall satisfaction with our service?",
  Q003 = "How would you rate the quality of our coffee?",
  Q004 = "How would you rate the value for money of our products?",
  Q005 = "How would you rate the quality of our customer service?",
  Q006 = "How easy is it to do business with us?",
  Q007 = "How would you rate your delivery experience?",
  Q008 = "How would you rate your experience with our website?",
  Q009 = "How would you rate your experience with our mobile app?",
  Q010 = "How would you rate the quality of our communications?",
  Q011 = "How much do you trust our brand?",
  Q012 = "How would you rate our brand's reputation?",
  Q013 = "How innovative do you consider our company to be?",
  Q014 = "How committed do you feel we are to sustainability?",
  Q015 = "How well does our brand align with your personal values?",
  Q016 = "How satisfied are you with our after-sales support?",
  Q017 = "How likely are you to remain a customer in the next 12 months?",
  Q018 = "How often do you buy from us?",
  Q019 = "What is your main channel for buying from us?",
  Q020 = "How did you first hear about us?",
  Q021 = "What was the main reason you chose us?",
  Q022 = "Have you made a complaint in the last 12 months?",
  Q023 = "Was your complaint resolved to your satisfaction?",
  Q024 = "How likely would you be to switch to another roaster?",
  Q025 = "What is your overall impression of our company?",
  Q026 = "What is the main reason for the score you just gave?",
  Q027 = "What one thing would most improve your experience with us?",
  Q028 = "Is there anything else you would like to tell us?"
)

rating_codes <- sprintf("Q%03d", 2:10)
likert_codes <- sprintf("Q%03d", 11:17)
open_codes   <- c("Q026", "Q027", "Q028")

# Base means for the 2025 wave; earlier waves subtract their delta.
base_mean <- c(
  Q001 = 8.1, Q002 = 7.0, Q003 = 7.2, Q004 = 6.0, Q005 = 6.8, Q006 = 7.5,
  Q007 = 6.5, Q008 = 7.0, Q009 = 6.3, Q010 = 6.7,
  Q011 = 3.6, Q012 = 3.8, Q013 = 3.3, Q014 = 3.1, Q015 = 3.4, Q016 = 3.2,
  Q017 = 3.5
)
base_sd <- c(
  Q001 = 2.0, Q002 = 1.8, Q003 = 1.6, Q004 = 2.0, Q005 = 1.9, Q006 = 1.5,
  Q007 = 2.2, Q008 = 1.7, Q009 = 2.0, Q010 = 1.8,
  Q011 = 1.1, Q012 = 1.0, Q013 = 1.2, Q014 = 1.1, Q015 = 1.0, Q016 = 1.2,
  Q017 = 1.1
)

region_effect <- list(
  Q001 = c(Gauteng = 0.5, "Western Cape" = 0.8, "KwaZulu-Natal" = -0.3, "Eastern Cape" = -1.0),
  Q002 = c(Gauteng = 0.3, "Western Cape" = 0.6, "KwaZulu-Natal" = -0.2, "Eastern Cape" = -0.5),
  Q003 = c(Gauteng = 0.2, "Western Cape" = 0.4, "KwaZulu-Natal" = 0.1, "Eastern Cape" = -0.5),
  Q004 = c(Gauteng = 0.0, "Western Cape" = 0.3, "KwaZulu-Natal" = 0.2, "Eastern Cape" = -0.3),
  Q005 = c(Gauteng = 0.5, "Western Cape" = 0.7, "KwaZulu-Natal" = -0.4, "Eastern Cape" = -0.8),
  Q007 = c(Gauteng = 0.8, "Western Cape" = 0.5, "KwaZulu-Natal" = -0.3, "Eastern Cape" = -1.2),
  Q010 = c(Gauteng = 0.3, "Western Cape" = 0.5, "KwaZulu-Natal" = -0.2, "Eastern Cape" = -0.7),
  Q011 = c(Gauteng = 0.2, "Western Cape" = 0.3, "KwaZulu-Natal" = -0.1, "Eastern Cape" = -0.4),
  Q013 = c(Gauteng = 0.3, "Western Cape" = 0.4, "KwaZulu-Natal" = -0.1, "Eastern Cape" = -0.5),
  Q016 = c(Gauteng = 0.4, "Western Cape" = 0.3, "KwaZulu-Natal" = -0.2, "Eastern Cape" = -0.8)
)

segment_effect <- list(
  Q001 = c(Premium = 1.2, Standard = 0.0, Budget = -0.8, "New Customer" = 0.3),
  Q002 = c(Premium = 1.0, Standard = 0.0, Budget = -0.5, "New Customer" = -0.3),
  Q003 = c(Premium = 0.8, Standard = 0.2, Budget = -0.6, "New Customer" = 0.0),
  Q004 = c(Premium = -0.5, Standard = 0.3, Budget = 0.5, "New Customer" = -0.2),
  Q005 = c(Premium = 1.5, Standard = 0.0, Budget = -0.8, "New Customer" = -0.3),
  Q006 = c(Premium = 0.3, Standard = 0.1, Budget = -0.2, "New Customer" = -0.8),
  Q008 = c(Premium = 0.5, Standard = 0.2, Budget = -0.3, "New Customer" = -0.6),
  Q009 = c(Premium = 0.8, Standard = 0.0, Budget = -0.5, "New Customer" = -0.4),
  Q011 = c(Premium = 0.5, Standard = 0.0, Budget = -0.3, "New Customer" = -0.1),
  Q012 = c(Premium = 0.4, Standard = 0.1, Budget = -0.2, "New Customer" = -0.1),
  Q014 = c(Premium = 0.6, Standard = 0.0, Budget = -0.3, "New Customer" = 0.2),
  Q015 = c(Premium = 0.5, Standard = 0.1, Budget = -0.4, "New Customer" = 0.1),
  Q017 = c(Premium = 0.7, Standard = 0.0, Budget = -0.5, "New Customer" = 0.2)
)

# ==============================================================================
# GENERATORS
# ==============================================================================

gen_scale <- function(code, n, region, segment, delta, lo, hi) {
  mu <- base_mean[[code]] + (delta[[code]] %||% 0)
  vals <- rnorm(n, mu, base_sd[[code]])
  re <- region_effect[[code]]
  if (!is.null(re)) for (r in names(re)) vals[region == r] <- vals[region == r] + re[[r]]
  se <- segment_effect[[code]]
  if (!is.null(se)) for (s in names(se)) vals[segment == s] <- vals[segment == s] + se[[s]]
  pmin(pmax(round(vals), lo), hi)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ==============================================================================
# VERBATIM POOLS
# ==============================================================================
# Each theme carries a positive and a negative phrasing. A comment is assembled
# from the themes it was coded against, so the text and the codes always agree.
# No em dashes anywhere in this file's authored strings.

themes_q026 <- list(
  "Coffee quality" = list(
    pos = c("The coffee itself is excellent and the roast is always fresh",
            "Every bag tastes the way it should, batch after batch",
            "The quality of the beans is the reason I keep coming back"),
    neg = c("The last three bags tasted stale and flat",
            "Quality has slipped since I first started buying",
            "The roast is inconsistent from one order to the next")),
  "Price and value" = list(
    pos = c("For what you get, the price is fair",
            "It costs a little more but the value is there",
            "The subscription price works out well against the supermarket"),
    neg = c("The price went up twice this year and I noticed",
            "It is simply too expensive for what arrives",
            "I can get something close to this for a lot less")),
  "Customer service" = list(
    pos = c("The team sorted out my query the same morning",
            "Whoever answers the phone actually listens",
            "Service has been friendly and quick every time"),
    neg = c("Nobody replied to my email for over a week",
            "I was passed between three people and still had no answer",
            "The service felt rushed and I was not really heard")),
  "Delivery" = list(
    pos = c("Delivery is reliable and lands when it says it will",
            "The courier has never let me down",
            "Orders arrive quickly and well packed"),
    neg = c("My order was four days late with no message",
            "Deliveries keep arriving on the wrong day",
            "The packaging arrived damaged twice in a row")),
  "Range and choice" = list(
    pos = c("There is enough variety to keep it interesting",
            "I like that the seasonal blends change",
            "The single origin range is genuinely good"),
    neg = c("The blend I want is out of stock more often than not",
            "The range has narrowed a lot this year",
            "There is very little choice for decaf drinkers")),
  "Ease of ordering" = list(
    pos = c("Ordering takes under a minute",
            "The website makes repeat orders simple",
            "Changing my subscription date was straightforward"),
    neg = c("The checkout failed three times before it went through",
            "Editing a standing order is far harder than it needs to be",
            "I could not find how to pause my subscription"))
)

themes_q027 <- list(
  "Faster delivery" = list(
    pos = c("Keep delivery as quick as it is now"),
    neg = c("Get orders out faster, two days would change everything",
            "Offer a same week option for people who run out",
            "Give a real delivery window instead of a guess")),
  "Lower prices" = list(
    pos = c("Hold the price where it is"),
    neg = c("Bring the price down or add a bulk discount",
            "A loyalty price for regular buyers would help",
            "Stop the annual increases")),
  "Better app" = list(
    pos = c("The app is fine as it is"),
    neg = c("Fix the app, it logs me out constantly",
            "Let me reorder from the app in one step",
            "Show order tracking properly in the app")),
  "More stock" = list(
    pos = c("Stock levels have been good lately"),
    neg = c("Keep the popular blends in stock",
            "Tell me when something is back rather than leaving me guessing",
            "Stop selling blends you cannot supply")),
  "Clearer communication" = list(
    pos = c("The emails are useful and not too frequent"),
    neg = c("Tell me when an order is delayed before I have to ask",
            "Fewer marketing emails and more order updates",
            "Explain the changes to the subscription properly")),
  "Easier returns" = list(
    pos = c("Returns were painless the one time I needed one"),
    neg = c("Make returns simpler, the form is confusing",
            "Refunds take far too long to come through",
            "Let me report a bad bag without phoning"))
)

themes_q028 <- list(
  "Praise for staff" = list(
    pos = c("The person who helped me in store was excellent",
            "Your team clearly cares about the product",
            "A quick thank you to the delivery driver, always cheerful"),
    neg = c("The staff seemed under pressure and it showed")),
  "Loyalty programme" = list(
    pos = c("The rewards points are a nice touch"),
    neg = c("A loyalty programme would keep me here longer",
            "The points expire far too quickly to be useful")),
  "Store environment" = list(
    pos = c("The shop is a pleasant place to spend half an hour",
            "The new store layout works well"),
    neg = c("The store gets far too crowded on a Saturday")),
  "Sustainability" = list(
    pos = c("Good to see the packaging move to something recyclable",
            "I like that you name the farms"),
    neg = c("There is still too much plastic in every order",
            "I would like to know more about how the growers are paid")),
  "Complaint handling" = list(
    pos = c("My complaint was handled properly and I was kept informed"),
    neg = c("I complained twice and heard nothing back",
            "The apology was fine but nothing actually changed"))
)

#' Build one open-end's coded comment records.
#'
#' Comments are conditioned on the respondent's NPS score, so a detractor's
#' text and a promoter's text differ in the way real fieldwork does.
build_comments <- function(theme_pool, ids, nps, region, segment, share, seed,
                           weights = NULL, tilt = NULL, region_boost = NULL) {
  set.seed(seed)
  n <- length(ids)
  pick <- sort(sample(seq_len(n), round(n * share)))
  labs <- names(theme_pool)
  if (is.null(weights)) weights <- setNames(rep(1, length(labs)), labs)
  if (is.null(tilt)) tilt <- setNames(rep(0, length(labs)), labs)
  out <- vector("list", length(pick))

  for (k in seq_along(pick)) {
    i <- pick[k]
    score <- nps[i]
    # Probability a mention is negative, driven by the person's own score.
    p_base <- if (score <= 6) 0.80 else if (score <= 8) 0.45 else 0.14
    n_themes <- sample(1:3, 1, prob = c(0.5, 0.35, 0.15))
    # Some themes are raised more often than others, and one region raises
    # delivery harder than the rest, so the coding carries a real story.
    w <- weights[labs]
    if (!is.null(region_boost)) {
      for (lab in names(region_boost)) {
        if (identical(region[i], region_boost[[lab]]$region)) {
          w[[lab]] <- w[[lab]] * region_boost[[lab]]$factor
        }
      }
    }
    chosen <- sample(labs, n_themes, prob = w / sum(w))
    vals <- setNames(integer(length(chosen)), chosen)
    frags <- character(0)
    for (lab in chosen) {
      pool <- theme_pool[[lab]]
      p_neg <- min(max(p_base + (tilt[[lab]] %||% 0), 0.02), 0.96)
      neg <- runif(1) < p_neg
      if (neg && length(pool$neg)) {
        vals[[lab]] <- 3L
        frags <- c(frags, sample(pool$neg, 1))
      } else if (!neg && length(pool$pos)) {
        vals[[lab]] <- 1L
        frags <- c(frags, sample(pool$pos, 1))
      } else {
        vals[[lab]] <- 2L
        frags <- c(frags, sample(c(pool$pos, pool$neg), 1))
      }
    }
    text <- paste0(paste(frags, collapse = ". "), ".")
    mix <- mean(vals)
    overall <- if (mix <= 1.4) 1L else if (mix >= 2.6) 3L else 2L
    # Noteworthy tiers: p = lead with this, m = must read, n = noteworthy.
    r <- runif(1)
    tier <- if (overall == 3L && n_themes >= 2 && r < 0.18) "p"
            else if (r < 0.10) "m"
            else if (r < 0.28) "n"
            else ""
    out[[k]] <- list(id = ids[i], region = region[i], segment = segment[i],
                     text = text, note = tier, sentiment = overall, vals = vals)
  }
  list(records = out, labels = labs)
}

# How often each theme is raised, and how it leans. Coffee quality is the
# strength people volunteer; delivery and price are what they complain about.
W_Q026 <- c("Coffee quality" = 1.7, "Delivery" = 1.4, "Price and value" = 1.3,
            "Customer service" = 1.0, "Ease of ordering" = 0.7,
            "Range and choice" = 0.7)
T_Q026 <- c("Coffee quality" = -0.34, "Delivery" = 0.20, "Price and value" = 0.20,
            "Customer service" = 0.0, "Ease of ordering" = 0.0,
            "Range and choice" = 0.05)
B_Q026 <- list(Delivery = list(region = "Eastern Cape", factor = 2.4))

W_Q027 <- c("Faster delivery" = 1.5, "Lower prices" = 1.4, "Better app" = 1.1,
            "More stock" = 0.9, "Clearer communication" = 0.8,
            "Easier returns" = 0.6)
T_Q027 <- setNames(rep(0, 6), names(W_Q027))
B_Q027 <- list("Faster delivery" = list(region = "Eastern Cape", factor = 2.0))

W_Q028 <- c("Praise for staff" = 1.4, "Sustainability" = 1.2,
            "Loyalty programme" = 1.0, "Complaint handling" = 0.8,
            "Store environment" = 0.7)
T_Q028 <- c("Praise for staff" = -0.35, "Sustainability" = 0.10,
            "Loyalty programme" = 0.15, "Complaint handling" = 0.25,
            "Store environment" = -0.10)

#' Turn coded records into the sheet layout the qual workbook reader expects:
#' a preamble line carrying the question wording, then a header row anchored on
#' "Response ID", demographics left of the verbatim, themes right of it.
comment_sheet_frame <- function(built, question_text) {
  labs <- built$labels
  recs <- built$records
  header <- c("Response ID", "Region", "Segment", "Comment", "Noteworthy",
              "Overall Sentiment", labs)
  body <- lapply(recs, function(r) {
    tv <- rep("", length(labs))
    names(tv) <- labs
    for (lab in names(r$vals)) tv[[lab]] <- as.character(r$vals[[lab]])
    c(as.character(r$id), r$region, r$segment, r$text, r$note,
      as.character(r$sentiment), unname(tv))
  })
  mat <- do.call(rbind, body)
  # Row 1 = the open-end prompt (preamble); row 2 = the header; rows 3+ = data.
  pre <- c(question_text, rep("", length(header) - 1))
  df <- as.data.frame(rbind(pre, header, mat), stringsAsFactors = FALSE)
  names(df) <- paste0("V", seq_len(ncol(df)))
  df
}

# ==============================================================================
# STRUCTURE / CONFIG BUILDERS
# ==============================================================================

build_questions_df <- function() {
  codes <- names(q_text)
  vtype <- vapply(codes, function(cd) {
    if (cd %in% c("Region", "Gender", "Age_Group", "Segment")) "Single_Response"
    else if (cd == "Q001") "NPS"
    else if (cd %in% rating_codes) "Rating"
    else if (cd %in% likert_codes) "Likert"
    else if (cd %in% open_codes) "Open_End"
    else "Single_Response"
  }, character(1))
  cat_of <- c(Region = "Demographics", Gender = "Demographics",
              Age_Group = "Demographics", Segment = "Demographics",
              Q001 = "Overall metrics", Q002 = "Overall metrics",
              Q003 = "Product and value", Q004 = "Product and value",
              Q005 = "Service and support", Q006 = "Experience and channels",
              Q007 = "Experience and channels", Q008 = "Experience and channels",
              Q009 = "Experience and channels", Q010 = "Service and support",
              Q011 = "Brand perception", Q012 = "Brand perception",
              Q013 = "Brand perception", Q014 = "Brand perception",
              Q015 = "Brand perception", Q016 = "Service and support",
              Q017 = "Loyalty", Q018 = "Buying behaviour",
              Q019 = "Experience and channels", Q020 = "Buying behaviour",
              Q021 = "Buying behaviour", Q022 = "Complaints",
              Q023 = "Complaints", Q024 = "Loyalty",
              Q025 = "Overall metrics", Q026 = "Comments",
              Q027 = "Comments", Q028 = "Comments")
  data.frame(
    QuestionCode = codes,
    QuestionText = unname(q_text[codes]),
    Variable_Type = unname(vtype),
    Columns = rep(1, length(codes)),
    Category = unname(cat_of[codes]),
    stringsAsFactors = FALSE
  )
}

build_options_df <- function() {
  ol <- list()
  add <- function(qc, opts, disp = NULL, weights = NA, box = NA) {
    if (is.null(disp)) disp <- opts
    ol[[length(ol) + 1]] <<- data.frame(
      QuestionCode = qc, OptionText = opts, DisplayText = disp,
      ShowInOutput = "Y", DisplayOrder = seq_along(opts),
      Index_Weight = weights, BoxCategory = box, ExcludeFromIndex = NA,
      stringsAsFactors = FALSE)
  }
  add("Region", c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"))
  add("Gender", c("Male", "Female"))
  add("Age_Group", c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"))
  add("Segment", c("Premium", "Standard", "Budget", "New Customer"))
  add("Q001", as.character(0:10), as.character(0:10), NA,
      c(rep("Detractor (0-6)", 7), rep("Passive (7-8)", 2), rep("Promoter (9-10)", 2)))
  for (qc in rating_codes) {
    add(qc, as.character(1:10), as.character(1:10), 1:10,
        c(rep("Poor (1-3)", 3), rep("Average (4-6)", 3), rep("Good or excellent (7-10)", 4)))
  }
  for (qc in likert_codes) {
    add(qc, as.character(1:5),
        c("Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"),
        1:5, c("Negative", "Negative", "Neutral", "Positive", "Positive"))
  }
  add("Q018", c("Weekly", "Monthly", "Quarterly", "Yearly", "First time"))
  add("Q019", c("Online", "In-store", "Mobile app", "Phone", "Subscription"))
  add("Q020", c("Social media", "Word of mouth", "TV advertising", "Online search",
                "Print media", "Email marketing"))
  add("Q021", c("Price", "Quality", "Convenience", "Brand reputation",
                "Recommendation", "No alternative"))
  add("Q022", c("Yes", "No"))
  add("Q023", c("Yes", "No", "Partially"),
      c("Yes, fully resolved", "No, not resolved", "Partially resolved"))
  add("Q024", c("Definitely would", "Probably would", "Not sure",
                "Probably would not", "Definitely would not"), NULL, NA,
      c("Would switch", "Would switch", "Undecided", "Would not switch", "Would not switch"))
  add("Q025", c("Excellent", "Good", "Average", "Below average", "Poor"), NULL, NA,
      c("Good or excellent", "Good or excellent", "Average",
        "Below average or poor", "Below average or poor"))
  # add() defaults disp to opts; a NULL disp above means "same as OptionText".
  # (add() fills DisplayText from OptionText when it is not given.)
  do.call(rbind, ol)
}

selection_rows <- function(is_current) {
  cat_order <- c("Overall metrics" = 1, "Product and value" = 2,
                 "Service and support" = 3, "Experience and channels" = 4,
                 "Brand perception" = 5, "Loyalty" = 6, "Buying behaviour" = 7,
                 "Complaints" = 8, "Comments" = 9, "Demographics" = 10)
  qdf <- build_questions_df()
  n <- nrow(qdf)
  banners <- c("Region", "Gender", "Age_Group", "Segment")
  include <- ifelse(qdf$QuestionCode %in% c(banners, open_codes), "N", "Y")
  usebanner <- ifelse(qdf$QuestionCode %in% banners, "Y", "N")
  bannerlab <- ifelse(qdf$QuestionCode %in% banners,
                      c(Region = "Region", Gender = "Gender",
                        Age_Group = "Age", Segment = "Customer Segment")[qdf$QuestionCode], "")
  disp <- rep(NA_integer_, n)
  disp[match(banners, qdf$QuestionCode)] <- 2:5
  createindex <- ifelse(qdf$QuestionCode %in% c(rating_codes, likert_codes), "Y", "N")

  # CategoryOrder is set on the first question of each category; the rest blank.
  corder <- rep(NA_integer_, n)
  seen <- character(0)
  for (i in seq_len(n)) {
    ct <- qdf$Category[i]
    if (!(ct %in% seen)) { corder[i] <- unname(cat_order[[ct]]); seen <- c(seen, ct) }
  }

  keyshare <- rep("", n)
  keyshare[qdf$QuestionCode == "Q025"] <- "Good or excellent"
  keyshare[qdf$QuestionCode == "Q024"] <- "Would not switch"
  keyshare[qdf$QuestionCode == "Q023"] <- "Yes, fully resolved"

  csheet <- rep("", n); clink <- rep("", n)
  if (is_current) {
    csheet[qdf$QuestionCode == "Q026"] <- "Recommend"
    clink[qdf$QuestionCode == "Q026"]  <- "Q001"
    csheet[qdf$QuestionCode == "Q027"] <- "Improve"
    clink[qdf$QuestionCode == "Q027"]  <- "Q002"
    csheet[qdf$QuestionCode == "Q028"] <- "Anything else"
  }

  bf <- rep("", n); fl <- rep("", n)
  bf[qdf$QuestionCode == "Q023"] <- 'Q022 == "Yes"'
  fl[qdf$QuestionCode == "Q023"] <- "Made a complaint in the last 12 months"

  data.frame(
    QuestionCode = qdf$QuestionCode,
    Include = include,
    UseBanner = usebanner,
    BannerLabel = unname(bannerlab),
    DisplayOrder = disp,
    CreateIndex = createindex,
    Category = qdf$Category,
    CategoryOrder = corder,
    KeyShare = keyshare,
    BaseFilter = bf,
    FilterLabel = fl,
    CommentSheet = csheet,
    CommentLink = clink,
    QuestionText = qdf$QuestionText,
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------------------------
# Report narrative. Authored here, in the voice of a research report, about the
# fictional company. No em dashes.
# ------------------------------------------------------------------------------

BACKGROUND <- paste0(
  "This is a demonstration report. Every number in it comes from a synthetic ",
  "dataset generated for the purpose, and the company it describes does not exist. ",
  "Nothing here is client data.\n\n",
  "The study it imitates is an annual customer experience survey for ", COMPANY,
  ", a fictional specialist coffee roaster selling online, in store and by ",
  "subscription. A sample of 1,000 customers was drawn from the customer database, ",
  "stratified by region, and interviewed online in January and February 2025. ",
  "Three earlier waves, 2022 to 2024, are carried in the Tracking tab.\n\n",
  "The data is weighted to the regional and segment profile of the customer base. ",
  "Significance is tested at the 95% level with a Bonferroni correction across ",
  "banner columns, and the letters under each figure name the columns it beats.\n\n",
  "Three open questions were coded into themes and are reported in the ",
  "Qualitative tab. The verbatims are synthetic, written to match the codes ",
  "they carry."
)

EXEC_SUMMARY <- paste0(
  "Satisfaction has improved in every wave since 2022 and now stands at 7.0 out ",
  "of 10, up from 6.5. The gains are real but unevenly spread, and one part of ",
  "the experience is still repairing damage done in 2023.\n\n",
  "Customer service is the clearest success. It has risen in every wave, from ",
  "6.1 in 2022 to 6.9 now. The mobile app has climbed on the same pattern, from ",
  "5.3 to 6.2, but from a much lower base: it remains the weakest digital ",
  "channel, behind the website at 6.9.\n\n",
  "Delivery is the counterweight. It fell from 6.8 in 2022 to 6.1 in 2023 and ",
  "has recovered only to 6.6, still short of where it started. Eastern Cape ",
  "customers rate delivery 5.0 against 7.3 in Gauteng, and delivery is the ",
  "theme they raise most often in their own words: 61% of their comments touch ",
  "it, against 29% everywhere else.\n\n",
  "The segment picture is consistent across almost every measure. Premium ",
  "customers rate the business highest and Budget customers lowest, and the gap ",
  "is widest on customer service at 2.1 points, the largest segment gap on any ",
  "rated measure in the study. New customers are the exception: they rate the ",
  "coffee close to the average but rate ease of doing business lowest of any ",
  "group at 6.7, which points at onboarding rather than at the product.\n\n",
  "Value for money inverts that order. Budget customers rate it 6.5 and Premium ",
  "customers 5.6, so the premium proposition is being questioned by the people ",
  "paying for it.\n\n",
  "Net promoter score has moved sharply, from 7 in 2023 to 25 now. Behind the ",
  "score, coffee quality is what people volunteer as the reason to stay, ",
  "mentioned in 40% of comments and running 70 points net positive. Delivery ",
  "and price are the reasons to leave, both net negative."
)

Q_COMMENTS <- list(
  Q001 = "Recommend scores run highest in the Western Cape at 8.6 and lowest in the Eastern Cape at 7.0. The net promoter score has moved from 7 in 2023 to 25 in 2025.",
  Q005 = "Up in every wave, from 6.1 in 2022 to 6.9 now. Premium customers rate service 2.1 points above Budget customers, the widest segment gap on any rated measure here.",
  Q007 = "Delivery fell from 6.8 in 2022 to 6.1 in 2023 and has recovered only to 6.6. The Eastern Cape rates it 5.0 against 7.3 in Gauteng.",
  Q004 = "Value for money inverts the usual segment order. Budget customers rate it 6.5 and Premium customers 5.6.",
  Q009 = "The app has improved in every wave, from 5.3 in 2022 to 6.2 now, and still sits below the website at 6.9."
)

QUAL_COMMENTS <- list(
  QUAL_RECOMMEND = paste0(
    "Coffee quality is both the theme raised most often and the most positive: ",
    "40% of comments mention it, running 70 points net positive. Delivery (35%) ",
    "and price (30%) are the counterweights, both net negative. Eastern Cape ",
    "customers raise delivery in 61% of their comments, against 29% everywhere else."),
  QUAL_IMPROVE = paste0(
    "Faster delivery leads the improvement list at 39% of comments, with lower ",
    "prices and a better app close behind at 30% each. Nothing else clears a quarter."),
  QUAL_ANYTHING_ELSE = paste0(
    "Unprompted praise for staff is the most common closing remark, in 42% of ",
    "comments and 73 points net positive. Complaint handling is the most negative ",
    "at 33 points net negative, on a base of 48 mentions.")
)

Q_HEADLINES <- list(
  Q005 = "Customer service has improved in every wave since 2022",
  Q007 = "Delivery has recovered only part of the 2023 fall",
  Q004 = "Premium customers rate value for money lowest",
  Q009 = "The app is improving but is still the weakest digital channel"
)

build_comments_df <- function() {
  rows <- list(
    list(QuestionCode = "_BACKGROUND", Comment = BACKGROUND, Banner = "", Headline = ""),
    list(QuestionCode = "_EXECUTIVE_SUMMARY", Comment = EXEC_SUMMARY, Banner = "", Headline = "")
  )
  for (qc in names(QUAL_COMMENTS)) {
    rows[[length(rows) + 1]] <- list(
      QuestionCode = qc, Comment = QUAL_COMMENTS[[qc]], Banner = "", Headline = "")
  }
  for (qc in names(Q_COMMENTS)) {
    rows[[length(rows) + 1]] <- list(
      QuestionCode = qc, Comment = Q_COMMENTS[[qc]], Banner = "",
      Headline = Q_HEADLINES[[qc]] %||% "")
  }
  do.call(rbind, lapply(rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))
}

build_settings_df <- function(w, is_current, waves_dir, logo_path) {
  s <- list(
    structure_file = "Demo_Survey_Structure.xlsx",
    output_subfolder = "Output",
    output_filename = sprintf("Turas_Demo_CX_%s.xlsx", w$label),
    output_format = "xlsx",
    apply_weighting = "TRUE",
    weight_variable = "Weight",
    show_unweighted_n = "TRUE",
    show_frequency = "TRUE",
    show_percent_column = "TRUE",
    show_percent_row = "FALSE",
    decimal_places_percent = "0",
    decimal_places_ratings = "1",
    decimal_places_index = "1",
    boxcategory_frequency = "FALSE",
    boxcategory_percent_column = "TRUE",
    enable_significance_testing = "TRUE",
    alpha = "0.05",
    alpha_secondary = "0.20",
    alpha_default = "primary",
    significance_min_base = "30",
    bonferroni_correction = "TRUE",
    enable_checkpointing = "FALSE",
    create_index_summary = "Y",
    show_standard_deviation = "FALSE",
    show_net_positive = "TRUE",
    sampling_method = "Stratified",
    project_title = "Turas demo: customer experience survey (synthetic data)",
    company_name = RESEARCHER,
    research_house = RESEARCHER,
    client_name = paste0(COMPANY, " (fictional)"),
    analyst_name = "The Research LampPost",
    analyst_email = "info@researchlamppost.co.za",
    brand_colour = "#16243f",
    accent_colour = "#d99a28",
    researcher_logo_path = logo_path,
    fieldwork_dates = w$fieldwork,
    wave = w$label,
    wave_order = as.character(w$order),
    dashboard_scale_mean = "10",
    dashboard_scale_index = "5",
    dashboard_green_mean = "7",
    dashboard_amber_mean = "5",
    dashboard_green_index = "4",
    dashboard_amber_index = "3",
    chart_palette_preset = "warm",
    html_report_v2 = "Y",
    html_report_v2_microdata = "Y",
    html_report_v2_tracking = "Y",
    enable_ai_insights = "FALSE",
    # A public demo is read, not worked in: no Save copy button.
    show_save_copy = "FALSE",
    generate_stats_pack = "N"
  )
  if (is_current) {
    s$waves_source <- waves_dir
    s$html_report_v2_cover <- "Y"
    s$html_report_v2_cover_findings <- "ALL"
    s$qual_workbook <- "Demo_Comments.xlsx"
    s$qual_confidentiality_mode <- "full"
    s$qual_demographic_cuts <- "allow"
    s$qual_verbatim_scope <- "all"
    s$qual_join_id_column <- "ResponseID"
    s$patterns_headline <- "Q001, Q002"
  }
  data.frame(Setting = names(s), Value = unlist(s, use.names = FALSE),
             stringsAsFactors = FALSE)
}

# ==============================================================================
# BUILD ONE WAVE
# ==============================================================================

build_wave <- function(w, out_root, waves_dir, logo_path) {
  is_current <- identical(w$label, "2025")
  dir_w <- file.path(out_root, paste0("w", w$label))
  dir.create(file.path(dir_w, "Output"), recursive = TRUE, showWarnings = FALSE)
  set.seed(w$seed)
  n <- w$n

  region <- sample(c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"),
                   n, replace = TRUE, prob = c(0.35, 0.25, 0.25, 0.15))
  gender <- sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.48, 0.52))
  age <- sample(c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"),
                n, replace = TRUE, prob = c(0.15, 0.30, 0.25, 0.18, 0.12))
  segment <- sample(c("Premium", "Standard", "Budget", "New Customer"),
                    n, replace = TRUE, prob = c(0.20, 0.35, 0.25, 0.20))
  wt <- runif(n, 0.6, 1.6); wt <- wt / mean(wt)

  dat <- data.frame(
    ResponseID = sprintf("R%s%04d", w$label, seq_len(n)),
    Region = region, Gender = gender, Age_Group = age, Segment = segment,
    Weight = round(wt, 4), stringsAsFactors = FALSE)

  dat$Q001 <- gen_scale("Q001", n, region, segment, w$delta, 0, 10)
  for (qc in rating_codes) dat[[qc]] <- gen_scale(qc, n, region, segment, w$delta, 1, 10)
  for (qc in likert_codes) dat[[qc]] <- gen_scale(qc, n, region, segment, w$delta, 1, 5)

  dat$Q018 <- sample(c("Weekly", "Monthly", "Quarterly", "Yearly", "First time"),
                     n, replace = TRUE, prob = c(0.10, 0.30, 0.25, 0.20, 0.15))
  dat$Q019 <- sample(c("Online", "In-store", "Mobile app", "Phone", "Subscription"),
                     n, replace = TRUE, prob = c(0.35, 0.25, 0.16, 0.06, 0.18))
  dat$Q020 <- sample(c("Social media", "Word of mouth", "TV advertising",
                       "Online search", "Print media", "Email marketing"),
                     n, replace = TRUE, prob = c(0.25, 0.20, 0.15, 0.20, 0.08, 0.12))
  dat$Q021 <- sample(c("Price", "Quality", "Convenience", "Brand reputation",
                       "Recommendation", "No alternative"),
                     n, replace = TRUE, prob = c(0.20, 0.25, 0.20, 0.15, 0.12, 0.08))
  dat$Q022 <- sample(c("Yes", "No"), n, replace = TRUE, prob = c(0.22, 0.78))
  dat$Q023 <- NA_character_
  yes_i <- which(dat$Q022 == "Yes")
  dat$Q023[yes_i] <- sample(c("Yes", "No", "Partially"), length(yes_i),
                            replace = TRUE, prob = c(0.45, 0.20, 0.35))
  # Switching intent tracks the person's own NPS score, so the two agree.
  dat$Q024 <- vapply(dat$Q001, function(s) {
    if (s <= 6) sample(c("Definitely would", "Probably would", "Not sure",
                         "Probably would not", "Definitely would not"), 1,
                       prob = c(0.22, 0.30, 0.26, 0.16, 0.06))
    else if (s <= 8) sample(c("Definitely would", "Probably would", "Not sure",
                              "Probably would not", "Definitely would not"), 1,
                            prob = c(0.06, 0.16, 0.28, 0.34, 0.16))
    else sample(c("Definitely would", "Probably would", "Not sure",
                  "Probably would not", "Definitely would not"), 1,
                prob = c(0.02, 0.06, 0.14, 0.32, 0.46))
  }, character(1))
  dat$Q025 <- vapply(dat$Q002, function(s) {
    if (s >= 9) sample(c("Excellent", "Good"), 1, prob = c(0.62, 0.38))
    else if (s >= 7) sample(c("Excellent", "Good", "Average"), 1, prob = c(0.16, 0.62, 0.22))
    else if (s >= 5) sample(c("Good", "Average", "Below average"), 1, prob = c(0.20, 0.58, 0.22))
    else sample(c("Average", "Below average", "Poor"), 1, prob = c(0.18, 0.42, 0.40))
  }, character(1))

  # --- Open ends + comment workbook (current wave only) ---
  built <- NULL
  if (is_current) {
    built <- list(
      Recommend = build_comments(themes_q026, dat$ResponseID, dat$Q001,
                                 region, segment, 0.46, w$seed + 11,
                                 W_Q026, T_Q026, B_Q026),
      Improve = build_comments(themes_q027, dat$ResponseID, dat$Q001,
                               region, segment, 0.34, w$seed + 12,
                               W_Q027, T_Q027, B_Q027),
      `Anything else` = build_comments(themes_q028, dat$ResponseID, dat$Q001,
                                       region, segment, 0.21, w$seed + 13,
                                       W_Q028, T_Q028)
    )
    text_col <- function(b) {
      v <- rep(NA_character_, n)
      idx <- match(vapply(b$records, function(r) r$id, character(1)), dat$ResponseID)
      v[idx] <- vapply(b$records, function(r) r$text, character(1))
      v
    }
    dat$Q026 <- text_col(built$Recommend)
    dat$Q027 <- text_col(built$Improve)
    dat$Q028 <- text_col(built$`Anything else`)
  } else {
    dat$Q026 <- NA_character_; dat$Q027 <- NA_character_; dat$Q028 <- NA_character_
  }

  # --- Write data ---
  wb <- createWorkbook(); addWorksheet(wb, "Data"); writeData(wb, "Data", dat)
  turas_saveWorkbook(wb, file.path(dir_w, "Demo_Survey_Data.xlsx"), overwrite = TRUE)

  # --- Write structure ---
  wbs <- createWorkbook()
  project_df <- data.frame(
    Setting = c("project_name", "project_code", "client_name", "study_type",
                "study_date", "data_file", "output_folder", "total_sample",
                "weight_column_exists", "weight_columns", "default_weight"),
    Value = c(paste0(COMPANY, " customer experience survey"),
              paste0("DEMO_CX_", w$label), paste0(COMPANY, " (fictional)"),
              "Tracking", paste0(w$label, "0215"),
              "Demo_Survey_Data.xlsx", "Output", as.character(n),
              "Y", "Weight", "Weight"),
    stringsAsFactors = FALSE)
  addWorksheet(wbs, "Project");  writeData(wbs, "Project", project_df)
  addWorksheet(wbs, "Questions"); writeData(wbs, "Questions", build_questions_df())
  addWorksheet(wbs, "Options");   writeData(wbs, "Options", build_options_df())
  addWorksheet(wbs, "Composite_Metrics")
  writeData(wbs, "Composite_Metrics", data.frame(
    CompositeCode = c("COMP_SAT", "COMP_EXP"),
    CompositeLabel = c("Overall satisfaction index", "Digital experience index"),
    CalculationType = c("Mean", "Mean"),
    SourceQuestions = c("Q002,Q003,Q004,Q005", "Q008,Q009"),
    Weights = c("", ""),
    SectionLabel = c("Overall metrics", "Experience and channels"),
    stringsAsFactors = FALSE))
  turas_saveWorkbook(wbs, file.path(dir_w, "Demo_Survey_Structure.xlsx"), overwrite = TRUE)

  # --- Write comment workbook ---
  if (is_current) {
    wbc <- createWorkbook()
    prompts <- c(Recommend = q_text[["Q026"]], Improve = q_text[["Q027"]],
                 `Anything else` = q_text[["Q028"]])
    for (sh in names(built)) {
      addWorksheet(wbc, sh)
      writeData(wbc, sh, comment_sheet_frame(built[[sh]], prompts[[sh]]),
                colNames = FALSE)
    }
    turas_saveWorkbook(wbc, file.path(dir_w, "Demo_Comments.xlsx"), overwrite = TRUE)
  }

  # --- Write config ---
  wbcfg <- createWorkbook()
  addWorksheet(wbcfg, "Settings")
  writeData(wbcfg, "Settings", build_settings_df(w, is_current, waves_dir, logo_path))
  addWorksheet(wbcfg, "Selection")
  writeData(wbcfg, "Selection", selection_rows(is_current))
  if (is_current) {
    addWorksheet(wbcfg, "Comments")
    writeData(wbcfg, "Comments", build_comments_df())
  }
  cfg_path <- file.path(dir_w, sprintf("Demo_Crosstab_Config_%s.xlsx", w$label))
  turas_saveWorkbook(wbcfg, cfg_path, overwrite = TRUE)

  cat(sprintf("  wave %s: n=%d -> %s\n", w$label, n, cfg_path))
  invisible(cfg_path)
}

# ==============================================================================
# RUN
# ==============================================================================

waves_dir <- normalizePath(file.path(out_root, "waves"), mustWork = FALSE)
dir.create(waves_dir, recursive = TRUE, showWarnings = FALSE)
logo_path <- file.path(turas_root, "examples/tabs/demo_survey/TRL_logo_high_quality.svg")

for (w in waves) build_wave(w, out_root, waves_dir, logo_path)

cat("\nDone. Configs written under", out_root, "\n")
