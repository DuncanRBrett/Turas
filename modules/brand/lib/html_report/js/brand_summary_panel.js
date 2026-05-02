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
      renderHeadline(root, snap);
      renderContext(root, cat.context);
      renderFocal(root, snap);
      renderDiagnostic(root, snap);
      // Apply colour again post-render (focal cards just rebuilt)
      if (snap && snap.colour) {
        $$('.brsum-focal-value', root).forEach(function (el) {
          el.style.color = snap.colour;
        });
      }
      dashboard.classList.remove('brsum-fading');
    }, 200);
  }

  function renderHeadline(root, snap) {
    var el = root.querySelector('[data-brsum-headline]');
    if (!el) return;
    if (!snap || !snap.headline) {
      el.textContent = '—';
      return;
    }
    // Inline-emphasise the brand name
    var html = escHtml(snap.headline);
    if (snap.name) {
      var brandHtml = '<span class="brsum-headline-focal">' +
                      escHtml(snap.name) + '</span>';
      // Replace first occurrence of the escaped brand name with the styled span
      html = html.replace(escHtml(snap.name), brandHtml);
    }
    el.innerHTML = html;
  }

  function renderContext(root, ctx) {
    var el = root.querySelector('[data-brsum-context]');
    if (!el) return;
    if (!ctx) { el.innerHTML = '<div class="brsum-empty-note">Category context not available.</div>'; return; }

    var entries = [];
    if (ctx.avg_purchases) entries.push(chip('Avg purchase frequency', ctx.avg_purchases.value, ctx.avg_purchases.sub));
    if (ctx.avg_brands)    entries.push(chip('Avg brands per buyer',   ctx.avg_brands.value,    ctx.avg_brands.sub));
    if (ctx.top_channel)   entries.push(chip('Top channel',            ctx.top_channel.value,   ctx.top_channel.sub));
    if (ctx.top_pack)      entries.push(chip('Top pack size',          ctx.top_pack.value,      ctx.top_pack.sub));

    if (entries.length === 0) {
      el.innerHTML = '<div class="brsum-empty-note">Category context metrics not available for this category.</div>';
      return;
    }
    el.innerHTML = entries.join('');
  }

  function chip(label, value, sub) {
    return '<div class="brsum-context-chip">' +
             '<div class="brsum-context-label">' + escHtml(label) + '</div>' +
             '<div class="brsum-context-value">' + escHtml(value) + '</div>' +
             (sub ? '<div class="brsum-context-sub">' + escHtml(sub) + '</div>' : '') +
           '</div>';
  }

  function renderFocal(root, snap) {
    var el = root.querySelector('[data-brsum-focal]');
    if (!el) return;
    if (!snap || !snap.focal_metrics) { el.innerHTML = ''; return; }

    var html = '';
    for (var i = 0; i < snap.focal_metrics.length; i++) {
      var m = snap.focal_metrics[i];
      html += '<div class="brsum-focal-card">' +
                (m.rank ? '<span class="brsum-rank-badge">' + escHtml(m.rank) + '</span>' : '') +
                '<div class="brsum-focal-label">' + escHtml(m.label) + '</div>' +
                '<div class="brsum-focal-value" style="color:' + escHtml(snap.colour || '#1A5276') + '">' + escHtml(m.value) + '</div>' +
                (m.cat_avg && m.cat_avg !== '—'
                  ? '<div class="brsum-focal-cat-avg">cat avg <span class="brsum-focal-cat-avg-num">' + escHtml(m.cat_avg) + '</span></div>'
                  : '') +
              '</div>';
    }
    el.innerHTML = html;
  }

  function renderDiagnostic(root, snap) {
    var attrEl = root.querySelector('[data-brsum-attr-chips]');
    var cepEl = root.querySelector('[data-brsum-cep-chips]');
    if (attrEl) attrEl.innerHTML = renderChipList(snap && snap.diagnostic ? snap.diagnostic.attributes : null);
    if (cepEl)  cepEl.innerHTML  = renderChipList(snap && snap.diagnostic ? snap.diagnostic.ceps : null);
  }

  function renderChipList(items) {
    if (!items || items.length === 0) {
      return '<span class="brsum-empty-note">No standout entries above the category average.</span>';
    }
    var html = '';
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      var d = it.delta;
      var deltaTxt = (d > 0 ? '+' : '') + d;
      var cls = (d > 0) ? 'brsum-chip-delta' : 'brsum-chip-delta neg';
      html += '<span class="brsum-chip">' +
                escHtml(it.label) +
                ' <span class="' + cls + '">' + deltaTxt + '</span>' +
              '</span>';
    }
    return html;
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
