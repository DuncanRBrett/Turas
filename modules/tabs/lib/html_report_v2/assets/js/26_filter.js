/**
 * v2 global filter bar + pickers. Filters apply to EVERY view (crosstabs,
 * dashboard, what-moved, findings, story) — the whole report recomputes
 * from microdata with live bases and significance. Also hosts the custom
 * banner picker ("cross anything by anything").
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var filterBar = TR.filterBar = {};

  filterBar.render = function () {
    var holder = document.getElementById("filterbar");
    if (!holder) return;
    var d2 = TR.d2, s = d2.state;
    if (!d2.hasMicrodata()) { holder.innerHTML = ""; return; }
    var chips = s.filters.map(function (f, i) {
      var q = d2.questionByCode(f.q);
      var labels = f.rows.map(function (ri) {
        return q && q.rows[ri] ? q.rows[ri].label : "?";
      });
      return '<span class="fchip">' + fmt.escapeHtml(q ? q.code : f.q) + ": " +
        fmt.escapeHtml(TR.charts.clip(labels.join(" / "), 48)) +
        '<button data-fremove="' + i + '" aria-label="Remove filter">✕</button></span>';
    }).join("");
    var n = s.filters.length ? TR.stats.maskCount(TR.stats.mask(s.filters)) : TR.MICRO.n;
    // Disclosure control: warn (report-wide) when a composite filter narrows the audience
    // below the confidentiality threshold — the views then withhold identifying detail.
    var discWarn = (TR.disclosure && TR.disclosure.audienceTooSmall())
      ? '<div class="fb-warn" role="alert">🛡 ' + fmt.escapeHtml(TR.disclosure.note()) + "</div>"
      : "";
    holder.innerHTML = '<div class="fb-in"><span class="fb-label">Audience</span>' +
      chips +
      '<button class="fb-add" data-fact="add">+ Add filter</button>' +
      (s.filters.length
        ? '<button class="fb-clear" data-fact="clear">Clear</button>' +
          '<span class="fb-n">n=' + fmt.base(n) + " of " + fmt.base(TR.MICRO.n) +
          ' · live recompute · <em>synthetic microdata</em>' +
          (TR.d2.tracking().enabled
            ? ' · wave trends hidden while filtered (prior waves are full-sample totals)'
            : "") + "</span>"
        : '<span class="fb-n">everyone (n=' + fmt.base(TR.MICRO.n) +
          ") · add a filter and every table, delta and dashboard recomputes live</span>") +
      "</div>" + discWarn + "<div id='fpicker' hidden></div>";
    holder.querySelectorAll("[data-fremove]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        TR.d2.state.filters.splice(parseInt(btn.getAttribute("data-fremove"), 10), 1);
        filterBar.render();
        TR.shell.route();
      });
    });
    holder.querySelectorAll("[data-fact]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        if (btn.getAttribute("data-fact") === "clear") {
          TR.d2.state.filters = [];
          filterBar.render();
          TR.shell.route();
        } else {
          openPicker(false);
        }
      });
    });
  };

  /** Question/value picker; asBanner=true picks a custom banner instead. */
  function openPicker(asBanner) {
    var holder = document.getElementById("fpicker");
    holder.hidden = false;
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">' +
      (asBanner ? "Cross every table by…" : "Filter the whole report by…") +
      '<button data-close aria-label="Close">✕</button></div>' +
      '<input type="search" id="fpick-search" placeholder="Search questions…">' +
      '<div class="fpick-list">' + TR.AGG.questions.map(function (q) {
        return '<button class="fpick-q" data-code="' + q.code + '" data-search="' +
          fmt.escapeHtml((q.code + " " + q.title).toLowerCase()) + '">' +
          '<span class="qc">' + q.code + "</span> " + fmt.escapeHtml(q.title) +
          "</button>";
      }).join("") + "</div></div>";
    holder.querySelector("[data-close]").addEventListener("click", function () {
      holder.hidden = true;
    });
    holder.querySelector("#fpick-search").addEventListener("input", function (e) {
      var term = e.target.value.trim().toLowerCase();
      holder.querySelectorAll(".fpick-q").forEach(function (b) {
        b.classList.toggle("hidden",
          !!term && b.getAttribute("data-search").indexOf(term) === -1);
      });
    });
    holder.querySelectorAll(".fpick-q").forEach(function (b) {
      b.addEventListener("click", function () {
        var code = b.getAttribute("data-code");
        if (asBanner) pickBannerMode(code, holder);
        else pickValues(code, holder);
      });
    });
    holder.querySelector("#fpick-search").focus();
  }

  /** Custom banner step 2: summary groupings (NETs) or detail categories.
   *  Groupings give analyst-friendly headers (Promoter/Passive/Detractor
   *  instead of 0–10) and are the default when they exist. */
  function pickBannerMode(code, holder) {
    var q = TR.d2.questionByCode(code);
    var netLabels = Object.keys(q.net_members || {}).map(function (k) {
      return q.rows[parseInt(k, 10)].label;
    });
    // hidden-scale questions (NPS / satisfaction with only boxes shown)
    // decompose into box groupings, not shown category rows
    if (!netLabels.length) {
      netLabels = TR.d2.boxRows(q).map(function (br) { return br.label; });
    }
    var catCount = TR.d2.catRows(q).length;
    if (!netLabels.length && !catCount) {
      TR.shell.toast("This question can't be used as a banner");
      holder.hidden = true;
      return;
    }
    // only one mode is meaningful — apply it without the extra choice
    if (!netLabels.length) { applyCustomBanner(code, "cat", holder); return; }
    if (!catCount) { applyCustomBanner(code, "net", holder); return; }
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">' +
      fmt.escapeHtml(q.code + " — column headers") +
      '<button data-close aria-label="Close">✕</button></div>' +
      '<button class="fpick-q" data-mode="net"><strong>Summary groupings (recommended)</strong> — ' +
      fmt.escapeHtml(TR.charts.clip(netLabels.join(" / "), 80)) + "</button>" +
      '<button class="fpick-q" data-mode="cat"><strong>Detail categories</strong> — all ' +
      catCount + " values as separate columns</button></div>";
    holder.querySelector("[data-close]").addEventListener("click", function () {
      holder.hidden = true;
    });
    holder.querySelectorAll("[data-mode]").forEach(function (b) {
      b.addEventListener("click", function () {
        applyCustomBanner(code, b.getAttribute("data-mode"), holder);
      });
    });
  }

  function applyCustomBanner(code, mode, holder) {
    var id = "custom:" + code + ":" + mode;
    TR.d2.state.banner = id;
    // Remember it as the live custom banner so switching to another banner does
    // not lose it — it stays available as a tab until replaced or ★ saved.
    if (!TR.savedBanners.has(id)) TR.d2.state.customBanner = id;
    holder.hidden = true;
    TR.shell.route();
    TR.shell.toast("Custom banner applied — kept as a tab · ★ save to keep it for good");
  }

  /**
   * Value picker. Offers category rows, decomposable NET rows (applied by
   * expanding to their member categories) AND box groupings for hidden-scale
   * questions (applied by matching per-respondent box membership) — so an
   * analyst can filter by "Top-2 box", "Promoter" or "Very Satisfied" alike.
   */
  function pickValues(code, holder) {
    var q = TR.d2.questionByCode(code);
    var options = TR.d2.catRows(q).map(function (cat) {
      return { value: "c" + cat.index, label: cat.label, net: false };
    });
    q.rows.forEach(function (r, ri) {
      if (r.kind === "net" && q.net_members && q.net_members[String(ri)]) {
        options.push({ value: "n" + ri, label: r.label, net: true });
      }
    });
    // hidden-scale groupings filter on box membership (no shown categories)
    TR.d2.boxRows(q).forEach(function (br) {
      options.push({ value: "b" + br.index, label: br.label, net: true });
    });
    var body = options.length
      ? '<div class="fpick-vals">' + options.map(function (opt) {
        return '<label class="fval"><input type="checkbox" value="' + opt.value +
          '"> ' + fmt.escapeHtml(opt.label) +
          (opt.net ? ' <span class="kindtag">net</span>' : "") + "</label>";
      }).join("") + "</div>" +
        '<button class="primary wide" data-apply>Apply filter</button>'
      : '<p class="fpick-empty">No filterable values — this is a derived or ' +
        "ranking metric.</p>";
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">' +
      fmt.escapeHtml(q.code + " — " + TR.charts.clip(q.title, 70)) +
      '<button data-close aria-label="Close">✕</button></div>' + body + "</div>";
    holder.querySelector("[data-close]").addEventListener("click", function () {
      holder.hidden = true;
    });
    var applyBtn = holder.querySelector("[data-apply]");
    if (applyBtn) applyBtn.addEventListener("click", function () {
      var rows = {}, box = false;
      Array.prototype.forEach.call(holder.querySelectorAll("input:checked"),
        function (el) {
          var v = el.value;
          if (v.charAt(0) === "c") {
            rows[parseInt(v.slice(1), 10)] = true;
          } else if (v.charAt(0) === "b") {
            box = true;
            rows[parseInt(v.slice(1), 10)] = true;
          } else {
            (q.net_members[v.slice(1)] || []).forEach(function (ri) {
              rows[ri] = true;
            });
          }
        });
      var rowList = Object.keys(rows).map(Number);
      if (!rowList.length) { TR.shell.toast("Pick at least one value"); return; }
      var filter = { q: code, rows: rowList };
      if (box) filter.box = true;
      TR.d2.state.filters.push(filter);
      holder.hidden = true;
      filterBar.render();
      TR.shell.route();
      TR.shell.toast("Filter applied — every view recomputed");
    });
  }

  filterBar.openCustomBanner = function () { openPicker(true); };

  /* ---------------- composite (profile) banner builder ---------------- */

  // In-progress columns + name while the builder is open. A composite is a
  // hand-picked set of spotlight groups (each from any question) shown as columns
  // across EVERY table and tested vs the rest — see 28c_composite.js.
  var compositeDraft = [], compositeName = "";

  /** Spotlight-group options for a question: detail categories, decomposable NET
   *  groupings (expanded to member rows) and hidden-scale box groupings — the
   *  same value set the audience filter offers, each ready to become one column.
   *  Each option already carries {rows, box?} so columnsFor rebuilds membership. */
  function groupOptionsFor(q) {
    var opts = [];
    TR.d2.catRows(q).forEach(function (cat) {
      opts.push({ label: cat.label, rows: [cat.index] });
    });
    q.rows.forEach(function (r, ri) {
      if (r.kind === "net" && q.net_members && q.net_members[String(ri)]) {
        opts.push({ label: r.label, rows: q.net_members[String(ri)].slice(), net: true });
      }
    });
    TR.d2.boxRows(q).forEach(function (br) {
      opts.push({ label: br.label, rows: [br.index], box: br.index, net: true });
    });
    return opts;
  }

  filterBar.openCompositeBuilder = function () {
    compositeDraft = [];
    compositeName = "";
    renderCompositeBuilder();
  };

  function renderCompositeBuilder() {
    var holder = document.getElementById("fpicker");
    if (!holder) return;
    holder.hidden = false;
    var cols = compositeDraft.map(function (c, i) {
      return '<li class="cb-col"><span>' + fmt.escapeHtml(c.label) +
        ' <em>' + fmt.escapeHtml(c.code) + "</em></span>" +
        '<button data-cbdel="' + i + '" aria-label="Remove column">✕</button></li>';
    }).join("");
    holder.innerHTML = '<div class="fpick cb"><div class="fpick-head">' +
      "Build a composite banner" +
      '<button data-close aria-label="Close">✕</button></div>' +
      '<p class="cb-help">Add the groups you want as columns — each can come from a ' +
      "different question (e.g. Marketing, Admin, Cape Town, Tenure 5y+). Total is " +
      "always the first column, and every group is tested against the rest of the " +
      "sample, so columns may overlap.</p>" +
      '<ol class="cb-cols"><li class="cb-col total">Total</li>' + cols + "</ol>" +
      '<button class="cb-add" data-cbadd>+ Add a group</button>' +
      '<div class="cb-save"><input type="text" id="cb-name" maxlength="60" ' +
      'placeholder="Name this banner…" value="' + fmt.escapeHtml(compositeName) + '">' +
      '<button class="primary" data-cbsave' + (compositeDraft.length ? "" : " disabled") +
      ">Save &amp; apply</button></div></div>";
    holder.querySelector("[data-close]").addEventListener("click", function () {
      holder.hidden = true;
    });
    var nameInput = holder.querySelector("#cb-name");
    if (nameInput) nameInput.addEventListener("input", function () {
      compositeName = nameInput.value;
    });
    holder.querySelectorAll("[data-cbdel]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        compositeDraft.splice(parseInt(btn.getAttribute("data-cbdel"), 10), 1);
        renderCompositeBuilder();
      });
    });
    holder.querySelector("[data-cbadd]").addEventListener("click", function () {
      pickCompositeQuestion(holder);
    });
    var saveBtn = holder.querySelector("[data-cbsave]");
    if (saveBtn) saveBtn.addEventListener("click", function () {
      var name = (compositeName || "").trim();
      if (!compositeDraft.length) { TR.shell.toast("Add at least one group"); return; }
      if (!name) { TR.shell.toast("Name the composite banner first"); return; }
      var id = TR.compositeBanners.add({ name: name,
        columns: compositeDraft.map(function (c) {
          var col = { code: c.code, label: c.label, rows: c.rows };
          if (c.box != null) col.box = c.box;
          return col;
        }) });
      if (!id) { TR.shell.toast("Could not save — add at least one group"); return; }
      TR.d2.state.banner = id;
      holder.hidden = true;
      TR.shell.route();
      TR.shell.toast("Composite banner applied — saved across reloads and in saved copies");
    });
  }

  /** Step 2a: pick which question the next column comes from (reuses the
   *  searchable question list); "Back" returns to the builder. */
  function pickCompositeQuestion(holder) {
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">' +
      "Add a group — pick a question" +
      '<button data-cbback aria-label="Back">‹ Back</button></div>' +
      '<input type="search" id="fpick-search" placeholder="Search questions…">' +
      '<div class="fpick-list">' + TR.AGG.questions.map(function (q) {
        return '<button class="fpick-q" data-code="' + q.code + '" data-search="' +
          fmt.escapeHtml((q.code + " " + q.title).toLowerCase()) + '">' +
          '<span class="qc">' + q.code + "</span> " + fmt.escapeHtml(q.title) +
          "</button>";
      }).join("") + "</div></div>";
    holder.querySelector("[data-cbback]").addEventListener("click", function () {
      renderCompositeBuilder();
    });
    holder.querySelector("#fpick-search").addEventListener("input", function (e) {
      var term = e.target.value.trim().toLowerCase();
      holder.querySelectorAll(".fpick-q").forEach(function (b) {
        b.classList.toggle("hidden",
          !!term && b.getAttribute("data-search").indexOf(term) === -1);
      });
    });
    holder.querySelectorAll(".fpick-q").forEach(function (b) {
      b.addEventListener("click", function () {
        pickCompositeValue(b.getAttribute("data-code"), holder);
      });
    });
    holder.querySelector("#fpick-search").focus();
  }

  /** Step 2b: pick ONE group from the chosen question to become a column. */
  function pickCompositeValue(code, holder) {
    var q = TR.d2.questionByCode(code);
    var options = groupOptionsFor(q);
    if (!options.length) {
      TR.shell.toast("This question has no groups to use as a column");
      pickCompositeQuestion(holder);
      return;
    }
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">' +
      fmt.escapeHtml(q.code + " — pick one group") +
      '<button data-cbback aria-label="Back">‹ Back</button></div>' +
      '<div class="fpick-vals">' + options.map(function (opt, i) {
        return '<button class="fval pick" data-opt="' + i + '">' +
          fmt.escapeHtml(opt.label) +
          (opt.net ? ' <span class="kindtag">group</span>' : "") + "</button>";
      }).join("") + "</div></div>";
    holder.querySelector("[data-cbback]").addEventListener("click", function () {
      pickCompositeQuestion(holder);
    });
    holder.querySelectorAll("[data-opt]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var opt = options[parseInt(btn.getAttribute("data-opt"), 10)];
        var col = { code: code, label: opt.label, rows: opt.rows };
        if (opt.box != null) col.box = opt.box;
        compositeDraft.push(col);
        renderCompositeBuilder();
      });
    });
  }

})(typeof window !== "undefined" ? window : globalThis);
