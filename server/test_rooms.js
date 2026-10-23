'use strict';

const assert = require('assert');
const WebSocket = require('ws');

const URL = process.env.TEST_WS || 'ws://127.0.0.1:3000/ws';

function client(name) {
  const ws = new WebSocket(URL);
  const inbox = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    inbox.push(msg);
    for (const w of waiters.splice(0)) {
      if (w.pred(msg)) {
        w.resolve(msg);
        return;
      }
      waiters.push(w);
    }
  });
  const opened = new Promise((resolve, reject) => {
    ws.on('open', resolve);
    ws.on('error', reject);
  });
  function wait(pred, timeout = 3000) {
    const found = inbox.find(pred);
    if (found) return Promise.resolve(found);
    return new Promise((resolve, reject) => {
      const w = { pred, resolve };
      waiters.push(w);
      setTimeout(() => {
        const i = waiters.indexOf(w);
        if (i >= 0) waiters.splice(i, 1);
        reject(new Error(`timeout waiting for ${name}`));
      }, timeout);
    });
  }
  function send(obj) {
    ws.send(JSON.stringify(obj));
  }
  return { name, ws, opened, wait, send, inbox };
}

async function main() {
  const host = client('host');
  const guest = client('guest');
  await Promise.all([host.opened, guest.opened]);
  await host.wait((m) => m.type === 'hello');

  host.send({ type: 'create', name: 'HOST', color: 'yellow' });
  const welcome = await host.wait((m) => m.type === 'welcome');
  assert.match(welcome.room, /^[A-Z0-9]{4}$/);

  guest.send({ type: 'join', room: welcome.room, name: 'GUEST', color: 'blue' });
  const joined = await guest.wait((m) => m.type === 'welcome');
  assert.strictEqual(joined.hostId, welcome.playerId);

  const room = await host.wait((m) => m.type === 'room' && m.room.players.length === 2);
  assert.strictEqual(room.room.hostId, welcome.playerId);

  host.send({ type: 'lobby', data: { mode: 'ghost', pac_count: 1 } });
  const settings = await guest.wait((m) => m.type === 'room' && m.room.settings.mode === 'ghost');
  assert.strictEqual(settings.room.settings.pac_count, 1);

  host.send({ type: 'color', color: 'green' });
  const colorRoom = await guest.wait((m) => m.type === 'room' && m.room.players.some((p) => p.color === 'green'));
  assert.ok(colorRoom);

  const roster = [
    { id: welcome.playerId, name: 'HOST', color: 'yellow', role: 'pac', pac_index: 0, ai: false, connected: true },
    { id: joined.playerId, name: 'GUEST', role: 'ghost', ghost_name: 'blinky', ai: false, connected: true },
  ];
  host.send({ type: 'start', data: { mode: 'ghost', pac_count: 1, roster, seed: 1 } });
  const start = await guest.wait((m) => m.type === 'start');
  assert.strictEqual(start.data.mode, 'ghost');
  assert.strictEqual(start.data.roster.length, 2);

  guest.send({ type: 'input', data: { dir: 'left' } });
  const input = await host.wait((m) => m.type === 'input');
  assert.strictEqual(input.playerId, joined.playerId);
  assert.strictEqual(input.data.dir, 'left');

  host.send({ type: 'snapshot', data: { s: 'playing', sc: 10 } });
  const snap = await guest.wait((m) => m.type === 'snapshot');
  assert.strictEqual(snap.data.sc, 10);

  host.send({ type: 'lobby_return' });
  await guest.wait((m) => m.type === 'lobby_return');

  guest.send({ type: 'leave' });
  const room2 = await host.wait((m) => m.type === 'room' && m.room.players.length === 1);
  assert.strictEqual(room2.room.players.length, 1);

  host.send({ type: 'leave' });
  host.ws.close();
  guest.ws.close();
  console.log('SERVER TEST: ALL OK');
}

main().catch((err) => {
  console.error('SERVER TEST FAILED:', err);
  process.exitCode = 1;
});
