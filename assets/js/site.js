// mather.host — progressive enhancement only; every page works without this script.
// Fills in live GitHub stats (stars, last update) and the "recently updated" list.
(function () {
  "use strict";

  var USER = "UKTailwind";
  var CACHE_KEY = "mh-repos-v1";
  var CACHE_MS = 60 * 60 * 1000;

  var needsStats = document.querySelectorAll("[data-repo]");
  var activity = document.getElementById("recent-activity");
  if (!needsStats.length && !activity) return;

  function readCache() {
    try {
      var raw = sessionStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      var c = JSON.parse(raw);
      return Date.now() - c.t < CACHE_MS ? c.d : null;
    } catch (e) { return null; }
  }

  function writeCache(d) {
    try { sessionStorage.setItem(CACHE_KEY, JSON.stringify({ t: Date.now(), d: d })); } catch (e) { /* ignore */ }
  }

  function load() {
    var cached = readCache();
    if (cached) return Promise.resolve(cached);
    return fetch("https://api.github.com/users/" + USER + "/repos?per_page=100&sort=pushed", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (list) {
        var slim = list.filter(function (r) { return !r.private; }).map(function (r) {
          return {
            name: r.name, desc: r.description, stars: r.stargazers_count,
            fork: r.fork, pushed: r.pushed_at, url: r.html_url, lang: r.language
          };
        });
        writeCache(slim);
        return slim;
      });
  }

  function ago(iso) {
    var s = (Date.now() - new Date(iso).getTime()) / 1000;
    var units = [["year", 31536000], ["month", 2592000], ["week", 604800], ["day", 86400], ["hour", 3600]];
    for (var i = 0; i < units.length; i++) {
      var n = Math.floor(s / units[i][1]);
      if (n >= 1) return n + " " + units[i][0] + (n > 1 ? "s" : "") + " ago";
    }
    return "today";
  }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  load().then(function (repos) {
    var byName = {};
    repos.forEach(function (r) { byName[r.name.toLowerCase()] = r; });

    needsStats.forEach(function (node) {
      var r = byName[node.getAttribute("data-repo").toLowerCase()];
      if (!r) return;
      node.textContent = "";
      if (r.stars > 0) node.appendChild(el("span", "star", String(r.stars)));
      node.appendChild(el("span", null, "updated " + ago(r.pushed)));
    });

    if (activity) {
      var skip = { "mather.host": 1 };
      // Forks carry the upstream description; say what was changed instead.
      var forkDesc = {
        "fuzix": "FuzixOS ported to the Pico Computer 3",
        "micropython": "MicroPython port for the Pico Computer 3",
        "zeptoforth": "Cortex-M7 double-precision and cache fixes, merged upstream",
        "tiny386": "386 emulator accuracy fixes, sent upstream",
        "usqlite": "μSQLite robustness fixes, sent upstream"
      };
      var recent = repos.filter(function (r) { return !skip[r.name]; }).slice(0, 6);
      if (!recent.length) return;
      activity.textContent = "";
      recent.forEach(function (r) {
        var li = el("li");
        var a = el("a", null, r.name);
        a.href = r.url;
        li.appendChild(a);
        var d = r.fork ? "Fork · " + (forkDesc[r.name.toLowerCase()] || r.desc || "") : (r.desc || "");
        li.appendChild(el("span", "desc", d));
        li.appendChild(el("span", "when", ago(r.pushed)));
        activity.appendChild(li);
      });
    }
  }).catch(function () { /* keep the static fallback content */ });
})();

// Code on article pages: a Copy button on each listing (figure.listing), and Windows (CRLF)
// line endings on anything copied from a code block. MMBasic terminals and editors don't
// treat a bare LF as the end of a line, so LF-only text pastes as one long statement.
(function () {
  "use strict";
  if (!document.querySelector(".article pre")) return;
  function crlf(t) { return t.replace(/\r?\n/g, "\r\n"); }

  // Text selected by hand inside a code block
  document.addEventListener("copy", function (e) {
    var sel = window.getSelection();
    if (!sel || sel.isCollapsed || !e.clipboardData) return;
    var node = sel.anchorNode;
    var el = node && (node.nodeType === 1 ? node : node.parentElement);
    if (!el || !el.closest(".article pre")) return;
    e.clipboardData.setData("text/plain", crlf(sel.toString()));
    e.preventDefault();
  });

  // The Copy button copies the whole listing, ending with a line break so the last line is entered too
  if (!navigator.clipboard) return;
  var figs = document.querySelectorAll("figure.listing");
  Array.prototype.forEach.call(figs, function (fig) {
    var code = fig.querySelector("pre code");
    var bar = fig.querySelector("figcaption");
    if (!code || !bar) return;
    var b = document.createElement("button");
    b.type = "button";
    b.className = "copy";
    b.textContent = "Copy";
    b.addEventListener("click", function () {
      navigator.clipboard.writeText(crlf(code.textContent.replace(/\s+$/, "")) + "\r\n").then(function () {
        b.textContent = "Copied";
        setTimeout(function () { b.textContent = "Copy"; }, 1600);
      }, function () { b.textContent = "Copy failed"; });
    });
    bar.insertBefore(b, bar.querySelector(".dl"));
  });
})();

// Visit counter. Any page of the live site counts one visit per browser per half hour of
// activity, using the free Abacus counter API (no account, no cookies). The home page shows
// the total in its footer. Local previews only read the count, so testing doesn't add to it.
(function () {
  "use strict";
  var URL_BASE = "https://abacus.jasoncameron.dev/";
  var KEY = "mather.host/visits";
  var GAP_MS = 30 * 60 * 1000;
  var SEEN_KEY = "mh-last-seen";

  var shown = document.querySelector("[data-visits]");
  var live = /(^|\.)mather\.host$/.test(location.hostname);
  var now = Date.now();
  var last = 0;
  try {
    last = Number(localStorage.getItem(SEEN_KEY)) || 0;
    localStorage.setItem(SEEN_KEY, String(now));
  } catch (e) { /* storage blocked: every page view counts */ }

  var counting = live && now - last > GAP_MS;
  if (!counting && !shown) return;

  fetch(URL_BASE + (counting ? "hit/" : "get/") + KEY, { cache: "no-store", referrerPolicy: "no-referrer" })
    .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(function (d) {
      if (!shown || typeof d.value !== "number") return;
      shown.textContent = d.value.toLocaleString("en-GB");
      var word = shown.nextSibling;
      if (word && word.nodeType === 3) word.nodeValue = d.value === 1 ? " visit" : " visits";
      var box = shown.closest(".visits");
      if (box) box.hidden = false;
    })
    .catch(function () { /* leave the counter hidden */ });
})();
