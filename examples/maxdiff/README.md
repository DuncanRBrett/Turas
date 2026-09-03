# MaxDiff example: Karoo Coffee Roasters

A complete, runnable MaxDiff study for a fictional specialist coffee roaster.
Ten things a customer might value when choosing a roaster (freshness, named
origin, price, delivery, a subscription they can pause, and so on), 400
synthetic respondents, 8 tasks of 4 items each, 3 design versions. Everything
here is synthetic. No client data is involved at any point.

The responses were simulated from known utilities, so a run can be checked
against the truth. The true order is in `karoo_maxdiff_true_utils()` in
`create_maxdiff_example.R`: freshness first, then named origin, then price,
with decaf and loyalty rewards last. The Budget segment leans to price and
rewards; Premium leans to origin and ethical sourcing.

## Files

| File | What it is |
|---|---|
| `Karoo_MaxDiff_Config.xlsx` | The ANALYSIS config. Run this. |
| `Karoo_MaxDiff_Data.xlsx` | One row per respondent: `RespID`, four segment columns, `Version`, `T1_Best` .. `T8_Worst` holding item ids, and `MustHave` (the anchor question, comma-separated item ids). |
| `Karoo_MaxDiff_Design.xlsx` | The design the module's own DESIGN mode generated. |
| `Karoo_MaxDiff_Design_Config.xlsx` | The DESIGN-mode config that produced it. |
| `create_maxdiff_example.R` | Rebuilds all of the above from scratch. |

## Run it

From the Turas root, either through the GUI (`launch_turas()`, MaxDiff,
pick `Karoo_MaxDiff_Config.xlsx`) or headless:

```bash
Rscript -e 'source("modules/maxdiff/R/00_main.R"); run_maxdiff("examples/maxdiff/Karoo_MaxDiff_Config.xlsx")'
```

It writes into `examples/maxdiff/Output/`:

| Output | Setting |
|---|---|
| `Karoo_MaxDiff_Results.xlsx` | always |
| `Karoo_MaxDiff_Results_stats_pack.xlsx` | `Generate_Stats_Pack` |
| `Karoo_MaxDiff_Results_md_island.json` | always. Point a tabs config's `maxdiff_island` at it and the interactive report gains a MaxDiff tab. |
| `Karoo_MaxDiff_Results_tabs_shares.xlsx` | `Generate_Tabs_Export`. Each respondent's preference shares as a tabs Allocation question (`MDSHARE_1` .. `MDSHARE_10`), with the QuestionMap and Options rows to paste. |
| `Karoo_MaxDiff_Results_simulator.html` | `Generate_Simulator`. The standalone simulator: preference shares, head-to-head, portfolio builder. |

## What to expect without cmdstanr

The module's hierarchical Bayes model runs in Stan. On a machine without
cmdstanr it falls back to an empirical-Bayes approximation on the count
scores, and says so everywhere: the console, the SUMMARY sheet, the island,
the MaxDiff tab and the tabs export. This example is configured for that
world. `Allow_Approx_Utilities_Export = YES` lets the fallback through the
tabs export, and the export is then stamped "approximate: count-based" in the
QuestionText and the METHOD sheet. With cmdstanr installed the same config
fits the Stan model and the stamp disappears.

## Rebuild the example

```bash
Rscript examples/maxdiff/create_maxdiff_example.R . examples/maxdiff
```

The script runs the module's DESIGN mode for the design, simulates the
choices, and writes the data and the analysis config. The integrated demo in
`examples/integrated_demo` sources the same script and passes its own
respondent frame, so the same people answer the survey, the conjoint and the
MaxDiff, and the exported shares join to the survey data by id.
