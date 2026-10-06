/* Convex stores rooms/SDP. Encrypted WebRTC carries host-authoritative matches. */
(() => {
  const events = [], peers = new Map();
  let client, room, role = '', slot = 0, token = '', unsubscribe, generation = 0, running = false, lastMatch = null;
  const panel = document.getElementById('online-lobby'), note = document.getElementById('online-status');
  const roomLabel = document.getElementById('room-code'), start = document.getElementById('online-start');
  const setup = document.getElementById('online-setup'), api = convex.anyApi.rooms;
  document.getElementById('stage').appendChild(panel);
  const emit = value => { if (events.length < 512) events.push(value); };
  const message = text => { note.textContent = text; };
  function backend() {
    if (!window.HOPKEY_CONVEX_URL) throw new Error('Online rooms are unavailable in this build.');
    return client ||= new convex.ConvexClient(window.HOPKEY_CONVEX_URL);
  }
  const count = () => [...peers.values()].filter(p => p.channel?.readyState === 'open').length;
  function refresh() {
    start.hidden = role !== 'host' || running; start.disabled = count() === 0;
    if (role === 'host') message(`${count() + 1} / 4 typists connected. Share the room code with your friends.`);
    else if (count()) message(`Connected as P${slot + 1}. Waiting for the host to start…`);
  }
  function connection(id, current) {
    const pc = new RTCPeerConnection({ iceServers: [{ urls: 'stun:stun.cloudflare.com:3478' }] });
    const peer = { pc, channel: null, timer: null, connected: false, sent: 0, received: 0 };
    peers.set(id, peer);
    peer.timer = setTimeout(() => {
      if (generation !== current || peer.connected) return;
      pc.close();
      if (role === 'guest') close(false);
      message('Could not connect. Try another network or disable your VPN, then create/join a new room.');
    }, 25000);
    pc.onconnectionstatechange = () => {
      if (generation !== current) return;
      if (['failed', 'closed'].includes(pc.connectionState)) lost(id);
      if (pc.connectionState === 'disconnected') {
        clearTimeout(peer.timer);
        peer.timer = setTimeout(() => { if (pc.connectionState === 'disconnected') lost(id); }, 6000);
      }
    };
    return peer;
  }
  function bind(id, channel, current) {
    const peer = peers.get(id); peer.channel = channel;
    channel.onopen = () => {
      if (generation !== current) return;
      clearTimeout(peer.timer); peer.connected = true;
      emit({ kind: 'peer_joined', peer: id }); refresh();
    };
    channel.onclose = () => { if (generation === current) lost(id); };
    channel.onmessage = event => {
      if (generation !== current || typeof event.data !== 'string' || event.data.length > 131072) return;
      try {
        const packet = JSON.parse(event.data);
        if (!packet || typeof packet !== 'object' || Array.isArray(packet)) return;
        if (role === 'guest' && id === 0 && packet.type === 'snapshot') lastMatch = packet.data;
        peer.received++; emit({ kind: 'packet', peer: id, packet });
      } catch { /* Invalid packets never enter gameplay. */ }
    };
  }
  function lost(id) {
    const peer = peers.get(id); if (!peer) return;
    peers.delete(id); clearTimeout(peer.timer); peer.pc.close();
    if (peer.connected) emit({ kind: 'peer_left', peer: id });
    if (role === 'guest') { close(false); panel.hidden = false; message('The host disconnected. Close this panel and create or join a new room.'); }
    else refresh();
  }
  async function gathered(pc) {
    if (pc.iceGatheringState === 'complete') return;
    await new Promise(resolve => {
      const done = () => { clearTimeout(timer); pc.removeEventListener('icegatheringstatechange', change); resolve(); };
      const change = () => { if (pc.iceGatheringState === 'complete') done(); };
      const timer = setTimeout(done, 8000); pc.addEventListener('icegatheringstatechange', change);
    });
  }
  function watch(current) {
    unsubscribe = backend().onUpdate(api.watch, { id: room.id, token }, async state => {
      if (generation !== current) return;
      if (!state) { close(false); panel.hidden = false; message('The room has closed. Create or join a new room.'); return; }
      if (role === 'host') {
        for (const id of peers.keys()) if (!state.peers.some(p => p.slot === id)) lost(id);
        for (const entry of state.peers) {
          if (peers.has(entry.slot)) continue;
          const peer = connection(entry.slot, current);
          peer.pc.ondatachannel = event => bind(entry.slot, event.channel, current);
          try {
            await peer.pc.setRemoteDescription({ type: 'offer', sdp: entry.offer });
            await peer.pc.setLocalDescription(await peer.pc.createAnswer()); await gathered(peer.pc);
            if (generation === current) await backend().mutation(api.answer, { id: room.id, token, slot: entry.slot, answer: peer.pc.localDescription.sdp });
          } catch (error) { if (generation === current) { lost(entry.slot); message(error.message); } }
        }
      } else {
        const answer = state.peers[0]?.answer, peer = peers.get(0);
        if (answer && peer && !peer.pc.remoteDescription) {
          try { await peer.pc.setRemoteDescription({ type: 'answer', sdp: answer }); }
          catch (error) { message(error.message); }
        }
      }
    }, error => { message(error.message); });
  }
  function close(hide = true) {
    const previous = room, credential = token;
    generation++; unsubscribe?.(); unsubscribe = null;
    for (const peer of peers.values()) { clearTimeout(peer.timer); peer.pc.close(); }
    peers.clear(); room = null; role = ''; running = false; lastMatch = null;
    if (previous && client) client.mutation(api.leave, { id: previous.id, token: credential }).catch(() => {});
    setup.hidden = false; start.hidden = true; roomLabel.textContent = '';
    if (hide) panel.hidden = true;
    emit({ kind: 'closed' });
  }
  async function hostRoom() {
    close(false); events.length = 0; const current = generation;
    token = crypto.randomUUID(); role = 'host'; message('Creating your room…'); setup.hidden = true;
    try {
      const result = await backend().mutation(api.create, { token });
      if (generation !== current) return;
      room = result; slot = 0; roomLabel.textContent = result.code;
      emit({ kind: 'hosted', slot: 0 }); watch(current); refresh();
    } catch (error) { role = ''; setup.hidden = false; message(error.message); }
  }
  async function joinRoom() {
    const code = document.getElementById('join-code').value.trim().toUpperCase();
    if (!/^[A-Z2-9]{6}$/.test(code)) { message('Enter the six-character room code.'); return; }
    close(false); events.length = 0; const current = generation;
    token = crypto.randomUUID(); role = 'guest'; message('Connecting to your friends…'); setup.hidden = true;
    try {
      const peer = connection(0, current);
      bind(0, peer.pc.createDataChannel('match', { ordered: true }), current);
      await peer.pc.setLocalDescription(await peer.pc.createOffer()); await gathered(peer.pc);
      if (generation !== current) return;
      const result = await backend().mutation(api.join, { code, token, offer: peer.pc.localDescription.sdp });
      if (generation !== current) return;
      room = result; slot = result.slot; roomLabel.textContent = code;
      emit({ kind: 'joined', slot }); watch(current);
    } catch (error) { close(false); message(error.message); }
  }
  document.getElementById('online-host').onclick = hostRoom;
  document.getElementById('online-join').onclick = joinRoom;
  document.getElementById('online-close').onclick = () => { close(); document.getElementById('canvas').focus(); };
  start.onclick = async () => {
    if (role !== 'host' || count() < 1) return;
    start.disabled = true;
    try {
      await backend().mutation(api.lock, { id: room.id, token });
      running = true; emit({ kind: 'start' }); panel.hidden = true; document.getElementById('canvas').focus();
    } catch (error) { message(error.message); refresh(); }
  };
  window.HOPKEY_NET = {
    openLobby() { panel.hidden = false; if (!room) message('One player hosts. Friends join with the code. Each PC controls one typist.'); },
    hideLobby() { running = true; panel.hidden = true; document.getElementById('canvas').focus(); },
    close,
    drain() { return JSON.stringify(events.splice(0)); },
    send(value, target = -1) {
      if (typeof value !== 'string' || value.length > 131072) return;
      const packet = JSON.parse(value);
      if (role === 'host' && packet.type === 'snapshot') lastMatch = packet.data;
      const replaceable = packet.type === 'snapshot' || packet.type === 'input';
      for (const [id, peer] of peers) {
        if (target >= 0 && id !== target) continue;
        if (peer.channel?.readyState !== 'open') continue;
        if (peer.channel.bufferedAmount > 1048576) { lost(id); continue; }
        // Snapshot/input can be superseded. Start/results stay reliably queued.
        if (!replaceable || peer.channel.bufferedAmount < 262144) { peer.channel.send(value); peer.sent++; }
      }
    },
    // Verification diagnostics omit private tokens and SDP.
    status() { return { role, slot, code: room?.code, running, peers: [...peers].map(([id, p]) => ({ id, state: p.pc.connectionState, sent: p.sent, received: p.received })), match: lastMatch ? { state: lastMatch.state, round: lastMatch.round, time: lastMatch.time, typed: lastMatch.current, players: lastMatch.players.map(p => ({ id: p.id, pos: p.pos, height: p.height, connected: p.connected })) } : null }; },
  };
  window.addEventListener('pagehide', () => close());
})();
