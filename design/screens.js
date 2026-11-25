/* TernaryCode Mobile — All 14 Screen Templates & Slate Mobile UI Kit.
   Every screen mirrors real TernaryCode Companion data structures (src/companion.rs, src/ade.rs)
   plus Android-native enhancements (QR scanner, multi-host, quick terminal keys, lock-screen actions). */

window.TC = (() => {
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  /* ---------------------------------------------------------------- Icons & Brand Marks */
  const ic = (name, cls = '') => `<svg class="ic${cls ? ' ' + cls : ''}" aria-hidden="true"><use href="#i-${name}"/></svg>`;

  const STATUS = {
    running:      ['notch',     'running',  'Running'],
    needs_input:  ['chat',      'input',    'Needs input'],
    done:         ['check',     'done',     'Done'],
    failed:       ['x',         'failed',   'Failed'],
    idle:         ['circle',    'idle',     'Idle'],
    rate_limited: ['hourglass', 'limited',  'Rate limited'],
    cooldown:     ['clock',     'cooldown', 'Cooldown'],
  };

  function glyph(status, size = 12, spin = true) {
    const s = STATUS[status] || STATUS.idle;
    const sp = s[0] === 'notch' && spin ? ' spin' : '';
    return ic(s[0], `s${size} c-${s[1]}${sp}`);
  }

  function pill(status, label) {
    const s = STATUS[status] || STATUS.idle;
    return `<span class="pill t-${s[1]}">${glyph(status, 12)}${esc(label || s[2])}</span>`;
  }

  const AGENT_SVG = {
    claude: `<svg viewBox="0 0 24 24"><path fill="#D97757" d="m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"/></svg>`,
    codex: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z"/></svg>`,
    opencode: `<svg viewBox="0 0 240 300"><path fill="currentColor" d="M180 60H60V240H180V60ZM240 300H0V0H240V300Z"/><path fill="currentColor" fill-opacity=".28" d="M180 240H60V120H180V240Z"/></svg>`,
    antigravity: `<img src="assets/antigravity.png" alt="">`,
  };

  function agentTile(agent) {
    if (agent === 'claude') return `<span class="ag-tile">${AGENT_SVG.claude}</span>`;
    if (agent === 'codex') return `<span class="ag-tile">${AGENT_SVG.codex}</span>`;
    if (agent === 'opencode') return `<span class="ag-tile">${AGENT_SVG.opencode}</span>`;
    if (agent === 'antigravity') return `<span class="ag-tile">${AGENT_SVG.antigravity}</span>`;
    return `<span class="ag-tile">${ic('term', 's12')}</span>`;
  }

  /* ---------------------------------------------------------------- Android Chrome */
  function androidBar(opts = {}) {
    const darkStyle = opts.onDark ? `color:#EDEDF0;background:${opts.darkBg || '#070709'};` : '';
    return `<div class="a-status" style="${darkStyle}">
      <span>09:41</span>
      <span class="a-camera"></span>
      <span class="a-status-r" style="${opts.onDark ? 'color:#D4D4D8;' : ''}">
        ${ic('wifi', 's12')}
        <span class="a-bat">94%</span>
      </span>
    </div>`;
  }

  function gesturePill(cls = '') {
    return `<div class="a-gesture${cls ? ' ' + cls : ''}"><i></i></div>`;
  }

  function bottomNav(activeTab, waitingCount = 2, inboxCount = 3, hasErr = true) {
    const btn = (id, label, icon, count, tone) => `
      <button class="${activeTab === id ? 'active' : ''}" data-act="tab" data-tab="${id}">
        <span class="tab-ic">${ic(icon, 's20')}${count ? `<span class="tab-badge t-${tone}">${count}</span>` : ''}</span>
        <span>${label}</span>
      </button>`;
    return `<nav class="m-nav">
      ${btn('live', 'Live', 'term', waitingCount, 'input')}
      ${btn('inbox', 'Inbox', 'tray', inboxCount, hasErr ? 'failed' : 'input')}
      ${btn('projects', 'Projects', 'squares', 0, '')}
      ${btn('accounts', 'Accounts', 'user', 0, '')}
    </nav>${gesturePill()}`;
  }

  function topHead(title, hostLabel, statusDot = 'ok', extraRight = '') {
    return `<div class="m-head">
      <h1>${esc(title)}</h1>
      <span class="sp"></span>
      <button class="host-pill" data-act="open-hosts" title="Switch host">
        <span class="dot ${statusDot}"></span>
        <span>${esc(hostLabel)}</span>
        ${ic('caret-down', 's12')}
      </button>
      ${extraRight}
      <button class="ibtn" data-act="open-settings" title="Settings">${ic('gear', 's18')}</button>
    </div>`;
  }

  /* ---------------------------------------------------------------- Realistic Fixtures */
  function createInitialState() {
    return {
      hostId: 'mbp',
      hosts: [
        { id: 'mbp', name: 'MacBook Pro', os: 'Mac', via: 'Wi-Fi LAN', addr: 'http://192.168.1.5:7890', latency: '4 ms', online: true, panes: 4 },
        { id: 'linux', name: 'Workstation', os: 'Linux', via: 'Tailscale', addr: 'http://100.84.12.9:7890', latency: '28 ms', online: true, panes: 2 },
        { id: 'win', name: 'Desktop PC', os: 'Windows', via: 'Cloudflare', addr: 'https://tc.ilham.dev', latency: '—', online: false, lastSeen: '2h ago', panes: 0 },
      ],
      selectedPane: 1,
      inboxFilter: 'all',
      projectQuery: '',
      failoverMode: 'auto',
      termFont: 11,
      termWrap: true,
      settings: {
        keepAlive: true,
        notifInput: true,
        notifLimit: true,
        notifFailed: true,
        notifDone: false,
        haptics: true,
        biometric: false,
      },
      panes: [
        {
          id: 1, project: 'storefront', hue: 'blue', letter: 'S', branch: 'main',
          label: 'Claude Code', agent: 'claude', provider: 'Claude Code', profile: 'claude1',
          supportsProfiles: true, status: 'needs_input', statusLabel: 'Needs input',
          task: 'Fix OAuth redirect loop',
          message: 'Bash · npm test -- auth',
          askTitle: 'Claude Code wants to run a command',
          askCmd: 'npm test -- auth', askTool: 'Bash', age: '12s',
          rateLimit: null,
          htmlOut: [
            `<span class="a">⏺ </span><span class="p">Update</span><span class="d">(src/auth/callback.ts)</span>`,
            `<span class="d">  ⎿  Updated with 6 additions and 2 removals</span>`,
            `<span class="d">  38   </span>const session = await getSession(req)`,
            `<span class="dl">  39 -   return redirect(session.returnTo)</span>`,
            `<span class="al">  39 +   const target = safeReturnTo(session.returnTo)</span>`,
            `<span class="al">  40 +   return redirect(target ?? "/account")</span>`,
            ``,
            `<span class="a">⏺ </span><span class="p">Bash</span><span class="d">(npm test -- auth)</span>`,
            `<span class="y">  ⎿  Waiting for your approval…</span>`,
          ].join('\n'),
        },
        {
          id: 2, project: 'api-gateway', hue: 'green', letter: 'A', branch: 'feat/ratelimit',
          label: 'Claude Code', agent: 'claude', provider: 'Claude Code', profile: 'claude1',
          supportsProfiles: true, status: 'rate_limited', statusLabel: 'Rate limited',
          task: 'Rate-limit /v1/search per API key',
          message: '5-hour window exhausted', age: '2m',
          rateLimit: { fromProfile: 'claude1', resetsIn: '14m', reason: 'You have reached your 5-hour usage limit on claude1 (MAX).' },
          htmlOut: [
            `<span class="a">⏺ </span><span class="p">Update</span><span class="d">(src/middleware/ratelimit.ts)</span>`,
            `<span class="d">  ⎿  Updated with 41 additions</span>`,
            `<span class="al">  14 +   const key = req.headers["x-api-key"]</span>`,
            `<span class="al">  15 +   if (bucket.remaining === 0) return res.status(429)</span>`,
            `<span class="a">⏺ </span><span class="p">Bash</span><span class="d">(npm test)</span>`,
            `<span class="g">  ⎿  Tests: 88 passed, 88 total</span>`,
            ``,
            `<span class="y">⚠ Usage limit reached for claude1 · resets in 14m</span>`,
          ].join('\n'),
        },
        {
          id: 3, project: 'ternarycode', hue: 'violet', letter: 'T', branch: 'main',
          label: 'Codex', agent: 'codex', provider: 'ChatGPT / Codex', profile: 'codex1',
          supportsProfiles: true, status: 'running', statusLabel: 'Running',
          task: 'Add companion api_version & stream',
          message: 'Running cargo test --workspace', age: '3m',
          rateLimit: null,
          htmlOut: [
            `<span class="c">• </span>Explored`,
            `<span class="d">  └ Read src/companion.rs, src/ade.rs</span>`,
            `<span class="c">• </span>Edited <span class="p">src/companion.rs</span> <span class="g">(+44</span> <span class="r">-6</span><span class="g">)</span>`,
            `<span class="c">• </span>Ran <span class="p">cargo test --workspace</span>`,
            `<span class="d">  └ Compiling ternarycode v0.3.12</span>`,
            `<span class="d">  └ Running unittests src/lib.rs (118 tests)</span>`,
            `<span class="b">◦ Working (48s · esc to interrupt)</span>`,
          ].join('\n'),
        },
        {
          id: 4, project: 'mobile-app', hue: 'rose', letter: 'M', branch: 'dev',
          label: 'flutter test', agent: 'shell', provider: null, profile: null,
          supportsProfiles: false, status: 'failed', statusLabel: 'Failed (code 1)',
          task: 'flutter test',
          message: 'flutter test exited with code 1', age: '4m',
          rateLimit: null,
          htmlOut: [
            `<span class="b">~/code/mobile-app </span><span class="d">dev </span><span class="g">❯ </span>flutter test`,
            `<span class="d">00:04 +31: loading test/cart_test.dart</span>`,
            `<span class="r">00:05 +31 -1: Cart applies voucher [E]</span>`,
            `<span class="r">  Expected: &lt;90.0&gt;</span>`,
            `<span class="r">    Actual: &lt;100.0&gt;</span>`,
            `<span class="d">  test/cart_test.dart 42:7</span>`,
            `<span class="r">00:06 +44 -1: Some tests failed.</span>`,
            `<span class="b">~/code/mobile-app </span><span class="d">dev </span><span class="g">❯ </span><span class="cur"></span>`,
          ].join('\n'),
        },
      ],
      finished: [
        { id: 'fin-1', project: 'docs-site', hue: 'amber', letter: 'D', agent: 'antigravity', who: 'Antigravity CLI', title: 'Updated onboarding copy · 2 files', age: '9m' },
      ],
      projects: [
        {
          id: 1, name: 'storefront', letter: 'S', hue: 'blue', branch: 'main',
          worktrees: [{ name: 'codex-export', branch: 'tc/export', status: 'running' }],
          sessions: [
            { id: 's1', title: 'Fix OAuth redirect loop', agent: 'claude', profile: 'claude1', status: 'needs_input', age: 'live', livePane: 1 },
            { id: 's2', title: 'Refactor Stripe webhook retries', agent: 'claude', profile: 'claude2', status: 'done', age: '2h ago', livePane: null },
            { id: 's3', title: 'Add order CSV export', agent: 'codex', profile: 'codex1', status: 'idle', age: 'yesterday', livePane: null },
          ],
        },
        {
          id: 2, name: 'ternarycode', letter: 'T', hue: 'violet', branch: 'main',
          worktrees: [],
          sessions: [
            { id: 's4', title: 'Add companion api_version & stream', agent: 'codex', profile: 'codex1', status: 'running', age: 'live', livePane: 3 },
            { id: 's5', title: 'Audit 53 bugs across workspace', agent: 'antigravity', profile: 'agy1', status: 'done', age: '4h ago', livePane: null },
          ],
        },
        {
          id: 3, name: 'api-gateway', letter: 'A', hue: 'green', branch: 'feat/ratelimit',
          worktrees: [],
          sessions: [
            { id: 's6', title: 'Rate-limit /v1/search per API key', agent: 'claude', profile: 'claude1', status: 'rate_limited', age: 'live', livePane: 2 },
            { id: 's7', title: 'Cache API keys in Redis', agent: 'claude', profile: 'claude2', status: 'done', age: '1d ago', livePane: null },
          ],
        },
      ],
      profiles: [
        {
          rank: 1, id: 'claude1', agent: 'claude', provider: 'Claude Code', hint: 'work@acme.dev',
          plan: 'MAX', state: 'rate_limited', stateLabel: 'Limited', enabled: true,
          w5: { pct: 100, tok: '1.4M', reset: '14m' }, wk: { pct: 64, tok: '8.9M', reset: '2d 6h' },
          activeIn: 'storefront, api-gateway',
        },
        {
          rank: 2, id: 'claude2', agent: 'claude', provider: 'Claude Code', hint: 'me@ilham.dev',
          plan: 'PRO', state: 'done', stateLabel: 'Ready', enabled: true,
          w5: { pct: 12, tok: '210k', reset: '4h 02m' }, wk: { pct: 28, tok: '3.1M', reset: '5d 11h' },
          activeIn: null,
        },
        {
          rank: 3, id: 'codex1', agent: 'codex', provider: 'ChatGPT / Codex', hint: 'ChatGPT Plus',
          plan: 'PLUS', state: 'running', stateLabel: 'In use', enabled: true,
          w5: { pct: 18, tok: '380k', reset: '2h 40m' }, wk: { pct: 22, tok: '4.2M', reset: '4d 18h' },
          activeIn: 'ternarycode',
        },
        {
          rank: 4, id: 'agy1', agent: 'antigravity', provider: 'Antigravity CLI', hint: 'Google AI Pro',
          plan: 'PRO', state: 'done', stateLabel: 'Ready', enabled: true,
          w5: { pct: 8, tok: '95k', reset: '4h 45m' }, wk: { pct: 14, tok: '1.1M', reset: '6d 2h' },
          activeIn: null,
        },
      ],
    };
  }

  function healthyFor(state, pane) {
    return state.profiles
      .filter(p => p.enabled && p.state !== 'rate_limited' && p.state !== 'cooldown' && p.state !== 'failed' && p.id !== pane.profile)
      .sort((a, b) => (pane.provider && a.provider === pane.provider ? 0 : 1) - (pane.provider && b.provider === pane.provider ? 0 : 1));
  }

  function quotaMeter(label, w) {
    const tone = w.pct >= 90 ? 'limited' : w.pct >= 70 ? 'input' : 'accent';
    return `<div class="meter">
      <div class="meter-top">
        <span class="meter-lbl">${esc(label)}</span>
        <span class="meter-val${w.pct >= 70 ? ' c-' + tone : ''}">${w.pct}% · ${esc(w.tok)}</span>
        <span class="meter-rst">↺ ${esc(w.reset)}</span>
      </div>
      <div class="bar"><i class="b-${tone}" style="width:${w.pct}%"></i></div>
    </div>`;
  }

  /* ---------------------------------------------------------------- Individual Screen Renderers */

  // 01 · Welcome & Pair
  function screenWelcome() {
    return `${androidBar()}
      <div class="pair-wrap">
        <img class="pair-logo" src="assets/icon.svg" alt="TernaryCode">
        <h1>Pair with TernaryCode</h1>
        <p class="pair-lead">Watch live agent runs, approve commands, switch rate-limited accounts, and resume sessions from your Android phone.</p>
        <div style="display:flex;flex-direction:column;gap:8px;margin-top:6px">
          <button class="btn primary block" data-act="go-screen" data-screen="qr">${ic('qr', 's18')}Scan QR code</button>
          <button class="btn secondary block" data-act="go-screen" data-screen="manual">${ic('keyboard', 's18')}Enter address &amp; code</button>
        </div>
        <div class="card" style="margin-top:8px">
          <div class="row" style="min-height:44px">
            ${ic('wifi', 's14 c-accent')}
            <div class="grow">
              <div class="t1" style="font-size:12px">Same Wi-Fi, Tailscale, Cloudflare or ngrok</div>
              <div class="data">Settings → Phone on your computer</div>
            </div>
          </div>
          <div class="row" style="min-height:44px">
            ${ic('shield', 's14 c-done')}
            <div class="grow">
              <div class="t1" style="font-size:12px">Stored in Android Keystore</div>
              <div class="data">Per-device token · revoke anytime</div>
            </div>
          </div>
        </div>
      </div>
      ${gesturePill('win')}`;
  }

  // 02 · Native QR Camera Scanner
  function screenQr() {
    const pattern = [
      1,1,1,0,1,1,1,
      1,0,1,0,1,0,1,
      1,1,1,0,1,1,1,
      0,0,0,1,0,0,0,
      1,0,1,1,0,1,0,
      1,1,0,0,1,0,1,
      1,0,1,1,1,1,1,
    ];
    return `${androidBar({ onDark: true })}
      <div class="cam-screen">
        <div class="cam-bg"></div>
        <div class="cam-top">
          <button class="cam-btn" data-act="go-screen" data-screen="welcome">${ic('arrow-left', 's14')}Back</button>
          <button class="cam-btn" data-act="toast" data-msg="Flashlight toggled">${ic('bolt', 's14')}Torch</button>
        </div>
        <div class="cam-mid">
          <div class="reticle">
            <span class="rc tl"></span><span class="rc tr"></span>
            <span class="rc bl"></span><span class="rc br"></span>
            <div class="reticle-qr">${pattern.map(v => `<b class="${v ? '' : 'o'}"></b>`).join('')}</div>
          </div>
          <div class="cam-cap">Point at the QR code in <b style="color:#fff">Settings → Phone</b> on your Mac, Linux, or Windows PC.</div>
        </div>
        <div class="cam-bot">
          <div class="cam-found">
            <img src="assets/icon.svg" alt="" style="width:28px;height:28px;border-radius:7px">
            <div class="grow">
              <div class="t1" style="color:#fff">Detected · 192.168.1.5:7890</div>
              <div class="data" style="color:#A1A1AA">Code K7M9-P2X4-Q8R2</div>
            </div>
            <button class="btn primary xs" data-act="complete-pair">Pair</button>
          </div>
          <button class="btn raised block sm" style="background:rgba(255,255,255,.08);color:#EDEDF0;border-color:rgba(255,255,255,.12)" data-act="go-screen" data-screen="manual">Enter code manually</button>
        </div>
      </div>
      ${gesturePill('dark-cam')}`;
  }

  // 03 · Manual Pairing & Tunnel Entry
  function screenManual(opts = {}) {
    const hasErr = Boolean(opts.error);
    return `${androidBar()}
      <div class="m-body" style="padding-top:10px;gap:14px">
        <div class="m-head">
          <button class="ibtn" data-act="go-screen" data-screen="welcome">${ic('arrow-left', 's18')}</button>
          <h1 style="font-size:18px;line-height:24px">Manual pairing</h1>
        </div>
        <div>
          <span class="field-lbl">Host address (LAN or tunnel)</span>
          <label class="field">
            ${ic('globe', 's14')}
            <input id="m-host" class="mono" value="${esc(opts.addr || 'http://192.168.1.5:7890')}" placeholder="https://tc.example.com">
          </label>
        </div>
        <div>
          <span class="field-lbl">Pairing code</span>
          <label class="field${hasErr ? ' err' : ' focused'}">
            ${ic('key', 's14')}
            <input id="m-code" class="mono" value="${esc(opts.code || 'K7M9-P2X4-Q8R2')}" placeholder="XXXX-XXXX-XXXX">
          </label>
        </div>
        <div>
          <span class="field-lbl">Device name</span>
          <label class="field">
            ${ic('phone', 's14')}
            <input id="m-name" value="${esc(opts.name || 'Pixel 9 Pro')}" placeholder="Android Phone">
          </label>
        </div>
        ${hasErr ? `<div class="err-line">${glyph('failed', 14, false)}<span>${esc(opts.error)}</span></div>` : ''}
        <button class="btn primary block" data-act="manual-connect">Connect</button>
        <div class="card" style="margin-top:4px">
          <div class="row" style="min-height:46px">
            <div class="grow">
              <div class="t1" style="font-size:12px">Auto-discovered on Wi-Fi (mDNS)</div>
              <div class="data">MacBook Pro · 192.168.1.5:7890</div>
            </div>
            <button class="go-btn" data-act="toast" data-msg="Filled 192.168.1.5:7890">Use</button>
          </div>
        </div>
        <p class="pair-note">Your typed code and device name stay intact if a connection check fails. Each phone receives its own revocable Bearer token.</p>
      </div>
      ${gesturePill('win')}`;
  }

  // 04 · Host Switcher Bottom Sheet + Offline / Reconnecting
  function screenHostsOverlay(state, opts = {}) {
    const activeHost = state.hosts.find(h => h.id === state.hostId) || state.hosts[0];
    const offline = Boolean(opts.offlineBackground);
    const bg = offline
      ? `<div class="m-body">
          ${topHead('Live', 'Desktop PC', 'err')}
          <div class="empty-box">
            <div class="empty-tile">${ic('offline', 's22')}</div>
            <div class="t1" style="font-size:15px">Desktop PC is unreachable</div>
            <div class="t2" style="white-space:normal;max-width:260px">Retrying https://tc.ilham.dev in 4s. Check your tunnel or switch to another computer.</div>
            <div class="duo" style="max-width:260px;margin-top:8px">
              <button class="btn secondary sm" data-act="toast" data-msg="Retrying connection…">Retry now</button>
              <button class="btn primary sm" data-act="open-hosts">Switch host</button>
            </div>
          </div>
        </div>`
      : `<div class="m-body" style="opacity:.45;pointer-events:none">${renderLiveInner(state, state.panes[0])}</div>`;

    return `${androidBar()}
      ${bg}
      ${bottomNav('live', 2, 3, true)}
      <div class="sheet-overlay" data-act="close-overlay">
        <div class="bsheet" data-act="noop">
          <div class="bsheet-handle"></div>
          <div class="bsheet-head">
            <h2>Computers</h2>
            <button class="ibtn sm" data-act="close-overlay">${ic('close', 's14')}</button>
          </div>
          <div class="card">
            ${state.hosts.map(h => `
              <div class="row click" data-act="select-host" data-host="${h.id}">
                <span class="dot ${h.online ? 'ok' : ''}"></span>
                <div class="grow">
                  <div class="t1">${esc(h.name)} <span class="data" style="display:inline;margin-left:4px">${esc(h.via)}</span></div>
                  <div class="data">${esc(h.addr)} · ${h.online ? `${h.panes} panes · ${h.latency}` : `offline · ${h.lastSeen}`}</div>
                </div>
                ${h.id === activeHost.id ? `<span class="tag t-accent">Active</span>` : `<span class="data">${h.online ? 'Switch' : 'Retry'}</span>`}
              </div>`).join('')}
          </div>
          <button class="btn secondary block sm" data-act="go-screen" data-screen="qr">${ic('qr', 's14')}Pair another computer</button>
        </div>
      </div>`;
  }

  // Helper: Live tab body
  function renderLiveInner(state, forcedPane, opts = {}) {
    const host = state.hosts.find(h => h.id === state.hostId) || state.hosts[0];
    const pane = forcedPane || state.panes.find(p => p.id === state.selectedPane) || state.panes[0];
    const healthy = healthyFor(state, pane);
    const ringCls = pane.status === 'needs_input' ? ' ring-wait' : pane.rateLimit ? ' ring-lim' : '';

    let actionBlock = '';
    if (pane.rateLimit) {
      actionBlock = `
        <div class="notice t-limited">
          ${glyph('rate_limited', 16, false)}
          <div class="grow">
            <div class="n-title">${esc(pane.rateLimit.fromProfile)} hit its 5h limit · resets in ${esc(pane.rateLimit.resetsIn)}</div>
            <div class="n-body">${esc(pane.rateLimit.reason)}</div>
          </div>
        </div>
        <div class="duo">
          ${healthy.slice(0, 2).map((pr, i) => `
            <button class="btn ${i === 0 ? 'primary' : 'raised'}" data-act="failover" data-pane="${pane.id}" data-profile="${pr.id}">
              ${ic('swap', 's14')}<span>Resume ${esc(pr.id)}</span>
            </button>`).join('')}
        </div>`;
    } else if (pane.status === 'needs_input') {
      actionBlock = `
        <div class="notice t-input">
          ${glyph('needs_input', 16, false)}
          <div class="grow">
            <div class="n-title">${esc(pane.askTitle || `${pane.label} needs your input`)}</div>
            <div class="n-body">${esc(pane.message)}</div>
          </div>
        </div>
        <div class="trio">
          <button class="btn primary" data-act="quick" data-pane="${pane.id}" data-kind="approve">Approve</button>
          <button class="btn raised" data-act="quick" data-pane="${pane.id}" data-kind="reject">Reject</button>
          <button class="btn danger" data-act="quick" data-pane="${pane.id}" data-kind="interrupt">Stop</button>
        </div>`;
    } else if (pane.status === 'failed') {
      actionBlock = `
        <div class="notice t-failed">
          ${glyph('failed', 16, false)}
          <div class="grow">
            <div class="n-title">${esc(pane.label)} exited with code 1</div>
            <div class="n-body">1 test failed in test/cart_test.dart:42</div>
          </div>
        </div>
        <div class="duo">
          <button class="btn primary sm" data-act="send-cmd" data-pane="${pane.id}" data-cmd="flutter test">Run again</button>
          <button class="btn raised sm" data-act="toast" data-msg="Sent prompt to Claude Code">Ask agent to fix</button>
        </div>`;
    }

    const showQuickKeys = opts.showQuickKeys !== false;
    const showSwaps = pane.supportsProfiles && !pane.rateLimit && healthy.length > 0 && (opts.showSwaps ?? pane.status === 'running');

    return `
      ${topHead('Live', host.name, host.online ? 'ok' : 'warn')}
      <div class="chips">
        ${state.panes.map(p => `
          <button class="chip ${p.id === pane.id ? 'active' : ''}" data-act="select-pane" data-pane="${p.id}">
            ${glyph(p.rateLimit ? 'rate_limited' : p.status, 12)}
            <span>${esc(p.project)}</span>
            <span class="lbl">${esc(p.label)}</span>
          </button>`).join('')}
      </div>
      <div class="term-sheet${ringCls}">
        <div class="pane-head">
          ${agentTile(pane.agent)}
          ${pill(pane.rateLimit ? 'rate_limited' : pane.status, pane.rateLimit ? 'Rate limited' : pane.statusLabel)}
          <span class="pane-where">${esc(pane.profile || pane.label)} · ${esc(pane.branch)}</span>
          <button class="ibtn sm" data-act="open-fullscreen" title="Fullscreen terminal">${ic('expand', 's14')}</button>
        </div>
        <div class="term-out" id="live-term-out">${pane.htmlOut}</div>
      </div>
      ${actionBlock}
      ${showSwaps ? `
        <div style="display:flex;flex-direction:column;gap:6px">
          <div class="sect-label">Switch account</div>
          <div class="swaps">
            ${healthy.slice(0, 4).map(pr => `
              <button class="swap" data-act="failover" data-pane="${pane.id}" data-profile="${pr.id}">
                ${ic('swap', 's12')}<span>${esc(pr.id)}</span><span class="pct">${pr.w5.pct}%</span>
              </button>`).join('')}
          </div>
        </div>` : ''}
      ${showQuickKeys ? `
        <div class="qkeys">
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Enter">↵ Enter</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Esc">Esc</button>
          <button class="qkey warn" data-act="quick" data-pane="${pane.id}" data-kind="interrupt">^C Stop</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Tab">Tab</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Up">↑</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Down">↓</button>
        </div>` : ''}
      <div class="composer">
        <label class="field sm">
          <input id="proto-prompt" placeholder="Send an instruction to ${esc(pane.label)}…" value="${esc(opts.draftPrompt || '')}">
        </label>
        <button class="btn secondary sm" data-act="send-prompt" data-pane="${pane.id}">Send</button>
      </div>`;
  }

  function screenLive(state, paneIdx = null, opts = {}) {
    const pane = paneIdx != null ? state.panes[paneIdx] : null;
    const waiting = state.panes.filter(p => p.status === 'needs_input' || p.rateLimit).length;
    const inboxCnt = state.panes.filter(p => p.status === 'needs_input' || p.status === 'failed' || p.rateLimit).length;
    return `${androidBar()}
      <div class="m-body">${renderLiveInner(state, pane, opts)}</div>
      ${bottomNav('live', waiting, inboxCnt, state.panes.some(p => p.status === 'failed'))}`;
  }

  // 08 · Fullscreen Terminal
  function screenFullscreen(state, paneIdx = 0) {
    const pane = state.panes[paneIdx] || state.panes[0];
    const fsz = state.termFont || 11;
    return `${androidBar()}
      <div class="fs-bar">
        <button class="ibtn sm" data-act="close-fullscreen">${ic('arrow-left', 's16')}</button>
        ${agentTile(pane.agent)}
        <div class="grow">
          <div class="t1" style="font-size:12.5px">${esc(pane.project)} · ${esc(pane.label)}</div>
          <div class="data">${esc(pane.profile || 'shell')} · ${esc(pane.branch)}</div>
        </div>
        <button class="ibtn sm" data-act="term-font" data-delta="-1" title="Smaller text"><span class="mono" style="font-size:11px">A−</span></button>
        <button class="ibtn sm" data-act="term-font" data-delta="1" title="Larger text"><span class="mono" style="font-size:11px">A+</span></button>
        <button class="ibtn sm ${state.termWrap ? 'on' : ''}" data-act="term-wrap" title="Toggle wrap">${ic('wrap', 's14')}</button>
      </div>
      <div style="flex:1;min-height:0;background:var(--sheet);display:flex;flex-direction:column;position:relative">
        <div class="term-out" style="font-size:${fsz}px;line-height:${Math.round(fsz * 1.48)}px;white-space:${state.termWrap ? 'pre-wrap' : 'pre'}">${pane.htmlOut}

<span class="d">────────────────────────────────────────</span>
<span class="d">  [scrollback · 142 lines buffered]</span>
<span class="d">  21   </span>export async function handleCallback(req) {
<span class="d">  22   </span>  const code = req.nextUrl.searchParams.get("code")
<span class="d">  23   </span>  if (!code) return redirect("/login?err=missing")
<span class="d">  24   </span>  const token = await exchangeCode(code)
<span class="d">  25   </span>  await createSession(req, token.userId)
<span class="d">  26   </span>  ...</div>
        <button class="fs-pill" data-act="toast" data-msg="Scrolled to bottom">↓ Latest output</button>
      </div>
      <div style="padding:8px 12px 6px;background:var(--window);border-top:1px solid var(--line-subtle);display:flex;flex-direction:column;gap:7px">
        <div class="qkeys">
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Enter">↵ Enter</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Esc">Esc</button>
          <button class="qkey warn" data-act="quick" data-pane="${pane.id}" data-kind="interrupt">^C</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Tab">Tab</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Up">↑</button>
          <button class="qkey" data-act="send-key" data-pane="${pane.id}" data-key="Down">↓</button>
          <button class="qkey" data-act="toast" data-msg="Copied output">Copy</button>
        </div>
        <div class="composer">
          <label class="field sm"><input placeholder="Type command or instruction…"></label>
          <button class="btn primary sm" data-act="toast" data-msg="Sent to pane">Send</button>
        </div>
      </div>
      ${gesturePill('win')}`;
  }

  // 09 · Inbox List
  function screenInbox(state) {
    const host = state.hosts.find(h => h.id === state.hostId) || state.hosts[0];
    const urgent = state.panes.filter(p => p.status === 'needs_input' || p.status === 'failed' || p.rateLimit);
    const donePanes = state.panes.filter(p => p.status === 'done');
    const finishedCount = donePanes.length + state.finished.length;
    const total = urgent.length + finishedCount;
    const f = state.inboxFilter || 'all';
    const waiting = state.panes.filter(p => p.status === 'needs_input' || p.rateLimit).length;

    return `${androidBar()}
      <div class="m-body">
        ${topHead('Inbox', host.name, host.online ? 'ok' : 'warn')}
        <div class="seg">
          <button class="${f === 'all' ? 'on' : ''}" data-act="inbox-filter" data-filter="all">All <span class="cnt">${total}</span></button>
          <button class="${f === 'needs' ? 'on' : ''}" data-act="inbox-filter" data-filter="needs">Needs you <span class="cnt">${urgent.length}</span></button>
          <button class="${f === 'done' ? 'on' : ''}" data-act="inbox-filter" data-filter="done">Finished <span class="cnt">${finishedCount}</span></button>
        </div>
        ${f !== 'done' ? `
          <div class="sect-label" style="margin-top:2px">Needs you · oldest first</div>
          ${urgent.map(p => `
            <div class="inbox-item click ${p.status === 'needs_input' ? 'urgent' : ''}" data-act="open-inbox-detail" data-pane="${p.id}">
              <div class="inbox-top">
                <span class="pa ${p.hue}">${p.letter}</span>
                <div class="grow">
                  <div style="display:flex;align-items:center;gap:6px">
                    ${glyph(p.rateLimit ? 'rate_limited' : p.status, 12, false)}
                    <span class="t1">${esc(p.project)}</span>
                    <span class="data" style="margin:0">${esc(p.label)}</span>
                  </div>
                  <div class="t2">${esc(p.rateLimit ? `${p.rateLimit.fromProfile} hit 5h limit · resets in ${p.rateLimit.resetsIn}` : p.message)}</div>
                </div>
                <span class="age">${esc(p.age)}</span>
              </div>
              ${p.status === 'needs_input' ? `
                <div class="inbox-acts">
                  <button class="btn primary xs" data-act="quick" data-pane="${p.id}" data-kind="approve">Approve</button>
                  <button class="btn secondary xs" data-act="quick" data-pane="${p.id}" data-kind="reject">Reject</button>
                </div>` : p.rateLimit ? `
                <div class="inbox-acts">
                  <button class="btn primary xs" data-act="failover" data-pane="${p.id}" data-profile="claude2">Resume on claude2</button>
                </div>` : ''}
            </div>`).join('')}
        ` : ''}
        ${f !== 'needs' ? `
          <div class="sect-label" style="margin-top:4px">Finished</div>
          ${donePanes.map(p => `
            <div class="inbox-item click" data-act="focus-pane" data-pane="${p.id}">
              <div class="inbox-top">
                <span class="pa ${p.hue}">${p.letter}</span>
                <div class="grow">
                  <div style="display:flex;align-items:center;gap:6px">
                    ${glyph('done', 12, false)}
                    <span class="t1">${esc(p.project)}</span>
                  </div>
                  <div class="t2">${esc(p.label)} finished · ${esc(p.task)}</div>
                </div>
                <span class="age">now</span>
              </div>
            </div>`).join('')}
          ${state.finished.map(it => `
            <div class="inbox-item click" data-act="toast" data-msg="Opened ${esc(it.project)}">
              <div class="inbox-top">
                <span class="pa ${it.hue}">${it.letter}</span>
                <div class="grow">
                  <div style="display:flex;align-items:center;gap:6px">
                    ${glyph('done', 12, false)}
                    <span class="t1">${esc(it.project)}</span>
                    <span class="data" style="margin:0">${esc(it.who)}</span>
                  </div>
                  <div class="t2">${esc(it.title)}</div>
                </div>
                <span class="age">${esc(it.age)}</span>
              </div>
            </div>`).join('')}
        ` : ''}
      </div>
      ${bottomNav('inbox', waiting, urgent.length, state.panes.some(p => p.status === 'failed'))}`;
  }

  // 10 · Inbox Item Detail
  function screenInboxDetail(state, paneId = 1) {
    const pane = state.panes.find(p => p.id === paneId) || state.panes[0];
    const waiting = state.panes.filter(p => p.status === 'needs_input' || p.rateLimit).length;
    const inboxCnt = state.panes.filter(p => p.status === 'needs_input' || p.status === 'failed' || p.rateLimit).length;

    return `${androidBar()}
      <div class="m-body">
        <div class="m-head">
          <button class="ibtn" data-act="tab" data-tab="inbox">${ic('arrow-left', 's18')}</button>
          <span class="pa sm ${pane.hue}">${pane.letter}</span>
          <span class="t1" style="font-size:14px">${esc(pane.project)}</span>
          <span class="sp"></span>
          ${pill(pane.rateLimit ? 'rate_limited' : pane.status, pane.statusLabel)}
        </div>
        <div style="display:flex;flex-direction:column;gap:8px">
          <div style="font-size:17px;line-height:23px;font-weight:600;letter-spacing:-0.015em">
            ${esc(pane.askTitle || pane.message)}
          </div>
          <div class="cmd-box">
            <span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap"><span class="ps">$</span>${esc(pane.askCmd || pane.message)}</span>
            <span class="tool">${esc(pane.askTool || pane.label)}</span>
          </div>
          <div class="data">Asked ${esc(pane.age)} ago via ${esc(pane.label)} hooks · account ${esc(pane.profile || 'default')}</div>
        </div>
        ${pane.status === 'needs_input' ? `
          <div class="trio">
            <button class="btn primary" data-act="quick" data-pane="${pane.id}" data-kind="approve">Approve</button>
            <button class="btn secondary" data-act="quick" data-pane="${pane.id}" data-kind="reject">Reject</button>
            <button class="btn raised" data-act="focus-pane" data-pane="${pane.id}">Open Live</button>
          </div>` : `
          <button class="btn primary block" data-act="focus-pane" data-pane="${pane.id}">Open in Live</button>`}
        <div style="display:flex;align-items:center;justify-content:space-between;margin-top:4px">
          <span class="sect-label">Last lines</span>
          <span class="mono c-accent" style="font-size:11px">● live</span>
        </div>
        <div class="term-sheet" style="min-height:230px">
          <div class="term-out">${pane.htmlOut}</div>
        </div>
      </div>
      ${bottomNav('inbox', waiting, inboxCnt, state.panes.some(p => p.status === 'failed'))}`;
  }

  // 11 · Projects, Worktrees & Sessions
  function screenProjects(state) {
    const host = state.hosts.find(h => h.id === state.hostId) || state.hosts[0];
    const waiting = state.panes.filter(p => p.status === 'needs_input' || p.rateLimit).length;
    const inboxCnt = state.panes.filter(p => p.status === 'needs_input' || p.status === 'failed' || p.rateLimit).length;
    const q = (state.projectQuery || '').trim().toLowerCase();
    const list = state.projects.filter(pr =>
      !q || pr.name.toLowerCase().includes(q) || pr.sessions.some(s => s.title.toLowerCase().includes(q))
    );

    return `${androidBar()}
      <div class="m-body">
        ${topHead('Projects', host.name, host.online ? 'ok' : 'warn')}
        <label class="field sm">
          ${ic('search', 's14')}
          <input id="proj-filter" value="${esc(state.projectQuery || '')}" placeholder="Filter projects &amp; sessions…">
        </label>
        ${list.map(pr => `
          <section class="group">
            <div class="group-head">
              <span class="pa sm ${pr.hue}">${pr.letter}</span>
              <span class="group-name">${esc(pr.name)}</span>
              <span class="branch-chip">${ic('branch', 's12')}${esc(pr.branch)}</span>
            </div>
            <div class="card">
              ${pr.sessions.map(s => `
                <div class="row click" data-act="${s.livePane ? 'focus-pane' : 'resume-session'}" data-pane="${s.livePane || ''}" data-title="${esc(s.title)}" data-proj="${esc(pr.name)}">
                  ${agentTile(s.agent)}
                  <div class="grow">
                    <div class="t1">${esc(s.title)}</div>
                    <div class="data">${esc(s.profile || s.agent)} · ${esc(s.age)}</div>
                  </div>
                  ${s.livePane
                    ? `<span class="tag t-accent">Live</span>`
                    : `<span class="go-btn">${ic('resume', 's12')}Resume</span>`}
                </div>`).join('')}
              ${pr.worktrees.map(w => `
                <div class="row wt-row click" data-act="toast" data-msg="Worktree ${esc(w.name)} (${esc(w.branch)})">
                  ${ic('fork', 's14')}
                  <div class="grow">
                    <div class="t1" style="font-size:12px">${esc(w.name)}</div>
                    <div class="data">worktree · ${esc(w.branch)}</div>
                  </div>
                  ${glyph(w.status, 12)}
                </div>`).join('')}
            </div>
          </section>`).join('')}
      </div>
      ${bottomNav('projects', waiting, inboxCnt, state.panes.some(p => p.status === 'failed'))}`;
  }

  // 12 · Accounts & Usage Quotas
  function screenAccounts(state) {
    const host = state.hosts.find(h => h.id === state.hostId) || state.hosts[0];
    const waiting = state.panes.filter(p => p.status === 'needs_input' || p.rateLimit).length;
    const inboxCnt = state.panes.filter(p => p.status === 'needs_input' || p.status === 'failed' || p.rateLimit).length;
    const healthyCnt = state.profiles.filter(p => p.state !== 'rate_limited').length;

    return `${androidBar()}
      <div class="m-body">
        ${topHead('Accounts', host.name, host.online ? 'ok' : 'warn')}
        <div class="stat-strip">
          <div class="stat-cell"><span class="stat-lbl">Running</span><span class="stat-val">${state.panes.filter(p => p.status === 'running' || p.status === 'needs_input').length}</span></div>
          <div class="stat-cell"><span class="stat-lbl">Healthy</span><span class="stat-val c-done">${healthyCnt}/${state.profiles.length}</span></div>
          <div class="stat-cell"><span class="stat-lbl">5h tokens</span><span class="stat-val">2.1M</span></div>
        </div>
        <div class="card">
          <div class="row click" data-act="toggle-failover">
            <div class="grow">
              <div class="t1">Failover mode</div>
              <div class="t2">When an account hits its 5h or weekly limit</div>
            </div>
            <span class="tag t-accent">${state.failoverMode === 'auto' ? 'Automatic' : 'Ask me'}</span>
          </div>
        </div>
        <div class="sect-label">Failover order</div>
        ${state.profiles.map(p => `
          <div class="acct-card">
            <div class="acct-top">
              ${agentTile(p.agent)}
              <div class="grow">
                <div class="acct-line">
                  <span class="acct-rank">#${p.rank}</span>
                  <span class="acct-id">${esc(p.id)}</span>
                  <span class="tag t-accent">${esc(p.plan)}</span>
                </div>
                <div class="t2">${esc(p.provider)} · ${esc(p.hint)}</div>
              </div>
              ${pill(p.state, p.stateLabel)}
            </div>
            ${quotaMeter('5h window', p.w5)}
            ${quotaMeter('Weekly', p.wk)}
            ${p.activeIn ? `<div class="data">Active in ${esc(p.activeIn)}</div>` : ''}
          </div>`).join('')}
      </div>
      ${bottomNav('accounts', waiting, inboxCnt, state.panes.some(p => p.status === 'failed'))}`;
  }

  // 13 · Settings, Notifications & Android APK Updates
  function screenSettings(state) {
    const host = state.hosts.find(h => h.id === state.hostId) || state.hosts[0];
    const s = state.settings;
    const sw = (key, on) => `<button class="sw ${on ? 'on' : ''}" data-act="toggle-setting" data-key="${key}" aria-pressed="${on}"><i></i></button>`;
    const theme = document.documentElement.dataset.theme || 'dark';

    return `${androidBar()}
      <div class="m-body">
        <div class="m-head">
          <button class="ibtn" data-act="close-settings">${ic('arrow-left', 's18')}</button>
          <h1 style="font-size:19px">Settings</h1>
          <span class="sp"></span>
          <button class="go-btn" data-act="go-screen" data-screen="android-notif">${ic('bell', 's12')}Shade preview</button>
        </div>

        <div class="sect-label">Connection</div>
        <div class="card">
          <div class="row click" data-act="open-hosts">
            <span class="dot ok"></span>
            <div class="grow">
              <div class="t1">${esc(host.name)}</div>
              <div class="data">${esc(host.addr)} · ${esc(host.via)}</div>
            </div>
            <span class="data">Switch</span>
          </div>
          <div class="row">
            <div class="grow">
              <div class="t1">Background keep-alive</div>
              <div class="t2">Android foreground service keeps SSE live</div>
            </div>
            ${sw('keepAlive', s.keepAlive)}
          </div>
        </div>

        <div class="sect-label">Android notifications</div>
        <div class="card">
          <div class="row">
            <div class="grow">
              <div class="t1">Needs input (with Approve/Reject)</div>
              <div class="t2">Answer agents directly from lock screen</div>
            </div>
            ${sw('notifInput', s.notifInput)}
          </div>
          <div class="row">
            <div class="grow">
              <div class="t1">Rate limit &amp; failover</div>
              <div class="t2">Alert with 1-tap Resume on next account</div>
            </div>
            ${sw('notifLimit', s.notifLimit)}
          </div>
          <div class="row">
            <div class="grow">
              <div class="t1">Command failed</div>
              <div class="t2">Non-zero exits and agent errors</div>
            </div>
            ${sw('notifFailed', s.notifFailed)}
          </div>
          <div class="row">
            <div class="grow">
              <div class="t1">Haptic feedback</div>
              <div class="t2">Tactile confirmation on Approve &amp; Stop</div>
            </div>
            ${sw('haptics', s.haptics)}
          </div>
        </div>

        <div class="sect-label">Appearance</div>
        <div class="card" style="padding:10px 12px">
          <div class="seg">
            <button class="${theme === 'dark' ? 'on' : ''}" data-act="set-theme" data-theme="dark">Dark</button>
            <button class="${theme === 'light' ? 'on' : ''}" data-act="set-theme" data-theme="light">Light</button>
          </div>
        </div>

        <div class="sect-label">App &amp; security</div>
        <div class="card">
          <div class="row">
            <div class="grow">
              <div class="t1">Biometric unlock</div>
              <div class="t2">Require fingerprint before approving</div>
            </div>
            ${sw('biometric', s.biometric)}
          </div>
          <div class="row click" data-act="toast" data-msg="Up to date · v0.1.0 (arm64 APK)">
            <div class="grow">
              <div class="t1">TernaryCode Mobile</div>
              <div class="data">v0.1.0 · GitHub APK self-updater</div>
            </div>
            <span class="go-btn">Check</span>
          </div>
        </div>

        <button class="btn danger block" data-act="go-screen" data-screen="welcome">${ic('signout', 's16')}Unpair this device</button>
      </div>
      ${gesturePill('win')}`;
  }

  // 14 · Android Lock Screen / Notification Shade (Native Quick-Approve)
  function screenAndroidNotif() {
    return `${androidBar({ onDark: true, darkBg: '#0B0B0E' })}
      <div class="android-shade">
        <div class="shade-clock">
          <div class="shade-time">09:41</div>
          <div class="shade-date">Wed, Nov 25 · Pixel 9 Pro</div>
        </div>

        <div class="shade-sec">Conversations &amp; Alerts</div>

        <div class="anotif urgent">
          <div class="anotif-meta">
            <img src="assets/icon.svg" alt="">
            <span>TernaryCode · storefront · 12s</span>
          </div>
          <div class="anotif-title">Claude Code wants to run a command</div>
          <div class="anotif-body">$ npm test -- auth</div>
          <div class="anotif-acts">
            <button class="pri" data-act="notif-approve">Approve</button>
            <button class="rej" data-act="toast" data-msg="Sent Reject (Esc) from notification">Reject</button>
            <button data-act="tab" data-tab="live">Open</button>
          </div>
        </div>

        <div class="anotif">
          <div class="anotif-meta">
            <img src="assets/icon.svg" alt="">
            <span>TernaryCode · api-gateway · 2m</span>
          </div>
          <div class="anotif-title">claude1 hit its 5-hour limit</div>
          <div class="anotif-body">Resets in 14m · claude2 (12%) is ready</div>
          <div class="anotif-acts">
            <button class="pri" data-act="notif-failover">Resume on claude2</button>
            <button data-act="tab" data-tab="live">Open</button>
          </div>
        </div>

        <div class="shade-sec">Silent · Background</div>

        <div class="anotif quiet">
          <div class="anotif-meta">
            <img src="assets/icon.svg" alt="">
            <span>TernaryCode · Connected to MacBook Pro</span>
          </div>
          <div class="anotif-body">192.168.1.5:7890 · 3 agents active · 2 waiting</div>
        </div>

        <div style="margin-top:auto;padding-top:12px">
          <button class="btn raised block sm" style="background:rgba(255,255,255,.08);color:#EDEDF0;border-color:rgba(255,255,255,.12)" data-act="tab" data-tab="live">Back to app</button>
        </div>
      </div>
      ${gesturePill('dark-cam')}`;
  }

  /* ---------------------------------------------------------------- Complete 14-Screen Catalogue */
  const FLOWS = [
    {
      id: 'flow-pair', num: '01', title: 'Onboarding, QR Pairing & Multi-Host',
      desc: 'Fast native camera QR scan, manual LAN/tunnel fallback, Keystore auth, and seamless multi-computer switching.',
      screens: [
        { id: 'welcome', idx: '01', name: 'Welcome & Pair', note: 'First-launch entry: native QR scan CTA, manual host/code fallback, and clear security trust cues.', render: () => screenWelcome() },
        { id: 'qr', idx: '02', name: 'QR Camera Scanner', note: 'Native Android camera reticle with live detected-host pill (IP + code) for instant 1-tap pair.', render: () => screenQr() },
        { id: 'manual', idx: '03', name: 'Manual Pairing & mDNS', note: 'LAN/Cloudflare/Tailscale URL + pairing code with mDNS discovery shortcut and preserved draft on error.', render: () => screenManual({ error: 'Invalid or expired pairing code — check Settings → Phone.' }) },
        { id: 'hosts', idx: '04', name: 'Host Switcher & Offline', note: 'Switch between paired Mac, Linux, and Windows machines (Wi-Fi, Tailscale, Cloudflare) plus clean retry state.', render: st => screenHostsOverlay(st, { offlineBackground: true }) },
      ],
    },
    {
      id: 'flow-live', num: '02', title: 'Live Terminal & Agent Control',
      desc: 'Thumb-first agent supervision: amber attention ring, syntax-colored diffs, quick terminal keys, and 1-tap failover.',
      screens: [
        { id: 'live-ask', idx: '05', name: 'Live · Agent Needs Input', note: 'Amber ring on terminal sheet, warm Notice banner, thumb-sized Approve/Reject/Stop, and quick key strip.', render: st => screenLive(st, 0) },
        { id: 'live-limit', idx: '06', name: 'Live · Rate Limit Failover', note: 'Orange limit Notice with same-provider prioritized Resume button (claude2 12%) and cross-provider handoff.', render: st => screenLive(st, 1, { showQuickKeys: false }) },
        { id: 'live-run', idx: '07', name: 'Live · Running & Switcher', note: 'Streaming Codex output with compact Switch account chips, quick keys (Esc/^C/Tab/arrows), and composer.', render: st => screenLive(st, 2, { showSwaps: true }) },
        { id: 'fullscreen', idx: '08', name: 'Fullscreen Terminal', note: 'Distraction-free output reader with A−/A+ monospace zoom, line wrap toggle, scrollback pill, and copy.', render: st => screenFullscreen(st, 0) },
      ],
    },
    {
      id: 'flow-inbox', num: '03', title: 'Inbox, Projects & Sessions',
      desc: 'Cross-project triage oldest-first, full context before approving, and 1-tap session resume across worktrees.',
      screens: [
        { id: 'inbox', idx: '09', name: 'Inbox · Attention Queue', note: 'Segmented All / Needs you / Finished list with inline quick Approve/Reject and Resume failover actions.', render: st => screenInbox(st) },
        { id: 'inbox-detail', idx: '10', name: 'Inbox · Item Detail', note: 'Full command box, hook provenance, primary Approve/Reject/Open Live buttons, and live terminal tail.', render: st => screenInboxDetail(st, 1) },
        { id: 'projects', idx: '11', name: 'Projects & Worktrees', note: 'Filterable project groups with Slate letter avatars, git branches, worktrees, Live tags, and Resume buttons.', render: st => screenProjects(st) },
      ],
    },
    {
      id: 'flow-ops', num: '04', title: 'Accounts, Settings & Android OS',
      desc: 'Multi-account 5h/weekly quota tracking, Android foreground service controls, APK self-updater, and lock-screen actions.',
      screens: [
        { id: 'accounts', idx: '12', name: 'Accounts & Quotas', note: 'Failover summary strip, Automatic/Ask policy, and ranked 5h + weekly meters with exact reset countdowns.', render: st => screenAccounts(st) },
        { id: 'settings', idx: '13', name: 'Settings & APK Updates', note: 'Foreground keep-alive, per-event notification toggles, biometric lock, Dark/Light switch, and APK updater.', render: st => screenSettings(st) },
        { id: 'android-notif', idx: '14', name: 'Android Lock Screen Actions', note: 'Native Android notification shade: Approve, Reject, or Resume on claude2 without even opening the app.', render: () => screenAndroidNotif() },
      ],
    },
  ];

  return {
    FLOWS,
    createInitialState,
    screens: {
      welcome: screenWelcome,
      qr: screenQr,
      manual: screenManual,
      hosts: screenHostsOverlay,
      live: screenLive,
      fullscreen: screenFullscreen,
      inbox: screenInbox,
      'inbox-detail': screenInboxDetail,
      projects: screenProjects,
      accounts: screenAccounts,
      settings: screenSettings,
      'android-notif': screenAndroidNotif,
    },
  };
})();
