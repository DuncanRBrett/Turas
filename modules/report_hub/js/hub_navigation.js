/**
 * Report Hub Navigation Controller
 *
 * Manages two-tier navigation:
 *   Level 1: Report switching (Overview, Tracker, Crosstabs, Pinned)
 *   Level 2: Sub-tab switching within each report
 *
 * Also handles URL hash deep linking and keyboard shortcuts.
 */

var ReportHub = ReportHub || {};

(function() {
  "use strict";

  var activeReport = "overview";
  var reportKeys = []; // Populated on init from DOM

  /**
   * Switch the active Level 1 report panel
   * @param {string} key - Report key ("overview", "tracker", "tabs", "pinned")
   */
  ReportHub.switchReport = function(key) {
    activeReport = key;

    // Update Level 1 tab active states
    var tabs = document.querySelectorAll(".hub-tab");
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle("active", tabs[i].getAttribute("data-hub-tab") === key);
    }

    // Show/hide report panels
    var panels = document.querySelectorAll(".hub-panel");
    for (var j = 0; j < panels.length; j++) {
      var panelKey = panels[j].getAttribute("data-hub-panel");
      panels[j].classList.toggle("active", panelKey === key);
    }

    // Show/hide Level 2 nav bars
    var l2Bars = document.querySelectorAll(".hub-nav-level2");
    for (var k = 0; k < l2Bars.length; k++) {
      var barKey = l2Bars[k].id.replace("hub-l2-", "");
      l2Bars[k].style.display = (barKey === key) ? "" : "none";
    }

    // Update URL hash
    if (history.replaceState) {
      history.replaceState(null, "", "#" + key);
    }

    // Trigger resize for sticky columns / layout recalculation
    window.dispatchEvent(new Event("resize"));
  };

  /**
   * Switch a sub-tab within a specific report
   * @param {string} reportKey - Report key
   * @param {string} tabName - Sub-tab name (e.g., "summary", "metrics", "crosstabs")
   */
  ReportHub.switchSubTab = function(reportKey, tabName) {
    var prefix = reportKey + "--";

    // Update Level 2 tab active states
    var l2Bar = document.getElementById("hub-l2-" + reportKey);
    if (l2Bar) {
      var subtabs = l2Bar.querySelectorAll(".hub-subtab");
      for (var i = 0; i < subtabs.length; i++) {
        subtabs[i].classList.toggle("active", subtabs[i].getAttribute("data-subtab") === tabName);
      }
    }

    // Show/hide sub-panels within this report
    var panel = document.querySelector('.hub-panel[data-hub-panel="' + reportKey + '"]');
    if (panel) {
      var subPanels = panel.querySelectorAll(".tab-panel");
      for (var j = 0; j < subPanels.length; j++) {
        subPanels[j].classList.remove("active");
      }
      var target = document.getElementById(prefix + "tab-" + tabName);
      if (target) {
        target.classList.add("active");
      }
    }

    // Trigger resize for layout recalculation
    window.dispatchEvent(new Event("resize"));
  };

  /**
   * Get the currently active report key
   * @return {string}
   */
  ReportHub.getActiveReport = function() {
    return activeReport;
  };

  /**
   * Initialize the hub navigation
   */
  ReportHub.initNavigation = function() {
    // Collect report keys from DOM
    var panels = document.querySelectorAll(".hub-panel");
    reportKeys = [];
    for (var i = 0; i < panels.length; i++) {
      reportKeys.push(panels[i].getAttribute("data-hub-panel"));
    }

    // Check URL hash for deep link
    var hash = window.location.hash.replace("#", "");
    if (hash && reportKeys.indexOf(hash) !== -1) {
      ReportHub.switchReport(hash);
    } else {
      // Default to overview
      ReportHub.switchReport("overview");
    }

    // Keyboard navigation
    document.addEventListener("keydown", function(e) {
      // Only when focus is on a hub tab or no specific element is focused
      var focused = document.activeElement;
      var isTabFocused = focused && focused.classList &&
        (focused.classList.contains("hub-tab") || focused.classList.contains("hub-subtab"));
      var isBodyFocused = focused === document.body || focused.tagName === "BODY";

      if (!isTabFocused && !isBodyFocused) return;

      if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
        var idx = reportKeys.indexOf(activeReport);
        if (idx === -1) return;

        if (e.key === "ArrowRight" && idx < reportKeys.length - 1) {
          ReportHub.switchReport(reportKeys[idx + 1]);
        } else if (e.key === "ArrowLeft" && idx > 0) {
          ReportHub.switchReport(reportKeys[idx - 1]);
        }
      }
    });
  };

  /**
   * Hub-level Save Report
   * Serializes the entire combined report state
   */
  ReportHub.saveReportHTML = function() {
    // Sync any editable content
    ReportHub.savePinnedData();

    // Stamp the date
    var dateBadge = document.getElementById("hub-date-badge");
    if (dateBadge) {
      var now = new Date();
      var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      dateBadge.textContent = "Saved " + months[now.getMonth()] + " " + now.getFullYear();
    }

    // Serialize the full page
    var html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;

    // Download as file
    var blob = new Blob([html], { type: "text/html;charset=utf-8" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = document.title.replace(/[^a-zA-Z0-9_\- ]/g, "") + "_saved.html";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  /**
   * Hub-level Print
   */
  ReportHub.printReport = function() {
    window.print();
  };

})();
