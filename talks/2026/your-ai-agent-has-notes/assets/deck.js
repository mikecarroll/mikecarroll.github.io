/* =============================================================================
   deck.js — reusable HTML-slide engine (zero dependencies)

   Controls:
     • click anywhere      → forward (reveal next fragment, else next slide)
     • Right Arrow / Space  → forward (convenience)
     • Left Arrow / Up      → back (hide last fragment, else previous slide)
     • Home / End           → first / last slide
     • N or S               → toggle speaker notes
     • ?                    → toggle keyboard help
     • Esc                  → close any overlay
     • R                    → toggle reading (transcript) mode

   URL: #slide-7 deep-links a slide;  ?print=1 prints all slides;  ?read=1
   opens the transcript view. Clicks on links/buttons never advance the deck.
   Every slide is driven by markup — no per-slide JS.
   ========================================================================== */
(function () {
  "use strict";

  var params = new URLSearchParams(location.search);
  var PRINT = params.get("print") === "1";
  var READ = params.get("read") === "1";

  var deck = document.querySelector(".deck");
  var stage = document.querySelector(".stage");
  var slides = Array.prototype.slice.call(document.querySelectorAll(".slide"));
  if (!deck || !slides.length) return;

  // --- Reading (transcript) mode: skip the deck engine entirely -------------
  if (READ) {
    document.body.classList.add("reading");
    return;
  }

  // --- Print mode: reveal everything, let CSS paginate, then stop -----------
  if (PRINT) {
    document.documentElement.classList.add("is-print");
    slides.forEach(function (s) {
      s.classList.add("is-active");
      fragmentsOf(s).forEach(function (f) {
        f.classList.add("is-visible");
      });
    });
    return;
  }

  // --- Mobile portrait overlay (interactive mode only) ----------------------
  var rotatePrompt = document.createElement("div");
  rotatePrompt.className = "rotate-prompt";
  var canFullscreen = !!document.documentElement.requestFullscreen;
  rotatePrompt.innerHTML =
    '<span class="rotate-icon">&#8635;</span>' +
    "<p>Rotate your device for the best experience</p>" +
    (canFullscreen ? '<button class="rotate-btn">Go fullscreen</button>' : "");
  document.body.appendChild(rotatePrompt);
  if (canFullscreen) {
    rotatePrompt.querySelector(".rotate-btn").addEventListener("click", function () {
      document.documentElement.requestFullscreen().then(function () {
        if (screen.orientation && screen.orientation.lock) {
          screen.orientation.lock("landscape-primary").catch(function () {});
        }
      }).catch(function () {});
    });
  }

  var current = 0; // active slide index
  var step = 0; // how many fragment *levels* revealed on the active slide

  function fragmentsOf(slide) {
    return Array.prototype.slice
      .call(slide.querySelectorAll(".fragment"))
      .sort(function (a, b) {
        return fragIndex(a) - fragIndex(b);
      });
  }

  function fragIndex(f) {
    var n = parseInt(f.getAttribute("data-fragment-index"), 10);
    return isNaN(n) ? 0 : n;
  }

  // Distinct, sorted fragment indices — fragments sharing an index reveal
  // together on a single click (reveal.js-style grouping).
  function fragLevels(slide) {
    var seen = {};
    fragmentsOf(slide).forEach(function (f) {
      seen[fragIndex(f)] = true;
    });
    return Object.keys(seen)
      .map(Number)
      .sort(function (a, b) {
        return a - b;
      });
  }

  // --- Scale the fixed 1280x720 stage to fit the viewport -------------------
  function fit() {
    var pad = 0;
    var sw = stage.offsetWidth || 1280;
    var sh = stage.offsetHeight || 720;
    var scale = Math.min(
      (window.innerWidth - pad) / sw,
      (window.innerHeight - pad) / sh
    );
    stage.style.transform = "scale(" + scale + ")";
  }

  // --- Chrome: progress dots + slide number --------------------------------
  var progress = document.querySelector(".progress");
  if (progress) {
    slides.forEach(function (_, i) {
      var dot = document.createElement("span");
      dot.className = "dot";
      dot.setAttribute("data-goto", i);
      progress.appendChild(dot);
    });
  }
  var slideNum = document.querySelector(".slide-num");

  function render() {
    slides.forEach(function (s, i) {
      s.classList.toggle("is-active", i === current);
    });
    var levels = fragLevels(slides[current]);
    var maxLevel = step > 0 ? levels[step - 1] : -Infinity;
    fragmentsOf(slides[current]).forEach(function (f) {
      f.classList.toggle("is-visible", fragIndex(f) <= maxLevel);
    });
    if (progress) {
      Array.prototype.forEach.call(progress.children, function (dot, i) {
        dot.classList.toggle("is-active", i === current);
      });
    }
    if (slideNum) {
      slideNum.textContent = current + 1 + " / " + slides.length;
    }
    renderNotes();
    var id = slides[current].id;
    if (id && location.hash !== "#" + id) {
      history.replaceState(null, "", "#" + id);
    }
  }

  function goto(index, opts) {
    index = Math.max(0, Math.min(slides.length - 1, index));
    current = index;
    // when jumping backwards onto a slide, show all its fragments
    step = opts && opts.atEnd ? fragLevels(slides[current]).length : 0;
    render();
  }

  function forward() {
    var levels = fragLevels(slides[current]);
    if (step < levels.length) {
      step++;
      render();
    } else if (current < slides.length - 1) {
      goto(current + 1);
    }
  }

  function back() {
    if (step > 0) {
      step--;
      render();
    } else if (current > 0) {
      goto(current - 1, { atEnd: true });
    }
  }

  // --- Speaker notes overlay -----------------------------------------------
  var notesOverlay = document.querySelector(".notes-overlay");
  var notesBody = notesOverlay && notesOverlay.querySelector(".notes-body");
  var notesOpen = false;

  function renderNotes() {
    if (!notesOverlay || !notesOpen) return;
    var note = slides[current].querySelector(".notes");
    notesBody.innerHTML = note ? note.innerHTML : "<em>No notes.</em>";
  }

  function toggleNotes() {
    if (!notesOverlay) return;
    notesOpen = !notesOpen;
    notesOverlay.hidden = !notesOpen;
    renderNotes();
  }

  // --- Help overlay ---------------------------------------------------------
  var helpOverlay = document.querySelector(".help-overlay");
  function toggleHelp() {
    if (!helpOverlay) return;
    helpOverlay.hidden = !helpOverlay.hidden;
  }

  // --- Input ----------------------------------------------------------------
  // Advance on click, but never when the user is interacting with a link,
  // button, or anything explicitly marked [data-no-advance].
  deck.addEventListener("click", function (e) {
    if (e.target.closest("a, button, [data-no-advance]")) return;
    forward();
  });

  // progress-dot jump
  if (progress) {
    progress.style.pointerEvents = "auto";
    progress.addEventListener("click", function (e) {
      var dot = e.target.closest("[data-goto]");
      if (dot) {
        e.stopPropagation();
        goto(+dot.getAttribute("data-goto"));
      }
    });
  }

  document.addEventListener("keydown", function (e) {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    switch (e.key) {
      case "ArrowRight":
      case "PageDown":
      case " ":
      case "Spacebar":
        e.preventDefault();
        forward();
        break;
      case "ArrowLeft":
      case "ArrowUp":
      case "PageUp":
        e.preventDefault();
        back();
        break;
      case "Home":
        e.preventDefault();
        goto(0);
        break;
      case "End":
        e.preventDefault();
        goto(slides.length - 1, { atEnd: true });
        break;
      case "n":
      case "N":
      case "s":
      case "S":
        toggleNotes();
        break;
      case "r":
      case "R":
        params.set("read", "1");
        location.search = params.toString();
        break;
      case "?":
        toggleHelp();
        break;
      case "Escape":
        if (helpOverlay && !helpOverlay.hidden) helpOverlay.hidden = true;
        else if (notesOpen) toggleNotes();
        break;
    }
  });

  // close help when clicking its backdrop
  if (helpOverlay) {
    helpOverlay.addEventListener("click", function (e) {
      if (!e.target.closest(".help-card")) helpOverlay.hidden = true;
    });
  }

  window.addEventListener("resize", fit);
  window.addEventListener("hashchange", function () {
    var idx = slides.findIndex(function (s) {
      return "#" + s.id === location.hash;
    });
    if (idx >= 0 && idx !== current) goto(idx);
  });

  // --- Boot -----------------------------------------------------------------
  fit();
  var startIdx = slides.findIndex(function (s) {
    return "#" + s.id === location.hash;
  });
  goto(startIdx >= 0 ? startIdx : 0);
})();
