#!/usr/bin/env Rscript
# ==============================================================================
# WHAT IF - REGENERATE THE TABS TEST FIXTURE
# ==============================================================================
#
# Writes modules/tabs/tests/fixtures/whatif/synthetic_whatif_island.json: a
# What if contribution file from the synthetic test project (no client data),
# used by the tabs R tests and the node gate for the What if tab. Rerun after
# changing the contribution file's shape.
#
# Usage, from the Turas root:
#   Rscript modules/whatif/dev/make_tabs_fixture.R
# ==============================================================================

source(file.path("modules", "whatif", "source_whatif.R"))
source(file.path("modules", "whatif", "lib", "generate_config_template.R"))
source(file.path("modules", "shared", "template_styles.R"))
for (f in list.files(file.path("modules", "whatif", "tests", "fixtures", "synthetic_data"),
                     pattern = "\\.R$", full.names = TRUE)) source(f)
dir <- tempfile("whatif_fixture_")
dir.create(dir)
p <- whatif_write_test_project(dir, n = 160, seed = 21, config = list(n_boot = 10))
res <- run_whatif(p$config, verbose = FALSE)
if (is_refusal(res) || is_error(res)) quit(status = 1)
out <- file.path("modules", "tabs", "tests", "fixtures", "whatif", "synthetic_whatif_island.json")
file.copy(res$files$island, out, overwrite = TRUE)
cat("wrote", out, round(file.size(out) / 1024), "kb;", length(res$payload$variants[[1]]$safe$groups), "groups;", paste(names(res$payload$variants), collapse = " and "), "\n")
