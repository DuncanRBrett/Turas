/* Turas Reader report — island-driven renderer. Reads #data-reader and builds
   the narrative into #rr-app. Two reading layers (Plain / Practitioner), a
   priority-matrix map, and every figure deep-links into the sibling crosstab
   (model.crosstab) via #tab=…&q=…&banner=…, decoded live on hashchange. No
   external requests; no computation — display only. */
(function () {
  "use strict";
  var app = document.getElementById("rr-app");
  var M;
  try { M = JSON.parse(document.getElementById("data-reader").textContent); }
  catch (e) { app.textContent = "Reader report: data island could not be parsed."; return; }
  if (!M || typeof M !== "object") { app.textContent = "Reader report: no data."; return; }

  var proj = M.project || {};
  var num = function (x) { return (x === null || x === undefined || x === "" || isNaN(x)) ? null : Number(x); };
  var fmt2 = function (x) { var n = num(x); return n === null ? "" : n.toFixed(2); };
  var esc = function (s) {
    return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  };

  /* ---- deep-link helper ---- */
  function xtHref(q, tab, banner) {
    if (!M.crosstab) return null;
    var parts = ["tab=" + (tab || "crosstabs")];
    if (q) parts.push("q=" + q);
    if (banner) parts.push("banner=" + banner);
    return M.crosstab + "#" + parts.join("&");
  }
  document.addEventListener("click", function (e) {
    if (e.target.closest(".term")) return;          // glossary terms handle themselves
    var t = e.target.closest("[data-q]");
    if (!t) return;
    var href = xtHref(t.getAttribute("data-q"), t.getAttribute("data-tab"), t.getAttribute("data-banner"));
    if (href) window.open(href, "turas_xtab");
  });

  /* ---- practitioner panel for a section key ---- */
  function prac(key) {
    var p = (M.practitioner || []).filter(function (x) { return x.after === key; });
    if (!p.length) return "";
    return p.map(function (x) {
      return '<div class="wrap"><details class="xp"><summary>' + esc(x.title) +
        '</summary><div class="xp-body"><p>' + esc(x.body) + "</p></div></details></div>";
    }).join("");
  }

  var out = [];
  function push(s) { out.push(s); }
  function section(label, h2, inner, key) {
    return '<hr class="sep"><section' + (key ? ' data-key="' + key + '"' : "") + '><div class="wrap">' +
      (label ? '<div class="sec-label">' + esc(label) + "</div>" : "") +
      (h2 ? "<h2>" + esc(h2) + "</h2>" : "") + inner + "</div></section>" + (key ? prac(key) : "");
  }

  /* ---- top bar (reading depth) ---- */
  var aiBadge = (M.disclosure && M.disclosure.mode === "ai")
    ? '<span class="ai-badge" title="' + esc(M.disclosure.text || "") + '">AI-drafted · analyst-reviewed</span>' : "";
  push('<div class="topbar"><div class="topbar-inner">' +
    '<span class="brand">' + esc(proj.client || "") + (proj.wave ? " · " + esc(proj.wave) : "") + "</span>" + aiBadge +
    '<div class="mode"><div class="mode-switch" role="group" aria-label="Reading depth">' +
    '<button id="rr-plain" class="on" type="button">Plain reading</button>' +
    '<button id="rr-xp" type="button">Practitioner</button></div></div></div></div>');

  /* ---- AI-degraded banner (§3.7): AI prose was requested but the pipeline
     fell back to the on-device narrative. Show it so a degraded run is never
     mistaken for an AI draft. ---- */
  if (M.disclosure && M.disclosure.requested_mode === "ai" && M.disclosure.mode !== "ai") {
    var reason = M.disclosure.fallback_reason ? " (" + esc(M.disclosure.fallback_reason) + ")" : "";
    push('<div class="rr-degraded" role="status">' +
      "<b>AI narrative was requested but unavailable" + reason +
      "</b> — showing the on-device narrative. Every figure is still computed by Turas from the survey data.</div>");
  }

  /* ---- hero ---- */
  var metaBits = [];
  if (proj.sampling_method) metaBits.push("<span>" + esc(proj.sampling_method) + "</span>");
  if (M.trend && M.trend.available && M.trend.refYear)
    metaBits.push("<span>Tracked against <b>" + esc(M.trend.refYear) + "</b></span>");
  push('<div class="hero"><div class="wrap">' +
    '<div class="kicker">Reader report' + (proj.wave ? " · " + esc(proj.wave) : "") + '</div>' +
    "<h1>" + esc(M.prose && M.prose.title || proj.name) + "</h1>" +
    (M.prose && M.prose.subtitle ? '<p class="sub">' + esc(M.prose.subtitle) + "</p>" : "") +
    (metaBits.length ? '<div class="meta">' + metaBits.join("") + "</div>" : "") +
    '<div class="pledge"><b>Every number wears its base.</b> A solid underline means the ' +
    '<button class="term" data-t="Base (n)">base</button> is sound; a dotted one means the group is ' +
    '<button class="term" data-t="Directional">directional</button> — a lead to weigh, not proof. ' +
    "Figures marked ↗ open the matching table in the crosstab; dotted words carry a definition.</div>" +
    "</div></div>");

  /* ---- argument ---- */
  if (M.prose && M.prose.claims && M.prose.claims.length) {
    var claims = M.prose.claims.map(function (c) {
      return '<p class="claim"><b>' + esc(c.lead) + "</b> " + esc(c.body) + "</p>";
    }).join("");
    push(section("The argument", "What the data says", claims));
  }

  /* ---- headline cards ---- */
  if (M.headline && M.headline.length) {
    var cards = M.headline.map(function (h) {
      var mx = num(h.scaleMax) || 5, v = num(h.value);
      var pct = v === null ? 0 : Math.max(0, Math.min(100, v / mx * 100));
      var foot = [];
      if (h.base != null) foot.push("n=" + h.base);
      if (h.netPositive != null) foot.push("NET +" + h.netPositive);
      var d = num(h.delta);
      var deltaHtml = d === null ? "<span></span>" :
        '<span class="d delta ' + (d < 0 ? "dn" : (d > 0 ? "up" : "flat")) + '">' + (d > 0 ? "+" : "") + fmt2(d) + "</span>";
      var q = esc(h.q || "");
      return '<div class="scard' + (q ? " xt" : "") + '"' +
        (q ? ' data-q="' + q + '" data-tab="' + esc(h.tab || "crosstabs") + '" data-banner="' + esc(h.banner || "") + '"' : "") + ">" +
        '<div class="lab">' + esc(h.label) + "</div>" +
        '<div class="val">' + fmt2(h.value) + "<small>/" + esc(mx) + "</small></div>" +
        '<div class="bar"><i style="width:' + pct.toFixed(1) + '%"></i></div>' +
        '<div class="foot"><span>' + esc(foot.join(" · ")) + "</span>" + deltaHtml + "</div></div>";
    }).join("");
    push('<hr class="sep"><section data-key="standing"><div class="wrap"><div class="sec-label">Where it stands</div>' +
      "<h2>The headline numbers</h2></div>" +
      '<div class="wrap-wide"><div class="scores">' + cards + "</div></div></section>" + prac("standing"));
  }

  /* ---- trend delta chart ---- */
  var withDelta = (M.items || []).filter(function (x) { return num(x.delta) !== null; });
  if (M.trend && M.trend.available && withDelta.length) {
    var rows = withDelta.slice().sort(function (a, b) { return a.delta - b.delta; });
    var maxAbs = Math.max.apply(null, rows.map(function (r) { return Math.abs(r.delta); }).concat([0.1]));
    var body = rows.map(function (it) {
      var d = num(it.delta);
      var cls = d <= -0.30 ? "" : (d <= -0.12 ? "mild" : "flat");
      var w = Math.max(2, Math.abs(d) / maxAbs * 100);
      return '<div class="drow dclick" data-q="' + esc(it.code) + '" data-tab="tracking">' +
        '<div class="dl">' + esc(it.short) + "<small>" + esc(it.code) + " · now " + fmt2(it.value) + "</small></div>" +
        '<div class="dtrack"><div class="zero"></div><div class="dbar ' + cls + '" style="width:' + w.toFixed(1) + '%"></div></div>' +
        '<div class="dv ' + cls + '">' + (d > 0 ? "+" : "") + fmt2(d) + "</div></div>";
    }).join("");
    push('<hr class="sep"><section><div class="wrap"><div class="sec-label">The trend</div>' +
      "<h2>Movement since " + esc(M.trend.refYear) + "</h2></div>" +
      '<div class="wrap-wide"><div class="dchart">' + body + "</div>" +
      '<p class="dcap wrap">Change in index per item, bars from a zero line at the right. Each row opens its trend in the crosstab.</p></div></section>');

    /* ---- priority-matrix map (score x change) ---- */
    push('<div class="wrap-wide"><div class="mapbox">' + buildMap(withDelta) + "</div>" +
      '<div class="wrap"><p class="dcap">Every point is a link: click one to open its table. ' +
      "Bottom-left — low and falling — is where attention is owed.</p></div></div>");
  }

  function buildMap(items) {
    var vals = items.map(function (i) { return num(i.value); }).filter(function (x) { return x !== null; });
    var dels = items.map(function (i) { return num(i.delta); });
    var xmin = Math.min.apply(null, vals) - 0.15, xmax = Math.max.apply(null, vals) + 0.15;
    var ymin = Math.min.apply(null, dels) - 0.05, ymax = Math.max.apply(null, dels.concat([0])) + 0.03;
    var W = 900, H = 460, X0 = 70, X1 = 780, Y0 = 30, Y1 = 400;
    var px = function (v) { return X0 + (v - xmin) / (xmax - xmin) * (X1 - X0); };
    var py = function (v) { return Y0 + (ymax - v) / (ymax - ymin) * (Y1 - Y0); };
    var xref = vals.reduce(function (a, b) { return a + b; }, 0) / vals.length;
    var sorted = dels.slice().sort(function (a, b) { return a - b; });
    var yref = sorted[Math.floor(sorted.length / 2)];
    var s = '<svg viewBox="0 0 ' + W + " " + H + '" role="img" aria-label="Items by score against change">';
    s += '<rect x="' + X0 + '" y="' + Y0 + '" width="' + (X1 - X0) + '" height="' + (Y1 - Y0) + '" fill="#FBFBF6" stroke="#D3D8CE"/>';
    s += '<line x1="' + px(xref) + '" y1="' + Y0 + '" x2="' + px(xref) + '" y2="' + Y1 + '" stroke="#C9CCC2" stroke-dasharray="4 4"/>';
    s += '<line x1="' + X0 + '" y1="' + py(yref) + '" x2="' + X1 + '" y2="' + py(yref) + '" stroke="#C9CCC2" stroke-dasharray="4 4"/>';
    var F = "-apple-system,Segoe UI,sans-serif";
    s += lab(X0 + 8, Y1 - 10, "#B0472F", "low & falling", "start");
    s += lab(X1 - 8, Y0 + 18, "#0A5236", "high & steady", "end");
    s += '<text x="' + ((X0 + X1) / 2) + '" y="' + (Y1 + 40) + '" font-family="' + F + '" font-size="12.5" fill="#4C5A55" text-anchor="middle">score  →</text>';
    s += '<text x="24" y="' + ((Y0 + Y1) / 2) + '" font-family="' + F + '" font-size="12.5" fill="#4C5A55" text-anchor="middle" transform="rotate(-90 24 ' + ((Y0 + Y1) / 2) + ')">change  →</text>';
    items.forEach(function (it) {
      var v = num(it.value), d = num(it.delta);
      if (v === null || d === null) return;
      var color = (v < xref && d < yref) ? "#B0472F" : (d < yref ? "#D9A24A" : "var(--brand)");
      var cx = px(v), cy = py(d), anchor = cx > X1 - 150 ? "end" : "start", lx = anchor === "end" ? cx - 10 : cx + 10;
      s += '<g class="map-dot" data-q="' + esc(it.code) + '" data-tab="crosstabs" tabindex="0" role="button" aria-label="' + esc(it.short) + '">' +
        '<circle class="core" cx="' + cx + '" cy="' + cy + '" r="6.5" fill="' + color + '"/>' +
        '<text x="' + lx + '" y="' + (cy + 3.5) + '" font-family="' + F + '" font-size="11" fill="#182220" text-anchor="' + anchor + '">' + esc(it.short) + "</text></g>";
    });
    return s + "</svg>";
    function lab(x, y, c, t, a) { return '<text x="' + x + '" y="' + y + '" font-family="' + F + '" font-size="12" fill="' + c + '" font-style="italic" text-anchor="' + a + '">' + t + "</text>"; }
  }

  /* ---- held / slipped ---- */
  if (M.splitHeld && M.splitHeld.length && M.splitSlipped && M.splitSlipped.length) {
    var colHS = function (arr) {
      return arr.map(function (it) {
        var d = num(it.delta);
        return '<div class="itemline"><span>' + esc(it.short) + '</span><span class="n"><b>' +
          fmt2(it.value) + "</b> " + (d !== null ? (d > 0 ? "+" : "") + fmt2(d) : "") + "</span></div>";
      }).join("");
    };
    push(section("What held, what slipped", "Where the movement is",
      '<div class="split2">' +
      '<div class="colbox hold"><h4>Held firm</h4><div class="ct">Least change</div>' + colHS(M.splitHeld) + "</div>" +
      '<div class="colbox slip"><h4>Slipped</h4><div class="ct">Biggest falls</div>' + colHS(M.splitSlipped) + "</div></div>"));
  }

  /* ---- values split ---- */
  if (M.values && M.values.available) {
    var vcol = function (arr) {
      return arr.map(function (v) {
        return '<div class="itemline"><span>' + esc(v.label) + '</span><span class="n"><b>' + fmt2(v.value) + "</b></span></div>";
      }).join("");
    };
    push(section("The values read", "Lived most and least",
      '<div class="split2">' +
      '<div class="colbox hold"><h4>Lives most</h4><div class="ct">Above the ' + fmt2(M.values.avg) + " average</div>" + vcol(M.values.livesMost) + "</div>" +
      '<div class="colbox slip"><h4>Lives least</h4><div class="ct">Below the average</div>' + vcol(M.values.livesLeast) + "</div></div>"));
  }

  /* ---- people (sub-group directional read) ---- */
  if (M.people && M.people.available) {
    var lo = M.people.lowest, an = M.people.anchor;
    var figs = (lo.metrics || []).map(function (m) {
      return '<span class="fig' + (lo.low ? " dir" : "") + '">' + fmt2(m.value) +
        '<span class="pv">' + esc(m.name.length > 22 ? m.name.slice(0, 21) + "…" : m.name) + "</span></span>";
    }).join(" · ");
    var body = "<p>Within " + esc(M.people.groupName) + ", <b>" + esc(lo.label) + "</b> sits lowest across the headline measures — " +
      figs + (lo.low ? ' <span class="fig dir">n=' + esc(lo.base) + "</span>" : " (n=" + esc(lo.base) + ")") +
      " — against <b>" + esc(an.label) + "</b> at " + fmt2(an.avg) + " (n=" + esc(an.base) + "). " +
      "The bases are small, so read the consistency, not any single figure.</p>";
    push(section("The people", "A soft spot, held at arm's length", body, "people"));
  }

  /* ---- verdict + leverage ---- */
  if (M.verdict) {
    var lev = (M.verdict.leverage || []).map(function (l) {
      return '<div class="lever"><div class="ln">' + esc(l.n) + '</div><div><p><b>' + esc(l.lead) + "</b> " + esc(l.body) + "</p></div></div>";
    }).join("");
    push('<hr class="sep"><section><div class="wrap"><div class="sec-label">Point of view</div>' +
      "<h2>The read, and where to push</h2>" +
      '<div class="verdict"><h3>' + esc(M.verdict.lead) + "</h3><p>" + esc(M.verdict.body) + "</p></div>" +
      (lev ? "<h3>The leverage, ranked</h3>" + lev : "") + "</div></section>");
  }

  /* ---- honest limits ---- */
  if (M.prose && M.prose.limits && M.prose.limits.length) {
    var lis = M.prose.limits.map(function (l) {
      return '<div class="li"><b>' + esc(l.lead) + "</b><p>" + esc(l.body) + "</p></div>";
    }).join("");
    push(section("Honest limits", "What this survey cannot tell you", '<div class="limit">' + lis + "</div>"));
  }

  /* ---- low-base register ---- */
  if (M.register && M.register.length) {
    var trs = M.register.map(function (r, i) {
      return "<tr><td class=\"n\">◇" + String(i + 1).padStart(2, "0") + "</td><td>" +
        esc(r.figure) + "</td><td>" + esc(r.base) + "</td><td>" + esc(r.section) + "</td></tr>";
    }).join("");
    push(section("Low-base register", "Every small-base figure, in one place",
      '<div class="tblwrap"><table class="reg"><tr><th>#</th><th>Figure</th><th>Base</th><th>Section</th></tr>' + trs + "</table></div>"));
  }

  /* ---- glossary ---- */
  if (M.glossary && M.glossary.length) {
    var gl = M.glossary.map(function (g) {
      return '<div class="gitem"><b>' + esc(g.term) + '</b><div class="plain">' + esc(g.plain) +
        '</div><div class="tech"><b>Technical</b> · ' + esc(g.tech) + "</div></div>";
    }).join("");
    push(section("The vocabulary", "Plain and technical", '<div class="gloss">' + gl + "</div>"));
  }

  /* ---- disclosure footer ---- */
  var disc = M.disclosure || {};
  var gen = app.getAttribute("data-generated") || "";
  push("<footer><div class=\"wrap\">" +
    '<div class="disc"><b>' + (disc.mode === "ai" ? "How this was written." : "How this was made.") + "</b> " +
    esc(disc.text || "") + (disc.model ? " Prose drafted by " + esc(disc.model) + "." : "") + "</div>" +
    '<div class="gen">The Research LampPost · Turas Reader report' + (gen ? " · generated " + esc(gen) : "") + "</div></div></footer>");

  app.innerHTML = out.join("\n");

  /* ---- reading-depth toggle ---- */
  var bp = document.getElementById("rr-plain"), bx = document.getElementById("rr-xp");
  function setMode(xp) {
    document.body.classList.toggle("practitioner", xp);
    bp.classList.toggle("on", !xp); bx.classList.toggle("on", xp);
    document.querySelectorAll("details.xp").forEach(function (d) { d.open = xp; });
  }
  bp.addEventListener("click", function () { setMode(false); });
  bx.addEventListener("click", function () { setMode(true); });

  /* ---- glossary popover ---- */
  var pop = document.createElement("div"); pop.id = "rr-pop"; document.body.appendChild(pop);
  var byTerm = {}; (M.glossary || []).forEach(function (g) { byTerm[g.term] = g; });
  document.addEventListener("click", function (e) {
    var t = e.target.closest(".term");
    if (!t) { if (!e.target.closest("#rr-pop")) pop.style.display = "none"; return; }
    var g = byTerm[t.getAttribute("data-t")]; if (!g) return;
    pop.innerHTML = '<div class="pt">' + esc(g.term) + '</div><div class="pl">' + esc(g.plain) +
      '</div><div class="pt2"><b>Technical:</b> ' + esc(g.tech) + "</div>";
    pop.style.display = "block";
    var r = t.getBoundingClientRect(), pw = Math.min(340, window.innerWidth - 28);
    pop.style.maxWidth = pw + "px";
    var x = r.left + window.scrollX; if (x + pw > window.scrollX + window.innerWidth - 14) x = window.scrollX + window.innerWidth - 14 - pw;
    pop.style.left = x + "px"; pop.style.top = (r.bottom + window.scrollY + 8) + "px";
  });
  window.addEventListener("keydown", function (e) { if (e.key === "Escape") pop.style.display = "none"; });
  document.querySelectorAll(".map-dot").forEach(function (g) {
    g.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); g.dispatchEvent(new MouseEvent("click", { bubbles: true })); }
    });
  });
})();
