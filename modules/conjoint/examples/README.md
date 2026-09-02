# Conjoint example: a smartphone choice-based conjoint

A complete, runnable example for the Turas conjoint module. Fifty synthetic
respondents each answered eight choice sets of three smartphones, described
on five attributes. Everything here is synthetic.

## Files

| File | What it is |
|---|---|
| `example_config.xlsx` | The config. Run this. Settings, Attributes and Instructions sheets. |
| `sample_cbc_data.csv` | The choice data: one row per alternative shown (1,200 rows), `chosen` = 1 on the picked one. |
| `create_example_config.R` | Rebuilds `example_config.xlsx` from scratch. |
| `test_analysis.R` | Runs the example end to end and prints the result. |
| `test_market_simulator.R` | Exercises the share-prediction and sensitivity functions on the example's utilities. |
| `output/` | Where a run writes. |

## Run it

From the Turas root, either through the GUI (`launch_turas()`, Conjoint,
pick `example_config.xlsx`) or headless:

```bash
Rscript -e 'source("modules/conjoint/R/00_main.R"); run_conjoint_analysis("modules/conjoint/examples/example_config.xlsx")'
```

or

```bash
Rscript modules/conjoint/examples/test_analysis.R
```

The config asks for hierarchical Bayes (bayesm, in renv). A run takes a few
seconds and writes into `output/`:

| Output | Setting |
|---|---|
| `example_results.xlsx` | always |
| `example_results_stats_pack.xlsx` | `generate_stats_pack` |
| `example_results_cj_island.json` | always. Point a tabs config's `conjoint_island` at it and the interactive report gains a Conjoint tab. |
| `example_results_tabs_importance.xlsx` | `generate_tabs_export`. Each respondent's attribute importance as a tabs Allocation question (`CJIMP_1` .. `CJIMP_5`), with the QuestionMap and Options rows to paste. Needs `hb` or `latent_class`. |
| `example_results_simulator.html` | `generate_html_simulator`. The standalone market simulator. |

Fifty respondents is small for HB. Expect a convergence warning and a
PARTIAL status; that is the module being honest about the sample, not a
fault in the example.

## What to expect

The data was simulated from known utilities:

| Attribute | Levels, best to worst |
|---|---|
| Brand | Apple (+0.8), Samsung (+0.4), Google (+0.2), OnePlus (-1.4) |
| Price | $299 (+1.2), $399 (+0.4), $499 (-0.3), $599 (-1.3) |
| Screen Size | 6.7 inches (+0.6), 6.1 inches (0.0), 5.5 inches (-0.6) |
| Battery Life | 24 hours (+0.8), 18 hours (0.0), 12 hours (-0.8) |
| Camera Quality | Excellent (+0.7), Good (0.0), Basic (-0.7) |

So Price and Brand should carry the most importance and Screen Size the
least, with Battery Life and Camera Quality close together in the middle.
The part-worth order within each attribute should match the table.

## Adapt it for your own study

1. Copy `example_config.xlsx`.
2. On the Attributes sheet, list your attributes and their levels
   (`LevelNames`, comma-separated, in the order you want them reported).
3. On the Settings sheet, point `data_file` at your data and `output_file` at
   where the results should go. The data needs one row per alternative shown,
   with respondent, choice-set and chosen columns named as in the settings.
4. Run it as above.

## Troubleshooting

A boxed SETTING RETIRED notice means the config carries a row nothing reads
any more (older templates had `generate_html_report`, `baseline_handling`
and others). The run continues; delete the row.

A refusal naming `PKG_BAYESM_MISSING` or `PKG_MLOGIT_MISSING` means R was
started outside the Turas folder, so renv did not activate. Run from the
Turas root.
