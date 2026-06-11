/**
 * v2 in-browser self-test — append #selftest to the URL. Mirrors the node
 * suite's core known answers, including live golden spot-checks of the
 * stats engine against the published tables embedded in this very file.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var selftest2 = TR.selftest2 = {};

  function eq(actual, expected, label) {
    var a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a !== e) throw new Error(label + ": expected " + e + ", got " + a);
  }

  selftest2.cases = function () {
    return [
      { name: "z-test known answer (production formula)", fn: function () {
        // 60/200 vs 40/200: pooled p=.25, se=.0433, z=2.31 -> significant
        eq(TR.stats.propHigher(60, 200, 40, 200), true, "sig pair");
        // 50/200 vs 45/200: z≈0.58 -> not significant
        eq(TR.stats.propHigher(50, 200, 45, 200), false, "non-sig pair");
        // np<5 precondition: 3/100 vs 0/100 suppressed
        eq(TR.stats.propHigher(3, 100, 0, 100), false, "np precondition");
      } },
      { name: "filter mask + recompute (golden vs published)", fn: function () {
        var campus = TR.AGG.banner_groups[0].id;
        var q = TR.AGG.questions[3];
        var pub = TR.model._publishedModel(q, campus);
        var comp = TR.model._computedModel(q, campus, []);
        for (var i = 0; i < pub.columns.length; i++) {
          eq(comp.columns[i].base, pub.columns[i].base || 0, q.code + " base " + i);
        }
        var ri = q.rows.findIndex(function (r) { return r.kind === "category"; });
        eq(comp.rows[ri].cells[1].n, pub.rows[ri].cells[1].n, q.code + " first cell count");
      } },
      { name: "filtered base shrinks and stays consistent", fn: function () {
        var q0 = TR.AGG.questions[0];
        var firstCat = TR.d2.catRows(q0)[0];
        var filters = [{ q: q0.code, rows: [firstCat.index] }];
        var mask = TR.stats.mask(filters);
        var n = TR.stats.maskCount(mask);
        eq(n > 0 && n < TR.MICRO.n, true, "filter is a strict subset");
        var comp = TR.model._computedModel(TR.AGG.questions[3],
          TR.AGG.banner_groups[0].id, filters);
        eq(comp.columns[0].base <= n, true, "filtered base bounded by mask");
      } },
      { name: "custom banner columns from any question", fn: function () {
        var q = TR.AGG.questions[2]; // intensity (2 categories)
        var spec = TR.stats.columnsFor("custom:" + q.code);
        eq(spec.columns.length, TR.d2.catRows(q).length + 1, "Total + categories");
        eq(spec.custom, true, "flagged custom");
      } },
      { name: "hash state round-trip", fn: function () {
        var s = TR.d2.state;
        var keep = JSON.stringify({ t: s.tab, q: s.activeQ, b: s.banner, f: s.filters });
        s.tab = "crosstabs"; s.activeQ = "Q008"; s.banner = "Q005";
        s.filters = [{ q: "Q002", rows: [0, 2] }];
        var hash = TR.d2.encodeHash();
        s.filters = []; s.activeQ = "X";
        TR.d2.decodeHash(hash);
        eq(s.activeQ, "Q008", "q restored");
        eq(s.filters[0].rows, [0, 2], "filter rows restored");
        var prev = JSON.parse(keep);
        s.tab = prev.t; s.activeQ = prev.q; s.banner = prev.b; s.filters = prev.f;
      } },
      { name: "wave matching present", fn: function () {
        var matched = 0;
        TR.AGG.questions.forEach(function (q) {
          var m = TR.model.forQuestion(q.code, TR.AGG.banner_groups[0].id, []);
          if (m.prevWave) matched++;
        });
        eq(matched >= 60, true, "at least 60 questions tracked vs 2024, got " + matched);
      } },
      { name: "pptx deck builds from a story model", fn: function () {
        var model = TR.model.forQuestion(TR.AGG.questions[0].code,
          TR.AGG.banner_groups[0].id, []);
        var slides = [TR.exporter.titleSlide(1),
          TR.exporter.slideForModel(model, "Test note")];
        var bytes = TR.pptx.package(slides, { project: TR.AGG.project });
        eq(bytes[0] === 0x50 && bytes[1] === 0x4B, true, "zip magic");
        eq(bytes.length > 4000, true, "non-trivial deck");
      } },
      { name: "renderer survives a broken model", fn: function () {
        var html = TR.render.tableHtml({ code: "X", title: "broken",
          columns: [{ label: "Total", letter: "", base: 0, low: true }],
          rows: [{ kind: "category", label: "r", cells: [{ pct: null, n: null, sig: "" }] }],
          lowBaseThreshold: 30 }, { heatmap: true });
        eq(html.indexOf("<table") === 0, true, "table renders");
      } }
    ];
  };

  selftest2.run = function () {
    var results = selftest2.cases().map(function (testCase) {
      try {
        testCase.fn();
        return { name: testCase.name, ok: true };
      } catch (e) {
        return { name: testCase.name, ok: false, error: e.message };
      }
    });
    var failed = results.filter(function (r) { return !r.ok; }).length;
    if (typeof document !== "undefined") {
      var panel = document.createElement("div");
      panel.className = "card selftest" + (failed ? " selftest-fail" : "");
      panel.innerHTML = "<h2>Self-test: " + (results.length - failed) + "/" +
        results.length + " passed</h2><ul>" + results.map(function (r) {
          return "<li>" + (r.ok ? "✓" : "✗") + " " + TR.fmt.escapeHtml(r.name) +
            (r.error ? " — <code>" + TR.fmt.escapeHtml(r.error) + "</code>" : "") + "</li>";
        }).join("") + "</ul>";
      var host = document.getElementById("tabhost");
      if (host) host.prepend(panel);
    }
    return results;
  };

})(typeof window !== "undefined" ? window : globalThis);
