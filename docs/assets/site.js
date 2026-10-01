/* PepBox site — mobile nav, extension filter, notch demo. No dependencies. */
(function () {
  "use strict";

  // ---- Mobile navigation ----
  var toggle = document.querySelector(".nav-toggle");
  var nav = document.getElementById("site-nav");
  if (toggle && nav) {
    var setOpen = function (open) {
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      nav.classList.toggle("is-open", open);
    };
    toggle.addEventListener("click", function () {
      setOpen(toggle.getAttribute("aria-expanded") !== "true");
    });
    nav.addEventListener("click", function (e) {
      if (e.target.closest("a")) setOpen(false);
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && toggle.getAttribute("aria-expanded") === "true") {
        setOpen(false);
        toggle.focus();
      }
    });
    document.addEventListener("click", function (e) {
      if (toggle.getAttribute("aria-expanded") === "true" && !nav.contains(e.target) && !toggle.contains(e.target)) {
        setOpen(false);
      }
    });
    window.matchMedia("(min-width: 761px)").addEventListener("change", function (m) {
      if (m.matches) setOpen(false);
    });
  }

  // ---- Extensions: live search + category chips ----
  var grid = document.getElementById("ext-grid");
  if (grid) {
    var items = Array.prototype.slice.call(grid.querySelectorAll(".ext"));
    var input = document.getElementById("ext-search");
    var chips = Array.prototype.slice.call(document.querySelectorAll("[data-filter]"));
    var empty = document.getElementById("ext-empty");
    var count = document.getElementById("ext-count");
    var category = "all";

    var apply = function () {
      var q = (input.value || "").trim().toLowerCase();
      var shown = 0;
      items.forEach(function (el) {
        var okCat = category === "all" || el.getAttribute("data-category") === category;
        var okText = !q || el.textContent.toLowerCase().indexOf(q) !== -1;
        var show = okCat && okText;
        el.hidden = !show;
        if (show) shown++;
      });
      empty.hidden = shown !== 0;
      count.textContent = shown === 1 ? "1 extension" : shown + " extensions";
    };

    chips.forEach(function (chip) {
      chip.addEventListener("click", function () {
        category = chip.getAttribute("data-filter");
        chips.forEach(function (c) { c.setAttribute("aria-pressed", c === chip ? "true" : "false"); });
        apply();
      });
    });
    input.addEventListener("input", apply);
    var reset = document.getElementById("ext-reset");
    if (reset) {
      reset.addEventListener("click", function () {
        input.value = "";
        category = "all";
        chips.forEach(function (c) { c.setAttribute("aria-pressed", c.getAttribute("data-filter") === "all" ? "true" : "false"); });
        apply();
        input.focus();
      });
    }
    apply();
  }

  // ---- Home: cycle the live activity beside the notch ----
  var left = document.getElementById("act-left");
  var right = document.getElementById("act-right");
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (left && right && !reduce) {
    var acts = [
      ["c-orange", "Timer", "4:59"],
      ["c-yellow", "Agent", "Needs you"],
      ["c-green", "Eye break", "Look away 18s"],
      ["c-purple", "Queue", "3 queued"],
      ["c-blue", "Download", "64%"]
    ];
    var i = 0;
    setInterval(function () {
      left.classList.add("is-fading");
      right.classList.add("is-fading");
      setTimeout(function () {
        i = (i + 1) % acts.length;
        var a = acts[i];
        left.className = "mock-act " + a[0];
        right.className = "mock-act " + a[0];
        left.lastChild.textContent = a[1];
        right.textContent = a[2];
      }, 350);
    }, 2600);
  }
})();
