/* =========================================================
   Shared task-page runtime.
   - Reads ?agent=clone|generic to pick script + label
   - Plays the transcript with a typing animation
   - Fires highlight cues at scripted timestamps
   - Enables the footer buttons after the script ends
   ========================================================= */

const Runtime = {
  agent: 'clone',
  state: 'idle',          // idle | playing | done
  cues:  [],              // [{at: ms, fn: () => void}]
  charDelay: 24,          // ms per character
  timers: [],

  init({ scriptByAgent, cues = [] }) {
    const params = new URLSearchParams(location.search);
    this.agent = params.get('agent') === 'generic' ? 'generic' : 'clone';
    this.script = scriptByAgent[this.agent];
    this.cues = cues;
    this.bindControls();
    this.renderAgentToggle();
    // Auto-play after a short delay for nicer demo feel
    setTimeout(() => this.play(), 600);
  },

  bindControls() {
    document.querySelectorAll('[data-action="replay"]').forEach(b =>
      b.addEventListener('click', () => this.play(true)));
    document.querySelectorAll('[data-action="skip"]').forEach(b =>
      b.addEventListener('click', () => this.finishImmediately()));
  },

  renderAgentToggle() {
    const wrap = document.querySelector('.exp-controls');
    if (!wrap) return;
    wrap.querySelectorAll('[data-agent]').forEach(b => {
      b.classList.toggle('active', b.dataset.agent === this.agent);
      b.addEventListener('click', () => {
        const url = new URL(location.href);
        url.searchParams.set('agent', b.dataset.agent);
        location.href = url.toString();
      });
    });
  },

  play(reset = false) {
    this.timers.forEach(clearTimeout);
    this.timers = [];
    this.state = 'playing';

    const target = document.querySelector('.transcript .body');
    if (!target) return;
    target.innerHTML = '';
    const caret = document.createElement('span');
    caret.className = 'caret';
    target.appendChild(caret);

    // disable footer buttons during playback
    document.querySelectorAll('.btn.gated, .decision-card.gated').forEach(b => {
      b.setAttribute('aria-disabled', 'true');
      b.disabled = true;
    });

    // Render script as HTML chunks so we can keep keyword/principal markup
    const tokens = this.tokenise(this.script);
    let elapsed = 0;
    let i = 0;
    const step = () => {
      if (i >= tokens.length) {
        caret.remove();
        this.state = 'done';
        document.querySelectorAll('.btn.gated, .decision-card.gated').forEach(b => {
          b.setAttribute('aria-disabled', 'false');
          b.disabled = false;
        });
        return;
      }
      const tok = tokens[i++];
      if (tok.tag) {
        const el = document.createElement('span');
        el.className = tok.tag;
        el.textContent = tok.text;
        target.insertBefore(el, caret);
        const t = setTimeout(step, tok.text.length * this.charDelay);
        this.timers.push(t);
      } else {
        // type char by char so the caret stays at the end
        let j = 0;
        const typer = () => {
          if (j >= tok.text.length) {
            step();
            return;
          }
          caret.insertAdjacentText('beforebegin', tok.text[j++]);
          const t = setTimeout(typer, this.charDelay);
          this.timers.push(t);
        };
        typer();
      }
      elapsed += tok.text.length * this.charDelay;
    };
    step();

    // schedule cues based on the *plain* script length
    let cumulative = 0;
    this.cues.forEach(cue => {
      const at = typeof cue.at === 'number'
        ? cue.at
        : Math.round((cue.atFraction || 0) * this.plainText().length * this.charDelay);
      const t = setTimeout(cue.fn, at);
      this.timers.push(t);
    });
  },

  finishImmediately() {
    this.timers.forEach(clearTimeout);
    this.timers = [];
    const target = document.querySelector('.transcript .body');
    if (target) target.innerHTML = this.renderScriptStatic(this.script);
    document.querySelectorAll('.btn.gated, .decision-card.gated').forEach(b => {
      b.setAttribute('aria-disabled', 'false');
      b.disabled = false;
    });
    this.cues.forEach(c => c.fn());
    this.state = 'done';
  },

  /* Script tokenisation supports inline marks:
     [k:bottleneck]   → keyword (red)
     [p:Look]         → principal signature (amber italic)
  */
  tokenise(s) {
    const re = /\[(k|p):([^\]]+)\]/g;
    const out = [];
    let last = 0; let m;
    while ((m = re.exec(s)) !== null) {
      if (m.index > last) out.push({ text: s.slice(last, m.index) });
      out.push({ text: m[2], tag: m[1] === 'k' ? 'keyword' : 'principal' });
      last = m.index + m[0].length;
    }
    if (last < s.length) out.push({ text: s.slice(last) });
    return out;
  },

  plainText() {
    return this.script.replace(/\[(k|p):([^\]]+)\]/g, '$2');
  },

  renderScriptStatic(s) {
    return this.tokenise(s).map(t =>
      t.tag ? `<span class="${t.tag}">${t.text}</span>` : t.text
    ).join('');
  }
};

/* Convenience: small helpers used by individual task pages */

function highlightRow(selector, ms = 2200) {
  const el = document.querySelector(selector);
  if (!el) return;
  el.classList.add('highlight');
  setTimeout(() => el.classList.remove('highlight'), ms);
}

function revealPanel(selector) {
  const el = document.querySelector(selector);
  if (!el) return;
  el.style.transition = 'opacity 400ms ease, transform 400ms ease';
  el.style.opacity = '1';
  el.style.transform = 'translateY(0)';
}

function hidePanel(selector) {
  const el = document.querySelector(selector);
  if (!el) return;
  el.style.opacity = '0';
  el.style.transform = 'translateY(8px)';
}

function showModal(html, onConfirm, onCancel) {
  const overlay = document.getElementById('overlay');
  overlay.innerHTML = `<div class="modal">${html}</div>`;
  overlay.classList.add('active');
  overlay.querySelector('[data-modal="confirm"]')?.addEventListener('click', () => {
    overlay.classList.remove('active');
    onConfirm && onConfirm();
  });
  overlay.querySelector('[data-modal="cancel"]')?.addEventListener('click', () => {
    overlay.classList.remove('active');
    onCancel && onCancel();
  });
}
