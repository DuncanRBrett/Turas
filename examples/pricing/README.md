# Pricing example: Karoo Coffee, what should a 250 g bag cost?

A complete, runnable pricing study for a fictional roaster. Everything is
synthetic and simulated from known quantities, so a run can be checked against
the truth. No client data is involved at any point.

## What is here

| File | What |
|---|---|
| `create_pricing_example.R` | The generator. Simulates the respondents and writes the data and configs below. |
| `Karoo_Pricing_Data.xlsx` | 400 respondents: RespID, Region, Gender, Age_Group, Segment, a Weight column (mean 1), the four Van Westendorp answers, a five-rung Gabor-Granger ladder (`GG_R60` to `GG_R140`, 0/1), the same ladder as a stop-early copy (`GGS_`, blank above the first No), and a monadic cell (`MON_Price`, `MON_Intent` on a 1 to 5 scale). |
| `Karoo_Pricing_Config.xlsx` | Van Westendorp and Gabor-Granger together, weighted, segmented by customer segment, with bootstrap intervals. The main example. |
| `Karoo_Pricing_Config_Monadic.xlsx` | The monadic cell test on the same people. |
| `Karoo_Pricing_Config_StopEarly.xlsx` | Gabor-Granger on the stop-early ladder. The module refuses it: the rungs have different bases. |
| `Karoo_Pricing_Config_StopEarly_Imputed.xlsx` | The same ladder with `GG_Stop_Early_Imputation = NO_AFTER_STOP`. Runs, and says what it imputed. |

The configs use the template's own setting names, so they exercise the same
loader path a hand-edited template takes.

## Run it

From the Turas root, either pick a config in the pricing GUI
(`launch_turas()`), or:

```bash
Rscript -e 'source("modules/pricing/R/00_main.R"); run_pricing_analysis("examples/pricing/Karoo_Pricing_Config.xlsx")'
```

Outputs land in `examples/pricing/Output/`: the results workbook, the stats
pack, and plots.

To rebuild the data and configs (for instance after changing the generator):

```bash
Rscript examples/pricing/create_pricing_example.R
```

## What to expect

`karoo_pricing_truth()` in the generator states the bands a correct run must
land in. On the weighted sample the Van Westendorp optimal price point sits in
the 80 to 115 rand band, the acceptable range runs from the 60s to the 130s,
Gabor-Granger demand falls from above 70% at R60 to below 40% at R140, and the
monadic price slope is negative. `test_karoo_example.R` in the module's test
suite asserts all of this on every run.

Three behaviours the example is built to show:

- **Weighting.** The weight over-represents the Western Cape, which values the
  bag more, so the weighted Van Westendorp points sit above the unweighted
  ones. The stats pack names the estimator (`psm_analysis_weighted`) and the
  Kish effective sample size.
- **Intransitive respondents.** About 8% have their cheap and expensive
  answers swapped. Under the default `VW_Monotonicity_Behavior = drop` they
  are excluded and the analysed base is reported; `flag_only` keeps them in
  the curves and says so.
- **Stop-early ladders.** The `GGS_` columns are blank above a respondent's
  first No, the way a sequential ladder comes out of a survey tool. Counting
  only the survivors at each rung would make demand barely fall, so the run
  refuses unless the config opts into `NO_AFTER_STOP`.

## The integrated demo

`examples/integrated_demo` builds a survey, a conjoint and a MaxDiff for the
same Karoo respondents and reports them in one tabs v2 report. The pricing
half of that (a Pricing tab and a crosstabbable acceptance grid) is the v2
session's work; this example's functions take a respondent frame so the demo
can reuse them.
