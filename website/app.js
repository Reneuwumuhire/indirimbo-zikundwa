// --- Auto-wire download buttons to the latest GitHub release assets ----------
// No tracking — a single public, unauthenticated read of the releases endpoint.
// Until builds are uploaded, the buttons keep their "releases page" fallback and
// show a "Build coming soon" badge.
(function () {
  const REPO = 'Reneuwumuhire/indirimbo-zikundwa';

  const setReady = (linkId, stateId, url, label) => {
    const link = document.getElementById(linkId);
    const state = document.getElementById(stateId);
    if (link && url) link.href = url;
    if (state) {
      state.textContent = label;
      state.classList.add('ready');
    }
  };

  fetch(`https://api.github.com/repos/${REPO}/releases`, { cache: 'no-store' })
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((releases) => {
      if (!Array.isArray(releases) || !releases.length) return;
      const rel = releases.find((r) => !r.prerelease && !r.draft) || releases[0];
      const assets = rel.assets || [];
      const find = (rx) => {
        const a = assets.find((x) => rx.test(x.name));
        return a && a.browser_download_url;
      };

      const apk = find(/\.apk$/i);
      const ios = find(/\.(ipa|tipa)$/i);
      const web = find(/web.*\.(zip|tar\.gz|tgz)$/i) || find(/\.(zip|tar\.gz|tgz)$/i);

      if (apk) setReady('dl-android', 'state-android', apk, 'Download .apk');
      if (ios) setReady('dl-ios', 'state-ios', ios, 'Download for iOS');
      if (web) setReady('dl-web', 'state-web', web, 'Download web build');

      // If any real build exists, point the hero CTA at the first available asset.
      const first = apk || ios || web;
      const hero = document.getElementById('hero-dl');
      if (first && hero) hero.setAttribute('href', '#download');
    })
    .catch(() => {
      /* offline / rate-limited / no releases yet — static fallbacks still work */
    });
})();

// --- Tiny scroll-reveal. No tracking, no deps. ------------------------------
(function () {
  const els = document.querySelectorAll(
    '.card, .how-item, .strip-item, .show-text, .show-shot, .dl-card, .faq details, .book, .gallery img'
  );
  els.forEach((el) => el.classList.add('reveal'));
  if (!('IntersectionObserver' in window)) {
    els.forEach((el) => el.classList.add('in'));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (e.isIntersecting) {
          e.target.classList.add('in');
          io.unobserve(e.target);
        }
      }
    },
    { threshold: 0.12 }
  );
  els.forEach((el) => io.observe(el));
})();
