/* =============================================================================
 * BRAND MODULE — EXECUTIVE SUMMARY PANEL JS
 * -----------------------------------------------------------------------------
 * Reads the per-(category, brand) JSON payload embedded in
 * <script type="application/json" class="brsum-data"> and renders the four
 * dashboard strips (context, focal, diagnostic, headline) when the user
 * changes either dropdown.
 *
 * Public functions exposed on window:
 *   brsumSwitchCat(catName)    — programmatic category change (used by the
 *                                closing-strip mini-cards)
 *   brsumInsertMd(before,after) — markdown toolbar handler (insight editor)
 *   brsumRenderInsight()        — re-render markdown preview
 *   brsumToggleEdu(btn)         — collapse/expand educational callout
 *
 * Markdown renderer: prefers the global `renderMarkdown` (tracker module).
 * When unavailable (brand-only reports), falls back to a tiny inline impl.
 * =============================================================================
 */
(function () {
  'use strict';

  function $(selector, root) { return (root || document).querySelector(selector); }
  function $$(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }

  function escHtml(s) {
    if (s == null) return '';
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  /* -------------------------------------------------------------------------
   * Init
   * ------------------------------------------------------------------------- */
  function init() {
    var root = document.querySelector('.brsum-root');
    if (!root) return;
    var dataNode = root.querySelector('script.brsum-data');
    if (!dataNode) return;
    var payload;
    try { payload = JSON.parse(dataNode.textContent || '{}'); }
    catch (e) { console.warn('[brsum] payload parse failed', e); return; }

    root.__brsumPayload = payload;

    var catSelect = root.querySelector('[data-brsum-cat]');
    var brandSelect = root.querySelector('[data-brsum-brand]');
    if (!catSelect || !brandSelect) return;

    catSelect.addEventListener('change', function () {
      onCategoryChange(root, catSelect.value, null);
    });
    brandSelect.addEventListener('change', function () {
      render(root, catSelect.value, brandSelect.value);
    });

    // Initial selections
    var initialCat = root.getAttribute('data-default-cat') || catSelect.value;
    var initialBrand = root.getAttribute('data-default-brand') || '';
    if (initialCat) catSelect.value = initialCat;
    onCategoryChange(root, initialCat, initialBrand);
  }

  /* -------------------------------------------------------------------------
   * Category change: refresh brand dropdown options, then render.
   * ------------------------------------------------------------------------- */
  function onCategoryChange(root, catName, preferredBrand) {
    var payload = root.__brsumPayload;
    if (!payload || !payload.categories || !payload.categories[catName]) return;
    var cat = payload.categories[catName];
    var brandSelect = root.querySelector('[data-brsum-brand]');
    if (!brandSelect) return;

    // Repopulate brand options for this category. Preserve current brand
    // when it exists in the new category; otherwise prefer the explicit
    // preferredBrand argument; otherwise fall back to the first brand.
    var prevBrand = brandSelect.value;
    var codes = cat.brand_codes || [];
    var labels = cat.brand_labels || [];
    var html = '';
    for (var i = 0; i < codes.length; i++) {
      html += '<option value="' + escHtml(codes[i]) + '">' +
              escHtml(labels[i] || codes[i]) + '</option>';
    }
    brandSelect.innerHTML = html;

    var chosen = '';
    if (preferredBrand && codes.indexOf(preferredBrand) >= 0) chosen = preferredBrand;
    else if (prevBrand && codes.indexOf(prevBrand) >= 0)       chosen = prevBrand;
    else if (codes.length > 0)                                 chosen = codes[0];

    if (chosen) brandSelect.value = chosen;

    render(root, catName, chosen);
  }

  /* -------------------------------------------------------------------------
   * Render the dashboard for a (cat, brand) pair, with a 200ms fade.
   * ------------------------------------------------------------------------- */
  function render(root, catName, brandCode) {
    var payload = root.__brsumPayload;
    if (!payload || !payload.categories || !payload.categories[catName]) return;
    var cat = payload.categories[catName];
    var snap = cat.brands ? cat.brands[brandCode] : null;
    var dashboard = root.querySelector('[data-brsum-fade]');
    if (!dashboard) return;

    // Resolve brand colour via TurasColours (hash + focal-aware) when
    // available; fall back to whatever the R payload supplied.
    var brandColour = (snap && snap.colour) ? snap.colour : '#1A5276';
    if (typeof TurasColours !== 'undefined' && brandCode) {
      try {
        var pdLike = { config: {
          brand_colours: payload.brand_colours_map || {},
          focal_colour: payload.focal_colour
        } };
        // Mark the focal brand so TurasColours uses focal_colour for it
        if (payload.default_brand && payload.default_brand === brandCode) {
          // Focal: use focal_colour directly
          brandColour = payload.focal_colour || brandColour;
        } else {
          brandColour = TurasColours.getBrandColour(pdLike, brandCode) || brandColour;
        }
      } catch (e) { /* fallback already set */ }
    }
    snap.colour = brandColour;
    root.style.setProperty('--brsum-brand-colour', brandColour);

    dashboard.classList.add('brsum-fading');
    setTimeout(function () {
      /* New card-grid layout — each card has a body container the
         renderer fills. Cards that aren't wired yet show a "coming
         soon" placeholder so the grid stays visible while we
         incrementally implement them. */
      renderFocalContext(root, snap, cat, catName);
      renderCategoryContextCard(root, cat.context);
      renderBrandSummaryCard(root, snap);
      renderMAMetricsCard(root, snap);
      renderWOMCard(root, snap);
      renderMiniFunnelCard(root, 'funnel',        cat.funnel,        brandCode, snap,
                           { emptyMessage: 'Funnel data not available.' });
      renderMiniFunnelCard(root, 'attitude',      cat.attitude,      brandCode, snap,
                           { emptyMessage: 'Brand attitude not available.' });
      renderMiniFunnelCard(root, 'loyalty',       cat.loyalty,       brandCode, snap,
                           { emptyMessage: 'Loyalty segmentation not available.' });
      renderMiniFunnelCard(root, 'purchase_dist', cat.purchase_dist, brandCode, snap,
                           { emptyMessage: 'Purchase distribution not available.' });
      renderDoPCard(root, cat.dop, brandCode, snap);
      renderDotPlotCard(root, 'cep',   cat.cep,   brandCode, snap, /*showDecision=*/true);
      renderDotPlotCard(root, 'attrs', cat.attrs, brandCode, snap, /*showDecision=*/true);
      /* Apply focal colour to any value text rendered inline. */
      if (snap && snap.colour) {
        $$('.brsum-focal-value', root).forEach(function (el) {
          el.style.color = snap.colour;
        });
      }
      dashboard.classList.remove('brsum-fading');
    }, 200);
  }

  /* ---------------------------------------------------------------------
   * v2 card-grid renderers
   *
   * Each card has a body container <div data-brsum-card-body="<key>"> the
   * renderer fills via innerHTML. The header (title) is static; the meta
   * span next to the title can carry the leader brand or other context.
   *
   * Common templates:
   *   - Focal-vs-cat-avg "value chip": large focal value + small cat avg
   *     underneath. Used by MA metrics + Brand summary cards.
   *   - "Statement" card (single value): used by WOM.
   *   - "Stat row" card (label + value): used by Category context.
   * --------------------------------------------------------------------- */

  function cardBody(root, key) {
    return root.querySelector('[data-brsum-card-body="' + key + '"]');
  }
  function cardMeta(root, key) {
    return root.querySelector('[data-brsum-card-meta="' + key + '"]');
  }

  function renderPlaceholder(root, key, msg) {
    var body = cardBody(root, key);
    if (!body) return;
    body.innerHTML = '<div class="brsum-card-empty">' + escHtml(msg || '—') + '</div>';
  }

  function renderFocalContext(root, snap, cat, catName) {
    var brandEl = root.querySelector('[data-brsum-fc-brand]');
    var catEl   = root.querySelector('[data-brsum-fc-cat]');
    if (brandEl) brandEl.textContent = (snap && snap.name) ? snap.name : '—';
    if (catEl)   catEl.textContent   = catName || (cat && cat.label) || '—';
    /* The header strip uses the focal colour as its background gradient,
       set via the --brsum-brand-colour custom prop on .brsum-root. */
  }

  function renderCategoryContextCard(root, ctx) {
    var body = cardBody(root, 'context');
    if (!body) return;
    if (!ctx) {
      body.innerHTML = '<div class="brsum-card-empty">Category context not available.</div>';
      return;
    }
    /* Eight category-level metrics, sourced from funnel + mental availability
       + cat_buying + shopper engines. Each row only renders when its source
       engine produced data; the card is hidden if every row is missing. */
    var rows = [];
    if (ctx.avg_aware_brands)    rows.push(statRow('Avg awareness',     ctx.avg_aware_brands.value,    ctx.avg_aware_brands.sub));
    if (ctx.avg_consider_brands) rows.push(statRow('Avg consideration', ctx.avg_consider_brands.value, ctx.avg_consider_brands.sub));
    if (ctx.avg_p12m_brands)     rows.push(statRow('Avg buying (long)', ctx.avg_p12m_brands.value,     ctx.avg_p12m_brands.sub));
    if (ctx.avg_p3m_brands)      rows.push(statRow('Avg buying (3m)',   ctx.avg_p3m_brands.value,      ctx.avg_p3m_brands.sub));
    if (ctx.avg_ceps)            rows.push(statRow('Avg CEPs',          ctx.avg_ceps.value,            ctx.avg_ceps.sub));
    if (ctx.avg_purchases)       rows.push(statRow('Avg purchases',     ctx.avg_purchases.value,       ctx.avg_purchases.sub));
    if (ctx.top_channel)         rows.push(statRow('Top channel',       ctx.top_channel.value,         ctx.top_channel.sub));
    if (ctx.top_pack)            rows.push(statRow('Top pack size',     ctx.top_pack.value,            ctx.top_pack.sub));
    if (rows.length === 0) {
      body.innerHTML = '<div class="brsum-card-empty">Category context metrics not available.</div>';
      return;
    }
    body.innerHTML = '<div class="brsum-stat-rows">' + rows.join('') + '</div>';
  }

  function statRow(label, value, sub) {
    return '<div class="brsum-stat-row">' +
             '<div class="brsum-stat-label">' + escHtml(label) + '</div>' +
             '<div class="brsum-stat-value">' + escHtml(value) +
               (sub ? '<span class="brsum-stat-sub">' + escHtml(sub) + '</span>' : '') +
             '</div>' +
           '</div>';
  }

  function valueChip(label, value, catAvg, focalColour, leaderHtml) {
    return '<div class="brsum-vchip">' +
             '<div class="brsum-vchip-label">' + escHtml(label) + '</div>' +
             '<div class="brsum-vchip-value brsum-focal-value" style="color:' + focalColour + '">' +
               escHtml(value) + '</div>' +
             (catAvg && catAvg !== '—'
               ? '<div class="brsum-vchip-catavg">cat avg <span>' + escHtml(catAvg) + '</span></div>'
               : '') +
             (leaderHtml || '') +
           '</div>';
  }

  function renderMAMetricsCard(root, snap) {
    var body = cardBody(root, 'ma_metrics');
    if (!body) return;
    if (!snap || !snap.ma_metrics) {
      body.innerHTML = '<div class="brsum-card-empty">Mental Availability metrics not available.</div>';
      return;
    }
    var col = snap.colour || '#1A5276';
    var html = '';
    for (var i = 0; i < snap.ma_metrics.length; i++) {
      var m = snap.ma_metrics[i];
      var leader = '';
      if (m.is_leader) {
        leader = '<div class="brsum-vchip-leader brsum-leader-on">CATEGORY LEADER</div>';
      } else if (m.leader && m.leader !== '—') {
        leader = '<div class="brsum-vchip-leader">Leader: ' + escHtml(m.leader) + '</div>';
      }
      html += valueChip(m.label, m.value, m.cat_avg, col, leader);
    }
    body.innerHTML = '<div class="brsum-vchip-grid">' + html + '</div>';
  }

  function renderBrandSummaryCard(root, snap) {
    var body = cardBody(root, 'brand_summary');
    var meta = cardMeta(root, 'brand_summary');
    if (meta) meta.textContent = (snap && snap.brand_summary_base) || '';
    if (!body) return;
    if (!snap || !snap.brand_summary) {
      body.innerHTML = '<div class="brsum-card-empty">Purchase behaviour metrics not available.</div>';
      return;
    }
    var col = snap.colour || '#1A5276';
    var html = '';
    for (var i = 0; i < snap.brand_summary.length; i++) {
      var m = snap.brand_summary[i];
      html += valueChip(m.label, m.value, m.cat_avg, col, '');
    }
    body.innerHTML = '<div class="brsum-vchip-grid">' + html + '</div>';
  }

  /* ---------------------------------------------------------------------
   * Word of mouth card — two columns (Heard / Said) each with three rows:
   * positive (green), negative (red), and a highlighted net row at the
   * bottom. Each row shows the focal value large + cat avg below.
   * --------------------------------------------------------------------- */
  function renderWOMCard(root, snap) {
    var body = cardBody(root, 'wom');
    var meta = cardMeta(root, 'wom');
    if (meta) meta.textContent = (snap && snap.wom && snap.wom.base_label) || '';
    if (!body) return;
    if (!snap || !snap.wom || !snap.wom.available) {
      body.innerHTML = '<div class="brsum-card-empty">Word-of-mouth not available.</div>';
      return;
    }
    var w = snap.wom;
    body.innerHTML =
      '<div class="brsum-wom-grid">' +
        womColumn('Heard', w.heard) +
        womColumn('Said',  w.said)  +
      '</div>';
  }

  function womColumn(title, col) {
    return '<div class="brsum-wom-col">' +
             '<div class="brsum-wom-col-title">' + escHtml(title) + '</div>' +
             womRow(col.positive, false) +
             womRow(col.negative, false) +
             womRow(col.net,      true)  +
           '</div>';
  }

  function womRow(row, isNet) {
    if (!row) return '';
    var toneCls = '';
    if (row.tone === 'pos') toneCls = ' brsum-wom-pos';
    else if (row.tone === 'neg') toneCls = ' brsum-wom-neg';
    var cls = 'brsum-wom-row' + toneCls + (isNet ? ' brsum-wom-net' : '');
    return '<div class="' + cls + '">' +
             '<div class="brsum-wom-label">' + escHtml(row.label) + '</div>' +
             '<div class="brsum-wom-vals">' +
               '<div class="brsum-wom-val">' + escHtml(row.value || '—') + '</div>' +
               (row.cat_avg && row.cat_avg !== '—'
                 ? '<div class="brsum-wom-catavg">cat avg ' + escHtml(row.cat_avg) + '</div>'
                 : '') +
             '</div>' +
           '</div>';
  }

  /* ---------------------------------------------------------------------
   * Mini-funnel card (Brand funnel + Brand attitude + Loyalty seg +
   * Purchase dist)
   *
   * Two side-by-side mini-funnel cards per metric: focal brand FIRST,
   * cat-avg SECOND. Each card lists the stages / segments stacked
   * vertically. Each row = one stage with a horizontal bar (% scaled
   * against a shared maximum so the comparison reads visually) and a
   * "<label> <pct>" caption underneath — same idiom as the brand-funnel
   * sub-tab's mini-funnels, scoped here under .brsum-mf-*.
   *
   * Block shape (R-side):
   *   stage_keys / stage_labels  (Brand funnel)
   *   seg_codes  / seg_labels    (Brand attitude / Loyalty / Purchase dist)
   * --------------------------------------------------------------------- */
  function fmtPctSingle(v) {
    if (v == null || isNaN(v)) return '—';
    return Math.round(v * 100) + '%';
  }

  function renderMiniFunnelCard(root, key, block, brandCode, snap, opts) {
    opts = opts || {};
    var body = cardBody(root, key);
    var meta = cardMeta(root, key);
    /* Per-brand base map wins when available (purchase distribution
       changes denominator with the focal); fall back to the global
       base_label for everything else. */
    if (meta) {
      var perBrand = block && block.base_by_brand && block.base_by_brand[brandCode];
      meta.textContent = perBrand || (block && block.base_label) || '';
    }
    if (!body) return;
    if (!block || !block.available) {
      var msg = opts.emptyMessage || 'Data not available.';
      body.innerHTML = '<div class="brsum-card-empty">' + escHtml(msg) + '</div>';
      return;
    }
    var rowKeys   = block.stage_keys   || block.seg_codes  || [];
    var rowLabels = block.stage_labels || block.seg_labels || rowKeys;
    var focalRow  = (block.brands && block.brands[brandCode]) || [];
    var catAvg    = block.cat_avg || [];
    var col       = (snap && snap.colour) || '#1A5276';
    var name      = (snap && snap.name)   || brandCode;

    /* Shared scale across both cards so the longest bar fills the lane. */
    var maxVal = 0;
    focalRow.forEach(function (v) { if (v != null && !isNaN(v) && v > maxVal) maxVal = v; });
    catAvg.forEach(function (v)  { if (v != null && !isNaN(v) && v > maxVal) maxVal = v; });
    if (maxVal <= 0) maxVal = 1;

    var focalCard = buildMiniFunnel(name, focalRow, rowLabels, col, maxVal, true);
    var avgCard   = buildMiniFunnel('Cat avg', catAvg, rowLabels, '#64748b', maxVal, false);

    body.innerHTML =
      '<div class="brsum-mf-row">' + focalCard + avgCard + '</div>';
  }

  function buildMiniFunnel(title, vals, labels, colour, maxVal, isFocal) {
    var stages = '';
    for (var i = 0; i < labels.length; i++) {
      var v = vals[i];
      var barW = (v == null || isNaN(v)) ? 0 : Math.max(6, Math.round((v / maxVal) * 100));
      var pctStr = fmtPctSingle(v);
      stages +=
        '<div class="brsum-mf-stage">' +
          '<div class="brsum-mf-bar-bg">' +
            '<div class="brsum-mf-bar" style="width:' + barW + '%;background:' + colour + ';"></div>' +
          '</div>' +
          '<div class="brsum-mf-label">' + escHtml(labels[i]) +
            ' <span class="brsum-mf-pct">' + pctStr + '</span>' +
          '</div>' +
        '</div>';
    }
    var cls = 'brsum-mf-card' + (isFocal ? ' brsum-mf-focal' : ' brsum-mf-avg');
    return '<div class="' + cls + '" style="border-left-color:' + colour + ';">' +
             '<div class="brsum-mf-title">' + escHtml(title) +
               (isFocal ? ' <span class="brsum-mf-badge">FOCAL</span>' : '') +
             '</div>' +
             '<div class="brsum-mf-stages">' + stages + '</div>' +
           '</div>';
  }

  /* ---------------------------------------------------------------------
   * Duplication of purchase card — top 3 partners + top 3 rivals for the
   * focal brand (mirrors the partition card on the DoP sub-tab).
   * --------------------------------------------------------------------- */
  function renderDoPCard(root, block, brandCode, snap) {
    var body = cardBody(root, 'dop');
    var meta = cardMeta(root, 'dop');
    if (!body) return;
    if (!block || !block.available) {
      if (meta) meta.textContent = '';
      body.innerHTML = '<div class="brsum-card-empty">Duplication of purchase data not available.</div>';
      return;
    }
    var brand = block.brands && block.brands[brandCode];
    if (!brand) {
      if (meta) meta.textContent = '';
      body.innerHTML = '<div class="brsum-card-empty">No data for this brand.</div>';
      return;
    }
    if (meta) meta.textContent = brand.weak ? 'weak partition signal' : '';

    var partnersHtml = brand.partners && brand.partners.length
      ? brand.partners.map(function (p) { return dopRow(p, true); }).join('')
      : '<li class="brsum-dop-empty">No brands over-index for this focal.</li>';
    var rivalsHtml = brand.rivals && brand.rivals.length
      ? brand.rivals.map(function (p) { return dopRow(p, false); }).join('')
      : '<li class="brsum-dop-empty">No brands under-index for this focal.</li>';

    body.innerHTML =
      '<div class="brsum-dop-grid">' +
        '<div class="brsum-dop-col brsum-dop-col-partners">' +
          '<div class="brsum-dop-coltitle">Partition partners' +
            '<span class="brsum-dop-hint">over-index vs cat avg</span>' +
          '</div>' +
          '<ul class="brsum-dop-list">' + partnersHtml + '</ul>' +
        '</div>' +
        '<div class="brsum-dop-col brsum-dop-col-rivals">' +
          '<div class="brsum-dop-coltitle">Partition rivals' +
            '<span class="brsum-dop-hint">under-index vs cat avg</span>' +
          '</div>' +
          '<ul class="brsum-dop-list">' + rivalsHtml + '</ul>' +
        '</div>' +
      '</div>';
  }

  function dopRow(p, isPartner) {
    var dev = Math.round(p.dev);
    var devTxt = (dev >= 0 ? '+' : '') + dev + 'pp';
    return '<li class="brsum-dop-item ' + (isPartner ? 'is-partner' : 'is-rival') + '">' +
             '<span class="brsum-dop-brand">' + escHtml(p.label || p.code) + '</span>' +
             '<span class="brsum-dop-actual">' + Math.round(p.obs) + '%</span>' +
             '<span class="brsum-dop-dev">' + devTxt + '</span>' +
             '<span class="brsum-dop-vs">vs ' + Math.round(p.avg) + '% avg</span>' +
           '</li>';
  }

  /* ---------------------------------------------------------------------
   * Dot plot card (CEP + Brand attributes, full-width)
   *
   * One row per stim: stim label on the left, then a horizontal lane
   * with the cat-avg dashed marker + the focal dot + numeric % + (CEP
   * only) the Mental Advantage decision badge (Defend / Build /
   * Maintain) on the right.
   * --------------------------------------------------------------------- */
  function renderDotPlotCard(root, key, block, brandCode, snap, showDecision) {
    var body = cardBody(root, key);
    var meta = cardMeta(root, key);
    /* Card meta shows the n base when available, with a short qualifier
       so readers know the rows are sorted by the focal brand. */
    if (meta) {
      if (block && block.available) {
        var baseTxt = block.base_label || '';
        meta.textContent = baseTxt
          ? baseTxt + ' · sorted by focal'
          : 'Sorted by focal brand';
      } else {
        meta.textContent = '';
      }
    }
    if (!body) return;
    if (!block || !block.available) {
      body.innerHTML = '<div class="brsum-card-empty">Mental Availability data not available.</div>';
      return;
    }
    var brand = block.brands && block.brands[brandCode];
    if (!brand) {
      body.innerHTML = '<div class="brsum-card-empty">No data for this brand.</div>';
      return;
    }
    var col   = (snap && snap.colour) || '#1A5276';
    var stims = block.stim_codes || [];
    var fps   = brand.focal_pct  || [];
    var avgs  = block.cat_avg_pct || [];
    var decs  = brand.decision   || [];
    var pps   = brand.advantage_pp || [];

    var maxVal = 0;
    fps.forEach(function (v) { if (v != null && !isNaN(v) && v > maxVal) maxVal = v; });
    avgs.forEach(function (v) { if (v != null && !isNaN(v) && v > maxVal) maxVal = v; });
    if (maxVal <= 0) maxVal = 10;
    /* Round up to a tidy 5% step for readability. */
    maxVal = Math.max(5, Math.ceil(maxVal / 5) * 5);

    /* Sort rows by focal value descending. NaN/missing focal values fall
       to the bottom. The cat-avg + decision arrays are aligned to stim
       index so we sort an index list, not the underlying arrays. */
    var idx = [];
    for (var s = 0; s < stims.length; s++) idx.push(s);
    idx.sort(function (a, b) {
      var va = fps[a], vb = fps[b];
      var aMissing = (va == null || isNaN(va));
      var bMissing = (vb == null || isNaN(vb));
      if (aMissing && bMissing) return 0;
      if (aMissing) return 1;
      if (bMissing) return -1;
      return vb - va;
    });

    var rows = '';
    for (var k = 0; k < idx.length; k++) {
      var i = idx[k];
      var fv = fps[i];
      var av = avgs[i];
      var fpct = (fv == null || isNaN(fv)) ? null : Math.min(100, (fv / maxVal) * 100);
      var apct = (av == null || isNaN(av)) ? null : Math.min(100, (av / maxVal) * 100);
      var dec  = decs[i];
      var pp   = pps[i];
      var decBadge = '';
      if (showDecision && dec) {
        var dKey = dec.toLowerCase();
        var ppTxt = (pp != null && !isNaN(pp))
          ? ((pp >= 0 ? '+' : '') + pp.toFixed(1) + 'pp')
          : '';
        decBadge =
          '<span class="brsum-dec-badge brsum-dec-' + escHtml(dKey) + '">' +
            escHtml(dec) +
            (ppTxt ? ' <em>' + ppTxt + '</em>' : '') +
          '</span>';
      }
      var avgMark = apct != null
        ? '<span class="brsum-dot-avg" style="left:' + apct.toFixed(2) + '%;" title="Cat avg: ' +
            Math.round(av) + '%"></span>'
        : '';
      var focalDot = fpct != null
        ? '<span class="brsum-dot-focal" style="left:' + fpct.toFixed(2) +
            '%;background:' + escHtml(col) + ';" title="' +
            escHtml((snap && snap.name) || brandCode) + ': ' +
            (fv == null ? '—' : Math.round(fv) + '%') + '"></span>'
        : '';
      var focalVal = fv == null || isNaN(fv) ? '—' : Math.round(fv) + '%';
      rows +=
        '<div class="brsum-dot-row">' +
          '<div class="brsum-dot-stim">' + escHtml(block.stim_labels[i] || stims[i]) + '</div>' +
          '<div class="brsum-dot-lane">' +
            '<div class="brsum-dot-track"></div>' +
            avgMark + focalDot +
          '</div>' +
          '<div class="brsum-dot-val" style="color:' + escHtml(col) + ';">' + focalVal + '</div>' +
          '<div class="brsum-dot-meta">' + decBadge + '</div>' +
        '</div>';
    }
    /* X-axis ticks (0%, 25%, 50%, 75%, 100% of maxVal). */
    var ticks = '';
    for (var t = 0; t <= 4; t++) {
      var leftPct = (t * 25);
      var tickVal = Math.round(maxVal * t / 4);
      ticks +=
        '<span class="brsum-dot-tick" style="left:' + leftPct + '%;">' + tickVal + '%</span>';
    }
    body.innerHTML =
      '<div class="brsum-dot-legend">' +
        '<span class="brsum-legend-dot" style="background:' + escHtml(col) + ';"></span>' +
        '<span class="brsum-legend-name">' + escHtml((snap && snap.name) || brandCode) + '</span>' +
        '<span class="brsum-dot-avg-marker"></span>' +
        '<span class="brsum-legend-name">Cat avg</span>' +
      '</div>' +
      '<div class="brsum-dot-rows">' + rows + '</div>' +
      '<div class="brsum-dot-axis">' + ticks + '</div>';
  }

  /* -------------------------------------------------------------------------
   * Public — programmatic category switch (closing strip mini-cards)
   * ------------------------------------------------------------------------- */
  window.brsumSwitchCat = function (catName) {
    var root = document.querySelector('.brsum-root');
    if (!root) return;
    var catSelect = root.querySelector('[data-brsum-cat]');
    if (!catSelect) return;
    catSelect.value = catName;
    onCategoryChange(root, catName, null);
    // Smooth scroll up so the user sees the new view
    var dashboard = root.querySelector('[data-brsum-fade]');
    if (dashboard) dashboard.scrollIntoView({behavior: 'smooth', block: 'start'});
  };

  /* -------------------------------------------------------------------------
   * Insight editor (ported from tracker)
   * ------------------------------------------------------------------------- */
  function fallbackRenderMd(md) {
    if (!md) return '';
    var html = md
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/^## (.+)$/gm, '<h2>$1</h2>')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/g, '<em>$1</em>')
      .replace(/^&gt; (.+)$/gm, '<blockquote>$1</blockquote>')
      .replace(/^- (.+)$/gm, '<li>$1</li>');
    html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function (m) { return '<ul>' + m + '</ul>'; });
    html = html.split('\n').map(function (line) {
      var t = line.trim();
      if (!t) return '';
      if (/^<(h2|ul|li|blockquote)/.test(t)) return t;
      return '<p>' + t + '</p>';
    }).join('\n');
    return html;
  }

  window.brsumRenderInsight = function () {
    var editor = document.getElementById('brsum-insight-editor');
    var rendered = document.getElementById('brsum-insight-rendered');
    if (!editor || !rendered) return;
    var md = editor.value;
    var html = (typeof window.renderMarkdown === 'function')
      ? window.renderMarkdown(md)
      : fallbackRenderMd(md);
    rendered.innerHTML = html;
  };

  window.brsumInsertMd = function (before, after) {
    var editor = document.getElementById('brsum-insight-editor');
    if (!editor) return;
    var start = editor.selectionStart;
    var end = editor.selectionEnd;
    var text = editor.value;
    var selected = text.substring(start, end);
    var replacement = before + (selected || 'text') + after;
    editor.value = text.substring(0, start) + replacement + text.substring(end);
    editor.focus();
    var newPos = start + before.length + (selected || 'text').length;
    editor.setSelectionRange(newPos, newPos);
    window.brsumRenderInsight();
  };

  /* -------------------------------------------------------------------------
   * Educational callout (collapse / expand)
   * ------------------------------------------------------------------------- */
  window.brsumToggleEdu = function (btn) {
    var wrap = btn ? btn.closest('[data-brsum-edu]') : null;
    if (!wrap) return;
    wrap.classList.toggle('open');
  };

  /* -------------------------------------------------------------------------
   * Boot
   * ------------------------------------------------------------------------- */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
