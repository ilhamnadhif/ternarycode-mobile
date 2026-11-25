/* TernaryCode Mobile Design Studio — Canvas Board & Interactive Android Prototype Controller */
(() => {
  const { FLOWS, createInitialState, screens } = window.TC;

  let mode = 'board'; // 'board' | 'proto'
  let theme = 'dark';
  let specOpen = false;

  // Interactive prototype live state
  let state = createInitialState();
  let route = 'live'; // 'welcome'|'qr'|'manual'|'live'|'fullscreen'|'inbox'|'inbox-detail'|'projects'|'accounts'|'settings'|'android-notif'
  let overlay = null; // null | 'hosts'
  let detailPaneId = 1;
  let manualErr = '';
  let toastText = '';
  let toastTimer = null;

  const $ = (s, r = document) => r.querySelector(s);
  const root = $('#studio-root');
  const specHost = $('#spec-host');

  function setTheme(t) {
    theme = t;
    document.documentElement.dataset.theme = t;
    $('#theme-label').textContent = t === 'dark' ? 'Dark' : 'Light';
    render();
  }

  function showToast(msg) {
    toastText = msg;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toastText = '';
      if (mode === 'proto') renderProtoPhone();
    }, 2600);
    if (mode === 'proto') renderProtoPhone();
  }

  function renderSpecDrawer() {
    if (!specOpen) { specHost.innerHTML = ''; return; }
    const dark = theme === 'dark';
    const surfaces = [
      ['bg/window', dark ? '#09090B' : '#EDEDEF'],
      ['bg/sheet', dark ? '#111113' : '#FBFBFC'],
      ['bg/raised', dark ? '#1A1A1D' : '#FFFFFF'],
      ['bg/inset', dark ? '#0C0C0E' : '#E9E9EC'],
      ['accent', dark ? '#2E6BE6' : '#1F5FBF'],
      ['status/input', dark ? '#F2B14B' : '#B26A00'],
      ['status/running', dark ? '#6AA5FF' : '#2563C9'],
      ['status/done', dark ? '#4DC48C' : '#15804E'],
      ['status/failed', dark ? '#F06A64' : '#C7352D'],
      ['status/limited', dark ? '#F29441' : '#C2560A'],
    ];
    specHost.innerHTML = `<div class="spec-drawer"><div class="spec-panel">
      <div class="spec-col">
        <h4>Slate Tokens (${dark ? 'Dark' : 'Light'})</h4>
        <div class="swatch-grid">
          ${surfaces.map(([k, hex]) => `<div class="swatch"><i style="background:${hex}"></i><span>${k}</span></div>`).join('')}
        </div>
      </div>
      <div class="spec-col">
        <h4>Desktop Companion API Contract</h4>
        <div class="api-list">
          <code><span class="api-m post">POST</span> /api/pair → {device_id, device_token}</code>
          <code><span class="api-m get">GET</span> /api/state → CompanionSnapshot</code>
          <code><span class="api-m ws">SSE</span> /api/events?token=… (live + 15s keepalive)</code>
          <code><span class="api-m post">POST</span> /api/pane/:id/input {action|text,enter}</code>
          <code><span class="api-m post">POST</span> /api/pane/:id/switch-profile {profile_id}</code>
          <code><span class="api-m post">POST</span> /api/session/resume {project_id,agent,…}</code>
        </div>
      </div>
      <div class="spec-col">
        <h4>Flutter Android Architecture</h4>
        <div class="api-list">
          <code>Renderer: Impeller (Vulkan / OpenGLES)</code>
          <code>Auth: flutter_secure_storage (Android Keystore)</code>
          <code>QR: mobile_scanner + mDNS (nsd) LAN discovery</code>
          <code>Background: ForegroundService + Action Notifs</code>
          <code>Distribution: Signed arm64-v8a APK · Self-updater</code>
          <code>Fonts: Inter + JetBrains Mono (bundled)</code>
        </div>
      </div>
    </div></div>`;
  }

  function renderBoard() {
    const staticState = createInitialState();
    root.innerHTML = `<div class="board">
      <div class="board-intro">
        <div>
          <h1>TernaryCode Mobile — Complete UI Design</h1>
          <p>14 Android screens designed with TernaryCode’s <b>Slate</b> design language (neutral surfaces, 1 px hairlines, one blue accent, colour + shape status glyphs). Click <b>Try live</b> on any screen to interact with the working prototype.</p>
        </div>
        <div class="board-meta">
          <span>390 × 844 · Android</span>
          <span>14 Screens · 4 Flows</span>
          <span>Slate Dark &amp; Light</span>
          <span>Flutter + Impeller</span>
        </div>
      </div>
      ${FLOWS.map(flow => `
        <section class="flow-sec" id="${flow.id}">
          <div class="flow-head">
            <div class="flow-title">
              <span class="flow-num">${flow.num}</span>
              <h2>${flow.title}</h2>
            </div>
            <p class="flow-desc">${flow.desc}</p>
          </div>
          <div class="screen-grid">
            ${flow.screens.map(sc => `
              <article class="artboard">
                <div class="artboard-head">
                  <div class="artboard-label">
                    <span class="artboard-idx">${sc.idx}</span>
                    <span class="artboard-name">${sc.name}</span>
                  </div>
                  <button class="artboard-try" data-open-proto="${sc.id}">Try live →</button>
                </div>
                <div class="phone" data-board-screen="${sc.id}">${sc.render(staticState)}</div>
                <p class="artboard-note">${sc.note}</p>
              </article>`).join('')}
          </div>
        </section>`).join('')}
    </div>`;
  }

  function renderProtoContent() {
    if (overlay === 'hosts') return screens.hosts(state, { offlineBackground: false });
    if (route === 'welcome') return screens.welcome();
    if (route === 'qr') return screens.qr();
    if (route === 'manual') return screens.manual({ error: manualErr });
    if (route === 'fullscreen') {
      const idx = Math.max(0, state.panes.findIndex(p => p.id === state.selectedPane));
      return screens.fullscreen(state, idx);
    }
    if (route === 'inbox') return screens.inbox(state);
    if (route === 'inbox-detail') return screens['inbox-detail'](state, detailPaneId);
    if (route === 'projects') return screens.projects(state);
    if (route === 'accounts') return screens.accounts(state);
    if (route === 'settings') return screens.settings(state);
    if (route === 'android-notif') return screens['android-notif']();
    return screens.live(state);
  }

  function renderProtoPhone() {
    const phone = $('#proto-phone');
    if (!phone) return;
    phone.innerHTML = renderProtoContent() + (toastText ? `<div class="m-toast"><span class="dot ok"></span><span>${toastText}</span></div>` : '');
    // Update jump list highlight
    document.querySelectorAll('.proto-jump').forEach(b => {
      const target = b.dataset.protoJump;
      const on = (overlay === 'hosts' && target === 'hosts') || (!overlay && target === route);
      b.classList.toggle('on', on);
    });
  }

  function renderProtoStage() {
    const jumps = [
      ['live', '05', 'Live Terminal'],
      ['inbox', '09', 'Inbox Queue'],
      ['inbox-detail', '10', 'Inbox Detail'],
      ['projects', '11', 'Projects & Sessions'],
      ['accounts', '12', 'Accounts & Quotas'],
      ['fullscreen', '08', 'Fullscreen Terminal'],
      ['settings', '13', 'Settings & Updates'],
      ['hosts', '04', 'Host Switcher Sheet'],
      ['welcome', '01', 'Welcome / Pair'],
      ['qr', '02', 'QR Camera Scanner'],
      ['manual', '03', 'Manual Pairing'],
      ['android-notif', '14', 'Android Lock Screen'],
    ];

    root.innerHTML = `<div class="proto-stage">
      <aside class="proto-side">
        <div class="proto-card">
          <h3>Screens</h3>
          <div class="proto-list">
            ${jumps.map(([id, num, lbl]) => `
              <button class="proto-jump" data-proto-jump="${id}">
                <span class="num">${num}</span><span>${lbl}</span>
              </button>`).join('')}
          </div>
        </div>
      </aside>

      <div class="phone interactive" id="proto-phone"></div>

      <aside class="proto-side">
        <div class="proto-card">
          <h3>Try Live Flows</h3>
          <p class="proto-hint">Tap <b>Approve</b> on <b>storefront</b> and watch Claude Code run tests and finish in real time.</p>
          <p class="proto-hint">Switch to <b>api-gateway</b> and tap <b>Resume claude2</b> to test 1-tap rate-limit failover.</p>
          <p class="proto-hint">Type a prompt in the composer or tap <b>^C Stop</b>, <b>Esc</b>, or the <b>expand</b> button.</p>
        </div>
        <div class="proto-card">
          <h3>Simulate Events</h3>
          <div class="sim-btns">
            <button class="sim-btn" id="sim-reset">Reset demo state</button>
            <button class="sim-btn" id="sim-ask">Trigger approval ask</button>
            <button class="sim-btn" id="sim-limit">Trigger rate limit</button>
            <button class="sim-btn" id="sim-shade">Open lock screen</button>
          </div>
        </div>
      </aside>
    </div>`;

    renderProtoPhone();
  }

  function openInProto(screenId) {
    mode = 'proto';
    overlay = null;
    manualErr = '';
    if (screenId === 'hosts') { route = 'live'; overlay = 'hosts'; }
    else if (screenId === 'live-ask') { route = 'live'; state.selectedPane = 1; }
    else if (screenId === 'live-limit') { route = 'live'; state.selectedPane = 2; }
    else if (screenId === 'live-run') { route = 'live'; state.selectedPane = 3; }
    else if (screenId === 'inbox-detail') { route = 'inbox-detail'; detailPaneId = 1; }
    else { route = screenId; }
    syncModeButtons();
    render();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function handleQuickAction(paneId, kind) {
    const pane = state.panes.find(p => p.id === paneId);
    if (!pane) return;
    if (kind === 'approve') {
      pane.status = 'running';
      pane.statusLabel = 'Running';
      pane.htmlOut += `\n<span class="d">  ⎿  Approved from Android · running…</span>`;
      showToast(`Approved ${pane.project} · ${pane.label}`);
      if (route === 'inbox-detail') route = 'live';
      state.selectedPane = pane.id;
      renderProtoPhone();
      setTimeout(() => {
        if (pane.status !== 'running') return;
        pane.status = 'done';
        pane.statusLabel = 'Done';
        pane.htmlOut += `\n<span class="g">  ⎿  Tests: 9 passed, 9 total</span>\n<span class="a">⏺ </span>Fixed. All 9 auth tests pass.\n<span class="d">&gt; </span><span class="cur"></span>`;
        if (mode === 'proto') {
          showToast(`${pane.project} finished · 9 tests passed`);
          renderProtoPhone();
        }
      }, 1400);
    } else if (kind === 'reject') {
      pane.status = 'idle';
      pane.statusLabel = 'Idle';
      pane.htmlOut += `\n<span class="r">  ⎿  Rejected (Esc sent from phone)</span>\n<span class="d">&gt; </span><span class="cur"></span>`;
      showToast(`Rejected command in ${pane.project}`);
      if (route === 'inbox-detail') route = 'inbox';
      renderProtoPhone();
    } else if (kind === 'interrupt') {
      pane.status = 'idle';
      pane.statusLabel = 'Idle';
      pane.htmlOut += `\n<span class="y">^C Interrupted</span>\n<span class="d">&gt; </span><span class="cur"></span>`;
      showToast(`Sent Ctrl+C to ${pane.project}`);
      renderProtoPhone();
    }
  }

  function handleFailover(paneId, profileId) {
    const pane = state.panes.find(p => p.id === paneId);
    if (!pane) return;
    pane.rateLimit = null;
    pane.profile = profileId;
    pane.status = 'running';
    pane.statusLabel = 'Running';
    pane.htmlOut += `\n<span class="b">⇄ Switched to ${profileId} · resuming session…</span>`;
    state.selectedPane = pane.id;
    route = 'live';
    showToast(`Resuming ${pane.project} on ${profileId}`);
    renderProtoPhone();
  }

  function syncModeButtons() {
    $('#mode-board').classList.toggle('on', mode === 'board');
    $('#mode-proto').classList.toggle('on', mode === 'proto');
    $('#studio-jumps').style.display = mode === 'board' ? 'flex' : 'none';
  }

  function render() {
    renderSpecDrawer();
    if (mode === 'board') renderBoard();
    else renderProtoStage();
  }

  /* ---------------------------------------------------------------- Delegated Studio + Prototype Events */
  document.addEventListener('click', ev => {
    const openBtn = ev.target.closest('[data-open-proto]');
    if (openBtn) { openInProto(openBtn.dataset.openProto); return; }

    const jumpBtn = ev.target.closest('[data-proto-jump]');
    if (jumpBtn) {
      const target = jumpBtn.dataset.protoJump;
      overlay = target === 'hosts' ? 'hosts' : null;
      if (target !== 'hosts') route = target;
      renderProtoPhone();
      return;
    }

    if (ev.target.id === 'sim-reset') { state = createInitialState(); route = 'live'; overlay = null; showToast('Demo state reset'); renderProtoPhone(); return; }
    if (ev.target.id === 'sim-ask') {
      const p = state.panes[0];
      p.status = 'needs_input'; p.statusLabel = 'Needs input';
      state.selectedPane = 1; route = 'live'; overlay = null;
      showToast('storefront: Claude Code needs approval');
      renderProtoPhone(); return;
    }
    if (ev.target.id === 'sim-limit') {
      const p = state.panes[1];
      p.status = 'rate_limited'; p.statusLabel = 'Rate limited';
      p.rateLimit = { fromProfile: 'claude1', resetsIn: '14m', reason: '5-hour limit reached on claude1 (MAX).' };
      state.selectedPane = 2; route = 'live'; overlay = null;
      showToast('api-gateway: claude1 hit 5h limit');
      renderProtoPhone(); return;
    }
    if (ev.target.id === 'sim-shade') { overlay = null; route = 'android-notif'; renderProtoPhone(); return; }

    // Inside board mode: clicking a phone opens it in prototype mode
    const boardPhone = mode === 'board' && ev.target.closest('[data-board-screen]');
    if (boardPhone) { openInProto(boardPhone.dataset.boardScreen); return; }

    if (mode !== 'proto') return;
    const actEl = ev.target.closest('[data-act]');
    if (!actEl) return;
    const act = actEl.dataset.act;

    if (act === 'tab') { overlay = null; route = actEl.dataset.tab; renderProtoPhone(); }
    else if (act === 'go-screen') { overlay = null; route = actEl.dataset.screen; renderProtoPhone(); }
    else if (act === 'open-hosts') { overlay = 'hosts'; renderProtoPhone(); }
    else if (act === 'close-overlay') { overlay = null; renderProtoPhone(); }
    else if (act === 'open-settings') { overlay = null; route = 'settings'; renderProtoPhone(); }
    else if (act === 'close-settings') { route = 'live'; renderProtoPhone(); }
    else if (act === 'open-fullscreen') { route = 'fullscreen'; renderProtoPhone(); }
    else if (act === 'close-fullscreen') { route = 'live'; renderProtoPhone(); }
    else if (act === 'select-pane') { state.selectedPane = Number(actEl.dataset.pane); renderProtoPhone(); }
    else if (act === 'focus-pane') { state.selectedPane = Number(actEl.dataset.pane); route = 'live'; overlay = null; renderProtoPhone(); }
    else if (act === 'open-inbox-detail') { detailPaneId = Number(actEl.dataset.pane); route = 'inbox-detail'; renderProtoPhone(); }
    else if (act === 'inbox-filter') { state.inboxFilter = actEl.dataset.filter; renderProtoPhone(); }
    else if (act === 'quick') { handleQuickAction(Number(actEl.dataset.pane), actEl.dataset.kind); }
    else if (act === 'failover') { handleFailover(Number(actEl.dataset.pane), actEl.dataset.profile); }
    else if (act === 'notif-approve') { handleQuickAction(1, 'approve'); route = 'live'; renderProtoPhone(); }
    else if (act === 'notif-failover') { handleFailover(2, 'claude2'); route = 'live'; renderProtoPhone(); }
    else if (act === 'complete-pair') { route = 'live'; showToast('Paired with MacBook Pro · Keystore saved'); renderProtoPhone(); }
    else if (act === 'manual-connect') {
      const code = ($('#m-code')?.value || '').trim();
      if (code.length < 4) { manualErr = 'Enter the pairing code shown in Settings → Phone.'; renderProtoPhone(); return; }
      manualErr = ''; route = 'live'; showToast('Connected to host'); renderProtoPhone();
    }
    else if (act === 'select-host') {
      const h = state.hosts.find(x => x.id === actEl.dataset.host);
      if (h) { state.hostId = h.id; overlay = null; showToast(`Switched to ${h.name}`); renderProtoPhone(); }
    }
    else if (act === 'send-prompt') {
      const inp = $('#proto-prompt');
      const txt = (inp?.value || '').trim();
      if (!txt) return;
      const pane = state.panes.find(p => p.id === Number(actEl.dataset.pane));
      if (pane) {
        pane.htmlOut += `\n<span class="p">&gt; ${txt.replace(/</g, '&lt;')}</span>\n<span class="b">◦ Processing…</span>`;
        showToast('Instruction sent');
        renderProtoPhone();
      }
    }
    else if (act === 'send-key') {
      showToast(`Sent ${actEl.dataset.key}`);
    }
    else if (act === 'send-cmd') {
      const pane = state.panes.find(p => p.id === Number(actEl.dataset.pane));
      if (pane) {
        pane.status = 'running'; pane.statusLabel = 'Running';
        pane.htmlOut += `\n<span class="g">❯ ${actEl.dataset.cmd}</span>\n<span class="b">◦ Running…</span>`;
        showToast(`Ran ${actEl.dataset.cmd}`);
        renderProtoPhone();
      }
    }
    else if (act === 'resume-session') {
      route = 'live';
      showToast(`Resuming “${actEl.dataset.title}” in ${actEl.dataset.proj}`);
      renderProtoPhone();
    }
    else if (act === 'toggle-failover') {
      state.failoverMode = state.failoverMode === 'auto' ? 'manual' : 'auto';
      showToast(`Failover: ${state.failoverMode === 'auto' ? 'Automatic' : 'Ask me'}`);
      renderProtoPhone();
    }
    else if (act === 'toggle-setting') {
      const k = actEl.dataset.key;
      state.settings[k] = !state.settings[k];
      renderProtoPhone();
    }
    else if (act === 'set-theme') { setTheme(actEl.dataset.theme); }
    else if (act === 'term-font') {
      state.termFont = Math.max(9, Math.min(15, state.termFont + Number(actEl.dataset.delta)));
      renderProtoPhone();
    }
    else if (act === 'term-wrap') { state.termWrap = !state.termWrap; renderProtoPhone(); }
    else if (act === 'toast') { showToast(actEl.dataset.msg || 'Done'); }
  });

  document.addEventListener('input', ev => {
    if (mode !== 'proto') return;
    if (ev.target && ev.target.id === 'proj-filter') {
      state.projectQuery = ev.target.value;
      const pos = ev.target.selectionStart;
      renderProtoPhone();
      const el = $('#proj-filter');
      if (el) { el.focus(); el.setSelectionRange(pos, pos); }
    }
  });

  document.addEventListener('keydown', ev => {
    if (mode !== 'proto' || ev.key !== 'Enter') return;
    if (ev.target && ev.target.id === 'proto-prompt') {
      const btn = document.querySelector('[data-act="send-prompt"]');
      if (btn) btn.click();
    }
  });

  // Top studio controls
  $('#mode-board').addEventListener('click', () => { mode = 'board'; syncModeButtons(); render(); });
  $('#mode-proto').addEventListener('click', () => { mode = 'proto'; syncModeButtons(); render(); });
  $('#toggle-theme').addEventListener('click', () => setTheme(theme === 'dark' ? 'light' : 'dark'));
  $('#toggle-spec').addEventListener('click', () => {
    specOpen = !specOpen;
    $('#toggle-spec').classList.toggle('on', specOpen);
    renderSpecDrawer();
  });

  syncModeButtons();
  render();
})();
