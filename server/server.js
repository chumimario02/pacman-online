'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = Number(process.env.PORT || 3000);
const PUBLIC_DIR = path.join(__dirname, 'public');
const MAX_PLAYERS = 4;
const COLORS = new Set(['yellow', 'blue', 'green', 'pink']);
const COLOR_ORDER = ['yellow', 'blue', 'green', 'pink'];
const GHOSTS = new Set(['blinky', 'pinky', 'inky', 'clyde']);
const GHOST_ORDER = ['blinky', 'pinky', 'inky', 'clyde'];

const rooms = new Map();

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.mp3': 'audio/mpeg',
};

function now() {
  return Date.now();
}

function makeId(prefix) {
  return prefix + crypto.randomBytes(5).toString('hex');
}

function makeCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  for (let attempt = 0; attempt < 100; attempt++) {
    let code = '';
    for (let i = 0; i < 4; i++) {
      code += alphabet[crypto.randomInt(0, alphabet.length)];
    }
    if (!rooms.has(code)) return code;
  }
  return String(Date.now()).slice(-4);
}

function cleanName(value) {
  return String(value || 'JUGADOR')
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .trim()
    .slice(0, 16) || 'JUGADOR';
}

function cleanColor(value) {
  return COLORS.has(value) ? value : 'yellow';
}

function cleanRole(value) {
  return value === 'ghost' ? 'ghost' : 'pac';
}

function cleanGhostName(value) {
  return GHOSTS.has(value) ? value : 'blinky';
}

function pacColorTaken(room, color, exceptId = null) {
  for (const p of room.players.values()) {
    if (p.id !== exceptId && p.role === 'pac' && p.color === color) return true;
  }
  return false;
}

function ghostNameTaken(room, ghostName, exceptId = null) {
  for (const p of room.players.values()) {
    if (p.id !== exceptId && p.role === 'ghost' && p.ghost_name === ghostName) return true;
  }
  return false;
}

function firstFreePacColor(room, requested, exceptId = null) {
  const wanted = cleanColor(requested);
  if (!pacColorTaken(room, wanted, exceptId)) return wanted;
  for (const color of COLOR_ORDER) {
    if (!pacColorTaken(room, color, exceptId)) return color;
  }
  return wanted;
}

function firstFreeGhostName(room, requested, exceptId = null) {
  const wanted = cleanGhostName(requested);
  if (!ghostNameTaken(room, wanted, exceptId)) return wanted;
  for (const ghost of GHOST_ORDER) {
    if (!ghostNameTaken(room, ghost, exceptId)) return ghost;
  }
  return wanted;
}

function send(ws, payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function publicPlayer(player) {
  return {
    id: player.id,
    name: player.name,
    color: player.color,
    role: player.role,
    ghost_name: player.ghost_name || '',
    joinedAt: player.joinedAt,
  };
}

function publicRoom(room) {
  return {
    code: room.code,
    hostId: room.hostId,
    players: Array.from(room.players.values()).map(publicPlayer),
    settings: room.settings,
    started: room.started,
    createdAt: room.createdAt,
  };
}

function broadcast(room, payload, exceptId = null) {
  for (const player of room.players.values()) {
    if (exceptId && player.id === exceptId) continue;
    send(player.ws, payload);
  }
}

function broadcastRoom(room) {
  const message = { type: 'room', room: publicRoom(room) };
  broadcast(room, message);
}

function leaveRoom(ws, reason = 'left') {
  const meta = ws.meta;
  if (!meta || !meta.room) return;
  const room = rooms.get(meta.room);
  ws.meta.room = null;
  if (!room) return;

  const leaving = room.players.get(meta.id);
  room.players.delete(meta.id);
  if (room.players.size === 0) {
    rooms.delete(room.code);
    return;
  }

  if (room.hostId === meta.id) {
    if (room.started) {
      broadcast(room, { type: 'room_closed', reason: 'host_left' });
      for (const player of room.players.values()) {
        try { player.ws.close(4000, 'host left'); } catch (_) {}
      }
      rooms.delete(room.code);
      return;
    }
    const next = room.players.values().next().value;
    room.hostId = next.id;
    room.started = false;
    broadcast(room, { type: 'host_changed', hostId: room.hostId });
  }

  broadcastRoom(room);
  if (leaving) {
    broadcast(room, { type: 'peer_left', playerId: leaving.id, reason });
  }
}

function createRoom(ws, msg) {
  leaveRoom(ws, 'switch');
  const code = makeCode();
  const role = cleanRole(msg.role);
  const player = {
    id: makeId('p_'),
    name: cleanName(msg.name),
    color: cleanColor(msg.color),
    role,
    ghost_name: role === 'ghost' ? cleanGhostName(msg.ghost_name) : '',
    ws,
    joinedAt: now(),
  };
  const room = {
    code,
    hostId: player.id,
    players: new Map([[player.id, player]]),
    settings: { bots: 2, mode: 'classic' },
    started: false,
    createdAt: now(),
  };
  rooms.set(code, room);
  ws.meta.room = code;
  ws.meta.id = player.id;
  send(ws, {
    type: 'welcome',
    playerId: player.id,
    hostId: room.hostId,
    room: room.code,
    roomState: publicRoom(room),
  });
  broadcastRoom(room);
  console.log(`[room ${code}] created by ${player.name} (${player.id})`);
}

function joinRoom(ws, msg) {
  const code = String(msg.room || '').toUpperCase().trim();
  const room = rooms.get(code);
  if (!room) {
    send(ws, { type: 'error', message: 'Esa sala no existe.' });
    return;
  }
  if (room.started) {
    send(ws, { type: 'error', message: 'La partida ya empezo.' });
    return;
  }
  if (room.players.size >= MAX_PLAYERS) {
    send(ws, { type: 'error', message: 'La sala esta llena (4 jugadores).' });
    return;
  }
  leaveRoom(ws, 'switch');
  const role = cleanRole(msg.role);
  const player = {
    id: makeId('p_'),
    name: cleanName(msg.name),
    color: cleanColor(msg.color),
    role,
    ghost_name: '',
    ws,
    joinedAt: now(),
  };
  if (role === 'ghost') {
    player.ghost_name = firstFreeGhostName(room, msg.ghost_name);
  } else {
    player.color = firstFreePacColor(room, msg.color);
  }
  room.players.set(player.id, player);
  ws.meta.room = code;
  ws.meta.id = player.id;
  send(ws, {
    type: 'welcome',
    playerId: player.id,
    hostId: room.hostId,
    room: room.code,
    roomState: publicRoom(room),
  });
  broadcastRoom(room);
  console.log(`[room ${code}] ${player.name} joined (${player.id})`);
}

function handleMessage(ws, raw) {
  let msg;
  try {
    msg = JSON.parse(raw.toString());
  } catch (_) {
    return;
  }
  if (!msg || typeof msg !== 'object') return;
  const type = String(msg.type || '');
  const meta = ws.meta || {};

  if (type === 'create') {
    createRoom(ws, msg);
    return;
  }
  if (type === 'join') {
    joinRoom(ws, msg);
    return;
  }
  if (type === 'leave') {
    leaveRoom(ws, 'leave');
    return;
  }

  const room = rooms.get(meta.room);
  if (!room || !meta.id) return;
  const player = room.players.get(meta.id);
  if (!player) return;

  if (type === 'profile') {
    const role = cleanRole(msg.role);
    if (role === 'ghost') {
      const ghostName = cleanGhostName(msg.ghost_name || player.ghost_name);
      if (ghostNameTaken(room, ghostName, player.id)) {
        send(ws, { type: 'error', message: 'Ese fantasma ya esta ocupado.' });
        return;
      }
      player.role = 'ghost';
      player.ghost_name = ghostName;
    } else {
      const color = cleanColor(msg.color || player.color);
      if (pacColorTaken(room, color, player.id)) {
        send(ws, { type: 'error', message: 'Ese color de Pac-Man ya esta ocupado.' });
        return;
      }
      player.role = 'pac';
      player.color = color;
    }
    broadcastRoom(room);
    return;
  }

  // Compatibilidad con clientes antiguos.
  if (type === 'color') {
    const color = cleanColor(msg.color);
    if (pacColorTaken(room, color, player.id)) {
      send(ws, { type: 'error', message: 'Ese color de Pac-Man ya esta ocupado.' });
      return;
    }
    player.role = 'pac';
    player.color = color;
    broadcastRoom(room);
    return;
  }

  if (type === 'lobby') {
    if (meta.id !== room.hostId || room.started) return;
    const data = msg.data || {};
    const rawBots = Number(data.bots);
    const bots = Number.isFinite(rawBots) ? Math.max(0, Math.min(4, Math.trunc(rawBots))) : 2;
    const mode = data.mode === 'remake' ? 'remake' : 'classic';
    room.settings = { bots, mode };
    broadcastRoom(room);
    return;
  }

  if (type === 'start') {
    if (meta.id !== room.hostId) return;
    room.started = true;
    const data = msg.data && typeof msg.data === 'object' ? msg.data : {};
    broadcast(room, { type: 'start', data, hostId: room.hostId });
    console.log(`[room ${room.code}] started ${data.mode || '?'}`);
    return;
  }

  if (type === 'input') {
    if (room.started && meta.id !== room.hostId) {
      send(room.players.get(room.hostId)?.ws, {
        type: 'input',
        playerId: meta.id,
        data: msg.data || {},
      });
    }
    return;
  }

  if (type === 'snapshot') {
    if (room.started && meta.id === room.hostId) {
      broadcast(room, { type: 'snapshot', data: msg.data || {} }, meta.id);
    }
    return;
  }

  if (type === 'lobby_return') {
    if (meta.id !== room.hostId) return;
    room.started = false;
    broadcast(room, { type: 'lobby_return' });
    broadcastRoom(room);
    return;
  }
}

const server = http.createServer((req, res) => {
  const reqUrl = new URL(req.url || '/', 'http://localhost');
  if (reqUrl.pathname === '/health' || reqUrl.pathname === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('ok');
    return;
  }

  let pathname = decodeURIComponent(reqUrl.pathname);
  if (pathname === '/' || pathname === '') pathname = '/index.html';
  const filePath = path.resolve(PUBLIC_DIR, '.' + pathname);
  if (!filePath.startsWith(PUBLIC_DIR + path.sep) && filePath !== PUBLIC_DIR) {
    res.writeHead(403);
    res.end('forbidden');
    return;
  }

  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      if (pathname === '/index.html') {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(`<!doctype html><html><head><meta charset="utf-8"><title>PAC-MAN ONLINE</title></head>
<body style="font-family:monospace;background:#05060c;color:#fff;padding:40px">
<h1>PAC-MAN ONLINE</h1>
<p>El build web todavia no esta en <code>server/public/</code>.</p>
<p>Exporta el proyecto Godot con el preset <b>Web</b> y vuelve a cargar.</p>
<p>Servidor WebSocket activo en <code>/ws</code>.</p>
</body></html>`);
        return;
      }
      res.writeHead(404);
      res.end('not found');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    const headers = {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': ['.html', '.js', '.pck'].includes(ext) ? 'no-cache' : 'public, max-age=86400',
    };
    res.writeHead(200, headers);
    fs.createReadStream(filePath).pipe(res);
  });
});

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 1024 * 1024 });

wss.on('connection', (ws) => {
  ws.meta = { id: null, room: null };
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
  ws.on('message', (data) => {
    try { handleMessage(ws, data); } catch (err) { console.error('message error', err); }
  });
  ws.on('close', () => {
    try { leaveRoom(ws, 'disconnect'); } catch (_) {}
  });
  ws.on('error', () => {});
  send(ws, { type: 'hello', server: 'pacman-online', version: 1 });
});

const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (ws.isAlive === false) {
      try { ws.terminate(); } catch (_) {}
      continue;
    }
    ws.isAlive = false;
    try { ws.ping(); } catch (_) {}
  }
}, 30000);
wss.on('close', () => clearInterval(heartbeat));

server.listen(PORT, '0.0.0.0', () => {
  console.log(`PAC-MAN ONLINE server on http://0.0.0.0:${PORT}`);
  console.log(`Serving ${PUBLIC_DIR}`);
});
