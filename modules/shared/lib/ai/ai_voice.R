# ==============================================================================
# SHARED AI — PROSE VOICE (single source of writing-voice guidance)
# ==============================================================================
# One canonical voice fragment, appended to the SYSTEM prompt of every AI call
# that writes reader-facing PROSE: the tabs insight callouts, the two-stage
# executive summary, and the reader-report narrative. It is deliberately NOT
# added to the fact-check / selectivity / pattern QA calls, where a writing
# voice is irrelevant.
#
# WHY THIS EXISTS. Each generator used to carry its own partial, divergent voice
# rules — two half-overlapping banned-word lists, and the executive summary had
# none at all. This consolidates them into one source of truth and adds the rule
# they all missed: what makes AI prose read as AI is ABSTRACTION and SIGNPOSTING,
# not vocabulary. "There is a tension worth explaining" has no banned words in
# it; the failure is naming an abstraction instead of the concrete thing, and
# announcing an insight instead of stating it.
#
# KEPT IN SYNC with Duncan's `duncan-writing-style` skill (its "de-AI checklist"
# and "narrating research findings" rules). Change the register there too.
#
# LOADING. Registered in the tabs report loader (modules/tabs/lib/html_report/
# 99_html_report_main.R) and the reader's on-demand loader
# (.reader_ensure_ai_layer in reader_ai_prose.R). Call sites read it defensively
# via get0("TURAS_PROSE_VOICE", ifnotfound = ""), so a run in which it was not
# sourced degrades to no-voice rather than erroring — the report always builds.
# ==============================================================================

TURAS_PROSE_VOICE <- paste0(
  "VOICE — write like a sharp, experienced analyst talking straight to the ",
  "reader, in South African English (colour, organisation, behaviour). Short, ",
  "clear sentences. Contractions are fine. Never a consultancy slide.\n",
  "- State the finding in plain words FIRST; the number follows as evidence, ",
  "not as the headline. Give every number a plain consequence or comparison ",
  "using only figures you were given -- never compute a new figure, and never ",
  "a vague adjective (\"a significant increase\").\n",
  "- Do NOT name an abstraction and stop. Never write that there is \"a ",
  "tension\", \"a disconnect\", \"a dynamic\", \"a gap\", \"a story\" or \"a ",
  "shift\" -- say the concrete thing itself. If a group or a result has a ",
  "shape, list its actual parts.\n",
  "- Do NOT signpost. Never announce that something is interesting, striking, ",
  "important or \"worth noting\", and never end on \"a question this raises\". ",
  "State the point; if it matters, the reader will see it.\n",
  "- Say whether a finding is CLAIMED or ACTUAL, especially when concern only ",
  "appears because it was asked. Name what the data cannot tell you rather than ",
  "overreaching; small-base subgroups are leads, not verdicts.\n",
  "- Banned words and tics: delve, dive into, unpack, landscape, journey, ",
  "leverage, holistic, nuanced, robust (unless statistical), \"key takeaway\", ",
  "\"it's worth noting\", \"at the end of the day\"; em-dash pile-ups; tidy ",
  "\"not just X but Y\" symmetry; showy triads; aphorisms used as filler."
)
