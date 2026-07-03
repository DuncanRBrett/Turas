# Reader Experience Plan — tabs v2 (Phase C, 2026-07-03)

Goal: the report "feels good but slightly clumsy". Make it clearer and more
usable for the READER (client stakeholder), not just the analyst. Principles
from Duncan's reporting standards, applied to an interactive report: the
insight leads, evidence supports, metadata always visible, story flow over
questionnaire flow, verbatims connected to the numbers.

Duncan has okayed source-format changes where they help ("historical reasons").

---

## A. Quick wins (low risk, high polish)

**A1. Fixed card anatomy.** Every dashboard/summary card gets fixed slots:
score top-left · question code top-right · band bar · title (2 lines max) ·
one META ROW at the foot holding the 💬 comments pill, 📌 pin and Δ chip.
Nothing may overlap the score (the current 💬 pill does — task already chipped
for a separate session). Same anatomy on every tab that renders cards.

**A2. `ShortLabel` in the source format.** Cards/charts/tracking/PPTX titles
currently truncate questionnaire wording mid-word ("good educatio..."). Add an
optional `ShortLabel` column to the QuestionMap; used wherever space is tight,
falling back to auto-trim. One analyst-authored phrase fixes every surface.

**A3. One audience strip, every tab.** A slim persistent strip: current cut
(filter/composite) · base n (weighted + effective when weighted) · wave.
Readers must always know WHO the numbers describe. (The audit found tabs
handling this differently — patterns hid the filter bar entirely.)

**A4. One "How to read this" panel.** Sig letters, lowercase 80% letters,
▲▵ arrows, strong/moderate/weak bands, the Precision Estimate — one
consolidated explainer opened from a single ⓘ; the long PE sentence on the
dashboard collapses to that icon after first view (dismiss persisted). Kills
scattered per-tab legends.

**A5. Consistency sweep.** Same slot + order for pin/comments/export controls
on every card and drawer; one number-format rule everywhere; one Δ chip style.
Each tab evolved its own conventions — unify.

## B. Reading layer (medium)

**B1. Read vs Analyse navigation.** The tab bar has outgrown one row:
- READ: Dashboard · Patterns · Tracking · Qualitative · Story
- ANALYSE: Crosstabs · Differences · Summary (+ exports)
Two visual groups (or an "Analyse" cluster), reading surfaces first. This is
the single biggest de-clumsifier.

**B2. Plain-language significance.** Letters are analyst-speak. Reader toggle
(default ON for saved copies): hover/callout renders sentences — "Durban
(62%) is meaningfully lower than the overall result (74%)". The engine already
computes everything; this is presentation only. Letters remain for analysts.

**B3. Insight titles on cards.** Where an analyst comment (Comments sheet),
promoted hub insight, or a flagged significant difference exists, the card
shows a one-line insight ABOVE the question text — the "slide title is the
insight" rule, applied to cards. Auto-sentences only when unambiguous;
analyst text always wins.

## C. Qualitative presentation (the Phase C core)

**C1. Quote-first typography.** Verbatims are the product here: larger quote
type on a comfortable measure, attribution/demo tags as quiet chips under the
quote, sentiment as a thin edge accent (never colour-only). Curated first:
shortlisted/highlighted quotes render at the top ("Analyst's selection"),
"show all N" expands the rest.

**C2. Theme cards connect to the numbers.** Each theme: salience, sentiment
split (diverging, never sized by volume), and 1–2 championed quotes inline —
plus, when the open question links to a closed question, the closed stat on
the card ("Registration rated 78.3 · 106 comments"). Verbatims tied to the
quant finding, per the reporting standard; the 💬 jump becomes bidirectional.

**C3. "Everything else" is a first-class theme.** Unthemed comments get the
same card treatment (not a flat tail list) + a coverage bar ("83% of comments
themed") so readers see how complete the framing is. Dovetails with
OPEN_END_CODING_PLAN.md — the deductive frame will lift coverage; the UI
should already report it.

**C4. Focus reading mode.** Full-width single-column quote flow for a theme
(or the collection/hub), j/k + arrow keys, Esc out. For the reader who wants
to actually READ the voice of the customer for ten minutes.

## D. Story tab as the decision document (bigger)

**D1. Landing = exec summary.** For saved/shared copies, the report opens on
a cover: headline (analyst-authored), 3–5 key findings (story pins + promoted
hub insights rendered as insight sentences with their evidence thumbnails),
then "explore the dashboard →". The CEO-only-reads-titles test, applied to
the report itself. Analyst copies keep opening on the dashboard.

**D2. Pins read as insights.** Pin titles default to the insight sentence
(editable), not the question label — flows straight into the Phase D PPTX
rebuild (insight title + chart + metadata = a proper slide).

## E. Source-format changes (approved direction)

- `ShortLabel` column (A2)
- Explicit `Scale_Min`/`Scale_Max` columns (removes inference; feeds bands,
  index math, chart axes)
- Declared open↔closed question links in the QuestionMap (today partly
  heuristic; one column makes C2 robust)
- Analyst headline field per question (extends the Comments sheet) powering B3

## Sequencing

1. A1–A5 as one polish pass (fast, all low-risk, all testable in the JS harness)
2. C1–C3 (qual presentation, the stated Phase C heart) + B1 navigation
3. B2–B3, C4
4. D1–D2 rolled into Phase D (PPTX rebuild shares the insight-title spine)

Each numbered item is independently shippable; suites stay green per item.
