# BR_DBA_test fixtures

Build script that produces two parallel test fixtures from the canonical
IPK synthetic config, used to browser-verify the
`feature/branded-reach-and-dba` branch.

## Why this exists

The brand module's `examples/3cat/` and `examples/9cat/` are stale after
the IPK rebuild and will not run. The canonical IPK config in OneDrive
(`OneDrive/.../IPK/Tabs/synthetic/8822527_*.xlsx`) is the single working
example, but it must not be modified — it is in active use on the live
IPK project.

This script copies the canonical files into two sister folders and
mutates the copies:

- `BR_DBA_test/placeholder/` — element flags Y, MR + DBA sheets stripped
  to headers only. Used to verify the "Data not yet collected"
  placeholder cards render cleanly.
- `BR_DBA_test/populated/` — element flags Y, MR + DBA sheets populated
  with synthetic asset definitions, synthetic data extended with
  required Reach + DBA response columns. Used to verify the modern
  panels render with real data.

## Usage

```bash
# Build both fixtures
Rscript modules/brand/tests/fixtures/br_dba_test/build_fixtures.R

# Build only one
Rscript modules/brand/tests/fixtures/br_dba_test/build_fixtures.R placeholder
Rscript modules/brand/tests/fixtures/br_dba_test/build_fixtures.R populated
```

The script reads but never writes the canonical `8822527_*.xlsx` files.
After running, verify the canonical file hashes match those recorded in
`~/.turas-baselines/IPK_pre_BR_DBA_branch/BASELINE.md`.

## What the populated fixture includes

- 3 Marketing Reach ads (one DSS-only TV, one ALL-category OOH, one
  POS-only digital), all attributed to IPK.
- 4 DBAs (LOGO, COLOUR, TAGLINE, CHARACTER) — same set defined in the
  canonical Brand_Config, mapped to question codes in the Structure.
- Synthetic data extended with 9 reach columns (`reach.seen.*`,
  `reach.brand.*`, `reach.media.*`) and 8 DBA columns
  (`DBA_FAME_*`, `DBA_UNIQUE_*`).
- Asset-quadrant distribution designed so each Romaniuk quadrant is
  represented:
  - LOGO, COLOUR → Use or Lose (high fame + high uniqueness)
  - TAGLINE → Invest to Build (low fame + high uniqueness)
  - CHARACTER → Avoid Alone (high fame + low uniqueness)

## Re-running

The script is deterministic (`set.seed(42)`) so re-running produces
identical synthetic responses. If the canonical files are updated in
OneDrive, re-run the script to refresh the fixtures.
