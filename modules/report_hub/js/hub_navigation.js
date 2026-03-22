/**
 * Report Hub Navigation Controller (iframe approach)
 *
 * Manages Level 1 report switching with lazy-loaded iframes.
 * Each report's HTML is base64-encoded and decoded at runtime,
 * then set as iframe.srcdoc with ZERO string manipulation.
 * Bridge functionality (header hiding, pin button) is injected
 * via DOM API after iframe loads — no regex, no script sanitization.
 */

var ReportHub = ReportHub || {};

(function() {
  "use strict";

  var activeReport = "overview";

  /** Decode a base64 string to a UTF-8 string */
  function decodeBase64(b64) {
    var binary = atob(b64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return new TextDecoder().decode(bytes);
  }

  /** Encode a UTF-8 string to base64 */
  function encodeBase64(str) {
    var bytes = new TextEncoder().encode(str);
    var binary = "";
    for (var i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  /**
   * Inject bridge functionality into a loaded iframe via DOM API.
   * This is called AFTER the iframe has fully loaded, so we interact
   * with a live document — no HTML string manipulation needed.
   */
  /**
   * Report label lookup for pin source badges
   */
  var reportLabels = {};

  function getReportLabel(key) {
    if (reportLabels[key]) return reportLabels[key];
    var tab = document.querySelector('.hub-tab[data-hub-tab="' + key + '"]');
    return tab ? tab.textContent.trim() : key;
  }

  function injectBridge(iframe, key) {
    try {
      var doc = iframe.contentDocument;
      var win = iframe.contentWindow;
      if (!doc) return;

      // Set up cross-frame communication
      win._hubReportKey = key;
      win.pinToHub = function(data) {
        if (window.ReportHub && window.ReportHub.addPin) {
          data.sourceLabel = getReportLabel(key);
          window.ReportHub.addPin(key, data);
        }
      };

      // Hide report headers and make nav strips sticky (hub provides its own header)
      var style = doc.createElement("style");
      style.textContent =
        ".header, .tk-header, .ci-header, .wt-header, .md-header, " +
        ".cj-header, .seg-header, .pr-header, .cd-header, .kd-header " +
        "{ display:none !important; } " +
        // Make all report nav strips sticky so they stay visible on scroll
        ".report-tabs, .banner-tabs, " +
        ".cj-report-tabs, .cj-slide-tabs, " +
        ".md-tab-nav, .md-subtab-nav, " +
        ".pr-tab-nav, " +
        ".kd-report-tabs, .cd-factor-tabs, .seg-report-tabs " +
        "{ position:sticky !important; top:0 !important; z-index:50 !important; " +
        "background:#fff !important; } " +
        ".hub-pin-float { position:fixed; bottom:20px; right:20px; z-index:9999; " +
        "background:var(--hub-bridge-brand, #323367); color:#fff; border:none; border-radius:8px; " +
        "padding:10px 18px; font-size:13px; font-weight:500; cursor:pointer; " +
        "box-shadow:0 2px 12px rgba(0,0,0,0.2); transition:all 0.2s; " +
        "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif; } " +
        ".hub-pin-float:hover { background:var(--hub-bridge-accent, #CC9900); " +
        "transform:translateY(-1px); box-shadow:0 4px 16px rgba(0,0,0,0.25); }";
      doc.head.appendChild(style);

      // Intercept the report's pin system via two mechanisms:
      // 1. MutationObserver on pinned-views-data store (catches modules that call savePinnedData)
      // 2. Monkey-patching known pin functions (catches modules that don't call savePinnedData)
      interceptReportPins(doc, win, key);
      patchModulePinFunctions(doc, win, key);

      // Track user edits inside the iframe (insights, slide titles, etc.)
      // so we only re-serialize iframes that were actually modified on save.
      // Uses targeted listeners on editable elements rather than a blanket
      // input listener (which can fire on scrolls in some browsers).
      ReportHub.dirtyIframes = ReportHub.dirtyIframes || {};
      var markDirty = function() { ReportHub.dirtyIframes[key] = true; };
      // Listen for input on textareas (insight editors) and contenteditable
      doc.addEventListener("input", function(e) {
        var tag = e.target.tagName;
        if (tag === "TEXTAREA" || tag === "INPUT" ||
            e.target.getAttribute("contenteditable") === "true") {
          markDirty();
        }
      });
      // Also catch blur on contenteditable (some browsers don't fire input)
      doc.addEventListener("focusout", function(e) {
        if (e.target.getAttribute && e.target.getAttribute("contenteditable") === "true") {
          markDirty();
        }
      });

    } catch (e) {
      console.warn("Could not inject bridge for " + key + ":", e.message);
    }
  }

  /**
   * Intercept a report's internal pin system so new pins flow to the hub.
   * Uses a MutationObserver on the report's #pinned-views-data element,
   * which all report types update via savePinnedData(). This avoids the
   * need to monkey-patch closure-scoped arrays.
   */
  function interceptReportPins(doc, win, key) {
    // Different modules use different element IDs for their pinned data store.
    // Try known IDs first, then fall back to any element with ID ending in
    // "-pinned-views-data" (auto-discovers future module conventions).
    var knownIds = [
      "pinned-views-data",
      "seg-pinned-views-data",
      "cd-pinned-views-data",
      "kd-pinned-views-data",
      "md-pinned-views-data",
      "cj-pinned-views-data",
      "pr-pinned-views-data"
    ];

    function findStore() {
      // Try known IDs
      for (var si = 0; si < knownIds.length; si++) {
        var el = doc.getElementById(knownIds[si]);
        if (el) return el;
      }
      // Fallback: query any element whose ID ends with "-pinned-views-data"
      var wildcard = doc.querySelector('[id$="-pinned-views-data"]');
      if (wildcard) return wildcard;
      // Also try just "pinned-views-data" as attribute (non-id match)
      return null;
    }

    var attempts = 0;
    var maxAttempts = 50; // 5 seconds — large reports may init slowly
    var interval = setInterval(function() {
      attempts++;
      var store = findStore();
      if (store) {
        clearInterval(interval);
        observePinnedStore(store, win, key);
      } else if (attempts >= maxAttempts) {
        clearInterval(interval);
        // Final fallback: observe document body for late-created pin stores
        observeForLateStore(doc, win, key);
      }
    }, 100);
  }

  /**
   * Fallback: watch the iframe document body for dynamically created
   * pin store elements. Some report modules create these lazily.
   */
  function observeForLateStore(doc, win, key) {
    if (!doc.body) return;
    var bodyObserver = new MutationObserver(function(mutations) {
      for (var m = 0; m < mutations.length; m++) {
        for (var n = 0; n < mutations[m].addedNodes.length; n++) {
          var node = mutations[m].addedNodes[n];
          if (node.id && node.id.indexOf("pinned-views-data") !== -1) {
            bodyObserver.disconnect();
            observePinnedStore(node, win, key);
            return;
          }
        }
      }
    });
    bodyObserver.observe(doc.body, { childList: true, subtree: true });
    // Auto-disconnect after 30 seconds to prevent memory leak
    setTimeout(function() { bodyObserver.disconnect(); }, 30000);
  }

  /**
   * Monkey-patch known module pin functions to ensure pins are forwarded
   * to the hub. This handles modules that push to their pinnedViews array
   * but don't call savePinnedData() (the MutationObserver never fires).
   * Polls for function availability since modules initialize asynchronously.
   */
  function patchModulePinFunctions(doc, win, key) {
    var label = getReportLabel(key);

    // Known module-specific pin function names (window-scoped)
    var pinFunctions = [
      // catdriver
      "cdPinSection", "cdPinComponent",
      // keydriver
      "kdPinSection", "kdPinComponent",
      // maxdiff (uses private scope, but has savePinnedData via $ selector)
      // tracker, tabs, pricing, conjoint — these call savePinnedData, observer works
    ];

    // Known module-specific pin array getters
    var arrayGetters = [
      { getter: "cdGetPinnedViews", save: "cdSavePinnedData" },
      { getter: "kdGetPinnedViews", save: "kdSavePinnedData" }
    ];

    var attempts = 0;
    var patchInterval = setInterval(function() {
      attempts++;
      var patched = false;

      // Strategy: wrap the save functions to also forward new pins
      for (var g = 0; g < arrayGetters.length; g++) {
        var ag = arrayGetters[g];
        if (win[ag.save] && !win[ag.save]._hubPatched) {
          (function(saveFn, getterFn) {
            var original = win[saveFn];
            var forwardedIds = {};

            // Read initial state
            if (win[getterFn]) {
              var initial = win[getterFn]();
              if (initial) {
                for (var i = 0; i < initial.length; i++) {
                  if (initial[i].id) forwardedIds[initial[i].id] = true;
                }
              }
            }

            win[saveFn] = function() {
              original.call(this);
              // After save, check for new pins
              if (win[getterFn]) {
                var pins = win[getterFn]();
                for (var j = 0; j < pins.length; j++) {
                  var item = pins[j];
                  if (item.id && !forwardedIds[item.id] && item.type !== "section") {
                    forwardedIds[item.id] = true;
                    var hubPin = {};
                    for (var prop in item) {
                      if (item.hasOwnProperty(prop)) hubPin[prop] = item[prop];
                    }
                    hubPin.sourceLabel = label;
                    if (!hubPin.title) hubPin.title = hubPin.sectionTitle || hubPin.panelLabel || "Pinned View";
                    if (!hubPin.timestamp) hubPin.timestamp = Date.now();
                    if (hubPin.tableHtml) {
                      hubPin.tableHtml = inlineTableStyles(doc, hubPin.tableHtml);
                    }
                    win.pinToHub(hubPin);
                  }
                }
              }
            };
            win[saveFn]._hubPatched = true;
          })(ag.save, ag.getter);
          patched = true;
        }
      }

      if (patched || attempts >= 30) {
        clearInterval(patchInterval);
      }
    }, 200);
  }

  /**
   * Inline computed visual styles on table HTML so it renders correctly
   * outside the report's CSS context. Creates a temporary element inside
   * the report iframe (which has the CSS), computes styles, and inlines
   * only the visual properties needed for correct rendering.
   * @param {Document} iframeDoc - The iframe's document (has report CSS)
   * @param {string} tableHtml - Raw table HTML from the pin
   * @returns {string} Table HTML with inlined styles
   */
  function inlineTableStyles(iframeDoc, tableHtml) {
    if (!tableHtml || !iframeDoc || !iframeDoc.body) return tableHtml;

    try {
      var temp = iframeDoc.createElement("div");
      temp.style.cssText = "position:absolute;left:-9999px;top:-9999px;visibility:hidden;";
      iframeDoc.body.appendChild(temp);
      temp.innerHTML = tableHtml;

      // Properties to inline for visual fidelity
      var PROPS = [
        "background-color", "color", "font-weight", "font-size", "font-style",
        "text-align", "padding", "padding-left", "padding-right", "padding-top", "padding-bottom",
        "border-bottom", "border-left", "border-right", "border-top",
        "width", "min-width", "max-width", "vertical-align", "white-space",
        "border-collapse", "border-spacing"
      ];

      var elements = temp.querySelectorAll("table, thead, tbody, tr, th, td, span, div");
      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var cs = iframeDoc.defaultView.getComputedStyle(el);
        var inlined = [];

        for (var p = 0; p < PROPS.length; p++) {
          var prop = PROPS[p];
          var val = cs.getPropertyValue(prop);
          if (!val || val === "initial" || val === "inherit" || val === "normal") continue;

          // Skip transparent/default backgrounds
          if (prop === "background-color" && (val === "rgba(0, 0, 0, 0)" || val === "transparent")) continue;
          // Skip default black text
          if (prop === "color" && (val === "rgb(0, 0, 0)" || val === "rgba(0, 0, 0, 0)")) continue;
          // Skip normal font-weight
          if (prop === "font-weight" && (val === "400" || val === "normal")) continue;
          // Skip default font-size (inherit from hub)
          if (prop === "font-size" && val === "16px") continue;
          // Skip auto widths
          if ((prop === "width" || prop === "min-width" || prop === "max-width") && val === "auto") continue;

          inlined.push(prop + ":" + val);
        }

        if (inlined.length > 0) {
          // Merge with existing inline styles
          var existing = el.getAttribute("style") || "";
          el.setAttribute("style", existing + (existing ? ";" : "") + inlined.join(";"));
        }

        // Remove class attributes — they mean nothing outside the report CSS
        el.removeAttribute("class");
      }

      var result = temp.innerHTML;
      iframeDoc.body.removeChild(temp);
      return result;
    } catch (e) {
      console.warn("Could not inline table styles:", e.message);
      return tableHtml;
    }
  }

  function observePinnedStore(store, win, key) {
    var label = getReportLabel(key);
    // Track what we've already forwarded by pin id
    var forwardedIds = {};

    // Parse initial state so we don't forward pre-existing pins
    try {
      var initial = JSON.parse(store.textContent || "[]");
      for (var i = 0; i < initial.length; i++) {
        if (initial[i].id) forwardedIds[initial[i].id] = true;
      }
    } catch (e) { /* empty or invalid */ }

    // Watch for changes to the store's text content
    var observer = new MutationObserver(function() {
      try {
        var pins = JSON.parse(store.textContent || "[]");
        for (var j = 0; j < pins.length; j++) {
          var item = pins[j];
          if (item.id && !forwardedIds[item.id]) {
            forwardedIds[item.id] = true;
            // Forward the entire pin object to the hub, adding source label.
            // Preserve all report-specific fields so formatting is retained.
            var hubPin = {};
            for (var prop in item) {
              if (item.hasOwnProperty(prop)) hubPin[prop] = item[prop];
            }
            hubPin.sourceLabel = label;
            if (!hubPin.title) hubPin.title = hubPin.metricLabel || hubPin.qCode || "Pinned View";
            if (!hubPin.timestamp) hubPin.timestamp = Date.now();

            // Inline computed styles on table HTML so it renders correctly
            // outside the report's CSS context (the hub has no report CSS).
            if (hubPin.tableHtml) {
              hubPin.tableHtml = inlineTableStyles(store.ownerDocument, hubPin.tableHtml);
            }

            win.pinToHub(hubPin);
          }
        }
      } catch (e) {
        console.warn("Failed to forward pin to hub:", e.message);
      }
    });

    // Observe all mutation types to catch both textContent and innerHTML updates
    observer.observe(store, { childList: true, characterData: true, subtree: true, attributes: true });
  }

  /**
   * Load a report into its iframe (lazy — only on first activation)
   */
  function loadIframe(key) {
    if (ReportHub.loadedIframes[key]) return;

    var dataEl = document.getElementById("hub-report-" + key);
    var iframe = document.getElementById("hub-iframe-" + key);
    var loading = document.getElementById("hub-loading-" + key);

    if (!dataEl || !iframe) return;

    // Decode the base64-encoded HTML
    var html;
    try {
      html = decodeBase64(dataEl.textContent.trim());
    } catch (e) {
      console.error("Failed to decode report HTML for " + key + ":", e);
      if (loading) {
        loading.querySelector(".hub-loading-text").textContent = "Failed to load report";
      }
      return;
    }

    // Set srcdoc directly — no sanitization, no string manipulation.
    // The HTML is set as-is, exactly as the standalone report works.
    iframe.srcdoc = html;

    // Track load timeout — if the iframe doesn't load within 15 seconds,
    // show an error with a retry button instead of an infinite spinner.
    var loadTimer = setTimeout(function() {
      if (loading) {
        var text = loading.querySelector(".hub-loading-text");
        var spinner = loading.querySelector(".hub-loading-spinner");
        if (spinner) spinner.style.display = "none";
        if (text) {
          text.innerHTML = 'Report is taking too long to load. ' +
            '<button style="margin-top:8px;padding:6px 16px;border:1px solid #ccc;' +
            'border-radius:6px;background:#fff;cursor:pointer;font-size:13px;" ' +
            'onclick="ReportHub.retryLoad(\'' + key + '\')">Retry</button>';
        }
      }
    }, 15000);

    iframe.addEventListener("load", function() {
      clearTimeout(loadTimer);

      // Hide loading indicator
      if (loading) loading.style.display = "none";

      // Inject bridge via DOM API (header hiding, pin button, cross-frame comms)
      injectBridge(iframe, key);

      // Trigger resize for layout recalculation inside iframe
      try {
        iframe.contentWindow.dispatchEvent(new Event("resize"));
      } catch (e) { /* cross-origin safety */ }
    });

    ReportHub.loadedIframes[key] = true;
  }

  /**
   * Retry loading a report that timed out
   */
  ReportHub.retryLoad = function(key) {
    ReportHub.loadedIframes[key] = false;
    var loading = document.getElementById("hub-loading-" + key);
    if (loading) {
      loading.style.display = "";
      var spinner = loading.querySelector(".hub-loading-spinner");
      var text = loading.querySelector(".hub-loading-text");
      if (spinner) spinner.style.display = "";
      if (text) text.textContent = "Loading report...";
    }
    loadIframe(key);
  };

  /**
   * Switch the active Level 1 report panel
   */
  ReportHub.switchReport = function(key) {
    activeReport = key;

    // Update tab active states
    var tabs = document.querySelectorAll(".hub-tab");
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle("active", tabs[i].getAttribute("data-hub-tab") === key);
    }

    // Show/hide panels
    var panels = document.querySelectorAll(".hub-panel");
    for (var j = 0; j < panels.length; j++) {
      panels[j].classList.toggle("active", panels[j].getAttribute("data-hub-panel") === key);
    }

    // Lazy-load iframe on first activation
    if (key !== "overview" && key !== "pinned" && key !== "about") {
      loadIframe(key);
    }

    // Update URL hash
    if (history.replaceState) {
      history.replaceState(null, "", "#" + key);
    }

    // Trigger resize for layout recalculation
    window.dispatchEvent(new Event("resize"));

    // Also trigger resize inside the active iframe
    var iframe = document.getElementById("hub-iframe-" + key);
    if (iframe && iframe.contentWindow) {
      try {
        iframe.contentWindow.dispatchEvent(new Event("resize"));
      } catch (e) { /* cross-origin safety */ }
    }
  };

  /**
   * Get the currently active report key
   */
  ReportHub.getActiveReport = function() {
    return activeReport;
  };

  /**
   * Initialize the hub navigation
   */
  ReportHub.initNavigation = function() {
    // Check URL hash for deep link
    var hash = window.location.hash.replace("#", "");
    if (hash && hash !== "overview") {
      // Verify this key exists
      var panel = document.querySelector('.hub-panel[data-hub-panel="' + hash + '"]');
      if (panel) {
        ReportHub.switchReport(hash);
        return;
      }
    }
    // Default to overview
    ReportHub.switchReport("overview");

    // Keyboard navigation (arrow keys on hub tabs)
    var allKeys = ["overview"].concat(ReportHub.reportKeys).concat(["pinned"]);
    document.addEventListener("keydown", function(e) {
      var focused = document.activeElement;
      var isTabFocused = focused && focused.classList &&
        (focused.classList.contains("hub-tab"));
      var isBodyFocused = focused === document.body || focused.tagName === "BODY";

      if (!isTabFocused && !isBodyFocused) return;

      if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
        var idx = allKeys.indexOf(activeReport);
        if (idx === -1) return;
        if (e.key === "ArrowRight" && idx < allKeys.length - 1) {
          ReportHub.switchReport(allKeys[idx + 1]);
        } else if (e.key === "ArrowLeft" && idx > 0) {
          ReportHub.switchReport(allKeys[idx - 1]);
        }
      }
    });
  };

  /**
   * Hub-level Save Report
   *
   * Serializes the entire hub including updated iframe contents.
   * Each iframe's current state is read and re-encoded to its base64 store,
   * so saved reports preserve user edits (insights, pins, etc.).
   *
   * Key safeguards:
   *  1. Syncs all textarea/contenteditable values to DOM attributes before
   *     outerHTML capture (prevents data loss — outerHTML reads attributes,
   *     not DOM properties).
   *  2. Only re-serializes iframes flagged as dirty (user made edits).
   *  3. Strips bridge-injected styles and clears report-internal pin stores
   *     before capture (pins live centrally in hub-pinned-data).
   *  4. Strips iframe srcdoc attributes from the outer document to avoid
   *     duplicating decoded HTML alongside the base64 store.
   *  5. Provides save feedback on all browsers (Chromium + fallback).
   */
  ReportHub.saveReportHTML = function() {
    // Stamp the date in header
    var dateEl = document.getElementById("hub-header-date");
    if (dateEl) {
      var now = new Date();
      var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      dateEl.textContent = "Last saved " + now.getDate() + " " + months[now.getMonth()] + " " + now.getFullYear();
    }

    // Save pinned data to the JSON store element
    if (typeof ReportHub.savePinnedData === "function") {
      ReportHub.savePinnedData();
    }

    // ---- CRITICAL: Sync all outer-document form values to DOM attributes ----
    // outerHTML captures the HTML attribute, NOT the DOM .value property.
    // Without this, user-typed textarea content (executive summary, slides,
    // about notes, insight editors) is silently lost on save/reload.
    syncFormStateToDom(document);

    // ---- Re-serialize dirty iframes ----
    // Only iframes where the user actually made edits (insights, etc.)
    // are re-encoded. Unmodified iframes keep their original base64 data.
    var dirtyFrames = ReportHub.dirtyIframes || {};
    for (var ki = 0; ki < ReportHub.reportKeys.length; ki++) {
      var rKey = ReportHub.reportKeys[ki];
      if (!ReportHub.loadedIframes[rKey] || !dirtyFrames[rKey]) continue;

      var iframe = document.getElementById("hub-iframe-" + rKey);
      var dataEl = document.getElementById("hub-report-" + rKey);
      if (!iframe || !dataEl || !iframe.contentDocument) continue;

      try {
        var iDoc = iframe.contentDocument;

        // Sync iframe form values too (insight textareas inside reports)
        syncFormStateToDom(iDoc);

        // 1. Remove bridge-injected styles (added by injectBridge)
        var bridgeStyles = iDoc.querySelectorAll("style");
        var removedStyles = [];
        for (var si = bridgeStyles.length - 1; si >= 0; si--) {
          var s = bridgeStyles[si];
          if (s.textContent.indexOf("hub-pin-float") !== -1) {
            s.parentNode.removeChild(s);
            removedStyles.push(s);
            break;
          }
        }

        // 2. Clear report's internal pin store — pins are already in the
        //    hub's central store, so keeping them in the iframe doubles
        //    storage. Save the original content to restore after capture.
        var pinStoreEls = iDoc.querySelectorAll('[id$="-pinned-views-data"]');
        var savedStores = [];
        for (var pi = 0; pi < pinStoreEls.length; pi++) {
          var pStore = pinStoreEls[pi];
          savedStores.push({ el: pStore, content: pStore.textContent });
          pStore.textContent = "[]";
        }

        // 3. Also clear rendered pin cards in the report's own pinned panel
        var pinnedContainer = iDoc.getElementById("pinned-cards-container");
        var savedPinnedHtml = null;
        if (pinnedContainer) {
          savedPinnedHtml = pinnedContainer.innerHTML;
          pinnedContainer.innerHTML = "";
        }

        // 4. Capture the cleaned HTML
        var updatedHTML = "<!DOCTYPE html>\n" + iDoc.documentElement.outerHTML;
        dataEl.textContent = encodeBase64(updatedHTML);

        // 5. Restore everything for the live view
        for (var ri = 0; ri < removedStyles.length; ri++) {
          iDoc.head.appendChild(removedStyles[ri]);
        }
        for (var qi = 0; qi < savedStores.length; qi++) {
          savedStores[qi].el.textContent = savedStores[qi].content;
        }
        if (pinnedContainer && savedPinnedHtml !== null) {
          pinnedContainer.innerHTML = savedPinnedHtml;
        }
      } catch (e) {
        console.warn("Could not save iframe state for " + rKey + ":", e.message);
      }
    }

    // Strip iframe srcdoc attributes before serializing — the report HTML
    // is already stored in base64 <script> elements and reloaded from there.
    // This prevents the full decoded report HTML from being duplicated in
    // the outer page's outerHTML, saving significant file size.
    var iframes = document.querySelectorAll(".hub-report-iframe");
    var savedSrcdocs = [];
    for (var fi = 0; fi < iframes.length; fi++) {
      if (iframes[fi].hasAttribute("srcdoc")) {
        savedSrcdocs.push({ el: iframes[fi], val: iframes[fi].getAttribute("srcdoc") });
        iframes[fi].removeAttribute("srcdoc");
      }
    }

    // Serialize the full page
    var html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;

    // Restore srcdoc so live iframes keep working
    for (var sdi = 0; sdi < savedSrcdocs.length; sdi++) {
      savedSrcdocs[sdi].el.setAttribute("srcdoc", savedSrcdocs[sdi].val);
    }

    var blob = new Blob([html], { type: "text/html;charset=utf-8" });

    // Derive filename
    var baseName = "";
    var metaEl = document.querySelector('meta[name="turas-original-filename"]');
    if (metaEl && metaEl.getAttribute("content")) {
      baseName = metaEl.getAttribute("content").replace(/\.html$/i, "");
    } else {
      baseName = document.title.replace(/[^a-zA-Z0-9_\- ]/g, "");
    }
    var suggestedName = baseName + "_updated.html";

    // Use File System Access API if available (Chromium browsers)
    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: suggestedName,
        types: [{
          description: "HTML Document",
          accept: { "text/html": [".html"] }
        }]
      }).then(function(handle) {
        return handle.createWritable().then(function(writable) {
          return writable.write(blob).then(function() {
            return writable.close();
          });
        });
      }).then(function() {
        showSaveToast("Report saved successfully");
      }).catch(function(err) {
        if (err.name !== "AbortError") {
          console.error("Save failed:", err);
          showSaveToast("Save failed — check console", true);
        }
      });
    } else {
      // Fallback download (Safari, Firefox)
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = suggestedName;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showSaveToast("Report downloaded as " + suggestedName);
    }
  };

  /**
   * Sync form element values to DOM attributes so outerHTML captures them.
   * outerHTML reads the HTML `value` attribute, not the DOM `.value` property.
   * Without this sync, user-typed content in textareas and inputs is lost.
   * Also syncs contenteditable elements' innerHTML.
   * @param {Document} doc - The document to sync
   */
  function syncFormStateToDom(doc) {
    // Textareas: set textContent to match current .value
    var textareas = doc.querySelectorAll("textarea");
    for (var i = 0; i < textareas.length; i++) {
      textareas[i].textContent = textareas[i].value;
    }
    // Inputs: set attribute to match current .value
    var inputs = doc.querySelectorAll('input[type="text"], input:not([type])');
    for (var j = 0; j < inputs.length; j++) {
      inputs[j].setAttribute("value", inputs[j].value);
    }
    // Slide title inputs (specific class)
    var slideTitles = doc.querySelectorAll(".hub-slide-title");
    for (var k = 0; k < slideTitles.length; k++) {
      slideTitles[k].setAttribute("value", slideTitles[k].value);
    }
  }

  /**
   * Show a brief toast notification for save feedback.
   * Works on all browsers — no dependencies.
   * @param {string} message - Toast text
   * @param {boolean} isError - Red styling if true
   */
  function showSaveToast(message, isError) {
    var existing = document.getElementById("hub-save-toast");
    if (existing) existing.parentNode.removeChild(existing);

    var toast = document.createElement("div");
    toast.id = "hub-save-toast";
    toast.textContent = message;
    toast.style.cssText = "position:fixed;bottom:24px;right:24px;z-index:99999;" +
      "background:" + (isError ? "#dc2626" : "#16a34a") + ";color:#fff;" +
      "padding:12px 24px;border-radius:8px;font-size:14px;font-weight:500;" +
      "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;" +
      "box-shadow:0 4px 16px rgba(0,0,0,0.2);opacity:0;transition:opacity 0.3s ease;";
    document.body.appendChild(toast);

    // Trigger reflow then fade in
    toast.offsetHeight;
    toast.style.opacity = "1";

    setTimeout(function() {
      toast.style.opacity = "0";
      setTimeout(function() {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
      }, 300);
    }, 3000);
  }

  /**
   * Hub-level Print
   */
  ReportHub.printReport = function() {
    window.print();
  };

})();
