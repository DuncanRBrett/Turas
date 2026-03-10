/**
 * Conjoint HTML Report Navigation
 * Handles tab switching and attribute detail navigation
 */

function switchCjTab(tabName) {
  document.querySelectorAll(".cj-tab").forEach(function(t) {
    t.classList.remove("active");
  });
  document.querySelectorAll(".cj-panel").forEach(function(p) {
    p.classList.remove("active");
  });

  var btn = document.querySelector(".cj-tab[data-tab=\"" + tabName + "\"]");
  if (btn) btn.classList.add("active");

  var panel = document.getElementById("panel-" + tabName);
  if (panel) panel.classList.add("active");
}

function switchCjAttr(attrName) {
  document.querySelectorAll(".cj-attr-btn").forEach(function(b) {
    b.classList.remove("active");
  });
  document.querySelectorAll(".cj-attr-detail").forEach(function(d) {
    d.classList.remove("active");
  });

  if (event && event.target) {
    event.target.classList.add("active");
  }

  var detail = document.getElementById("attr-" + attrName);
  if (detail) detail.classList.add("active");
}

document.addEventListener("DOMContentLoaded", function() {
  switchCjTab("overview");
});
