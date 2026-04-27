/* SIZE-EXCEPTION: SVG quadrant compositor + matrix renderer + action list
   + Office-HTML exporter form a coherent rendering pipeline driven from a
   single advantage block; splitting would fragment the sequential
   composition and the shared state helpers (palette, focal lookup,
   stim/base toggles). Compares favourably to the existing brand_ma_panel.js.
   ==========================================================================
   Brand Mental Advantage sub-tab — interactivity
   ==========================================================================
   Three coordinated views driven from pd.advantage:
     - Strategic quadrant (focal brand): bubble chart, X = stim_penetration,
       Y = MA score, size = focal raw linkage %, colour = decision quadrant.
     - Diverging-palette matrix (all brands): MA score per cell, threshold
       palette, optional significance dot.
     - Action list (focal brand): Defend / Build / Maintain cards.
   Controls: stim toggle (CEPs/Attributes), base toggle (% total / % aware
   for bubble size), show-significance, show-counts. Re-renders on focal
   change via the existing turas:brand-focal-change event.
   ========================================================================== */

(function () {
  if (window.__BRAND_MA_ADVANTAGE_INIT__) return;
  window.__BRAND_MA_ADVANTAGE_INIT__ = true;

  // Diverging palette anchors. Threshold-aware colour interpolation.
  var COL_DEFEND  = [5, 150, 105];
  var COL_NEUTRAL = [241, 245, 249];
  var COL_BUILD   = [220, 38, 38];

  function lerp(a, b, t) { return Math.round(a + (b - a) * t); }
  function rgb(c) { return 'rgb(' + c[0] + ',' + c[1] + ',' + c[2] + ')'; }

  function maColour(score, threshold) {
    if (score == null || isNaN(score)) return '#f1f5f9';
    var s = Math.max(-2 * threshold, Math.min(2 * threshold, score));
    var t = s / (2 * threshold);
    if (t >= 0)
      return rgb([lerp(COL_NEUTRAL[0], COL_DEFEND[0], t),
                  lerp(COL_NEUTRAL[1], COL_DEFEND[1], t),
                  lerp(COL_NEUTRAL[2], COL_DEFEND[2], t)]);
    return rgb([lerp(COL_NEUTRAL[0], COL_BUILD[0], -t),
                lerp(COL_NEUTRAL[1], COL_BUILD[1], -t),
                lerp(COL_NEUTRAL[2], COL_BUILD[2], -t)]);
  }

  function escAttr(s) {
    if (s == null) return '';
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;')
      .replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
  function escHtml(s) { return escAttr(s); }
  function fmtScore(v) { if (v == null || isNaN(v)) return '–'; return (v >= 0 ? '+' : '') + v.toFixed(1); }

  // ------------------------------------------------------------ state
  function getAdvState(panel) {
    if (!panel.__maAdvState) panel.__maAdvState = {};
    return panel.__maAdvState;
  }
  function getActiveStim(panel) {
    var pd = panel.__maData; if (!pd || !pd.advantage) return null;
    var st = getAdvState(panel);
    return st.stim || pd.advantage.default_stim || pd.advantage.available_stims[0];
  }
  function getActiveBase(panel) {
    var st = getAdvState(panel); return st.base || 'total';
  }

  function getStimBlock(panel) {
    var pd = panel.__maData; if (!pd || !pd.advantage) return null;
    return pd.advantage[getActiveStim(panel)];
  }

  // ------------------------------------------------------------ render orchestrator
  function renderAdvantage(panel) {
    var block = getStimBlock(panel); if (!block) return;
    renderQuadrant(panel, block);
    renderMatrix(panel, block);
    renderActionList(panel, block);
  }

  // ============================================================ QUADRANT
  // SIZE-EXCEPTION: SVG composition is a sequential pipeline (scales,
  // background zones, gridlines, threshold lines, axes, bubbles) that
  // shares closure-scoped scaling functions; decomposing fragments the
  // visual flow and forces redundant coordinate plumbing.
  function renderQuadrant(panel, block) {
    var svg = panel.querySelector('svg.ma-adv-quadrant-svg');
    if (!svg) return;
    var pd = panel.__maData;
    var focal = (panel.__maState && panel.__maState.focal) || block.focal_brand_code;
    var threshold = pd.advantage.threshold_pp || 5;
    var base = getActiveBase(panel);

    var pts = block.cells.filter(function (c) { return c.brand_code === focal; })
      .map(function (c) {
        var pen = block.stim_penetration[block.codes.indexOf(c.stim_code)];
        var sizeSrc = (base === 'aware' && c.pct_aware != null) ? c.pct_aware : c.pct_total;
        return { code: c.stim_code, ma: c.ma, pen: pen, size: sizeSrc != null ? sizeSrc : 0,
                 decision: c.decision, isSig: c.is_sig,
                 label: block.labels[block.codes.indexOf(c.stim_code)] };
      });
    if (pts.length === 0) { svg.innerHTML = ''; return; }

    var width = svg.clientWidth || 600;
    var height = 420;
    var mL = 56, mR = 28, mT = 28, mB = 48;
    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
    svg.setAttribute('height', height);

    var pW = width - mL - mR, pH = height - mT - mB;
    var xMax = Math.max(10, Math.ceil(Math.max.apply(null, pts.map(function (p) { return p.pen; })) / 10) * 10);
    var maAbsMax = Math.max(threshold * 2,
                              Math.ceil(Math.max.apply(null, pts.map(function (p) { return Math.abs(p.ma); }))));
    var sizeMax = Math.max(1, Math.max.apply(null, pts.map(function (p) { return p.size; })));

    function toX(v) { return mL + pW * v / xMax; }
    function toY(v) { return mT + pH * (1 - (v + maAbsMax) / (2 * maAbsMax)); }
    function bR(s)  { return Math.max(6, Math.min(22, 6 + 16 * s / sizeMax)); }

    var parts = [];
    parts.push('<rect class="ma-adv-q-bg" x="' + mL + '" y="' + mT + '" width="' + pW + '" height="' + pH + '"/>');
    var yZero = toY(0), yPos = toY(threshold), yNeg = toY(-threshold);
    parts.push('<rect class="ma-adv-q-zone-defend" x="' + mL + '" y="' + mT + '" width="' + pW + '" height="' + (yPos - mT) + '"/>');
    parts.push('<rect class="ma-adv-q-zone-build"  x="' + mL + '" y="' + yNeg + '" width="' + pW + '" height="' + (mT + pH - yNeg) + '"/>');

    // Grid + tick labels
    for (var xi = 0; xi <= 5; xi++) {
      var xv = xMax * xi / 5; var gx = toX(xv);
      parts.push('<line class="ma-adv-q-grid" x1="' + gx + '" y1="' + mT + '" x2="' + gx + '" y2="' + (mT + pH) + '"/>');
      parts.push('<text class="ma-adv-q-tick" x="' + gx + '" y="' + (mT + pH + 14) + '" text-anchor="middle">' + Math.round(xv) + '%</text>');
    }
    for (var yi = -2; yi <= 2; yi++) {
      var yv = (maAbsMax / 2) * yi; if (Math.abs(yv) > maAbsMax) continue;
      var gy = toY(yv);
      parts.push('<line class="ma-adv-q-grid" x1="' + mL + '" y1="' + gy + '" x2="' + (mL + pW) + '" y2="' + gy + '"/>');
      parts.push('<text class="ma-adv-q-tick" x="' + (mL - 6) + '" y="' + gy + '" text-anchor="end" dominant-baseline="middle">' + (yv >= 0 ? '+' : '') + yv.toFixed(0) + 'pp</text>');
    }

    // Zero + threshold lines
    parts.push('<line class="ma-adv-q-zero"   x1="' + mL + '" y1="' + yZero + '" x2="' + (mL + pW) + '" y2="' + yZero + '"/>');
    parts.push('<line class="ma-adv-q-thresh" x1="' + mL + '" y1="' + yPos + '" x2="' + (mL + pW) + '" y2="' + yPos + '"/>');
    parts.push('<line class="ma-adv-q-thresh" x1="' + mL + '" y1="' + yNeg + '" x2="' + (mL + pW) + '" y2="' + yNeg + '"/>');

    // Axes + labels + zone labels
    parts.push('<line class="ma-adv-q-axis" x1="' + mL + '" y1="' + mT + '" x2="' + mL + '" y2="' + (mT + pH) + '"/>');
    parts.push('<line class="ma-adv-q-axis" x1="' + mL + '" y1="' + (mT + pH) + '" x2="' + (mL + pW) + '" y2="' + (mT + pH) + '"/>');
    parts.push('<text class="ma-adv-q-axis-label" x="' + (mL + pW / 2) + '" y="' + (height - 6) + '" text-anchor="middle">Stimulus penetration (any brand, %)</text>');
    parts.push('<text class="ma-adv-q-axis-label" transform="rotate(-90 ' + (mL - 40) + ' ' + (mT + pH / 2) + ')" x="' + (mL - 40) + '" y="' + (mT + pH / 2) + '" text-anchor="middle">Mental Advantage (pp)</text>');
    parts.push('<text class="ma-adv-q-zone-label" x="' + (mL + pW - 6) + '" y="' + (mT + 14) + '" text-anchor="end">DEFEND</text>');
    parts.push('<text class="ma-adv-q-zone-label" x="' + (mL + 6) + '" y="' + (mT + 14) + '">AMPLIFY</text>');
    parts.push('<text class="ma-adv-q-zone-label" x="' + (mL + pW - 6) + '" y="' + (mT + pH - 6) + '" text-anchor="end">BUILD</text>');
    parts.push('<text class="ma-adv-q-zone-label" x="' + (mL + 6) + '" y="' + (mT + pH - 6) + '">LOW PRIORITY</text>');

    // Bubbles
    pts.forEach(function (p) {
      var cx = toX(p.pen), cy = toY(p.ma), r2 = bR(p.size);
      var cls = 'ma-adv-q-bubble ma-adv-q-bubble-' + (p.decision || 'na');
      if (p.isSig) cls += ' ma-adv-q-bubble-sig';
      parts.push('<circle class="' + cls + '" cx="' + cx + '" cy="' + cy + '" r="' + r2 + '">' +
                 '<title>' + escHtml(p.label) + '\nMA: ' + fmtScore(p.ma) + 'pp' +
                 '\nStim penetration: ' + p.pen.toFixed(1) + '%' +
                 '\nFocal raw linkage: ' + (p.size != null ? p.size.toFixed(1) + '%' : '—') +
                 (p.isSig ? '\n(significant, p<0.05)' : '') + '</title></circle>');
      var lblX = cx + r2 + 4, anchor = 'start';
      if (lblX + 60 > mL + pW) { lblX = cx - r2 - 4; anchor = 'end'; }
      parts.push('<text class="ma-adv-q-label" x="' + lblX + '" y="' + (cy + 3) + '" text-anchor="' + anchor + '">' + escHtml(p.label) + '</text>');
    });

    svg.innerHTML = parts.join('');
  }

  // ============================================================ MATRIX
  function renderMatrix(panel, block) {
    var wrap = panel.querySelector('.ma-adv-matrix-wrap');
    if (!wrap) return;
    var pd = panel.__maData;
    var focal = (panel.__maState && panel.__maState.focal) || block.focal_brand_code;
    var threshold = pd.advantage.threshold_pp || 5;

    // Brand column order: focal first, others by raw config order
    var brands = (block.brand_codes || []).slice();
    var brandNames = (pd.config && pd.config.brand_names) || [];
    var brandCodes = (pd.config && pd.config.brand_codes) || brands;
    function nameFor(code) {
      var i = brandCodes.indexOf(code); return i < 0 ? code : (brandNames[i] || code);
    }
    if (focal && brands.indexOf(focal) >= 0)
      brands = [focal].concat(brands.filter(function (b) { return b !== focal; }));

    // Sort rows by focal MA desc
    var idx = block.codes.map(function (c, i) { return i; });
    var focalCells = {};
    block.cells.forEach(function (c) {
      if (c.brand_code === focal) focalCells[c.stim_code] = c.ma;
    });
    idx.sort(function (a, b) {
      var va = focalCells[block.codes[a]]; va = va == null ? -Infinity : va;
      var vb = focalCells[block.codes[b]]; vb = vb == null ? -Infinity : vb;
      return vb - va;
    });

    // Build header
    var ths = ['<th class="ma-adv-matrix-th-stim">' + (getActiveStim(panel) === 'ceps' ? 'CEP' : 'Attribute') + '</th>'];
    brands.forEach(function (b) {
      var cls = b === focal ? 'ma-adv-matrix-th-focal' : '';
      ths.push('<th class="' + cls + '">' + escHtml(nameFor(b)) + '</th>');
    });

    // Build rows
    var cellByKey = {};
    block.cells.forEach(function (c) { cellByKey[c.stim_code + '|' + c.brand_code] = c; });

    var rows = idx.map(function (i) {
      var stim = block.codes[i], lbl = block.labels[i];
      var tds = ['<td class="ma-adv-matrix-stim" title="' + escAttr(lbl) + '">' + escHtml(lbl) + '</td>'];
      brands.forEach(function (b) {
        var c = cellByKey[stim + '|' + b];
        if (!c || c.ma == null) {
          tds.push('<td class="' + (b === focal ? 'ma-adv-matrix-focal' : '') + '">–</td>');
          return;
        }
        var bg = maColour(c.ma, threshold);
        var sigCls = c.is_sig ? ' ma-adv-sig-dot' : '';
        var focalCls = b === focal ? ' ma-adv-matrix-focal' : '';
        var counts = '<span class="ma-adv-cell-counts">a=' + Math.round(c.actual) + ' / e=' + Math.round(c.expected) + '</span>';
        var tip = lbl + ' × ' + nameFor(b) + ': MA ' + fmtScore(c.ma) + 'pp' +
                  ' (actual ' + Math.round(c.actual) + ' vs expected ' + Math.round(c.expected) + ')' +
                  (c.is_sig ? ' • significant' : '');
        tds.push('<td class="' + focalCls + sigCls + '" style="background:' + bg + ';" title="' + escAttr(tip) + '">' +
                 fmtScore(c.ma) + counts + '</td>');
      });
      return '<tr>' + tds.join('') + '</tr>';
    });

    wrap.innerHTML = '<table class="ma-adv-matrix"><thead><tr>' + ths.join('') + '</tr></thead><tbody>' + rows.join('') + '</tbody></table>';
  }

  // ============================================================ ACTION LIST
  function renderActionList(panel, block) {
    var pd = panel.__maData;
    var focal = (panel.__maState && panel.__maState.focal) || block.focal_brand_code;
    var threshold = pd.advantage.threshold_pp || 5;
    var labelOf = function (code) {
      var i = block.codes.indexOf(code); return i < 0 ? code : block.labels[i];
    };

    // Group cells by decision for the focal brand
    var groups = { defend: [], build: [], maintain: [] };
    block.cells.filter(function (c) { return c.brand_code === focal; }).forEach(function (c) {
      var d = c.ma >= threshold ? 'defend' : c.ma <= -threshold ? 'build' : 'maintain';
      groups[d].push(c);
    });
    groups.defend.sort(function (a, b) { return b.ma - a.ma; });
    groups.build.sort(function (a, b) { return a.ma - b.ma; });
    groups.maintain.sort(function (a, b) { return Math.abs(b.ma) - Math.abs(a.ma); });

    // Find leading competitor per CEP for build rows
    function leaderOn(stim) {
      var max = null;
      block.cells.forEach(function (c) {
        if (c.stim_code !== stim || c.brand_code === focal) return;
        if (!max || c.ma > max.ma) max = c;
      });
      return max;
    }

    function brandName(code) {
      var codes = (pd.config && pd.config.brand_codes) || [];
      var names = (pd.config && pd.config.brand_names) || [];
      var i = codes.indexOf(code); return i < 0 ? code : (names[i] || code);
    }

    function rowHtml(c, key) {
      var meta = '';
      if (key === 'build') {
        var lead = leaderOn(c.stim_code);
        if (lead && lead.ma > 0)
          meta = '<div class="ma-adv-action-meta">Leader: ' + escHtml(brandName(lead.brand_code)) + ' (' + fmtScore(lead.ma) + 'pp)</div>';
      }
      return '<li class="ma-adv-action-row" title="MA ' + fmtScore(c.ma) + 'pp">' +
             '<span class="ma-adv-action-label">' + escHtml(labelOf(c.stim_code)) + '</span>' +
             '<span class="ma-adv-action-score">' + fmtScore(c.ma) + 'pp' + (c.is_sig ? ' •' : '') + '</span>' +
             meta + '</li>';
    }

    ['defend', 'build', 'maintain'].forEach(function (key) {
      var ol = panel.querySelector('ol.ma-adv-action-list[data-ma-adv-list="' + key + '"]');
      var countEl = panel.querySelector('[data-ma-decision-count="' + key + '"]');
      if (countEl) countEl.textContent = String(groups[key].length);
      if (!ol) return;
      if (groups[key].length === 0) {
        ol.innerHTML = '<li class="ma-adv-action-empty">None</li>';
      } else {
        ol.innerHTML = groups[key].map(function (c) { return rowHtml(c, key); }).join('');
      }
    });
  }

  // ============================================================ EXCEL EXPORT
  // Export the focal-sorted MA matrix as an .xls (Office HTML). Captures
  // intent that doesn't fit the legacy MA exporter: MA scores in pp,
  // expected vs actual counts on hover, decision label per cell.
  // SIZE-EXCEPTION: Office HTML construction is a head-body-foot
  // template assembled inline with brand/stim ordering shared from the
  // matrix renderer; split would duplicate state-setup code.
  function exportAdvantageMatrix(panel) {
    var pd = panel.__maData; var block = getStimBlock(panel);
    if (!pd || !block) return;
    var focal = (panel.__maState && panel.__maState.focal) || block.focal_brand_code;
    var threshold = pd.advantage.threshold_pp || 5;
    var cat = (pd.meta && pd.meta.category_label) || 'category';
    var stim = getActiveStim(panel);
    var brandCodes = (pd.config && pd.config.brand_codes) || block.brand_codes;
    var brandNames = (pd.config && pd.config.brand_names) || brandCodes;
    var brands = block.brand_codes.slice();
    if (focal && brands.indexOf(focal) >= 0)
      brands = [focal].concat(brands.filter(function (b) { return b !== focal; }));
    function nameFor(code) { var i = brandCodes.indexOf(code); return i < 0 ? code : (brandNames[i] || code); }

    var idx = block.codes.map(function (c, i) { return i; });
    var focalCells = {};
    block.cells.forEach(function (c) { if (c.brand_code === focal) focalCells[c.stim_code] = c.ma; });
    idx.sort(function (a, b) {
      var va = focalCells[block.codes[a]]; va = va == null ? -Infinity : va;
      var vb = focalCells[block.codes[b]]; vb = vb == null ? -Infinity : vb;
      return vb - va;
    });
    var cellByKey = {};
    block.cells.forEach(function (c) { cellByKey[c.stim_code + '|' + c.brand_code] = c; });

    var tdStyle = 'border:1px solid #ccc;padding:4px 8px;font-family:Calibri,sans-serif;font-size:12px;';
    var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel"' +
               ' xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="UTF-8">' +
               '<style>td,th{' + tdStyle + '}th{background:#1a2744;color:#fff;font-weight:700;}' +
               '.mode{background:#e8edf5;color:#1a2744;font-style:italic;font-size:11px;}' +
               '.focal{font-weight:700;background:#eef4fb;}' +
               '.defend{background:#d1fae5;}.build{background:#fee2e2;}.maintain{background:#f1f5f9;}' +
               '</style></head><body><table>';
    html += '<tr><td class="mode" colspan="' + (brands.length + 1) + '">Mental Advantage (pp), ' +
            (stim === 'ceps' ? 'Category Entry Points' : 'Brand Attributes') +
            ' — ' + escHtml(cat) + ' (Defend ≥ +' + threshold + ', Build ≤ −' + threshold + ')</td></tr>';
    html += '<tr><th>' + (stim === 'ceps' ? 'CEP' : 'Attribute') + '</th>' +
            brands.map(function (b) { return '<th>' + escHtml(nameFor(b)) + '</th>'; }).join('') + '</tr>';
    idx.forEach(function (i) {
      var stimCode = block.codes[i], lbl = block.labels[i];
      html += '<tr><td>' + escHtml(lbl) + '</td>';
      brands.forEach(function (b) {
        var c = cellByKey[stimCode + '|' + b];
        if (!c || c.ma == null) { html += '<td>—</td>'; return; }
        var dec = c.ma >= threshold ? 'defend' : c.ma <= -threshold ? 'build' : 'maintain';
        var cls = dec + (b === focal ? ' focal' : '');
        var sigSfx = c.is_sig ? ' •' : '';
        html += '<td class="' + cls + '">' + fmtScore(c.ma) + sigSfx + '</td>';
      });
      html += '</tr>';
    });
    html += '</table></body></html>';

    var blob = new Blob([html], { type: 'application/vnd.ms-excel;charset=utf-8' });
    var url  = URL.createObjectURL(blob);
    var a    = document.createElement('a');
    a.href = url;
    a.download = 'ma_advantage_' + stim + '_' + (cat || 'category').toLowerCase().replace(/[^a-z0-9]+/g, '_') + '.xls';
    document.body.appendChild(a); a.click();
    setTimeout(function () { URL.revokeObjectURL(url); a.remove(); }, 0);
  }

  // ============================================================ EVENT BINDINGS
  function bindAdvantage(panel) {
    if (panel.__maAdvBound) return; panel.__maAdvBound = true;

    // Intercept the advantage Excel export button before the legacy
    // exportTable handler can run (legacy expects different data attrs).
    panel.querySelectorAll('.ma-export-btn[data-ma-stim="advantage"]').forEach(function (btn) {
      btn.addEventListener('click', function (ev) {
        ev.stopImmediatePropagation();
        exportAdvantageMatrix(panel);
      }, true);
    });

    panel.querySelectorAll('[data-ma-action="adv-stim"]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var stim = btn.getAttribute('data-ma-adv-stim'); if (!stim) return;
        getAdvState(panel).stim = stim;
        panel.querySelectorAll('[data-ma-action="adv-stim"]').forEach(function (b) {
          var on = b === btn;
          b.classList.toggle('sig-btn-active', on); b.setAttribute('aria-pressed', on ? 'true' : 'false');
        });
        renderAdvantage(panel);
      });
    });

    panel.querySelectorAll('[data-ma-action="adv-base"]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var base = btn.getAttribute('data-ma-adv-base'); if (!base) return;
        getAdvState(panel).base = base;
        panel.querySelectorAll('[data-ma-action="adv-base"]').forEach(function (b) {
          var on = b === btn;
          b.classList.toggle('sig-btn-active', on); b.setAttribute('aria-pressed', on ? 'true' : 'false');
        });
        var block = getStimBlock(panel); if (block) renderQuadrant(panel, block);
      });
    });

    var sigCb = panel.querySelector('input[data-ma-action="adv-show-sig"]');
    if (sigCb) sigCb.addEventListener('change', function () {
      var wrap = panel.querySelector('.ma-adv-matrix-wrap');
      if (wrap) wrap.classList.toggle('ma-adv-show-sig', sigCb.checked);
    });
    var cntCb = panel.querySelector('input[data-ma-action="adv-show-counts"]');
    if (cntCb) cntCb.addEventListener('change', function () {
      var wrap = panel.querySelector('.ma-adv-matrix-wrap');
      if (wrap) wrap.classList.toggle('ma-adv-show-counts', cntCb.checked);
    });
  }

  // ============================================================ PUBLIC API
  window.MAAdvantage = {
    init:   function (panel) {
      bindAdvantage(panel);
      // Default state: turn on the significance dots class so the CSS
      // shows them when toggled checked at boot.
      var wrap = panel.querySelector('.ma-adv-matrix-wrap');
      if (wrap) wrap.classList.add('ma-adv-show-sig');
      renderAdvantage(panel);
    },
    render: renderAdvantage
  };
})();
