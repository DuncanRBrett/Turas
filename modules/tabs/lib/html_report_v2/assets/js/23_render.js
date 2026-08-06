/**
 * v2 renderers — crosstab table HTML (heatmap, counts, low-base, deltas),
 * export matrix/TSV/clipboard flavours, and the per-question bar chart.
 * All pure string builders over the view model from 22_model.js.
 *
 * SIZE-EXCEPTION: one cohesive rendering surface over the model contract;
 * the table builder dominates and decomposing it would obscure the layout.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt, S = TR.svg;

  var render = TR.render = {};

  /* ---- disclosure control: a withheld column's base ----
   * applyDisclosureSuppression (22_model.js) blanks a sub-k column's cells and
   * strips the letters pointing at it, but the base row is a disclosure in its
   * own right: "4" names the headcount of an identifiable subgroup. The
   * workbook for the same run withholds it as "n<10" (excel_writer.R
   * write_base_rows -> disclosure_marker), so the two deliverables of one run
   * would otherwise enforce different standards.
   *
   * Returns the marker for a suppressed column and null for every other, so an
   * unprotected report (k <= 1 — nothing is ever flagged) renders byte-identically.
   * TR.disclosure is guarded: the flag only ever arrives from a model built with
   * it loaded, and "n<k" mirrors disclosure_marker()'s own unknown-k branch. */
  var WITHHELD_TITLE = "Withheld: this column's base is below the confidentiality " +
    "threshold, so its exact size is not disclosed";
  render.baseMarker = function (col) {
    if (!col || !col.suppressed) return null;
    var k = (TR.disclosure && TR.disclosure.minBase) ? TR.disclosure.minBase() : null;
    return (k && k > 1) ? "n<" + k : "n<k";
  };

  /* brand helpers shared with the v1 pptx packager */
  TR.charts = TR.charts || {};
  TR.charts.brandOf = function () {
    return (TR.AGG && TR.AGG.project.brand_colour) || TR.DEFAULT_BRAND;
  };
  TR.charts.accentOf = function () {
    return (TR.AGG && TR.AGG.project.accent_colour) || TR.DEFAULT_ACCENT;
  };
  TR.charts.clip = function (label, max) {
    var s = String(label == null ? "" : label);
    return s.length > max ? s.slice(0, max - 1) + "…" : s;
  };

  /* ---- chart colour scheme (mirrors the classic report's palette) ----
   * The data layer carries project.chart_palette (the resolved preset, 7
   * colours) so v2 colours categories semantically — negative = red,
   * positive = green — instead of a flat brand ramp. Absent (older islands /
   * the SACAP prototype) -> null, and callers fall back to brand shades, so
   * nothing changes for those reports. */
  TR.charts.chartPalette = function () {
    return (TR.AGG && TR.AGG.project && TR.AGG.project.chart_palette) || null;
  };

  // Category label (lower-cased) -> palette key. Ported verbatim from the
  // classic get_semantic_colour() sentiment map.
  var SEMANTIC_KEY = {
    "negative": "negative", "terrible or not good": "negative", "poor (1-3)": "negative",
    "poor": "negative", "below average or poor": "negative", "dissatisfied (1-5)": "negative",
    "detractor (0-6)": "negative", "detractor": "negative", "do not trust": "negative",
    "would switch": "negative", "strongly disagree": "negative", "very dissatisfied": "negative",
    "below average": "mod_negative", "dissatisfied": "mod_negative", "disagree": "mod_negative",
    "neutral": "neutral", "average": "neutral", "average (4-6)": "neutral", "undecided": "neutral",
    "passive (7-8)": "neutral", "passive": "neutral", "some trust": "neutral",
    "neither agree nor disagree": "neutral", "average satisfaction": "neutral",
    "average satisfaction (6-8)": "neutral",
    "satisfied": "mod_positive", "above average": "mod_positive", "agree": "mod_positive",
    "good": "mod_positive",
    "positive": "positive", "good or excellent": "positive", "good or excellent (7-10)": "positive",
    "excellent": "positive", "very satisfied (9-10)": "positive", "very satisfied": "positive",
    "promoter (9-10)": "positive", "promoter": "positive", "fully trust": "positive",
    "would not switch": "positive", "strongly agree": "positive",
    "dk": "dk_na", "na": "dk_na", "dk/na": "dk_na", "dk / na": "dk_na", "don't know": "dk_na",
    "not applicable": "dk_na", "n/a": "dk_na", "refused": "dk_na", "prefer not to say": "dk_na",
    "other": "other"
  };

  function hexRGB(hex) {
    var c = String(hex || "#000000").replace("#", "");
    if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
    return [parseInt(c.substr(0, 2), 16), parseInt(c.substr(2, 2), 16), parseInt(c.substr(4, 2), 16)];
  }
  function rgbHex(r, g, b) {
    var h = function (v) { return ("0" + Math.round(v).toString(16)).slice(-2); };
    return "#" + h(r) + h(g) + h(b);
  }

  /** Semantic colour for a category label, or null when no palette is
   *  configured (caller falls back to a brand shade). Exact sentiment match
   *  first, then a negative->positive gradient by ordinal position. Mirrors the
   *  classic get_semantic_colour(). */
  TR.charts.semanticColour = function (label, index, nTotal) {
    var pal = TR.charts.chartPalette();
    if (!pal) return null;
    var key = SEMANTIC_KEY[String(label == null ? "" : label).toLowerCase().trim()];
    if (key && pal[key]) return pal[key];
    if (!(nTotal > 1)) return pal.neutral;
    var frac = index / (nTotal - 1);                 // 0 = most negative, 1 = most positive
    var anchors = [pal.negative, pal.mod_negative, pal.neutral, pal.mod_positive, pal.positive]
      .map(hexRGB);
    var stops = [0, 0.25, 0.5, 0.75, 1];
    var seg = 0;
    for (var s = 0; s < stops.length; s++) { if (frac >= stops[s]) seg = s; }
    if (seg >= stops.length - 1) seg = stops.length - 2;
    var t = Math.max(0, Math.min(1, (frac - stops[seg]) / (stops[seg + 1] - stops[seg])));
    var a = anchors[seg], b = anchors[seg + 1];
    return rgbHex(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t);
  };

  /** Per-category colour array: the semantic palette when configured, else the
   *  brand-shade ramp the charts have always used. */
  render.categoryColours = function (rows) {
    var brand = TR.charts.brandOf(), n = rows.length;
    return rows.map(function (r, i) {
      return TR.charts.semanticColour(r.label, i, n) ||
        S.shade(brand, 0.16 + 0.84 * (i / Math.max(n - 1, 1)));
    });
  };

  // Config-precision formatters (review 2026-08, I13): the crosstab tab and its
  // export matrix hard-coded whole-% / 1dp means, ignoring DECIMAL PLACES — an
  // NPS published as 79 displayed "79.0", and percent_decimals=1 workbooks
  // (46.3%) displayed "46%". Means resolve per model: an NPS/0-100 metric takes
  // percent precision (fmt.decimalsForQ), everything else ratings precision.
  // The percentage side of that now lives in fmtValue, below.
  function fmtMean(v, model) {
    if (v === null || v === undefined) return "–";
    return Number(v).toFixed(fmt.decimalsForQ(model || null, true));
  }
  // Review 2026-08 (C1): a config with show_percent_column = N puts ROW
  // percentages or raw FREQUENCIES in the same value slot, and every one of them
  // used to be printed with a "%" — a counts-only workbook shipped "142%",
  // "80% B". The statistic travels on the model; the vocabulary is TR.fmt's.
  var statOf = fmt.statOf, isPct = fmt.isPctStat, fmtValue = fmt.value;
  render.statOf = statOf;
  render.fmtValue = fmtValue;
  /** Plain-English name of a non-default statistic, for the table's corner cell
   *  and the export note; "" for the ordinary column percentage. */
  render.statNote = function (model) {
    // A filtered / custom-banner recompute always produces COLUMN percentages.
    // When the published question reported something else, say so — otherwise
    // the numbers silently change unit as the reader applies a filter (C1).
    if (model && model.statWas) {
      return "Column % — recomputed (published as " +
        fmt.statName(model.statWas) + ")";
    }
    var stat = statOf(model, null);
    return stat === fmt.COL_PCT ? "" : fmt.statName(stat);
  };

  /** Heatmap tint: brand colour with alpha scaled by value. */
  function heat(value, max) {
    if (value === null || value === undefined || !(max > 0)) return "";
    // Tint scales with the ABSOLUTE value (max is 100 for % cells), so 73%
    // reads clearly darker than 3%. (Per-row normalisation made every cell in a
    // single-column table its own row max -> identical shade.) The spread does
    // the differentiating, so a moderate 0.45 ceiling keeps the darkened n=
    // count legible on the heaviest cells.
    var alpha = Math.max(0, Math.min(value / max, 1)) * 0.45;
    var brand = TR.charts.brandOf().replace("#", "");
    var r = parseInt(brand.substr(0, 2), 16), g = parseInt(brand.substr(2, 2), 16),
        b = parseInt(brand.substr(4, 2), 16);
    return "background:rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ");";
  }

  /** B2: reader toggle for plain-language significance (off in bare sandboxes). */
  function explainOn() {
    return !!(TR.reader && TR.reader.explainOn && TR.reader.explainOn());
  }
  /** Focusable-tooltip attributes for a plain-language sentence ("" when none).
   *  aria-label carries the sentence for keyboard/AT focus; the visual tooltip
   *  is the CSS .xpl::after (pointer-events none, so clicks pass through). */
  function explainAttrs(sentence) {
    if (!sentence) return "";
    var esc = fmt.escapeHtml(sentence);
    return ' xpl" tabindex="0" data-explain="' + esc + '" aria-label="' + esc;
  }

  /** @param {boolean} [pctLike=true] - false when the row holds counts, so the
   *  prior-wave tooltip does not append a "%" to a headcount (C1). */
  function deltaChip(delta, pctLike) {
    if (pctLike === undefined) pctLike = true;
    if (!delta || delta.diff === null) return "";
    var up = delta.diff >= 0;
    var size = delta.isMean ? Math.abs(delta.diff).toFixed(1)
      : Math.abs(delta.diff).toFixed(0);
    if (!delta.isMean && Math.abs(delta.diff) < 1) return "";
    var sentence = explainOn() ? TR.reader.deltaSentence(delta) : "";
    return '<span class="delta ' + (up ? "up" : "down") +
      (delta.sig ? " sig" : "") +
      (sentence ? explainAttrs(sentence) : '" title="' +
        (delta.year || "prior wave") + ": " +
        (delta.isMean ? delta.prev.toFixed(1)
          : Math.round(delta.prev) + (pctLike ? "%" : "")) +
        (delta.sig ? " · significant change" : "")) + '">' +
      (up ? "▲" : "▼") + size + "</span>";
  }
  render.deltaChip = deltaChip;

  /** Crosstab table from a view model. */
  render.tableHtml = function (model, opts) {
    opts = opts || {};
    var sort = model.sorted || null;
    // The corner cell names the quantity whenever it is NOT the column
    // percentage, so a counts-only or row-%-only table says so on its face.
    var unit = render.statNote(model);
    var out = ['<table class="ct"><thead><tr><th class="lab">Response' +
      (unit ? '<div class="cunit">' + fmt.escapeHtml(unit) + "</div>" : "") +
      "</th>"];
    model.columns.forEach(function (col, i) {
      var arrow = sort && sort.col === i
        ? (sort.dir === "desc" ? " ↓" : " ↑") : "";
      out.push('<th class="' + (i === 0 ? "total" : "") +
        (opts.sortable ? " sortable" : "") + '"' +
        (opts.sortable ? ' data-sortcol="' + i + '" title="Click to sort rows by ' +
          fmt.escapeHtml(col.label) + ' (descending / ascending / original)"' : "") + ">" +
        (i > 0 && opts.hideable
          ? '<button class="colx" data-hidecol="' + fmt.escapeHtml(col.label) +
            '" title="Hide this column (table, chart and exports)" ' +
            'aria-label="Hide column ' + fmt.escapeHtml(col.label) + '">✕</button>'
          : "") +
        '<div class="cth">' + fmt.escapeHtml(col.label) + arrow + "</div>" +
        (col.letter ? '<div class="clt">(' + col.letter + ")</div>" : "") +
        "</th>");
    });
    out.push("</tr></thead><tbody>");
    var ivLabels = opts.intervals ? TR.conf.labels() : null;
    var baseCell = function (col, value) {
      var mark = render.baseMarker(col);
      return mark
        ? '<span class="supb" title="' + fmt.escapeHtml(WITHHELD_TITLE) + '">' +
          fmt.escapeHtml(mark) + "</span>"
        : value;
    };
    // Weighted designs: the primary row is the unweighted sample size (it anchors
    // the low-base flag); the weighted + Kish effective bases follow beneath, so
    // the reader can see the report IS weighted and read the design effect. The
    // rows mirror the Excel workbook. Unweighted reports keep the single "Base
    // (n=)" row unchanged.
    var wproj = (TR.AGG && TR.AGG.project) || {};
    var wtd = !!wproj.weighted;
    out.push('<tr class="rb"><td class="lab">' +
      (wtd ? "Base (unweighted)" : "Base (n=)") + "</td>");
    model.columns.forEach(function (col) {
      // A withheld column prints the marker alone: its worst-case margin
      // (98/√n) and its coverage note ("2% of 200") each invert to the exact
      // base, so masking the number and keeping its derivations would disclose
      // it anyway. Nothing below runs for a suppressed column, which is why an
      // unprotected report is untouched.
      if (col.suppressed) {
        out.push("<td>" + baseCell(col, "") + "</td>");
        return;
      }
      // Worst-case margin is sized on the finite-population-corrected effective
      // base when a universe is known (Infinity -> ±0.0pp for a full census).
      var moeBase = col.ciBase != null ? col.ciBase : col.base;
      var moe = opts.intervals && col.base ? TR.conf.maxMoePct(moeBase) : null;
      // The FPC only frames a column when it MATERIALLY applies (known universe +
      // coverage above the floor); a thin sample reads as a plain low base.
      var colFpc = col.population != null && TR.conf.fpcApplies(col.base, col.population);
      var lowTitle = colFpc
        ? "Even after the finite population correction the effective base is below "
          + model.lowBaseThreshold + " — interpret with caution"
        : "Base below " + model.lowBaseThreshold + " — interpret with caution";
      out.push("<td>" + (col.low
        ? '<span class="lowb" title="' + lowTitle + '">' +
          fmt.base(col.base) + " ⚠</span>"
        : fmt.base(col.base)) +
        // Coverage of a known universe: a small base that is most of its group
        // is a near-complete count, not a fragile sample. That framing is only
        // true on a DECLARED census — on a sample the base cell stays a plain n
        // (the tiny FPC still applies to the intervals, silently). "5% of
        // 14 563" under every base on a stratified sample reads as noise.
        (colFpc && col.coverage != null &&
         TR.conf.labels().sampling_method_normalised === "census"
          ? '<div class="civ" title="' + fmt.escapeHtml(fmt.base(col.base) +
            " of " + fmt.base(col.population) + " in this group responded — its " +
            "numbers carry a finite population correction") + '">' +
            Math.round(col.coverage * 100) + "% of " + fmt.base(col.population) +
            "</div>"
          : "") +
        (moe !== null
          ? '<div class="civ" title="Worst-case 95% ' +
            ivLabels.precision_term + " at this base (" +
            ivLabels.moe_abbrev + ')">±' + moe.toFixed(1) + "pp</div>"
          : "") + "</td>");
    });
    out.push("</tr>");

    // Weighted base + Kish effective base rows (weighted reports only; the
    // per-column values come from the data layer / recompute, rounded like the
    // workbook). The unweighted row above always shows (it anchors the low-base
    // flag and is the disclosure requirement); the weighted base — least useful
    // interpretively, and identical to unweighted on the Total — can be dropped
    // for simpler client tables via show_weighted_base. Effective base is gated
    // by show_effective_n. Both default on (undefined -> shown) so a report
    // generated before these flags existed is unchanged.
    if (wtd) {
      if (wproj.show_weighted_base !== false) {
        out.push('<tr class="rb"><td class="lab">Base (weighted)</td>');
        model.columns.forEach(function (col) {
          out.push("<td>" + baseCell(col,
            col.baseW != null ? fmt.base(col.baseW) : "–") + "</td>");
        });
        out.push("</tr>");
      }
      if (wproj.show_effective_n !== false) {
        out.push('<tr class="rb"><td class="lab" title="Kish effective sample ' +
          'size — significance and confidence intervals are sized on this, not ' +
          'the raw count">Effective base</td>');
        model.columns.forEach(function (col) {
          out.push("<td>" + baseCell(col,
            col.baseEff != null ? fmt.base(col.baseEff) : "–") + "</td>");
        });
        out.push("</tr>");
      }
    }

    model.rows.forEach(function (row, ri) {
      var cls = row.kind === "net" ? "rn" : row.kind === "mean" ? "rm" : "rc";
      out.push('<tr class="' + cls + '"><td class="lab">' +
        (opts.rowHideable
          ? '<button class="rowx" data-hiderow="' + fmt.escapeHtml(row.label) +
            '" title="Hide this row (table, chart and exports)" ' +
            'aria-label="Hide row ' + fmt.escapeHtml(row.label) + '">✕</button>'
          : "") +
        fmt.escapeHtml(row.label) +
        (row.indexDesc ? '<div class="idxd">' + fmt.escapeHtml(row.indexDesc) + "</div>" : "") +
        "</td>");
      var rowStat = statOf(model, row);
      var rowIsPct = isPct(rowStat);
      row.cells.forEach(function (cell, i) {
        // magnitude mode: "bars" (default) | "heat" (background tint) | "off".
        // true (older pins) -> bars; the heat tint only when explicitly "heat".
        var mag = opts.heatmap === true ? "bars" : (opts.heatmap || "off");
        // The tint is scaled against a 0–100 maximum, which only holds for a
        // percentage — a count of 142 would peg every cell at full strength.
        var style = mag === "heat" && (row.kind === "mean" || rowIsPct)
          ? heat(row.kind === "mean" ? cell.mean : cell.pct, 100) : "";
        var body;
        if (row.kind === "mean") {
          body = '<span class="mv">' + fmtMean(cell.mean, model) + "</span>";
        } else {
          body = '<span class="v">' + fmtValue(cell.pct, rowStat) + "</span>";
        }
        if (cell.sig) {
          // B2: with "Explain significance" on, the marker becomes a focusable
          // plain-language tooltip built from the model's own letter map / delta.
          var sentence = explainOn()
            ? (model.composite ? TR.reader.arrowSentence(model, row, i)
              : TR.reader.letterSentence(model, row, i)) : "";
          if (model.composite) {
            // composite (profile) banner: cell.sig is a vs-the-rest arrow
            // (▲ above / ▼ below the rest), not column letters — render it as-is
            // with a matching tooltip and a down-class for the red ▼ / ▿.
            var down = /[▼▿]/.test(cell.sig);
            body += '<span class="sg' + (down ? " dn" : "") +
              (sentence ? explainAttrs(sentence) : '" title="Significantly ' +
                (down ? "lower" : "higher") +
                ' than the rest of the sample (everyone not in this column)') + '">' +
              fmt.escapeHtml(cell.sig) + "</span>";
          } else {
            body += '<span class="sg' +
              (sentence ? explainAttrs(sentence)
                : '" title="Significantly higher than column(s) ' +
                  fmt.escapeHtml(cell.sig)) + '">▲' +
              fmt.escapeHtml(cell.sig) + "</span>";
          }
        }
        if (i === 0 && opts.showDeltas && row.delta) {
          body += deltaChip(row.delta, rowIsPct);
        }
        if (opts.intervals && cell.ci) {
          body += '<div class="civ" title="95% ' + ivLabels.interval_name +
            ": the value would likely land between " +
            TR.conf.fmtRange(cell.ci.lo, cell.ci.hi, row.kind === "mean") +
            ' if the survey were repeated">' +
            TR.conf.fmtRange(cell.ci.lo, cell.ci.hi, row.kind === "mean") +
            "</div>";
        }
        if (opts.showCounts && row.kind !== "mean") {
          body += '<div class="fq">' + (cell.n === null || cell.n === undefined
            ? "" : "n=" + fmt.base(cell.n)) + "</div>";
        }
        // magnitude data bar under category % cells (doesn't obscure the text).
        // The bar's width IS the value read as a percentage of 100, so a count
        // row gets none — 142 would simply fill the track (C1).
        if (mag === "bars" && row.kind !== "mean" && rowIsPct &&
            cell.pct !== null && cell.pct !== undefined) {
          body += '<div class="dbar"><div class="dbf" style="width:' +
            Math.max(0, Math.min(cell.pct, 100)).toFixed(0) + '%"></div></div>';
        }
        out.push('<td style="' + style + '">' + body + "</td>");
      });
      out.push("</tr>");
    });
    out.push("</tbody></table>");
    return out.join("");
  };

  /** Plain matrix for exports (clipboard / PPTX / PNG-table). With
   *  opts.intervals each banner column gains "… lo"/"… hi" columns so
   *  Excel exports of interval views carry the 95% bounds explicitly. */
  render.matrix = function (model, opts) {
    opts = opts || {};
    var iv = !!opts.intervals;
    var perCol = function (label, lo, hi) {
      return iv ? [label, lo, hi] : [label];
    };
    // Same unit note as the on-screen corner cell, so a pasted / PPTX'd table
    // never reads a column of counts as percentages.
    var unitNote = render.statNote(model);
    var head = [unitNote ? "Response — " + unitNote : "Response"];
    model.columns.forEach(function (col) {
      var label = col.label + (col.letter ? " (" + col.letter + ")" : "");
      head = head.concat(perCol(label, label + " lo", label + " hi"));
    });
    // Weighted reports mirror the on-screen base block (tableHtml): the
    // unweighted row is relabelled and the weighted + Kish effective bases
    // follow, gated by the same show_weighted_base / show_effective_n flags —
    // an export labelled plain "Base (n=)" next to weighted percentages reads
    // as unweighted counts.
    var wproj = (TR.AGG && TR.AGG.project) || {};
    var wtd = !!wproj.weighted;
    // A withheld column's base is masked here too, or the exact headcount the
    // on-screen table refuses to print would ride out in the clipboard, the
    // XLSX and the PPTX matrix instead (C2).
    var baseCells = [wtd ? "Base (unweighted)" : "Base (n=)"];
    model.columns.forEach(function (col) {
      baseCells = baseCells.concat(perCol(render.baseMarker(col) ||
        (fmt.base(col.base) + (col.low ? " ⚠" : "")), "", ""));
    });
    var body = [{ kind: "base", cells: baseCells }];
    if (wtd) {
      var baseRow = function (label, key) {
        var cells = [label];
        model.columns.forEach(function (col) {
          cells = cells.concat(perCol(render.baseMarker(col) ||
            (col[key] != null ? fmt.base(col[key]) : "–"), "", ""));
        });
        body.push({ kind: "base", cells: cells });
      };
      if (wproj.show_weighted_base !== false) baseRow("Base (weighted)", "baseW");
      if (wproj.show_effective_n !== false) baseRow("Effective base", "baseEff");
    }
    var round1 = function (v) { return Math.round(v * 10) / 10; };
    // The wave-change chip for a row (▼0.1), as structured data the export
    // tables can colour; Excel/TSV ignore it. Tiny non-mean moves are dropped,
    // mirroring the on-screen deltaChip.
    var deltaInfo = function (row) {
      var d = row.delta;
      if (!d || d.diff === null || d.diff === undefined) return null;
      if (!d.isMean && Math.abs(d.diff) < 1) return null;
      var size = d.isMean ? Math.abs(d.diff).toFixed(1) : Math.abs(d.diff).toFixed(0);
      return { text: (d.diff >= 0 ? "▲" : "▼") + size, up: d.diff >= 0, sig: !!d.sig };
    };
    model.rows.forEach(function (row) {
      if (opts.categoriesOnly && row.kind !== "category") return;
      var cells = [row.label];
      var rowStat = statOf(model, row);
      row.cells.forEach(function (cell) {
        var value = row.kind === "mean" ? fmtMean(cell.mean, model)
          : fmtValue(cell.pct, rowStat);
        cells = cells.concat(perCol(
          value + (cell.sig ? " " + cell.sig : ""),
          cell.ci ? round1(cell.ci.lo) : "",
          cell.ci ? round1(cell.ci.hi) : ""));
      });
      body.push({
        kind: row.kind === "mean" ? "stat" : row.kind === "net" ? "stat" : "row",
        cells: cells, delta: deltaInfo(row)
      });
    });
    return { head: head, body: body };
  };

  render.tsv = function (model) {
    var m = render.matrix(model);
    return [m.head.join("\t")].concat(m.body.map(function (row) {
      return row.cells.join("\t");
    })).join("\n");
  };

  render.clipboardHtml = function (model) {
    var m = render.matrix(model);
    var brand = TR.charts.brandOf();
    var cellCss = "padding:4px 9px;font-size:10pt;border:1px solid #d8dcea;";
    var out = ['<table style="border-collapse:collapse;font-family:Calibri,Arial,sans-serif;">', "<tr>"];
    m.head.forEach(function (h, i) {
      out.push('<th style="' + cellCss + "background:" + brand +
        ";color:#fff;font-weight:bold;text-align:" + (i === 0 ? "left" : "center") +
        ';">' + fmt.escapeHtml(h) + "</th>");
    });
    out.push("</tr>");
    m.body.forEach(function (row) {
      var extra = row.kind === "base" ? "color:#6b7280;font-style:italic;"
        : row.kind === "stat" ? "font-weight:bold;background:#f3f4f8;" : "";
      out.push("<tr>" + row.cells.map(function (cell, i) {
        return '<td style="' + cellCss + extra + "text-align:" +
          (i === 0 ? "left" : "center") + ';">' + fmt.escapeHtml(cell) + "</td>";
      }).join("") + "</tr>");
    });
    out.push("</table>");
    return out.join("");
  };

  /** Series palette: brand first, then accent + distinguishable colours. */
  render.palette = function () {
    var brand = TR.charts.brandOf();
    var base = [brand, TR.charts.accentOf(), S.shade(brand, 0.55), "#5B8FA8",
      "#C0655B", S.shade(brand, 0.32), "#7A7FB6", "#6B7280"];
    var proj = (TR.AGG && TR.AGG.project) || {};
    // Configured banner-series colours take the lead (multi-column charts);
    // any extra columns fall back to the defaults.
    if (proj.chart_series && proj.chart_series.length) return proj.chart_series.concat(base);
    // Otherwise chart_bar_colour overrides the single-series default.
    if (proj.chart_bar_colour) base[0] = proj.chart_bar_colour;
    return base;
  };

  /**
   * Chart source rows + shared axis max. model.chartKind picks the source:
   * "summary" = NET rows (Detractor/Passive/Promoter instead of 0–10),
   * "both" = detail categories AND nets, anything else = detail only.
   * Difference rows (NET POSITIVE) never chart. Falls back to whatever
   * exists so the chart is never silently empty.
   */
  render.chartRows = function (model) {
    if (model.chartKind === "mean") return render.meanChartRows(model);
    var pick = function (kinds) {
      return model.rows.filter(function (r) {
        return kinds.indexOf(r.kind) !== -1 && !r.diff &&
          r.cells.some(function (c) {
            return c.pct !== null && c.pct !== undefined;
          });
      });
    };
    var kinds = model.chartKind === "summary" ? ["net"]
      : model.chartKind === "both" ? ["category", "net"]
      : ["category"];
    var rows = pick(kinds);
    if (!rows.length) rows = pick(["category", "net"]);
    // per-row chart selection from the Rows & columns panel — rows the
    // user unticked for the chart (the table is governed separately)
    var hidden = model.hiddenChartRows || [];
    if (hidden.length) {
      rows = rows.filter(function (r) { return hidden.indexOf(r.label) === -1; });
    }
    var max = 0;
    rows.forEach(function (r) {
      r.cells.forEach(function (c) { if (c.pct > max) max = c.pct; });
    });
    return { rows: rows, axisMax: S.niceMax(max) };
  };

  /**
   * Chart source rows for the "Index (mean)" plot: the question's mean / Index
   * row(s), with the rating exposed in the chartable `pct` slot so the renderer
   * (columnChart, meanScale) scales + labels them as RATINGS, not percentages.
   * Honours per-row unticks and takes its axis from the data, like the
   * distribution path.
   */
  render.meanChartRows = function (model) {
    var has = function (c) { return c.mean !== null && c.mean !== undefined; };
    var rows = model.rows.filter(function (r) {
      return r.kind === "mean" && r.cells.some(has);
    }).map(function (r) {
      return { kind: r.kind, label: r.label, cells: r.cells.map(function (c) {
        return { pct: has(c) ? c.mean : null, n: c.n, sig: c.sig || "" };
      }) };
    });
    var hidden = model.hiddenChartRows || [];
    if (hidden.length) rows = rows.filter(function (r) { return hidden.indexOf(r.label) === -1; });
    var max = 0;
    rows.forEach(function (r) { r.cells.forEach(function (c) { if (c.pct > max) max = c.pct; }); });
    return { rows: rows, axisMax: S.niceMax(max) };
  };

  /** True when the question has a chartable mean (Index) row. */
  render.hasMeanRow = function (model) {
    return model.rows.some(function (r) {
      return r.kind === "mean" && r.cells.some(function (c) {
        return c.mean !== null && c.mean !== undefined;
      });
    });
  };

  /**
   * Transpose a mean ("Index") plot so each charted column becomes its own
   * labelled bar (its mean) — the column identity then reads off the axis next
   * to the bar, instead of from a legend. Returns {model, cols} unchanged for
   * any non-mean plot, or when the Index row is unticked (nothing to chart), so
   * distribution charts and the empty case are untouched.
   */
  render.asMeanByColumn = function (model, cols) {
    if (!Array.isArray(cols)) cols = [cols || 0];
    if (model.valueKind !== "mean") return { model: model, cols: cols };
    var data = render.meanChartRows(model);
    if (!data.rows.length) return { model: model, cols: cols };
    var src = data.rows[0];                       // the Index row; cells[ci].pct = its mean
    var rows = cols.map(function (ci) {
      var c = src.cells[ci] || {};
      return { kind: "category",
        label: model.columns[ci] ? model.columns[ci].label : "?",
        cells: [{ pct: (c.pct === null || c.pct === undefined) ? null : c.pct, n: null, sig: "" }] };
    });
    return { model: { code: model.code, valueKind: "mean",
      columns: [{ label: src.label, letter: "", base: null, low: false }],
      rows: rows }, cols: [0] };
  };

  /** True when a model actually has chartable NET rows. */
  render.hasNetRows = function (model) {
    return model.rows.some(function (r) {
      return r.kind === "net" && !r.diff && r.cells.some(function (c) {
        return c.pct !== null && c.pct !== undefined;
      });
    });
  };

  function colLegend(model, cols, y, x0, maxW) {
    var palette = render.palette();
    return S.legend(cols.map(function (ci, k) {
      return { label: model.columns[ci] ? model.columns[ci].label : "?",
        colour: palette[k % palette.length] };
    }), x0, y, maxW);
  }

  /**
   * Horizontal bars, grouped when multiple columns are selected
   * (e.g. Total + each campus side by side).
   * @param {number[]|number} cols - selected column indexes.
   */
  render.barChart = function (model, cols) {
    if (!Array.isArray(cols)) cols = [cols || 0];
    var mb = render.asMeanByColumn(model, cols); model = mb.model; cols = mb.cols;
    var data = render.chartRows(model);
    if (!data.rows.length) return "";
    var meanScale = model.valueKind === "mean";   // ratings, not percentages
    var barNote = statOf(model, null);            // counts chart as counts (C1)
    var W = 660, LABEL = 210, VAL = 64;
    var barH = cols.length > 1 ? 13 : 20;
    var groupGap = 9;
    var plotW = W - LABEL - VAL;
    var x = S.linear(data.axisMax, plotW);
    var palette = render.palette();
    // Single series: colour each bar by its category (semantic palette) — the
    // classic-report look. Multiple columns stay series-coloured so the cuts
    // remain distinguishable.
    var catColours = cols.length === 1 ? render.categoryColours(data.rows) : null;
    var body = [], y = 8;
    var labelLineH = 12;
    data.rows.forEach(function (r, ri) {
      // full label, wrapped — the row grows to fit the text (no ellipses)
      var labelLines = S.wrapText(r.label, 32);
      var barBlock = (barH + 2) * cols.length - 2;
      var rowH = Math.max(barBlock, labelLines.length * labelLineH - 2);
      var labelTop = y + rowH / 2 + 4 - (labelLines.length - 1) * labelLineH / 2;
      labelLines.forEach(function (line, li) {
        body.push(S.text(LABEL - 8, labelTop + li * labelLineH, line,
          { "text-anchor": "end", "font-size": 11.5, fill: "#3b4252" }));
      });
      var barY = y + (rowH - barBlock) / 2;
      cols.forEach(function (ci, k) {
        var cell = r.cells[ci];
        var v = cell ? cell.pct : null;
        var w = v === null ? 0 : Math.max(x(v), 0);
        body.push(S.el("rect", { x: LABEL, y: barY, width: plotW, height: barH,
          fill: "#eef0f7", rx: 3 }));
        body.push(S.el("rect", { x: LABEL, y: barY, width: w, height: barH,
          fill: catColours ? catColours[ri] : palette[k % palette.length], rx: 3 }));
        body.push(S.text(LABEL + w + 6, barY + barH * 0.78,
          (meanScale ? fmtMean(v, model) : fmtValue(v, statOf(model, r))) +
          (cols.length === 1 && cell && cell.sig
            ? " " + (/^[▲▼▵▿]/.test(cell.sig) ? "" : "▲") + cell.sig : ""),
          { "font-size": cols.length > 1 ? 10 : 11.5, "font-weight": 600,
            fill: "#1c2333" }));
        barY += barH + 2;
      });
      y += rowH + groupGap;
    });
    var note = "0–" + data.axisMax + (meanScale ? " rating scale"
      : isPct(barNote) ? "% scale" : " count scale");
    if (cols.length === 1 && model.columns[cols[0]]) {
      note += " · " + model.columns[cols[0]].label;
    }
    body.push(S.text(LABEL, y + 8, note, { "font-size": 10, fill: "#9aa1b1" }));
    y += 18;
    if (cols.length > 1) {
      var legend = colLegend(model, cols, y + 6, LABEL, W - LABEL - 10);
      body.push(legend.body);
      y += legend.height + 6;
    }
    return S.root(W, y + 4, model.code + " — chart", body.join(""));
  };

})(typeof window !== "undefined" ? window : globalThis);
