/**
 * Turas Hub App — Cross-Project Search
 *
 * Full-text search across all projects' pins, insights, report metadata,
 * and annotations. Results link to the relevant project and report.
 *
 * Public API:
 *   Search.show()           — Open search overlay
 *   Search.hide()           — Close search overlay
 *   Search.handleResults(data) — Process results from R
 */

var Search = (function() {
  "use strict";

  var DEBOUNCE_MS = 300;
  var searchTimer = null;

  /**
   * Show the search overlay.
   */
  function show() {
    var overlay = document.getElementById("search-overlay");
    if (!overlay) return;

    overlay.style.display = "flex";
    var input = document.getElementById("search-input");
    if (input) {
      input.value = "";
      input.focus();
    }

    // Clear previous results
    var results = document.getElementById("search-results");
    if (results) results.innerHTML = "";
    var hint = document.getElementById("search-hint");
    if (hint) hint.style.display = "";
  }

  /**
   * Hide the search overlay.
   */
  function hide() {
    var overlay = document.getElementById("search-overlay");
    if (overlay) overlay.style.display = "none";
  }

  /**
   * Initialise — bind events.
   */
  function init() {
    var input = document.getElementById("search-input");
    if (input) {
      input.addEventListener("input", function() {
        var query = this.value.trim();
        clearTimeout(searchTimer);
        if (query.length < 2) {
          var results = document.getElementById("search-results");
          if (results) results.innerHTML = "";
          var hint = document.getElementById("search-hint");
          if (hint) hint.style.display = "";
          return;
        }
        searchTimer = setTimeout(function() {
          performSearch(query);
        }, DEBOUNCE_MS);
      });

      input.addEventListener("keydown", function(e) {
        if (e.key === "Escape") hide();
      });
    }
  }

  /**
   * Send search query to R.
   */
  function performSearch(query) {
    var hint = document.getElementById("search-hint");
    if (hint) hint.style.display = "none";

    var results = document.getElementById("search-results");
    if (results) {
      results.innerHTML = '<div class="search-loading"><div class="spinner"></div> Searching...</div>';
    }

    HubApp.sendToShiny("hub_search", query);
  }

  /**
   * Handle search results from R.
   * @param {object} data - { results: [...], query: "..." }
   */
  function handleResults(data) {
    var container = document.getElementById("search-results");
    if (!container) return;

    if (!data || !data.results || data.results.length === 0) {
      container.innerHTML =
        '<div class="search-empty">No results found for "' +
        escapeHtml(data ? data.query || "" : "") + '"</div>';
      return;
    }

    var html = '<div class="search-count">' +
      data.results.length + ' result' +
      (data.results.length !== 1 ? 's' : '') +
      ' for "' + escapeHtml(data.query || "") + '"</div>';

    for (var i = 0; i < data.results.length; i++) {
      var item = data.results[i];
      html += buildResultCard(item);
    }

    container.innerHTML = html;

    // Bind click handlers
    var cards = container.querySelectorAll(".search-result-card");
    for (var c = 0; c < cards.length; c++) {
      cards[c].addEventListener("click", handleResultClick);
    }
  }

  /**
   * Build HTML for a single search result.
   */
  function buildResultCard(item) {
    var typeIcon = getTypeIcon(item.type);
    var typeBadge = item.type || "item";

    return '<div class="search-result-card" ' +
      'data-project-path="' + escapeAttr(item.project_path || "") + '" ' +
      'data-type="' + escapeAttr(item.type || "") + '">' +
      '<div class="search-result-header">' +
        '<span class="search-result-type">' + typeIcon + ' ' + escapeHtml(typeBadge) + '</span>' +
        '<span class="search-result-project">' + escapeHtml(item.project_name || "") + '</span>' +
      '</div>' +
      '<div class="search-result-title">' + escapeHtml(item.title || "") + '</div>' +
      (item.snippet ? '<div class="search-result-snippet">' + escapeHtml(item.snippet) + '</div>' : '') +
      (item.source ? '<div class="search-result-source">Source: ' + escapeHtml(item.source) + '</div>' : '') +
    '</div>';
  }

  /**
   * Get icon for result type.
   */
  function getTypeIcon(type) {
    var icons = {
      report: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
      pin: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="17" x2="12" y2="22"/><path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z"/></svg>',
      annotation: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>',
      section: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/></svg>'
    };
    return icons[type] || icons.report;
  }

  /**
   * Handle click on a search result — open the project.
   */
  function handleResultClick() {
    var path = this.getAttribute("data-project-path");
    if (!path) return;

    hide();
    HubApp.sendToShiny("hub_open_project", path);
    HubApp.showToast("Opening project...");
  }

  function escapeHtml(str) {
    if (!str) return "";
    return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function escapeAttr(str) {
    return escapeHtml(str).replace(/'/g, "&#39;");
  }

  return {
    init: init,
    show: show,
    hide: hide,
    handleResults: handleResults
  };
})();
