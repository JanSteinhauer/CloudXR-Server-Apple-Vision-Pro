/* =========================================================
   Reusable avatar SVGs for the AR window prototype.
   Two render modes: 'clone' (photoreal stylised) and
   'generic' (geometric humanoid). Posture variant 'forward'
   leans the body slightly for Task 2 (Performance Feedback).
   ========================================================= */

const AVATARS = {
  clone(opts = {}) {
    const lean = opts.posture === 'forward' ? 12 : 0;
    return `
    <svg viewBox="0 0 360 620" xmlns="http://www.w3.org/2000/svg">
      <!-- ground shadow -->
      <ellipse cx="180" cy="600" rx="160" ry="14" fill="#000" opacity="0.45"/>
      <!-- body -->
      <path d="M ${60 - lean*0.3} 600
               Q ${80 - lean*0.4} 360 ${180 - lean} 280
               Q ${280 - lean*1.6} 360 ${300 - lean*1.7} 600 Z"
            fill="#3a4a5e"/>
      <!-- shirt v-neck -->
      <path d="M ${150 - lean} 300 L ${180 - lean} 340 L ${210 - lean} 300 Z" fill="#2a3140"/>
      ${opts.posture === 'forward'
        ? `<ellipse cx="${180 - lean}" cy="440" rx="38" ry="22" fill="#d8b89a"/>`
        : ''}
      ${opts.gesture === 'palmUp'
        ? `<ellipse cx="92" cy="395" rx="30" ry="16" fill="#d8b89a" transform="rotate(-22 92 395)"/>`
        : ''}
      <!-- head -->
      <ellipse cx="${180 - lean}" cy="170" rx="86" ry="100" fill="#d8b89a"/>
      <!-- hair -->
      <path d="M ${96 - lean} 142
               Q ${118 - lean} 64 ${180 - lean} 64
               Q ${244 - lean} 64 ${266 - lean} 142
               Q ${266 - lean} 122 ${180 - lean} 110
               Q ${102 - lean} 122 ${96 - lean} 142 Z"
            fill="#2b2218"/>
      <!-- brow lines (subtle for clone) -->
      ${opts.posture === 'forward'
        ? `<line x1="${148 - lean}" y1="152" x2="${172 - lean}" y2="154" stroke="#3a2a20" stroke-width="2"/>
           <line x1="${188 - lean}" y1="154" x2="${212 - lean}" y2="152" stroke="#3a2a20" stroke-width="2"/>`
        : ''}
      <!-- eyes -->
      <ellipse cx="${152 - lean}" cy="174" rx="6" ry="3" fill="#1a1a1a"/>
      <ellipse cx="${208 - lean}" cy="174" rx="6" ry="3" fill="#1a1a1a"/>
      <!-- mouth -->
      ${opts.posture === 'forward'
        ? `<line x1="${158 - lean}" y1="222" x2="${202 - lean}" y2="222" stroke="#7a4a3a" stroke-width="2"/>`
        : `<path d="M ${160 - lean} 220 Q ${180 - lean} 230 ${200 - lean} 220" stroke="#7a4a3a" stroke-width="2" fill="none"/>`}
    </svg>`;
  },

  generic() {
    return `
    <svg viewBox="0 0 360 620" xmlns="http://www.w3.org/2000/svg">
      <ellipse cx="180" cy="600" rx="150" ry="14" fill="#000" opacity="0.45"/>
      <!-- geometric body -->
      <path d="M 90 600 Q 110 360 180 280 Q 250 360 270 600 Z" fill="#5b6378"/>
      <!-- collar capsule -->
      <rect x="146" y="280" width="68" height="36" rx="18" fill="#6b7388"/>
      <!-- abstract head -->
      <ellipse cx="180" cy="170" rx="78" ry="90" fill="#cfd6e3"/>
      <!-- visor glow ring -->
      <ellipse cx="180" cy="170" rx="78" ry="90" fill="none"
               stroke="#7bb6ff" stroke-opacity="0.45" stroke-width="2"/>
      <!-- minimal eye line -->
      <rect x="138" y="170" width="22" height="4" rx="2" fill="#1a1a1a"/>
      <rect x="200" y="170" width="22" height="4" rx="2" fill="#1a1a1a"/>
    </svg>`;
  }
};

/**
 * Mount an avatar into a host element based on URL ?agent= and posture
 * options provided by the task page.
 *
 *   mountAvatar(host, {
 *     forcedType:  'clone' | 'generic' | null,
 *     posture:     'forward' | 'casual' | null,
 *     gesture:     'palmUp' | null,
 *     amberHalo:   true | false  // Task 2
 *   })
 */
function mountAvatar(host, opts = {}) {
  const params = new URLSearchParams(location.search);
  const type = opts.forcedType || params.get('agent') || 'clone';
  const isClone = type === 'clone';

  const labelText = isClone
    ? (opts.posture === 'forward'
        ? 'Manager Clone · forward lean'
        : opts.gesture === 'palmUp'
          ? 'Manager Clone · advisory mode'
          : 'Manager Clone (Ditto)')
    : 'Generic Agent (Delegate)';

  host.classList.toggle('generic', !isClone);
  host.classList.toggle('amber', !!opts.amberHalo && isClone);

  host.innerHTML = `
    <div class="halo"></div>
    ${isClone ? AVATARS.clone({ posture: opts.posture, gesture: opts.gesture }) : AVATARS.generic()}
    <div class="label">${labelText}</div>
  `;
}
