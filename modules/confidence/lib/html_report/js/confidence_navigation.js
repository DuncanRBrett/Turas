// ==============================================================================
// CONFIDENCE HTML REPORT - NAVIGATION & INTERACTIVITY
// ==============================================================================
// Tab switching, question navigation, and save functionality.
// No external dependencies.
// ==============================================================================

function switchReportTab(tabName) {
  document.querySelectorAll(".report-tab").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
  });
  document.querySelectorAll(".tab-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("tab-" + tabName);
  if (target) target.classList.add("active");
}

function switchQuestionDetail(questionId) {
  document.querySelectorAll(".ci-nav-btn").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-question") === questionId);
  });
  document.querySelectorAll(".ci-detail-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("ci-detail-" + questionId);
  if (target) target.classList.add("active");
}

function saveReportHTML() {
  var meta = document.querySelector('meta[name="turas-source-filename"]');
  var baseName = meta ? meta.getAttribute("content") : "Confidence_Report";
  var filename = baseName + "_Updated.html";

  // Persist textarea values into the DOM before serializing
  document.querySelectorAll("textarea").forEach(function(ta) {
    ta.setAttribute("data-saved-value", ta.value);
    ta.textContent = ta.value;
  });

  // Update save timestamp
  var badge = document.getElementById("ci-save-badge");
  if (badge) {
    var now = new Date();
    var ts = now.toLocaleDateString("en-GB", {day:"numeric", month:"short", year:"numeric"}) +
             " " + now.toLocaleTimeString("en-GB", {hour:"2-digit", minute:"2-digit"});
    badge.textContent = "Last saved: " + ts;
    badge.style.display = "inline-block";
  }

  var html = document.documentElement.outerHTML;
  var blob = new Blob(["<!DOCTYPE html>\n" + html], { type: "text/html" });
  var url = URL.createObjectURL(blob);

  var a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function toggleHelpOverlay() {
  var overlay = document.getElementById("ci-help-overlay");
  if (overlay) overlay.classList.toggle("active");
}

document.addEventListener("DOMContentLoaded", function() {
  switchReportTab("summary");

  // Restore saved textarea values
  document.querySelectorAll("textarea[data-saved-value]").forEach(function(ta) {
    ta.value = ta.getAttribute("data-saved-value");
  });

  // Callout collapsibility with localStorage persistence
  var storageKey = "turas-ci-callout-states";
  var saved = {};
  try { saved = JSON.parse(localStorage.getItem(storageKey) || "{}"); } catch(e) {}

  document.querySelectorAll(".t-callout").forEach(function(callout, idx) {
    var key = callout.id || ("callout-" + idx);
    if (saved[key] === "collapsed") {
      callout.classList.add("collapsed");
    } else if (saved[key] === "expanded") {
      callout.classList.remove("collapsed");
    }
    var header = callout.querySelector(".t-callout-header");
    if (header) {
      // Remove inline onclick to avoid double-toggle
      header.removeAttribute("onclick");
      header.addEventListener("click", function() {
        callout.classList.toggle("collapsed");
        try {
          var states = JSON.parse(localStorage.getItem(storageKey) || "{}");
          states[key] = callout.classList.contains("collapsed") ? "collapsed" : "expanded";
          localStorage.setItem(storageKey, JSON.stringify(states));
        } catch(e) {}
      });
    }
  });

  // Escape key closes help overlay
  document.addEventListener("keydown", function(e) {
    if (e.key === "Escape") {
      var overlay = document.getElementById("ci-help-overlay");
      if (overlay && overlay.classList.contains("active")) {
        overlay.classList.remove("active");
      }
    }
  });
});
