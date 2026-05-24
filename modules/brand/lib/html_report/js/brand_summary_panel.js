/* =============================================================================
 * BRAND MODULE — EXECUTIVE SUMMARY PANEL JS
 * -----------------------------------------------------------------------------
 * SIZE-EXCEPTION: this file is the full set of card renderers for the
 * summary panel. Each renderer is short, but they share helpers (escHtml,
 * cardBody, valueChip, dopRow, womColumn, fmtPctSingle) and a single
 * orchestrator (`render()`) — splitting across files would force the
 * orchestrator to import the helpers from another file purely to keep
 * line counts down, with no readability win.
 *
 * Reads the per-(category, brand) JSON payload embedded in
 * <script type="application/json" class="brsum-data"> and renders the
 * 6-card narrative dashboard when the user changes either dropdown.
 *
 * Card renderers (in render-order):
 *   renderFocalContext       — header strip (focal name + cat label)
 *   renderHeroCard           — auto-headline + 4 anchor numbers
 *   renderMentalCard         — MMS / SoM / Network Size value-chips
 *   renderPhysicalCard       — collapsed funnel (mini-funnel renderer)
 *   renderWorkingCard / renderWeakCard
 *                            — top/bottom-3 CEPs + attributes by
 *                              advantage_pp (shared renderAdvantageCard)
 *   renderConversationCard   — WOM (heard/said) + DoP partners/rivals
 *
 * Public functions exposed on window:
 *   brsumSwitchCat(catName)     — programmatic category change (used by
 *                                 the closing-strip mini-cards)
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

    // Resolve brand colour. Priority: brand_colours_map[code] (Brands-sheet
    // Colour column — single source of truth) → focal_colour iff this brand
    // IS the project focal AND has no map entry (legacy fallback) → hash.
    // The user-selected focal does NOT change the colour: every brand keeps
    // its own colour from the map regardless of which brand is being viewed.
    var brandColour = (snap && snap.colour) ? snap.colour : '#1A5276';
    if (typeof TurasColours !== 'undefined' && brandCode) {
      try {
        var pdLike = {
          config: {
            brand_colours: payload.brand_colours_map || {},
            focal_colour: payload.focal_colour
          },
          meta: { focal_brand_code: payload.focal_brand_code ||
                                    payload.default_brand }
        };
        brandColour = TurasColours.getBrandColour(pdLike, brandCode) || brandColour;
      } catch (e) { /* fallback already set */ }
    }
    snap.colour = brandColour;
    root.style.setProperty('--brsum-brand-colour', brandColour);

    dashboard.classList.add('brsum-fading');
    setTimeout(function () {
      /* 6-card narrative layout. Each renderer reads the payload and
         fills its own card body — they're independent so any single
         card can degrade to "data not available" without breaking
         the rest. Order matches the visual top-to-bottom flow. */
      renderFocalContext(root, snap, cat, catName);
      renderHeroCard(root, snap, cat, catName, brandCode);
      renderMentalCard(root, snap);
      renderFunnelCard(root, cat.funnel, brandCode, snap);
      renderWorkingCard(root, cat, brandCode, snap);
      renderWeakCard(root, cat, brandCode, snap);
      renderWomCard(root, snap);
      renderRepertoireCard(root, cat.dop, brandCode);
      /* Apply focal colour to any value text rendered inline. */
      if (snap && snap.colour) {
        $$('.brsum-focal-value', root).forEach(function (el) {
          el.style.color = snap.colour;
        });
      }
      dashboard.classList.remove('brsum-fading');
    }, 200);

    /* Closing strip: re-render outside the fade so it updates immediately
       on brand change. Spelled-out metric names + active-brand-specific
       numbers — Duncan's v1.1 polish. */
    renderClosingStrip(root, brandCode);
  }


  /* -------------------------------------------------------------------------
   * Closing strip: <brand> across all categories.
   *
   * One mini-card per deep-dive category; each card pulls Mental Market
   * Share / Mental Penetration / Bought past 3 months for the currently
   * selected brand from payload.categories[cat].brands[brand]. Re-runs on
   * every brand-picker change so the strip always reflects the dropdown,
   * not the config-time focal.
   * ------------------------------------------------------------------------- */
  function renderClosingStrip(root, brandCode) {
    var closing = root.querySelector('[data-brsum-closing]');
    if (!closing) return;
    var payload = root.__brsumPayload;
    if (!payload || !payload.categories) return;

    /* Resolve the brand's display name from any category's snap. */
    var brandName = brandCode;
    var cats = payload.categories;
    var firstName = null;
    Object.keys(cats).some(function (cn) {
      var snap = cats[cn] && cats[cn].brands && cats[cn].brands[brandCode];
      if (snap && snap.name) { firstName = snap.name; return true; }
      return false;
    });
    if (firstName) brandName = firstName;

    var title = closing.querySelector('[data-brsum-closing-title]');
    if (title) title.textContent = brandName + ' across all categories';

    var cards = closing.querySelectorAll('[data-brsum-mini-cat]');
    cards.forEach(function (card) {
      var cn = card.getAttribute('data-brsum-mini-cat');
      var snap = cats[cn] && cats[cn].brands && cats[cn].brands[brandCode];
      var fm = (snap && snap.focal_metrics) ? snap.focal_metrics : null;
      var mms  = (fm && fm[0]) ? fm[0].value : '—';
      var mpen = (fm && fm[1]) ? fm[1].value : '—';
      var bt   = (fm && fm[2]) ? fm[2].value : '—';
      var setVal = function (sel, v) {
        var el = card.querySelector('[data-brsum-mini-metric="' + sel + '"]');
        if (el) el.innerHTML = (v == null || v === '') ? '—' : escHtml(String(v));
      };
      setVal('mms',  mms);
      setVal('mpen', mpen);
      setVal('bt',   bt);
    });
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

  /* Attribute-safe escape for tooltips / titles (different rules to text). */
  function escAttr(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
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

  /* ---------------------------------------------------------------------
   * Hero card — the headline. Auto-generated single-sentence verdict
   * + 4 anchor numbers (MMS / MPen / % bought / SCR), all on the focal
   * brand. Sets the story for everything below.
   * --------------------------------------------------------------------- */
  function renderHeroCard(root, snap, cat, catName, brandCode) {
    var body = cardBody(root, 'hero');
    if (!body) return;
    if (!snap) {
      body.innerHTML = '<div class="brsum-card-empty">No data for this brand.</div>';
      return;
    }
    var col      = snap.colour || '#1A5276';
    var fname    = snap.name || brandCode || 'Focal brand';
    var anchors  = heroAnchors(snap);
    var verdict  = heroHeadline(snap, cat, catName, fname, anchors);
    var rankBadge = anchors.mms_rank
      ? '<div class="brsum-hero-rank">#' + escHtml(anchors.mms_rank) +
          ' by MMS in ' + escHtml(catName) + '</div>'
      : '';
    var anchorsHtml = [
      heroAnchor('Mental Market Share', anchors.mms,   anchors.mms_avg,  col),
      heroAnchor('Mental Penetration',  anchors.mpen,  anchors.mpen_avg, col),
      heroAnchor('% who bought',        anchors.pen,   anchors.pen_avg,  col),
      heroAnchor('Loyalty (SCR)',       anchors.scr,   anchors.scr_avg,  col)
    ].join('');
    body.innerHTML =
      '<div class="brsum-hero">' +
        rankBadge +
        '<div class="brsum-hero-verdict">' + escHtml(verdict) + '</div>' +
        '<div class="brsum-hero-anchors">' + anchorsHtml + '</div>' +
      '</div>';
  }

  function heroAnchor(label, value, catAvg, colour) {
    return '<div class="brsum-hero-anchor">' +
             '<div class="brsum-hero-anchor-v brsum-focal-value" style="color:' + colour + '">' +
               escHtml(value || '—') + '</div>' +
             '<div class="brsum-hero-anchor-l">' + escHtml(label) + '</div>' +
             (catAvg && catAvg !== '—'
               ? '<div class="brsum-hero-anchor-a">cat avg ' + escHtml(catAvg) + '</div>'
               : '') +
           '</div>';
  }

  /* Resolve the 4 anchor numbers + rank from the snapshot. Falls back to
     a "—" string when the source field is missing or NA. */
  function heroAnchors(snap) {
    var out = { mms: '—', mms_avg: '—', mms_rank: null,
                mpen: '—', mpen_avg: '—',
                pen:  '—', pen_avg:  '—',
                scr:  '—', scr_avg:  '—' };
    if (snap.ma_metrics && snap.ma_metrics.length) {
      for (var i = 0; i < snap.ma_metrics.length; i++) {
        var m = snap.ma_metrics[i];
        var lab = (m.label || '').toLowerCase();
        if (lab.indexOf('mental market share') >= 0 || lab === 'mms') {
          out.mms = m.value; out.mms_avg = m.cat_avg;
          if (m.rank) out.mms_rank = m.rank;
        } else if (lab.indexOf('mental penetration') >= 0 || lab === 'mpen') {
          out.mpen = m.value; out.mpen_avg = m.cat_avg;
        }
      }
    }
    if (snap.brand_summary && snap.brand_summary.length) {
      for (var j = 0; j < snap.brand_summary.length; j++) {
        var s = snap.brand_summary[j];
        var sl = (s.label || '').toLowerCase();
        if (sl.indexOf('penetration') >= 0 || sl.indexOf('% who bought') >= 0 ||
            sl === '% bought' || sl === 'pen') {
          out.pen = s.value; out.pen_avg = s.cat_avg;
        } else if (sl.indexOf('scr') >= 0 || sl.indexOf('loyalty') >= 0) {
          out.scr = s.value; out.scr_avg = s.cat_avg;
        }
      }
    }
    return out;
  }

  /* Auto-headline. Picks one of a small set of fact-driven templates
     based on MMS rank, MPen-vs-cat-avg, and pen-vs-cat-avg. Never
     generates flowery prose — every output is a direct fact statement
     the reader can verify against the anchor numbers above. */
  function heroHeadline(snap, cat, catName, fname, a) {
    var rank   = a.mms_rank ? parseInt(a.mms_rank, 10) : null;
    var nBrands = (cat && cat.n_brands) ? cat.n_brands : null;
    var mpenCmp = compareToAvg(a.mpen, a.mpen_avg);
    var penCmp  = compareToAvg(a.pen,  a.pen_avg);
    var rankClause = '';
    if (rank === 1) rankClause = fname + ' is the category leader by Mental Market Share in ' + catName + '.';
    else if (rank === 2 || rank === 3) rankClause = fname + ' ranks #' + rank + ' by MMS in ' + catName + '.';
    else if (rank && nBrands && rank >= Math.ceil(nBrands * 0.75))
      rankClause = fname + ' sits at #' + rank + ' of ' + nBrands + ' by MMS in ' + catName + ' — bottom-quartile mental position.';
    else if (rank) rankClause = fname + ' ranks #' + rank + (nBrands ? ' of ' + nBrands : '') + ' by MMS in ' + catName + '.';
    else rankClause = fname + ' in ' + catName + '.';

    /* Verdict clause — adds one fact about the brand vs cat avg. */
    var verdictClause = '';
    if (mpenCmp === 'above' && penCmp === 'above')
      verdictClause = ' Strong on both mental (MPen) and physical (% bought) availability.';
    else if (mpenCmp === 'above' && penCmp === 'below')
      verdictClause = ' Mental availability is above the category average, but physical purchase is lagging — a conversion gap.';
    else if (mpenCmp === 'below' && penCmp === 'above')
      verdictClause = ' Punching above its mental availability on physical purchase — but the mental base is the constraint.';
    else if (mpenCmp === 'below' && penCmp === 'below')
      verdictClause = ' Below the category average on both mental and physical availability.';
    else verdictClause = '';
    return rankClause + verdictClause;
  }

  /* Comparison helper. Strips % / digits-only-with-comma formatting and
     compares numerically. Returns 'above' / 'at' / 'below' or null. */
  function compareToAvg(v, avg) {
    var nv = parseNumericLike(v);
    var na = parseNumericLike(avg);
    if (nv == null || na == null) return null;
    if (nv > na * 1.05) return 'above';
    if (nv < na * 0.95) return 'below';
    return 'at';
  }
  function parseNumericLike(s) {
    if (s == null) return null;
    var t = String(s).replace(/[%,\s]/g, '').replace(/[^\d.\-]/g, '');
    if (!t) return null;
    var n = parseFloat(t);
    return isNaN(n) ? null : n;
  }

  /* ---------------------------------------------------------------------
   * Mental availability card — MMS / SoM / Network Size value-chips,
   * each with cat-avg under and a leader badge / leader name. Same
   * value-chip widget as the old MA card; just narrower scope.
   * --------------------------------------------------------------------- */
  function renderMentalCard(root, snap) {
    var body = cardBody(root, 'mental');
    if (!body) return;
    if (!snap || !snap.ma_metrics || !snap.ma_metrics.length) {
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

  /* ---------------------------------------------------------------------
   * Buying funnel card — collapsed Aware -> Prefer -> Bought funnel.
   * The label was "Physical conversion" in the first cut — corrected:
   * these stages are all CLAIMED BUYING (% who say they're aware, who
   * prefer, who bought in N months). Physical availability (in-store
   * distribution) is not measured in this study. Reuses the mini-funnel
   * renderer (focal + cat-avg side-by-side, stacked stage bars).
   * --------------------------------------------------------------------- */
  function renderFunnelCard(root, funnelBlock, brandCode, snap) {
    renderMiniFunnelCard(root, 'funnel', funnelBlock, brandCode, snap,
      { emptyMessage: 'Funnel data not available.' });
  }

  /* ---------------------------------------------------------------------
   * What's working card — top-3 CEPs + top-3 attributes the focal brand
   * over-indexes on (by advantage_pp, focal value minus cat avg in pp).
   * Two columns side-by-side. Each item shows label, focal value, cat
   * avg, signed delta.
   * --------------------------------------------------------------------- */
  function renderWorkingCard(root, cat, brandCode, snap) {
    renderAdvantageCard(root, 'working', cat, brandCode, snap, 'top');
  }
  function renderWeakCard(root, cat, brandCode, snap) {
    renderAdvantageCard(root, 'weak', cat, brandCode, snap, 'bottom');
  }

  /* Shared engine for the Working / Weak cards. direction = 'top' takes
     the 3 items with the largest positive advantage_pp; 'bottom' takes
     the 3 with the largest negative advantage_pp. CEP + attributes
     render side-by-side. Each side falls back to "no items in this
     direction" when no qualifying entry exists. */
  function renderAdvantageCard(root, key, cat, brandCode, snap, direction) {
    var body = cardBody(root, key);
    if (!body) return;
    var col = (snap && snap.colour) || '#1A5276';
    var cepHtml  = advantageCol(cat.cep,   brandCode, direction, col, 'CEPs');
    var attrHtml = advantageCol(cat.attrs, brandCode, direction, col, 'Attributes');
    if (!cepHtml && !attrHtml) {
      body.innerHTML = '<div class="brsum-card-empty">Mental Availability data not available.</div>';
      return;
    }
    var blurb = direction === 'top'
      ? 'CEPs and attributes this brand <strong>over-indexes</strong> on — its link rate is higher than the category average. Source: Mental Availability battery (% of respondents linking each item to the brand). Ranked by the gap to the category average, biggest positive first.'
      : 'CEPs and attributes this brand <strong>under-indexes</strong> on — its link rate is lower than the category average. Source: Mental Availability battery (% of respondents linking each item to the brand). Ranked by the gap to the category average, biggest negative first.';
    body.innerHTML =
      '<p class="brsum-card-blurb">' + blurb + '</p>' +
      '<div class="brsum-adv-grid">' +
        (cepHtml  || '<div class="brsum-adv-col brsum-adv-empty">No CEP data.</div>') +
        (attrHtml || '<div class="brsum-adv-col brsum-adv-empty">No attribute data.</div>') +
      '</div>';
  }

  function advantageCol(block, brandCode, direction, col, title) {
    if (!block || !block.available) return '';
    var brand = block.brands && block.brands[brandCode];
    if (!brand) return '';
    var stims  = block.stim_codes  || [];
    var labels = block.stim_labels || stims;
    var avgs   = block.cat_avg_pct || [];
    var fps    = brand.focal_pct   || [];
    /* Delta is computed as focal_pct - cat_avg_pct so the displayed +/-pp
       matches the displayed focal and cat-avg values exactly. We do NOT
       use brand.advantage_pp here — that's the MA engine's own advantage
       metric (focal minus a model-based expected value), which would not
       equal focal-minus-cat-avg and would confuse the reader who reads
       both numbers off the row. The MA decision (Defend / Build /
       Maintain) lives on the deep-dive MA tab; the Summary card uses
       the simpler arithmetic delta. */
    var ranked = [];
    for (var i = 0; i < stims.length; i++) {
      var fv = fps[i], av = avgs[i];
      if (fv == null || isNaN(fv) || av == null || isNaN(av)) continue;
      var delta = fv - av;
      ranked.push({ idx: i, delta: delta });
    }
    if (!ranked.length) return '';
    ranked.sort(function (a, b) {
      return direction === 'top' ? b.delta - a.delta : a.delta - b.delta;
    });
    /* Drop wrong-sign rows so the "Working" card never lists negatives
       and "Weak" never lists positives — those don't fit the heading. */
    ranked = ranked.filter(function (r) {
      return direction === 'top' ? r.delta > 0 : r.delta < 0;
    });
    if (!ranked.length) {
      return '<div class="brsum-adv-col">' +
               '<div class="brsum-adv-coltitle">' + escHtml(title) + '</div>' +
               '<div class="brsum-adv-empty">No ' +
                 (direction === 'top' ? 'over-indexers' : 'under-indexers') +
               ' for this brand.</div>' +
             '</div>';
    }
    ranked = ranked.slice(0, 3);
    var rows = ranked.map(function (r) {
      var i = r.idx;
      var fv = fps[i], av = avgs[i], delta = r.delta;
      var deltaTxt = (delta >= 0 ? '+' : '') + delta.toFixed(1) + 'pp';
      return '<li class="brsum-adv-item ' +
               (direction === 'top' ? 'is-over' : 'is-under') + '">' +
               '<span class="brsum-adv-label">' +
                 escHtml(labels[i] || stims[i]) + '</span>' +
               '<span class="brsum-adv-focal" style="color:' + col + '">' +
                 Math.round(fv) + '%</span>' +
               '<span class="brsum-adv-cat">vs ' +
                 Math.round(av) + '% avg</span>' +
               '<span class="brsum-adv-delta">' + deltaTxt + '</span>' +
             '</li>';
    }).join('');
    return '<div class="brsum-adv-col">' +
             '<div class="brsum-adv-coltitle">' + escHtml(title) + '</div>' +
             '<ul class="brsum-adv-list">' + rows + '</ul>' +
           '</div>';
  }

  /* ---------------------------------------------------------------------
   * Word of mouth card — Heard + Said columns (positive / negative / net
   * per side), each row showing focal value + cat avg under. Uses the
   * shared womColumn / womRow helpers. The original cut combined this
   * with DoP partners/rivals in one card — split per Duncan's review.
   * --------------------------------------------------------------------- */
  function renderWomCard(root, snap) {
    var body = cardBody(root, 'conversation');
    if (!body) return;
    if (!snap || !snap.wom || !snap.wom.available) {
      body.innerHTML = '<div class="brsum-card-empty">Word of mouth not available.</div>';
      return;
    }
    var w = snap.wom;
    body.innerHTML =
      '<div class="brsum-wom-grid">' +
        womColumn('Heard', w.heard) +
        womColumn('Said',  w.said)  +
      '</div>';
  }

  /* ---------------------------------------------------------------------
   * Repertoire ties card — top 2 DoP partners + top 2 rivals for the
   * focal brand. Partners over-index, rivals under-index, both measured
   * vs the column average across other brand rows (the partition-card
   * metric on the DoP sub-tab). Split out from the merged "Conversation
   * & competitive ties" card so the WOM read and the repertoire read
   * each get their own real estate.
   * --------------------------------------------------------------------- */
  function renderRepertoireCard(root, dopBlock, brandCode) {
    var body = cardBody(root, 'repertoire');
    if (!body) return;
    if (!dopBlock || !dopBlock.available) {
      body.innerHTML = '<div class="brsum-card-empty">Duplication of purchase data not available.</div>';
      return;
    }
    var brand = dopBlock.brands && dopBlock.brands[brandCode];
    if (!brand) {
      body.innerHTML = '<div class="brsum-card-empty">No DoP data for this brand.</div>';
      return;
    }
    var partners = (brand.partners || []).slice(0, 2);
    var rivals   = (brand.rivals   || []).slice(0, 2);
    var partnersHtml = partners.length
      ? '<ul class="brsum-dop-list">' +
          partners.map(function (p) { return dopRow(p, true);  }).join('') +
        '</ul>'
      : '<div class="brsum-dop-empty">No over-indexing partners.</div>';
    var rivalsHtml = rivals.length
      ? '<ul class="brsum-dop-list">' +
          rivals.map(function (p) { return dopRow(p, false); }).join('') +
        '</ul>'
      : '<div class="brsum-dop-empty">No under-indexing rivals.</div>';
    body.innerHTML =
      '<p class="brsum-card-blurb">' +
        'Among this brand’s buyers, who else ends up in the basket? ' +
        '<strong>Partners</strong> show up more than their overall popularity predicts — ' +
        'natural co-buys. <strong>Rivals</strong> show up less — head-to-head substitutes. ' +
        'Percentage points (pp) compare each brand’s share among focal buyers with its share across the whole category.' +
      '</p>' +
      '<div class="brsum-conv-dop-row">' +
        '<div class="brsum-conv-dop-side">' +
          '<div class="brsum-conv-dop-side-title">Partners — over-index</div>' +
          partnersHtml +
        '</div>' +
        '<div class="brsum-conv-dop-side">' +
          '<div class="brsum-conv-dop-side-title">Rivals — under-index</div>' +
          rivalsHtml +
        '</div>' +
      '</div>';
  }

  /* WOM column helpers — shared by renderConversationCard. */
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

  /* DoP row helper — shared by renderConversationDop. */
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
