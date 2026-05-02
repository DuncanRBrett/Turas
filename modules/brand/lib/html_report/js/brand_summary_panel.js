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
      renderPlaceholder(root, 'funnel',        'Brand funnel mini-funnel — coming soon');
      renderPlaceholder(root, 'attitude',      'Brand attitude mini-funnel — coming soon');
      renderPlaceholder(root, 'loyalty',       'Loyalty segmentation mini-funnel — coming soon');
      renderPlaceholder(root, 'purchase_dist', 'Purchase distribution mini-funnel — coming soon');
      renderPlaceholder(root, 'dop',           'Duplication of purchase (top 3 partners / rivals) — coming soon');
      renderPlaceholder(root, 'cep',           'CEP dot plot — coming soon');
      renderPlaceholder(root, 'attrs',         'Brand attributes dot plot — coming soon');
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
    /* Spec: avg purchases per category buyer, avg repertoire size, plus
       top channel and top pack when shopper data is present. */
    var rows = [];
    if (ctx.avg_purchases) rows.push(statRow('Avg purchases / buyer', ctx.avg_purchases.value, ctx.avg_purchases.sub));
    if (ctx.avg_brands)    rows.push(statRow('Avg repertoire size',   ctx.avg_brands.value,    ctx.avg_brands.sub));
    if (ctx.top_channel)   rows.push(statRow('Top channel',           ctx.top_channel.value,   ctx.top_channel.sub));
    if (ctx.top_pack)      rows.push(statRow('Top pack size',         ctx.top_pack.value,      ctx.top_pack.sub));
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
    if (!body) return;
    if (!snap || !snap.brand_summary) {
      body.innerHTML = '<div class="brsum-card-empty">Brand summary metrics not available.</div>';
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

  function renderWOMCard(root, snap) {
    var body = cardBody(root, 'wom');
    if (!body) return;
    if (!snap || !snap.wom) {
      body.innerHTML = '<div class="brsum-card-empty">Word-of-mouth not available.</div>';
      return;
    }
    var col = snap.colour || '#1A5276';
    body.innerHTML = '<div class="brsum-vchip-grid brsum-vchip-grid-single">' +
      valueChip(snap.wom.label, snap.wom.value, snap.wom.cat_avg, col, '') +
    '</div>';
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
