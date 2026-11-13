// Kentr – animaties voor kent.lrvdlinden.app
// Alles respecteert "minder beweging" (prefers-reduced-motion).
(function () {
  'use strict';
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const hasIO = 'IntersectionObserver' in window;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  // Jaartal in de footer
  $$('.year').forEach(e => { e.textContent = new Date().getFullYear(); });

  // Navigatie krijgt schaduw na scrollen
  const nav = $('.nav');
  if (nav) {
    const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 10);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // Volgorde-variabelen voor gestaffelde animaties
  $$('.list').forEach(l => $$('li', l).forEach((li, i) => li.style.setProperty('--r', i)));
  $$('.fp-row').forEach((r, i) => r.style.setProperty('--r', i));
  $$('.ld-row').forEach((r, i) => r.style.setProperty('--k', i));
  $$('.fd-chips span').forEach((c, i) => c.style.setProperty('--c', i));

  // Hulpje: één keer iets doen als een element in beeld komt
  function whenVisible(el, fn, threshold = 0.25) {
    if (!el) return;
    if (reduce || !hasIO) { fn(); return; }
    const io = new IntersectionObserver(entries => {
      if (entries.some(e => e.isIntersecting)) { io.disconnect(); fn(); }
    }, { threshold, rootMargin: '0px 0px -40px 0px' });
    io.observe(el);
  }

  // Inschuiven tijdens scrollen
  const groups = ['.section-head', '.features .card', '.demo', '.panel', '.stats .stat', '.trust-item',
    '#faq details', '.brands-title', '.more-apps', '.page > *'];
  const items = [];
  groups.forEach(sel => $$(sel).forEach((el, i) => {
    if (el.closest('.hero')) return;
    el.classList.add('reveal');
    el.style.setProperty('--r', String(i % 6));
    items.push(el);
  }));
  if (reduce || !hasIO) {
    items.forEach(el => el.classList.add('in'));
  } else {
    const io = new IntersectionObserver(entries => entries.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    }), { threshold: 0, rootMargin: '0px 0px -50px 0px' });
    items.forEach(el => io.observe(el));
  }

  // Tellers: 0 → doel als ze in beeld komen
  function countUp(el) {
    const to = +el.dataset.to;
    const prefix = el.dataset.prefix || '';
    const fmt = n => prefix + n.toLocaleString('nl-NL');
    if (reduce) { el.textContent = fmt(to); return; }
    const start = performance.now(), dur = 1500;
    const step = now => {
      const t = Math.min(1, (now - start) / dur);
      el.textContent = fmt(Math.round(to * (1 - Math.pow(1 - t, 3))));
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }
  $$('.count').forEach(el => {
    el.textContent = (el.dataset.prefix || '') + '0';
    if (el.closest('.lookup-demo')) return; // die telt mee met de demo
    whenVisible(el, () => countUp(el), 0.6);
  });

  // Fiscaal paneel, tijdlijn, slot-CTA
  whenVisible($('.fiscal-panel'), () => $('.fiscal-panel').classList.add('in'), 0.3);
  whenVisible($('.timeline'), () => $('.timeline').classList.add('in'), 0.4);
  whenVisible($('.cta-band'), () => $('.cta-band').classList.add('in'), 0.3);

  // Hero: na de binnenkomst laten zweven en meekantelen met de muis
  const stage = $('.stage');
  const phone = stage && $('.phone', stage);
  if (stage && phone && !reduce) {
    setTimeout(() => { stage.classList.remove('enter-stage'); stage.classList.add('floating'); }, 2900);
    if (window.matchMedia('(pointer: fine)').matches) {
      stage.addEventListener('mousemove', e => {
        const r = stage.getBoundingClientRect();
        const x = (e.clientX - r.left) / r.width - 0.5;
        const y = (e.clientY - r.top) / r.height - 0.5;
        phone.style.transform = `perspective(1200px) rotateY(${x * 12}deg) rotateX(${-y * 9}deg)`;
      });
      stage.addEventListener('mouseleave', () => { phone.style.transform = ''; });
    }
  }

  // Opzoeken-demo: kenteken typen → zoeken → resultaat met teller; daarna opnieuw
  const ld = $('.lookup-demo');
  if (ld) {
    const text = $('.ld-text', ld);
    const price = $('.count', ld);
    const plates = ['QN-112-T', 'QK-99-NT', '12-QNT-3'];
    let round = 0;
    const sleep = ms => new Promise(r => setTimeout(r, ms));
    async function run() {
      if (reduce) {
        text.textContent = plates[0];
        ld.classList.add('done');
        price.textContent = '€ ' + (+price.dataset.to).toLocaleString('nl-NL');
        return;
      }
      for (;;) {
        ld.classList.remove('done', 'searching');
        price.textContent = '€ 0';
        text.textContent = '';
        await sleep(600);
        const plate = plates[round++ % plates.length];
        for (const ch of plate) { text.textContent += ch; await sleep(ch === '-' ? 90 : 160); }
        await sleep(350);
        ld.classList.add('searching');
        await sleep(1100);
        ld.classList.remove('searching');
        ld.classList.add('done');
        await sleep(900);
        countUp(price);
        await sleep(5200);
      }
    }
    whenVisible(ld, run, 0.35);
  }

  // Terugvinden-demo: filters ploppen erin, zoeken, resultaten schuiven in, één wordt herkend; daarna opnieuw
  const fd = $('.find-demo');
  if (fd) {
    const list = $$('.fd-item', fd);
    const count = $('.fd-count b', fd);
    const sleep = ms => new Promise(r => setTimeout(r, ms));
    async function run() {
      if (reduce) {
        list.forEach(i => i.classList.add('in'));
        fd.classList.add('play');
        $('.match', fd).classList.add('hit');
        count.textContent = list.length;
        return;
      }
      for (;;) {
        fd.classList.remove('play', 'scanning');
        list.forEach(i => i.classList.remove('in', 'dim', 'hit'));
        count.textContent = '0';
        void fd.offsetWidth;
        fd.classList.add('play');
        await sleep(1300);
        fd.classList.add('scanning');
        await sleep(1200);
        fd.classList.remove('scanning');
        for (let i = 0; i < list.length; i++) {
          list[i].classList.add('in');
          count.textContent = String(i + 1);
          await sleep(320);
        }
        await sleep(700);
        list.forEach(i => { if (!i.classList.contains('match')) i.classList.add('dim'); });
        $('.match', fd).classList.add('hit');
        await sleep(4200);
      }
    }
    whenVisible(fd, run, 0.35);
  }

  // Een gedeelde #vraag gaat vanzelf open en blijft zichtbaar
  function openFromHash() {
    const id = decodeURIComponent(location.hash.slice(1));
    const el = id && document.getElementById(id);
    if (!el) return;
    if (el.tagName === 'DETAILS') el.open = true;
    el.classList.add('in');
    $$('.reveal', el).forEach(r => r.classList.add('in'));
  }
  openFromHash();
  window.addEventListener('hashchange', openFromHash);
})();
