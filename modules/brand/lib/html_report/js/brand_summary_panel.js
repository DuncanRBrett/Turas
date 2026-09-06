/* =============================================================================
 * BRAND MODULE: EXECUTIVE SUMMARY PANEL JS
 * -----------------------------------------------------------------------------
 * SIZE-EXCEPTION: this file is the full set of card renderers for the
 * summary panel. Each renderer is short, but they share helpers (escHtml,
 * cardBody, valueChip, dopRow, womColumn, fmtPctSingle) and a single
 * orchestrator (`render()`): splitting across files would force the
 * orchestrator to import the helpers from another file purely to keep
 * line counts down, with no readability win.
 *
 * Reads the per-(category, brand) JSON payload embedded in
 * <script type="application/json" class="brsum-data"> and renders the
 * 6-card narrative dashboard when the user changes either dropdown.
 *
 * Card renderers (in render-order):
 *   renderFocalContext: header strip (focal name + cat label)
 *   renderHeroCard, auto-headline + 4 anchor numbers
 *   renderMentalCard, MMS / SoM / Network Size value-chips
 *   renderPhysicalCard, collapsed funnel (mini-funnel renderer)
 *   renderWorkingCard / renderWeakCard
 *, top/bottom-3 CEPs + attributes by
 *                              advantage_pp (shared renderAdvantageCard)
 *   renderConversationCard, WOM (heard/said) + DoP partners/rivals
 *
 * Public functions exposed on window:
 *   brsumSwitchCat(catName): programmatic category change (used by
 *                                 the closing-strip mini-cards)
 *   brsumInsertMd(before,after), markdown toolbar handler (insight editor)
 *   brsumRenderInsight(), re-render markdown preview
 *   brsumToggleEdu(btn), collapse/expand educational callout
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
    // Colour column, single source of truth) → focal_colour iff this brand
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
         fills its own card body. They're independent so any single
         card can degrade to "data not available" without breaking
         the rest. Order matches the visual top-to-bottom flow. */
      renderFocalContext(root, snap, cat, catName);
      renderHeroCard(root, snap, cat, catName, brandCode);
      renderMentalCard(root, snap);
      renderFunnelCard(root, cat.funnel, brandCode, snap);
      renderWorkingCard(root, cat, brandCode, snap);
      renderWeakCard(root, cat, brandCode, snap);
      renderOpportunitiesCard(root, cat, brandCode, snap);
      renderWomCard(root, snap);
      renderRepertoireCard(root, cat.dop, brandCode);
      renderPenetrationNotes(root, cat);
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
       numbers, Duncan's v1.1 polish. */
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
      var mms  = (fm && fm[0]) ? fm[0].value : '–';
      var mpen = (fm && fm[1]) ? fm[1].value : '–';
      var bt   = (fm && fm[2]) ? fm[2].value : '–';
      var setVal = function (sel, v) {
        var el = card.querySelector('[data-brsum-mini-metric="' + sel + '"]');
        if (el) el.innerHTML = (v == null || v === '') ? '–' : escHtml(String(v));
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
    body.innerHTML = '<div class="brsum-card-empty">' + escHtml(msg || '–') + '</div>';
  }

  function renderFocalContext(root, snap, cat, catName) {
    var brandEl = root.querySelector('[data-brsum-fc-brand]');
    var catEl   = root.querySelector('[data-brsum-fc-cat]');
    if (brandEl) brandEl.textContent = (snap && snap.name) ? snap.name : '–';
    if (catEl)   catEl.textContent   = catName || (cat && cat.label) || '–';
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
             (catAvg && catAvg !== '–'
               ? '<div class="brsum-vchip-catavg">cat avg <span>' + escHtml(catAvg) + '</span></div>'
               : '') +
             (leaderHtml || '') +
           '</div>';
  }

  /* ---------------------------------------------------------------------
   * Hero card: the headline. Auto-generated single-sentence verdict
   * + 4 anchor numbers (MMS / MPen / % bought / SCR), all on the focal
   * brand. Sets the story for everything below.
   * --------------------------------------------------------------------- */
  /* The tile markup is emitted by R, once, and this fills it. That is the
     Mental Availability hero-card pattern and it keeps the comparison slot
     in one place: br_compare_slot() in panels/00_json_island.R writes the
     element and its data-compare-source, and nothing here builds a second
     copy of that markup or hard-codes the words "vs category average". */
  function renderHeroCard(root, snap, cat, catName, brandCode) {
    var body = cardBody(root, 'hero');
    if (!body) return;
    var strip   = body.querySelector('[data-brsum-tiles]');
    var verdict = body.querySelector('[data-brsum-verdict-body]');

    if (!snap) {
      if (verdict) verdict.innerHTML =
        '<div class="brsum-card-empty">No data for this brand.</div>';
      if (strip) $$('.brsum-tile', strip).forEach(function (t) {
        setTileValue(t, null, null, null);
      });
      return;
    }

    var col     = snap.colour || '#1A5276';
    var fname   = snap.name || brandCode || 'Focal brand';
    var anchors = heroAnchors(snap);
    var tiles   = tileFacts(anchors, cat);

    if (strip) {
      $$('.brsum-tile', strip).forEach(function (tile) {
        var key = tile.getAttribute('data-brsum-tile');
        var f = tiles[key];
        if (!f) return;
        if (f.label) {
          var lab = tile.querySelector('[data-brsum-tile-label]');
          if (lab) lab.textContent = f.label;
        }
        setTileValue(tile, f.value, f.catAvg, f.rank, col);
      });
    }

    if (verdict) {
      verdict.innerHTML = heroHeadline(snap, cat, catName, fname, anchors)
        .map(function (s) { return '<p>' + escHtml(s) + '</p>'; }).join('');
    }
  }

  /* Fill one tile. An absent figure is an en dash, never a zero and never a
     borrowed value. When the comparison figure is absent the slot says so by
     switching its source to "none", so a reader and a later wave build can
     both tell an empty slot from a real comparison. */
  function setTileValue(tile, value, catAvg, rank, colour) {
    var v = tile.querySelector('[data-brsum-tile-value]');
    if (v) {
      v.textContent = (value == null || value === '') ? '–' : value;
      if (colour) v.style.color = colour;
    }
    var slot = tile.querySelector('[data-compare-slot]');
    if (slot) {
      var cv = slot.querySelector('.br-compare-value');
      var has = catAvg != null && catAvg !== '' && catAvg !== '–';
      if (cv) cv.textContent = has ? catAvg : '–';
      slot.setAttribute('data-compare-source', has ? 'category-average' : 'none');
    }
    var r = tile.querySelector('[data-brsum-tile-rank]');
    if (r) {
      if (rank && rank.rank) {
        r.textContent = 'Rank ' + rank.rank +
          (rank.of ? ' of ' + rank.of : '') + ' in the category';
        r.hidden = false;
      } else {
        r.textContent = '';
        r.hidden = true;
      }
    }
  }

  /* What each headline tile shows. Four tiles, keyed on the tile ids the R
     skeleton emits. Only Mental Market Share carries a rank: it is the only
     metric the payload ranks, and ranking another one here would be a new
     computation on a different base to the one the MA tab reports. */
  function tileFacts(a, cat) {
    return {
      mpen: { value: a.mpen, catAvg: a.mpen_avg },
      mms:  { value: a.mms,  catAvg: a.mms_avg,
              rank: { rank: a.mms_rank, of: a.mms_rank_of } },
      bt:   { value: a.bt,   catAvg: a.bt_avg,
              label: boughtWindowLabel(cat) },
      scr:  { value: a.scr,  catAvg: a.scr_avg }
    };
  }

  /* The bought-window tile takes its wording from the funnel's own stage
     label, so a study whose target window is not three months reads its own
     words. With no funnel the static label in the skeleton stands. */
  function boughtWindowLabel(cat) {
    var f = cat && cat.funnel;
    if (!f || !f.available || !f.stage_keys || !f.stage_labels) return null;
    var i = f.stage_keys.indexOf('bought_target');
    if (i < 0 || !f.stage_labels[i]) return null;
    return 'Bought, ' + String(f.stage_labels[i]).toLowerCase();
  }

  /* Route from a headline tile to the destination that holds its evidence.
     The category tab id rides on the selected <option> as data-cat-id, put
     there by the R skeleton, so nothing has to guess it from a label. */
  window.brsumGoTo = function (el) {
    var host = el && el.closest ? el.closest('[data-brsum-dest]') : null;
    var dest = host ? host.getAttribute('data-brsum-dest') : null;
    var root = document.querySelector('.brsum-root');
    var sel  = root ? root.querySelector('[data-brsum-cat]') : null;
    var opt  = (sel && sel.selectedIndex >= 0) ? sel.options[sel.selectedIndex] : null;
    var catId = opt ? opt.getAttribute('data-cat-id') : null;
    if (!dest || !catId) return;
    if (typeof window.switchBrandTab === 'function') {
      window.switchBrandTab('cat-' + catId);
    }
    var btn = document.querySelector(
      '.br-destination-btn[data-group="' + catId + '"][data-destination="' + dest + '"]');
    if (btn && typeof window.switchBrandDestination === 'function') {
      window.switchBrandDestination(btn);
    }
  };

  /* Normalise whatever a payload carries for a rank into { rank, of }.
     The R payload writes the MMS rank as the string "Rank 1 / 15" on
     snap.focal_metrics; earlier code looked for a bare number on
     snap.ma_metrics, where no rank field has ever been written, so the
     rank badge and the rank clause never rendered. This reader accepts
     every shape the payload could carry: a number, "Rank 1 / 15",
     "#1 of 15", "1/15", or an object with rank / of fields. Anything it
     cannot read returns nulls, and the caller renders no rank rather
     than a guessed one. */
  function parseRank(v) {
    var out = { rank: null, of: null };
    if (v == null) return out;
    if (typeof v === 'number') {
      if (isFinite(v) && v > 0) out.rank = Math.round(v);
      return out;
    }
    if (typeof v === 'object') {
      var r = parseRank(v.rank);
      out.rank = r.rank;
      var o = parseRank(v.of != null ? v.of : v.n);
      out.of = o.rank;
      return out;
    }
    var nums = String(v).match(/\d+/g);
    if (!nums || !nums.length) return out;
    out.rank = parseInt(nums[0], 10);
    if (nums.length > 1) out.of = parseInt(nums[1], 10);
    if (!isFinite(out.rank) || out.rank <= 0) { out.rank = null; out.of = null; }
    if (out.of != null && (!isFinite(out.of) || out.of <= 0)) out.of = null;
    return out;
  }

  /* Find one entry in a metric list by matching its label. */
  function metricByLabel(list, needles) {
    if (!list || !list.length) return null;
    for (var i = 0; i < list.length; i++) {
      var lab = (list[i].label || '').toLowerCase();
      for (var j = 0; j < needles.length; j++) {
        if (lab.indexOf(needles[j]) >= 0) return list[i];
      }
    }
    return null;
  }

  /* Resolve the 4 anchor numbers + rank from the snapshot. Falls back to
     a "–" string when the source field is missing or NA. */
  function heroAnchors(snap) {
    var out = { mms: '–', mms_avg: '–', mms_rank: null, mms_rank_of: null,
                mpen: '–', mpen_avg: '–',
                pen:  '–', pen_avg:  '–',
                bt:   '–', bt_avg:   '–',
                scr:  '–', scr_avg:  '–' };
    if (snap.ma_metrics && snap.ma_metrics.length) {
      for (var i = 0; i < snap.ma_metrics.length; i++) {
        var m = snap.ma_metrics[i];
        var lab = (m.label || '').toLowerCase();
        if (lab.indexOf('mental market share') >= 0 || lab === 'mms') {
          out.mms = m.value; out.mms_avg = m.cat_avg;
          if (m.rank) {
            var rm = parseRank(m.rank);
            out.mms_rank = rm.rank; out.mms_rank_of = rm.of;
          }
        } else if (lab.indexOf('mental penetration') >= 0 || lab === 'mpen') {
          out.mpen = m.value; out.mpen_avg = m.cat_avg;
        }
      }
    }
    /* The rank the R payload actually writes. focal_metrics carries it on
       the MMS entry as "Rank 1 / 15"; ma_metrics above is kept only as a
       fallback for a payload that starts carrying one there. */
    if (out.mms_rank == null) {
      var fm = metricByLabel(snap.focal_metrics, ['mental market share', 'mms']);
      if (fm && fm.rank) {
        var rf = parseRank(fm.rank);
        out.mms_rank = rf.rank; out.mms_rank_of = rf.of;
      }
    }
    /* The bought-in-the-target-window figure. It comes from focal_metrics,
       which reads the funnel's bought_target stage, so the tile's value and
       the tile's label share one source. brand_summary carries a second
       purchase figure on a different base; the "Which penetration is which"
       block in the drawer sets the two out side by side. */
    var bm = metricByLabel(snap.focal_metrics, ['bought target', 'bought']);
    if (bm) { out.bt = bm.value; out.bt_avg = bm.cat_avg; }
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

  /* "What the numbers say".
   *
   * The old title was "verdict" and two of its clauses read as diagnoses:
   * "That is a conversion gap", "punching above its mental availability".
   * Rules over four comparisons do not earn that, so every clause here is
   * the comparison stated flat, in the reader's own units, and each one is
   * omitted rather than softened when its figures are missing. Returns an
   * array of sentences; the caller renders one paragraph each.
   */
  function heroHeadline(snap, cat, catName, fname, a) {
    var out = [];
    var rank = a.mms_rank ? parseInt(a.mms_rank, 10) : null;
    /* The denominator the rank was computed against wins over the count of
       brands in the picker: the two diverge when a brand is in the picker
       but absent from the MMS table. */
    var nBrands = a.mms_rank_of || ((cat && cat.n_brands) ? cat.n_brands : null);
    var where = catName ? (' in ' + catName) : '';

    /* 1. Where the brand sits in the category, by the one metric that is
          ranked in the payload. */
    if (rank === 1) {
      out.push(fname + ' has the largest Mental Market Share' + where +
               (nBrands ? ', of ' + nBrands + ' brands measured' : '') + '.');
    } else if (rank && nBrands) {
      out.push(fname + ' ranks #' + rank + ' of ' + nBrands +
               ' on Mental Market Share' + where + '.');
    } else if (rank) {
      out.push(fname + ' ranks #' + rank + ' on Mental Market Share' + where + '.');
    } else {
      out.push(fname + where.replace(/^ in /, ' is measured in ') + '.');
    }

    /* 2. Mental against physical, stated as two comparisons rather than as
          a diagnosis of the gap between them. */
    var mpenCmp = compareToAvg(a.mpen, a.mpen_avg);
    var btCmp   = compareToAvg(a.bt,   a.bt_avg);
    if (mpenCmp && btCmp) {
      out.push('Mental Penetration is ' + cmpWords(mpenCmp) +
               ' the category average at ' + a.mpen + ' against ' + a.mpen_avg +
               '; the share who bought in the target window is ' +
               cmpWords(btCmp) + ' it at ' + a.bt + ' against ' + a.bt_avg + '.');
    } else if (mpenCmp) {
      out.push('Mental Penetration is ' + cmpWords(mpenCmp) +
               ' the category average at ' + a.mpen + ' against ' + a.mpen_avg + '.');
    } else if (btCmp) {
      out.push('The share who bought in the target window is ' + cmpWords(btCmp) +
               ' the category average at ' + a.bt + ' against ' + a.bt_avg + '.');
    }

    /* 3. Loyalty, on the same footing. */
    var scrCmp = compareToAvg(a.scr, a.scr_avg);
    if (scrCmp) {
      out.push('Share of Category Requirement is ' + cmpWords(scrCmp) +
               ' the category average at ' + a.scr + ' against ' + a.scr_avg +
               ': the share of its buyers’ category purchases the brand takes.');
    }

    /* 4. Whether the brand leads any Mental Availability measure. Read off
          the is_leader flag the payload already carries, not recomputed. */
    var leads = [];
    if (snap.ma_metrics && snap.ma_metrics.length) {
      for (var i = 0; i < snap.ma_metrics.length; i++) {
        if (snap.ma_metrics[i].is_leader) leads.push(snap.ma_metrics[i].label);
      }
    }
    if (leads.length) {
      out.push('It leads the category on ' + joinWords(leads) + '.');
    }

    /* 5. Word of mouth, when the category collected it. */
    if (snap.wom && snap.wom.available && snap.wom.heard && snap.wom.heard.net) {
      var wn = snap.wom.heard.net;
      var womCmp = compareToAvg(wn.value, wn.cat_avg);
      if (womCmp) {
        out.push('Net word of mouth heard is ' + cmpWords(womCmp) +
                 ' the category average at ' + wn.value + ' against ' +
                 wn.cat_avg + '.');
      }
    }
    return out;
  }

  function cmpWords(c) {
    if (c === 'above') return 'above';
    if (c === 'below') return 'below';
    return 'in line with';
  }

  function joinWords(list) {
    if (list.length === 1) return list[0];
    if (list.length === 2) return list[0] + ' and ' + list[1];
    return list.slice(0, -1).join(', ') + ' and ' + list[list.length - 1];
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
   * Mental availability card: MMS / SoM / Network Size value-chips,
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
      } else if (m.leader && m.leader !== '–') {
        leader = '<div class="brsum-vchip-leader">Leader: ' + escHtml(m.leader) + '</div>';
      }
      html += valueChip(m.label, m.value, m.cat_avg, col, leader);
    }
    body.innerHTML = '<div class="brsum-vchip-grid">' + html + '</div>';
  }

  /* ---------------------------------------------------------------------
   * Buying funnel card: collapsed Aware -> Prefer -> Bought funnel.
   * The label was "Physical conversion" in the first cut, corrected:
   * these stages are all CLAIMED BUYING (% who say they're aware, who
   * prefer, who bought in N months). Physical availability (in-store
   * distribution) is not measured in this study. Reuses the mini-funnel
   * renderer (focal + cat-avg side-by-side, stacked stage bars).
   * --------------------------------------------------------------------- */
  /* ---------------------------------------------------------------------
   * "Which penetration is which", one table per category listing every
   * penetration-like figure the report shows, with its base and definition
   * (production review 2026-07-12, M7). Category-level, so it does not
   * change with the selected brand.
   * --------------------------------------------------------------------- */
  function renderPenetrationNotes(root, cat) {
    var box = root.querySelector('[data-brsum-pen-notes]');
    if (!box) return;
    var pn = cat && cat.penetration_notes;
    if (!pn || !pn.notes || !pn.notes.length) { box.hidden = true; box.innerHTML = ''; return; }
    var rows = pn.notes.map(function (n) {
      var val = (n.value == null || isNaN(n.value)) ? '–' : (Math.round(n.value * 10) / 10) + '%';
      var base = escHtml(n.base || '');
      if (n.n != null && n.base_n != null) base += ' (n = ' + n.n + ' of ' + n.base_n + ', unweighted)';
      else if (n.base_n != null) base += ' (n = ' + n.base_n + ', unweighted)';
      return '<tr><th scope="row">' + escHtml(n.label || '') + '</th>' +
             '<td class="brsum-pen-val">' + val + '</td>' +
             '<td>' + base + '</td>' +
             '<td class="brsum-pen-def">' + escHtml(n.definition || '') + '</td></tr>';
    }).join('');
    box.innerHTML = '<div class="brsum-pen-notes-title">' + escHtml(pn.title || '') + '</div>' +
      '<p class="brsum-pen-notes-intro">' + escHtml(pn.intro || '') + '</p>' +
      '<table><thead><tr><th>Figure</th><th>Value</th><th>Base</th><th>What it measures</th></tr></thead><tbody>' +
      rows + '</tbody></table>';
    box.hidden = false;
  }

  function renderFunnelCard(root, funnelBlock, brandCode, snap) {
    renderMiniFunnelCard(root, 'funnel', funnelBlock, brandCode, snap,
      { emptyMessage: 'Funnel data not available.' });
  }

  /* ---------------------------------------------------------------------
   * The two Why blocks, split by concept.
   *
   * They used to be split by direction, over-indexers in one card and
   * under-indexers in the other, with category entry points and attributes
   * mixed inside each. Those are different things: a category entry point
   * is a buying moment, an attribute is what people say the brand is like,
   * and a reader has to be able to tell which is which. So one card is
   * moments and the other is associations, and inside each the split is
   * ahead of the category average against behind it.
   *
   * The card keys stay `working` and `weak` because pins, PNG capture and
   * Excel export resolve a section by data-section="brsum-<key>" and
   * analysts have saved work against those names. The key is an identifier
   * and the card title is a label; nothing derives one from the other.
   * --------------------------------------------------------------------- */
  var CONCEPTS = {
    working: {
      block: 'cep',
      unit: 'category entry point',
      units: 'category entry points',
      blurb: 'Category Entry Points: the buying moments people link to this brand. Source: the Mental Availability battery, as the % of respondents linking each moment to the brand. Ranked by the gap to the category average.'
    },
    weak: {
      block: 'attrs',
      unit: 'attribute',
      units: 'attributes',
      blurb: 'Brand attributes: what people say this brand is like. Source: the Mental Availability battery, as the % of respondents linking each attribute to the brand. Ranked by the gap to the category average.'
    }
  };

  function renderWorkingCard(root, cat, brandCode, snap) {
    renderConceptCard(root, 'working', cat, brandCode, snap);
  }
  function renderWeakCard(root, cat, brandCode, snap) {
    renderConceptCard(root, 'weak', cat, brandCode, snap);
  }

  function renderConceptCard(root, key, cat, brandCode, snap) {
    var body = cardBody(root, key);
    if (!body) return;
    var spec  = CONCEPTS[key];
    var block = cat ? cat[spec.block] : null;
    var col   = (snap && snap.colour) || '#1A5276';

    var meta = cardMeta(root, key);
    if (meta) meta.textContent = (block && block.base_label) ? block.base_label : '';

    var aheadHtml  = advantageCol(block, brandCode, 'top', col,
                                  'Ahead of the category average', spec);
    var behindHtml = advantageCol(block, brandCode, 'bottom', col,
                                  'Behind the category average', spec);
    if (!aheadHtml && !behindHtml) {
      body.innerHTML = '<div class="brsum-card-empty">' +
        escHtml(spec.units.charAt(0).toUpperCase() + spec.units.slice(1)) +
        ' were not measured for this category.</div>';
      return;
    }
    body.innerHTML =
      '<p class="brsum-card-blurb">' + spec.blurb + '</p>' +
      '<div class="brsum-adv-grid">' +
        (aheadHtml  || '<div class="brsum-adv-col brsum-adv-empty">No ' +
                       escHtml(spec.unit) + ' data.</div>') +
        (behindHtml || '<div class="brsum-adv-col brsum-adv-empty">No ' +
                       escHtml(spec.unit) + ' data.</div>') +
      '</div>';
  }

  /* Rank one concept's items for one direction. `spec` names the unit so an
     empty column can say what it found none of. */
  function advantageCol(block, brandCode, direction, col, title, spec) {
    if (!block || !block.available) return '';
    var brand = block.brands && block.brands[brandCode];
    if (!brand) return '';
    var stims  = block.stim_codes  || [];
    var labels = block.stim_labels || stims;
    var avgs   = block.cat_avg_pct || [];
    var fps    = brand.focal_pct   || [];
    /* Delta is computed as focal_pct - cat_avg_pct so the displayed +/-pp
       matches the displayed focal and cat-avg values exactly. We do NOT
       use brand.advantage_pp here. That's the MA engine's own advantage
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
    /* Drop wrong-sign rows so the ahead column never lists a shortfall and
       the behind column never lists a lead. Those don't fit the heading,
       and promoting the least-strong item into a gap would invent one. */
    var total = ranked.length;
    ranked = ranked.filter(function (r) {
      return direction === 'top' ? r.delta > 0 : r.delta < 0;
    });
    var unit  = (spec && spec.unit)  || 'item';
    var units = (spec && spec.units) || 'items';
    if (!ranked.length) {
      var none = direction === 'top'
        ? 'This brand is at or behind the category average on every one of the ' +
          total + ' ' + units + ' measured.'
        : 'This brand is at or above the category average on every one of the ' +
          total + ' ' + units + ' measured. There is no ' + unit +
          ' behind the category average to report.';
      return '<div class="brsum-adv-col">' +
               '<div class="brsum-adv-coltitle">' + escHtml(title) + '</div>' +
               '<div class="brsum-adv-empty">' + escHtml(none) + '</div>' +
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
   * Opportunities to examine.
   *
   * The block this replaces was labelled Protect, Build and Investigate,
   * which reads as a model's decision. It is rules over numbers, so it says
   * so, and every item names where it came from: a Mental Advantage
   * decision, something read off the funnel above, or a rule of thumb.
   *
   * The hard rule here is that it never manufactures a weakness. When
   * Mental Advantage returns no defend and no build item, the block says
   * that plainly instead of promoting the least-strong item into a gap. A
   * rule-of-thumb item may still name the largest and the smallest lead,
   * but it is labelled as a rule of thumb and never as a model output.
   * --------------------------------------------------------------------- */
  function renderOpportunitiesCard(root, cat, brandCode, snap) {
    var body = cardBody(root, 'opportunities');
    if (!body) return;
    var parts = [];
    parts.push('<p class="brsum-card-blurb">Rules over the numbers on this ' +
      'page, not a model recommendation. Each item names where it came ' +
      'from, and nothing here is a finding on its own.</p>');

    var adv = advantageDecisions(cat, brandCode);
    if (!adv.measured) {
      parts.push(oppNone('Mental Advantage was not run for this category, ' +
        'so there is no defend or build item to report.'));
    } else if (adv.defend.length || adv.build.length) {
      var items = [];
      adv.defend.slice(0, 2).forEach(function (d) {
        items.push(oppItem('model', 'Mental Advantage: defend',
          d.label + ' is linked to this brand well above what its size in the ' +
          'category would predict, at ' + signed(d.advantage) + 'pp. ' +
          'Mental Advantage marks it defend.'));
      });
      adv.build.slice(0, 2).forEach(function (d) {
        items.push(oppItem('model', 'Mental Advantage: build',
          d.label + ' is linked to this brand well below what its size in the ' +
          'category would predict, at ' + signed(d.advantage) + 'pp. ' +
          'Mental Advantage marks it build.'));
      });
      parts.push('<ul class="brsum-opp-list">' + items.join('') + '</ul>');
    } else {
      /* The honest empty case. On the IPK fixture this is what the focal
         brand gets: every one of its category entry points and attributes
         lands on maintain. */
      var fname = (snap && snap.name) || 'This brand';
      parts.push(oppNone('Mental Advantage returns no defend and no build ' +
        'item for ' + fname + ' here. All ' + adv.n + ' measured ' + adv.what +
        ' sit inside its threshold, which it reads as maintain. There is no ' +
        'gap in this battery to report, and none is invented below.'));
      var rules = [];
      if (adv.best) {
        rules.push(oppItem('rule-of-thumb', 'Rule of thumb: worth protecting',
          adv.best.label + ' is this brand’s largest lead over the category ' +
          'average, at ' + signed(adv.best.delta) + 'pp. A rule of thumb for ' +
          'what to protect, not a model output.'));
      }
      if (adv.worst && adv.best && adv.worst.idx !== adv.best.idx) {
        rules.push(oppItem('rule-of-thumb', 'Rule of thumb: worth watching',
          adv.worst.label + ' is its ' +
          (adv.worst.delta >= 0 ? 'smallest lead over' : 'largest shortfall against') +
          ' the category average, at ' + signed(adv.worst.delta) + 'pp. A rule ' +
          'of thumb for what to watch, not a model output.'));
      }
      if (rules.length) {
        parts.push('<ul class="brsum-opp-list">' + rules.join('') + '</ul>');
      }
    }

    var drop = biggestFunnelDrop(cat, brandCode);
    if (drop) {
      parts.push('<ul class="brsum-opp-list">' + oppItem('observed',
        'Read off the funnel above',
        'The largest step down is from ' + drop.from + ' at ' +
        pctText(drop.fromValue) + ' to ' + drop.to + ' at ' +
        pctText(drop.toValue) + ', which is ' + Math.round(drop.ratio * 100) +
        '% of the stage before it.') + '</ul>');
    }
    body.innerHTML = parts.join('');
  }

  function oppItem(kind, tag, text) {
    return '<li class="brsum-opp-item" data-brsum-opp-kind="' + kind + '">' +
             '<span class="brsum-opp-tag">' + escHtml(tag) + '</span>' +
             '<span class="brsum-opp-text">' + escHtml(text) + '</span>' +
           '</li>';
  }
  function oppNone(text) {
    return '<p class="brsum-opp-none" data-brsum-opp-none>' +
           escHtml(text) + '</p>';
  }
  function signed(v) {
    return (v >= 0 ? '+' : '') + Number(v).toFixed(1);
  }
  function pctText(v) {
    return Math.round(v * 100) + '%';
  }

  /* Read the Mental Advantage decision the engine already wrote for each
     stimulus, across both batteries. The decision is the model's, taken at
     its own threshold against its own expected value; nothing is
     reclassified here. The best and worst entries are the arithmetic gap to
     the category average, which is the figure the two Why cards display, so
     a rule-of-thumb item and the list above it cannot disagree. */
  function advantageDecisions(cat, brandCode) {
    var out = { measured: false, defend: [], build: [], n: 0,
                what: 'items', best: null, worst: null };
    var seen = [];
    [['cep', 'category entry points'], ['attrs', 'attributes']].forEach(
      function (pair) {
        var block = cat ? cat[pair[0]] : null;
        if (!block || !block.available) return;
        var brand = block.brands && block.brands[brandCode];
        if (!brand) return;
        out.measured = true;
        seen.push(pair[1]);
        var stims  = block.stim_codes  || [];
        var labels = block.stim_labels || stims;
        var avgs   = block.cat_avg_pct || [];
        var fps    = brand.focal_pct   || [];
        var decs   = brand.decision    || [];
        var advs   = brand.advantage_pp || [];
        for (var i = 0; i < stims.length; i++) {
          var label = labels[i] || stims[i];
          var dec = String(decs[i] || '').toLowerCase();
          if (dec === 'defend' || dec === 'build') {
            out[dec].push({ label: label, advantage: advs[i] });
          }
          var fv = fps[i], av = avgs[i];
          if (fv == null || isNaN(fv) || av == null || isNaN(av)) continue;
          out.n++;
          var entry = { idx: pair[0] + ':' + i, label: label, delta: fv - av };
          if (!out.best  || entry.delta > out.best.delta)  out.best  = entry;
          if (!out.worst || entry.delta < out.worst.delta) out.worst = entry;
        }
      });
    out.defend.sort(function (a, b) { return b.advantage - a.advantage; });
    out.build.sort(function (a, b) { return a.advantage - b.advantage; });
    if (seen.length) out.what = seen.join(' and ');
    return out;
  }

  /* The largest step down in the funnel this page already draws, as a share
     of the stage before it. .biggest_drop_for_focal() in R/03_funnel.R finds
     the same step under the default ratio conversion metric, and this is
     phrased as a share of the stage before so it stays true whichever metric
     the config sets. Nothing here is added to the payload. */
  function biggestFunnelDrop(cat, brandCode) {
    var f = cat && cat.funnel;
    if (!f || !f.available) return null;
    var vals = f.brands && f.brands[brandCode];
    var keys = f.stage_keys || [];
    var labs = f.stage_labels || keys;
    if (!vals || vals.length < 2) return null;
    var worst = null;
    for (var i = 1; i < vals.length; i++) {
      var prev = vals[i - 1], cur = vals[i];
      if (prev == null || cur == null || isNaN(prev) || isNaN(cur) || prev <= 0)
        continue;
      var ratio = cur / prev;
      if (!worst || ratio < worst.ratio) {
        worst = { from: labs[i - 1] || keys[i - 1], to: labs[i] || keys[i],
                  fromValue: prev, toValue: cur, ratio: ratio };
      }
    }
    return worst;
  }

  /* ---------------------------------------------------------------------
   * Word of mouth card: Heard + Said columns (positive / negative / net
   * per side), each row showing focal value + cat avg under. Uses the
   * shared womColumn / womRow helpers. The original cut combined this
   * with DoP partners/rivals in one card: split per Duncan's review.
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
   * Repertoire ties card: top 2 DoP partners + top 2 rivals for the
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
        '<strong>Partners</strong> show up more than their overall popularity predicts: ' +
        'natural co-buys. <strong>Rivals</strong> show up less: head-to-head substitutes. ' +
        'Percentage points (pp) compare each brand’s share among focal buyers with its share across the whole category.' +
      '</p>' +
      '<div class="brsum-conv-dop-row">' +
        '<div class="brsum-conv-dop-side">' +
          '<div class="brsum-conv-dop-side-title">Partners: over-index</div>' +
          partnersHtml +
        '</div>' +
        '<div class="brsum-conv-dop-side">' +
          '<div class="brsum-conv-dop-side-title">Rivals: under-index</div>' +
          rivalsHtml +
        '</div>' +
      '</div>';
  }

  /* WOM column helpers: shared by renderConversationCard. */
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
               '<div class="brsum-wom-val">' + escHtml(row.value || '–') + '</div>' +
               (row.cat_avg && row.cat_avg !== '–'
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
   * "<label> <pct>" caption underneath, same idiom as the brand-funnel
   * sub-tab's mini-funnels, scoped here under .brsum-mf-*.
   *
   * Block shape (R-side):
   *   stage_keys / stage_labels  (Brand funnel)
   *   seg_codes  / seg_labels    (Brand attitude / Loyalty / Purchase dist)
   * --------------------------------------------------------------------- */
  function fmtPctSingle(v) {
    if (v == null || isNaN(v)) return '–';
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

  /* DoP row helper: shared by renderConversationDop. */
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
   * Public: programmatic category switch (closing strip mini-cards)
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
    if (window._brSyncCommentary) window._brSyncCommentary(editor);
    editor.focus();
    var newPos = start + before.length + (selected || 'text').length;
    editor.setSelectionRange(newPos, newPos);
    window.brsumRenderInsight();
  };

  /* -------------------------------------------------------------------------
   * Test seam
   *
   * The Overview's derived sentences are pure functions of one (category,
   * brand) snapshot, and every one of them has to hold for a brand at the
   * top of a category, in the middle and at the bottom. The renderers reach
   * into the DOM, so the derivations are exposed here and exercised
   * directly by modules/brand/tests/js/test_summary_overview.js. Nothing in
   * the report calls these; they read the payload and return values.
   * ------------------------------------------------------------------------- */
  window.brsumDerive = {
    parseRank: parseRank,
    heroAnchors: heroAnchors,
    heroHeadline: function (snap, cat, catName) {
      var a = heroAnchors(snap);
      var fname = (snap && snap.name) || 'Focal brand';
      var lines = heroHeadline(snap, cat, catName, fname, a);
      return { anchors: a, rank: a.mms_rank, of: a.mms_rank_of,
               lines: lines, headline: lines.join(' ') };
    },
    tileFacts: function (snap, cat) { return tileFacts(heroAnchors(snap), cat); },
    boughtWindowLabel: boughtWindowLabel,
    advantageDecisions: advantageDecisions,
    biggestFunnelDrop: biggestFunnelDrop
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
