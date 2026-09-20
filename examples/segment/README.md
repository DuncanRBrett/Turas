# Thornhill Grocers: the segment worked example

A small, self-contained shopper segmentation whose right answer is known before
the module sees it. Run it to check segment works, or to see what its output
looks like, without needing a client project.

## Running it

In the GUI, which is the point of it:

```r
source("launch_turas.R"); launch_turas()
```

Pick **Segment**, then browse to
`examples/segment/Thornhill_Segment_Config.xlsx`. Outputs land in
`examples/segment/Output/`.

`Thornhill_Segment_Config_Explore.xlsx` is the same study in exploration mode,
k = 2 to 6, if you want to see how it chooses k rather than being told.

Note: segment resolves `output_folder` against the working directory, not
against the config file, unlike keydriver. Both configs therefore say
`examples/segment/Output/`, which is right when you launch from the Turas root
and wrong if you launch from somewhere else.

## What is in it

| File | What |
|---|---|
| `Thornhill_Segment_Data.xlsx` | 1,200 shoppers, sheet `Data` |
| `Thornhill_Segment_Config.xlsx` | final mode, k fixed at 3 |
| `Thornhill_Segment_Config_Explore.xlsx` | exploration mode, k = 2 to 6 |
| `Output/` | a committed run, so you can look without running |

Six attitude statements scored 1 to 10 do the clustering. Five further
variables are along for profiling only: `age_band`, `region` and
`shops_online` as demographics, `household_size` and `monthly_spend` as
profile variables. `region` is a character variable on purpose, because that
is the path that used to be tested with Kruskal-Wallis as though its
categories had an order.

The data file also carries `true_segment`, which the config does not mention
and the module never sees. It is there so the answer can be checked.

## The true answer, by construction

Three segments, unequal by design, with these centres:

| Statement | Price-led | Convenience-led | Quality-led |
|---|---|---|---|
| Price comes first | 8.6 | 4.0 | 3.2 |
| I hunt for promotions | 8.2 | 3.4 | 2.8 |
| Convenience over price | 3.4 | 8.8 | 5.4 |
| I am short of time | 3.0 | 8.4 | 4.6 |
| Fresh quality is worth paying for | 4.2 | 5.6 | 8.9 |
| I stick to brands I trust | 3.6 | 6.4 | 7.8 |
| **Share of sample** | **45%** | **32%** | **23%** |

Each answer is its segment's centre plus noise (sd 1.25), clipped to 1 to 10.
Convenience-led and Quality-led deliberately overlap on brand trust, so the
problem is not trivial.

**A correct run recovers 99.6% of shoppers into their true segment**, at an
average silhouette of 0.510. `test_segment_example.R` asserts the recovery
stays above 95%.

## What you will notice, and why it is not a bug

The segments come back named **Moderate, Moderate 2 and Satisfied**. That is
`auto_name_style = descriptive` doing what it does: it names a segment by its
overall level on the clustering variables, which suits a satisfaction battery
and says nothing useful about shopper attitudes. The other two styles are no
better here (`persona` gives Fence-Sitters, Moderates, Neutrals; `simple`
gives Segment 1, 2, 3).

This example keeps `auto` on purpose, so the report shows what the module
really does rather than a name I typed in.

If you want to name them properly, read the profiles first and then set
`segment_names` in the config. **It is positional**: the names are assigned to
cluster 1, 2, 3 in that order, and the cluster numbering is not stable across
engine changes. Naming them without checking which cluster is which is how a
report ends up confidently mislabelled.

## Rebuilding it

```r
source("examples/segment/create_segment_example.R")
build_segment_example()
```

Deterministic: seed 2026 in the generator, seed 2026 in the config.

To see the mini-batch path, which is chosen automatically above 10,000 rows
and was dead for every such study until September 2026:

```r
source("examples/segment/create_segment_example.R")
write_segment_data(build_segment_data(n = 12000), "examples/segment/Thornhill_Segment_Data.xlsx")
```

Then run the config as usual. The console says which algorithm it used.

## Why this exists

Segment had no example of any kind. That is not a tidiness problem. Mini-batch
k-means passed an argument the function does not take, so every study over
10,000 rows died, in final mode with a raw R error and in exploration mode with
a refusal that named nothing. Latent class analysis was 767 lines that no
production path could reach, while the README told people to switch it on.
Both had passing tests around them. Nothing caught either, because there was
nothing to run.

Keydriver gained its Suiderland example for the same reason, and pricing its
Karoo Coffee one.
