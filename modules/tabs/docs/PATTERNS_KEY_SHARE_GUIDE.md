# Patterns and closed questions — the KeyShare column

**Status:** live from 2026-07-17 (branch `feature/tabs-patterns-key-share`).

The Patterns tab used to read one kind of question: rated scales with an
index. On an engagement study that covers nearly everything. On a study like
CCPB CSAT — 95 questions, 58 of them Single_Response — it read about a
quarter of the survey and was silent on the rest.

KeyShare fixes that. It is one optional column on the config's Selection
sheet, next to CreateIndex. You name the one answer whose share summarises
the question, and the question joins the scan: group portraits, the split
pointer, the GPS line, and the same multiple-comparison trust-gate the rated
questions go through. "Depot X is under strain on its ratings — yet leads
every depot on correct-day delivery (84% vs 71%)" becomes a sentence the tab
can find and prove.

## The one rule

**Name the answer where a higher share is better.** That is the whole
contract. The engine never guesses direction — the data cannot tell it that
"Always" is good on delivery-day but "Always shop around" is bad. You
declare it; anything undeclared stays out of the scan, and the tab says so
rather than pretending it looked.

When the natural summary of a question is a problem share, flip it. On "Is
language a problem?" don't tag the problem — tag `Not a problem`. The
portrait then reads "leads on language" instead of a double negative.

## What to enter

The exact label of an option, a BoxCategory, or a NET row. Matching trims
spaces, ignores case, and treats non-breaking spaces as spaces (Alchemer
option text is full of both), but it is otherwise exact — a typo means the
question quietly stays out, so eyeball the Patterns tab after a regen. A
grouping (box/NET) wins over a single option with the same name. On a
Multi_Mention question the share is "% who mentioned it".

Leave it blank for profile and preference questions — order method,
franchise vs independent, who takes the order. There is no good direction
there, so there is nothing honest to scan. And don't tag rated questions:
CreateIndex already carries them, and a KeyShare on a rated question is
ignored.

Don't tag everything that can be tagged. A portrait shows a group's top
lows and highs; forty tagged trivia questions crowd out the story. Tag the
service-delivery checks and the funnel/loyalty markers — the questions a
depot manager would actually be judged on.

## What it does and does not touch

Tagged shares join: the group portraits (as real cells, "62% / 71%"), the
which-split-matters pointer, the one-line GPS answer, the per-cell BH
correction and the per-group consistency test (so a share-heavy study gets
the same never-cry-wolf gate), and the reliability ribbon's n.

They stay out of: the Dashboard (that remains rated-only), the weakest/
strongest area cards, the odd-one-out and hidden-disagreement checks (both
are scale-point machinery), and the Tracking tab.

## Worked example — CCPB CSAT W2026

Suggested values, read straight from the live survey structure. These are
suggestions — the direction call is yours, especially the flagged ones.

| Question | KeyShare | Note |
|---|---|---|
| Q11 rotates your stock | `Always` | |
| Q12 correct delivery day | `Always` | |
| Q17 display advertising material | `Always` | |
| Q18 restock the cooler | `Always` | |
| Q19 clean the cooler | `Always` | |
| Q20 rotate stock in store | `Always` | |
| Q21 product free of dust | `Always` | |
| Q29 offered a sales promotion | `Yes` | |
| Q30 take stock count | `Always` | |
| Q31 collect damaged goods | `Always` | |
| Q33 aware of sales manager | `Yes` | |
| Q34 manager visit frequency | `Quarterly or better` | BoxCategory |
| Q53–Q57 fountain service checks | `Always` | five questions |
| Q58 fountain cleaning | `Every 6-8 weeks` | |
| Q59 staff sanitising training | `Every 6-8 weeks` | |
| Q74 Eyethu | `I have joined Eyethu` | funnel share |
| Q77 language a problem | `Not a problem` | flipped |
| Q05 shop around | `Only buy from Coca-Cola Peninsula Beverages` | loyalty share — your call whether exclusivity is the story |

Worth a look before tagging: Q06 (MyPenbev interest) has "Not sure" grouped
into the `Interested` box in the current structure — either fix the box or
tag `Very interested`. Q32 (relationship ladder) has no grouping; if you
want it in, add a BoxCategory for the top rungs first. Leave Q01, Q51, Q52,
Q70 and the preference multis blank — no direction.

## Worked example — SACS-2025

The engagement battery is rated and already fully scanned; most of SACS
needs nothing. The real win is the values battery (Q18–Q23: integrity,
excellence, team-ness, results, person-centred, purposeful). It has
CreateIndex = N, so today it sits outside both the Dashboard and Patterns.
Tag each with its existing box, `Always or often`, and the six values join
the campus and department portraits — which is exactly where "Marketing is
low on person-centredness but high on results-orientation" comes from.

## Worked example — SACAP Student 2025

Categorical-heavy: 41 Single_Response questions, most untouched by the old
scan. The behavioural claims are the prize — they are the funnel:

| Question | KeyShare | Note |
|---|---|---|
| Q019 actually recommended SACAP | `Yes` | |
| Q020 suggested against studying | check wording | if this is the warn-off question, the favourable share is `No` |
| Q023 lived up to expectations | `Completely` | or add a Mostly+Completely box first and tag that |
| Q054 used the eBooks function | `Yes` | |

The WIL/practicum participation questions (Q031–Q048) can be tagged `Yes`
if participation is the story that wave; they run on their course-filtered
bases either way. Registration and profile questions stay blank.

## Area cards and the AreaSummary column (added 2026-07-17)

The weakest/strongest area cards used to require two questions per theme
and flat-average them. Both rules were wrong on a study built the classic
way — component ratings plus a section-overall question. The customer has
already weighed the components in the overall; averaging it back in with
them produces a number nobody rated, and barring one-question areas kept
a 9.5 Orders rating out of the race while a two-question 8.85 "won".

Now: any tagged theme is an area, one question is enough, and an area
scores on its **summary question** — mark it with `Y` in a new
`AreaSummary` column on the Selection sheet. A single-question area needs
no marker. A multi-question area with no marker still falls back to the
flat average, and the card states that basis. The strongest/weakest race
runs within one scale family, so an NPS-only area is never crowned
against 0–10 ratings.

CCPB W2026 AreaSummary fills: Q08 (Deliveries), Q27 (Salesperson), Q46
(Coolers), Q64 (Fountains). Signwriting has no overall question — it
ranks on its average and says so (worth adding an overall next wave).
Orders/Invoicing/Call centre/Merchandising/MyPenbev are single-question
areas — nothing to fill. The Overall category (Q78 + Q79) mixes a 0–10
with an NPS, so it is correctly dropped from the area race; those two are
the apex tiles via `patterns_headline`.

## Two Settings-sheet levers (added 2026-07-17)

Both are rows on the config's Settings sheet, both optional, both parsed as
comma/semicolon-separated lists.

**`patterns_exclude_banners`** — banner labels (or ids) the Patterns scan
must skip. Operational cuts like Interviewer are fieldwork QC, not client
story: without this, the tab's lead portrait can be an interviewer effect
("Lebogang carries a tension…"). The banner stays everywhere else —
crosstabs, Differences — it just never becomes a portrait.
CCPB W2026: `Interviewer`.

**`patterns_headline`** — pins the apex KPI tiles to these question codes,
in order. Without it the tab auto-detects satisfaction/overall-titled
questions and takes the first three in questionnaire order — on CCPB that
put delivery, invoicing and merchandising in the tiles (two of them both
labelled "Satisfaction") and left the actual headlines, Q78 overall
performance and Q79 recommend, off the page entirely.
CCPB W2026: `Q78, Q79`.

The third lever already existed: `show_patterns` = N hides the tab.

## The config echo (added 2026-07-18)

Every Patterns lever is validated at generation time against what the data
layer actually contains, and the outcome is printed to the console and added
as a "Patterns configuration" section on the Report tab's statistical-
diagnostics panel (it travels inside saved copies). A misspelt banner name, a
KeyShare label that matches no option, an AreaSummary on an untagged question
— each gets a ⚠ line saying what will be ignored and why, instead of silently
doing nothing. The matching rules mirror the report engine exactly (NBSP/case
forgiven, NETs before options, score-difference NETs never bind), so a ✓ in
the echo is a promise about what the report will do. A config with no
Patterns levers prints nothing.

## Mechanics, for the record

- The column flows Selection sheet → orchestrator → report island as
  `q.key_share`; no survey-structure changes, and old configs regenerate
  byte-identically.
- Statistically, a tagged share is tested exactly like a rated question:
  each group vs the rest on a weighted 0/100 per-respondent encoding (a
  Welch t on 0/100 is the two-proportion z-test), through the same
  Benjamini-Hochberg pass and per-group sign test, with a 10pp variance
  floor standing in for the rated scales' 10%-of-scale floor.
- Displayed values are always the two real crosstab cells — the group's
  share and the overall — never a synthetic aggregate.
- Tests: `tests/takeout_tests.mjs` (KeyShare suite), `portrait_tests.mjs`,
  plus the R config/data-layer suites.
