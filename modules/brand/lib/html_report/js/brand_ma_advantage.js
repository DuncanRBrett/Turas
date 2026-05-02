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
  // Base is fixed: Romaniuk uses total respondents as the denominator.
  // The toggle has been removed; we keep the constant exposed for any
  // downstream callers (matrix tooltip, pin titles).
  function getActiveBase(panel) { return 'total'; }

  // Colour resolution delegated to the shared TurasColours module (brand_colours.js).
  function brandColourFor(pd, code) {
    return TurasColours.getBrandColour(pd, code);
  }

  function getStimBlock(panel) {
    var pd = panel.__maData; if (!pd || !pd.advantage) return null;
    return pd.advantage[getActiveStim(panel)];
  }

  // ------------------------------------------------------------ tooltip
  // Single shared tooltip per panel; positioned by mouse coords.
  function tooltipEl(panel) {
    return panel.querySelector('.ma-adv-tooltip');
  }
  function showTooltip(panel, html, ev) {
    var el = tooltipEl(panel); if (!el) return;
    el.innerHTML = html;
    el.removeAttribute('hidden');
    moveTooltip(el, ev);
  }
  function moveTooltip(el, ev) {
    if (!el || !ev) return;
    var pad = 12;
    el.style.left = (ev.clientX) + 'px';
    el.style.top  = (ev.clientY - pad) + 'px';
  }
  function hideTooltip(panel) {
    var el = tooltipEl(panel); if (el) el.setAttribute('hidden', '');
  }
  function decisionLabel(d) {
    return d === 'defend' ? 'Defend' : d === 'build' ? 'Build' : d === 'maintain' ? 'Maintain' : '—';
  }
  function tooltipHtml(p, base) {
    var rows = [
      ['MA',                   fmtScore(p.ma) + 'pp' + (p.isSig ? ' •' : '')],
      ['Stimulus penetration', p.pen.toFixed(1) + '%'],
      ['Linkage (' + (base === 'aware' ? '% aware' : '% total') + ')',
        p.size != null ? p.size.toFixed(1) + '%' : '—']
    ];
    var rowHtml = rows.map(function (r) {
      return '<div class="ma-adv-tooltip-row"><span class="ma-adv-tooltip-key">' +
             escHtml(r[0]) + '</span><span class="ma-adv-tooltip-val">' +
             escHtml(r[1]) + '</span></div>';
    }).join('');
    var dec = p.decision || 'maintain';
    return '<strong>' + escHtml(p.label) + '</strong>' + rowHtml +
           '<div class="ma-adv-tooltip-decision ma-adv-tooltip-' + dec + '">' +
           decisionLabel(dec) + (p.isSig ? ' • significant (p&lt;0.05)' : '') + '</div>';
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
  // background zones, gridlines, threshold + mean lines, axes, bubbles,
  // smart labels) sharing closure-scoped scaling functions; decomposing
  // would fragment the visual flow and force redundant coordinate plumbing.
  function renderQuadrant(panel, block) {
    var svg = panel.querySelector('svg.ma-adv-quadrant-svg');
    if (!svg) return;
    var pd = panel.__maData;
    var focal = (panel.__maState && panel.__maState.focal) || block.focal_brand_code;
    var threshold = pd.advantage.threshold_pp || 5;

    var hidden = panel.__maAdvHiddenStims || {};

    // Bubble per CEP/attribute for the focal brand. Hidden stims (row
    // checkbox unchecked) drop their bubble from the chart but the row
    // stays visible — Duncan: "strike and grey out, like brand attribute
    // tabs so I can put it back." Romaniuk base only — pct_total.
    var allPts = block.cells.filter(function (c) { return c.brand_code === focal; })
      .filter(function (c) { return !hidden[c.stim_code]; })
      .map(function (c) {
        var pen = block.stim_penetration[block.codes.indexOf(c.stim_code)];
        return { code: c.stim_code, ma: c.ma, pen: pen, x: pen,
                 size: c.pct_total != null ? c.pct_total : 0,
                 decision: c.decision, isSig: c.is_sig,
                 label: block.labels[block.codes.indexOf(c.stim_code)] };
      });
    var pts = allPts;
    if (pts.length === 0) { svg.innerHTML = ''; return; }

    var width = svg.clientWidth || 600;
    var height = 460;
    var mL = 60, mR = 28, mT = 28, mB = 52;
    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
    svg.setAttribute('height', height);

    var pW = width - mL - mR, pH = height - mT - mB;
    // X-axis range: user-set if provided, else auto from data.
    var xrange = panel.__maAdvXRange || {};
    var xAutoMax = Math.max(10, Math.ceil(Math.max.apply(null, allPts.map(function (p) { return p.x; })) / 10) * 10);
    var xAutoMin = 0;
    var xMin = (xrange.min != null && !isNaN(xrange.min)) ? xrange.min : xAutoMin;
    var xMax = (xrange.max != null && !isNaN(xrange.max)) ? xrange.max : xAutoMax;
    if (xMax <= xMin) { xMin = xAutoMin; xMax = xAutoMax; }
    var maAbsMax = Math.max(threshold * 2,
                              Math.ceil(Math.max.apply(null, allPts.map(function (p) { return Math.abs(p.ma); }))));
    // Bubble size: fixed 0-100% reference so toggling base actually shows
    // bigger/smaller bubbles. Without this, normalising to dataset max
    // cancels the constant awareness factor and the toggle looks dead.
    var sizeRefMax = 100;
    // Mean of the active x-axis dimension (vertical divider).
    var xMean = allPts.reduce(function (s, p) { return s + p.x; }, 0) / allPts.length;
    var xLabel = 'Stimulus penetration (any brand, %)';

    function toX(v) { return mL + pW * (v - xMin) / (xMax - xMin); }
    function toY(v) { return mT + pH * (1 - (v + maAbsMax) / (2 * maAbsMax)); }
    function bR(s)  { return Math.max(4, Math.min(22, 4 + 18 * s / sizeRefMax)); }

    /* Inline SVG presentation attributes act as a fallback for pin/PNG
       capture: html2canvas only reliably renders SVG fills/strokes when
       they are present as attributes on the element. Live CSS rules still
       win during normal rendering (CSS > attributes), so the chart looks
       identical on screen — but the captured PNG no longer ends up as a
       solid black box when the stylesheet doesn't survive the export. */
    var BUBBLE_FILL = {
      defend:   'rgba(5, 150, 105, 0.78)',
      build:    'rgba(220, 38, 38, 0.78)',
      maintain: 'rgba(148, 163, 184, 0.78)',
      na:       'rgba(226, 232, 240, 0.6)'
    };
    var BUBBLE_STROKE = {
      defend:   '#047857',
      build:    '#b91c1c',
      maintain: '#64748b',
      na:       '#cbd5e1'
    };

    var parts = [];
    parts.push('<rect class="ma-adv-q-bg" fill="rgba(241, 245, 249, 0.5)" x="' + mL + '" y="' + mT + '" width="' + pW + '" height="' + pH + '"/>');
    var yZero = toY(0), yPos = toY(threshold), yNeg = toY(-threshold);
    parts.push('<rect class="ma-adv-q-zone-defend" fill="rgba(5, 150, 105, 0.05)" x="' + mL + '" y="' + mT + '" width="' + pW + '" height="' + (yPos - mT) + '"/>');
    parts.push('<rect class="ma-adv-q-zone-build"  fill="rgba(220, 38, 38, 0.05)" x="' + mL + '" y="' + yNeg + '" width="' + pW + '" height="' + (mT + pH - yNeg) + '"/>');

    // Grid + tick labels (X) — span the [xMin, xMax] range
    for (var xi = 0; xi <= 5; xi++) {
      var xv = xMin + (xMax - xMin) * xi / 5; var gx = toX(xv);
      parts.push('<line class="ma-adv-q-grid" stroke="#eef2f7" stroke-width="1" x1="' + gx + '" y1="' + mT + '" x2="' + gx + '" y2="' + (mT + pH) + '"/>');
      parts.push('<text class="ma-adv-q-tick" fill="#94a3b8" font-size="9" x="' + gx + '" y="' + (mT + pH + 14) + '" text-anchor="middle">' + Math.round(xv) + '%</text>');
    }
    // Y grid + ticks
    for (var yi = -2; yi <= 2; yi++) {
      var yv = (maAbsMax / 2) * yi; if (Math.abs(yv) > maAbsMax) continue;
      var gy = toY(yv);
      parts.push('<line class="ma-adv-q-grid" stroke="#eef2f7" stroke-width="1" x1="' + mL + '" y1="' + gy + '" x2="' + (mL + pW) + '" y2="' + gy + '"/>');
      parts.push('<text class="ma-adv-q-tick" fill="#94a3b8" font-size="9" x="' + (mL - 6) + '" y="' + gy + '" text-anchor="end" dominant-baseline="middle">' + (yv >= 0 ? '+' : '') + yv.toFixed(0) + 'pp</text>');
    }

    // Vertical mean-x divider (the X-axis equivalent of the zero-MA line)
    var xMeanPx = toX(xMean);
    parts.push('<line class="ma-adv-q-vmid" stroke="#475569" stroke-width="1.6" stroke-dasharray="4 3" opacity="0.65" x1="' + xMeanPx + '" y1="' + mT + '" x2="' + xMeanPx + '" y2="' + (mT + pH) + '"/>');
    parts.push('<text class="ma-adv-q-vmid-label" fill="#475569" font-size="9" font-weight="600" x="' + (xMeanPx + 4) + '" y="' + (mT + pH - 6) + '">avg (' + xMean.toFixed(0) + '%)</text>');

    // Horizontal zero + threshold lines
    parts.push('<line class="ma-adv-q-zero"   stroke="#475569" stroke-width="1.6" x1="' + mL + '" y1="' + yZero + '" x2="' + (mL + pW) + '" y2="' + yZero + '"/>');
    parts.push('<line class="ma-adv-q-thresh" stroke="#94a3b8" stroke-width="1.2" stroke-dasharray="5 4" x1="' + mL + '" y1="' + yPos + '" x2="' + (mL + pW) + '" y2="' + yPos + '"/>');
    parts.push('<line class="ma-adv-q-thresh" stroke="#94a3b8" stroke-width="1.2" stroke-dasharray="5 4" x1="' + mL + '" y1="' + yNeg + '" x2="' + (mL + pW) + '" y2="' + yNeg + '"/>');

    // Axes + axis labels + zone labels
    parts.push('<line class="ma-adv-q-axis" stroke="#94a3b8" stroke-width="1.5" x1="' + mL + '" y1="' + mT + '" x2="' + mL + '" y2="' + (mT + pH) + '"/>');
    parts.push('<line class="ma-adv-q-axis" stroke="#94a3b8" stroke-width="1.5" x1="' + mL + '" y1="' + (mT + pH) + '" x2="' + (mL + pW) + '" y2="' + (mT + pH) + '"/>');
    parts.push('<text class="ma-adv-q-axis-label" fill="#475569" font-size="11" font-weight="600" x="' + (mL + pW / 2) + '" y="' + (height - 6) + '" text-anchor="middle">' + escHtml(xLabel) + '</text>');
    parts.push('<text class="ma-adv-q-axis-label" fill="#475569" font-size="11" font-weight="600" transform="rotate(-90 ' + (mL - 44) + ' ' + (mT + pH / 2) + ')" x="' + (mL - 44) + '" y="' + (mT + pH / 2) + '" text-anchor="middle">Mental Advantage (pp)</text>');
    parts.push('<text class="ma-adv-q-zone-label" fill="#94a3b8" font-size="9" font-weight="700" x="' + (mL + pW - 6) + '" y="' + (mT + 14) + '" text-anchor="end">DEFEND</text>');
    parts.push('<text class="ma-adv-q-zone-label" fill="#94a3b8" font-size="9" font-weight="700" x="' + (mL + 6) + '" y="' + (mT + 14) + '">AMPLIFY</text>');
    parts.push('<text class="ma-adv-q-zone-label" fill="#94a3b8" font-size="9" font-weight="700" x="' + (mL + pW - 6) + '" y="' + (mT + pH - 6) + '" text-anchor="end">BUILD</text>');
    parts.push('<text class="ma-adv-q-zone-label" fill="#94a3b8" font-size="9" font-weight="700" x="' + (mL + 6) + '" y="' + (mT + pH - 6) + '">LOW PRIORITY</text>');

    // Bubbles — store position + payload index for hover lookup
    var labelCandidates = [];
    pts.forEach(function (p, i) {
      // Skip points outside the configured x-range (so manual zoom works).
      if (p.x < xMin || p.x > xMax) return;
      var cx = toX(p.x), cy = toY(p.ma), r2 = bR(p.size);
      var decKey = p.decision || 'na';
      var cls = 'ma-adv-q-bubble ma-adv-q-bubble-' + decKey;
      if (p.isSig) cls += ' ma-adv-q-bubble-sig';
      var bFill   = BUBBLE_FILL[decKey]   || BUBBLE_FILL.na;
      var bStroke = BUBBLE_STROKE[decKey] || BUBBLE_STROKE.na;
      var bSW     = p.isSig ? '2.5' : '1.5';
      parts.push('<circle class="' + cls + '" fill="' + bFill +
                 '" stroke="' + bStroke + '" stroke-width="' + bSW +
                 '" cx="' + cx + '" cy="' + cy + '" r="' + r2 +
                 '" data-ma-adv-bubble-idx="' + i + '"></circle>');
      labelCandidates.push({ idx: i, cx: cx, cy: cy, r: r2, p: p });
    });

    // Smart label placement: only label the most extreme cells, and skip
    // any whose box overlaps an already-placed label. Hover tooltip covers
    // the rest.
    var ordered = labelCandidates.slice().sort(function (a, b) {
      return Math.abs(b.p.ma) - Math.abs(a.p.ma);
    });
    var placed = [];
    var maxLabels = Math.min(10, ordered.length);
    for (var li = 0; li < ordered.length && placed.length < maxLabels; li++) {
      var lc = ordered[li];
      var cx = lc.cx, cy = lc.cy, r2 = lc.r;
      var lblX = cx + r2 + 4, anchor = 'start';
      if (lblX + 80 > mL + pW) { lblX = cx - r2 - 4; anchor = 'end'; }
      var box = { x: anchor === 'start' ? lblX : lblX - 80,
                  y: cy - 6, w: 80, h: 12 };
      var collides = placed.some(function (b) {
        return !(box.x + box.w < b.x || box.x > b.x + b.w ||
                 box.y + box.h < b.y || box.y > b.y + b.h);
      });
      if (collides) continue;
      placed.push(box);
      parts.push('<text class="ma-adv-q-label" fill="#1e293b" font-size="10" x="' + lblX + '" y="' + (cy + 3) + '" text-anchor="' + anchor + '">' + escHtml(lc.p.label) + '</text>');
    }

    svg.innerHTML = parts.join('');

    // Wire hover tooltip on bubbles (single shared tooltip element)
    svg.querySelectorAll('circle.ma-adv-q-bubble').forEach(function (c) {
      var idx = parseInt(c.getAttribute('data-ma-adv-bubble-idx'), 10);
      var p = pts[idx];
      if (!p) return;
      c.addEventListener('mouseenter', function (ev) {
        showTooltip(panel, tooltipHtml(p, base), ev);
      });
      c.addEventListener('mousemove', function (ev) {
        moveTooltip(tooltipEl(panel), ev);
      });
      c.addEventListener('mouseleave', function () { hideTooltip(panel); });
    });
  }

  // ============================================================ COLUMN/ROW VISIBILITY
  function applyBrandColumnVisibility(panel) {
    var hidden = panel.__maAdvHiddenBrands || {};
    panel.querySelectorAll('.ma-adv-matrix [data-ma-cell-brand]').forEach(function (el) {
      var code = el.getAttribute('data-ma-cell-brand');
      el.classList.toggle('ma-adv-col-hidden', !!hidden[code]);
    });
  }
  // Per-row checkbox: when unchecked, the row stays in the table but is
  // greyed out and struck through, mirroring the brand-attributes tab so
  // the user can re-check to restore. The chart drops the bubble for any
  // unchecked stim.
  function applyStimRowVisibility(panel) {
    var hidden = panel.__maAdvHiddenStims || {};
    panel.querySelectorAll('tr[data-ma-adv-row-stim]').forEach(function (tr) {
      var code = tr.getAttribute('data-ma-adv-row-stim');
      tr.classList.toggle('ma-adv-row-inactive', !!hidden[code]);
    });
    var block = getStimBlock(panel); if (block) renderQuadrant(panel, block);
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
      ths.push('<th class="' + cls + '" data-ma-cell-brand="' + escAttr(b) + '">' + escHtml(nameFor(b)) + '</th>');
    });

    // Build rows
    var cellByKey = {};
    block.cells.forEach(function (c) { cellByKey[c.stim_code + '|' + c.brand_code] = c; });

    // Build a flat lookup so hover handlers can resolve cell payloads.
    var hoverPayload = [];
    var hiddenStims = panel.__maAdvHiddenStims || {};
    var rows = idx.map(function (i) {
      var stim = block.codes[i], lbl = block.labels[i];
      var checked = hiddenStims[stim] ? '' : ' checked';
      var rowCls = hiddenStims[stim] ? 'ma-adv-row-inactive' : '';
      var stimCell = '<td class="ma-adv-matrix-stim"><label class="ma-adv-row-toggle">' +
                     '<input type="checkbox" data-ma-adv-stim-toggle="' + escAttr(stim) + '"' + checked + '>' +
                     '<span class="ma-adv-row-stim-label">' + escHtml(lbl) + '</span></label></td>';
      var tds = [stimCell];
      brands.forEach(function (b) {
        var c = cellByKey[stim + '|' + b];
        if (!c || c.ma == null) {
          tds.push('<td class="' + (b === focal ? 'ma-adv-matrix-focal' : '') + '">–</td>');
          return;
        }
        // Cell formatting MUST NOT change based on significance.
        // Significance is shown via an inline asterisk after the score
        // (text-only — no class, no extra elements that affect layout).
        var bg = maColour(c.ma, threshold);
        var focalCls = b === focal ? ' ma-adv-matrix-focal' : '';
        var counts = '<span class="ma-adv-cell-counts">a=' + Math.round(c.actual) + ' / e=' + Math.round(c.expected) + '</span>';
        var pen = block.stim_penetration[block.codes.indexOf(stim)];
        var hi = hoverPayload.length;
        hoverPayload.push({ code: stim, label: lbl + ' × ' + nameFor(b),
                            ma: c.ma, pen: pen, size: c.pct_total,
                            decision: c.decision, isSig: c.is_sig });
        var sigSfx = c.is_sig ? '*' : '';
        tds.push('<td class="' + focalCls + '" data-ma-adv-cell-bg style="background-color:' + bg +
                 ' !important;background-image:none !important;--ma-cell-bg:' + bg +
                 ';" data-ma-adv-cell-idx="' + hi + '" data-ma-cell-brand="' + escAttr(b) +
                 '" data-ma-cell-stim="' + escAttr(stim) + '">' +
                 fmtScore(c.ma) + sigSfx + counts + '</td>');
      });
      return '<tr data-ma-adv-row-stim="' + escAttr(stim) + '" class="' + rowCls + '">' + tds.join('') + '</tr>';
    });

    wrap.innerHTML = '<table class="ma-adv-matrix"><thead><tr>' + ths.join('') + '</tr></thead><tbody>' + rows.join('') + '</tbody></table>';

    // Wire stim-row checkbox to hide the row + matching bubble.
    wrap.querySelectorAll('input[data-ma-adv-stim-toggle]').forEach(function (cb) {
      var code = cb.getAttribute('data-ma-adv-stim-toggle');
      cb.addEventListener('change', function () {
        panel.__maAdvHiddenStims = panel.__maAdvHiddenStims || {};
        panel.__maAdvHiddenStims[code] = !cb.checked;
        applyStimRowVisibility(panel);
      });
    });
    applyBrandColumnVisibility(panel);

    // Wire matrix-cell hover tooltip (replaces slow native title tooltip).
    var base = 'total';
    wrap.querySelectorAll('td[data-ma-adv-cell-idx]').forEach(function (td) {
      var idx2 = parseInt(td.getAttribute('data-ma-adv-cell-idx'), 10);
      var p = hoverPayload[idx2]; if (!p) return;
      td.addEventListener('mouseenter', function (ev) { showTooltip(panel, tooltipHtml(p, base), ev); });
      td.addEventListener('mousemove',  function (ev) { moveTooltip(tooltipEl(panel), ev); });
      td.addEventListener('mouseleave', function () { hideTooltip(panel); });
    });
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
  // Use event delegation on the advantage subtab so listeners survive
  // any future re-render and stay attached even if buttons are
  // dynamically replaced. A single click handler on the wrapper inspects
  // the click target via closest() and dispatches by data-ma-action.
  function syncSegmentedButtons(panel, action, value, valueAttr) {
    panel.querySelectorAll('[data-ma-action="' + action + '"]').forEach(function (b) {
      var on = b.getAttribute(valueAttr) === value;
      b.classList.toggle('sig-btn-active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }
  function bindAdvantage(panel) {
    if (panel.__maAdvBound) return; panel.__maAdvBound = true;

    var subtab = panel.querySelector('.ma-subtab[data-ma-subtab="advantage"]') || panel;

    // Intercept the advantage Excel export button before the legacy
    // exportTable handler can run (legacy expects different data attrs).
    panel.querySelectorAll('.ma-export-btn[data-ma-stim="advantage"]').forEach(function (btn) {
      btn.addEventListener('click', function (ev) {
        ev.stopImmediatePropagation();
        exportAdvantageMatrix(panel);
      }, true);
    });

    // Single delegated click handler for the stim toggle, x-range reset
    // and brand chips. Base toggle is removed (Romaniuk — total only).
    subtab.addEventListener('click', function (ev) {
      var stimBtn = ev.target.closest('[data-ma-action="adv-stim"]');
      if (stimBtn && subtab.contains(stimBtn)) {
        var stim = stimBtn.getAttribute('data-ma-adv-stim');
        if (!stim) return;
        getAdvState(panel).stim = stim;
        syncSegmentedButtons(panel, 'adv-stim', stim, 'data-ma-adv-stim');
        renderAdvantage(panel);
        return;
      }
      var resetBtn = ev.target.closest('button[data-ma-action="adv-xrange-reset"]');
      if (resetBtn && subtab.contains(resetBtn)) {
        var minEl = panel.querySelector('input[data-ma-action="adv-xrange-min"]');
        var maxEl = panel.querySelector('input[data-ma-action="adv-xrange-max"]');
        if (minEl) minEl.value = ''; if (maxEl) maxEl.value = '';
        panel.__maAdvXRange = {};
        var b2 = getStimBlock(panel); if (b2) renderQuadrant(panel, b2);
        return;
      }
    });

    // X-axis range state + delegated change listener for the two inputs.
    // (Reset button is handled by the click delegate above.) Listener
    // fires on `input` so the chart updates as the user types, and on
    // `change` for completeness when the field commits.
    panel.__maAdvXRange = panel.__maAdvXRange || {};
    function readAndApplyXRange() {
      var minEl = panel.querySelector('input[data-ma-action="adv-xrange-min"]');
      var maxEl = panel.querySelector('input[data-ma-action="adv-xrange-max"]');
      var s = panel.__maAdvXRange;
      var minV = (minEl && minEl.value !== '') ? parseFloat(minEl.value) : NaN;
      var maxV = (maxEl && maxEl.value !== '') ? parseFloat(maxEl.value) : NaN;
      s.min = isNaN(minV) ? null : minV;
      s.max = isNaN(maxV) ? null : maxV;
      var block = getStimBlock(panel); if (block) renderQuadrant(panel, block);
    }
    ['input', 'change'].forEach(function (evName) {
      subtab.addEventListener(evName, function (ev) {
        var t = ev.target;
        if (!t || !t.matches) return;
        if (t.matches('input[data-ma-action="adv-xrange-min"], input[data-ma-action="adv-xrange-max"]')) {
          readAndApplyXRange();
        }
      });
    });

    panel.__maAdvHiddenBrands = panel.__maAdvHiddenBrands || {};
    panel.__maAdvHiddenStims = panel.__maAdvHiddenStims || {};

    // Seed hidden state from DOM so chip_default = focal_only takes effect:
    // any chip rendered with .col-chip-off is hidden until the user toggles it on.
    subtab.querySelectorAll('button[data-ma-adv-chip-brand].col-chip-off').forEach(function (c) {
      var code = c.getAttribute('data-ma-adv-chip-brand');
      if (code) panel.__maAdvHiddenBrands[code] = true;
    });

    // Brand-column chips + Show all/Hide all toggle: delegated click.
    subtab.addEventListener('click', function (ev) {
      // Show all / Hide all toggle
      var toggleBtn = ev.target.closest('button[data-ma-adv-action="toggleall"]');
      if (toggleBtn && subtab.contains(toggleBtn)) {
        var focal = panel.__maState && panel.__maState.focal;
        var chips = subtab.querySelectorAll('button[data-ma-adv-chip-brand]');
        var nonFocal = [];
        chips.forEach(function (c) {
          if (c.getAttribute('data-ma-adv-chip-brand') !== focal) nonFocal.push(c);
        });
        var allOn = nonFocal.every(function (c) { return !c.classList.contains('col-chip-off'); });
        var nextState = !allOn;
        nonFocal.forEach(function (c) {
          var code = c.getAttribute('data-ma-adv-chip-brand');
          c.classList.toggle('col-chip-off', !nextState);
          panel.__maAdvHiddenBrands[code] = !nextState;
        });
        applyBrandColumnVisibility(panel);
        toggleBtn.textContent = nextState ? 'Hide all' : 'Show all';
        return;
      }

      // Individual brand chip
      var chip = ev.target.closest('button[data-ma-adv-chip-brand]');
      if (!chip || !subtab.contains(chip)) return;
      var code = chip.getAttribute('data-ma-adv-chip-brand');
      var off = chip.classList.toggle('col-chip-off');
      panel.__maAdvHiddenBrands[code] = off;
      applyBrandColumnVisibility(panel);
    });

    // Show counts and Show chart checkboxes — direct change listeners
    // (single elements per panel, no risk of detachment).
    var cntCb = panel.querySelector('input[data-ma-action="adv-show-counts"]');
    if (cntCb) cntCb.addEventListener('change', function () {
      var wrap = panel.querySelector('.ma-adv-matrix-wrap');
      if (wrap) wrap.classList.toggle('ma-adv-show-counts', cntCb.checked);
    });
    var chartCb = panel.querySelector('input[data-ma-action="adv-show-chart"]');
    if (chartCb) chartCb.addEventListener('change', function () {
      var view = panel.querySelector('.ma-adv-quadrant-view');
      if (!view) return;
      if (chartCb.checked) {
        view.removeAttribute('hidden');
        var block = getStimBlock(panel); if (block) renderQuadrant(panel, block);
      } else {
        view.setAttribute('hidden', '');
        hideTooltip(panel);
      }
    });
  }

  // Apply the same brand-palette colours used elsewhere in the MA panel
  // to the advantage tab's "Show brands" chip row. Falls back to the
  // stable BRAND_PALETTE hash so EVERY chip gets a colour (was failing
  // for brands without an explicit Colour cell — only 3/10 lit up).
  function colourAdvantageChips(panel) {
    var pd = panel.__maData; if (!pd) return;
    panel.querySelectorAll('button[data-ma-adv-chip-brand]').forEach(function (chip) {
      var code = chip.getAttribute('data-ma-adv-chip-brand');
      var col = brandColourFor(pd, code);
      chip.style.setProperty('--brand-chip-color', col);
      chip.style.backgroundColor = col;
      chip.style.borderColor = col;
      chip.style.color = '#fff';
      chip.style.fontWeight = (pd.meta && code === pd.meta.focal_brand_code) ? '700' : '500';
    });
  }

  // ============================================================ PUBLIC API
  window.MAAdvantage = {
    init:   function (panel) {
      bindAdvantage(panel);
      colourAdvantageChips(panel);
      renderAdvantage(panel);
    },
    render: function (panel) {
      colourAdvantageChips(panel);
      renderAdvantage(panel);
    }
  };
})();
