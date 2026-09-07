// ==============================================================================
// BRAND REPORT - CORE INTERACTIVITY
// ==============================================================================
// Tab switching, category sub-navigation, insight editor, save, help,
// table sorting, Excel export.
// ==============================================================================

(function() {
  "use strict";

  // --- Tab switching ---
  window.switchBrandTab = function(tabName) {
    document.querySelectorAll(".br-tab-btn").forEach(function(btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
    });
    document.querySelectorAll(".br-panel").forEach(function(panel) {
      panel.classList.remove("active");
    });
    var target = document.getElementById("panel-" + tabName);
    if (target) target.classList.add("active");

    var titleEl = document.getElementById("br-header-title");
    if (titleEl) {
      var header = document.querySelector(".br-header");
      var reportTitle = header ? (header.getAttribute("data-report-title") || "") : "";
      var nonCatTabs = ["summary", "pinned", "about", "dba", "wom", "portfolio"];
      if (nonCatTabs.indexOf(tabName) !== -1) {
        titleEl.textContent = reportTitle;
      } else {
        var activeBtn = document.querySelector('.br-tab-btn[data-tab="' + tabName + '"]');
        if (activeBtn) {
          var badge = activeBtn.querySelector(".br-pin-badge");
          var label = activeBtn.textContent.trim();
          if (badge) label = label.replace(badge.textContent.trim(), "").trim();
          titleEl.textContent = label;
        }
      }
    }
  };

  // --- Activating one sub-panel host ---
  // Shared by the destination switcher and by switchCategorySubtab. The two
  // things a host needs on activation, unchanged from the flat sub-tab bar:
  //   1. show only the .br-insight-wrap whose data-insight-internal-tab
  //      matches this host's internal tab, so one Section_Insights box is
  //      visible at a time;
  //   2. click the panel's own hidden sub-tab button, which is how the MA,
  //      funnel and cat-buying panels run their own state updates and
  //      re-render charts that were laid out while hidden.
  function activateHost(host) {
    if (!host) return;
    var internalTab = host.getAttribute("data-internal-tab") || "";
    var cbTab       = host.getAttribute("data-cb-tab") || "";

    if (internalTab) {
      host.querySelectorAll('.br-insight-wrap[data-insight-internal-tab]')
        .forEach(function (w) {
          w.style.display =
            (w.getAttribute('data-insight-internal-tab') === internalTab)
              ? 'block' : 'none';
        });

      // MA panel: click the hidden .ma-subtab-btn
      var maBtn = host.querySelector(
        '.ma-subtab-btn[data-ma-subtab-target="' + internalTab + '"]'
      );
      if (maBtn) { maBtn.click(); return; }

      // Funnel panel: click the hidden .fn-subtab-btn
      var fnBtn = host.querySelector(
        '.fn-subtab-btn[data-fn-subtab-target="' + internalTab + '"]'
      );
      if (fnBtn) { fnBtn.click(); return; }
    }

    if (cbTab) {
      // Cat-buying panel: click the hidden .cb-subtab-btn
      var cbBtn = host.querySelector(
        '.cb-subtab-btn[data-cb-tab="' + cbTab + '"]'
      );
      if (cbBtn) cbBtn.click();
    }
  }
  window.brActivateHost = activateHost;

  function hostsIn(root) {
    return root ? Array.prototype.slice.call(
      root.querySelectorAll(".br-subpanel")) : [];
  }

  // --- Destination switching (five destinations per category) ---
  window.switchBrandDestination = function(btn) {
    var group = btn.getAttribute("data-group");
    var dest  = btn.getAttribute("data-destination");

    document.querySelectorAll('.br-destination-btn[data-group="' + group + '"]')
      .forEach(function(b) {
        b.classList.toggle("active", b.getAttribute("data-destination") === dest);
      });

    var active = null;
    document.querySelectorAll('.br-destination[data-group="' + group + '"]')
      .forEach(function(d) {
        var on = d.getAttribute("data-destination") === dest;
        d.classList.toggle("active", on);
        if (on) active = d;
      });

    if (!active) return;
    // Only hosts that are actually laid out are re-activated: a host inside
    // a collapsed Advanced item is activated when that item is expanded.
    var main = active.querySelector(".br-dest-main");
    hostsIn(main).forEach(activateHost);
    active.querySelectorAll(".br-adv-body:not([hidden])").forEach(function(b) {
      hostsIn(b).forEach(activateHost);
    });
  };

  // --- Advanced drawer, and its one-at-a-time accordion ---
  // Opening either tier moves what is on screen, sometimes by the height of
  // a whole panel, so the thing the reader clicked is scrolled back under
  // the sticky tab bar afterwards. scroll-margin-top on the toggles does
  // the clearing; smooth is deliberate, so the reader sees the page move
  // rather than finding themselves somewhere new.
  function brRevealToggle(btn) {
    if (!btn || !btn.scrollIntoView) return;
    try {
      btn.scrollIntoView({ block: "start", behavior: "smooth" });
    } catch (e) {
      btn.scrollIntoView(true);
    }
  }

  window.brToggleAdvanced = function(btn) {
    var body = btn.parentNode ? btn.parentNode.querySelector(".br-advanced-body") : null;
    if (!body) return;
    var open = body.hidden;
    body.hidden = !open;
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    if (open) {
      body.querySelectorAll(".br-adv-body:not([hidden])").forEach(function(b) {
        hostsIn(b).forEach(activateHost);
      });
      brRevealToggle(btn);
    }
  };

  window.brToggleAdvancedItem = function(btn) {
    var item = btn.closest(".br-adv-item");
    var wrap = item ? item.parentNode : null;
    if (!item || !wrap) return;
    var body = item.querySelector(".br-adv-body");
    if (!body) return;
    var opening = body.hidden;

    // One researcher-grade analysis expanded at a time.
    wrap.querySelectorAll(".br-adv-item").forEach(function(other) {
      var ob = other.querySelector(".br-adv-body");
      var ot = other.querySelector(".br-adv-toggle");
      if (!ob) return;
      ob.hidden = true;
      if (ot && ot.tagName === "BUTTON") ot.setAttribute("aria-expanded", "false");
    });

    if (opening) {
      body.hidden = false;
      btn.setAttribute("aria-expanded", "true");
      hostsIn(body).forEach(activateHost);
    }
    // Collapsing the item that was open above this one pulls the clicked
    // header up the page; the reveal puts it back where the reader is
    // looking, whether the click opened or closed something.
    brRevealToggle(btn);
  };

  // --- Overview route into the Summary tab for one category ---
  // The summary panel's category dropdown is keyed on the category's display
  // name, not on the cat id the category tab uses, so the name is passed in
  // and matched first; the id is the fallback for a report whose summary
  // options are keyed differently.
  window.brOpenSummaryFor = function(catId, catName) {
    window.switchBrandTab("summary");
    var sel = document.querySelector("[data-brsum-cat]");
    if (!sel) return;
    var pick = null;
    for (var i = 0; i < sel.options.length; i++) {
      var o = sel.options[i];
      var v = String(o.value || "");
      if (catName && (v === catName || o.textContent.trim() === catName)) {
        pick = o.value; break;
      }
      if (v.toLowerCase().replace(/[^a-z0-9]+/g, "-") === catId) {
        pick = o.value;
      }
    }
    if (pick === null) return;
    sel.value = pick;
    sel.dispatchEvent(new Event("change", { bubbles: true }));
  };

  // --- Category sub-tab switching (kept: the panel-internal route) ---
  // Nothing in the destination shell calls this, but it stays valid and
  // stays the one way a caller reaches a panel's internal tab. Each button
  // carries data-subpanel and data-internal-tab. The internal panel nav bars
  // (.fn-subnav / .ma-subnav / .cb-subnav) are hidden via CSS but remain in
  // the DOM so dispatching a click on them triggers their own JS updates.
  // The host selector now also matches on data-internal-tab, because one
  // category renders several hosts per sub-panel since the render was split.
  window.switchCategorySubtab = function(btn) {
    var group       = btn.getAttribute("data-group");
    var subtab      = btn.getAttribute("data-subtab");
    var subpanel    = btn.getAttribute("data-subpanel");
    var internalTab = btn.getAttribute("data-internal-tab") || "";

    document.querySelectorAll('.br-subtab-btn[data-group="' + group + '"]').forEach(function(b) {
      b.classList.toggle("active", b.getAttribute("data-subtab") === subtab);
    });

    var sel = '.br-subpanel[data-group="' + group + '"]';
    var own = sel + '[data-subpanel="' + subpanel + '"]';
    if (internalTab) own += '[data-internal-tab="' + internalTab + '"]';

    // Show the sub-panel that owns this tab
    document.querySelectorAll(sel).forEach(function(p) {
      p.classList.toggle("active", p.matches(own));
    });

    if (internalTab) activateHost(document.querySelector(own));
  };


  // ==========================================================================
  // Persistent comparison set
  // ==========================================================================
  // One control per category sets the focal brand and its comparators, and
  // every destination respects it. Nothing is recomputed and no panel's
  // own filtering is reimplemented: the control drives each panel's existing
  // focal select, and publishes the hidden-brand set to the shared
  // category-scoped store that BrandSelector already keeps.
  //
  // There is no cap on the comparators. An earlier version stopped at five
  // and enforced it by unticking the sixth box, which reversed a click with
  // no message: a silent failure of exactly the kind TRS exists to prevent.
  // The cap came from a single-category tracker where every view is a chart.
  // Turas tables have always shown every brand in the category, and chart
  // legibility is handled separately by the per-chart "Chart brands" control,
  // so the reason for the cap has been designed away rather than relaxed.
  // If a limit is ever needed here it must say so on screen; it may not undo
  // the reader's click.

  // Three states, and the trigger always names the live one:
  //   "focal"   - only the focal brand is shown
  //   "compare" - the focal brand plus the picked comparators
  //   "all"     - every brand in the category
  // "all" stays a mode rather than a state derived from every box being
  // ticked. A reader asking for the whole category is making a different
  // claim from a reader who happens to have picked all of them, and the mode
  // is what a category-wide view publishes.
  function cmpPopover(group) {
    return document.querySelector('.br-cmp-popover[data-group="' + group + '"]');
  }

  function cmpState(group) {
    var pop = cmpPopover(group);
    var boxes = pop ? pop.querySelectorAll(".br-cmp-check") : [];
    var focalSel = document.getElementById("br-focal-select-" + group);
    var focal = focalSel ? focalSel.value : "";
    var comparators = [];
    Array.prototype.forEach.call(boxes, function (b) {
      if (b.checked && b.value !== focal) comparators.push(b.value);
    });
    var mode = pop ? (pop.getAttribute("data-cmp-mode") || "focal") : "focal";
    if (mode !== "all") mode = comparators.length > 0 ? "compare" : "focal";
    return { focal: focal, comparators: comparators, mode: mode };
  }

  function cmpSetMode(group, mode) {
    var pop = cmpPopover(group);
    if (!pop) return;
    pop.setAttribute("data-cmp-mode", mode);
    pop.querySelectorAll(".br-cmp-mode").forEach(function (b) {
      var key = b.getAttribute("data-cmp-set");
      b.classList.toggle("active",
        (key === "all" && mode === "all") ||
        (key === "focal" && mode === "focal"));
    });
    pop.querySelector(".br-cmp-list").classList.toggle("br-cmp-list-off",
                                                       mode === "all");
  }

  // Every panel host in this category, whatever its destination.
  function categoryPanels(group) {
    var sel = '.fn-panel[data-category-key="' + group + '"],' +
              '.ma-panel[data-category-key="' + group + '"],' +
              '.cb-panel[data-cb-cat-code="' + group + '"],' +
              '.wom-panel[data-cat-code="' + group + '"],' +
              '.demo-panel[id="demo-panel-' + group + '"]';
    return Array.prototype.slice.call(document.querySelectorAll(sel));
  }

  function setPanelFocal(panel, code) {
    var sel = panel.querySelector(".fn-focus-select") ||
              panel.querySelector(".ma-focus-select") ||
              panel.querySelector('select.cb-focus-select[data-cb-action="focus"]') ||
              panel.querySelector(".wom-focus-select") ||
              panel.querySelector(".demo-focal-select");
    if (!sel || !code) return;
    var found = false;
    for (var i = 0; i < sel.options.length; i++) {
      if (String(sel.options[i].value) === String(code)) { found = true; break; }
    }
    if (!found || sel.value === code) return;
    sel.value = code;
    sel.dispatchEvent(new Event("change", { bubbles: true }));
  }

  window.brApplyComparisonSet = function(group) {
    var st = cmpState(group);
    cmpSetMode(group, st.mode);

    // The trigger keeps the word "Brands" in every state. Read as "Focal
    // only", the control looked like a status line rather than a control,
    // and the brand selector was reported missing by a reader looking
    // straight at it. The badge carries what the words leave out: how many
    // of the category's brands are on screen.
    var pop = cmpPopover(group);
    var total = pop ? pop.querySelectorAll(".br-cmp-check").length : 0;
    var shown = st.mode === "all" ? total
                                  : st.comparators.length + (st.focal ? 1 : 0);
    var badge = document.querySelector('.br-cmp-count[data-group="' + group + '"]');
    if (badge) {
      badge.textContent = String(shown) + "/" + String(total);
      badge.hidden = st.mode !== "compare";
    }
    var text = document.querySelector('.br-cmp-text[data-group="' + group + '"]');
    if (text) {
      // "focal + N" rather than "focal and N others". Measured in headless
      // Chrome at 800 pixels wide: the longer wording takes the trigger to
      // 210 pixels and wraps the control bar onto a second line, while this
      // one holds 161 and one line at every width tested. The title spells
      // it out for anyone the shorthand does not.
      text.textContent =
        st.mode === "all" ? "Brands: all " + String(total)
      : st.mode === "compare" ? "Brands: focal + " + String(st.comparators.length)
      : "Brands: focal only";
    }
    var trig = document.querySelector('.br-cmp-trigger[data-group="' + group + '"]');
    if (trig) {
      trig.title =
        st.mode === "all"
          ? ("Showing all " + String(total) + " brands in this category")
      : st.mode === "compare"
          ? ("Showing the focal brand and " + String(st.comparators.length) +
             " comparators, of " + String(total) + " brands in this category")
      : ("Showing the focal brand only, of " + String(total) +
         " brands in this category");
    }

    categoryPanels(group).forEach(function (p) { setPanelFocal(p, st.focal); });

    // The visible set follows the state exactly, in all three states, so
    // the words on the trigger and the rows in the tables never disagree.
    if (typeof window.BrandSelector !== "undefined" &&
        window.BrandSelector.setCategoryHidden) {
      if (st.mode === "all") {
        window.BrandSelector.setCategoryHidden(group, []);
      } else {
        var show = {};
        show[st.focal] = true;
        st.comparators.forEach(function (c) { show[c] = true; });
        var hidden = window.BrandSelector.categoryBrands(group).filter(function (c) {
          return !show[c];
        });
        window.BrandSelector.setCategoryHidden(group, hidden);
      }
    }

    // Every published set resets each panel's chart-only set to its table
    // set, so any live "Chart brands" deviation is already gone by here.
    // This repaints the controls and clears their notes so the face of the
    // report says so too. It runs on all three header states, which is why
    // the all-brands branch above no longer returns early.
    if (window.BrandChartFocus) window.BrandChartFocus.refreshAll();
  };

  window.brComparisonFocalChanged = function(sel) {
    var group = sel.getAttribute("data-group");
    // The focal brand is always in the comparison set and cannot be unpicked,
    // so its own checkbox follows the dropdown. The brand that was focal
    // before is released rather than silently promoted to a comparator: a
    // pick the reader never made is a surprise, whether or not slots are
    // scarce. This is a consequence of changing the focal brand, which the
    // reader did just ask for, not a reversal of a click on that checkbox.
    document.querySelectorAll(
      '.br-cmp-popover[data-group="' + group + '"] .br-cmp-check')
      .forEach(function (b) {
        var isFocal = (b.value === sel.value);
        var wasFocal = b.disabled && !isFocal;
        b.disabled = isFocal;
        if (isFocal) b.checked = true;
        else if (wasFocal) b.checked = false;
      });
    window.brApplyComparisonSet(group);
  };

  window.brComparisonSetChanged = function(box) {
    var pop = box.closest(".br-cmp-popover");
    if (!pop) return;
    var group = pop.getAttribute("data-group");
    // Ticking a brand always leaves "all brands": the picks are what the
    // reader is now asking for.
    pop.setAttribute("data-cmp-mode", "compare");
    // Every tick stands. This function must never write box.checked: the
    // one thing it may not do is undo the click that called it.
    window.brApplyComparisonSet(group);
  };

  // The two named states. "Focal only" clears the picks; "All brands" is a
  // mode of its own rather than every box ticked, because a reader asking
  // for the category is not the same as a reader who ticked everything.
  window.brSetComparisonMode = function(btn) {
    var pop = btn.closest(".br-cmp-popover");
    if (!pop) return;
    var group = pop.getAttribute("data-group");
    var want = btn.getAttribute("data-cmp-set");
    if (want === "focal") {
      pop.querySelectorAll(".br-cmp-check").forEach(function (b) {
        if (!b.disabled) b.checked = false;
      });
      pop.setAttribute("data-cmp-mode", "focal");
    } else {
      pop.setAttribute("data-cmp-mode", "all");
    }
    window.brApplyComparisonSet(group);
  };

  window.brToggleComparisonPopover = function(btn) {
    var group = btn.getAttribute("data-group");
    var pop = document.querySelector('.br-cmp-popover[data-group="' + group + '"]');
    if (!pop) return;
    var open = pop.hidden;
    document.querySelectorAll(".br-cmp-popover").forEach(function (p) { p.hidden = true; });
    document.querySelectorAll(".br-cmp-trigger").forEach(function (t) {
      t.setAttribute("aria-expanded", "false");
    });
    pop.hidden = !open;
    btn.setAttribute("aria-expanded", open ? "true" : "false");
  };

  window.brSwitchCategoryFromControl = function(sel) {
    var target = sel.value;
    if (!target) return;
    // Keep the reader on the same destination in the category they move to.
    var group = sel.getAttribute("data-group");
    var activeBtn = document.querySelector(
      '.br-destination-btn[data-group="' + group + '"].active');
    var dest = activeBtn ? activeBtn.getAttribute("data-destination") : null;
    window.switchBrandTab("cat-" + target);
    if (!dest) return;
    var newBtn = document.querySelector(
      '.br-destination-btn[data-group="' + target + '"][data-destination="' + dest + '"]');
    if (newBtn) window.switchBrandDestination(newBtn);
  };

  document.addEventListener("click", function (ev) {
    if (ev.target && ev.target.closest &&
        !ev.target.closest(".br-cmp-popover") &&
        !ev.target.closest(".br-cmp-trigger")) {
      document.querySelectorAll(".br-cmp-popover").forEach(function (p) { p.hidden = true; });
    }
  }, true);

  // ==========================================================================
  // Destination toolbars: one per main view, one per Advanced drawer
  // ==========================================================================
  // Stage 5. Every scope here is resolved from data-group, data-destination
  // and data-tier. None of it reads or writes data-section, because the set
  // of section anchors is a contract with the analysts who typed those names
  // into Section_Insights sheets, and a destination is not a section.
  //
  // Pin and PNG offer the anchors that are inside the scope, so consolidating
  // the toolbars does not take away the reader's choice of what to capture;
  // it takes away having to hunt for the right button. Excel takes every
  // table in the scope, which is what gives the six Category Buying analyses
  // an export again after Stage 2 narrowed section-repertoire-<cat> to the
  // Category Context host.

  function destOf(btn) {
    var g = btn.getAttribute("data-group");
    var d = btn.getAttribute("data-destination");
    if (!g || !d) return null;
    return document.querySelector('.br-destination[data-group="' + g +
                                  '"][data-destination="' + d + '"]');
  }

  function destScope(btn) {
    var dest = destOf(btn);
    if (!dest) return null;
    var tier = btn.getAttribute("data-tier") || "main";
    return tier === "advanced"
      ? dest.querySelector(".br-advanced-body")
      : dest.querySelector(".br-dest-main");
  }
  window.brDestScope = destScope;

  // Is this heading hidden by something INSIDE the capture root?
  //
  // Naming a card after the first heading in its root, visible or not, gave
  // the Brand Funnel a card called "Summary": the funnel anchor wraps the
  // whole leaf, and the first heading under it belongs to the Summary
  // sub-tab that no nav routes to and that carries the hidden attribute.
  // Skipping every invisible heading instead swung it the other way: a
  // reader opens the pin picker with the Advanced drawer shut, so every
  // heading under that drawer is invisible, and seven Branded Reach cards
  // and six Audience Lens cards all came back with the same leaf name.
  //
  // The distinction is where the hiding lives. A drawer collapsed above the
  // root, or an inactive sub-tab above it, hides the root and its heading
  // together, and that heading is still the name of what is being captured.
  // A pane hidden BETWEEN the root and the heading is a piece of the root
  // the reader is not looking at, and its heading names that pane rather
  // than the capture. So the walk stops at the root and never leaves it.
  //
  // captureFromRoot() in brand_pins.js calls this same function, because the
  // picker's label and the card's title must agree.
  function headingHiddenWithin(el, root) {
    if (!el) return true;
    // Fast path: laid out on screen, so nothing above it is hidden either.
    if (el.offsetParent !== null) return false;
    var n = el;
    while (n && n !== root && n.nodeType === 1) {
      if (n.hasAttribute("hidden")) return true;
      var cs = window.getComputedStyle ? window.getComputedStyle(n) : null;
      if (cs && (cs.display === "none" || cs.visibility === "hidden")) return true;
      n = n.parentElement;
    }
    return false;
  }
  window.brHeadingHiddenWithin = headingHiddenWithin;

  // Does this root hold anything a capture would put on a card?
  function hasCapturable(el) {
    if (!el) return false;
    if (el.querySelector("table")) return true;
    if (el.querySelector("[data-pin-as-table],[data-pin-as-chart],[data-fn-rel-chart-area]")) return true;
    var svgs = el.querySelectorAll("svg");
    for (var i = 0; i < svgs.length; i++) {
      if (!svgs[i].closest("button")) return true;
    }
    return false;
  }

  // What a scope offers to pin or export, in document order, each with a
  // label a reader will recognise and the root a capture is taken from.
  //
  // Anchors first, because an anchor is a name an analyst may have saved a
  // pin against and capturing from it keeps that pin meaning the same thing.
  // Then any leaf host that holds no anchor at all: the five Category Buying
  // analyses in the Brand and Buying drawer are exactly that case, and
  // before Stage 5 they had no pin or PNG control of any kind. An entry with
  // nothing capturable under it is left out rather than offered and then
  // producing an empty card.
  function sectionsIn(scope) {
    if (!scope) return [];
    var seen = {}, out = [];
    scope.querySelectorAll("[data-section]").forEach(function (el) {
      if (el.tagName === "BUTTON") return;
      var key = el.getAttribute("data-section");
      if (!key || seen[key]) return;
      if (!hasCapturable(el)) return;
      seen[key] = true;
      // A heading hidden by a pane inside this root does not name the entry.
      // The anchors sit on a wrapper around the whole leaf, so the first
      // heading under one can belong to a sub-tab the reader is not on: on
      // the funnel it is the Summary sub-tab that no nav routes to, which
      // had the picker offering "Summary" for the Brand Funnel. A heading
      // that is merely off screen because the whole root sits in a collapsed
      // drawer is still the right name. captureFromRoot() in brand_pins.js
      // applies the identical test, and the two must agree or the picker
      // names one thing and the card another.
      var title = null;
      var heads = el.querySelectorAll(".br-element-title, h2, h3");
      for (var hi = 0; hi < heads.length; hi++) {
        if (!headingHiddenWithin(heads[hi], el)) { title = heads[hi]; break; }
      }
      var host  = el.closest("[data-leaf-label]");
      var label = (title && title.textContent.trim()) ||
                  (host && host.getAttribute("data-leaf-label")) || key;
      out.push({ key: key, label: label, el: el });
    });
    scope.querySelectorAll("[data-leaf][data-leaf-label]").forEach(function (host) {
      if (host.querySelector("[data-section]")) return;
      var leaf = host.getAttribute("data-leaf");
      if (!leaf) return;
      var group = host.getAttribute("data-group") || "";
      // The key is scoped to the category. Five categories all offering
      // "cb-norms" would put five identically keyed pins in the store, and
      // the five Category Buying analyses are the only entries that reach
      // this branch. It is not a data-section value and never was.
      var key = group ? group + ":" + leaf : leaf;
      if (seen[key]) return;
      if (!hasCapturable(host)) return;
      seen[key] = true;
      var label = host.getAttribute("data-leaf-label") || leaf;
      // These sub-tabs carry no heading of their own, so a pin taken from
      // one would be titled with its key. It gets the analysis name and the
      // category, which is what tells two categories' cards apart.
      var cat = catLabelFor(host);
      out.push({ key: key, label: label, el: host,
                 title: cat ? label + ": " + cat : label });
    });
    return out;
  }
  window.brSectionsIn = sectionsIn;

  // The category a node sits in, by its tab button's own text.
  function catLabelFor(el) {
    var panel = el && el.closest ? el.closest(".br-panel") : null;
    if (!panel || !panel.id) return "";
    var tab = panel.id.replace(/^panel-/, "");
    var btn = document.querySelector('.br-tab-btn[data-tab="' + tab + '"]');
    if (!btn) return "";
    var label = btn.textContent.trim();
    var badge = btn.querySelector(".br-pin-badge");
    if (badge) label = label.replace(badge.textContent.trim(), "").trim();
    return label;
  }

  function destLabel(btn) {
    var g = btn.getAttribute("data-group");
    var d = btn.getAttribute("data-destination");
    var b = document.querySelector('.br-destination-btn[data-group="' + g +
                                   '"][data-destination="' + d + '"]');
    return b ? b.textContent.trim() : d;
  }

  // Pin and PNG share one picker. Nothing is captured until the reader picks,
  // and a scope with exactly one anchor skips the dialog rather than asking a
  // question with one answer.
  function destPicker(btn, opts, run) {
    var scope = destScope(btn);
    var items = sectionsIn(scope);
    if (!items.length) {
      alert("There is nothing on this view to " + opts.verb + ".");
      return;
    }
    if (items.length === 1) { run(items); return; }
    if (typeof TurasPins === "undefined") { run([items[0]]); return; }
    var boxes = items.map(function (it) {
      return { key: it.key, label: it.label, available: true, checked: true };
    });
    TurasPins.showCheckboxPopover(btn, boxes, function (flags) {
      run(items.filter(function (it) { return flags[it.key]; }));
    }, btn.closest(".br-dest-tools") || btn.parentElement,
       { title: opts.title, actionLabel: opts.actionLabel });
  }

  window.brDestPin = function(btn) {
    destPicker(btn, { verb: "pin", title: "PIN TO VIEWS", actionLabel: "Pin" },
      function (items) {
        items.forEach(function (it) {
          if (typeof window.brPinFrom === "function") {
            window.brPinFrom(it.el, it.key, it.title || it.label);
          }
        });
        btn.classList.add("pin-flash");
        setTimeout(function () { btn.classList.remove("pin-flash"); }, 600);
      });
  };

  window.brDestPng = function(btn) {
    destPicker(btn, { verb: "export", title: "EXPORT AS PNG",
                      actionLabel: "Export" },
      function (items) {
        items.forEach(function (it) {
          if (typeof window.brExportPngFrom === "function") {
            window.brExportPngFrom(it.el, it.key, it.title || it.label);
          }
        });
      });
  };

  window.brDestExcel = function(btn) {
    var scope = destScope(btn);
    if (!scope) return;
    var g = btn.getAttribute("data-group");
    var d = btn.getAttribute("data-destination");
    var t = btn.getAttribute("data-tier") || "main";
    _brExportRoot(scope, g + "-" + d + (t === "advanced" ? "-advanced" : ""),
                  destLabel(btn));
  };

  // --- Destination commentary ---
  // One box per destination, hidden until asked for, and mirrored into the
  // saved file by the same textarea mirror every other commentary box uses.
  window.brToggleDestNote = function(btn) {
    var wrap = btn.closest(".br-dest-toolbar");
    var note = wrap ? wrap.querySelector(".br-dest-note") : null;
    if (!note) return;
    var opening = note.hidden;
    note.hidden = !opening;
    btn.setAttribute("aria-expanded", opening ? "true" : "false");
    // The label names the state, the way the significance toggle's does. An
    // open box still offering to add one is the same small lie.
    btn.textContent = opening ? "Commentary" : "+ Add commentary";
    if (opening) {
      var ta = note.querySelector("textarea");
      if (ta) ta.focus();
    }
  };

  // A saved report reopens with its commentary in the textarea's text
  // content, so a box that was written in must open again on load. Without
  // this the text is in the file and behind a click nobody knows to make.
  function openWrittenDestNotes() {
    document.querySelectorAll(".br-dest-note").forEach(function (note) {
      var ta = note.querySelector("textarea");
      if (!ta || !ta.value.trim()) return;
      note.hidden = false;
      var wrap = note.closest(".br-dest-toolbar");
      var btn = wrap ? wrap.querySelector(".br-dest-note-toggle") : null;
      if (btn) {
        btn.setAttribute("aria-expanded", "true");
        btn.textContent = "Commentary";
      }
    });
  }

  // ==========================================================================
  // Significance as a toggle, off by default, one control per destination
  // ==========================================================================
  // The idea is the tabs v2 sigMode: a reader asks for significance rather
  // than being given it. None of that code is reused; this is a class on the
  // destination and a stylesheet rule.
  //
  // CSS rather than DOM surgery, because the MA table, the funnel table and
  // the Mental Advantage focal view all re-render themselves on a focal
  // switch, a base toggle or a brand filter, and a DOM pass would have to be
  // chased after every one of them. An attribute on the destination survives
  // all of it, and survives Save, because it is a content attribute.
  //
  // The capture path is the part CSS cannot do on its own. TurasPins' inliner
  // skips values it reads as defaults, display:none among them, so a marker
  // hidden by CSS would come back on a pinned card or a PNG. brand_pins.js
  // wraps TurasPins.capturePortableHtml once and strips the markers out of
  // any capture taken from a destination whose toggle is off, so the card a
  // reader gets matches the page they were looking at.
  //
  // The funnel's nested view is a separate matter and the two agree by
  // construction: Stage 4 leaves those markers out of the markup because they
  // were computed on a different base, so turning significance on cannot make
  // them appear. The funnel's own "How this works" says so.
  window.brToggleDestSig = function(btn) {
    var dest = destOf(btn);
    if (!dest) return;
    var on = dest.getAttribute("data-br-sig") !== "on";
    dest.setAttribute("data-br-sig", on ? "on" : "off");
    dest.querySelectorAll(".br-sig-toggle").forEach(function (b) {
      b.setAttribute("aria-pressed", on ? "true" : "false");
      b.textContent = on ? "Significance: on" : "Significance: off";
    });
  };

  // Is the destination containing this element showing significance?
  // Anything outside a destination (the Portfolio tab, the Summary tab) is
  // left as it was: those are not destinations and have no toggle.
  window.brSigOnFor = function(el) {
    if (!el || !el.closest) return true;
    var dest = el.closest(".br-destination");
    if (!dest) return true;
    return dest.getAttribute("data-br-sig") === "on";
  };

  // ==========================================================================
  // "How this works": every explanatory block, collapsed, one per view
  // ==========================================================================
  // The blocks are moved, not rewritten and not deleted. Each one keeps its
  // own markup, its own text and its own bases; all that changes is that they
  // sit together at the foot of the view instead of between the analyses.
  //
  // Collected in the browser rather than assembled in R because the panels
  // emit them from fifteen different builders, several of them nested inside
  // fragments this file never sees as anything but a string. Nothing moved
  // here carries a data-section anchor, an id or a payload, so no anchor and
  // no island moves with them.
  var HOWTO_SELECTOR = [
    ".t-callout",                 // the shared callout registry's block
    "details.ma-chart-callout",   // MA chart notes
    "details.ma-adv-intro-callout",
    "details.cb-info-callout"     // Category Buying notes
  ].join(",");

  function brCollectHowTo() {
    document.querySelectorAll(".br-howto").forEach(function (drawer) {
      var body = drawer.querySelector(".br-howto-body");
      var scope = drawer.parentNode;
      if (!body || !scope) return;
      var found = 0;
      scope.querySelectorAll(HOWTO_SELECTOR).forEach(function (block) {
        if (block.closest(".br-howto")) return;
        // A callout that shipped collapsed had a disclosure of its own. The
        // drawer is now the disclosure, so opening it must show everything
        // rather than present a second thing to click. Stage 3 took the same
        // decision for the Overview's methodology callout.
        block.classList.remove("collapsed");
        if (block.tagName === "DETAILS") block.setAttribute("open", "");
        body.appendChild(block);
        found += 1;
      });
      if (found > 0) {
        drawer.hidden = false;
        var t = drawer.querySelector(".br-howto-count");
        if (t) t.textContent = String(found);
      }
    });
  }
  window.brCollectHowTo = brCollectHowTo;

  window.brToggleHowTo = function(btn) {
    var wrap = btn.closest(".br-howto");
    var body = wrap ? wrap.querySelector(".br-howto-body") : null;
    if (!body) return;
    var opening = body.hidden;
    body.hidden = !opening;
    btn.setAttribute("aria-expanded", opening ? "true" : "false");
  };

  // --- Insight editor ---
  window._brToggleInsight = function(sectionId) {
    var container = document.querySelector('.br-insight-container[data-section="' + sectionId + '"]');
    if (!container) return;
    var visible = container.style.display !== "none";
    container.style.display = visible ? "none" : "block";
    if (!visible) {
      var editor = container.querySelector(".br-insight-editor");
      if (editor) editor.focus();
    }
  };

  window._brToggleInsightEdit = function(sectionId) {
    var container = document.querySelector('.br-insight-container[data-section="' + sectionId + '"]');
    if (!container) return;
    var editor = container.querySelector(".br-insight-editor");
    var rendered = container.querySelector(".br-insight-rendered");
    if (!editor || !rendered) return;

    if (editor.style.display === "none") {
      editor.style.display = "block";
      rendered.style.display = "none";
      editor.focus();
    } else {
      rendered.innerHTML = _brRenderMd(editor.value);
      editor.style.display = "none";
      rendered.style.display = "block";
    }
  };

  window._brDismissInsight = function(sectionId) {
    var container = document.querySelector('.br-insight-container[data-section="' + sectionId + '"]');
    if (container) container.style.display = "none";
  };

  function _brRenderMd(md) {
    if (!md) return "";
    var html = md
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/^## (.+)$/gm, "<h4>$1</h4>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>")
      .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
      .replace(/^- (.+)$/gm, "<li>$1</li>");
    html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function(m) { return "<ul>" + m + "</ul>"; });
    return html.split("\n").map(function(line) {
      var t = line.trim();
      if (!t) return "";
      if (/^<(h4|ul|li|blockquote)/.test(t)) return t;
      return "<p>" + t + "</p>";
    }).join("\n");
  }

  // --- Table sorting ---
  function initTableSort() {
    document.querySelectorAll(".br-table th").forEach(function(th) {
      th.style.cursor = "pointer";
      th.addEventListener("click", function() {
        var table = th.closest("table");
        var tbody = table.querySelector("tbody");
        if (!tbody) return;
        var colIdx = Array.from(th.parentNode.children).indexOf(th);
        var rows = Array.from(tbody.querySelectorAll("tr"));
        var asc = th.getAttribute("data-sort-dir") !== "asc";
        th.setAttribute("data-sort-dir", asc ? "asc" : "desc");

        // Remove arrows from siblings
        th.parentNode.querySelectorAll("th").forEach(function(h) {
          h.textContent = h.textContent.replace(/ [▲▼]/g, "");
        });
        th.textContent += asc ? " ▲" : " ▼";

        rows.sort(function(a, b) {
          var av = a.children[colIdx] ? a.children[colIdx].textContent.trim() : "";
          var bv = b.children[colIdx] ? b.children[colIdx].textContent.trim() : "";
          var an = parseFloat(av.replace(/[%,]/g, ""));
          var bn = parseFloat(bv.replace(/[%,]/g, ""));
          if (!isNaN(an) && !isNaN(bn)) return asc ? an - bn : bn - an;
          return asc ? av.localeCompare(bv) : bv.localeCompare(av);
        });
        rows.forEach(function(r) { tbody.appendChild(r); });
      });
    });
  }

  // --- Commentary persistence: one mechanism for every textarea ---
  // A textarea's .value is live state that outerHTML never sees. Its text
  // content is what a saved file carries and what a browser loads back as
  // the initial value. Mirroring value into text content on every input
  // event (and once more just before Save serialises the page) makes every
  // commentary box in the report survive Save and reopen: the generic
  // .br-insight-editor, the funnel and cat-buying .fn-insight-textarea, the
  // MA / WoM / Branded Reach / Ad Hoc / Audience Lens .ma-insight-box-text
  // and the Summary .brsum-insight-editor. The MA and Audience Lens boxes
  // used sessionStorage / localStorage before, which a saved file never
  // carried and which two clients' reports sharing a category code
  // overwrote in one browser; both are retired (review 2026-07-12, C2 + H3).
  // Mirrors TurasPins, whose textContent store already survives Save.
  window._brSyncCommentary = function(ta) {
    if (!ta || !ta.tagName || ta.tagName !== "TEXTAREA") return;
    if (ta.textContent !== ta.value) ta.textContent = ta.value;
  };
  window._brSyncAllCommentary = function() {
    document.querySelectorAll("textarea").forEach(window._brSyncCommentary);
  };
  function initCommentaryPersistence() {
    ["input", "change"].forEach(function(evt) {
      document.addEventListener(evt, function(ev) {
        window._brSyncCommentary(ev.target);
      }, true);
    });
  }

  // --- Selection persistence: the same mirror, for the brand controls ---
  // The commentary mirror above exists because a textarea's .value is live
  // state that outerHTML never sees. Three more pieces of live state have
  // exactly that shape, and until this they were lost on Save:
  //
  //   * a checkbox's .checked. The content attribute is defaultChecked, so
  //     ticking a comparator changes nothing outerHTML can see.
  //   * an option's .selected. Same story: the content attribute is
  //     defaultSelected, so the focal brand a reader picked did not persist.
  //   * a panel's chart-only hidden set, which lives on its BrandSelector
  //     handle and never touched the DOM at all.
  //
  // The third one was the dangerous one. The note above a narrowed chart is
  // a plain text node, so it DID survive serialisation while the state
  // behind it did not: a reopened copy could show a note saying the chart
  // omits three brands with a chart that showed all of them. A client-facing
  // artefact making a false statement. BrandChartFocus.prepareForSave()
  // writes that set into the DOM here; restoreAll() reads it back after the
  // header has published on load, which is the only safe order because every
  // published set resets a panel's chart-only set to its table set.
  //
  // Scope is deliberate and narrow: the category header's own controls, plus
  // the per-chart deviation. Panel-local view state (base toggles, sort
  // order, the table-or-chart card switch) is not mirrored and never was.
  window._brSyncSelectionState = function() {
    document.querySelectorAll(".br-controls select").forEach(function (sel) {
      for (var i = 0; i < sel.options.length; i++) {
        var o = sel.options[i];
        if (o.selected) o.setAttribute("selected", "");
        else o.removeAttribute("selected");
      }
    });
    document.querySelectorAll(".br-controls input[type=\"checkbox\"]")
      .forEach(function (cb) {
        if (cb.checked) cb.setAttribute("checked", "");
        else cb.removeAttribute("checked");
        // disabled reflects on its own, but the focal brand's locked box is
        // the one control whose attribute must not drift, so it is written
        // rather than assumed.
        if (cb.disabled) cb.setAttribute("disabled", "");
        else cb.removeAttribute("disabled");
      });
    if (window.BrandChartFocus &&
        typeof window.BrandChartFocus.prepareForSave === "function") {
      window.BrandChartFocus.prepareForSave();
    }
  };

  // Everything a saved copy needs written into the DOM, in one place, so the
  // Save button and the QA round trip exercise the same code.
  window._brSyncReportState = function() {
    // Belt and braces: mirror every textarea once more before serialising,
    // in case a panel wrote .value programmatically without an input event.
    window._brSyncAllCommentary();
    window._brSyncSelectionState();
  };

  window._brSerialiseReport = function() {
    window._brSyncReportState();
    return "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
  };

  // --- Save report ---
  window._brSaveReport = function() {
    var html = window._brSerialiseReport();
    var blob = new Blob([html], { type: "text/html" });
    var meta = document.querySelector('meta[name="turas-source-filename"]');
    var fname = meta ? meta.content.replace(/\.html$/, "") + "_saved.html" : "brand_report.html";

    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: fname,
        types: [{ description: "HTML", accept: { "text/html": [".html"] } }]
      }).then(function(handle) {
        return handle.createWritable().then(function(w) {
          return w.write(blob).then(function() { return w.close(); });
        });
      }).catch(function() {});
    } else {
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = fname;
      a.click();
      URL.revokeObjectURL(a.href);
    }
  };

  // --- Help overlay ---
  window._brToggleHelp = function() {
    var overlay = document.getElementById("br-help-overlay");
    if (overlay) overlay.classList.toggle("open");
  };

  // --- Excel export ---
  // One workbook builder, two entry points. _brExportPanel takes a section
  // anchor and is what every existing button and every saved habit calls;
  // _brExportRoot takes an element and is what a destination toolbar uses,
  // because a destination has no anchor of its own by design. Neither reads
  // the other's scope, and the XML is written once.
  //
  // Sheet names come from the nearest enclosing anchor or leaf label rather
  // than a bare index, so a workbook of eleven tables says which analysis
  // each sheet came from. Excel caps a sheet name at 31 characters and
  // rejects : \ / ? * [ ], so the name is cleaned and de-duplicated.
  function _brSheetNames(tables, fallback) {
    var used = {}, out = [];
    tables.forEach(function (table, idx) {
      var host = table.closest("[data-section]") ||
                 table.closest("[data-leaf-label]");
      var raw = "";
      if (host) {
        raw = host.getAttribute("data-section") ||
              host.getAttribute("data-leaf-label") || "";
      }
      if (!raw) raw = fallback + (idx > 0 ? "_" + idx : "");
      raw = String(raw).replace(/[:\\\/?*\[\]]/g, " ").trim().substring(0, 28);
      if (!raw) raw = "Sheet";
      var name = raw, n = 1;
      while (used[name]) { n += 1; name = raw.substring(0, 26) + "_" + n; }
      used[name] = true;
      out.push(name);
    });
    return out;
  }

  // A workbook cell carries the figure its table cell displays, and nothing
  // else. Everything below exists because it did not: a category average of
  // 61% with a 51 to 72 range rail beneath it was written as 615172, because
  // textContent runs the figure and the two bounds together; "1/9" was
  // written as the number 1, because parseFloat reads a leading prefix and
  // discards the rest; and rows the reader's brand filter had hidden were in
  // the file anyway.

  // Interface furniture. A sort control is not data and never was.
  //
  // The significance markers are here for a reason worth writing down. Four
  // of the six classes draw an arrow, and the arrow strip at the foot of
  // _brVisibleText has always taken those out along with the sort arrows, so
  // a workbook has never carried them. The advantage tables draw an asterisk
  // instead, which no glyph rule catches, and once a cell is a whole number
  // or nothing at all, "+9.4 *" stops being a number while "+7.3" next to it
  // stays one. A column that is numeric except on its significant rows sorts
  // its own findings into a block at the bottom. So the marker is treated as
  // what it is, a mark the page puts beside a figure, and the six classes are
  // named together rather than four of them being dropped by accident of
  // which character they happen to use. The reader turns the markers on to
  // read them on screen; the workbook carries the figures.
  var _BR_CHROME = "button, input, select, .ct-sort-indicator, " +
                   ".cb-sort-ind, .pf-fp-sort-ind, .wom-sort-ind, " +
                   ".ma-sort-btn, .fn-sort-btn, " +
                   ".ma-sig, .ma-fv-sig, .ma-adv-sig, .ct-sig, " +
                   ".fn-sig-avg, .fn-sig";

  // The range rail: a bar and the two bounds under a figure. It is read as a
  // range, not as part of the figure, so it is left out of the cell's text.
  var _BR_RAIL = ".ma-ci-bar-wrap, .ma-ci-limits";

  var _BR_ENDASH = "–";

  // Is this node one the reader can see?
  //
  // The question asked is the node's OWN computed display, never an
  // ancestor's, and that is deliberate. A category tab or a Category Buying
  // sub-tab that is not the one on screen hides its whole subtree, and its
  // tables are still inside the destination the toolbar exports; an
  // ancestor-aware test (offsetParent, getClientRects) would drop them and
  // the export would fall silent on eight analyses. A node's own computed
  // display is unaffected by a hidden ancestor, so it catches exactly the
  // three things that record a reader's choice: the brand filter's
  // row.style.display, the portfolio footprint's hidden columns, and an
  // in-cell count annotation the stylesheet hides until Show count is on.
  function _brShown(el) {
    if (!el || el.nodeType !== 1) return true;
    if (el.style && el.style.display === "none") return false;
    if (typeof getComputedStyle !== "function") return true;
    var cs = null;
    try { cs = getComputedStyle(el); } catch (err) { return true; }
    if (!cs) return true;
    return cs.display !== "none" && cs.visibility !== "hidden";
  }

  // Does this element read as a separate piece of text?
  //
  // Anything but a plain inline run does. A block starts on its own line; an
  // inline-block is a pill with a margin, which is how the FOCAL badge, the
  // buyer badge and every other chip are drawn. Only a bare inline run flows
  // into the text beside it, which is what "1" and "/9" do in the portfolio
  // footprint's "1/9".
  function _brBreaks(el) {
    if (typeof getComputedStyle !== "function") return false;
    var cs = null;
    try { cs = getComputedStyle(el); } catch (err) { return false; }
    var d = cs && cs.display;
    return !!d && d !== "inline" && d !== "contents";
  }

  // The visible text of a node, with chrome and the rail left out.
  //
  // Two pieces of text are kept apart where the page keeps them apart, and
  // run together where it runs them together. An option label and its role
  // badge are two blocks, so "Prefer not to say" and "buyer" get a space; a
  // FOCAL badge is an inline-block pill, so a brand name and its badge get
  // one; a count is a block under its figure, so "10%" and "n=995 / 9,525"
  // get one. The portfolio footprint's "1" and "/9" are two bare inline
  // spans with nothing between them and read as one fraction, so they get
  // none. Joining every pair with a space would have written "1 /9".
  function _brVisibleText(node, skipRail) {
    var parts = [];
    (function walk(n) {
      var kids = n.childNodes || [];
      for (var i = 0; i < kids.length; i++) {
        var k = kids[i];
        if (k.nodeType === 3) {
          var raw = String(k.nodeValue || "");
          parts.push(raw.trim() ? raw : null);
          continue;
        }
        if (k.nodeType !== 1) continue;
        if (k.matches && k.matches(_BR_CHROME)) continue;
        if (skipRail && k.matches && k.matches(_BR_RAIL)) continue;
        if (!_brShown(k)) continue;
        var brk = _brBreaks(k);
        if (brk) parts.push(null);
        walk(k);
        if (brk) parts.push(null);
      }
    })(node);
    var out = "", gap = false;
    parts.forEach(function (p) {
      if (p === null) { gap = true; return; }
      var t = String(p).replace(/\s+/g, " ").trim();
      if (!t) return;
      if (out && gap) out += " ";
      out += t;
      gap = false;
    });
    // initTableSort appends an arrow to a header's own text; the panel sort
    // buttons draw their own. Neither is content.
    return out.replace(/[▲▼↑↓↕⇅]/g, "").trim();
  }

  // The rail under a figure, when the reader can see it: its two bounds and
  // what the page itself calls the range. The MA and funnel tables title it
  // "95% CI: 5% to 8%" and Category Buying titles it one standard deviation
  // across brands, so the name is read from the title rather than assumed.
  // Calling a standard deviation a confidence interval would be a fabricated
  // statistic.
  function _brCellRange(cell) {
    if (!cell || !cell.querySelector) return null;
    var lim = cell.querySelector(".ma-ci-limits");
    if (!lim || !_brShown(lim)) return null;
    var spans = lim.querySelectorAll("span");
    if (spans.length < 2) return null;
    var lo = _brVisibleText(spans[0]);
    var hi = _brVisibleText(spans[1]);
    if (!lo && !hi) return null;
    var wrap = cell.querySelector(".ma-ci-bar-wrap");
    var title = (wrap && wrap.getAttribute("title")) || "";
    var label = title.split(":")[0].trim() || "range";
    return { lo: lo, hi: hi, label: label };
  }

  function _brXmlEsc(s) {
    return String(s).replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;");
  }

  // A cell is a number only when the whole of it is one: sign, thousands
  // separators and a trailing per cent included. parseFloat on its own reads
  // "5 Roses" as 5 and "1/9" as 1.
  var _BR_NUMERIC = /^[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?%?$/;

  function _brDataCell(text) {
    var t = String(text == null ? "" : text).trim();
    if (t !== "" && _BR_NUMERIC.test(t)) {
      var n = parseFloat(t.replace(/[%,]/g, ""));
      if (isFinite(n)) {
        return '<Cell><Data ss:Type="Number">' + n + "</Data></Cell>";
      }
    }
    return '<Cell><Data ss:Type="String">' + _brXmlEsc(t) + "</Data></Cell>";
  }

  // One table, read as a grid of what a reader can see. Hidden rows and
  // hidden columns are not in it. Column positions account for colspan so a
  // banner row above the header does not shift the columns beneath it.
  function _brReadTable(table) {
    var grid = [];
    table.querySelectorAll("tr").forEach(function (tr) {
      if (!_brShown(tr)) return;
      var cells = [], col = 0;
      tr.querySelectorAll("th, td").forEach(function (cell) {
        if (!_brShown(cell)) return;
        var span = parseInt(cell.getAttribute("colspan"), 10);
        if (!isFinite(span) || span < 1) span = 1;
        cells.push({
          col: col,
          span: span,
          header: cell.tagName === "TH",
          text: _brVisibleText(cell, true),
          range: _brCellRange(cell)
        });
        col += span;
      });
      grid.push(cells);
    });
    return grid;
  }

  // Where the ranges sit decides where their numbers go. On the MA matrix and
  // the funnel relationship table the category average is a COLUMN, so two
  // columns beside it read naturally. On the Metrics table it is a ROW with a
  // rail in every metric column, and two columns per metric would leave every
  // brand row carrying en dashes in most of them, so the bounds go in two
  // rows underneath instead.
  function _brRangePlan(grid) {
    var rows = {}, cols = {}, colLabel = {}, nR = 0, nC = 0;
    grid.forEach(function (cells, ri) {
      cells.forEach(function (c) {
        if (!c.range) return;
        if (!rows[ri]) { rows[ri] = true; nR += 1; }
        if (!cols[c.col]) {
          cols[c.col] = true; nC += 1; colLabel[c.col] = c.range.label;
        }
      });
    });
    return { shape: nC === 0 ? "none" : (nC <= nR ? "cols" : "rows"),
             cols: cols, colLabel: colLabel };
  }

  function _brRowXml(cells, plan) {
    var xml = "<Row>";
    cells.forEach(function (c) {
      xml += _brDataCell(c.text);
      if (plan.shape !== "cols") return;
      for (var k = c.col; k < c.col + c.span; k++) {
        if (!plan.cols[k]) continue;
        if (k === c.col && c.header) {
          var base = c.text ? c.text + " " : "";
          xml += _brDataCell(base + "(" + plan.colLabel[k] + " low)");
          xml += _brDataCell(base + "(" + plan.colLabel[k] + " high)");
        } else if (k === c.col && c.range) {
          xml += _brDataCell(c.range.lo || _BR_ENDASH);
          xml += _brDataCell(c.range.hi || _BR_ENDASH);
        } else {
          xml += _brDataCell(_BR_ENDASH);
          xml += _brDataCell(_BR_ENDASH);
        }
      }
    });
    return xml + "</Row>";
  }

  // The two bound rows under a row-shaped range. The first cell names them
  // from the row they belong to, so "Category average" is followed by
  // "Category average (95% CI low)".
  function _brBoundRowXml(cells, which) {
    var label = "range";
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].range) { label = cells[i].range.label; break; }
    }
    var head = (cells[0] && cells[0].text ? cells[0].text + " " : "") +
               "(" + label + " " + (which === "lo" ? "low" : "high") + ")";
    var xml = "<Row>";
    cells.forEach(function (c, i) {
      if (i === 0 && !c.range) { xml += _brDataCell(head); return; }
      xml += _brDataCell(c.range ? (c.range[which] || _BR_ENDASH) : _BR_ENDASH);
    });
    return xml + "</Row>";
  }

  function _brTablesToWorkbook(tables, fallback) {
    var names = _brSheetNames(tables, fallback);
    var xml = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">';
    tables.forEach(function (table, idx) {
      var grid = _brReadTable(table);
      var plan = _brRangePlan(grid);
      xml += '<Worksheet ss:Name="' + names[idx] + '"><Table>';
      grid.forEach(function (cells) {
        xml += _brRowXml(cells, plan);
        if (plan.shape !== "rows") return;
        if (!cells.some(function (c) { return !!c.range; })) return;
        xml += _brBoundRowXml(cells, "lo");
        xml += _brBoundRowXml(cells, "hi");
      });
      xml += "</Table></Worksheet>";
    });
    xml += "</Workbook>";
    return xml;
  }

  // Exposed so modules/brand/tests/js/test_excel_export.js can drive the
  // builder directly against a stub DOM. Nothing in the report calls it
  // through window; the two entry points below call it in scope.
  window._brTablesToWorkbook = _brTablesToWorkbook;

  function _brDownloadWorkbook(xml, filename) {
    var blob = new Blob([xml], { type: "application/vnd.ms-excel" });
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename + ".xls";
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function _brExportRoot(root, filename, whatItIs) {
    if (!root) return;
    var tables = root.querySelectorAll("table.br-table");
    if (tables.length === 0) tables = root.querySelectorAll("table");
    if (tables.length === 0) {
      alert("There is no table on " + (whatItIs || "this view") + " to export.");
      return;
    }
    _brDownloadWorkbook(_brTablesToWorkbook(tables, filename), filename);
  }
  window._brExportRoot = _brExportRoot;

  // A section anchor names several elements, not one.
  //
  // data-section is on the pin button and the insight box as well as on the
  // panel, because each of those is addressed by the same anchor name. Asking
  // for the first match in document order gave the Portfolio sub-tabs their
  // own pin button, which holds no table, so all four of their Excel buttons
  // said "There is no table on this section to export" while the sub-tab
  // beneath them held one. That was true at 33000b28 and is not a regression;
  // the pf- clause below it was written for this and never ran, because the
  // pin button had already satisfied the test.
  //
  // The candidates are gathered in order of how specific they are, and the
  // first one that actually holds a table wins. A named element with no table
  // still wins over nothing at all, so a genuinely empty section keeps its
  // old message rather than exporting some neighbour's numbers.
  window._brExportPanel = function(panelId) {
    var seen = [], panel = null;
    function offer(el) {
      if (!el || seen.indexOf(el) !== -1) return;
      seen.push(el);
      if (!panel) panel = el;
    }
    offer(document.getElementById("section-" + panelId));
    if (/^pf-/.test(panelId)) {
      offer(document.getElementById(panelId.replace(/^pf-/, "pf-subtab-")));
    }
    document.querySelectorAll('[data-section="' + panelId + '"]')
            .forEach(offer);
    for (var i = 0; i < seen.length; i++) {
      if (seen[i].querySelector && seen[i].querySelector("table")) {
        panel = seen[i];
        break;
      }
    }
    if (!panel) return;
    _brExportRoot(panel, panelId, "this section");
  };

  // Publish every category's opening state once, so the header and the
  // panels agree from the first paint rather than only after a click.
  //
  // This has to run after the panels have registered with BrandSelector,
  // because categoryBrands() is a union over registered subscribers and
  // would return an empty list before then. brand_report.js is first in the
  // bundle, so its DOMContentLoaded handler runs before every panel's;
  // window load runs after all of them.
  function brApplyAllComparisonSets() {
    var seen = {};
    document.querySelectorAll(".br-cmp-popover[data-group]").forEach(function (p) {
      var g = p.getAttribute("data-group");
      if (!g || seen[g]) return;
      seen[g] = true;
      window.brApplyComparisonSet(g);
    });
    // A reopened saved copy carries each chart's deviation as an attribute.
    // It is put back here and nowhere else, because every published set
    // resets a panel's chart-only set to its table set, so a restore that
    // ran before the loop above would be wiped by it. This is the one place
    // that is guaranteed to be after every header publish on load.
    if (window.BrandChartFocus &&
        typeof window.BrandChartFocus.restoreAll === "function") {
      window.BrandChartFocus.restoreAll();
    }
    // After every panel has painted, so a callout a panel builds at run time
    // is collected with the ones R wrote into the file.
    brCollectHowTo();
  }
  window.brApplyAllComparisonSets = brApplyAllComparisonSets;

  // --- Init ---
  function init() {
    initTableSort();
    initCommentaryPersistence();
    openWrittenDestNotes();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  if (document.readyState === "complete") {
    setTimeout(brApplyAllComparisonSets, 0);
  } else {
    window.addEventListener("load", function () {
      setTimeout(brApplyAllComparisonSets, 0);
    });
  }
})();
