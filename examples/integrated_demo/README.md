# Integrated demo: survey, conjoint and MaxDiff in one report

One command builds a complete study for a fictional company, Karoo Coffee
Roasters, runs the conjoint and maxdiff modules on it, and produces a tabs v2
report that carries the survey crosstabs, a Conjoint tab, a MaxDiff tab, the
two modules' per-respondent exports as crosstabbable questions, and links to
both standalone simulators. Everything is synthetic. No client data is
involved at any point.

## Run it

From the Turas root:

```bash
Rscript examples/integrated_demo/build_integrated_demo.R
```

It takes a couple of minutes; the conjoint's hierarchical Bayes estimation
(bayesm, 600 respondents) is the slow part. Then open

```
examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html
```

in a browser. The Conjoint and MaxDiff tabs sit in the Read group of the tab
bar. In the crosstabs, `CJIMP` (conjoint attribute importance) and `MDSHARE`
(MaxDiff preference shares) are Allocation questions, so the model results
can be read by region, gender, age and customer segment, with significance
letters, like any other question. Both simulators sit beside the report and
the two tabs link to them.

## What the script does

| Step | What happens |
|---|---|
| 1 | Draws 600 synthetic respondents with region, gender, age and customer segment. |
| 2 | Simulates a short customer survey: NPS, four ratings, two agreement items, buying frequency and channel. Premium customers rate quality higher, Budget customers rate value higher, the Eastern Cape rates delivery lower. |
| 3 | Simulates a choice-based conjoint (roast, origin, pack size, price, delivery; 10 sets of 3) from known part-worths. Budget weighs price more and origin less; Premium the reverse. |
| 4 | Builds the MaxDiff through the module's own DESIGN mode (`examples/maxdiff/create_maxdiff_example.R`) and simulates the choices for the same respondents. |
| 5 | Runs the conjoint module (HB) and the maxdiff module. Each writes its Excel deliverable, stats pack, island file, tabs export and simulator. |
| 6 | Joins the two tabs exports to the survey data by respondent id. |
| 7 | Writes the tabs Survey_Structure and Crosstab_Config, with `conjoint_island` and `maxdiff_island` pointing at the two island files and the Allocation questions declared from the exports' own QuestionMap snippets. |
| 8 | Runs tabs and copies the two simulators beside the report. |

## What to look for

- The MaxDiff tab and the MaxDiff simulator both say the utilities are the
  empirical-Bayes fallback, because cmdstanr is not installed. The MDSHARE
  QuestionText in the crosstabs carries the same stamp. With cmdstanr
  installed the same script fits the Stan model and the stamp disappears.
- The Conjoint tab shows importance and part-worths with honest intervals
  (posterior standard errors, heterogeneity shown separately).
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
