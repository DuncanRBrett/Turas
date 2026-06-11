/**
 * In-browser self-test — open the report with #selftest appended to the URL
 * and a pass/fail panel renders at the top. Mirrors the node known-answer
 * suite so the report can be verified without any tooling installed.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var selftest = TR.selftest = {};

  function assertEqual(actual, expected, label) {
    var a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a !== e) throw new Error(label + ": expected " + e + ", got " + a);
  }

  /** Shared known-answer cases (also run by tests/run_tests.mjs via node). */
  selftest.cases = function () {
    return [
      { name: "fmt.num percent rounding", fn: function () {
        assertEqual(TR.fmt.num(42.4, "pct"), "42%", "42.4 pct");
        assertEqual(TR.fmt.num(42.5, "pct"), "43%", "42.5 pct");
        assertEqual(TR.fmt.num(3.84, "dec1"), "3.8", "3.84 dec1");
        assertEqual(TR.fmt.num(5, "nps"), "+5", "nps positive");
        assertEqual(TR.fmt.num(-9, "nps"), "-9", "nps negative");
        assertEqual(TR.fmt.num(null, "pct"), "–", "null");
      } },
      { name: "fmt.base thousands", fn: function () {
        assertEqual(TR.fmt.base(12345), "12\u202F345", "12345");
        assertEqual(TR.fmt.base(500), "500", "500");
      } },
      { name: "escaping", fn: function () {
        assertEqual(TR.fmt.escapeHtml('<b a="1">'), "&lt;b a=&quot;1&quot;&gt;", "html");
        assertEqual(TR.fmt.escapeXml("a&'b"), "a&amp;&apos;b", "xml");
      } },
      { name: "svg.niceMax steps", fn: function () {
        assertEqual(TR.svg.niceMax(47), 50, "47");
        assertEqual(TR.svg.niceMax(82), 100, "82");
        assertEqual(TR.svg.niceMax(130), 150, "130");
        assertEqual(TR.svg.niceMax(0), 10, "0");
      } },
      { name: "svg.shade colour mix", fn: function () {
        assertEqual(TR.svg.shade("#000000", 0.5), "#808080", "black 0.5");
        assertEqual(TR.svg.shade("#323367", 1), "#323367", "full strength");
      } },
      { name: "crc32 known answers", fn: function () {
        assertEqual(TR.zip.crc32(TR.zip.bytes("123456789")), 0xCBF43926, "123456789");
        assertEqual(TR.zip.crc32(TR.zip.bytes("")), 0, "empty");
      } },
      { name: "zip structure", fn: function () {
        var bytes = TR.zip.build([{ name: "a.txt", data: "hello" },
          { name: "b/c.xml", data: "<x/>" }]);
        assertEqual([bytes[0], bytes[1], bytes[2], bytes[3]],
          [0x50, 0x4B, 0x03, 0x04], "local header signature");
        var eocd = bytes.length - 22;
        assertEqual([bytes[eocd], bytes[eocd + 1], bytes[eocd + 2], bytes[eocd + 3]],
          [0x50, 0x4B, 0x05, 0x06], "EOCD signature");
        assertEqual(bytes[eocd + 10] + (bytes[eocd + 11] << 8), 2, "entry count");
      } },
      { name: "validate accumulates errors", fn: function () {
        var bad = { project: {}, banner: { columns: ["Total", "A"] },
          questions: [{ id: "x", title: "t", type: "wrong",
            rows: [{ label: "r", values: [1] }] }] };
        var res = TR.data.validate(bad);
        assertEqual(res.ok, false, "ok flag");
        var codes = res.errors.map(function (e) { return e.code; });
        assertEqual(codes.indexOf("DATA_NO_PROJECT") >= 0, true, "project error");
        assertEqual(codes.indexOf("DATA_Q_BAD_TYPE") >= 0, true, "type error");
        assertEqual(codes.indexOf("DATA_ROW_LEN") >= 0, true, "row length error");
      } },
      { name: "bar geometry known answer", fn: function () {
        var payload = { project: { name: "t", brand_colour: "#323367" },
          banner: { columns: ["Total"] },
          questions: [] };
        var q = { id: "k", title: "k", type: "single",
          rows: [{ label: "Row", values: [25] }] };
        var svgString = TR.charts.hBars(q, payload, 0);
        // plot width = 660-170-64 = 426; axis max 25 -> 25; bar = full 426
        assertEqual(svgString.indexOf('width="426"') >= 0, true, "bar width 426");
      } },
      { name: "composer.compose model", fn: function () {
        var payload = { project: { name: "t" },
          banner: { columns: ["Total", "A"] },
          questions: [
            { id: "a", code: "A1", title: "A", type: "single", bases: [10, 5],
              rows: [{ label: "x", values: [40, 20] }] },
            { id: "b", code: "B1", title: "B", type: "single", bases: [10, 5],
              rows: [{ label: "y", values: [60, 30] }] }
          ] };
        var res = TR.composer.compose(payload, ["a", "b"], 0);
        assertEqual(res.ok, true, "ok");
        assertEqual(res.model.items.length, 2, "items");
        assertEqual(res.model.sharedMax, 60, "shared max");
        assertEqual(res.model.trends.length, 0, "no trends");
        var tooFew = TR.composer.compose(payload, ["a"], 0);
        assertEqual(tooFew.ok, false, "min enforced");
      } },
      { name: "pptx package parts", fn: function () {
        var payload = { project: { name: "t", brand_colour: "#323367" },
          banner: { columns: ["Total"] }, questions: [] };
        var bytes = TR.pptx.package([TR.pptxSlides.titleSlide(payload, 1)], payload);
        assertEqual(bytes.length > 2000, true, "non-trivial size");
        assertEqual([bytes[0], bytes[1]], [0x50, 0x4B], "zip magic");
      } },
      { name: "renderer survives broken question (browser)", fn: function () {
        if (typeof document === "undefined") return;
        var payload = TR.state.payload;
        var broken = { id: "__broken__", code: "X", title: "Broken", type: "single",
          rows: null, stats: [{ label: "Mean", values: payload.banner.columns.map(
            function () { return 1; }) }] };
        var article = document.createElement("article");
        article.setAttribute("data-q", "__broken__");
        article.setAttribute("data-col", "0");
        article.innerHTML = '<div class="cardbody pending"></div>';
        var patched = { project: payload.project, banner: payload.banner,
          questions: [broken] };
        TR.cards.fill(article, patched);
        var table = article.querySelector('[data-slot="table"]');
        assertEqual(!!table && table.innerHTML.indexOf("Mean") >= 0, true,
          "table renders despite missing rows");
      } }
    ];
  };

  /** Run all cases; render a panel in the browser, return results. */
  selftest.run = function () {
    var results = selftest.cases().map(function (testCase) {
      try {
        testCase.fn();
        return { name: testCase.name, ok: true, error: null };
      } catch (e) {
        return { name: testCase.name, ok: false, error: e.message };
      }
    });
    if (typeof document !== "undefined") {
      var failed = results.filter(function (r) { return !r.ok; }).length;
      var panel = document.createElement("section");
      panel.className = "card selftest" + (failed ? " selftest-fail" : "");
      panel.innerHTML = "<h2>Self-test: " + (results.length - failed) + "/" +
        results.length + " passed</h2><ul>" + results.map(function (r) {
          return "<li>" + (r.ok ? "✓" : "✗") + " " + TR.fmt.escapeHtml(r.name) +
            (r.error ? " — <code>" + TR.fmt.escapeHtml(r.error) + "</code>" : "") +
            "</li>";
        }).join("") + "</ul>";
      var main = document.getElementById("main");
      if (main) main.prepend(panel);
    }
    return results;
  };

})(typeof window !== "undefined" ? window : globalThis);
