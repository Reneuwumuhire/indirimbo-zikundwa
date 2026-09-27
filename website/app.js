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
