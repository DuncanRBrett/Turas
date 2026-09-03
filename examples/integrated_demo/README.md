# Integrated demo: survey, conjoint, MaxDiff and pricing in one report

One command builds a complete study for a fictional company, Karoo Coffee
Roasters, runs the conjoint, maxdiff and pricing modules on it, and produces a
tabs v2 report that carries the survey crosstabs, a Conjoint tab, a MaxDiff
tab, a Pricing tab, the three modules' per-respondent exports as crosstabbable
questions, and links to the standalone simulators. Everything is synthetic. No
client data is involved at any point.

## Run it

From the Turas root:

```bash
Rscript examples/integrated_demo/build_integrated_demo.R
```

It takes a while; the conjoint's hierarchical Bayes estimation (bayesm, 600
respondents) and the MaxDiff Stan model are the slow parts, and with cmdstanr
installed the whole build can run to half an hour. Then open

```
examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html
```

in a browser. The Conjoint, MaxDiff and Pricing tabs sit in the Read group of
the tab bar. In the crosstabs, `CJIMP` (conjoint attribute importance) and
`MDSHARE` (MaxDiff preference shares) are Allocation questions and `GGACC`
(the Gabor-Granger acceptance ladder) is a Multi_Mention, so all three sets of
results can be read by region, gender, age and customer segment, with
significance letters, like any other question. The simulators sit beside the
report and their tabs link to them.

The three module tabs are frozen: the results were estimated once on the whole
sample, so the audience filter is hidden while one is open. The crosstab
exports are the filterable half, which is why both exist.

## What the script does

| Step | What happens |
|---|---|
| 1 | Draws 600 synthetic respondents with region, gender, age and customer segment. |
| 2 | Simulates a short customer survey: NPS, four ratings, two agreement items, buying frequency and channel. Premium customers rate quality higher, Budget customers rate value higher, the Eastern Cape rates delivery lower. |
| 3 | Simulates a choice-based conjoint (roast, origin, pack size, price, delivery; 10 sets of 3) from known part-worths. Budget weighs price more and origin less; Premium the reverse. |
| 4 | Builds the MaxDiff through the module's own DESIGN mode (`examples/maxdiff/create_maxdiff_example.R`) and simulates the choices for the same respondents. |
| 4b | Simulates the pricing questions on the same respondents through `examples/pricing/create_pricing_example.R`: the four Van Westendorp prices and a five-rung Gabor-Granger ladder. |
| 5 | Runs the conjoint, maxdiff and pricing modules. Each writes its Excel deliverable, stats pack, island file, tabs export and simulator. |
| 6 | Joins the three tabs exports to the survey data by respondent id. |
| 7 | Writes the tabs Survey_Structure and Crosstab_Config, with `conjoint_island`, `maxdiff_island` and `pricing_island` pointing at the three island files, and the exported questions declared from the exports' own QuestionMap snippets. |
| 8 | Runs tabs and copies the simulators beside the report. |

## What to look for

- The MaxDiff tab and the MaxDiff simulator name the estimator that actually
  ran. With cmdstanr and CmdStan installed the script fits the Stan model and
  nothing is stamped. Without them the run falls back to empirical Bayes, and
  the tab, the simulator and the MDSHARE QuestionText in the crosstabs all
  carry the approximate stamp. The MaxDiff tab's Spread (SD) column is the
  variation across respondents on either path; a Mean SE column appears only
  when a posterior produced one, so only under Stan.
- `GGACC` by customer segment shows Budget falling away fastest as the price
  rises. On the standalone pricing example, acceptance runs 85% at R60 down to
  12% at R140 for Budget, against 86% down to 51% for Premium: a 73-point drop
  against 35. The generator gives Budget a lower value anchor, so this is the
  shape the synthetic data was built to have.
- The Conjoint tab shows importance and part-worths with honest intervals
  (posterior standard errors, heterogeneity shown separately).
- The Pricing tab names its estimator too: with a weight variable set, the Van
  Westendorp points come from `psm_analysis_weighted` on a survey design, and
  the panel says so. Each price point carries the bootstrap interval that
  brackets it, and the Gabor-Granger table shows what was observed beside the
  smoothed curve that is published.
- In the crosstabs, MDSHARE by customer segment should show Budget high on
  "A lower price per kilogram" and "Loyalty rewards on repeat orders" and
  Premium high on "Single-origin beans with the farm named". CJIMP by
  segment should show Budget putting more importance on price.

## Doing this for a real project

The same recipe, by hand:

1. Run conjoint and maxdiff on their own configs. Turn on
   `generate_tabs_export` (conjoint) and `Generate_Tabs_Export` (maxdiff).
2. Merge each export's DATA sheet onto the survey data by respondent id.
3. Paste each export's QUESTIONMAP_SNIPPET rows into the Survey_Structure
   (Questions and Options).
4. In the Crosstab_Config, set `html_report_v2 = TRUE`, `conjoint_island`
   and `maxdiff_island` to the island files the modules wrote.
5. Run tabs. Copy the simulators next to the report if you want the links to
   resolve.
