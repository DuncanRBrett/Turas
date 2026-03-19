library(httpuv)
app <- list(
  call = function(req) {
    path <- req$PATH_INFO
    if (path == "/" || path == "") path <- "/demo_results_report.html"
    fpath <- file.path("examples/conjoint/v3_demo/output", sub("^/", "", path))
    if (file.exists(fpath)) {
      ct <- if (grepl("\\.html$", fpath)) "text/html"
            else if (grepl("\\.js$", fpath)) "application/javascript"
            else if (grepl("\\.css$", fpath)) "text/css"
            else "application/octet-stream"
      list(status = 200L, headers = list("Content-Type" = ct), body = readBin(fpath, "raw", file.info(fpath)$size))
    } else {
      list(status = 404L, headers = list("Content-Type" = "text/plain"), body = "Not found")
    }
  }
)
cat("Serving on http://localhost:8765\n")
s <- startServer("0.0.0.0", 8765, app)
while (TRUE) { service(); Sys.sleep(0.1) }
