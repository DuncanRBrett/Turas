# Website demo build

How `/Users/duncan/Dev/TRL Website/demo/turas-demo.html` is produced. Everything
here is synthetic. The fictional company is "Karoo Coffee Roasters" and no
client data, config or output is touched at any point.

Built 2 September 2026. These files are UNTRACKED: commit them only if you want
the demo to be reproducible from the repo.

## What it makes

Four waves (2022, 2023, 2024, 2025) of a fictional customer experience tracker.
The three earlier waves exist only to feed the Tracking tab; the 2025 wave is
the demo report itself and carries the microdata island, the comment workbook,
the Comments-sheet narrative and the cover flag.

## Rebuild

```
OUT=/tmp/turas_website_demo
mkdir -p "$OUT/waves"
Rscript examples/tabs/demo_survey/website_demo/build_website_demo.R /Users/duncan/Dev/Turas "$OUT"

for W in 2022 2023 2024; do
  Rscript -e 'source("modules/tabs/run_tabs.R"); run_tabs_analysis(commandArgs(TRUE)[1])' \
    "$OUT/w$W/Demo_Crosstab_Config_$W.xlsx"
done
cp "$OUT"/w202{2,3,4}/Output/*_wave.json "$OUT/waves/"

Rscript -e 'source("modules/tabs/run_tabs.R"); run_tabs_analysis(commandArgs(TRUE)[1])' \
  "$OUT/w2025/Demo_Crosstab_Config_2025.xlsx"

python3 examples/tabs/demo_survey/website_demo/scrub_client_names.py \
  "$OUT/w2025/Output/Turas_Demo_CX_2025_report.html" \
  "/Users/duncan/Dev/TRL Website/demo/turas-demo.html"
```

Run it from the Turas repo root. `waves_source` is written as an absolute path,
so `$OUT` must be the same folder on the rebuild as on the generate.

## The three scripts

| file | what it does |
|---|---|
| `build_website_demo.R` | writes the four waves' data, structure, config and comment workbook |
| `facts.R` | prints the observed figures, so every sentence in the executive summary can be checked against the numbers it describes |
| `scrub_client_names.py` | replaces real client abbreviations that the renderer carries in its own source comments (CCPB, SACAP, SACS, CCS, IPK, ASSA, VAS). They are invisible to a reader but readable in View Source, and this is a public file. Every hit is a comment or an inert self-test string, so nothing behaves differently. This is the ONLY step that edits the engine's output after the fact; fixing those comments at source would remove it. |

## Known limits

- The cover page (`html_report_v2_cover = Y`) is set but does not show on a
  fresh build: `reader.coverAvailable()` requires a saved copy carrying story
  content. Save a copy with pins to see it.
- The NPS tile colours as a percentage of 100, so a realistic NPS of 25 reads
  "Weak". That is engine behaviour, not a config setting.
- Em dashes were removed from the tabs renderer, the shared callout registry
  and the tabs R engine on 2 September 2026, so the report now ships with none
  of any kind (literal, `&mdash;` or `&#8212;`). Nothing in this build needs a
  post-processing pass for them.
- The demo sets `show_save_copy = FALSE`, a setting added the same day. Default
  is TRUE, so every other report keeps its Save copy button.
