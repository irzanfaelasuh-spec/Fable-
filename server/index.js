import crypto from 'node:crypto';
import http from 'node:http';
import { WebSocketServer, WebSocket } from 'ws';
import { closeStorage, initializeStorage, registerUser, verifyUser } from './storage.js';

const PORT = Number(process.env.PORT || 8080);
const MAX_PLAYERS = 5;
const ROOM_CODE_LENGTH = 6;
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MAX_CHAT_LENGTH = 160;
const rooms = new Map();
const usedRoomCodes = new Set();
const expiredRoomCodes = new Set();
const clients = new Set();

const httpServer = http.createServer((request, response) => {
  if (request.url === '/health' || request.url === '/') {
    response.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
    response.end(JSON.stringify({ service: 'FABLEBRINK realtime', status: 'ok', rooms: rooms.size, maxPlayersPerRoom: MAX_PLAYERS }));
    return;
  }
  response.writeHead(404, { 'content-type': 'application/json' });
  response.end(JSON.stringify({ error: 'not_found' }));
});

const wss = new WebSocketServer({ server: httpServer, path: '/ws', maxPayload: 16 * 1024 });

function send(ws, payload) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}

function roomPlayers(room) {
  return [...room.players.values()].map((player) => ({
    id: player.id,
    username: player.username,
    x: player.x,
    y: player.y,
    host: player.id === room.hostId
  }));
}

function broadcast(room, payload, except = null) {
  for (const player of room.players.values()) {
    if (player.ws !== except) send(player.ws, payload);
  }
}

function createCode() {
  let code = '';
  do {
    code = '';
    for (let i = 0; i < ROOM_CODE_LENGTH; i += 1) {
      code += CODE_ALPHABET[crypto.randomInt(0, CODE_ALPHABET.length)];
    }
  } while (rooms.has(code) || usedRoomCodes.has(code));
  usedRoomCodes.add(code);
  return code;
}

function roomError(ws, code) {
  send(ws, { type: 'room_error', code });
}

function removeFromRoom(ws) {
  const code = ws.roomCode;
  if (!code) return;
  const room = rooms.get(code);
  ws.roomCode = null;
  if (!room) return;
  const leaving = room.players.get(ws.playerId);
  room.players.delete(ws.playerId);
  if (room.players.size === 0) {
    rooms.delete(code);
    expiredRoomCodes.add(code);
    return;
  }
  if (room.hostId === ws.playerId) {
    const nextHost = room.players.values().next().value;
    room.hostId = nextHost.id;
  }
  broadcast(room, {
    type: 'room_update',
    status: room.status,
    hostId: room.hostId,
    players: roomPlayers(room),
    notice: leaving ? `${leaving.username} left the room.` : 'A player left the room.'
  });
}

function rateLimit(ws, key, intervalMs) {
  const now = Date.now();
  const previous = ws.rateLimits.get(key) || 0;
  if (now - previous < intervalMs) return false;
  ws.rateLimits.set(key, now);
  return true;
}

function requireAuth(ws) {
  if (!ws.username) {
    send(ws, { type: 'error', code: 'not_authenticated' });
    return false;
  }
  return true;
}

async function handleMessage(ws, payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) || typeof payload.type !== 'string') {
    send(ws, { type: 'error', code: 'invalid_message' });
    return;
  }

  switch (payload.type) {
    case 'heartbeat':
      send(ws, { type: 'heartbeat_ack' });
      return;

    case 'register': {
      if (ws.username) return send(ws, { type: 'auth_result', ok: false, code: 'already_authenticated' });
      if (!rateLimit(ws, 'auth', 900)) return send(ws, { type: 'auth_result', ok: false, code: 'rate_limited' });
      const username = String(payload.username || '').trim();
      const password = String(payload.password || '');
      if (!/^[A-Za-z0-9_]{3,16}$/.test(username) || password.length < 8 || password.length > 72) {
        return send(ws, { type: 'auth_result', ok: false, code: 'invalid_input' });
      }
      try {
        const result = await registerUser(username, password);
        if (!result.ok) return send(ws, { type: 'auth_result', ok: false, code: result.code });
        ws.username = username;
        ws.playerId = crypto.randomUUID();
        return send(ws, { type: 'auth_result', ok: true, username, playerId: ws.playerId });
      } catch (error) {
        console.error('[auth] register failed:', error.message);
        return send(ws, { type: 'auth_result', ok: false, code: 'server_error' });
      }
    }

    case 'login': {
      if (ws.username) return send(ws, { type: 'auth_result', ok: false, code: 'already_authenticated' });
      if (!rateLimit(ws, 'auth', 900)) return send(ws, { type: 'auth_result', ok: false, code: 'rate_limited' });
      const username = String(payload.username || '').trim();
      const password = String(payload.password || '');
      if (!/^[A-Za-z0-9_]{3,16}$/.test(username) || password.length < 1 || password.length > 72) {
        return send(ws, { type: 'auth_result', ok: false, code: 'invalid_credentials' });
      }
      try {
        const result = await verifyUser(username, password);
        if (!result.ok) return send(ws, { type: 'auth_result', ok: false, code: 'invalid_credentials' });
        ws.username = result.username;
        ws.playerId = crypto.randomUUID();
        return send(ws, { type: 'auth_result', ok: true, username: result.username, playerId: ws.playerId });
      } catch (error) {
        console.error('[auth] login failed:', error.message);
        return send(ws, { type: 'auth_result', ok: false, code: 'server_error' });
      }
    }

    case 'logout':
      removeFromRoom(ws);
      ws.username = null;
      ws.playerId = null;
      send(ws, { type: 'logout_result', ok: true });
      return;

    case 'create_room': {
      if (!requireAuth(ws)) return;
      if (ws.roomCode) removeFromRoom(ws);
      const code = createCode();
      const room = {
        code,
        seed: crypto.randomInt(1, 2147483647),
        hostId: ws.playerId,
        status: 'lobby',
        players: new Map(),
        createdAt: Date.now()
      };
      const player = { id: ws.playerId, username: ws.username, ws, x: 180, y: 0 };
      room.players.set(player.id, player);
      rooms.set(code, room);
      ws.roomCode = code;
      send(ws, { type: 'room_created', code, seed: room.seed, maxPlayers: MAX_PLAYERS, hostId: room.hostId, players: roomPlayers(room), status: room.status });
      return;
    }

    case 'join_room': {
      if (!requireAuth(ws)) return;
      const code = String(payload.code || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, ROOM_CODE_LENGTH);
      const room = rooms.get(code);
      if (!room) return roomError(ws, expiredRoomCodes.has(code) ? 'expired' : 'invalid_code');
      if (room.status !== 'lobby') return roomError(ws, 'expired');
      if (room.players.size >= MAX_PLAYERS) return roomError(ws, 'full');
      if (ws.roomCode) removeFromRoom(ws);
      const player = { id: ws.playerId, username: ws.username, ws, x: 180, y: 0 };
      room.players.set(player.id, player);
      ws.roomCode = code;
      send(ws, { type: 'room_joined', code, seed: room.seed, maxPlayers: MAX_PLAYERS, hostId: room.hostId, players: roomPlayers(room), status: room.status });
      broadcast(room, { type: 'room_update', status: room.status, hostId: room.hostId, players: roomPlayers(room) }, ws);
      return;
    }

    case 'start_game': {
      if (!requireAuth(ws)) return;
      const room = rooms.get(ws.roomCode);
      if (!room) return roomError(ws, 'invalid_code');
      if (room.hostId !== ws.playerId) return roomError(ws, 'not_host');
      if (room.status !== 'lobby') return roomError(ws, 'expired');
      room.status = 'playing';
      broadcast(room, { type: 'game_started', code: room.code, seed: room.seed, players: roomPlayers(room) });
      return;
    }

    case 'leave_room':
      removeFromRoom(ws);
      send(ws, { type: 'left_room' });
      return;

    case 'close_room': {
      if (!requireAuth(ws)) return;
      const room = rooms.get(ws.roomCode);
      if (!room) return send(ws, { type: 'room_closed', ok: true });
      if (room.hostId !== ws.playerId) return roomError(ws, 'not_host');
      broadcast(room, { type: 'room_closed', ok: true, code: room.code });
      for (const player of room.players.values()) player.ws.roomCode = null;
      rooms.delete(room.code);
      expiredRoomCodes.add(room.code);
      return;
    }

    case 'move': {
      if (!requireAuth(ws) || !ws.roomCode) return;
      const room = rooms.get(ws.roomCode);
      if (!room || room.status !== 'playing') return;
      const player = room.players.get(ws.playerId);
      const x = Number(payload.x);
      const y = Number(payload.y);
      if (!player || !Number.isFinite(x) || !Number.isFinite(y) || Math.abs(x) > 120000 || Math.abs(y) > 50000) return;
      player.x = x;
      player.y = y;
      broadcast(room, { type: 'player_moved', id: player.id, username: player.username, x, y }, ws);
      return;
    }

    case 'chat': {
      if (!requireAuth(ws) || !ws.roomCode) return;
      const room = rooms.get(ws.roomCode);
      if (!room || room.status !== 'playing') return;
      if (!rateLimit(ws, 'chat', 450)) return send(ws, { type: 'chat_rejected', code: 'rate_limited' });
      const message = String(payload.message || '').trim().slice(0, MAX_CHAT_LENGTH);
      if (!message) return;
      broadcast(room, { type: 'chat_message', username: ws.username, message, timestamp: Date.now() });
      return;
    }

    case 'emote': {
      if (!requireAuth(ws) || !ws.roomCode) return;
      const room = rooms.get(ws.roomCode);
      if (!room || room.status !== 'playing') return;
      const emote = String(payload.emote || '').toLowerCase();
      if (!['hi', 'sad', 'happy'].includes(emote)) return;
      broadcast(room, { type: 'player_emote', id: ws.playerId, emote });
      return;
    }

    case 'block_change': {
      if (!requireAuth(ws) || !ws.roomCode) return;
      const room = rooms.get(ws.roomCode);
      if (!room || room.status !== 'playing') return;
      if (!rateLimit(ws, 'block', 80)) return;
      const action = String(payload.action || '');
      const x = Number(payload.x);
      const y = Number(payload.y);
      const block = Number(payload.block || 2);
      if (!['break', 'place'].includes(action) || !Number.isInteger(x) || !Number.isInteger(y) || !Number.isInteger(block)) return;
      if (x < 0 || x >= 4800 || y < 0 || y >= 70 || block < 1 || block > 5) return;
      broadcast(room, { type: 'block_changed', id: ws.playerId, action, x, y, block }, ws);
      return;
    }

    default:
      send(ws, { type: 'error', code: 'unknown_message_type' });
  }
}

wss.on('connection', (ws, request) => {
  ws.username = null;
  ws.playerId = null;
  ws.roomCode = null;
  ws.rateLimits = new Map();
  ws.clientIp = request.socket.remoteAddress || 'unknown';
  clients.add(ws);
  send(ws, { type: 'server_ready', protocol: 1, maxPlayers: MAX_PLAYERS });

  ws.on('message', async (data, isBinary) => {
    if (isBinary) return send(ws, { type: 'error', code: 'text_json_required' });
    try {
      const payload = JSON.parse(data.toString('utf8'));
      await handleMessage(ws, payload);
    } catch (error) {
      console.error('[message] rejected:', error.message);
      send(ws, { type: 'error', code: 'server_error' });
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
    removeFromRoom(ws);
  });
  ws.on('error', (error) => console.warn('[websocket] client error:', error.message));
});

await initializeStorage();
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`[FABLEBRINK] realtime server listening on :${PORT}`);
});

async function shutdown() {
  console.log('[FABLEBRINK] shutting down');
  for (const ws of clients) ws.close(1001, 'server restarting');
  wss.close();
  httpServer.close();
  await closeStorage();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
