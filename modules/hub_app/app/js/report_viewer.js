/**
 * Turas Hub App — Report Viewer
 *
 * Manages report loading via iframes. Each report is served from the
 * Shiny backend via addResourcePath (same origin, no CORS issues).
 *
 * Features:
 * - Tab bar for switching between reports
 * - Lazy-load iframes on first tab activation
 * - LRU eviction: max MAX_ACTIVE_IFRAMES loaded at once
 * - Bridge injection: hides report headers, makes navs sticky,
 *   sets up pin forwarding (MutationObserver on pinned-views-data)
 */

var ReportViewer = (function() {
  "use strict";

  // ---- Configuration ----
  var MAX_ACTIVE_IFRAMES     = 5;    // Max iframes loaded simultaneously
  var IFRAME_LOAD_TIMEOUT_MS = 15000; // Timeout before showing retry
  var BRIDGE_POLL_MS         = 100;   // Interval for pin store discovery
  var BRIDGE_MAX_ATTEMPTS    = 50;    // Max polls (50 x 100ms = 5s)

  // ---- State ----
  var reports = [];           // Array of report objects with URLs
  var activeKey = null;       // Currently visible report key (filename-based)
  var iframeState = {};       // key -> { loaded: bool, lastAccess: timestamp, iframe: element }
  var loadTimeouts = {};      // key -> timeout ID

  /**
   * Render the report viewer for a project.
   * Creates tab bar and prepares iframe containers.
   * @param {object} data - { project_name, project_path, reports, report_count }
   */
  function render(data) {
    reports = data.reports || [];
    activeKey = null;
    iframeState = {};
    loadTimeouts = {};

    var tabs = HubApp.dom.reportTabs;
    var container = HubApp.dom.reportContainer;
    var title = HubApp.dom.projectTitle;
    var count = HubApp.dom.reportCount;
    var loading = HubApp.dom.reportLoading;

    // Set project title
    if (title) title.textContent = data.project_name || "";
    if (count) count.textContent = data.report_count + " report" +
      (data.report_count !== 1 ? "s" : "");

    // Clear previous content
    tabs.innerHTML = "";
    // Remove old iframes (keep loading indicator)
    var oldFrames = container.querySelectorAll(".report-iframe");
    for (var i = 0; i < oldFrames.length; i++) {
      container.removeChild(oldFrames[i]);
    }
    if (loading) loading.style.display = "none";

    if (reports.length === 0) {
      tabs.innerHTML = '<div style="padding:12px;color:#94a3b8;">No reports found</div>';
      return;
    }

    // Build tabs and iframe placeholders
    for (var r = 0; r < reports.length; r++) {
      var report = reports[r];
      var key = reportKey(report);

      // Create tab button
      var tab = document.createElement("button");
      tab.className = "report-tab";
      tab.textContent = report.label || report.filename;
      tab.setAttribute("data-key", key);
      tab.addEventListener("click", handleTabClick);
      tabs.appendChild(tab);

      // Create iframe (not loaded yet)
      var iframe = document.createElement("iframe");
      iframe.className = "report-iframe";
      iframe.id = "report-iframe-" + key;
      iframe.setAttribute("data-key", key);
      iframe.setAttribute("data-url", report.url);
      // No sandbox — reports are trusted Turas content served same-origin.
      // Sandbox would block downloads, clipboard, modals, and other
      // functionality the reports rely on.
      container.appendChild(iframe);

      // Track state
      iframeState[key] = {
        loaded: false,
        lastAccess: 0,
        iframe: iframe,
        report: report
      };
    }

    // Activate the first report
    activateReport(reportKey(reports[0]));
  }

  /**
   * Handle tab click — switch to the selected report.
   */
  function handleTabClick() {
    var key = this.getAttribute("data-key");
    if (key && key !== activeKey) {
      activateReport(key);
    }
  }

  /**
   * Activate a report by key: show its iframe, lazy-load if needed,
   * and enforce LRU eviction.
   * @param {string} key - Report key
   */
  function activateReport(key) {
    if (!iframeState[key]) return;

    activeKey = key;

    // Update tab active state
    var tabs = HubApp.dom.reportTabs.querySelectorAll(".report-tab");
    for (var t = 0; t < tabs.length; t++) {
      tabs[t].classList.toggle("active", tabs[t].getAttribute("data-key") === key);
    }

    // Hide all iframes, show the active one
    var iframes = HubApp.dom.reportContainer.querySelectorAll(".report-iframe");
    for (var i = 0; i < iframes.length; i++) {
      iframes[i].classList.toggle("active", iframes[i].getAttribute("data-key") === key);
    }

    // Update access time
    iframeState[key].lastAccess = Date.now();

    // Lazy-load if not yet loaded
    if (!iframeState[key].loaded) {
      loadReport(key);
    }

    // Enforce LRU eviction
    evictLRU();
  }

  /**
   * Load a report into its iframe.
   * @param {string} key - Report key
   */
  function loadReport(key) {
    var entry = iframeState[key];
    if (!entry) return;

    var iframe = entry.iframe;
    var url = iframe.getAttribute("data-url");

    if (!url) {
      console.error("[Hub App] No URL for report:", key);
      return;
    }

    // Show loading indicator
    var loading = HubApp.dom.reportLoading;
    if (loading) loading.style.display = "";

    // Set the iframe src to trigger loading
    iframe.src = url;

    // Listen for load event
    iframe.addEventListener("load", function onLoad() {
      iframe.removeEventListener("load", onLoad);
      entry.loaded = true;

      // Hide loading indicator if this is still the active report
      if (activeKey === key && loading) {
        loading.style.display = "none";
      }

      // Clear timeout
      if (loadTimeouts[key]) {
        clearTimeout(loadTimeouts[key]);
        delete loadTimeouts[key];
      }

      // Inject bridge (header hiding, sticky navs, pin forwarding)
      injectBridge(iframe, key);
    });

    // Set load timeout
    loadTimeouts[key] = setTimeout(function() {
      if (!entry.loaded) {
        console.warn("[Hub App] Report load timeout:", key);
        if (loading) loading.style.display = "none";
      }
    }, IFRAME_LOAD_TIMEOUT_MS);
  }

  /**
   * Evict least-recently-used iframes when over the limit.
   * Unloads iframe content but keeps the element in the DOM.
   */
  function evictLRU() {
    var loadedKeys = [];
    for (var k in iframeState) {
      if (iframeState[k].loaded) {
        loadedKeys.push(k);
      }
    }

    if (loadedKeys.length <= MAX_ACTIVE_IFRAMES) return;

    // Sort by last access (oldest first), excluding the active report
    loadedKeys.sort(function(a, b) {
      return iframeState[a].lastAccess - iframeState[b].lastAccess;
    });

    var toEvict = loadedKeys.length - MAX_ACTIVE_IFRAMES;
    var evicted = 0;

    for (var i = 0; i < loadedKeys.length && evicted < toEvict; i++) {
      var key = loadedKeys[i];
      if (key === activeKey) continue; // Never evict active report

      // Unload by clearing src
      iframeState[key].iframe.src = "about:blank";
      iframeState[key].loaded = false;
      evicted++;
    }
  }

  /**
   * Inject bridge functionality into a loaded report iframe.
   * Hides report headers, makes nav strips sticky, and sets up
   * pin forwarding via MutationObserver.
   *
   * Adapted from hub_navigation.js for the Hub App context.
   *
   * @param {HTMLIFrameElement} iframe
   * @param {string} key - Report key
   */
  function injectBridge(iframe, key) {
    try {
      var doc = iframe.contentDocument;
      var win = iframe.contentWindow;
      if (!doc || !doc.head) return;

      // 1. Inject CSS to hide headers and make navs sticky
      var style = doc.createElement("style");
      style.textContent =
        // Hide all known report header classes
        ".header, .tk-header, .ci-header, .wt-header, .md-header, " +
        ".cj-header, .seg-header, .pr-header, .cd-header, .kd-header " +
        "{ display:none !important; } " +
        // Make all report nav strips sticky
        ".report-tabs, .banner-tabs, " +
        ".cj-report-tabs, .cj-slide-tabs, " +
        ".md-tab-nav, .md-subtab-nav, " +
        ".pr-tab-nav, " +
        ".kd-report-tabs, .cd-factor-tabs, .seg-report-tabs " +
        "{ position:sticky !important; top:0 !important; z-index:50 !important; " +
        "background:#fff !important; }";
      doc.head.appendChild(style);

      // 2. Set up cross-frame pin forwarding
      win._hubAppReportKey = key;

      // Find the report label for this key
      var reportLabel = key;
      var entry = iframeState[key];
      if (entry && entry.report && entry.report.label) {
        reportLabel = entry.report.label;
      }

      // Pin callback — reports can call parent.pinToHub(data) directly
      win.pinToHub = function(data) {
        data.source = key;
        data.sourceLabel = reportLabel;
        PinBoard.addPin(key, data);
      };

      // 3. Set up MutationObserver on pin stores
      interceptPins(doc, win, key, reportLabel);

    } catch (e) {
      console.warn("[Hub App] Bridge injection failed for", key, ":", e.message);
    }
  }

  /**
   * Set up MutationObserver on the report's pinned-views-data store.
   * Auto-discovers the store element by trying known IDs and falling
   * back to any element with ID matching *-pinned-views-data.
   *
   * @param {Document} doc - iframe document
   * @param {Window} win - iframe window
   * @param {string} key - Report key
   * @param {string} label - Report label for display
   */
  function interceptPins(doc, win, key, label) {
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
      for (var i = 0; i < knownIds.length; i++) {
        var el = doc.getElementById(knownIds[i]);
        if (el) return el;
      }
      return doc.querySelector('[id$="-pinned-views-data"]');
    }

    var attempts = 0;
    var interval = setInterval(function() {
      attempts++;
      var store = findStore();

      if (store) {
        clearInterval(interval);
        observeStore(store, win, key, label);
      } else if (attempts >= BRIDGE_MAX_ATTEMPTS) {
        clearInterval(interval);
        // Final fallback: watch for late-created stores
        observeForLateStore(doc, win, key, label);
      }
    }, BRIDGE_POLL_MS);
  }

  /**
   * Observe a pin store element for changes.
   * When the report's savePinnedData() updates the store,
   * we detect the new pin and forward it to the hub.
   *
   * @param {Element} store - The pinned-views-data element
   * @param {Window} win - iframe window
   * @param {string} key - Report key
   * @param {string} label - Report label
   */
  function observeStore(store, win, key, label) {
    var lastContent = store.textContent || "";

    var observer = new MutationObserver(function() {
      var newContent = store.textContent || "";
      if (newContent === lastContent) return;

      // Detect the newly added pin
      try {
        var oldPins = lastContent ? JSON.parse(lastContent) : [];
        var newPins = newContent ? JSON.parse(newContent) : [];

        if (newPins.length > oldPins.length) {
          var latestPin = newPins[newPins.length - 1];
          latestPin.source = key;
          latestPin.sourceLabel = label;
          PinBoard.addPin(key, latestPin);
        }
      } catch (e) {
        console.warn("[Hub App] Could not parse pin store for", key);
      }

      lastContent = newContent;
    });

    observer.observe(store, { childList: true, characterData: true, subtree: true });
  }

  /**
   * Fallback: watch iframe body for dynamically created pin stores.
   */
  function observeForLateStore(doc, win, key, label) {
    if (!doc.body) return;

    var observer = new MutationObserver(function(mutations) {
      for (var m = 0; m < mutations.length; m++) {
        for (var n = 0; n < mutations[m].addedNodes.length; n++) {
          var node = mutations[m].addedNodes[n];
          if (node.id && node.id.indexOf("pinned-views-data") !== -1) {
            observer.disconnect();
            observeStore(node, win, key, label);
            return;
          }
        }
      }
    });

    observer.observe(doc.body, { childList: true, subtree: true });

    // Auto-disconnect after 30 seconds to prevent memory leaks
    setTimeout(function() {
      observer.disconnect();
    }, 30000);
  }

  /**
   * Generate a stable key for a report (based on filename without extension).
   * @param {object} report - Report object
   * @returns {string}
   */
  function reportKey(report) {
    var name = report.filename || report.path || "";
    // Remove extension and sanitise for use as DOM id
    return name.replace(/\.html$/i, "").replace(/[^a-zA-Z0-9_-]/g, "_");
  }

  /**
   * Clean up all iframes when leaving the report view.
   */
  function cleanup() {
    for (var key in iframeState) {
      if (iframeState[key].iframe) {
        iframeState[key].iframe.src = "about:blank";
      }
    }
    for (var t in loadTimeouts) {
      clearTimeout(loadTimeouts[t]);
    }
    iframeState = {};
    loadTimeouts = {};
    activeKey = null;
    reports = [];
  }

  // --- Public API ---
  return {
    render: render,
    cleanup: cleanup,
    activateReport: activateReport
  };
})();
