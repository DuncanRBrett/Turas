# What if module: blindspot pass on the results approach

Written 24 September 2026 as a research and education pass, not a build. The
trigger was The Economist's "Donald Trump's disintegrating coalition"
interactive (10 September 2026). Nothing in the repo was changed. Probe scripts
live in the session scratchpad; every number below says where it came from.

## Verdict

The core approach holds. A penalised proportional-odds model with ridge-shrunk
context baselines, bootstrap ranges, a sign check and counterfactual moves is a
sound way to answer "what would this group's NPS do if an area moved", and two
worries I brought to it were tested and closed. One real blind spot is open: the
effort table ranks areas by their partial effect, which systematically punishes
any area that shares variance with the halo carrier (value for money on SACAP).
That changes wording and flagging, not the engine. One shipped-number edge
exists around don't-know answers. The Economist piece suggests two things the
programme does not yet have: a causal ordering with mediators, and a
wave-to-wave decomposition of who moved.

## What the Economist actually did

From the data team's Off the Charts post "Welcome to the statistical
dollhouse" (the article itself is paywalled and could not be read):

- 58,000 YouGov respondents since January 2026, with demographics, 2024 vote,
  Trump approval and midterm intention.
- A nested chain of three models: demographics predict the 2024 vote; that plus
  demographics predicts approval; that plus both predicts the midterm vote.
- A database of 22 million profiles, "each representing a group of voters
  with shared demographics". That it carries a population count per profile,
  so any built voter and any group aggregates to the electorate, is my
  inference from how such frames work, not something the post says.

Build a student is the direct analogue and the module already has it. The
effort table has no Economist analogue; it is a different tool.

## Checked and holds

Run on the SACAP 2025 prototype file (`prototypes/nps-simulator/build/model_sacap.json`:
weighted, n 1,361, NPS 46.6, ratings 1 to 5 with don't-know at the centre, the
old multinomial prototype's data), five-fold cross-validation with the module's
own fold layout (seed 7), using the module's fit functions.

Pooled slopes. The engine gives every group the same slope per rating; groups
differ only in where their ratings sit. I tested whether letting slopes vary by
campus, year or course predicts better on held-out data. Ratings only: pseudo
R2 0.2032. Ridge-shrunk interactions: campus 0.2022, year 0.2096, course
0.2112. Fully separate fits per level collapse (campus 0.181, course 0.139, year
negative). A gain of 0.008 at best does not justify per-group slopes. Pooling is
right.

Reference-level coding under ridge. The baselines drop the modal level and
shrink the others toward it, which in principle makes the answer depend on the
reference. Measured on the four context variables in the prototype file, groups
of 30 or more (23 groups, not the README's 36, which used more variables):
reference coding (penalty 5) held-out R2 0.2146, 0 of 23 groups outside their
band, median group error 1.5; all-level symmetric coding
(penalty 10) 0.2142, 0 of 23, median error 2.3. Swapping the course reference to
its rarest level moves the lever slopes by at most 0.013. Harmless.

Also already on record from `robustness.py` (23 September): fit equals
`ordinal::clm`, proportional odds holds except value for money, a straight
line per point beats bands, the additive shortcut is within 0.3 points at the
median.

## The open blind spot: partial effects punish shared variance

Every move in the tab holds all other ratings fixed. That is the right
counterfactual for "what is unique to this area", and the wrong one for "what
happens if we fix this area", because ratings move together, partly through
halo (people who like SACAP rate everything higher) and partly through real
spillover (better email responsiveness makes admin feel better).

Measured, all students, lift everyone below Good to Good:

| Area | Need | Others fixed | Others co-move |
|---|---|---|---|
| Value for money | 471 | +14.3 | +20.8 |
| Educators | 173 | +2.2 | +6.8 |
| Student admin | 392 | +2.2 | +9.2 |
| Course content | 148 | +1.9 | +5.7 |
| MySACAP | 207 | +1.3 | +5.2 |
| Staff friendly | 188 | +1.2 | +5.3 |
| Email responsiveness | 481 | +0.9 | +10.3 |
| Assessment feedback | 373 | +0.5 | +9.4 |

The need column counts the prototype file's don't-knows, which sit at the
centre (59 on value for money), so the don't-know edge described below is
already inside these numbers. "Others co-move" shifts every other rating by
its sample regression slope on the moved one. It is a ceiling that includes reverse causation and must never
ship as a number. The teaching point is the shape: the tab's column is a floor
for any area caught in the halo, and the gap between floor and ceiling is
largest for exactly the areas the tab says are worth least. A client reading
"+0.5 for assessment feedback" will conclude it is worthless. The data cannot
say that.

A standard key driver analysis on the same eight ratings (LMG, the Shapley
decomposition of a linear R2 of 0.341; scratchpad script) gives value for
money 35.5% of explained variance, course content 15.0, educators 14.1, staff
8.0, admin 8.0, assessment feedback 6.8, MySACAP 6.4, email 6.2. Same leader,
much flatter tail: LMG puts value for money at 2.4 times the next area, the
partial floor effect at 6.5 times. Other agencies' driver outputs, which SACAP
may have seen, use LMG or relative weights, so the tab will look harsher on the
tail than anything they have been shown before.

What good looks like here:

- Keep the partial effect as the number. Label it in the column note as the
  change with every other area held where it is.
- Add a per-area "halo" flag as a ratio: fit each rating lever on its own
  (the single-lever ordinal effect of the same move) and flag the area when
  its partial effect is below some fraction of that, say a third. A top-half
  versus bottom-half rule does not work: assessment feedback and email both
  have a marginal correlation of 0.32, bottom half of the eight, and would not
  flag. Say "caught in the halo, the model cannot separate it", the same way
  the sign check already greys an unstable area. The sign-check sentence in
  the tab is the right register.
- Put the LMG share in the stats pack beside the effort table so the ranking
  can be reconciled with a conventional driver analysis.
- Treat value for money as a mediator, not a lever, in the next version (below).

## Where the Economist chain helps: mediators and ordering

PLAN.md already calls value for money "a second outcome". The Economist's nested
chain is the modelling consequence: commit to an ordering (service ratings feed
value for money, value for money and service ratings feed NPS), fit the two
stages, and report each service area's direct effect plus its indirect effect
through value for money. ACSI's PLS-SEM does the same with quality feeding
value feeding satisfaction. This resolves the floor-and-ceiling problem in a
principled way for one named mediator, with cross-sectional data still unable
to rule out reverse causation. It is a version 2 change to the engine and the
config (a "mediator" lever kind), not a patch.

## Where the Economist headline helps: who moved between waves

The article's product is "which groups left the coalition". The Turas analogue
is a shift-share (Kitagawa) decomposition of a tracker's NPS change: how much
of the wave-to-wave movement is groups changing size, and how much is groups
changing their own NPS, with the largest within-group movers named. Brief
section 7 has a backtest; nothing in PLAN.md or the brief has this. CCPB has two
waves with the same questions and about 10 offices, so the group level would
have to be coarse. This is the most direct borrowing from the piece, and it is a
tracker feature rather than a What if feature.

## Poststratification

The 22 million profiles look like a population frame. Turas already has the
Population sheet, which for SACAP covers campus and course only. With it, Build
a student could answer "for the whole student body" by weighting profiles to
the population rather than the sample, and an empty campus by course cell
would vanish because it has no population count. Course by year, the case the
Structure rules exist for, has no population counts, so the rules stay. Minor
now; worth remembering if the frame ever grows.

## Shipped-number edge: don't-know answers in the need count

Verified by reading the code, not by running it. `09_prepare.R` fills a
don't-know rating with the scale centre or the rounded median (config
`dont_know`, default median). `whatif_need_mask()` in `04_moves.R` counts
anyone below the fix target as needing the fix, and the floor move lifts them.
Nothing excludes filled don't-knows from either. So with `dont_know = centre` on
a 1 to 5 scale, every don't-know on value for money (59 of them on SACAP 2025)
counts as a student who needs value for money fixed and contributes a lift of
one scale point to the estimate. With the median rule it depends on whether the
median sits below the target; on SACAP 2025 the median is Good on all eight
ratings (checked in the prototype file), so they drop out there, but a lever
with a median of 3 would pull them back in. A
don't-know has no rating to lift. The clean rule is to leave don't-knows out of
the need count and out of every rating move, and report their number beside the
need, as the config template already promises.

## Smaller potholes

- The floor move lifts everyone below Good to Good. Real interventions shift a
  distribution; some move one point, some none. The brief's brand plan has a
  partial "10 more in 100" move; the same idea (lift a share of those in need)
  belongs on ratings too, as a second scenario type, not a replacement.
- The tab anchors scenarios on the group's actual NPS and adds the model's
  change. Right choice; keep it, and keep the calibration table so a reader
  sees where the model's own level misses.
- Bootstrap keeps weights fixed. Fine at SACAP's design effect of 1.12, as the
  brief says. The trigger to re-rake inside the bootstrap (design effect above
  about 1.5) should be checked by preflight rather than remembered.
- Only 17 detractors on CCPB. Modelling the raw 0 to 10 answer as an eleven
  category ordinal outcome and banding the predicted probabilities afterwards
  would use every respondent's exact score and share the slope across all ten
  thresholds. Not testable here (the prototype JSON holds banded outcomes
  only); worth one run on CCPB when the data is to hand.

## Questions Duncan does not yet know to ask

- Did CCPB 2025 and 2026 survey the same outlets? If they are matched, a
  within-outlet change model (does an outlet whose delivery rating fell see its
  recommend score fall?) removes outlet-level halo and is both the strongest
  backtest and the best estimate the programme could have. Nothing else in the
  toolkit gets closer to cause.
- Which area is the halo carrier in each study? On SACAP it is value for money.
  On CCPB it may be the sales rep. The preflight could name it: the rating with
  the highest average correlation with the others.
- What does the client already believe the ranking is? If they have seen an
  LMG-style driver chart, the tab's flatter-then-steeper ranking needs the
  reconciliation line in the stats pack.
- How will the report say "we cannot tell" for an area? The sign check has a
  register for it. The halo flag needs the same one.

## Prompts to direct the next work

1. "In modules/whatif, exclude don't-know respondents from whatif_need_mask()
   and from every rating move, keep reporting their count beside the need, and
   add a test on the synthetic fixture where a don't-know sits below the
   target. Do not run a client config; I will rerun SACAP 2025 myself and
   report which need counts moved." (Question for Duncan first: which
   `dont_know` setting is in the SACAP config he was sent? The module default
   is median; session 1 reproduced the prototype's numbers, which used centre.)
2. "Add a halo flag to the What if engine and tab: for each rating lever, fit
   the same move with that lever alone and compare it with the partial effect;
   flag the area when the partial effect is under a third of the single-lever
   effect, and show it in the tab in the same register as the sign check. Put
   the LMG relative importance shares in the stats pack next to the effort
   table. Tests first."
3. "Design, do not build, a mediator lever kind for the What if engine: a
   named rating (value for money on SACAP) fitted as an outcome of the other
   ratings and as a lever for NPS, with each service area's direct and indirect
   effect reported. Read docs/v2_lift/BLINDSPOT_WHATIF_RESULTS_2026_09_24.md
   first and say what the config, the tab and the stats pack would show."
4. "For the tracker module, design a shift-share decomposition of the
   wave-to-wave change in NPS by a chosen group variable: composition change
   versus within-group change, with the largest movers named. Use CCPB 2025 and
   2026 as the worked example and say what the tab would show."
5. "Check whether CCPB 2025 and 2026 sampled the same outlets (Response ID or
   outlet name in both data files). If at least 100 match, fit a within-outlet
   change model of recommend on the five rating levers and compare its slopes
   with the What if cross-sectional slopes."

## Sources

- The Economist data team, "Welcome to the statistical dollhouse", Off the
  Charts (Substack), September 2026.
- The Economist, "Donald Trump's disintegrating coalition", 10 September 2026
  (paywalled; only the Substack description was read).
- ACSI methodology (PLS-SEM, quality to value to satisfaction).
- Brandt's penalty-reward contrast analysis; Matzler and Sauerwein 2002 on
  asymmetric attribute effects (the module's straight-line check already
  tested and rejected bands on these two studies).
- Gertheiss and Tutz on penalised categorical predictors (reference-level
  question, closed by measurement above).
