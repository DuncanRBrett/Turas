# What-if driver simulator: planning notes

Planning session, 23 Sep 2026. Nothing here is built into Turas.
BUILD BRIEF: docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md (five sessions, SACAP first). Prototypes and
fit scripts live in this folder; see README.md for how to run them.

## The idea in one paragraph

Take one outcome question and the service or experience questions around it. Fit
a model of how the outcome depends on them. Let a client pick a group of real
respondents and ask "what happens to the outcome if this improves, slips, or is
extended to everyone who lacks it?". The answer is the change in the outcome for
that group, with a range. The business question it serves is "where should we
direct resources?". The Economist-style "build a person" view is the hook that
gets people to play; the group what-if is where the value is.

The outcome does not have to be NPS. Any outcome with two or more ordered or
unordered categories works: brand user or not, satisfied (top two box) or not,
consideration, renewal intent, a 5-point overall rating. A continuous outcome
(a mean score) is the keydriver module's territory, not this one.

## What the two datasets showed

All figures are from scratch Python fits on the real files, run 23 Sep 2026.
Cross-validated McFadden pseudo R squared unless stated.

| | SACAP 2025 students | CCPB 2026 outlets |
|---|---|---|
| n | 1,361, weighted | 753, unweighted |
| NPS | 46.6 | 79.4 (17 detractors) |
| Who they are (context) alone | about 0.00 | about 0.00 |
| Experience ratings alone | 0.198 | 0.162 (promoter vs rest) |
| Context added to ratings | worse (0.184) | worse (0.144) |

Context never predicts on its own. CORRECTED 23 Sep 2026 (see "How robust is it"): added to the
ratings WITH a ridge penalty, it improves SACAP's held-out fit and fixes its group calibration.

CCPB specifics:

- Ceiling. Ratings average about 9 of 10. The downside of a slip is larger than
  the upside of an improvement (delivery: about 8 NPS points lost for one point
  down, about 4 gained for one point up).
- The three rep questions correlate at 0.80 to 0.85. Entered separately, "rep
  overall" came out negative. Averaging them into one lever fixed it.
- Ordinal model (Detractor < Passive < Promoter) fits slightly better than
  multinomial (0.133 vs 0.127) and moves outlets down to Detractor, so NPS
  losses are not understated the way the promoter-only model understates them.
- Service coverage matters beyond ratings: having coolers about +6 NPS, knowing
  the sales manager about +8, CCPB doing the merchandising about +8. Size and
  channel controls barely changed these.
- Allowing signage does nothing on its own; signage condition among outlets that
  have signage does (0.172 to 0.205 in that subset). Cooler satisfaction adds
  nothing once coolers are in.
- Fountains: 30 outlets. Too few to test.
- Invoicing and "offered a promotion" fail the sign check (wrong way in 38% and
  26% of bootstrap refits). Invoicing has almost no variation (84% give 9 or 10).
- "Called CCPB in the last 12 months" (about -11) and "shops around" look like
  levers and are not. One is a symptom of a problem, the other is loyalty itself.
- 2025 vs 2026: the ranking of rating levers held (delivery first, invoicing
  last). Sizes moved; the rep lever grew, but its 2025 version lacks Q202, so it
  is not like for like. This is a stability comparison, not a backtest.
- Value for effort differs from total gain. Fixing the rep for the 99 outlets
  rated below 8 gives the most per outlet reached (about 19 net promoters per
  100 outlets). Extending CCPB merchandising gives the biggest total gain but
  means reaching 592 outlets.

## Blind spots

1. Benefit is not value. "Where to direct resources" needs cost. The tool shows
   benefit only. The honest proxy is room to act (how many need fixing) and gain
   per outlet reached. A client-entered cost per lever would close the loop.
2. Association is not cause. People who like the brand rate everything higher
   (halo). SACAP's "value for money" behaves like a second outcome, not a lever.
   Brand image attributes will be worse than service ratings on this: users
   credit their own brand with everything.
3. Symptoms and outcomes pose as levers. Contact, complaints, shopping around,
   switching intent. Every lever list needs a human pass that asks "can the
   client actually pull this?".
4. Overlapping items flip signs. Group correlated questions into one lever and
   refuse any lever whose sign is unstable.
5. Not everyone gets every service. Routed questions must be modelled as "has
   the service" plus "rating if they have it", and a scenario on that rating
   applies only to those who have it. Median imputation is wrong for routing.
6. Impossible combinations, two kinds. Context: CCPB has 9,240 possible cells,
   276 that exist, 138 with a single outlet; Indirect method only goes with
   Indirect size; offices nest in centres. Levers: a signage rating for an outlet
   without signage. Fix: cascading choices that only offer what exists, and
   levers that switch off when they cannot apply.
7. Disclosure. A group of one is an identifiable outlet. The what-if needs every
   respondent's ratings in the page because the model is not linear. That single
   fact decides the architecture (see decision 1).
8. One lever at a time never happens in real life. Improvements come in bundles.
   The scenario builder covers this; the default table does not.
9. Ceilings shrink the evidence. At CCPB each slope rests on the minority who
   scored lower. Ranges show it; the text must say it.
10. Drivers drift between waves. A tracker should show driver effects per wave,
    and the real test is whether groups whose ratings moved had outcomes move as
    predicted. With about 10 CCPB offices that test will be noisy.

## Where it fits in a Turas project

Survey_Structure (question types, routing, Composite_Metrics) -> data -> tabs as
now -> a driver-simulator config (outcome, levers and how items group into them,
coverage and nested levers, context for group picking, minimum group size) -> an
R fit with bootstraps -> a report island that recalculates in the browser, like
the conjoint simulator -> composed into the report hub, hardened last.

Catdriver is the natural home for the outcome side: it already fits binary,
ordinal and multinomial outcomes, takes weights and a subgroup variable. It does
not fit the lever side as it stands. `08a_guards_hard.R` refuses continuous
drivers, and an ordinal driver becomes one dummy per level, so a 1 to 10 rating
would become nine separate effects. The simulator needs a "score" driver type
(one straight-line effect per point) plus composites and nested levers.

## Decisions for Duncan

1. Disclosure architecture. DECIDED 23 Sep 2026: both, chosen per project. Open
   mode ships respondent rows (national and panel studies). Client-safe mode ships
   the model plus precomputed group results (list studies), with the minimum
   counted on respondents. See "Two delivery modes" below.
2. Model. DECIDED by Duncan, 23 Sep 2026: ordinal by default (binary when the
   outcome has two categories, multinomial only for genuinely unordered outcomes).
3. Where the code lives. Option A: extend catdriver with a score driver type and
   a simulator output. Option B: a new module that calls catdriver's engines.
   Recommendation: B, because it leaves catdriver's reports and guards untouched
   and the simulator has its own config and island. Worth a proper look at
   catdriver before deciding.
4. Lever tagging. Who marks a variable as rating, coverage, nested, symptom or
   context? Recommendation: the config, with a preflight that flags likely
   symptoms (contact, complaints, switching) and overlapping items for review.

## Client-safe mode (checked on SACAP 2025, 23 Sep 2026)

Client-safe in Turas means no respondent-level island and a release audit. The
prototypes ship every respondent's ratings, so they would fail it. A client-safe
version is possible with a different split:

- "Build a student" is already safe. It needs only the model coefficients, which
  are fitted on everyone. Drop the matched-n line and the "show a real student"
  button; those are the parts that touch individuals.
- The group what-if is precomputed in R and shipped as group results only: actual
  NPS, room to act per lever, and each lever's slip and fix with ranges.
- Groups offered: whole sample, each single context variable, and a two-way
  crossing only if EVERY cell clears k. Suppressing some cells of a crossing while
  showing its margin lets subtraction recover them (the SACS cube hole).
- SACAP at k = 5: all single-variable groups pass (smallest is Masters, n = 21);
  2 of 6 crossings pass (campus x new/returning, course x new/returning). At
  k = 3 a third passes (year x new/returning). No three-way crossing passes at
  either. Course and year here are the collapsed prototype versions.
- Combined scenarios: adding up single-lever results matches the exact answer
  closely most of the time (825 random 2 to 4 lever combos in 165 groups: median
  error 0.6 NPS points, 90th percentile 3.8, worst 10.9, against a median change
  of 16.7). So free combos can ship as "approximate", with named bundles from the
  config precomputed exactly.
- k = 3 is not defensible. At n = 3 the group NPS has seven possible values, room
  to act reads "1 of 3", and a zero gain from "+1 notch" says all three already
  answered Excellent. k = 5 is the floor; results below 30 are also statistically
  thin, which matches SACAP's significance_min_base of 30.

## Two delivery modes (Duncan, 23 Sep 2026)

National and panel studies do not need client-safe: the client cannot know who
the respondents are. List studies (students, staff, outlets) may need it: the
client knows everyone in the population. The simulator must do both, from one
fit and one page design, with the output builder as the only difference.

| | Open | Client-safe |
|---|---|---|
| Build a person | yes | yes (coefficients only) |
| "Real respondents like this" count, "show a real respondent" | yes | no |
| Groups offered | any combination | whole sample, single variables, and crossings where every cell clears the minimum |
| Group what-if | exact, calculated in the browser from respondent rows | precomputed in R, shipped as group results |
| Combined scenarios | exact | sum of single levers, labelled approximate; named bundles exact |
| Release audit | not required | required; the build refuses if it fails |

Settings, reusing what tabs already has so one project-level choice governs
both reports:

- Mode follows the tabs "Who is this file for?" choice. No separate switch.
- `min_reporting_base`: the minimum group. 5 on SACS; any number.
- The minimum counts respondents, as tabs does today. DECIDED by Duncan, 23 Sep
  2026: a population basis was considered and dropped. It only protects when the
  client cannot tell who answered, and list studies often let them tell (prize
  draw entries, reminder lists, tracked links, near-total response in a small
  group). SACAP's frame also has population for campus and course only, so most
  groups would have been refused anyway.
- A separate reliability floor on respondents (flag below 30, SACAP's
  significance_min_base). Disclosure and reliability are different questions:
  a group can clear the minimum of 5 and still say almost nothing.

## Client-safe SACAP prototype (built 23 Sep 2026)

`fit_sacap_safe.py` and `template_sacap_safe.html`. The page carries the model
(201 sets of 8 coefficients) and precomputed results for 57 groups, nothing per
respondent. Minimum group 5 respondents; smallest published group 14. Refused:
campus by course, campus by year, course by year, year by new or returning (each
has at least one cell under 5). Differencing check: 0 failures. An independent
check on the built HTML found no list of respondent length (longest 201). The
page repeats the audit in the browser and says so.

Model: ordinal, weighted, ratings only. Assessment feedback and email
responsiveness fail the sign check (wrong way in 31% and 28% of refits) and show
greyed. Bundles exact against sum of parts, all students: teaching +16.0 against
+16.7, service +7.5 against +7.6.

### Revised 23 Sep 2026: secondary suppression, age and gender

All or nothing hid whole crossings for one small cell. Replaced by secondary
suppression: hide cells under the minimum, then the smallest cells in the same
row or column until every row and column hides nothing or at least the minimum.
Age and gender added (gender: Female, Male, Other or not said). A cross-table
check was also needed: publishing "Online Access, Honours year" next to "Online
Access, BSocSci Honours" let one student be recovered by subtraction, and two
similar pairs existed. The build now hides the inner group of any such pair and
repeats until none remain. Longer chains across several tables are not checked.

Published groups by minimum (respondents), SACAP 2025, 10 breakdowns:

| Minimum | Groups published | Campus by course shown (of 53) | Course by age shown (of 84) |
|---|---|---|---|
| 2 | 342 | 43 | 74 |
| 3 | 315 | 38 | 66 |
| 5 | 289 | 38 | 55 |
| 10 | 228 | 30 | 34 |

SACAP's invitation promises results "in an aggregated format" and "no way your
answers can be identified to you". At a minimum of 2, each student in the group
can read the other's answer by removing their own. The prototype stays at 5.

DECIDED by Duncan, 23 Sep 2026: the minimum group defaults to 5 respondents and
can be set per project.

## How it presents in a Turas report (checked against the code, 23 Sep 2026)

The tabs v2 report already carries other modules as tabs. Catdriver writes a
contribution file (`{output}_cd_island.json`); the tabs setting
`catdriver_island` points at it; `run_crosstabs.R` reads it; `build_report_v2.R`
includes `27j_catdriver.js` only when it is there; `24_shell.js` adds the tab to
the "Read" group. Conjoint, MaxDiff, Pricing and Key drivers work the same way.
The simulator would be one more: a `simulator_island` setting, a
`{output}_sim_island.json` file, a `27w_simulator.js` renderer, and a "What if"
tab in the Read group.

The report's data mode decides how the tab behaves
(`html_report_v2_interactivity`: records, cube or none):

- records (open): the tab is LIVE. The group is whatever the report's filter bar
  says, including custom filters. Ratings come from the microdata the report
  already carries, so the simulator file adds only the model. Catdriver's tab is
  frozen because a model cannot be re-fitted in the browser; the simulator can be
  live because it only applies a fixed model to a different set of people.
- cube (client-safe): the filter bar offers only published slices. The tab shows
  precomputed results for the current slice, and says plainly when a slice has
  none. One minimum and one suppression rule should govern both the cube and the
  simulator.
- none: precomputed results for the whole sample and each banner column.

The secondary suppression and cross-table check built for the simulator are the
same problem as the SACS cube hole (`cube_order = 1` is the stop-gap). Built once
in the shared disclosure layer, they would fix both.

A clickable mockup of the tab is in `template_whatif_mockup.html` (built 23 Sep
2026). Open mode recalculates exactly for any filter; client-safe mode allows two
filters, offers only published groups, and greys out hidden ones and undeclared
breakdowns. For all students the two modes give identical numbers.

Revised 23 Sep 2026 after Duncan's review: (1) the scenario result now shows in
the scenario card, before and after on an NPS line; it used to update only the
summary card at the top, so it looked dead. (2) "Build a student" is now the
Economist-style line: pick campus, course, year, new or returning, gender, age,
and full or part time, and see that profile's expected NPS against all students,
with a 90% range. It uses a second, additive model on who the student is (ridge
penalty 5, chosen by cross-validation; held-out pseudo R squared 0.012). Profiles
of real students run from about 21 to 65. The ratings-based view moved to "Rate
SACAP as one student". Open mode shows how many real students match a profile
(5 or more) and their actual NPS; client-safe mode shows the estimate only.

To check before building: that every lever question is in the microdata (a
question with Include = N may not be), and how pins and the Story tab capture a
live panel.

## Generic engine and the CCPB tab (23 Sep 2026)

The SACAP-only mockup became `whatif_engine.py` plus one study file per client
(`study_sacap.py`, `study_ccpb.py`) and one page template (`template_whatif.html`).
A study file is the prototype of the config a Turas build would read: outcome,
levers with their kind (rating, nested, coverage) and grouped items, context for
filters, the profile sentence, declared crossings, bundles and symptoms.

SACAP through the engine reproduces the earlier numbers exactly. CCPB: lever model
held-out pseudo R squared 0.172; 244 groups publish at a minimum of 5 (5 hidden by
the nesting check). The profile model includes coverage facts (coolers, knows the
sales manager, who merchandises), which is why it moves more than SACAP's (real
outlet profiles 67 to 90, held-out 0.017). Spaza, delivery and rep both slipping
one point: 82 to 69 exact in the open view, 71 approximate client-safe.

## How robust is it (robustness.py, run 23 Sep 2026)

| Check | SACAP | CCPB |
|---|---|---|
| Hand-built ordinal fit against R `ordinal::clm` | identical to 4 decimals | identical to 4 decimals |
| Proportional odds (`nominal_test`, p<0.05) | 1 of 8 terms fails: value for money | 0 of 11 fail |
| Held-out fit, ordinal against multinomial | 0.201 vs 0.197 | 0.172 vs 0.145 |
| Straight line per point against a separate effect per band | 0.201 vs 0.189 | 0.174 vs 0.164 |
| Groups of 30+ whose held-out predicted NPS misses the actual beyond its 95% band | 6 of 36 (about 2 expected) | 1 of 41 (about 2 expected) |
| Highest correlation between rating levers; largest variance inflation | 0.71; 2.3 | 0.38; 1.3 |
| Additive shortcut (client-safe) against exact, random 2 to 4 lever moves | median 0.3, worst 5.6 points | median 0.3, worst 4.9 points |

What this says:

- The engine computes what it claims: it matches the standard R package exactly.
- The model's assumptions hold, with one exception: value for money in SACAP
  behaves differently at the Detractor and Promoter ends. A partial model (one
  extra slope for that lever) would handle it; the ranking is unaffected.
- The main weakness was calibration in SACAP. Honours students recommend SACAP
  far less than their ratings predict (actual 24, predicted 43 for BSocSci
  Honours); 18 to 20 year olds and the Higher Certificate far more. Something
  outside the eight ratings drives those groups.
- Fix, tested: add who the respondent is to the lever model as baselines, with a
  ridge penalty on those terms. SACAP: held-out fit 0.201 to 0.213, groups outside
  their band 6 to 0, median group error 4.3 to 1.1 points. CCPB: no change
  (Restaurants stay under-predicted, actual 97 against 78). The build should do
  this, penalising only the context terms and choosing the penalty by
  cross-validation. The prototype pages do not do it yet.
- What no check can settle: cause. These are cross-sectional associations. The
  honest reading is "outlets that rate delivery one point lower recommend less by
  this much", not "fixing delivery will add this much". The tracker backtest is
  the closest test available.
- Not yet checked: bootstrap intervals treat the survey weights as fixed; "don't
  know" is set to the middle score; CCPB has only 17 detractors, which the ordinal
  model handles by sharing slopes, but the detractor end is thinly evidenced.

## Setting it up for any study

The study files are the prototype of a config. In Turas it would be a workbook,
with labels, scales and routing read from Survey_Structure:

- Settings: outcome question and how to band it (NPS 0 to 10, top two box, an
  ordered scale), the unit noun, weight variable, minimum group, reliability floor.
- Levers: label, question(s) averaged into it, kind (rating, coverage, nested),
  what counts as having the service, the fix target (Good, 8), include or exclude
  as a symptom.
- Profile: the questions that describe a respondent, in sentence order, with the
  words between them.
- Filters and crossings: the audience variables and the declared two-way
  breakdowns, like a banner.
- Bundles: named combinations of moves.

A preflight would flag what still needs judgement: rating questions correlating
above about 0.7 (group them), a sign that flips across refits, routed questions
(make them nested), and likely symptoms (contact, complaints, switching).

## The profile builder on staff surveys (SACS question, 23 Sep 2026)

The group what-if (effort table, scenarios) is fine for a staff survey such as
SACS under the client-safe rules. The "Build an employee" profile line is not:

- The sentence can describe a real person. In the SACS 2025 delivered file, 57 of
  144 commenters were alone in their campus, department and tenure combination.
  The estimate is not their answer, but it will be read as theirs, against an
  invitation that promises no way to identify individual responses.
- A characteristic's effect is learned from its members, so a level with fewer
  than the minimum (a two-person department) leaks a near-average of those people.
- The page ships the bootstrap refits; for staff surveys ship only the ranges.

The SACAP client-safe mockup has the same issue more mildly: 532 of 1,361
students are in groups under 5 on just four of its seven characteristics.

DECIDED by Duncan, 23 Sep 2026 (staff surveys): (1) a per-study switch for the profile builder, off by
default for employee surveys and any study where the client manages the
respondents; (2) in client-safe mode, the builder offers only combinations that
at least the minimum number of real respondents share, and every level entering
the profile model must itself clear the minimum. The ratings-only view uses no
demographics and stays on.

## Weights (checked on SACAP, 23 Sep 2026)

Weighting is a per-study setting that must match the study's report. SACAP
student reports have always run unweighted (Duncan, 23 Sep 2026), so
`study_sacap.py` now sets USE_WEIGHTS = False and the mockup shows NPS 45.6, as
SACAP's report does; the earlier prototypes used the weighted file (46.6).
National studies may run either way. CCPB CSAT runs unweighted.

The engine already takes a weight column; SACAP runs weighted. SACAP's weights run
0.20 to 3.69, design effect 1.12 (1,361 students count as about 1,215). Weighted
against unweighted, all students: value for money -26.6 / +14.3 against -26.3 /
+14.1; held-out fit 0.201 against 0.204; two near-tied areas swap rank, inside their
ranges. Same picture for Honours. Group counts for the privacy rules stay
unweighted, which is correct. CCPB would take weights the same way; the open
question is what population CCPB would weight to. One limit: the bootstrap keeps
each respondent's weight fixed rather than re-weighting every resample, so ranges
are a little narrow when weights are heavy. Fine at a design effect of 1.1; worth
re-raking inside the bootstrap if a study's design effect is above about 1.5.

## A brand tracker such as IPK (thinking, not tested on IPK data)

From the IPK notes: four focal categories (each respondent answers one: BAK 250,
PAS 300, POS 300, DSS 350), a six-level brand attitude per brand, awareness and
purchase, category entry points, a female-only panel sample. What changes:

- The unit is a respondent-brand pair, not a respondent. Each person rates every
  brand in their category, so the data is stacked, each brand needs its own
  baseline, and the bootstrap must resample people, not rows.
- Outcome: attitude collapsed to an order (Love or Prefer / Ambivalent or Price /
  Avoid, with No opinion left out), or bought in the last 3 months.
- Levers: mostly yes/no links between a brand and an entry point or asset. That is
  the coverage kind, but "extend to everyone" is unrealistic for a brand, so it
  needs a partial move: "10% more category buyers link IPK to X".
- Halo is much stronger than for service ratings: buyers link their own brand to
  everything because they buy it. The honest designs split the question: what
  moves non-buyers toward considering, and what keeps buyers loyal, fitted
  separately, or with past purchase as a baseline.
- The natural extension is share shift: model the choice among brands, so a
  what-if says which competitors IPK would take from. That is the conjoint
  simulator's pattern applied to survey data.
- Per-category fits on 250 to 350 people give wider ranges, and small brands will
  be thin.
- The sample is an anonymous panel, so open mode and the profile builder are fine
  (skip gender: female only).
- It would sit in the brand report, following its portfolio pattern (focal brand
  picker, JSON payload, JS re-render). New brand R files must be added to
  .source_brand_module() or they never load.
- A tracker is where the backtest becomes real: did brands whose links moved
  between waves move in attitude as predicted?

## No impossible students (Duncan, 23 Sep 2026)

Build a student must not offer an impossible combination, such as a Masters
student on the Bachelor of Social Work. Constrain structural traits only (course,
year, campus, full or part time), from data-derived rules Duncan confirms in the
config; never block personal traits. Numbers and the design are in the build
brief, decision 10. The prototype pages do not do this yet.

## Prompts to direct the next session

1. "Read prototypes/nps-simulator/PLAN.md and the catdriver module. Recommend
   whether the driver simulator should extend catdriver or be a new module that
   calls its engines, with the file-level changes each would need. No code."
2. "Design the driver-simulator config sheet: outcome, lever groups, coverage and
   nested levers, symptom exclusions, context, minimum group size. Show it as a
   filled example for CCPB 2026 and for SACAP 2025."
3. "Run the group-level backtest on CCPB: fit on 2025, predict each office's 2026
   NPS from its 2026 ratings, and compare with actual. Report honestly, including
   if it fails."
4. "Try the simulator on a brand outcome (brand user yes or no) with image
   attributes as levers, and measure how much halo inflates the effects compared
   with service ratings."
