# Report Hub test setup -- shared module sourcing
library(testthat)

hub_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = FALSE)
if (!file.exists(file.path(hub_root, "00_guard.R"))) {
  hub_root <- normalizePath("modules/report_hub", mustWork = FALSE)
}
if (!file.exists(file.path(hub_root, "00_guard.R"))) {
  stop("Cannot find report_hub module root. Run tests from the Turas project root.")
}

source(file.path(hub_root, "00_guard.R"))
source(file.path(hub_root, "01_html_parser.R"))
# 02_namespace_rewriter.R is no longer used (iframe approach)
source(file.path(hub_root, "03_front_page_builder.R"))
source(file.path(hub_root, "04_navigation_builder.R"))
source(file.path(hub_root, "07_page_assembler.R"))
source(file.path(hub_root, "08_html_writer.R"))

if (!requireNamespace("htmltools", quietly = TRUE)) {
  skip("htmltools not available")
}
