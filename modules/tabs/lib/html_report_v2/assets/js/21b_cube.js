/**
 * v2 AGGREGATE CUBE engine. The second computed source.
 *
 * TR.MICRO carries one array position per respondent, which is what lets the
 * report recompute a filtered or custom-bannered table, and also what lets a
 * recipient join those indices back to the published labels and reproduce a
 * respondent-by-question dataset. TR.CUBE carries precomputed sufficient
 * statistics per (variable combination, question, cell) instead: the same
 * figures, no respondents.
 *
 * Everything here returns the shapes 21_stats.js already returns, so nothing
 * above the stats seam has to know which source it is reading. 21_stats routes
 * to these functions when a cube is installed and a respondent island is not.
 *
 * What the cube can and cannot serve:
 *   serves    filters up to TR.CUBE.order on DECLARED variables; every declared
 *             banner under a filter; custom banners on declared variables in
 *             category and NET modes; composite banners restricted to declared
 *             variables; Differences; Pattern Recognition; confidence detail;
 *             the Reader's audience strip
 *   refuses   a filter on an undeclared question ("undeclared"), more variables
 *             than the order cap ("order"), a question whose block was withheld
 *             at this cut ("block"). A refusal is a sentence, never a base of 0
 *             against real figures.
 *
 * Written to be read beside modules/tabs/lib/cube_writer.R, which builds what
 * this reads. The two are held to each other by CP-4 in
 * modules/tabs/lib/html_report_v2/tests/computed_parity_tests.mjs.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var cube = TR.cube = {};

  /** The empty combination, and its single cell. An empty string is not a
   *  usable JSON object key, and "*" cannot collide with a real combination:
   *  a one-variable key is a bare variable name. Mirrors CUBE_TOTAL_SLICE. */
  var TOTAL = "*";

  /** True when the cube is the source: installed, with no respondent island. */
  cube.active = function () {
    return !!(TR.CUBE && TR.CUBE.slices && !(TR.MICRO && TR.MICRO.answers));
  };

  /** Declared variable names, in the order the cube's slice keys use. */
  cube.varNames = function () {
    return TR.CUBE && TR.CUBE.vars ? Object.keys(TR.CUBE.vars) : [];
  };

  cube.isDeclared = function (name) {
    return !!(TR.CUBE && TR.CUBE.vars &&
      Object.prototype.hasOwnProperty.call(TR.CUBE.vars, name));
  };

  cube.levelsOf = function (name) {
    var v = TR.CUBE && TR.CUBE.vars && TR.CUBE.vars[name];
    return v ? v.levels : [];
  };

  /**
   * The cube levels a set of QUESTION ROW indices names, or null when this
   * variable cannot be addressed in row space.
   *
   * Everything a reader picks arrives in row space: the filter bar, the custom
   * banner and the composite builder all name a value by its position in the
   * question's own row list (26_filter.js, selectionToFilter). A QUESTION
   * variable's level IS that position and passes straight through. A BANNER
   * variable's level is a COLUMN index, and columns begin after Total, so the
   * two spaces are offset and a row taken at face value reports a different
   * group under the reader's label. It is translated through the map
   * cube_writer.R builds, which carries a row only where the row and the column
   * name the same people.
   *
   * null means refuse. A row the map does not carry belongs to a banner that
   * merged it with another or left it out, and there is no honest answer to
   * give. A row mapped to -1 is a value nobody chose: it drops out of the
   * selection and leaves an audience of nobody, which is what the respondent
   * island returns for it.
   */
  cube.levelsForRows = function (name, rows) {
    var v = TR.CUBE && TR.CUBE.vars && TR.CUBE.vars[name];
    if (!v) return null;
    var list = (rows || []).map(Number);
    if (v.kind !== "banner") return list;
    var map = v.rowmap;
    if (!map) return null;
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var lv = map[String(list[i])];
      if (lv === undefined || lv === null) return null;
      if (lv >= 0) out.push(lv);
    }
    return out;
  };

  cube.questionFacts = function (code) {
    var qs = TR.CUBE && TR.CUBE.questions;
    return (qs && Object.prototype.hasOwnProperty.call(qs, code)) ? qs[code] : null;
  };

  cube.has = function (code, what) {
    var f = cube.questionFacts(code);
    return !!(f && f.has && f.has.indexOf(what) !== -1);
  };

  /**
   * One authored sentence for a cut this report cannot serve.
   *
   * A refusal has to READ as a refusal. The alternative the engine would
   * otherwise fall into is a table of dashes over a base of 0, which looks
   * exactly like "nobody in this group answered" and is a different, false
   * statement. Keyed like every other sentence in the report, so the author can
   * edit it.
   */
  cube.refusalText = function (refusal) {
    if (!refusal || !TR.txt) return "";
    if (refusal.reason === "order") {
      return TR.txt("cube.refuse.order", { order: (TR.CUBE && TR.CUBE.order) || 2 });
    }
    if (refusal.reason === "undeclared") return TR.txt("cube.refuse.undeclared");
    if (refusal.reason === "rows") return TR.txt("cube.refuse.rows");
    return TR.txt("cube.refuse.block", { k: (TR.CUBE && TR.CUBE.k) || 0 });
  };

  /* ---------------------------------------------------------------------------
     Slices and cells
  --------------------------------------------------------------------------- */

  /** Slice key for a set of variable names, ordered as the cube declares them. */
  function sliceKey(names) {
    if (!names.length) return TOTAL;
    var order = cube.varNames();
    var sorted = names.slice().sort(function (a, b) {
      return order.indexOf(a) - order.indexOf(b);
    });
    return sorted.join("*");
  }
  cube._sliceKey = sliceKey;

  /** The variable names a slice key is built from, in key order. */
  function sliceVars(key) {
    return key === TOTAL ? [] : key.split("*");
  }

  /**
   * Cell keys of one slice, parsed once into {key, lv: {var: level}}. Parsing
   * a key per lookup would re-split the same strings thousands of times on the
   * enumerated parity run; the cache is keyed on the cube object so installing
   * a different cube cannot read a stale index.
   */
  var cellCache = null, cellCacheFor = null;
  function cellIndex(key) {
    if (cellCacheFor !== TR.CUBE) { cellCache = {}; cellCacheFor = TR.CUBE; }
    if (cellCache[key]) return cellCache[key];
    var slice = TR.CUBE.slices[key];
    var vars = sliceVars(key);
    var out = [];
    if (slice && slice.cells) {
      Object.keys(slice.cells).forEach(function (ck) {
        var lv = {};
        if (vars.length) {
          var parts = ck.split("|");
          for (var i = 0; i < vars.length; i++) lv[vars[i]] = Number(parts[i]);
        }
        out.push({ key: ck, lv: lv });
      });
    }
    cellCache[key] = out;
    return out;
  }

  /** The level selection a column spec imposes, or null for Total. */
  function colSel(col) {
    if (!col) return null;
    if (col.rest) return colSel(col.of);
    return col.sel || null;
  }
  cube._colSel = colSel;

  /** The variables a (audience, column) lookup needs. */
  function requiredVars(mask, col) {
    var out = [];
    var sel = (mask && mask.sel) || {};
    Object.keys(sel).forEach(function (v) { out.push(v); });
    var cs = colSel(col);
    if (cs && out.indexOf(cs.var) === -1) out.push(cs.var);
    return out;
  }

  /**
   * Cell records for (audience, column), as {add, sub} so a "the rest" column
   * is the exact subtraction it has to be: every accumulator here is additive,
   * so the rest is (everyone in the audience) minus (this column), including
   * the respondents who fall in no column of the banner at all. That is what
   * the respondent-island engine's complement mask contains, so the two agree.
   *
   * @param source "q" for a question block, "cells" for the audience record
   * @returns {{add: Array, sub: Array}|null} null when the cut is refused
   */
  function records(code, mask, col, source) {
    if (col && col.rest) {
      var whole = records(code, mask, null, source);
      var part = records(code, mask, col.of, source);
      if (!whole || !part) return null;
      return { add: whole.add, sub: part.add,
        withheld: whole.withheld || part.withheld };
    }
    var vars = requiredVars(mask, col);
    if (vars.length > TR.CUBE.order) return null;
    var key = sliceKey(vars);
    var slice = TR.CUBE.slices[key];
    if (!slice) return null;
    var block = source === "cells" ? slice.cells : (slice.q ? slice.q[code] : null);
    if (!block) return null;
    var sel = (mask && mask.sel) || {};
    var selVars = Object.keys(sel);
    var cs = colSel(col);
    var out = [];
    var withheld = false;
    cellIndex(key).forEach(function (c) {
      for (var i = 0; i < selVars.length; i++) {
        if (sel[selVars[i]].indexOf(c.lv[selVars[i]]) === -1) return;
      }
      if (cs && cs.levels.indexOf(c.lv[cs.var]) === -1) return;
      var rec = block[c.key];
      if (rec) {
        // A cell that ships its base and no answers. Its group is under k on a
        // published banner margin, exactly as that column is blanked in the
        // workbook. The BASE still counts, so the column reports who is in it;
        // the figures do not, and the caller blanks them rather than reading
        // absent answers as zeros. That matters most when a selection mixes a
        // shipped cell with a withheld one: the base would clear k and the
        // percentages would silently be computed off part of the group.
        if (rec.sup) withheld = true;
        out.push(rec);
      }
    });
    return { add: out, sub: [], withheld: withheld };
  }
  cube._records = records;

  /**
   * Why this cut cannot be served, or null when it can.
   * Checked ONCE, before any accumulation, so a refusal reaches the reader as a
   * sentence rather than as a table of dashes.
   */
  cube.refusalFor = function (code, columns, mask) {
    if (mask && mask.refused) return mask.refused;
    var specs = (columns || []).slice();
    if (!specs.length) specs = [null];
    for (var i = 0; i < specs.length; i++) {
      var col = specs[i];
      var vars = requiredVars(mask, col);
      if (vars.length > TR.CUBE.order) return { reason: "order" };
      var cs = colSel(col);
      if (cs && !cube.isDeclared(cs.var)) {
        return { reason: "undeclared", "var": cs.var };
      }
      var key = sliceKey(vars);
      var slice = TR.CUBE.slices[key];
      if (!slice) return { reason: "block", q: code };
      if (code !== null && (!slice.q || !slice.q[code])) {
        return { reason: "block", q: code };
      }
    }
    return null;
  };

  /* ---------------------------------------------------------------------------
     Summation helpers. Every one is add minus sub.
  --------------------------------------------------------------------------- */

  function sumTuple(rs, field, width) {
    var out = new Array(width);
    for (var i = 0; i < width; i++) out[i] = 0;
    if (!rs) return out;
    var walk = function (list, sign) {
      list.forEach(function (rec) {
        var v = rec[field];
        if (!v) return;
        for (var i = 0; i < width; i++) out[i] += sign * (v[i] || 0);
      });
    };
    walk(rs.add, 1); walk(rs.sub, -1);
    return out;
  }

  function sumMap(rs, field, key) {
    var total = 0;
    if (!rs) return 0;
    var k = String(key);
    var walk = function (list, sign) {
      list.forEach(function (rec) {
        var m = rec[field];
        if (!m) return;
        var v = m[k];
        if (v) total += sign * v;
      });
    };
    walk(rs.add, 1); walk(rs.sub, -1);
    return total;
  }

  function sumNested(rs, field, key, width) {
    var out = new Array(width);
    for (var i = 0; i < width; i++) out[i] = 0;
    if (!rs) return out;
    var k = String(key);
    var walk = function (list, sign) {
      list.forEach(function (rec) {
        var m = rec[field];
        if (!m) return;
        var v = m[k];
        if (!v) return;
        for (var i = 0; i < width; i++) out[i] += sign * (v[i] || 0);
      });
    };
    walk(rs.add, 1); walk(rs.sub, -1);
    return out;
  }

  /** Is any record in this set carrying the field at all? An optional channel
   *  is present for every cell of a block or absent from the whole block, so
   *  one record answers for all of them. */
  function carries(rs, field) {
    if (!rs) return false;
    var any = false;
    rs.add.forEach(function (rec) { if (rec[field] !== undefined) any = true; });
    rs.sub.forEach(function (rec) { if (rec[field] !== undefined) any = true; });
    return any;
  }

  function effectiveBase(sumW, sumW2) {
    return sumW2 > 0 ? (sumW * sumW) / sumW2 : 0;
  }

  /** The {mean, sd, k} shape, from the five moments 21_stats accumulates. */
  function meanShape(m) {
    var wbase = m[1];
    if (!wbase) return { mean: null, sd: 0, k: 0 };
    var eff = effectiveBase(m[1], m[2]);
    var mean = m[3] / wbase;
    var popVar = m[4] / wbase - mean * mean;
    var variance = eff > 1 ? popVar * eff / (eff - 1) : 0;
    return { mean: mean, sd: Math.sqrt(Math.max(variance, 0)), k: eff };
  }
  cube._meanShape = meanShape;

  /* ---------------------------------------------------------------------------
     The audience
  --------------------------------------------------------------------------- */

  /**
   * The audience spec the cube uses in place of a respondent mask. Nothing
   * outside 21_stats may index a mask, so this carries no per-respondent state
   * at all: a level selection per declared variable, and the count.
   *
   * Two filters on ONE variable intersect their level sets, which is what
   * chaining two masks does today.
   */
  cube.mask = function (filters) {
    var sel = {}, refused = null;
    (filters || []).forEach(function (f) {
      if (refused) return;
      if (f.box) {
        // Box groupings are not declared variables in this version: a box
        // partition would be a second variable per question, and the config
        // layer refuses to declare a hidden-scale question as a filter
        // variable. Fails closed rather than filtering on something else.
        refused = { reason: "undeclared", "var": f.q };
        return;
      }
      if (!cube.isDeclared(f.q)) {
        refused = { reason: "undeclared", "var": f.q };
        return;
      }
      var wanted = cube.levelsForRows(f.q, f.rows);
      if (wanted === null) {
        refused = { reason: "rows", "var": f.q };
        return;
      }
      var have = sel[f.q];
      sel[f.q] = have
        ? have.filter(function (x) { return wanted.indexOf(x) !== -1; })
        : wanted;
    });
    var spec = { cube: true, sel: sel, refused: refused, count: 0 };
    if (!refused) {
      var rs = records(null, spec, null, "cells");
      if (!rs) spec.refused = { reason: "block" };
      else spec.count = sumTuple(rs, "a", 3)[0];
    }
    return spec;
  };

  cube.maskCount = function (mask) { return mask ? (mask.count || 0) : 0; };

  /** Audience moments {n, sw, sw2} for the strip and the disclosure gate. */
  cube.audienceMoments = function (mask, col) {
    var rs = records(null, mask, col || null, "cells");
    if (!rs) return { n: 0, sw: 0, sw2: 0 };
    var a = sumTuple(rs, "a", 3);
    return { n: a[0], sw: a[1], sw2: a[2] };
  };

  /* ---------------------------------------------------------------------------
     Columns
  --------------------------------------------------------------------------- */

  /** A column spec for one set of levels of one declared variable. */
  function levelCol(label, letter, name, levels, extra) {
    var c = { label: label, letter: letter, sel: { "var": name, levels: levels } };
    if (extra) Object.keys(extra).forEach(function (k) { c[k] = extra[k]; });
    return c;
  }

  /** Everyone in ANY column of a banner group. Not the same as Total: a
   *  respondent in no column of the group is excluded, which is the arm the
   *  Executive Takeout's cell family compares against. */
  cube.groupColumn = function (bannerId) {
    if (!cube.isDeclared(bannerId)) return null;
    return levelCol("All", "", bannerId, cube.levelsOf(bannerId).slice());
  };

  cube.columnsFor = function (banner) {
    var columns = [{ label: "Total", letter: "", member: null, sel: null }];
    if (banner && banner.indexOf("composite:") === 0) {
      var spec = TR.compositeBanners && TR.compositeBanners.get(banner);
      if (!spec || !spec.columns || !spec.columns.length) {
        return { columns: columns, composite: true, missing: !spec };
      }
      var ok = true;
      var built = [];
      spec.columns.forEach(function (def) {
        if (!ok) return;
        // A box-scored spotlight has no declared variable behind it, and a
        // column from an undeclared question is the disclosure hole this whole
        // design closes. Either one falls back to Total only, which is the
        // missing-spec behaviour a saved banner already has.
        if (def.box != null || !cube.isDeclared(def.code)) { ok = false; return; }
        var lv = cube.levelsForRows(def.code, def.rows);
        if (lv === null) { ok = false; return; }
        built.push(levelCol(def.label, "", def.code, lv, { composite: true }));
      });
      if (!ok) return { columns: columns, composite: true, missing: true };
      return { columns: columns.concat(built), composite: true, spec: spec };
    }
    if (banner && banner.indexOf("custom:") === 0) {
      var bits = banner.split(":");
      var code = bits[1];
      var mode = bits[2] || "cat";
      var q = TR.d2.questionByCode(code);
      if (!q || !cube.isDeclared(code)) {
        return { columns: columns, custom: true, missing: true };
      }
      var defs = [];
      if (mode === "net") {
        Object.keys(q.net_members || {}).map(Number).sort(function (a, b) {
          return a - b;
        }).forEach(function (ri) {
          defs.push({ label: q.rows[ri].label,
            members: (q.net_members[String(ri)] || []).map(Number) });
        });
        // No decomposable NETs. The respondent island falls back to BOX
        // groupings here, which are not declared variables in this version, so
        // a question that carries boxes shows Total only. One that carries none
        // falls through to its category rows exactly as the island does.
        if (!defs.length && cube.has(code, "boxes")) {
          return { columns: columns, custom: true, missing: true };
        }
      }
      if (!defs.length) {
        TR.d2.catRows(q).forEach(function (cat) {
          defs.push({ label: cat.label, members: [cat.index] });
        });
      }
      // Built to one side first: a banner whose columns cannot all be
      // translated shows Total only, exactly as an undeclared one does, rather
      // than a table half of whose columns are about someone else.
      var letterAt = 0;
      var made = [];
      var translatable = true;
      defs.forEach(function (def) {
        if (!translatable) return;
        var lv = cube.levelsForRows(code, def.members);
        if (lv === null) { translatable = false; return; }
        made.push(levelCol(def.label,
          String.fromCharCode(65 + (letterAt++ % 26)), code, lv));
      });
      if (!translatable) return { columns: columns, custom: true, missing: true };
      return { columns: columns.concat(made), custom: true, source: q, mode: mode };
    }
    var groupCols = TR.d2.groupCols(banner);
    if (!cube.isDeclared(banner)) {
      return { columns: columns, custom: false, missing: groupCols.length > 0 };
    }
    groupCols.forEach(function (ci) {
      columns.push(levelCol(TR.AGG.columns[ci].label, TR.AGG.columns[ci].letter,
        banner, [ci], { colIndex: ci }));
    });
    return { columns: columns, custom: false };
  };

  /** "The rest": everyone in the audience except this column. */
  cube.restOf = function (col) {
    if (!col || !col.sel) return { sel: null };   // the rest of Total is nobody
    return { rest: true, of: col, label: "Rest", letter: "" };
  };

  /* ---------------------------------------------------------------------------
     The accumulators. Each returns the shape 21_stats returns.
  --------------------------------------------------------------------------- */

  cube.tabulate = function (q, columns, mask) {
    var catRows = TR.d2.catRows(q);
    return columns.map(function (col) {
      var rs = records(q.code, mask, col, "q");
      var counts = {};
      catRows.forEach(function (cat) {
        counts[cat.index] = rs ? sumMap(rs, "r", cat.index) : 0;
      });
      var b = sumTuple(rs, "b", 3);
      var out = { base: b[0], counts: counts, wbase: b[1],
        effBase: effectiveBase(b[1], b[2]) };
      // computedModel calls tabulate for every column before anything else, so
      // this is where the withheld flag reaches the view. The column then
      // blanks whole, through the disclosure pass that already blanks a
      // below-threshold column.
      if (rs && rs.withheld) out.withheld = true;
      return out;
    });
  };

  /**
   * The NET row a member list belongs to. netCounts takes the members rather
   * than the row, and a NET is a UNION whose accumulator is stored per row, so
   * the row has to be recovered. Every caller derives the list from
   * q.net_members, so the match is exact; an unrecognised list returns null and
   * the row goes blank rather than showing a sum of overlapping members.
   */
  function netRowFor(q, members) {
    var want = (members || []).map(Number).slice().sort(function (a, b) {
      return a - b;
    }).join(",");
    var nm = q.net_members || {};
    var found = null;
    Object.keys(nm).forEach(function (ri) {
      if (found !== null) return;
      var have = (nm[ri] || []).map(Number).slice().sort(function (a, b) {
        return a - b;
      }).join(",");
      if (have === want) found = ri;
    });
    return found;
  }
  cube._netRowFor = netRowFor;

  cube.netCounts = function (q, members, columns, mask) {
    var ri = netRowFor(q, members);
    return columns.map(function (col) {
      var rs = records(q.code, mask, col, "q");
      // netCounts counts only respondents with a RAW answer, a narrower base
      // than tabulate's wherever a question carries box membership without one.
      // `nb` is written only when it differs, so `b` is the fallback.
      var base = (rs && carries(rs, "nb")) ? sumTuple(rs, "nb", 3)
        : sumTuple(rs, "b", 3);
      var hit = (rs && ri !== null) ? sumMap(rs, "n", ri) : 0;
      return { base: base[0], n: hit, wbase: base[1],
        effBase: effectiveBase(base[1], base[2]) };
    });
  };

  cube.boxCounts = function (qcode, boxRi, columns, mask) {
    return columns.map(function (col) {
      var rs = records(qcode, mask, col, "q");
      var b = sumTuple(rs, "b", 3);
      return { base: b[0], n: rs ? sumMap(rs, "x", boxRi) : 0, wbase: b[1],
        effBase: effectiveBase(b[1], b[2]) };
    });
  };

  cube.indexMeans = function (q, columns, mask) {
    var facts = cube.questionFacts(q.code);
    if (!facts || !facts.score_src) return null;
    return columns.map(function (col) {
      var rs = records(q.code, mask, col, "q");
      return meanShape(sumTuple(rs, "s", 5));
    });
  };

  cube.medians = function (q, columns, mask) {
    var facts = cube.questionFacts(q.code);
    if (!facts || !facts.score_src) return null;
    if (TR.stats.isWeighted && TR.stats.isWeighted()) {
      return columns.map(function () { return { mean: null, sd: 0, k: 0 }; });
    }
    var values = facts.score_values || null;
    return columns.map(function (col) {
      var rs = records(q.code, mask, col, "q");
      if (!rs) return { mean: null, sd: 0, k: 0 };
      if (values && values.length) {
        // A designed scale ships its whole distribution per cell, so the median
        // of any union of cells is exact.
        var counts = [], total = 0, i;
        for (i = 0; i < values.length; i++) {
          var c = sumMap(rs, "d", TR.cube._scoreKey(values[i]));
          counts.push(c);
          total += c;
        }
        if (!total) return { mean: null, sd: 0, k: 0 };
        var lower = valueAt(values, counts, Math.floor((total - 1) / 2));
        var upper = valueAt(values, counts, Math.floor(total / 2));
        return { mean: (lower + upper) / 2, sd: 0, k: total };
      }
      // A continuous measure has no distribution to sum. Its median is served
      // where the cut resolves to a SINGLE cell (one precomputed scalar) and
      // withheld otherwise, because a median of a union cannot come from one
      // median per cell. Blank, never a plausible wrong number.
      if (rs.sub.length === 0 && rs.add.length === 1 && rs.add[0].m !== undefined) {
        var b = sumTuple(rs, "b", 3);
        return { mean: rs.add[0].m, sd: 0, k: b[0] };
      }
      return { mean: null, sd: 0, k: 0 };
    });
  };

  /** The value at a zero-based rank in a counted distribution. */
  function valueAt(values, counts, rank) {
    var seen = 0;
    for (var i = 0; i < values.length; i++) {
      seen += counts[i];
      if (rank < seen) return values[i];
    }
    return values[values.length - 1];
  }

  /** Mirrors cube_score_key() in cube_writer.R. */
  cube._scoreKey = function (v) {
    var s = String(v);
    return s;
  };

  cube.seriesMeans = function (q, rowIndex, columns, mask) {
    if (!cube.has(q.code, "series")) return null;
    var served = false;
    var out = columns.map(function (col) {
      var rs = records(q.code, mask, col, "q");
      if (rs && carries(rs, "sr")) served = true;
      return meanShape(sumNested(rs, "sr", rowIndex, 5));
    });
    return served ? out : null;
  };

  cube.ratioOfTotals = function (ratio, columns, mask, qcode) {
    var served = false;
    var out = columns.map(function (col) {
      var rs = records(qcode, mask, col, "q");
      if (rs && carries(rs, "rt")) served = true;
      var t = sumTuple(rs, "rt", 3);
      return { mean: t[2] > 0 ? t[1] / t[2] : null, sd: 0, k: t[0] };
    });
    return served ? out : null;
  };

  /**
   * The +-100 NET POSITIVE score, from the box counts and the answered base.
   * Sum of w times score is 100 times (W plus minus W minus); sum of w times
   * score squared is 10,000 times (W plus plus W minus). Both come from the box
   * accumulators, so the printed net's letters test the number the row shows,
   * exactly as they do on the respondent island.
   */
  cube.netScoreMeans = function (qcode, plusRi, minusRi, columns, mask) {
    return columns.map(function (col) {
      var rs = records(qcode, mask, col, "q");
      var b = sumTuple(rs, "b", 3);
      if (!b[1]) return { mean: null, sd: 0, k: 0 };
      var wp = rs ? sumMap(rs, "x", plusRi) : 0;
      var wm = rs ? sumMap(rs, "x", minusRi) : 0;
      return meanShape([b[0], b[1], b[2], 100 * (wp - wm), 10000 * (wp + wm)]);
    });
  };

  /** {n, sw, sw2, swx, swx2} for one column's scores. The Welch arms of the
   *  Executive Takeout's cell family, which only ever used those moments. */
  cube.momentsOf = function (qcode, col, mask) {
    var rs = records(qcode, mask, col, "q");
    var s = sumTuple(rs, "s", 5);
    return { n: s[0], sw: s[1], sw2: s[2], swx: s[3], swx2: s[4] };
  };

  /**
   * The same moments for a KeyShare row: a 0/100 encoding of "is this
   * respondent in the share", over the question's answered base. The numerator
   * is the row count for a category, the NET count for a decomposable NET and
   * the box count for a box-scored one, which is exactly what the per-respondent
   * encoding sums to.
   */
  cube.shareMomentsOf = function (q, ri, col, mask) {
    var rs = records(q.code, mask, col, "q");
    var b = sumTuple(rs, "b", 3);
    var row = (q.rows || [])[ri] || {};
    var hit = 0;
    if (row.kind === "net") {
      var members = q.net_members && q.net_members[String(ri)];
      if (members && members.length) hit = sumMap(rs, "n", netRowFor(q, members));
      else hit = sumMap(rs, "x", ri);
    } else {
      hit = sumMap(rs, "r", ri);
    }
    return { n: b[0], sw: b[1], sw2: b[2], swx: 100 * hit, swx2: 10000 * hit };
  };

})(typeof window !== "undefined" ? window : globalThis);
