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

document.addEventListener("DOMContentLoaded", function() {
  switchReportTab("summary");

  // Restore saved textarea values
  document.querySelectorAll("textarea[data-saved-value]").forEach(function(ta) {
    ta.value = ta.getAttribute("data-saved-value");
  });
});
