Short answer: yes---**you can (and should) defer SPSS-specific
compatibility** without hurting your roadmap. Keep only a few
"no-regret" abstractions so you can add SPSS parity later *if ever
needed*. Everything else is optional overhead.

**What to defer (saves effort now)**

-   **SPSS file I/O**: .sav/.zsav export with full variable/value
    labels, user-missing, formats.

-   **SPSS "Custom Tables" parity** (exact stub/total placement, hidden
    categories, table notes, etc.).

-   **SPSS syntax/weight imports** (reading .sps or mirroring SPSS
    weight specs).

-   **SPSS Complex Samples parity** (matching IBM's exact variance
    estimators & UI behavior).

-   **SPSS rounding/format quirks** (banker's rounding, p-value display
    rules, legacy missing codes like 99/999).

These are the parts that consume disproportionate time for little gain
if you're not actively using SPSS.

**What to keep (tiny cost now; future-proofs you)**

-   **A
    generic stat_profile switch** (turas_standard, displayr_like, spss_like)
    that only toggles *your* engine's options (tests,
    multiple-comparison correction, flag style).

    -   No SPSS code required---just a profile name mapped to your
        existing options.

-   **A stable long-format export schema** (CSV/JSON) for
    tables/metrics.

    -   If someone ever needs SPSS, a small adapter can convert your
        long data to .sav later.

-   **Optional "design-aware mode"** behind a config flag (using
    R's survey later).

    -   Leave the flag and the interface; implement later if/when
        needed.

-   **Multiple-response set abstraction** (MR sets) in your core.

    -   SPSS users expect it, but it benefits your own workflow
        regardless.

**Impact on the codebase**

-   You **do not** need SPSS libraries or emulation now.

-   Keep your **shared core** (turas.core) API generic (tests, weights,
    nets, banners).

-   If SPSS ever becomes relevant: write a **thin adapter** that (a)
    exports to .sav and/or (b) maps your tables to an SPSS-like layout.
    This stays outside the core.

**Practical decision table**

  -------------------------------------------------------------------------
  **Area**                      **Build now**              **Defer**
  ----------------------------- -------------------------- ----------------
  Profiles (stat_profile)       ✅ (low effort)            

  Long-format CSV/JSON          ✅                         

  Design-aware variance         ◻ behind flag, implement   ✅
                                later                      implementation

  .sav/.zsav export                                        ✅

  SPSS Custom Tables parity                                ✅

  SPSS syntax ingestion                                    ✅

  Exact SPSS rounding/labels                               ✅
  quirks                                                   
  -------------------------------------------------------------------------

**Minimal spec tweak (to keep doors open)**

In tracking_config.xlsx / tabs_config.xlsx:

-   stat_profile: turas_standard \| displayr_like \| spss_like

-   design_aware: FALSE *(keep the key; implement later)*

In dev docs:

-   Note: "SPSS compatibility is *out of scope* for Phase 1. Future
    support, if requested, will be delivered via adapters without
    modifying turas.core."

**Bottom line**

You'll **avoid meaningful overhead** by deferring SPSS specifics. Keep
just two light hooks---stat_profile and a dormant design_aware flag.
Everything else can be added later as a **bolt-on adapter** without
touching your core or slowing the Tracking/Tabs work now.
